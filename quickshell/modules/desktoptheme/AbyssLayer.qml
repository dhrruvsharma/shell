pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import qs.modules.lock
import qs.modules.lock.themes.abyss
import qs.services as Services

// Abyss desktop theme: the wallpaper sunk under the sea (desktop_abyss
// shader; `wallpaper` is a texture of what's under the layer), as deep as
// the hour: the sunlit shallows with caustics and shafts of light at noon,
// down through the twilight to the dark of the trenches at midnight, where
// only the bioluminescence and the marine snow show. Bottom right, the
// boat's depth gauge: the hour's depth and zone on a gauge of the five
// zones, the water's temperature and pressure, and your place in the crew
// (the lock level; XP as leagues logged). The water rises over the
// wallpaper as it switches on, and the depth moves once a minute. See
// ThemeLayer.
Item {
    id: root

    property real boot: 1
    property date now: new Date()
    property real pxScale: 1
    property Item wallpaper: null

    readonly property real line: pxScale < 1 ? 1 / pxScale : 1
    readonly property real metres: Deep.depthAt(now)
    readonly property var zone: Deep.zoneAt(metres)
    readonly property int level: Services.LockStats.level
    readonly property int floorXp: Services.LockStats.xpForLevel(level)
    readonly property int ceilXp: Services.LockStats.xpForLevel(level + 1)
    readonly property real progress: Math.max(0, Math.min(1, (Services.LockStats.xp - floorXp) / Math.max(1, ceilXp - floorXp)))

    ShaderEffect {
        anchors.fill: parent
        visible: root.wallpaper !== null

        property variant source: root.wallpaper
        property real itemWidth: width
        property real itemHeight: height
        property real depth: Deep.shade(root.metres)
        property real flood: LockTheme.seg(root.boot, 0, 0.9)
        property real lineScale: Math.min(2.5, root.line)
        property color glowColor: Deep.glow
        property color lumeColor: Deep.lume
        property color waterColor: Deep.water
        property color sunColor: "#d9f4ee"

        fragmentShader: Qt.resolvedUrl("../../shaders/desktop_abyss.frag.qsb")
    }

    // The depth gauge, bottom right.
    Item {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 40
        anchors.bottomMargin: 36
        width: gaugeRow.implicitWidth + 40
        height: gaugeRow.implicitHeight + 28
        opacity: LockTheme.seg(root.boot, 0.5, 1)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.6
            shadowBlur: 0.7
            blurMax: 24
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 3
        }

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: Deep.alpha(Deep.glass, 0.82)
            border.width: root.line
            border.color: Deep.alpha(Deep.lume, 0.4)

            // The glass face, catching the light along its top.
            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 14
                gradient: Gradient {
                    GradientStop { position: 0; color: Deep.alpha(Deep.foam, 0.07) }
                    GradientStop { position: 0.35; color: "transparent" }
                }
            }
        }

        Row {
            id: gaugeRow
            anchors.centerIn: parent
            spacing: 16

            ZoneGauge {
                anchors.verticalCenter: parent.verticalCenter
                height: info.implicitHeight
                metres: root.metres
            }

            Column {
                id: info
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Text {
                    text: "−" + Deep.metres(root.metres)
                    font.family: Deep.display
                    font.pixelSize: 22
                    color: Deep.lume
                }

                Text {
                    text: (root.zone.name + "  ·  " + root.zone.latin).toUpperCase()
                    font.family: Deep.ui
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.letterSpacing: 2
                    color: Deep.glow
                }

                Text {
                    text: Deep.temperature(root.metres).toFixed(1) + " °C  ·  " + Math.round(Deep.pressure(root.metres)) + " ATM  ·  " + Qt.formatTime(root.now, "HH:mm")
                    font.family: Deep.mono
                    font.pixelSize: 12
                    color: Deep.alpha(Deep.foam, 0.72)
                }

                Item {
                    width: 1
                    height: 4
                }

                Text {
                    text: (Deep.rank(root.level) + "  ·  " + (Quickshell.env("USER") || "crew")).toUpperCase()
                    font.family: Deep.ui
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                    color: Deep.foam
                }

                Row {
                    spacing: 10

                    // Progress to the next rank, lit cell by cell.
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Repeater {
                            model: 16

                            Rectangle {
                                required property int index
                                readonly property bool lit: (index + 0.5) / 16 <= root.progress
                                width: 7
                                height: 7
                                radius: 3.5
                                color: lit ? Deep.lume : "transparent"
                                border.width: 1
                                border.color: Deep.alpha(Deep.lume, lit ? 1 : 0.35)
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Deep.count(Services.LockStats.xp) + " LEAGUES"
                        font.family: Deep.mono
                        font.pixelSize: 11
                        color: Deep.alpha(Deep.foam, 0.62)
                    }
                }
            }
        }
    }
}
