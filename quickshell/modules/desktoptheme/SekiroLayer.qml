pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.components
import qs.modules.lock
import qs.modules.lock.themes.sekiro
import qs.services as Services

// Sekiro desktop theme, over the wallpaper: the season falling on Ashina
// caught in mid-air round the edges (sakura, fireflies, maple leaves or
// snow by the month) with a low mist along the foot
// (shaders/desktop_sekiro.frag); bottom left, out of the wallpaper's way,
// the shinobi's HUD as the game draws it: two resurrection nodes over the
// vitality gauge, here your battery (the second node is charged while you
// rest at the idol, plugged in); bottom right, the name of the area the
// shinobi is in at this hour, brushed under in crimson, with the
// Sculptor's Idol he rests at there, what's happening, the season, and
// your rank on the shinobi's path. It changes once a minute. See
// ThemeLayer.
Item {
    id: root

    property real boot: 1
    property date now: new Date()
    property real pxScale: 1

    readonly property real line: pxScale < 1 ? 1 / pxScale : 1
    readonly property var stretch: Shinobi.stretch(now)
    readonly property var season: Shinobi.season(now)
    readonly property var tints: [["#f7cbd6", "#e98aa8"], ["#e4ff9a", "#fff4bf"], ["#de5a2c", "#a3221a"], ["#f4f7fb", "#c9d3e2"]][season.fall]

    // Vitality: your battery (full where there is none).
    readonly property bool hasBattery: Services.Battery.percentage > 0 || Services.Battery.charging
    readonly property real vitality: hasBattery ? Math.max(0, Math.min(1, Services.Battery.percentage / 100)) : 1
    readonly property bool resting: !hasBattery || Services.Battery.charging || Services.Battery.full

    ShaderEffect {
        anchors.fill: parent

        property real itemWidth: width
        property real itemHeight: height
        property real boot: root.boot
        property real lineScale: root.line
        property real fall: root.season.fall
        property real drift: 0
        property real chrome: 1
        property real unit: 1
        property color mistColor: "#aab4c4"
        property color tintA: root.tints[0]
        property color tintB: root.tints[1]

        fragmentShader: Qt.resolvedUrl("../../shaders/desktop_sekiro.frag.qsb")
    }

    // ── The shinobi's HUD, bottom left ──────────────────────────────────
    Item {
        id: hud
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 44 + Services.BarLayout.reserveLeft
        anchors.bottomMargin: 50 + Services.BarLayout.reserveBottom
        width: 360
        height: hudColumn.implicitHeight
        opacity: LockTheme.seg(root.boot, 0.3, 0.85)
        transform: Translate { x: -(1 - LockTheme.seg(root.boot, 0.3, 0.85)) * 24 }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.8
            shadowBlur: 0.55
            blurMax: 18
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 2
        }

        Column {
            id: hudColumn
            spacing: 7

            Row {
                spacing: 6

                ResurrectionNode {
                    width: 34
                    height: 34
                    emblem: 0
                    rose: Shinobi.node
                    roseGlow: Shinobi.nodeGlow
                }

                ResurrectionNode {
                    width: 34
                    height: 34
                    emblem: 1
                    lit: root.resting
                    struck: !root.resting
                    seed: 2
                    rose: Shinobi.node
                    roseGlow: Shinobi.nodeGlow
                }
            }

            // The vitality gauge: a dark channel with steel caps, filled in
            // copper (red, and running out, when the battery is low).
            Item {
                id: vit
                width: 320
                height: 12

                readonly property bool low: root.hasBattery && root.vitality <= 0.2 && !Services.Battery.charging

                Rectangle {
                    x: 3
                    width: parent.width - 6
                    height: parent.height
                    color: Shinobi.alpha("black", 0.6)
                    border.width: 1
                    border.color: Shinobi.alpha(Shinobi.steel, 0.35)

                    Rectangle {
                        x: 2
                        y: 2
                        width: Math.max(0, (parent.width - 4) * root.vitality)
                        height: parent.height - 4
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.lighter(vit.low ? Shinobi.vitalityLow : Shinobi.vitality, 1.25) }
                            GradientStop { position: 0.5; color: vit.low ? Shinobi.vitalityLow : Shinobi.vitality }
                            GradientStop { position: 1; color: Qt.darker(vit.low ? Shinobi.vitalityLow : Shinobi.vitality, 1.5) }
                        }
                    }
                }

                Repeater {
                    model: 2

                    Rectangle {
                        required property int index
                        x: index === 0 ? 0 : vit.width - width
                        y: -3
                        width: 3
                        height: vit.height + 6
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#e7e9ec" }
                            GradientStop { position: 1; color: "#7d8188" }
                        }
                    }
                }
            }

            Row {
                spacing: 10

                Text {
                    id: nameText
                    text: Shinobi.userName
                    font.family: Shinobi.display
                    font.pixelSize: 19
                    color: Shinobi.ivory
                }

                Text {
                    anchors.baseline: nameText.baseline
                    text: Shinobi.rank(Services.LockStats.level) + "  ·  vitality " + Math.round(root.vitality * 100) + "%" + (root.hasBattery && Services.Battery.charging ? ", resting at the idol" : "")
                    font.family: Shinobi.book
                    font.pixelSize: 14
                    color: Shinobi.alpha(Shinobi.ivory, 0.72)
                }
            }
        }
    }

    // ── Where the shinobi is, bottom right ──────────────────────────────
    Item {
        id: card
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 48 + Services.BarLayout.reserveRight
        anchors.bottomMargin: 48 + Services.BarLayout.reserveBottom
        width: cardColumn.implicitWidth
        height: cardColumn.implicitHeight
        opacity: LockTheme.seg(root.boot, 0.45, 1)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.85
            shadowBlur: 0.6
            blurMax: 20
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 2
        }

        Column {
            id: cardColumn
            spacing: 3

            Text {
                id: area
                anchors.right: parent.right
                text: root.stretch.area
                font.family: Shinobi.display
                font.pixelSize: 38
                font.letterSpacing: 1
                color: Shinobi.ivory
            }

            // Brushed under in crimson.
            BrushStroke {
                anchors.right: parent.right
                width: Math.max(area.implicitWidth * 0.86, 180)
                height: 15
                ink: Shinobi.alpha(Shinobi.kanji, 0.88)
                seed: 3
                dry: 0.7
                weight: 0.6
                reveal: LockTheme.seg(root.boot, 0.55, 1)
            }

            Text {
                anchors.right: parent.right
                topPadding: 2
                text: Shinobi.idolKanji + "  Sculptor's Idol  ·  " + root.stretch.idol
                font.family: Shinobi.book
                font.pixelSize: 17
                color: Shinobi.landLight
            }

            Text {
                anchors.right: parent.right
                text: root.stretch.deed
                font.family: Shinobi.book
                font.pixelSize: 15
                color: Shinobi.alpha(Shinobi.ivory, 0.8)
            }

            Text {
                anchors.right: parent.right
                topPadding: 4
                text: (root.season.name + "  ·  " + root.season.line).toUpperCase()
                font.family: Shinobi.book
                font.pixelSize: 11
                font.letterSpacing: 1.8
                color: Shinobi.alpha(Shinobi.ivory, 0.62)
            }
        }
    }
}
