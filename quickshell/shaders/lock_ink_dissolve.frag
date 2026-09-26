#version 440

// Ink dissolve for the "Sealed Cave Abode" lock theme.
//
// The captured desktop dissolves along an organic front spreading from
// `origin` (distance mixed with fbm noise) as progress runs 0 -> 1: ahead of
// the front the picture bleeds into ink, the front itself burns with a thin
// gold rim, and behind it the pixels are gone. `inward` flips the order so
// that, run back from 1 to 0, the desktop re-forms from the centre out.
// `desat` greys the intact picture towards an ink-wash tone. At progress 0 and
// desat 0 the capture passes through untouched.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float progress;
    float desat;
    float inward;
    vec2 origin;
    vec4 inkColor;   // opaque
    vec4 goldColor;  // opaque
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
        p = p * 2.07 + vec2(11.7, 3.9);
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 uv = qt_TexCoord0;
    vec4 col = texture(source, uv);

    if (ubuf.progress <= 0.0) {
        if (ubuf.desat > 0.0) {
            float lum = dot(col.rgb, vec3(0.2126, 0.7152, 0.0722));
            vec3 wash = mix(ubuf.inkColor.rgb * col.a, vec3(lum), 0.75);
            col.rgb = mix(col.rgb, wash, ubuf.desat);
        }
        fragColor = col * ubuf.qt_Opacity;
        return;
    }

    vec2 aspect = vec2(res.x / res.y, 1.0);
    vec2 o = ubuf.origin;
    float reach = length(max(o, 1.0 - o) * aspect);
    float d = length((uv - o) * aspect) / max(reach, 0.001);
    if (ubuf.inward > 0.5)
        d = 1.0 - d;
    float n = fbm(uv * vec2(res.x / res.y, 1.0) * 3.5);
    float v = clamp(d * 0.62 + n * 0.38, 0.0, 1.0);

    const float w = 0.1;
    float t = ubuf.progress * (1.0 + w) - w;
    if (v < t) {
        fragColor = vec4(0.0);
        return;
    }

    float lum = dot(col.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 wash = mix(ubuf.inkColor.rgb * col.a, vec3(lum), 0.75);
    col.rgb = mix(col.rgb, wash, ubuf.desat);

    // Near the front the picture bleeds into ink, with a burning gold rim.
    float k = (v - t) / w;
    if (k < 1.0) {
        col.rgb = mix(ubuf.inkColor.rgb * col.a, col.rgb, smoothstep(0.0, 1.0, k));
        float rim = 1.0 - smoothstep(0.0, 0.18, k);
        col.rgb = mix(col.rgb, ubuf.goldColor.rgb * col.a, rim * 0.9);
    }

    fragColor = col * ubuf.qt_Opacity;
}
