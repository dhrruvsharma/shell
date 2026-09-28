pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.modules.lock.themes.artdeco

// Art Deco clock face: an elevator's floor dial whose needle sweeps round
// the twelve hours, the time under it in thin Deco capitals, the date
// between gold rules, and the hour of a grand hotel's day.
Item {
    id: root

    property date now: new Date()
    readonly property var hm: Qt.formatDateTime(now, "h:mm AP").split(" ")

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    Column {
        id: col
        spacing: 4

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.75
            shadowBlur: 0.8
            blurMax: 28
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 2
        }

        DecoDial {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 230
            value: ((root.now.getHours() % 12) + root.now.getMinutes() / 60) / 12
            ticks: 13
            labels: ["12", "3", "6", "9", "12"]
            line: 1.5
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            Text {
                id: time
                text: root.hm[0]
                font.family: Deco.display
                font.pixelSize: 96
                font.weight: Font.Bold
                color: Deco.gold
            }

            Text {
                anchors.baseline: time.baseline
                text: root.hm[1] ?? ""
                font.family: Deco.ui
                font.pixelSize: 20
                font.weight: Font.DemiBold
                font.letterSpacing: 3
                color: Deco.ivory
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                height: 1
                color: Deco.gold
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 6
                rotation: 45
                color: Deco.gold
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Deco.date(root.now)
                font.family: Deco.ui
                font.pixelSize: 14
                font.weight: Font.DemiBold
                font.letterSpacing: 3
                color: Deco.ivory
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 6
                rotation: 45
                color: Deco.gold
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                height: 1
                color: Deco.gold
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 4
            text: Deco.hour(root.now)
            font.family: Deco.marquee
            font.pixelSize: 17
            font.letterSpacing: 4
            color: Deco.gold
        }
    }
}
