pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.colors
import qs.modules.workspacedisc
import qs.services as Services

// A corner of your screen at its own size, with the workspace disc in it
// (the real one, in its skin and size, turned to the workspace you're on)
// in one of its states: tucked away, peeking out, or opened out. The bar
// lies along the corner's edge where it does.
Item {
    id: view

    // "tucked", "peek" or "open".
    property string phase: "peek"
    property string corner: Services.WorkspaceDiscService.corner
    // The corner the pointer wakes it from, marked.
    property bool showZone: false
    property string label: ""

    readonly property bool onRight: view.corner === "topRight" || view.corner === "bottomRight"
    readonly property bool onBottom: view.corner === "bottomLeft" || view.corner === "bottomRight"
    // The bar's room along this corner's edges, at screen size.
    readonly property real barX: view.onRight ? Services.BarLayout.reserveRight : Services.BarLayout.reserveLeft
    readonly property real barY: view.onBottom ? Services.BarLayout.reserveBottom : Services.BarLayout.reserveTop

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: Qt.darker(BookStyle.cover, 1.2)
    }

    Item {
        id: glass
        anchors.fill: parent
        anchors.margins: 2
        clip: true

        // The wallpaper's own corner, at screen size.
        Image {
            readonly property real sw: 1920
            readonly property real sh: 1200
            x: view.onRight ? glass.width - sw : 0
            y: view.onBottom ? glass.height - sh : 0
            width: sw
            height: sh
            source: "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
            sourceSize: Qt.size(960, 600)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: 0.85
        }

        // The bar, where it runs along this corner.
        Rectangle {
            visible: view.barY > 0
            x: 0
            y: view.onBottom ? glass.height - view.barY : 0
            width: glass.width
            height: view.barY
            color: Colors.withAlpha(Colors.background, 0.92)
        }

        Rectangle {
            visible: view.barX > 0
            x: view.onRight ? glass.width - view.barX : 0
            y: 0
            width: view.barX
            height: glass.height
            color: Colors.withAlpha(Colors.background, 0.92)
        }

        WorkspaceDisc {
            id: disc
            still: true
            corner: view.corner
            forceExpanded: view.phase === "open"
            x: view.onRight ? glass.width - view.barX - implicitWidth : view.barX
            y: view.onBottom ? glass.height - view.barY - implicitHeight : view.barY
            width: implicitWidth
            height: implicitHeight
            opacity: view.phase === "tucked" ? 0 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                }
            }
        }

        // Where the pointer wakes it.
        Rectangle {
            visible: view.showZone
            x: view.onRight ? glass.width - view.barX - width : view.barX
            y: view.onBottom ? glass.height - view.barY - height : view.barY
            width: disc.revealSize
            height: disc.revealSize
            color: Colors.withAlpha(BookStyle.accent, 0.3)
            border.width: 1
            border.color: BookStyle.accent
        }
    }

    BookText {
        visible: view.label !== ""
        anchors.top: parent.bottom
        anchors.topMargin: 8
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: view.label
        wrapMode: Text.WordWrap
        font.pixelSize: 13
        font.italic: true
        color: BookStyle.inkSoft
    }
}
