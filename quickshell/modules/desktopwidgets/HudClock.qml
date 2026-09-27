pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.components
import qs.modules.desktoptheme
import qs.modules.lock

// HUD clock face: stage time in a chamfered panel, with a day-progress meter
// of one segment per hour.
Item {
    id: root

    property date now: new Date()
    readonly property color accent: Colors.primary
    readonly property int hour: now.getHours()

    implicitWidth: 330
    implicitHeight: col.implicitHeight + 32

    HudFrame {
        cut: 14
        fill: LockTheme.alpha(Colors.background, 0.62)
        stroke: LockTheme.alpha(root.accent, 0.35)
        tickColor: root.accent
    }

    Column {
        id: col
        x: 22
        y: 16
        spacing: 6

        Text {
            text: "STAGE TIME"
            font.family: LockTheme.mono
            font.pixelSize: 11
            font.weight: Font.Bold
            font.letterSpacing: 4
            color: root.accent
        }

        Row {
            spacing: 10

            Text {
                id: hm
                text: Qt.formatDateTime(root.now, "hh:mm")
                font.family: LockTheme.display
                font.pixelSize: 58
                font.weight: Font.Bold
                color: Colors.on_surface
            }

            Text {
                anchors.baseline: hm.baseline
                text: Qt.formatDateTime(root.now, "AP")
                font.family: LockTheme.display
                font.pixelSize: 18
                font.weight: Font.Bold
                color: root.accent
            }
        }

        Text {
            text: Qt.formatDateTime(root.now, "ddd · d MMM").toUpperCase() + "  ·  DAY " + Clocks.dayOfYear(root.now)
            font.family: LockTheme.mono
            font.pixelSize: 12
            font.letterSpacing: 2
            color: LockTheme.alpha(Colors.on_surface, 0.72)
        }

        Row {
            spacing: 3

            Repeater {
                model: 24

                Rectangle {
                    required property int index
                    width: 9.5
                    height: 5
                    color: index < root.hour ? root.accent
                        : index === root.hour ? LockTheme.alpha(root.accent, 0.5)
                        : LockTheme.alpha(Colors.on_surface, 0.15)
                }
            }
        }
    }
}
