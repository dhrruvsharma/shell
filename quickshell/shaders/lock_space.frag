#version 440

// Deep-space backdrop for the "Astral" lock theme: three parallax layers of
// twinkling stars drifting past, an fbm nebula tinted with the two theme
// colours, and a faint galactic band. Motion comes from `time`, which only
// advances while the lock screen is awake.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float time;
    float nebula;      // 0..1 nebula strength
    vec4 baseColor;    // opaque
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
vec3 stars(vec2 p, float density, float size, float t, float seed) {
    vec2 cell = floor(p);
    float h = hash(cell + seed);
    if (h > density)
        return vec3(0.0);
    vec2 pos = vec2(hash(cell + seed + 1.3), hash(cell + seed + 7.9)) * 0.8 + 0.1;
    float d = length(fract(p) - pos);
    float twinkle = 0.65 + 0.35 * sin(t * (1.0 + h * 3.0) + h * 60.0);
    float core = smoothstep(size, 0.0, d);
    float halo = smoothstep(size * 4.0, 0.0, d) * 0.25;
    vec3 tint = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.9, 0.75), hash(cell + seed + 3.7));
    return tint * (core + halo) * twinkle * (0.45 + 0.55 * hash(cell + seed + 5.1));
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 uv = qt_TexCoord0;
    vec2 p = vec2(uv.x * res.x / res.y, uv.y);
    float t = ubuf.time;

    vec3 col = ubuf.baseColor.rgb;

    // Nebula: two tinted fbm clouds, drifting slowly.
    float n1 = fbm(p * 1.6 + vec2(t * 0.006, -t * 0.003));
    float n2 = fbm(p * 2.8 - vec2(t * 0.004, t * 0.005) + 13.0);
    col += ubuf.tintA.rgb * smoothstep(0.45, 0.95, n1) * 0.32 * ubuf.nebula;
    col += ubuf.tintB.rgb * smoothstep(0.5, 1.0, n2) * 0.22 * ubuf.nebula;

    // Galactic band across the sky.
    float band = exp(-pow((uv.y - 0.35 - 0.25 * uv.x) * 3.2, 2.0));
    col += mix(ubuf.tintA.rgb, vec3(0.8, 0.85, 1.0), 0.6) * band * 0.06 * (0.6 + 0.4 * n2);

    // Stars in three parallax layers.
    col += stars(p * 90.0 + vec2(t * 0.35, 0.0), 0.16 + band * 0.1, 0.05, t, 1.0) * 0.55;
    col += stars(p * 48.0 + vec2(t * 0.8, 0.0), 0.12, 0.06, t, 17.0) * 0.85;
    col += stars(p * 22.0 + vec2(t * 1.6, 0.0), 0.07, 0.07, t, 31.0) * 1.2;

    // Vignette.
    vec2 c = uv - 0.5;
    c.x *= res.x / res.y;
    col *= mix(1.0, 0.55, smoothstep(0.4, 1.2, length(c)));

    fragColor = vec4(col, 1.0) * ubuf.qt_Opacity;
}
