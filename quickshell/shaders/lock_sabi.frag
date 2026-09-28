#version 440

// Ageing transition for the "Ensō" lock theme (sabi: the beauty of age).
//
// As progress runs 0 -> 1 the captured desktop yellows like an old print
// along an uneven front, a tea-coloured stain gathers at its edge, and it
// fades away into the paper beneath. Run back from 1 to 0 it comes back from
// the paper. At progress 0 the capture passes through untouched.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float progress;
    vec4 paperColor;   // opaque
    vec4 stainColor;   // opaque
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
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = p * 2.03 + vec2(17.3, 9.1);
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 col = texture(source, uv);
    float p = ubuf.progress;
    if (p <= 0.0) {
        fragColor = col * ubuf.qt_Opacity;
        return;
    }

    float aspect = ubuf.itemWidth / max(ubuf.itemHeight, 1.0);
    float n = fbm(uv * vec2(aspect, 1.0) * 2.6) * 0.8 + fbm(uv * vec2(aspect, 1.0) * 9.0) * 0.2;
    float front = p * 1.45;
    float aged = smoothstep(n - 0.2, n + 0.05, front);
    float gone = smoothstep(n + 0.12, n + 0.3, front);

    // Yellowing towards sepia, and towards the paper.
    float lum = dot(col.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 sepia = vec3(lum) * vec3(1.08, 0.95, 0.76) * col.a;
    vec3 c = mix(col.rgb, sepia, aged * 0.9);
    c = mix(c, ubuf.paperColor.rgb * col.a, aged * 0.3);

    // A tea stain where it's about to go.
    float rim = smoothstep(0.0, 0.1, gone) * (1.0 - smoothstep(0.1, 0.45, gone));
    c = mix(c, ubuf.stainColor.rgb * col.a, rim * 0.55);

    float keep = 1.0 - gone;
    fragColor = vec4(c, col.a) * keep * ubuf.qt_Opacity;
}
