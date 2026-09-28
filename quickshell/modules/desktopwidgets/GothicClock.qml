pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.modules.lock.themes.gothic

// Cathedral clock face: a rose window glazed in the wallpaper's colours,
// its lancets lit through the hours and its roundels through the minutes;
// beside it the time in blackletter, the canonical hour the bells last
// rang, the date and the year of grace, and the season of the church year.
Item {
    id: root

    property date now: new Date()
    readonly property var hm: Qt.formatDateTime(now, "h:mm AP").split(" ")
    readonly property var hour: Gothic.canonicalHour(now)
    readonly property var season: Gothic.season(now)

    implicitWidth: body.implicitWidth
    implicitHeight: body.implicitHeight

    Row {
        id: body
        spacing: 24

        RoseWindow {
            anchors.verticalCenter: parent.verticalCenter
            width: 200
            height: 200
            lit: root.now.getHours() % 12 + root.now.getMinutes() / 60
            litInner: root.now.getMinutes() / 5
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
                    font.family: Gothic.blackletter
                    font.pixelSize: 78
                    color: Gothic.parchment
                }

                Text {
                    anchors.baseline: time.baseline
                    text: root.hm[1] ?? ""
                    font.family: Gothic.caps
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    color: Gothic.glassC
                }
            }

            Text {
                text: root.hour.en + "  ·  " + root.hour.gloss
                font.family: Gothic.book
                font.pixelSize: 19
                font.italic: true
                color: Gothic.glassC
            }

            Text {
                topPadding: 4
                text: Gothic.date(root.now)
                font.family: Gothic.book
                font.pixelSize: 17
                color: Gothic.parchment
            }

            Text {
                topPadding: 2
                text: (Gothic.year(root.now) + "  ·  " + root.season.la).toUpperCase()
                font.family: Gothic.caps
                font.pixelSize: 12
                font.weight: Font.Bold
                font.letterSpacing: 2
                color: Gothic.alpha(Gothic.parchment, 0.78)
            }
        }
    }
}
