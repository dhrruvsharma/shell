import QtQuick

// An ensō brushstroke (shaders/enso.frag), Wabi-sabi's mark: drawn whole on
// the clock widget, a keystroke at a time on the "Ensō" lock screen, which
// also cracks it and mends it with gold. The circle sits in the middle of the
// item with a radius of 0.4 × its smaller side, leaving room for the wander.
ShaderEffect {
    property real sweep: 0.92
    // Where the brush lands, in turns clockwise from twelve o'clock.
    property real start: 0.62
    property real thickness: 0.16
    property real ghost: 0
    property real bleed: 0
    property real cracks: 0
    property real gold: 0
    property real seed: 3.7
    property vector4d crackAt: Qt.vector4d(0.2, 0.45, 0.68, 0.86)
    property color inkColor: Wabi.sumi
    property color goldColor: Wabi.gold

    readonly property real itemWidth: width
    readonly property real itemHeight: height

    fragmentShader: Qt.resolvedUrl("../../../../shaders/enso.frag.qsb")
}
