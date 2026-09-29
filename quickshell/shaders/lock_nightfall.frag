#version 440
// The desktop at nightfall behind the "Portcullis" lock screen's gate
// (modules/lock/themes/siege/SiegeSurface.qml): as `night` runs 0 -> 1 the
// capture darkens to a moonlit blue, the torches on the jambs throw a warm
// light across what's near them, and the corners sink into the dark. At 0
// it is the capture exactly. No time in it: it's drawn again only while
// `night` or `light` changes.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float night;
    float light;       // how bright the torches burn (a grant flares them)
    float reach;       // px
    vec2 torchA;       // px
    vec2 torchB;
    vec4 moonColor;
    vec4 fireColor;
} ubuf;

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 c = texture(source, uv);
    vec2 px = uv * vec2(ubuf.itemWidth, ubuf.itemHeight);
    float lum = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));

    vec3 n = mix(c.rgb, vec3(lum) * ubuf.moonColor.rgb * 1.1, 0.62) * 0.38;
    float warm = exp(-pow(length(px - ubuf.torchA) / ubuf.reach, 2.0))
               + exp(-pow(length(px - ubuf.torchB) / ubuf.reach, 2.0));
    n += c.rgb * ubuf.fireColor.rgb * warm * 0.55 * ubuf.light;
    vec2 d = uv - 0.5;
    n *= 1.0 - smoothstep(0.32, 0.9, length(d * vec2(1.0, 1.25))) * 0.6;

    fragColor = vec4(mix(c.rgb, n, clamp(ubuf.night, 0.0, 1.0)), 1.0) * ubuf.qt_Opacity;
}
