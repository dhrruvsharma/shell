#version 440
// A paper talisman of the Cave Abode power menu (modules/power/
// XianxiaPower.qml), as the layer effect over its drawing: the flat paper
// gets long fibres and darkened, uneven edges; `glow` wakes the cinnabar
// script with spirit light and puts a golden aura round the sheet (drawn in
// the `pad` margin round it); `burn` sets it alight from the foot, a ragged
// front of embers eating up the sheet, charring the paper just ahead of it
// and leaving nothing behind. Premultiplied.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float pad;         // px of margin round the paper
    float glow;        // 0..1
    float burn;        // 0..1
    float seed;
    float shadow;      // 0..1 its shadow on what's behind
    vec4 auraColor;    // opaque
    vec4 emberColor;   // opaque
} ubuf;

layout(binding = 1) uniform sampler2D source;

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
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = p * 2.07 + vec2(11.7, 3.9);
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 size = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * size;
    float pad = ubuf.pad;
    vec2 lo = vec2(pad);
    vec2 hi = size - pad;

    vec4 s = texture(source, uv);

    // Distance from the sheet's edge: < 0 inside.
    vec2 q = max(lo - px, px - hi);
    float dOut = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);

    // Fibres running down the sheet, and its edges darkened by handling.
    vec3 col = s.rgb;
    if (s.a > 0.0) {
        vec3 rgb = s.rgb / s.a;
        float fib = fbm(px * vec2(0.09, 0.012) + ubuf.seed * 17.0);
        float speck = noise(px * 0.35 + ubuf.seed * 5.0);
        rgb *= 0.9 + 0.14 * fib - 0.05 * smoothstep(0.75, 1.0, speck);
        float worn = smoothstep(0.0, 16.0, -dOut + (fbm(px * 0.06 + ubuf.seed) - 0.5) * 10.0);
        rgb *= mix(0.72, 1.0, worn);
        // Woken, the cinnabar strokes (red well above green) burn a hotter
        // vermilion and the paper warms.
        float ink = smoothstep(0.25, 0.45, rgb.r - rgb.g);
        rgb *= 1.0 + 0.1 * ubuf.glow * (1.0 - ink);
        rgb = mix(rgb, vec3(1.0, 0.3, 0.12), ink * ubuf.glow * 0.62);
        col = rgb * s.a;
    }
    float alpha = s.a;

    // Burning from the foot: `v` 0 at the foot of the sheet .. 1 at its head.
    // Ahead of the flames the paper browns, then chars; behind them there
    // is nothing left.
    if (ubuf.burn > 0.0) {
        float v = clamp((hi.y - px.y) / (hi.y - lo.y), 0.0, 1.0);
        float n = fbm(px * 0.03 + ubuf.seed * 3.0);
        float front = ubuf.burn * 1.32 - 0.16 + (n - 0.5) * 0.24;
        float ahead = v - front;
        float keep = smoothstep(-0.004, 0.008, ahead);
        float toast = 1.0 - smoothstep(0.02, 0.2, ahead);
        col = mix(col, vec3(0.42, 0.2, 0.06) * alpha, toast * 0.45);
        float scorch = 1.0 - smoothstep(0.0, 0.05, ahead);
        col = mix(col, vec3(0.12, 0.06, 0.03) * alpha, scorch * 0.85);
        float ember = exp(-abs(ahead) * 60.0) * step(dOut, 1.0);
        col *= keep;
        alpha *= keep;
        col += ubuf.emberColor.rgb * ember * (0.95 + 0.6 * noise(px * 0.07 + ubuf.seed));
        alpha = max(alpha, clamp(ember * 1.2, 0.0, 1.0));
    }

    // Behind the sheet: its aura, and under that its shadow (both outside
    // it only, and gone with the paper).
    float left = 1.0 - smoothstep(0.0, 0.3, ubuf.burn);
    float aura = dOut > 0.0 ? exp(-dOut / (pad * 0.3)) * ubuf.glow * 0.5 * left : 0.0;
    vec2 sq = max(lo + vec2(6.0, 11.0) - px, px - hi - vec2(6.0, 11.0));
    float dShadow = length(max(sq, 0.0)) + min(max(sq.x, sq.y), 0.0);
    float shade = (1.0 - smoothstep(-6.0, 14.0, dShadow)) * 0.5 * ubuf.shadow * left;
    vec4 under = vec4(ubuf.auraColor.rgb * aura, aura);
    under += vec4(0.0, 0.0, 0.0, shade) * (1.0 - under.a);
    vec4 outc = vec4(col, alpha) + under * (1.0 - alpha);

    fragColor = outc * ubuf.qt_Opacity;
}
