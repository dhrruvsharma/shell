pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.modules.desktoptheme
import qs.modules.lock.themes.observatory

// Observatory clock face: an astrolabe set for the observing site, its rete
// turned to the sidereal time so the stars stand where they do in the sky
// and its rule on the hour; beside it the time in Fell type, the sidereal
// time with the Sun's sign, the date, and the Moon's phase with the year.
Item {
    id: root

    property date now: new Date()
    readonly property var hm: Qt.formatDateTime(now, "h:mm AP").split(" ")
    readonly property var sun: Sky.sun(now)
    readonly property var moon: Sky.moon(now)

    implicitWidth: body.implicitWidth
    implicitHeight: body.implicitHeight

    Row {
        id: body
        spacing: 26

        Astrolabe {
            anchors.verticalCenter: parent.verticalCenter
            width: 236
            height: 236
            rete: Sky.lst(root.now)
            rule: (root.now.getHours() + root.now.getMinutes() / 60 - 12) * 15

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.65
                shadowBlur: 0.7
                blurMax: 24
                shadowHorizontalOffset: 2
                shadowVerticalOffset: 4
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.8
                shadowBlur: 0.8
                blurMax: 28
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 2
            }

            Row {
                spacing: 10

                Text {
                    id: time
                    text: root.hm[0]
                    font.family: Sky.display
                    font.pixelSize: 80
                    color: Sky.parchment
                }

                Text {
                    anchors.baseline: time.baseline
                    text: (root.hm[1] ?? "").toLowerCase().split("").join(".") + "."
                    font.family: Sky.caps
                    font.pixelSize: 22
                    color: Sky.brass
                }
            }

            Text {
                text: "Sidereal " + Sky.hm(Sky.lst(root.now)) + "  ·  the Sun in " + Sky.signOf(root.sun.lon)[0]
                font.family: Sky.display
                font.italic: true
                font.pixelSize: 20
                color: Sky.brass
            }

            Text {
                topPadding: 4
                text: Qt.formatDate(root.now, "dddd") + ", the " + Clocks.ordinal(root.now.getDate()) + " of " + Qt.formatDate(root.now, "MMMM")
                font.family: Sky.book
                font.pixelSize: 18
                color: Sky.parchment
            }

            Text {
                topPadding: 3
                text: (Sky.phaseName(root.moon) + "  ·  Anno " + Clocks.roman(root.now.getFullYear())).toUpperCase()
                font.family: Sky.caps
                font.pixelSize: 13
                font.letterSpacing: 2
                color: Sky.alpha(Sky.parchment, 0.75)
            }
        }
    }
}
