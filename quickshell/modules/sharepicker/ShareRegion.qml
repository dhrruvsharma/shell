pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.control
import qs.modules.screenshot

// A region being drawn on a screen, in the view's coordinates: all the rest
// goes down, and it has its size, handles to pull, and the button that shares
// it. The view does the dragging.
Item {
    id: region

    // Where it is.
    required property var rect
    // Its size on the screen itself, for the label.
    required property int pixelWidth
    required property int pixelHeight
    // Still being drawn: no handles or button yet.
    property bool drawing: false

    signal shareClicked

    readonly property real shade: 0.62

    // Four strips: everything that isn't in the region.
    Rectangle {
        width: region.width
        height: region.rect.y
        color: "black"
        opacity: region.shade
    }

    Rectangle {
        y: region.rect.y + region.rect.h
        width: region.width
        height: region.height - y
        color: "black"
        opacity: region.shade
    }

    Rectangle {
        y: region.rect.y
        width: region.rect.x
        height: region.rect.h
        color: "black"
        opacity: region.shade
    }

    Rectangle {
        x: region.rect.x + region.rect.w
        y: region.rect.y
        width: region.width - x
        height: region.rect.h
        color: "black"
        opacity: region.shade
    }

    Rectangle {
        x: region.rect.x - 2
        y: region.rect.y - 2
        width: region.rect.w + 4
        height: region.rect.h + 4
        color: "transparent"
        border.width: 2
        border.color: ControlStyle.accent
    }

    Repeater {
        model: region.drawing ? [] : [[0, 0], [0.5, 0], [1, 0], [0, 0.5], [1, 0.5], [0, 1], [0.5, 1], [1, 1]]

        Rectangle {
            required property var modelData

            x: region.rect.x + region.rect.w * modelData[0] - 5
            y: region.rect.y + region.rect.h * modelData[1] - 5
            width: 10
            height: 10
            radius: ControlStyle.radius(5)
            color: ControlStyle.accent
            border.width: 1
            border.color: Colors.withAlpha("black", 0.5)
        }
    }

    // Its size, above the corner, or inside when that's off the view.
    Rectangle {
        x: region.rect.x
        y: region.rect.y >= height + 10 ? region.rect.y - height - 8 : region.rect.y + 8
        width: size.implicitWidth + 16
        height: 26
        radius: ControlStyle.radius(6)
        color: Colors.withAlpha("black", 0.72)

        Text {
            id: size

            anchors.centerIn: parent
            text: region.pixelWidth + " × " + region.pixelHeight
            font.family: ControlStyle.mono
            font.pixelSize: 13
            font.features: ({
                    "tnum": 1
                })
            color: "white"
        }
    }

    MouseArea {
        id: share

        visible: !region.drawing
        // Under the corner; inside if it would run off the view.
        x: Math.max(8, Math.min(region.rect.x + region.rect.w - width, region.width - width - 8))
        y: region.rect.y + region.rect.h + height + 12 <= region.height ? region.rect.y + region.rect.h + 10 : region.rect.y + region.rect.h - height - 10
        width: shareRow.implicitWidth + 28
        height: 40
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: region.shareClicked()

        Rectangle {
            anchors.fill: parent
            radius: ControlStyle.radius(12)
            color: ControlStyle.accent
            opacity: share.containsMouse ? 1 : 0.92
        }

        Row {
            id: shareRow

            anchors.centerIn: parent
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Share this region"
                font.family: ControlStyle.ui
                font.pixelSize: 15
                color: ControlStyle.inkOn(ControlStyle.accent)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Enter"
                font.family: ControlStyle.mono
                font.pixelSize: 11
                color: Colors.withAlpha(ControlStyle.inkOn(ControlStyle.accent), 0.65)
            }
        }
    }
}
