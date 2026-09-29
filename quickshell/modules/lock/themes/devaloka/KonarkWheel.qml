import QtQuick

// A sun wheel of Konark (shaders/konark.frag), the Devaloka clock's face:
// the stone wheel of Surya's chariot that is also a sundial, cast in the
// theme's gold. Noon at the top, the hours clockwise; its eight broad
// spokes mark the praharas, the one the hour is in is lit, and the beads
// between them light up three minutes at a time. The wheel fills the item;
// its glow spills a little past it.
Item {
    id: wheel

    // Local time, 0..24.
    property real hour: 12
    property real glow: 1

    ShaderEffect {
        anchors.centerIn: parent
        width: Math.min(wheel.width, wheel.height) * inset
        height: width

        property real inset: 1.1
        property real itemWidth: width
        property real itemHeight: height
        property real hour: wheel.hour
        property real glow: wheel.glow
        property color goldColor: Deva.gold
        property color pigmentColor: Deva.pigment
        property color groundColor: Deva.ground
        property color lightColor: Deva.amrita

        fragmentShader: Qt.resolvedUrl("../../../../shaders/konark.frag.qsb")
    }
}
