import QtQuick

// A treasure of the churning (shaders/ratna.frag): a gem in a gold collet,
// lit, twinkling, or spoiled by the poison. The gem fills 62% of the item;
// the rest is for its halo.
ShaderEffect {
    property color gem: "#e8374b"
    property real lit: 1
    property real twinkle: 0
    property real spoil: 0

    property real itemWidth: width
    property color gemColor: gem
    property color goldColor: Deva.gold
    property color poisonColor: Deva.poison

    fragmentShader: Qt.resolvedUrl("../../../../shaders/ratna.frag.qsb")
}
