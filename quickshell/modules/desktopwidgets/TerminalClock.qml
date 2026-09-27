pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.colors
import qs.modules.desktoptheme
import qs.modules.lock

// Mainframe clock face: a shell session printing the time, in phosphor.
Item {
    id: root

    property date now: new Date()
    readonly property string mono: "Iosevka Nerd Font"
    readonly property color accent: Colors.primary
    readonly property string host: hostFile.text().trim() || "mainframe"
    readonly property string prompt: (Quickshell.env("USER") || "user") + "@" + host + ":~$"

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    FileView {
        id: hostFile
        path: "/etc/hostname"
        printErrors: false
    }

    Column {
        id: col
        spacing: 4

        component PromptLine: Row {
            id: line
            property string command
            spacing: 8

            Text {
                text: root.prompt
                font.family: root.mono
                font.pixelSize: 16
                font.weight: Font.Bold
                color: root.accent
            }

            Text {
                text: line.command
                font.family: root.mono
                font.pixelSize: 16
                color: LockTheme.alpha(Colors.on_surface, 0.8)
            }
        }

        PromptLine {
            command: "date +\"%I:%M %p\""
        }

        Row {
            spacing: 14
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: root.accent
                shadowOpacity: 0.6
                shadowBlur: 0.7
                blurMax: 24
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }

            Text {
                id: hm
                text: Qt.formatDateTime(root.now, "hh:mm")
                font.family: root.mono
                font.pixelSize: 104
                font.weight: Font.Bold
                color: root.accent
            }

            Text {
                anchors.baseline: hm.baseline
                text: Qt.formatDateTime(root.now, "AP")
                font.family: root.mono
                font.pixelSize: 30
                font.weight: Font.Bold
                color: root.accent
            }
        }

        Text {
            text: Qt.formatDateTime(root.now, "ddd yyyy-MM-dd").toLowerCase() + "  ·  week " + Clocks.isoWeek(root.now) + "  ·  day " + Clocks.dayOfYear(root.now)
            font.family: root.mono
            font.pixelSize: 16
            color: LockTheme.alpha(Colors.on_surface, 0.72)
        }

        Item {
            width: 1
            height: 8
        }

        Row {
            spacing: 8

            PromptLine {
                command: ""
            }

            // Static block cursor: a blinking one would redraw forever.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 10
                height: 18
                color: root.accent
            }
        }
    }
}
