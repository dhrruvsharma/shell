pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import qs.components
import qs.modules.desktoptheme
import qs.modules.lock
import qs.modules.lock.themes.wasteland
import qs.services as Services

// Wasteland desktop theme, over the wallpaper: a sky thick with dust, grit,
// rust and grime creeping in from the edges and hazard tape across the
// bottom-left corner (desktop_dust shader), and bottom right a scrap plate
// with your survivor's tag: the lock level as how far you've come on the
// road, XP as scrap, and the days without incident (the unlock streak).
// Static once drawn: the dust blows in from the left as it switches on. See
// ThemeLayer.
Item {
    id: root

    property real boot: 1
    property date now: new Date()
    property real pxScale: 1

    readonly property int level: Services.LockStats.level
    readonly property int floorXp: Services.LockStats.xpForLevel(level)
    readonly property int ceilXp: Services.LockStats.xpForLevel(level + 1)
    readonly property real progress: Math.max(0, Math.min(1, (Services.LockStats.xp - floorXp) / Math.max(1, ceilXp - floorXp)))

    ShaderEffect {
        anchors.fill: parent

        property real itemWidth: width
        property real itemHeight: height
        property real storm: LockTheme.seg(root.boot, 0, 1)
        property real lineScale: Math.min(2.5, 1 / root.pxScale)
        property color dustColor: Waste.dust
        property color rustColor: Waste.rust
        property color hazardColor: Waste.hazard
        property color grimeColor: Waste.grime

        fragmentShader: Qt.resolvedUrl("../../shaders/desktop_dust.frag.qsb")
    }

    // The survivor's tag, bottom right.
    Item {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 40
        anchors.bottomMargin: 36
        width: tag.implicitWidth + 44
        height: tag.implicitHeight + 30
        opacity: LockTheme.seg(root.boot, 0.5, 1)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.6
            shadowBlur: 0.5
            blurMax: 16
            shadowHorizontalOffset: 2
            shadowVerticalOffset: 3
        }

        ScrapPlate {
            anchors.fill: parent
            seed: 4
            rivetSize: 5
            rivetInset: 7
        }

        Column {
            id: tag
            anchors.centerIn: parent
            spacing: 4

            Text {
                text: Waste.rank(root.level) + "  ·  " + (Quickshell.env("USER") || "survivor").toUpperCase()
                font.family: Waste.stencil
                font.pixelSize: 19
                font.weight: Font.Bold
                font.letterSpacing: 1
                color: Waste.bone
            }

            Text {
                text: "DAY " + Clocks.dayOfYear(root.now) + "  ·  " + Services.LockStats.liveStreak + " DAYS WITHOUT INCIDENT"
                font.family: Waste.stencilCond
                font.pixelSize: 14
                font.weight: Font.Bold
                font.letterSpacing: 1.5
                color: Waste.hazard
            }

            Row {
                spacing: 8

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 150
                    height: 8

                    Rectangle {
                        anchors.fill: parent
                        color: Waste.grime
                        border.width: 1
                        border.color: Waste.steelHi
                    }

                    HazardStripes {
                        x: 1
                        y: 1
                        width: (parent.width - 2) * root.progress
                        height: parent.height - 2
                        stripe: 4
                        colorA: Waste.hazard
                        colorB: Waste.grime
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Waste.count(Services.LockStats.xp) + " SCRAP"
                    font.family: Waste.cond
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                    color: Waste.alpha(Waste.bone, 0.75)
                }
            }
        }
    }
}
