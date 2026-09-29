pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.components
import qs.modules.lock
import qs.modules.lock.themes.devaloka
import qs.modules.lock.themes.observatory
import qs.services as Services

// Devaloka desktop theme, over the wallpaper, bottom right and out of the
// wallpaper's way: a lacquered plaque with the day's panchang (the Moon in
// its phase, the tithi in Devanagari, the lunar month and the nakshatra,
// the yoga, the karana and the season, and your standing among the sages:
// the lock level, XP as punya), and beside it a seal: a yantra drawn in
// gold in a gold ring (shaders/desktop_yantra.frag: the bindu, the
// triangles, the lotuses, the circles and the gated square of the
// bhupura), drawn outwards like a rangoli as the theme switches on. It
// changes once a minute. See ThemeLayer.
Item {
    id: root

    property real boot: 1
    property date now: new Date()
    property real pxScale: 1

    readonly property real line: pxScale < 1 ? 1 / pxScale : 1
    readonly property var pan: Deva.panchang(now)

    // The seal, beside the panchang.
    Item {
        anchors.right: plaque.left
        anchors.rightMargin: 16
        anchors.verticalCenter: plaque.verticalCenter
        width: 176
        height: 176
        opacity: LockTheme.seg(root.boot, 0.2, 0.7)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.55
            shadowBlur: 0.6
            blurMax: 20
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 3
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Deva.alpha(Deva.ground, 0.84)
            border.width: root.line
            border.color: Deva.gold

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4 * root.line
                radius: width / 2
                color: "transparent"
                border.width: root.line
                border.color: Deva.alpha(Deva.gold, 0.35)
            }
        }

        ShaderEffect {
            anchors.fill: parent
            anchors.margins: 10

            property real itemWidth: width
            property real itemHeight: height
            property real boot: root.boot
            property real lineScale: Math.min(3, root.line)
            property real strength: 1
            // Its corners just inside the inner ring.
            property real size: width * 0.345
            property real halo: 0
            property point centre: Qt.point(width / 2, height / 2)
            property color goldColor: Deva.gold
            property color pigmentColor: Deva.pigment
            property color groundColor: Deva.ground
            property color bindColor: Deva.kumkum

            fragmentShader: Qt.resolvedUrl("../../shaders/desktop_yantra.frag.qsb")
        }
    }

    // The panchang, bottom right.
    Item {
        id: plaque
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 40
        anchors.bottomMargin: 56
        width: plaqueRow.implicitWidth + 48
        height: plaqueRow.implicitHeight + 40
        opacity: LockTheme.seg(root.boot, 0.45, 1)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.55
            shadowBlur: 0.6
            blurMax: 20
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 3
        }

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: Deva.alpha(Deva.ground, 0.84)
            border.width: root.line
            border.color: Deva.gold

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4 * root.line
                radius: 5
                color: "transparent"
                border.width: root.line
                border.color: Deva.alpha(Deva.gold, 0.35)
            }
        }

        Repeater {
            model: 2

            TempleBorder {
                required property int index
                x: index === 0 ? 16 : parent.width / 2 + 15
                y: 5 * root.line
                width: parent.width / 2 - 31
                height: 4
                step: 6
                down: true
                rule: 0
                color: Deva.alpha(Deva.gold, 0.55)
            }
        }

        Lotus {
            x: (parent.width - width) / 2
            y: -8
            width: 26
            height: 17
            stroke: Deva.gold
            fill: Deva.alpha(Deva.pigment, 0.55)
            lineWidth: root.line
        }

        Row {
            id: plaqueRow
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 3
            spacing: 16

            Orb {
                anchors.verticalCenter: parent.verticalCenter
                width: 70
                height: 70
                illum: root.pan.illum
                waxing: root.pan.waxing
                glow: 0.6
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    text: root.pan.tithiLineDev + "  ·  " + root.pan.nakshatraDev
                    font.family: Deva.display
                    font.weight: Font.Medium
                    font.pixelSize: 24
                    color: Deva.ivory
                }

                Text {
                    text: root.pan.masaName + " " + root.pan.tithiLine + "  ·  " + root.pan.nakshatraName + " nakshatra"
                    font.family: Deva.book
                    font.italic: true
                    font.pixelSize: 16
                    color: Deva.gold
                }

                Text {
                    text: ("Yoga " + root.pan.yogaName + "  ·  Karana " + root.pan.karanaName + "  ·  " + root.pan.rituName + " ritu").toUpperCase()
                    font.family: Deva.display
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    font.letterSpacing: 1.8
                    color: Deva.alpha(Deva.gold, 0.85)
                }

                Text {
                    topPadding: 2
                    text: Deva.rank(Services.LockStats.level) + " (" + Deva.rankDev(Services.LockStats.level) + ")  ·  " + Deva.count(Services.LockStats.xp) + " punya"
                    font.family: Deva.book
                    font.pixelSize: 14
                    color: Deva.alpha(Deva.ivory, 0.66)
                }
            }
        }
    }
}
