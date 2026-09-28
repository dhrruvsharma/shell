#version 440

// Neon-noir city backdrop for the "Black ICE" lock theme.
//
// The wallpaper is softened, darkened and regraded: shadows sink into the
// night with the second neon in them, highlights light up in the first, as
// if the picture were lit by signs. Over it, haze drifts low down and rain
// falls in two layers. Everything that moves is a function of `time`, which
// only advances while the lock screen is awake.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float time;
    float rain;        // 0..1
    vec4 nightColor;   // opaque
    vec4 neonA;        // opaque
    vec4 neonB;        // opaque
} ubuf;

layout(binding = 1) uniform sampler2D wall;

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

// One layer of rain: streaks in columns, falling.
float rainLayer(vec2 px, float colW, float segL, float speed, float seed, float t) {
    float ang = 0.16;
    vec2 r = vec2(px.x * cos(ang) - px.y * sin(ang), px.x * sin(ang) + px.y * cos(ang));
    r.y -= t * speed;
    vec2 cell = floor(vec2(r.x / colW, r.y / segL));
    float h = hash(cell + seed);
    if (h > 0.32)
        return 0.0;
    float x0 = (0.2 + 0.6 * hash(cell + seed + 3.1)) * colW;
    float start = hash(cell + seed + 7.3) * 0.5;
    float len = 0.2 + 0.4 * hash(cell + seed + 11.9);
    float along = fract(r.y / segL) - start;
    float taper = smoothstep(0.0, len * 0.5, along) * (1.0 - smoothstep(len * 0.5, len, along)) * step(0.0, along) * step(along, len);
    float dx = abs(mod(r.x, colW) - x0);
    return smoothstep(1.0, 0.0, dx) * taper * (0.4 + 0.6 * hash(cell + seed + 17.7));
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * res;
    float t = ubuf.time;

    // Soft 9-tap sample of the wallpaper.
    vec2 o = 4.0 / res;
    vec3 w = vec3(0.0);
    for (int x = -1; x <= 1; x++)
        for (int y = -1; y <= 1; y++)
            w += texture(wall, uv + vec2(float(x), float(y)) * o).rgb;
    w /= 9.0;
    float l = dot(w, vec3(0.2126, 0.7152, 0.0722));

    // Noir grade lit by signs.
    vec3 tint = mix(ubuf.neonB.rgb, ubuf.neonA.rgb, smoothstep(0.25, 0.85, l));
    vec3 col = mix(vec3(l), w, 0.35) * 0.4;
    col = mix(col, col * tint * 1.7, 0.4);
    col += tint * pow(l, 3.0) * 0.28;
    col = mix(ubuf.nightColor.rgb, col, 0.35 + 0.65 * smoothstep(0.0, 0.5, l));

    // Haze drifting low down.
    float fog = fbm(uv * vec2(2.6, 2.0) + vec2(t * 0.015, 0.0)) * smoothstep(0.35, 1.0, uv.y);
    col += mix(ubuf.neonB.rgb, ubuf.neonA.rgb, 0.3) * fog * 0.14;

    // Rain, two layers.
    vec3 wet = mix(vec3(0.75, 0.8, 0.92), mix(ubuf.neonA.rgb, ubuf.neonB.rgb, uv.x), 0.5);
    float drops = rainLayer(px, 11.0, 150.0, 900.0, 1.0, t) * 0.22 + rainLayer(px, 7.0, 90.0, 520.0, 9.0, t) * 0.12;
    col += wet * drops * ubuf.rain;

    // Vignette and faint scanlines.
    vec2 c = uv - 0.5;
    c.x *= res.x / res.y;
    col *= mix(1.0, 0.45, smoothstep(0.35, 1.15, length(c)));
    col *= 1.0 - 0.06 * step(2.0, mod(px.y, 3.0));

    fragColor = vec4(col, 1.0) * ubuf.qt_Opacity;
}
