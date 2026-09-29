import QtQuick

// A disc of the sky (shaders/orb.frag): the Moon in its phase, or, with
// `eclipse`, the Sun with the Moon drawing across it (`cover` 0 clear .. 1
// total, the corona out). The disc fills 62% of the item; the rest is for
// its glow.
ShaderEffect {
    property bool eclipse: false
    property real illum: 1
    property bool waxing: true
    property real cover: 0
    property real glow: 1
    property color lightColor: eclipse ? Sky.lamp : "#efe6cc"
    property color darkColor: eclipse ? "#0b0b10" : "#1b2130"
    property color coronaColor: "#f4f1ff"

    readonly property real mode: eclipse ? 1 : 0
    // Which side is lit: the right while waxing (seen from the north).
    readonly property real side: (waxing ? 1 : -1) * (Sky.site.lat >= 0 ? 1 : -1)

    fragmentShader: Qt.resolvedUrl("../../../../shaders/orb.frag.qsb")
}
