#version 440
// Neon Noir over the wallpaper: a noir shade that deepens towards the edges,
// neon light spilling in from signs just off screen (the first neon from the
// left, the second from the right), city haze glowing low down, and still
// rain streaks catching the light. Output is premultiplied and translucent:
// the shade darkens, the light adds. Nothing depends on time, so it only
// costs a quad on frames that are drawn anyway.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float shade;       // 0..1 noir darkening
    float spill;       // 0..1 neon light from the sides
    float haze;        // 0..1 lit fog low down
    float rain;        // 0..1 rain streaks
    float lineScale;   // >1 thickens the rain in small previews
    vec4 nightColor;   // opaque
    vec4 neonA;        // opaque
    vec4 neonB;        // opaque
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
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = p * 2.07 + vec2(11.3, 5.7);
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * res;
    float aspect = res.x / res.y;

    // Noir shade, heavier at the edges.
    vec2 c = uv - 0.5;
    c.x *= aspect;
    float vig = smoothstep(0.3, 1.1, length(c));
    float dark = ubuf.shade * (0.3 + 0.5 * vig);
    vec3 rgb = ubuf.nightColor.rgb * dark;

    // Neon spilling in from off-screen signs.
    float left = exp(-uv.x * 7.0) * (0.45 + 0.55 * smoothstep(0.15, 0.85, uv.y));
    float right = exp(-(1.0 - uv.x) * 7.0) * (0.35 + 0.65 * smoothstep(0.05, 0.7, uv.y));
    rgb += (ubuf.neonA.rgb * left + ubuf.neonB.rgb * right) * 0.13 * ubuf.spill;

    // City haze: patchy fog low down, lit by the second neon.
    float fog = smoothstep(0.5, 1.0, uv.y) * (0.45 + 0.55 * fbm(vec2(uv.x * aspect * 2.2, uv.y * 3.5)));
    rgb += mix(ubuf.neonB.rgb, ubuf.neonA.rgb, 0.25) * fog * 0.14 * ubuf.haze;

    // Rain: streaks slanting slightly left, in columns of random segments.
    float ang = 0.16;
    vec2 r = vec2(px.x * cos(ang) - px.y * sin(ang), px.x * sin(ang) + px.y * cos(ang));
    float colW = 9.0 * ubuf.lineScale;
    float segL = 110.0 * ubuf.lineScale;
    vec2 cell = floor(vec2(r.x / colW, r.y / segL));
    float h = hash(cell);
    if (h < 0.3) {
        float x0 = (0.2 + 0.6 * hash(cell + 3.1)) * colW;
        float start = hash(cell + 7.3) * 0.5;
        float len = 0.25 + 0.45 * hash(cell + 11.9);
        float along = fract(r.y / segL) - start;
        float body = step(0.0, along) * step(along, len);
        float taper = smoothstep(0.0, len * 0.4, along) * (1.0 - smoothstep(len * 0.6, len, along));
        float dx = abs(mod(r.x, colW) - x0);
        float line = smoothstep(0.9 * ubuf.lineScale, 0.0, dx) * body * taper;
        vec3 wet = mix(vec3(0.72, 0.78, 0.9), mix(ubuf.neonA.rgb, ubuf.neonB.rgb, uv.x), 0.45);
        rgb += wet * line * (0.06 + 0.16 * hash(cell + 17.7)) * ubuf.rain * (0.6 + 0.4 * (1.0 - uv.y));
    }

    fragColor = vec4(rgb, dark) * ubuf.qt_Opacity;
}
