pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.components
import qs.modules.lock
import qs.modules.lock.themes.artdeco
import qs.services as Services

// Art Deco desktop theme, over the wallpaper, like a 1920s poster: a
// sunburst fanning up behind a skyline of setback towers, gold on their
// ledges and a few windows lit (desktop_deco shader), a stepped gilt frame
// under the bar, and a brass plaque bottom right with the floor you've
// risen to (the lock level) on an elevator dial. Static once drawn: the
// towers rise and the rays fan open as it switches on. See ThemeLayer.
Item {
    id: root

    property real boot: 1
    property date now: new Date()
    property real pxScale: 1

    readonly property real line: pxScale < 1 ? 1 / pxScale : 1
    readonly property int level: Services.LockStats.level
    readonly property int floorXp: Services.LockStats.xpForLevel(level)
    readonly property int ceilXp: Services.LockStats.xpForLevel(level + 1)
    readonly property real progress: Math.max(0, Math.min(1, (Services.LockStats.xp - floorXp) / Math.max(1, ceilXp - floorXp)))

    ShaderEffect {
        anchors.fill: parent
        opacity: Math.min(1, root.boot * 2)

        property real itemWidth: width
        property real itemHeight: height
        property real rise: LockTheme.seg(root.boot, 0, 0.9)
        property real lineScale: Math.min(2.5, 1 / root.pxScale)
        property color goldColor: Deco.gold
        property color jewelColor: Deco.jewel
        property color nightColor: Deco.lacquer

        fragmentShader: Qt.resolvedUrl("../../shaders/desktop_deco.frag.qsb")
    }

    // The gilt frame under the bar: a double rule stepped at the corners.
    DecoFrame {
        anchors.fill: undefined
        x: 14
        y: 44 + 8
        width: parent.width - 28
        height: parent.height - y - 14
        cut: 9
        steps: 2
        fill: "transparent"
        stroke: Deco.alpha(Deco.gold, 0.55)
        strokeWidth: root.line
        gap: 6
        innerStroke: Deco.alpha(Deco.gold, 0.22)
        opacity: LockTheme.seg(root.boot, 0.25, 0.85)
    }

    // The floor plaque, bottom right.
    Item {
        id: plaque

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 40
        anchors.bottomMargin: 36
        width: plaqueRow.implicitWidth + 44
        height: plaqueRow.implicitHeight + 28
        opacity: LockTheme.seg(root.boot, 0.45, 1)

        DecoFrame {
            cut: 5
            steps: 2
            fill: Deco.alpha(Deco.lacquer, 0.84)
            stroke: Deco.gold
            strokeWidth: root.line
            gap: 4
            innerStroke: Deco.alpha(Deco.gold, 0.35)
        }

        Row {
            id: plaqueRow
            anchors.centerIn: parent
            spacing: 18

            DecoDial {
                anchors.verticalCenter: parent.verticalCenter
                width: 74
                value: 0.08 + root.progress * 0.84
                ticks: 9
                line: Math.max(1, root.line)
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    text: "FLOOR " + root.level
                    font.family: Deco.display
                    font.pixelSize: 24
                    font.weight: Font.Bold
                    font.letterSpacing: 2
                    color: Deco.gold
                }

                Text {
                    text: Deco.floorName(root.level)
                    font.family: Deco.ui
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 3
                    color: Deco.ivory
                }

                Text {
                    text: (Quickshell.env("USER") || "guest").toUpperCase() + "  ·  " + Services.LockStats.xp.toLocaleString(Qt.locale(), "f", 0) + " PRESTIGE"
                    font.family: Deco.ui
                    font.pixelSize: 10
                    font.letterSpacing: 2
                    color: Deco.alpha(Deco.ivory, 0.6)
                }
            }
        }
    }
}
