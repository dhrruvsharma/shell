import QtQuick

// One stroke of a sumi brush across the item, left to right: a wet blot
// where it comes down, ragged edges, and dry streaks where it lifts off
// (shaders/brush_stroke.frag). `reveal` draws it; `seed` makes each stroke
// its own. Sekiro's: under titles, through a spent resurrection node.
ShaderEffect {
    id: stroke

    property color ink: "black"
    property real seed: 1
    property real reveal: 1
    property real dry: 0.55
    property real weight: 0.78

    property real itemWidth: width
    property real itemHeight: height
    property color inkColor: ink

    fragmentShader: Qt.resolvedUrl("../shaders/brush_stroke.frag.qsb")
}
