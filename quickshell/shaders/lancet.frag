#version 440
// A lancet window for the Cathedral power menu (modules/power/
// GothicPower.qml): a tall pane under an equilateral pointed arch, glazed
// in diamond quarries of two jewel glasses held in lead, a heavier lead
// round the edge. `light` is how much daylight comes through it (dull and
// dark at 0); the candle standing in front of it warms the glass from the
// foot (`candle`). Premultiplied; clear outside the arch.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float light;       // 0..1
    float candle;      // 0..1
    float seed;
    float quarry;      // px across a quarry
    vec4 glassA;       // opaque
    vec4 glassB;       // opaque
    vec4 leadColor;    // opaque
    vec4 warmColor;    // opaque
} ubuf;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Signed distance inside the lancet (> 0 inside), px.
float lancet(vec2 p, float w, float h) {
    float spring = w * 0.866;
    float side = min(p.x, w - p.x);
    float foot = h - p.y;
    float d = min(side, foot);
    if (p.y < spring) {
        // The two arcs of the arch, each struck from the far side's springing.
        float a = w - length(p - vec2(w, spring));
        float b = w - length(p - vec2(0.0, spring));
        d = min(d, min(a, b));
    }
    return d;
}

void main() {
    vec2 size = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 p = qt_TexCoord0 * size;
    float d = lancet(p, size.x, size.y);
    float inside = smoothstep(-0.8, 0.8, d);
    if (inside <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    // Diamond quarries.
    float s = ubuf.quarry;
    vec2 q = vec2(p.x + p.y, p.x - p.y) / s;
    vec2 cell = floor(q);
    vec2 f = fract(q) - 0.5;
    float lead = smoothstep(0.43, 0.47, max(abs(f.x), abs(f.y)));
    float h = hash(cell + ubuf.seed);
    vec3 glass = mix(ubuf.glassA.rgb, ubuf.glassB.rgb, step(0.62, h));
    glass *= 0.75 + 0.35 * hash(cell * 1.7 + ubuf.seed + 3.0);
    // A paler glass now and then, as old glazing has.
    glass = mix(glass, vec3(0.86, 0.82, 0.7), step(0.92, h) * 0.5);

    float day = mix(0.12, 1.0, ubuf.light);
    // Light falls through the upper glass more than the lower.
    float through = day * (0.75 + 0.25 * (1.0 - p.y / size.y));
    vec3 col = glass * through;
    // The candle's warmth on the lower panes.
    float warm = ubuf.candle * exp(-max(0.0, size.y - p.y) / (size.y * 0.35)) * 0.55;
    col += ubuf.warmColor.rgb * warm * (0.4 + 0.6 * glass);

    // Lead between the quarries and a heavier calme round the edge.
    float edge = 1.0 - smoothstep(2.5, 4.5, d);
    float leadA = max(lead, edge);
    col = mix(col, ubuf.leadColor.rgb, leadA);

    fragColor = vec4(col, 1.0) * inside * ubuf.qt_Opacity;
}
