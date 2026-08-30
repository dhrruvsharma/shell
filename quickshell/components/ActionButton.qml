import QtQuick
import QtQuick.Layouts
import qs.colors
import qs.components

Rectangle {
    id: root

    required property string icon
    required property string label
    required property color buttonColor
    signal clicked

    Layout.fillWidth: true
    Layout.preferredHeight: 56

    radius: 16
    border.width: 1
    border.color: Colors.outline_variant

    property bool hovered: false
    property bool pressed: false
    color: buttonColor

    scale: pressed ? 0.96 : (hovered ? 0.98 : 1)
    opacity: hovered ? 0.95 : 1

    RowLayout {
        anchors.centerIn: parent
        spacing: 12

        MaterialIcon {
            text: icon
            font.pixelSize: 22
        }

        StyledText {
            text: label
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        onClicked: root.clicked()
        onEntered: root.hovered = true
        onExited: root.hovered = false
        onPressed: root.pressed = true
        onReleased: root.pressed = false
    }

    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 90 } }
}
