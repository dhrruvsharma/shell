pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.colors
import qs.modules.lock.themes.gothic

// The Cathedral's wheel: a rose window, glazed in the wallpaper's colours,
// in a ring of dark stone, turning with the apps. The pointer is a gilded
// rod laid from the tracery to the chosen app's name, a quatrefoil at its
// root.
Item {
    id: face

    required property LauncherDial dial

    readonly property real r: dial.radius
    readonly property color gilt: dial.accent

    Item {
        id: disc
        x: face.dial.cx - face.r
        y: face.dial.cy - face.r
        width: face.r * 2
        height: width
        rotation: face.dial.turn

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "#141210"
            border.width: 2
            border.color: "#060505"
        }

        RoseWindow {
            anchors.fill: parent
            anchors.margins: face.r * 0.06
        }

        // The stone ring's moulding.
        Rectangle {
            anchors.fill: parent
            anchors.margins: face.r * 0.035
            radius: width / 2
            color: "transparent"
            border.width: 1.5
            border.color: Colors.withAlpha(face.gilt, 0.45)
        }
    }

    // The quatrefoil, and the rod.
    Rectangle {
        x: face.dial.cx + face.r + 2
        y: face.dial.cy - height / 2
        width: Math.max(0, face.dial.nameX - 24 - x)
        height: 3
        radius: 1.5
        opacity: face.dial.nameShown
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.lighter(face.gilt, 1.3) }
            GradientStop { position: 1; color: Qt.darker(face.gilt, 1.5) }
        }

        Text {
            x: parent.width - 4
            anchors.verticalCenter: parent.verticalCenter
            text: "✠"
            font.pixelSize: 20
            color: face.gilt
        }
    }

    Repeater {
        model: 4

        Rectangle {
            required property int index
            readonly property real a: index * Math.PI / 2
            x: face.dial.cx + face.r + 2 + Math.cos(a) * 7 - width / 2
            y: face.dial.cy + Math.sin(a) * 7 - height / 2
            width: 12
            height: 12
            radius: 6
            color: Qt.darker(face.gilt, 1.2)
            border.width: 1
            border.color: "#060505"
        }
    }
}
