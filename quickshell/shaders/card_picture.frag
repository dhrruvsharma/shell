#version 440
// A picture in the wallpaper picker (modules/wallpaper/CardPicture.qml): a
// texture cropped to fill the item the way Image.PreserveAspectCrop does,
// with rounded corners, and a band of light that can sweep across it.
//
// Compile: /usr/lib/qt6/bin/qsb --qt6 -o card_picture.frag.qsb card_picture.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // The part of the texture shown: x, y, width, height, in 0..1.
    vec4 crop;
    // The item's size on screen and its corner radius, in pixels.
    vec2 pixels;
    float radiusPx;
    // Where the band of light is, 0..1 across the picture (none outside
    // about -0.3..1.3).
    float shine;
};

layout(binding = 1) uniform sampler2D source;

void main()
{
    vec4 c = texture(source, crop.xy + qt_TexCoord0 * crop.zw);

    // Rounded corners: the distance to the rounded rectangle's edge, in
    // pixels, gives a one-pixel soft edge at any size.
    vec2 halfSize = 0.5 * pixels;
    float r = min(radiusPx, min(halfSize.x, halfSize.y));
    vec2 q = abs((qt_TexCoord0 - 0.5) * pixels) - (halfSize - r);
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
    float inside = clamp(0.5 - d, 0.0, 1.0);

    // The light: a slanted band, a bright core in a wider glow, sweeping
    // left to right as `shine` goes from 0 to 1.
    vec2 p = qt_TexCoord0 * pixels;
    float t = (p.x + 0.45 * p.y) / (pixels.x + 0.45 * pixels.y) - shine;
    // (pow() is undefined for a negative base: square by hand.)
    float core = t * 11.0;
    float halo = t * 3.5;
    float band = 0.34 * exp(-core * core) + 0.08 * exp(-halo * halo);
    c.rgb += c.a * band;

    fragColor = c * inside * qt_Opacity;
}
