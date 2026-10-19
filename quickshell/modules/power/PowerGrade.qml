import QtQuick

// The grabbed desktop graded into a scene's setting (shaders/
// power_grade.frag): set what the scene wants and leave the rest. Without a
// grab it fades in as a plain wash over the live desktop instead.
ShaderEffect {
    id: grade

    required property var menu

    property real amount: 1
    property real saturation: 1
    property real brightness: 1
    property real contrast: 1
    property real duo: 0
    property real tint: 0
    property real vignette: 0
    property real scan: 0
    property real scanPx: 3
    property real grain: 0
    property real time: menu.time
    property color shadowColor: "black"
    property color lightColor: "white"
    property color tintColor: "black"

    readonly property variant source: menu.world
    readonly property real itemWidth: width
    readonly property real itemHeight: height

    anchors.fill: parent
    opacity: menu.hasWorld ? 1 : amount
    fragmentShader: Qt.resolvedUrl("../../shaders/power_grade.frag.qsb")
}
