#version 440
// Still starfield for the Astral desktop theme, drawn over the wallpaper: a
// light veil so the stars read on a bright wallpaper, a faint nebula in the
// two theme colours, a galactic band, three layers of stars and a vignette.
// Output is premultiplied and translucent. Nothing depends on time, so it
// only costs a quad on frames that are drawn anyway.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float starScale;   // star size multiplier (small previews need bigger stars)
    float veil;        // 0..1 darkening veil
    float nebula;      // 0..1
    float vignette;    // 0..1
    vec4 veilColor;    // opaque
    vec4 tintA;        // opaque
    vec4 tintB;        // opaque
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
        p = p * 2.1 + vec2(5.2, 1.3);
        a *= 0.5;
    }
    return v;
}

// One layer of stars: a random star in some grid cells.
vec3 stars(vec2 p, float density, float size, float seed) {
    vec2 cell = floor(p);
    float h = hash(cell + seed);
    if (h > density)
        return vec3(0.0);
    vec2 pos = vec2(hash(cell + seed + 1.3), hash(cell + seed + 7.9)) * 0.8 + 0.1;
    float d = length(fract(p) - pos);
    float s = size * ubuf.starScale;
    float core = smoothstep(s, 0.0, d);
    float halo = smoothstep(s * 4.0, 0.0, d) * 0.25;
    vec3 tint = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.9, 0.75), hash(cell + seed + 3.7));
    return tint * (core + halo) * (0.45 + 0.55 * hash(cell + seed + 5.1));
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 uv = qt_TexCoord0;
    vec2 p = vec2(uv.x * res.x / res.y, uv.y);

    // Veil and vignette (premultiplied black-ish over the wallpaper).
    vec2 c = uv - 0.5;
    c.x *= res.x / res.y;
    float v = smoothstep(0.4, 1.2, length(c)) * ubuf.vignette;
    float a = ubuf.veil;
    vec3 col = ubuf.veilColor.rgb * a;
    col *= 1.0 - v;
    a = v + a * (1.0 - v);

    // Light, added on top (premultiplied colour with no extra coverage).
    float n1 = fbm(p * 1.6);
    float n2 = fbm(p * 2.8 + 13.0);
    col += ubuf.tintA.rgb * smoothstep(0.5, 0.95, n1) * 0.16 * ubuf.nebula;
    col += ubuf.tintB.rgb * smoothstep(0.55, 1.0, n2) * 0.12 * ubuf.nebula;

    float band = exp(-pow((uv.y - 0.35 - 0.25 * uv.x) * 3.2, 2.0));
    col += mix(ubuf.tintA.rgb, vec3(0.85, 0.88, 1.0), 0.6) * band * 0.04 * (0.6 + 0.4 * n2);

    col += stars(p * 90.0, 0.16 + band * 0.1, 0.05, 1.0) * 0.5;
    col += stars(p * 48.0, 0.12, 0.06, 17.0) * 0.8;
    col += stars(p * 22.0, 0.07, 0.07, 31.0) * 1.1;

    fragColor = vec4(col, a) * ubuf.qt_Opacity;
}
