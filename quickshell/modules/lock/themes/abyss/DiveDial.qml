pragma ComponentBehavior: Bound
import QtQuick

// A diver's watch (shaders/dive_dial.frag), the Abyss theme's mark: a
// ceramic bezel for the minutes of a dive, a wave-engraved dial and hands
// and markers filled with lume, glowing in the dark. The desktop clock
// tells the time on it; the Bathysphere lock turns the bezel to the start
// of the dive.
Item {
    id: dial

    property real hour: 0
    property real minute: 0
    property real bezel: 0
    property real glow: 1
    // Printed on the dial: a line under twelve and one over six.
    property string upper: "ABYSS"
    property string lower: ""

    readonly property real radius: Math.min(width, height) / 2

    ShaderEffect {
        anchors.centerIn: parent
        width: dial.radius * 2 * 1.08
        height: width

        property real itemWidth: width
        property real itemHeight: height
        property real hour: dial.hour
        property real minute: dial.minute
        property real bezel: dial.bezel
        property real glow: dial.glow
        property color lumeColor: Deep.lume
        property color dialColor: Qt.tint(Deep.water, Deep.alpha(Deep.glow, 0.12))
        property color bezelColor: "#0d1418"
        property color metalColor: "#aebfc6"

        fragmentShader: Qt.resolvedUrl("../../../../shaders/dive_dial.frag.qsb")
    }

    // The bezel's tens.
    Repeater {
        model: [10, 20, 30, 40, 50]

        Text {
            required property int modelData
            readonly property real a: (modelData / 60 * 360 + dial.bezel) * Math.PI / 180
            readonly property real r: dial.radius * 0.9
            x: dial.width / 2 + Math.sin(a) * r - width / 2
            y: dial.height / 2 - Math.cos(a) * r - height / 2
            rotation: modelData / 60 * 360 + dial.bezel + (modelData > 15 && modelData < 45 ? 180 : 0)
            text: modelData
            font.family: Deep.display
            font.pixelSize: dial.radius * 0.1
            color: "#c9d6db"
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: dial.height / 2 - dial.radius * 0.42
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: dial.upper
            font.family: Deep.display
            font.pixelSize: dial.radius * 0.085
            font.letterSpacing: dial.radius * 0.012
            color: Deep.alpha(Deep.foam, 0.85)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "BATHYSPHERE"
            font.family: Deep.ui
            font.pixelSize: dial.radius * 0.05
            font.letterSpacing: dial.radius * 0.01
            color: Deep.alpha(Deep.lume, 0.8)
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: dial.height / 2 + dial.radius * 0.26
        visible: dial.lower.length > 0
        text: dial.lower
        font.family: Deep.mono
        font.pixelSize: dial.radius * 0.075
        color: Deep.glow
    }
}
