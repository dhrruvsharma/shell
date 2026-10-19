#version 440
// The grabbed desktop graded into a power menu scene's setting
// (modules/power): drained of colour, darkened and given more or less
// contrast, mapped onto a duotone (its darks to one colour, its lights to
// another: a noir split-tone, dusk, lamplight), washed with a tint, and
// finished with a vignette, scanlines and grain. `amount` takes it there
// from the desktop as it was (0). Opaque.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float amount;      // 0..1
    float saturation;  // colour kept, 0..1
    float brightness;  // multiplier
    float contrast;    // 1 = as is
    float duo;         // 0..1 how far onto the duotone
    float tint;        // 0..1
    float vignette;    // 0..1
    float scan;        // 0..1 scanline strength
    float scanPx;      // px from one scanline to the next
    float grain;       // 0..1
    float time;        // seconds (moves the grain)
    vec4 shadowColor;  // the duotone's darks
    vec4 lightColor;   // and lights
    vec4 tintColor;
} ubuf;

layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * res;
    vec3 src = texture(source, uv).rgb;

    float lum = dot(src, vec3(0.299, 0.587, 0.114));
    vec3 col = mix(vec3(lum), src, ubuf.saturation);
    col = (col - 0.5) * ubuf.contrast + 0.5;
    col = max(col, 0.0) * ubuf.brightness;
    vec3 duo = mix(ubuf.shadowColor.rgb, ubuf.lightColor.rgb, smoothstep(0.0, 1.0, lum));
    col = mix(col, duo * ubuf.brightness, ubuf.duo);
    col = mix(col, ubuf.tintColor.rgb, ubuf.tint);

    vec2 c = uv - 0.5;
    c.x *= res.x / max(res.y, 1.0);
    col *= 1.0 - ubuf.vignette * smoothstep(0.3, 1.05, length(c));

    if (ubuf.scan > 0.0) {
        float s = 0.5 + 0.5 * cos(px.y * 6.2831853 / max(1.0, ubuf.scanPx));
        col *= 1.0 - ubuf.scan * 0.55 * s;
    }
    if (ubuf.grain > 0.0)
        col += (hash(floor(px) + fract(ubuf.time * 7.3) * 91.0) - 0.5) * ubuf.grain * 0.09;

    fragColor = vec4(mix(src, col, ubuf.amount), 1.0) * ubuf.qt_Opacity;
}
