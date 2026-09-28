#version 440
// Wabi-sabi over the wallpaper: a veil of washi paper with its long fibres,
// edges aged to a warm brown along an uneven line, and two cracks mended with
// gold (kintsugi) running in from the rim: one up from the bottom edge, one
// down from the top. Output is premultiplied and translucent. Nothing depends
// on time, so it only costs a quad on frames that are drawn anyway.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float paper;       // 0..1 paper veil
    float age;         // 0..1 browned edges
    float seam;        // 0..1 kintsugi
    float lineScale;   // >1 thickens hairlines in small previews
    vec4 paperColor;   // opaque
    vec4 ageColor;     // opaque
    vec4 goldColor;    // opaque
    vec4 goldHi;       // opaque
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
        p = p * 2.03 + vec2(17.3, 9.1);
        a *= 0.5;
    }
    return v;
}

vec4 over(vec4 dst, vec3 rgb, float a) {
    return vec4(rgb * a + dst.rgb * (1.0 - a), a + dst.a * (1.0 - a));
}

// Long paper fibres: thin, wandering lines of noise stretched along `dir`.
float fibres(vec2 px, vec2 dir, float seed) {
    vec2 n = vec2(-dir.y, dir.x);
    vec2 q = vec2(dot(px, dir), dot(px, n));
    float v = noise(vec2(q.x * 0.004, q.y * 0.06) + seed);
    return smoothstep(0.035, 0.0, abs(v - 0.5)) * noise(q * vec2(0.01, 0.02) + seed * 3.0);
}

// How far a crack wanders off its straight line, `along` px from its origin
// (it leaves the origin straight, so branches meet their parent).
float crackOff(float along, float seed) {
    return ((noise(vec2(along * 0.018, seed)) - 0.5) * 34.0
          + (noise(vec2(along * 0.11, seed + 5.0)) - 0.5) * 7.0) * smoothstep(0.0, 40.0, along);
}

vec2 crackPoint(vec2 origin, vec2 dir, float along, float seed) {
    return origin + dir * along + vec2(-dir.y, dir.x) * crackOff(along, seed);
}

// A mended crack from `origin` along `dir` for `len` px: a jagged line that
// thins out as it goes. Returns (coverage, core).
vec2 crack(vec2 px, vec2 origin, vec2 dir, float len, float seed) {
    vec2 n = vec2(-dir.y, dir.x);
    vec2 d = px - origin;
    float along = dot(d, dir);
    if (along < -4.0 || along > len + 4.0)
        return vec2(0.0);
    float t = clamp(along / len, 0.0, 1.0);
    float w = mix(2.1, 0.5, t) * ubuf.lineScale;
    float dist = abs(dot(d, n) - crackOff(along, seed));
    float ends = smoothstep(-4.0, 0.0, along) * (1.0 - smoothstep(len - 20.0, len + 4.0, along));
    return vec2(smoothstep(w + 0.8, w * 0.4, dist), smoothstep(w * 0.6, 0.0, dist)) * ends;
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * res;
    float aspect = res.x / res.y;

    // The paper: a warm veil, uneven like handmade sheets, with fibres.
    float cloud = fbm(uv * vec2(aspect, 1.0) * 5.0);
    vec4 col = vec4(0.0);
    col = over(col, ubuf.paperColor.rgb, ubuf.paper * (0.05 + 0.06 * cloud));
    float f = fibres(px, normalize(vec2(1.0, 0.35)), 1.7) + fibres(px, normalize(vec2(0.4, 1.0)), 8.3) * 0.7
            + fibres(px, normalize(vec2(1.0, -0.6)), 4.1) * 0.8;
    col = over(col, mix(ubuf.paperColor.rgb, vec3(1.0), 0.4), clamp(f, 0.0, 1.0) * 0.055 * ubuf.paper);

    // Aged edges along an uneven line.
    vec2 c = uv - 0.5;
    c.x *= aspect;
    float edge = smoothstep(0.55, 1.2, length(c) + (fbm(uv * 4.0 + 2.0) - 0.5) * 0.3);
    col = over(col, ubuf.ageColor.rgb, edge * 0.42 * ubuf.age);

    // Kintsugi.
    if (ubuf.seam > 0.0) {
        vec2 aFrom = vec2(res.x * 0.43, res.y);
        vec2 aDir = normalize(vec2(0.35, -1.0));
        float aLen = res.y * 0.2;
        vec2 a = crack(px, aFrom, aDir, aLen, 3.0);
        vec2 b = crack(px, crackPoint(aFrom, aDir, aLen * 0.4, 3.0), normalize(vec2(-0.8, -0.6)), res.y * 0.08, 9.0);
        vec2 d = crack(px, vec2(res.x * 0.64, 0.0), normalize(vec2(-0.25, 1.0)), res.y * 0.11, 14.0);
        vec2 k = max(max(a, b), d);
        vec3 gold = mix(ubuf.goldColor.rgb, ubuf.goldHi.rgb, k.y);
        col = over(col, gold, k.x * ubuf.seam);
    }

    fragColor = col * ubuf.qt_Opacity;
}
