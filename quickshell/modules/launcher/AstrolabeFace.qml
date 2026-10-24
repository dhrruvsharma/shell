pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.lock.themes.observatory

// The Observatory's wheel: an astrolabe engraved for your latitude. The
// plate stays put while the rete, set to the sky of this moment, turns with
// the apps; the rule lies at three o'clock across the chosen one, and a
// brass sight runs on from the limb to its name.
Item {
    id: face

    required property LauncherDial dial

    readonly property real r: dial.radius
    readonly property real lst: Sky.lst(new Date())

    Astrolabe {
        x: face.dial.cx - face.r
        y: face.dial.cy - face.r
        width: face.r * 2
        height: width
        rete: face.lst + face.dial.turn
        rule: 90
        starNames: true
    }

    // The sight: a brass bar from the limb to the name, a vane at its end.
    Rectangle {
        x: face.dial.cx + face.r - 2
        y: face.dial.cy - height / 2
        width: Math.max(0, face.dial.nameX - 26 - x)
        height: 4
        opacity: face.dial.nameShown
        border.width: 0.5
        border.color: Sky.alpha(Sky.brassDeep, 0.9)
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.lighter(Sky.brass, 1.25) }
            GradientStop { position: 1; color: Sky.brassDeep }
        }

        Rectangle {
            x: parent.width - width
            y: parent.height / 2 - height / 2
            width: 5
            height: 22
            radius: 1
            color: Sky.brass
            border.width: 0.5
            border.color: Sky.brassDeep

            Rectangle {
                anchors.centerIn: parent
                width: 1.5
                height: 8
                color: Colors.withAlpha("black", 0.7)
            }
        }
    }
}
