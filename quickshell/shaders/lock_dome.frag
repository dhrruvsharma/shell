#version 440
// The "Astrolabe" lock's way in and out (modules/lock/themes/observatory):
// night falls on the desktop, darkening from the top with stars pricking out
// in its shadows, then the picture parts down the middle like the shutters
// of an observatory's dome, each half sliding away with a brass edge and
// the shadow of its thickness, showing the sky behind. Run backwards on the
// way out. At `progress` 0 it is exactly the desktop; at 1, transparent.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float progress;
    vec4 nightColor;
    vec4 brassColor;
} ubuf;

layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    float p = clamp(ubuf.progress, 0.0, 1.0);
    float dusk = smoothstep(0.0, 0.5, p);
    float open = smoothstep(0.38, 1.0, p);

    // The shutters: each half slides away from the middle.
    float gap = open * 0.56;
    float side = uv.x < 0.5 ? -1.0 : 1.0;
    float inSlit = step(abs(uv.x - 0.5), gap) * step(1e-4, gap);
    vec2 suv = vec2(clamp(uv.x - side * gap, 0.0, 1.0), uv.y);
    vec4 c = texture(source, suv);

    // Night falling from the top.
    float t = clamp(dusk * 1.5 - suv.y * 0.5, 0.0, 1.0);
    float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
    vec3 col = mix(c.rgb, c.rgb * 0.26 + ubuf.nightColor.rgb * 0.5, t * 0.85);
    // Stars in its shadows, fixed to the picture as it slides.
    vec2 g = suv * res / 7.0;
    vec2 cell = floor(g);
    float s = step(0.985, hash(cell)) * smoothstep(0.45, 0.0, length(fract(g) - 0.5));
    col += vec3(1.0, 0.96, 0.86) * s * t * (1.0 - smoothstep(0.2, 0.6, lum)) * 0.9;

    // As they roll round the dome the shutters turn from us and darken, and
    // their inner edges show a brass rim and the shadow of their thickness.
    float fromEdge = abs(abs(uv.x - 0.5) - gap) * res.x;
    float running = step(0.001, open) * (1.0 - inSlit);
    float shade = exp(-fromEdge / 60.0) * 0.55 * running;
    col *= 1.0 - open * 0.4;
    col *= 1.0 - shade;
    float rim = (1.0 - smoothstep(4.0, 6.0, fromEdge)) * running;
    col = mix(col, ubuf.brassColor.rgb * (0.8 + 0.3 * sin(uv.y * 80.0) * 0.3), rim);

    float alpha = 1.0 - inSlit;
    fragColor = vec4(col * alpha, alpha) * ubuf.qt_Opacity;
}
