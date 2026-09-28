pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.desktoptheme
import qs.modules.lock.themes.cyberpunk

// Neon Noir clock face: the time as a neon sign slipping out of register
// (a ghost in each neon either side of a glowing core), the weekday in kanji
// and the date, and which shift the city is on.
Item {
    id: root

    property date now: new Date()
    readonly property string hm: Qt.formatDateTime(now, "hh:mm")

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    Column {
        id: col
        spacing: 8

        Item {
            width: digits.implicitWidth + ap.implicitWidth + 24
            height: digits.implicitHeight

            NeonText {
                id: digits
                text: root.hm
                size: 104
                split: 4
            }

            Text {
                id: ap
                anchors.left: digits.right
                anchors.leftMargin: 14
                anchors.bottom: digits.bottom
                anchors.bottomMargin: digits.height * 0.18
                text: Qt.formatDateTime(root.now, "AP")
                font.family: Neon.ui
                font.pixelSize: 30
                font.letterSpacing: 2
                color: Neon.b
            }
        }

        Row {
            spacing: 14

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Neon.weekdays[root.now.getDay()]
                font.family: Neon.kana
                font.weight: Font.Black
                font.pixelSize: 22
                color: Neon.b
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(root.now, "ddd d MMM yyyy").toUpperCase()
                font.family: Neon.ui
                font.pixelSize: 24
                font.letterSpacing: 2
                color: Neon.ink
            }
        }

        Row {
            spacing: 10

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 3
                color: Neon.a
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Neon.shift(root.now) + "  //  WK " + Clocks.isoWeek(root.now) + "  ·  DAY " + Clocks.dayOfYear(root.now)
                font.family: Neon.ui
                font.pixelSize: 17
                font.letterSpacing: 3
                color: Neon.alpha(Neon.ink, 0.72)
            }
        }
    }
}
