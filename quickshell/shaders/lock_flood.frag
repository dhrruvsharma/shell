#version 440
// The "Bathysphere" lock's way in and out (modules/lock/themes/abyss): the
// desktop floods. The water rises from the bottom under a rippling
// meniscus, the picture beneath it swimming and losing its reds to the sea,
// bubbles on the way up; then everything sinks into the dark and the water
// becomes the view from the porthole. Run backwards, the sea drains away
// down the screen. At `progress` 0 it is exactly the desktop; at 1,
// transparent.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float progress;
    vec4 waterColor;
    vec4 glowColor;
} ubuf;

layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    float p = clamp(ubuf.progress, 0.0, 1.0);
    float px = 1.0 / res.y;
    float rise = smoothstep(0.0, 0.7, p);
    float sink = smoothstep(0.45, 1.0, p);
    float running = step(0.001, p);

    // The waterline.
    float level = 1.04 - rise * 1.12;
    float surf = level + 0.012 * sin(uv.x * 16.0 + p * 18.0) + 0.006 * sin(uv.x * 41.0 - p * 27.0);
    float under = smoothstep(surf - px, surf + px, uv.y);

    // Beneath it the picture swims and the sea takes its colour.
    vec2 swim = vec2(sin(uv.y * 34.0 + p * 22.0), cos(uv.x * 27.0 + p * 17.0)) * 0.006 * under * running;
    vec4 c = texture(source, clamp(uv + swim, 0.0, 1.0));
    float depth = max(0.0, uv.y - surf) * 1.5 + sink * 2.6;
    vec3 through = exp(-vec3(0.6, 0.18, 0.1) * depth * 1.6);
    vec3 wet = c.rgb * through * (1.0 - sink * 0.85)
        + ubuf.waterColor.rgb * (1.0 - exp(-depth * 0.9)) * (1.0 - sink * 0.55);
    vec3 col = mix(c.rgb, wet, under);

    // The meniscus, bright while it climbs.
    float line = exp(-abs(uv.y - surf) / (2.5 * px)) * running * (1.0 - sink);
    col = mix(col, vec3(0.86, 1.0, 1.0), line * 0.6);

    // Bubbles just under it, rising.
    vec2 g = vec2(uv.x * res.x / res.y, uv.y) * 30.0 + vec2(0.0, p * 9.0);
    vec2 f = fract(g) - 0.5;
    float bub = step(0.92, hash(floor(g))) * smoothstep(0.05, 0.0, abs(length(f) - 0.2));
    col += mix(ubuf.glowColor.rgb, vec3(1.0), 0.5) * bub * under * smoothstep(0.3, 0.0, uv.y - surf) * 0.45 * running;

    // At the end the water becomes the scene behind.
    float alpha = 1.0 - smoothstep(0.78, 1.0, p);
    fragColor = vec4(col * alpha, alpha) * ubuf.qt_Opacity;
}
