pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.modules.lock
import qs.modules.lock.themes.observatory
import qs.services as Services

// Observatory desktop theme, over the wallpaper: tonight's sky over the
// observing site as an engraved star chart looking at the meridian (the
// stars where they stand right now with the Moon and the planets among
// them, the Milky Way, the equatorial grid and the ecliptic: StarChart), the
// night deepening towards the zenith once the Sun is down; and bottom right
// a brass plate with the Moon's face, the sidereal time and your standing
// at the observatory (the lock level; XP as observations). The chart turns
// with the sky once a minute; its lines are ruled in as it switches on. See
// ThemeLayer.
Item {
    id: root

    property real boot: 1
    property date now: new Date()
    property real pxScale: 1

    readonly property real line: pxScale < 1 ? 1 / pxScale : 1
    readonly property var moon: chart.moon
    readonly property string culminating: Sky.culminating(now)

    StarChart {
        id: chart
        anchors.fill: parent
        now: root.now
        boot: root.boot
        pxScale: root.pxScale
        strength: 0.85
        veil: 0.8
    }

    // The brass plate, bottom right.
    Item {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 40
        anchors.bottomMargin: 62
        width: plateRow.implicitWidth + 44
        height: plateRow.implicitHeight + 30
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
            radius: 10
            color: Sky.alpha(Sky.night, 0.8)
            border.width: root.line
            border.color: Sky.brass

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4 * root.line
                radius: 7
                color: "transparent"
                border.width: root.line
                border.color: Sky.alpha(Sky.brass, 0.35)
            }
        }

        Row {
            id: plateRow
            anchors.centerIn: parent
            spacing: 16

            Orb {
                anchors.verticalCenter: parent.verticalCenter
                width: 70
                height: 70
                illum: root.moon.illum
                waxing: root.moon.waxing
                glow: 0.6
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    text: Sky.phaseName(root.moon) + " in " + Sky.signOf(root.moon.lon)[0]
                    font.family: Sky.display
                    font.italic: true
                    font.pixelSize: 24
                    color: Sky.parchment
                }

                Text {
                    text: "SIDEREAL " + Sky.hm(Sky.lst(root.now)) + "  ·  JD " + Sky.jd(root.now).toFixed(2)
                    font.family: Sky.caps
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    color: Sky.brass
                }

                Text {
                    text: root.culminating ? root.culminating + " on the meridian" : Sky.site.name
                    font.family: Sky.book
                    font.italic: true
                    font.pixelSize: 15
                    color: Sky.alpha(Sky.parchment, 0.85)
                }

                Text {
                    text: Sky.rank(Services.LockStats.level) + "  ·  " + Sky.count(Services.LockStats.xp) + " observations"
                    font.family: Sky.book
                    font.pixelSize: 14
                    color: Sky.alpha(Sky.parchment, 0.62)
                }
            }
        }
    }
}
