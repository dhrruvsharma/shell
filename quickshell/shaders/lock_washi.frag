#version 440

// Washi backdrop for the "Ensō" lock theme.
//
// Warm handmade paper with its long fibres and uneven tone, the wallpaper
// printed on it faintly in sumi (with a trace of its own colour), edges aged
// brown, and a few things of the season drifting down: cherry petals in
// spring, fireflies in summer, maple leaves in autumn, snow in winter. What
// moves is a function of `time`, which only advances while the lock screen is
// awake.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float time;
    float season;      // 0 spring, 1 summer, 2 autumn, 3 winter
    float inkPrint;    // 0..1 how strongly the wallpaper shows
    vec4 paperColor;   // opaque
    vec4 inkColor;     // opaque
    vec4 ageColor;     // opaque
} ubuf;

layout(binding = 1) uniform sampler2D wall;

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

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = p * 2.03 + vec2(17.3, 9.1);
        a *= 0.5;
    }
    return v;
}

float fibres(vec2 px, vec2 dir, float seed) {
    vec2 n = vec2(-dir.y, dir.x);
    vec2 q = vec2(dot(px, dir), dot(px, n));
    float v = noise(vec2(q.x * 0.004, q.y * 0.06) + seed);
    return smoothstep(0.035, 0.0, abs(v - 0.5)) * noise(q * vec2(0.01, 0.02) + seed * 3.0);
}

// One layer of falling things; returns (coverage, glow) in `col` terms.
vec4 fall(vec2 px, float cell, float speed, float seed, float t, float s) {
    vec2 p = px / cell;
    p.y -= t * speed / cell;
    vec2 id = floor(p);
    float h = hash(id + seed);
    if (h > 0.16)
        return vec4(0.0);
    vec2 f = fract(p) - 0.5;
    float ph = hash(id + seed + 5.0) * TAU;
    f.x -= sin(t * 0.9 + ph) * 0.22;
    f.x += (hash(id + seed + 9.0) - 0.5) * 0.3;
    // Tumbling.
    float a = t * (0.6 + hash(id + seed + 2.0)) + ph;
    vec2 r = vec2(f.x * cos(a) - f.y * sin(a), f.x * sin(a) + f.y * cos(a));
    float size = (0.6 + 0.4 * hash(id + seed + 13.0));
    float cover = 0.0;
    vec3 tone = vec3(0.0);
    if (s < 0.5) {
        // Cherry petal: a notched ellipse.
        vec2 e = r / (vec2(0.07, 0.045) * size);
        float body = smoothstep(1.08, 0.92, length(e));
        float notch = smoothstep(0.32, 0.26, length(e - vec2(1.0, 0.0)));
        cover = body * (1.0 - notch);
        tone = mix(vec3(0.95, 0.76, 0.8), vec3(0.98, 0.9, 0.9), hash(id + seed + 3.0));
    } else if (s < 1.5) {
        // Firefly: a warm speck with a halo, pulsing.
        float d = length(f);
        float pulse = 0.5 + 0.5 * sin(t * 2.5 + ph * 3.0);
        cover = (smoothstep(0.03, 0.0, d) + smoothstep(0.12, 0.0, d) * 0.35) * pulse;
        tone = vec3(0.72, 0.66, 0.2);
    } else if (s < 2.5) {
        // Maple leaf: five pointed lobes with deep notches, on a stem.
        float ang = atan(r.y, r.x);
        float rad = length(r) / size;
        float lobe = 0.022 + 0.05 * (1.0 - pow(abs(sin(ang * 2.5)), 0.5));
        cover = smoothstep(lobe + 0.005, lobe - 0.005, rad);
        vec2 st = r / size;
        cover = max(cover, smoothstep(0.006, 0.002, abs(st.x)) * step(0.0, st.y) * step(st.y, 0.075));
        tone = mix(vec3(0.72, 0.2, 0.1), vec3(0.85, 0.5, 0.15), hash(id + seed + 3.0));
    } else {
        // Snow.
        float d = length(f) / size;
        cover = smoothstep(0.045, 0.03, d);
        tone = vec3(0.8, 0.84, 0.88);
    }
    return vec4(tone, cover);
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * res;
    float aspect = res.x / res.y;
    float t = ubuf.time;

    // Paper: uneven tone and fibres.
    vec3 col = ubuf.paperColor.rgb * (0.96 + 0.06 * fbm(uv * vec2(aspect, 1.0) * 6.0));
    float fib = fibres(px, normalize(vec2(1.0, 0.35)), 1.7) + fibres(px, normalize(vec2(0.4, 1.0)), 8.3) * 0.7;
    col = mix(col, vec3(1.0), clamp(fib, 0.0, 1.0) * 0.18);

    // The wallpaper, printed faintly in sumi.
    vec2 o = 3.0 / res;
    vec3 w = (texture(wall, uv).rgb * 2.0 + texture(wall, uv + vec2(o.x, 0.0)).rgb + texture(wall, uv - vec2(o.x, 0.0)).rgb
            + texture(wall, uv + vec2(0.0, o.y)).rgb + texture(wall, uv - vec2(0.0, o.y)).rgb) / 6.0;
    float l = dot(w, vec3(0.2126, 0.7152, 0.0722));
    vec3 ink = mix(ubuf.inkColor.rgb, mix(vec3(l), w, 0.5) * 0.7, 0.3);
    col = mix(col, ink, pow(1.0 - l, 1.3) * ubuf.inkPrint);

    // Aged edges.
    vec2 c = uv - 0.5;
    c.x *= aspect;
    float edge = smoothstep(0.5, 1.15, length(c) + (fbm(uv * 4.0 + 2.0) - 0.5) * 0.3);
    col = mix(col, col * ubuf.ageColor.rgb * 1.3, edge * 0.55);

    // The season, drifting down.
    vec4 a = fall(px, 170.0, 38.0, 1.0, t, ubuf.season);
    vec4 b = fall(px + vec2(61.0, 0.0), 110.0, 24.0, 7.0, t, ubuf.season);
    col = mix(col, a.rgb, clamp(a.a, 0.0, 1.0) * 0.9);
    col = mix(col, b.rgb, clamp(b.a, 0.0, 1.0) * 0.6);

    fragColor = vec4(col, 1.0) * ubuf.qt_Opacity;
}
