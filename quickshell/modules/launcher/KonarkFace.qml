pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.components
import qs.modules.lock.themes.devaloka

// Devaloka's wheel: a sun wheel of Konark, the stone wheel of Surya's
// chariot that tells the hours, cast in gold, the prahara of this hour lit,
// turning with the apps. A lotus at its rim points along a thread of gold
// to the chosen app's name, and a temple border stands under the name.
Item {
    id: face

    required property LauncherDial dial

    readonly property real r: dial.radius
    readonly property date now: new Date()

    KonarkWheel {
        x: face.dial.cx - face.r
        y: face.dial.cy - face.r
        width: face.r * 2
        height: width
        rotation: face.dial.turn
        hour: face.now.getHours() + face.now.getMinutes() / 60
    }

    // The thread of gold, and the lotus it springs from.
    Rectangle {
        x: face.dial.cx + face.r + 18
        y: face.dial.cy - 1
        width: Math.max(0, face.dial.nameX - 20 - x)
        height: 2
        opacity: face.dial.nameShown
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Deva.goldHi }
            GradientStop { position: 1; color: Colors.withAlpha(Deva.gold, 0.5) }
        }

        Rectangle {
            x: parent.width - 4
            y: parent.height / 2 - 4
            width: 8
            height: 8
            radius: 4
            rotation: 45
            color: Deva.goldHi
        }
    }

    Lotus {
        x: face.dial.cx + face.r - 8
        y: face.dial.cy - height / 2
        width: 34
        height: 22
        rotation: 90
        opacity: face.dial.nameShown
        stroke: Deva.goldHi
        fill: Colors.withAlpha(Deva.gold, 0.45)
    }

    TempleBorder {
        x: face.dial.nameX
        y: face.dial.nameY + face.dial.nameHeight - 2
        width: Math.max(60, face.dial.nameWidth)
        height: 6
        step: 8
        visible: face.dial.app !== null
        opacity: face.dial.nameShown
        color: Colors.withAlpha(Deva.gold, 0.7)
    }
}
