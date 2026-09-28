#version 440
// An ensō: one brushstroke round a circle, drawn clockwise from `start`
// (turns from twelve o'clock) for `sweep` of the way. The stroke lands heavy,
// thins as the brush runs dry (kasure streaks towards the end) and lifts off
// in a taper; the radius wanders a little, as a hand does. `ghost` shows the
// whole circle as a faint trace. Up to four cracks (`crackAt`, turns along
// the stroke) break it; `gold` fills them with kintsugi. `bleed` swells a blot
// of ink at the brush's tip. Premultiplied output; everything is a function of
// the uniforms, so it only redraws when they change.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float sweep;       // 0..1 of the circle drawn
    float start;       // turns clockwise from twelve o'clock
    float thickness;   // stroke width as a fraction of the radius
    float ghost;       // 0..1 faint trace of the whole circle
    float bleed;       // 0..1 ink blot at the tip
    float cracks;      // how many of crackAt are in use (0..4)
    float gold;        // 0..1 cracks filled with gold
    float seed;
    vec4 crackAt;      // turns along the stroke
    vec4 inkColor;     // opaque
    vec4 goldColor;    // opaque
} ubuf;

const float TAU = 6.28318530718;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Ring radius (px) at stroke position s: a hand's wander, drifting slightly
// outward as it goes.
float ringRadius(float s, float r0) {
    return r0 * (1.0 + 0.022 * sin(s * TAU * 1.3 + ubuf.seed * 3.1) + 0.03 * (noise(vec2(s * 5.0, ubuf.seed)) - 0.5) + 0.025 * s);
}

// Stroke width (px) at s: heavy where the brush lands, thinner after,
// tapering to nothing at the tip.
float strokeWidth(float s, float r0) {
    float w = r0 * ubuf.thickness * (0.72 + 0.4 * (1.0 - s)) * (1.0 + 0.4 * exp(-s * 30.0));
    w *= 1.0 + 0.14 * (noise(vec2(s * 11.0, ubuf.seed + 4.0)) - 0.5);
    return w * (1.0 - 0.85 * smoothstep(ubuf.sweep - 0.08, ubuf.sweep, s));
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 p = (qt_TexCoord0 - 0.5) * res;
    float r0 = min(res.x, res.y) * 0.4;
    float r = length(p);
    float a = fract(atan(p.x, -p.y) / TAU);
    float s = fract(a - ubuf.start);

    float R = ringRadius(s, r0);
    float across = r - R;
    vec4 col = vec4(0.0);

    // The trace of the whole circle.
    if (ubuf.ghost > 0.0) {
        float gw = r0 * ubuf.thickness * 0.35;
        float g = smoothstep(gw * 0.5 + 0.8, gw * 0.5 - 0.8, abs(across)) * ubuf.ghost * 0.22;
        col = vec4(ubuf.inkColor.rgb * g, g);
    }

    // The stroke.
    float cover = 0.0;
    float cracked = 0.0;
    if (s <= ubuf.sweep && ubuf.sweep > 0.0) {
        float w = strokeWidth(s, r0);
        float rough = ((noise(vec2(s * 60.0, sign(across) * 7.0 + ubuf.seed)) - 0.5) * 0.06
                     + (noise(vec2(s * 260.0, sign(across) * 3.0 + ubuf.seed)) - 0.5) * 0.03) * w;
        cover = smoothstep(w * 0.5 + rough + 0.8, w * 0.5 + rough - 0.8, abs(across));

        // Kasure: dry streaks along the stroke, more of them as the ink runs out.
        float dry = smoothstep(0.3, 1.0, s) * 0.55 + smoothstep(ubuf.sweep - 0.2, ubuf.sweep, s) * 0.35;
        float streak = noise(vec2(across / max(w, 1.0) * 16.0 + ubuf.seed * 11.0, s * 4.0));
        cover *= mix(1.0, smoothstep(dry - 0.12, dry + 0.05, streak), step(0.02, dry));

        // Cracks: jagged lines across the stroke, a hair wider when mended
        // (kintsugi lacquer stands proud of the break).
        float crackW = mix(1.6, 2.4, ubuf.gold);
        for (int i = 0; i < 4; i++) {
            if (float(i) >= ubuf.cracks)
                break;
            float at = ubuf.crackAt[i];
            float arc = (s - at) * TAU * r;
            float jag = (noise(vec2(across * 0.2 + float(i) * 9.0, ubuf.seed + float(i))) - 0.5) * 16.0
                      + (noise(vec2(across * 1.1, float(i) * 3.0)) - 0.5) * 4.0;
            cracked = max(cracked, smoothstep(crackW + 0.9, crackW - 0.6, abs(arc - jag)));
        }
    }

    // Where the brush landed: a rounded press of ink.
    if (ubuf.sweep > 0.0) {
        float a0 = ubuf.start * TAU;
        vec2 p0 = vec2(sin(a0), -cos(a0)) * ringRadius(0.0, r0);
        float w0 = strokeWidth(0.0, r0) * 0.5;
        float land = smoothstep(w0 + 0.8, w0 - 0.8, length(p - p0) + (noise(p * 0.15 + ubuf.seed) - 0.5) * w0 * 0.25);
        cover = max(cover, land);
    }

    // A blot swelling at the tip.
    if (ubuf.bleed > 0.0 && ubuf.sweep > 0.0) {
        float tipA = (ubuf.start + ubuf.sweep) * TAU;
        float tipR = ringRadius(ubuf.sweep, r0);
        vec2 tip = vec2(sin(tipA), -cos(tipA)) * tipR;
        float br = r0 * ubuf.thickness * (0.25 + 0.3 * ubuf.bleed);
        float blot = smoothstep(br + 0.8, br - 0.8, length(p - tip) + (noise(p * 0.2) - 0.5) * br * 0.5);
        cover = max(cover, blot * ubuf.bleed);
    }

    // Ink pools at the edges of a stroke: a touch darker there.
    vec3 ink = ubuf.inkColor.rgb * (0.9 + 0.1 * smoothstep(0.0, 1.0, abs(across) / max(strokeWidth(s, r0) * 0.5, 1.0)));
    float inkA = cover * (1.0 - cracked * (1.0 - ubuf.gold));
    col = vec4(ink * inkA + col.rgb * (1.0 - inkA), inkA + col.a * (1.0 - inkA));
    float goldA = cover * cracked * ubuf.gold;
    col = vec4(ubuf.goldColor.rgb * goldA + col.rgb * (1.0 - goldA), goldA + col.a * (1.0 - goldA));

    fragColor = col * ubuf.qt_Opacity;
}
