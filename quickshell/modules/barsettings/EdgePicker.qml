pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import qs.colors
import qs.services as Services

// Which screen edge the bar sits on: a little screen with your wallpaper
// and a bar slot along each edge; the bar's own lit, a click on another
// moves the bar there (as dragging an empty stretch of the bar does).
Item {
    id: root

    readonly property string edge: Services.BarLayout.edge
    property string hovered: ""

    implicitWidth: 168
    implicitHeight: 105

    Rectangle {
        id: screenMask
        anchors.fill: parent
        radius: Services.DesktopTheme.rad(12)
        visible: false
        layer.enabled: true
    }

    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: screenMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        Rectangle {
            anchors.fill: parent
            color: Colors.background
        }

        Image {
            anchors.fill: parent
            source: "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
            sourceSize: Qt.size(Math.max(1, width * 2), Math.max(1, height * 2))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            opacity: 0.85
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: screenMask.radius
        color: "transparent"
        border.width: 1
        border.color: Colors.withAlpha(Colors.outline_variant, 0.9)
    }

    Repeater {
        model: ["top", "bottom", "left", "right"]

        Item {
            id: slot

            required property string modelData
            readonly property bool side: modelData === "left" || modelData === "right"
            readonly property bool current: root.edge === modelData
            readonly property real thick: 9
            readonly property real inset: 5

            // Its strip along the edge, with a margin round it to grab.
            x: modelData === "right" ? root.width - width : 0
            y: modelData === "bottom" ? root.height - height : 0
            width: slot.side ? slot.thick + 2 * slot.inset : root.width
            height: slot.side ? root.height : slot.thick + 2 * slot.inset

            Rectangle {
                x: slot.side ? slot.inset : slot.inset + slot.thick + 3
                y: slot.side ? slot.inset + slot.thick + 3 : slot.inset
                width: slot.side ? slot.thick : parent.width - 2 * (slot.inset + slot.thick + 3)
                height: slot.side ? parent.height - 2 * (slot.inset + slot.thick + 3) : slot.thick
                radius: Services.DesktopTheme.rad(4.5)
                color: slot.current ? Colors.primary
                    : root.hovered === slot.modelData ? Colors.withAlpha(Colors.primary, 0.55)
                    : Colors.withAlpha(Colors.scrim, 0.4)
                border.width: slot.current ? 0 : 1
                border.color: Colors.withAlpha("white", root.hovered === slot.modelData ? 0.7 : 0.35)

                Behavior on color {
                    ColorAnimation { duration: 140 }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: slot.current ? Qt.ArrowCursor : Qt.PointingHandCursor
                onEntered: root.hovered = slot.modelData
                onExited: if (root.hovered === slot.modelData) root.hovered = ""
                onClicked: Services.BarLayout.setEdge(slot.modelData)
            }
        }
    }
}
