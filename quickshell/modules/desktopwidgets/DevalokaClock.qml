pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.modules.lock.themes.devaloka

// Devaloka clock face: a sun wheel of Konark, its hand on the hour and the
// prahar lit; beside it the hour in Devanagari numerals with the part of
// the day, the tithi of the lunar month and the nakshatra the Moon is in,
// the weekday by its graha with the date, and the muhurta, the prahar's
// raga and the Vikram year.
Item {
    id: root

    property date now: new Date()
    readonly property var pan: Deva.panchang(now)
    readonly property var mu: Deva.muhurta(now)
    readonly property var pr: Deva.prahar(now)
    readonly property var part: Deva.dayPart(now)

    implicitWidth: body.implicitWidth
    implicitHeight: body.implicitHeight

    Row {
        id: body
        spacing: 26

        KonarkWheel {
            anchors.verticalCenter: parent.verticalCenter
            width: 226
            height: 226
            hour: root.now.getHours() + root.now.getMinutes() / 60

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.7
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
                spacing: 12

                Text {
                    id: time
                    text: Deva.numerals(Qt.formatTime(root.now, "h:mm AP").split(" ")[0])
                    font.family: Deva.display
                    font.weight: Font.DemiBold
                    font.pixelSize: 80
                    color: Deva.ivory
                }

                Text {
                    anchors.baseline: time.baseline
                    text: root.part[1]
                    font.family: Deva.display
                    font.pixelSize: 28
                    color: Deva.gold
                }
            }

            Text {
                text: root.pan.masaName + " " + root.pan.tithiLine + "  ·  " + root.pan.nakshatraName
                font.family: Deva.book
                font.italic: true
                font.pixelSize: 21
                color: Deva.gold
            }

            Text {
                topPadding: 2
                text: root.pan.varaName + ", the " + Deva.ordinal(root.now.getDate()) + " of " + Qt.formatDate(root.now, "MMMM")
                font.family: Deva.book
                font.pixelSize: 18
                color: Deva.ivory
            }

            Text {
                topPadding: 5
                text: (root.mu.name + " muhurta  ·  raga " + root.pr.raga + "  ·  Vikram " + root.pan.vikram).toUpperCase()
                font.family: Deva.display
                font.pixelSize: 12
                font.weight: Font.Medium
                font.letterSpacing: 2
                color: Deva.alpha(Deva.ivory, 0.72)
            }
        }
    }
}
