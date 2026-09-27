#version 440
// Ink and mist for the Cave Abode desktop theme, drawn over the wallpaper:
// ink bleeding in from the edges along a broken fbm line, mist banks that
// thicken towards the valleys at the bottom, and a few still motes of qi.
// Output is premultiplied and translucent. Nothing depends on time, so it
// only costs a quad on frames that are drawn anyway.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float ink;         // 0..1 edge ink
    float mist;        // 0..1 mist banks
    float motes;       // 0..1 qi motes
    float moteScale;   // mote size multiplier (small previews need bigger motes)
    vec4 inkColor;     // opaque
    vec4 mistColor;    // opaque
    vec4 moteColor;    // opaque
} ubuf;

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

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = p * 2.03 + vec2(17.3, 9.1);
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 uv = qt_TexCoord0;
    float aspect = res.x / res.y;

    // Ink from the edges.
    vec2 c = uv - 0.5;
    c.x *= aspect;
    float edge = smoothstep(0.5, 1.15, length(c) + (fbm(uv * 3.0 + 3.0) - 0.5) * 0.4);
    float inkA = edge * ubuf.ink;
    vec4 col = vec4(ubuf.inkColor.rgb * inkA, inkA);

    // Mist banks, thicker towards the bottom.
    float m = fbm(uv * vec2(2.4, 5.2));
    float m2 = fbm(uv * vec2(4.8, 9.0) + 7.0);
    float bank = smoothstep(0.45, 0.85, m * 0.7 + m2 * 0.3);
    float depth = 0.04 + 0.6 * smoothstep(0.4, 1.0, uv.y);
    float mistA = bank * depth * ubuf.mist;
    col = vec4(ubuf.mistColor.rgb * mistA + col.rgb * (1.0 - mistA), mistA + col.a * (1.0 - mistA));

    // Still motes of qi, more of them low down.
    vec2 p = vec2(uv.x * aspect, uv.y) * 16.0;
    vec2 cell = floor(p);
    float h = hash(cell + 3.0);
    if (h > 0.9 - 0.12 * uv.y) {
        vec2 f = fract(p) - 0.5 - (vec2(hash(cell + 7.0), hash(cell + 13.0)) - 0.5) * 0.6;
        float d = length(f);
        float glow = smoothstep(0.06 * ubuf.moteScale, 0.0, d) + smoothstep(0.2 * ubuf.moteScale, 0.0, d) * 0.25;
        col.rgb += ubuf.moteColor.rgb * glow * ubuf.motes * (0.4 + 0.6 * hash(cell + 21.0));
    }

    fragColor = col * ubuf.qt_Opacity;
}
