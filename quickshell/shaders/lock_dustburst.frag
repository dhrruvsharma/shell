#version 440
// A cloud of dust thrown up along the floor when the "Blast Door" shutter
// slams down (Wasteland): billows rise from the bottom edge and spread,
// then settle and thin out as `progress` runs 0 -> 1. Premultiplied.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float progress;
    vec4 dustColor;    // opaque
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
    vec2 uv = qt_TexCoord0;
    float p = clamp(ubuf.progress, 0.0, 1.0);
    if (p <= 0.0 || p >= 1.0) {
        fragColor = vec4(0.0);
        return;
    }
    float aspect = ubuf.itemWidth / max(ubuf.itemHeight, 1.0);
    // Height the billows have reached, and how they churn as they rise.
    float rise = 1.0 - (0.25 + 0.75 * sqrt(p));
    vec2 q = vec2(uv.x * aspect * 2.5, uv.y * 2.0 + p * 0.8);
    float n = fbm(q + vec2(p * 0.6, 0.0));
    float body = smoothstep(rise - 0.1, rise + 0.25, uv.y + (n - 0.5) * 0.45);
    float thin = (1.0 - smoothstep(0.35, 1.0, p));
    float a = body * thin * (0.45 + 0.55 * n);
    vec3 c = ubuf.dustColor.rgb * (0.75 + 0.45 * n);
    fragColor = vec4(c * a, a) * 0.9 * ubuf.qt_Opacity;
}
