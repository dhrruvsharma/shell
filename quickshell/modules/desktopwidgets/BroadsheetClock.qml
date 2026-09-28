pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.desktoptheme
import qs.modules.lock.themes.newspaper

// Broadsheet clock face: the top of a front page, clipped out: volume,
// number and edition over a heavy rule, the time set as the headline, the
// dateline and the price under it, and how far through the year we are.
Item {
    id: root

    property date now: new Date()
    readonly property var hm: Qt.formatDateTime(now, "h:mm AP").split(" ")
    readonly property int day: Clocks.dayOfYear(now)
    readonly property int daysLeft: Math.round((new Date(now.getFullYear() + 1, 0, 1) - new Date(now.getFullYear(), now.getMonth(), now.getDate())) / 86400000)

    implicitWidth: page.width + 5
    implicitHeight: page.height + 5

    Rectangle {
        x: 5
        y: 5
        width: page.width
        height: page.height
        color: Press.alpha("black", 0.42)
    }

    Rectangle {
        id: page
        width: col.implicitWidth + 36
        height: col.implicitHeight + 28
        color: Press.paper

        Column {
            id: col
            x: 18
            y: 14
            spacing: 4

            Item {
                width: Math.max(headline.implicitWidth, 330)
                height: top.implicitHeight

                Text {
                    id: top
                    text: Press.volume(root.now) + "  ·  " + Press.number(root.now)
                    font.family: Press.body
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 0.5
                    color: Press.ink
                }

                Text {
                    anchors.right: parent.right
                    text: Press.edition(root.now)
                    font.family: Press.body
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 0.5
                    color: Press.spotInk
                }
            }

            Rectangle {
                width: parent.width
                height: 3
                color: Press.ink
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Press.ink
            }

            Row {
                id: headline
                spacing: 10

                Text {
                    id: time
                    text: root.hm[0]
                    font.family: Press.masthead
                    font.pixelSize: 96
                    font.weight: Font.Black
                    color: Press.ink
                }

                Text {
                    anchors.baseline: time.baseline
                    text: (root.hm[1] ?? "").toLowerCase().split("").join(".") + "."
                    font.family: Press.masthead
                    font.pixelSize: 26
                    font.weight: Font.Bold
                    font.italic: true
                    color: Press.ink
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Press.ink
            }

            Item {
                width: parent.width
                height: dateline.implicitHeight

                Text {
                    id: dateline
                    text: Press.dateline(root.now)
                    font.family: Press.body
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.letterSpacing: 0.6
                    color: Press.ink
                }

                Text {
                    anchors.right: parent.right
                    text: "FIVE CENTS"
                    font.family: Press.body
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.letterSpacing: 0.6
                    color: Press.ink
                }
            }

            Text {
                text: "Week " + Clocks.isoWeek(root.now) + ", the " + Clocks.ordinal(root.day) + " day of the year; " + root.daysLeft + " remain."
                font.family: Press.body
                font.pixelSize: 13
                font.italic: true
                color: Press.inkSoft
            }
        }
    }
}
