import QtQuick
import QtQuick.Controls
import qs.colors

// Button with the shell's background/label styling, replacing the hand-written
// `background: Rectangle` + `contentItem: Text` pair.
Button {
    id: root

    property real radius: 14
    property int borderWidth: 1
    property color backgroundColor: "transparent"
    property color hoverColor: Colors.surface_container_high
    property color borderColor: Colors.outline_variant
    property color textColor: Colors.on_surface
    property int fontPixelSize: 14
    property int fontWeight: Font.Medium

    background: Rectangle {
        radius: root.radius
        color: root.hovered ? root.hoverColor : root.backgroundColor
        border.width: root.borderWidth
        border.color: root.borderColor
    }

    contentItem: StyledText {
        text: root.text
        color: root.textColor
        font.pixelSize: root.fontPixelSize
        font.weight: root.fontWeight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
