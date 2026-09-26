#version 440

// Static lock screen backdrop, drawn over the blurred wallpaper: a darkening
// tint, a vignette, a centred dot grid and faint scanlines. Everything is a
// pure function of position, so it only costs a quad on frames that are drawn
// anyway and never forces extra ones.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float gridSize;   // px between dots
    float dotAlpha;
    float scanAlpha;
    float tintAlpha;
    float vignette;   // 0..1
    vec4 tintColor;   // opaque
    vec4 dotColor;    // opaque
} ubuf;

// Premultiplied `over` of a flat colour with coverage a.
vec4 over(vec4 dst, vec3 rgb, float a) {
    return vec4(rgb * a + dst.rgb * (1.0 - a), a + dst.a * (1.0 - a));
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 px = qt_TexCoord0 * res;

    vec4 col = vec4(ubuf.tintColor.rgb * ubuf.tintAlpha, ubuf.tintAlpha);

    // Vignette, aspect corrected so it stays round on wide screens.
    vec2 uv = qt_TexCoord0 - 0.5;
    uv.x *= res.x / max(res.y, 1.0);
    float v = smoothstep(0.32, 1.0, length(uv)) * ubuf.vignette;
    col = over(col, vec3(0.0), v);

    // Scanlines: one dark row every 3 px.
    float scan = step(2.0, mod(px.y, 3.0)) * ubuf.scanAlpha;
    col = over(col, vec3(0.0), scan);

    // Dot grid centred on the screen, fading out towards the edges.
    vec2 g = mod(px - res * 0.5, ubuf.gridSize) - ubuf.gridSize * 0.5;
    float dotMask = 1.0 - smoothstep(0.55, 1.35, length(g));
    float fade = 1.0 - smoothstep(0.25, 0.85, length(uv));
    col = over(col, ubuf.dotColor.rgb, dotMask * ubuf.dotAlpha * fade);

    fragColor = col * ubuf.qt_Opacity;
}
