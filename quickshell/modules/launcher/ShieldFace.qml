pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.lock.themes.siege

// Siege's wheel: a war shield, painted gyronny in your tincture inside its
// riveted steel rim, turning with the apps. Its sword and spear stay aimed
// at three o'clock; a longsword is laid out from the rim, point first, at
// the chosen app's name.
Item {
    id: face

    required property LauncherDial dial

    readonly property real r: dial.radius
    // Where the hands point in the shield's own frame, in degrees from
    // twelve: three o'clock on the screen, whatever its turn.
    readonly property real aim: ((90 - dial.turn) % 360 + 360) % 360

    Buckler {
        x: face.dial.cx - face.r
        y: face.dial.cy - face.r
        width: face.r * 2
        height: width
        rotation: face.dial.turn
        minute: face.aim / 6
        hour: face.aim * 11 / 360
    }

    // The longsword: pommel over the rim, blade under the chosen app, point
    // at its name. (It stands point up; a quarter turn lays it pointing
    // right.)
    Sword {
        readonly property real from: face.dial.cx + face.r - 40
        readonly property real len: Math.max(120, face.dial.nameX - 22 - from)
        x: from + len / 2 - width / 2
        y: face.dial.cy - height / 2
        width: Math.round(len * 0.16)
        height: len
        rotation: 90
        opacity: face.dial.nameShown
    }
}
