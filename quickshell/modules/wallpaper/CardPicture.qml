import QtQuick

// A picture in the wallpaper picker drawn from a texture: the preview's own
// image, or a ShaderEffectSource of the video playing in it. It fills the
// item the way Image.PreserveAspectCrop does, with rounded corners, and a
// band of light can sweep across it (shaders/card_picture.frag).
ShaderEffect {
    id: picture

    // The texture (an Image or a ShaderEffectSource), and its width over
    // its height.
    property var source
    property real sourceAspect: 1
    // Corner radius, in the item's own units.
    property real radius: 0
    // Screen pixels to one unit (the scale it's drawn at), for smooth edges.
    property real pixelScale: 1
    // Where the band of light is, 0..1 across; none outside about -0.3..1.3.
    property real shine: -1

    readonly property real aspect: width / Math.max(1, height)
    // The middle of the texture, cut to the item's shape.
    readonly property vector4d crop: aspect > sourceAspect
        ? Qt.vector4d(0, (1 - sourceAspect / aspect) / 2, 1, sourceAspect / aspect)
        : Qt.vector4d((1 - aspect / sourceAspect) / 2, 0, aspect / sourceAspect, 1)
    readonly property vector2d pixels: Qt.vector2d(width * pixelScale, height * pixelScale)
    readonly property real radiusPx: radius * pixelScale

    fragmentShader: Qt.resolvedUrl("../../shaders/card_picture.frag.qsb")
}
