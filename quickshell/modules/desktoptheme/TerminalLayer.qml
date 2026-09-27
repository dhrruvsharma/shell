pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.colors
import qs.modules.lock

// Mainframe desktop theme, over the wallpaper: scanlines, a darker tube
// vignette and a console frame under the bar with its title tabs. Static once
// drawn: the frame draws itself in as it switches on. See ThemeLayer.
Item {
    id: root

    property real boot: 1
    property date now: new Date()
    property real pxScale: 1

    readonly property string mono: "Iosevka Nerd Font"
    readonly property color accent: Colors.primary
    readonly property string user: Quickshell.env("USER") || "user"
    readonly property string host: hostFile.text().trim() || "mainframe"
    readonly property string prompt: user + "@" + host + ":~$"

    FileView {
        id: hostFile
        path: "/etc/hostname"
        printErrors: false
    }

    ShaderEffect {
        anchors.fill: parent
        opacity: root.boot

        property real itemWidth: width * root.pxScale
        property real itemHeight: height * root.pxScale
        property real gridSize: 30
        property real dotAlpha: 0
        property real scanAlpha: root.pxScale < 1 ? 0.1 : 0.16
        property real tintAlpha: 0.16
        property real vignette: 0.5
        property color tintColor: Colors.background
        property color dotColor: root.accent

        fragmentShader: Qt.resolvedUrl("../../shaders/lock_backdrop.frag.qsb")
    }

    // Console frame: draws in from the top-left corner.
    Item {
        id: frame

        readonly property real draw: LockTheme.seg(root.boot, 0, 0.7)
        readonly property real line: root.pxScale < 1 ? 1 / root.pxScale : 1
        readonly property color lineColor: LockTheme.alpha(root.accent, 0.4)

        x: 16
        y: 44 + 10
        width: parent.width - 32
        height: parent.height - y - 16

        Rectangle { width: parent.width * frame.draw; height: frame.line; color: frame.lineColor }
        Rectangle { width: frame.line; height: parent.height * frame.draw; color: frame.lineColor }
        Rectangle { x: parent.width - width; y: parent.height * (1 - frame.draw); width: frame.line; height: parent.height * frame.draw; color: frame.lineColor }
        Rectangle { x: parent.width * (1 - frame.draw); y: parent.height - height; width: parent.width * frame.draw; height: frame.line; color: frame.lineColor }

        component Tab: Rectangle {
            property alias text: tabText.text
            width: tabText.implicitWidth + 20
            height: 20
            color: Colors.background
            border.width: frame.line
            border.color: frame.lineColor
            opacity: LockTheme.seg(root.boot, 0.5, 1)

            Text {
                id: tabText
                anchors.centerIn: parent
                font.family: root.mono
                font.pixelSize: 12
                font.weight: Font.Medium
                font.letterSpacing: 1
                color: root.accent
            }
        }

        Tab {
            x: 24
            y: -10
            text: "tty1 · " + root.user + "@" + root.host
        }

        Tab {
            x: parent.width - width - 24
            y: -10
            text: root.host.toUpperCase() + "-OS · SECURE CONSOLE"
        }

        Tab {
            x: parent.width - width - 24
            y: parent.height - 10
            text: Qt.formatDateTime(root.now, "yyyy-MM-dd")
        }
    }
}
