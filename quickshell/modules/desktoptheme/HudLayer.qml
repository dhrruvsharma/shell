pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.colors
import qs.components
import qs.modules.lock
import qs.modules.lock.themes.arcade
import qs.services as Services

// HUD desktop theme, over the wallpaper: a dot grid and vignette (the arcade
// lock's backdrop shader), viewfinder brackets in the corners and the player
// readout bottom right. Static once drawn: the only motion is a scan sweeping
// down as it switches on. The clock is a desktop widget. See ThemeLayer.
Item {
    id: root

    property real boot: 1
    property date now: new Date()
    property real pxScale: 1

    readonly property color accent: Colors.primary

    ShaderEffect {
        anchors.fill: parent
        opacity: root.boot

        property real itemWidth: width * root.pxScale
        property real itemHeight: height * root.pxScale
        property real gridSize: 30 * root.pxScale * (root.pxScale < 1 ? 1.6 : 1)
        property real dotAlpha: 0.28
        property real scanAlpha: 0
        property real tintAlpha: 0.1
        property real vignette: 0.45
        property color tintColor: Colors.background
        property color dotColor: root.accent

        fragmentShader: Qt.resolvedUrl("../../shaders/lock_backdrop.frag.qsb")
    }

    // Brackets frame the area under the bar.
    HudCorners {
        x: 0
        y: 44
        width: parent.width
        height: parent.height - 44
        size: 42
        margin: 14
        thickness: root.pxScale < 1 ? 2 / root.pxScale : 2
        color: LockTheme.alpha(root.accent, 0.75)
        enter: LockTheme.seg(root.boot, 0.1, 0.8)
    }

    // Player readout, bottom right (lock screen progression).
    Column {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 36
        anchors.bottomMargin: 34
        spacing: 5
        opacity: LockTheme.seg(root.boot, 0.45, 1) * 0.85

        Text {
            anchors.right: parent.right
            text: (Quickshell.env("USER") || "player").toUpperCase() + "  ·  LV " + Services.LockStats.level + "  ·  " + Services.LockStats.rank
            font.family: LockTheme.mono
            font.pixelSize: 12
            font.weight: Font.Bold
            font.letterSpacing: 3
            color: root.accent
        }

        Row {
            id: xpRow
            anchors.right: parent.right
            spacing: 8

            readonly property int floorXp: Services.LockStats.xpForLevel(Services.LockStats.level)
            readonly property int ceilXp: Services.LockStats.xpForLevel(Services.LockStats.level + 1)

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 140
                height: 3
                color: LockTheme.alpha(Colors.on_surface, 0.15)

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, (Services.LockStats.xp - xpRow.floorXp) / Math.max(1, xpRow.ceilXp - xpRow.floorXp)))
                    height: parent.height
                    color: root.accent
                }
            }

            Text {
                text: Services.LockStats.xp.toLocaleString(Qt.locale(), "f", 0) + " XP"
                font.family: LockTheme.mono
                font.pixelSize: 11
                font.letterSpacing: 1.5
                color: LockTheme.alpha(Colors.on_surface, 0.7)
            }
        }
    }

    // Boot scan: a line of light sweeping down once.
    Rectangle {
        width: parent.width
        height: 90
        y: root.boot * (parent.height + height) - height
        visible: root.boot < 1
        opacity: 1 - root.boot
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.92; color: LockTheme.alpha(root.accent, 0.18) }
            GradientStop { position: 1; color: LockTheme.alpha(root.accent, 0.8) }
        }
    }
}
