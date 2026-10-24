pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.lock.themes.wabisabi

// Wabi-sabi's wheel: a round sheet of washi with one ensō brushed on it,
// cracked once and mended in gold, turning with the apps. The pointer is
// a seal stamped in vermilion at the paper's edge, and a seam of gold from
// it to the chosen app's name.
Item {
    id: face

    required property LauncherDial dial

    readonly property real r: dial.radius
    readonly property color paper: "#ece4d3"

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
            color: face.paper
            border.width: 1
            border.color: "#b8ab90"

            // The deckle edge: a darker band of the paper's own fibre.
            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: width / 2
                color: "transparent"
                border.width: 6
                border.color: Colors.withAlpha("#c9bc9f", 0.5)
            }
        }

        Enso {
            anchors.fill: parent
            sweep: 0.9
            start: 0.35
            thickness: 0.12
            seed: 4.1
            cracks: 2
            gold: 1
            inkColor: Wabi.sumi
            goldColor: Wabi.gold
        }
    }

    // The seal.
    Rectangle {
        x: face.dial.cx + face.r - width - 10
        y: face.dial.cy - height / 2
        width: 30
        height: 30
        radius: 3
        rotation: -4
        color: "#b8382a"

        Text {
            anchors.centerIn: parent
            text: "選"
            font.family: "Noto Serif CJK JP"
            font.pixelSize: 19
            font.weight: Font.Bold
            color: face.paper
        }
    }

    // The seam of gold.
    Rectangle {
        x: face.dial.cx + face.r + 6
        y: face.dial.cy - height / 2
        width: Math.max(0, face.dial.nameX - 26 - x)
        height: 2
        radius: 1
        opacity: face.dial.nameShown
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Wabi.gold }
            GradientStop { position: 1; color: Colors.withAlpha(Wabi.gold, 0.4) }
        }
    }
}
