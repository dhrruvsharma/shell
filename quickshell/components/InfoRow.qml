import QtQuick
import QtQuick.Layouts
import qs.colors
import qs.components

RowLayout {
    required property string icon
    required property string label
    required property string value

    Layout.fillWidth: true
    spacing: 14

    Rectangle {
        Layout.preferredWidth: 36
        Layout.preferredHeight: 36
        radius: 8
        color: Colors.tertiary_container

        MaterialIcon {
            anchors.centerIn: parent
            text: icon
            font.pixelSize: 18
            color: Colors.on_tertiary_container
        }
    }

    StyledText {
        Layout.fillWidth: true
        text: label
        color: Colors.on_surface_variant
        font.pixelSize: 14
        font.weight: Font.Medium
    }

    StyledText {
        text: value
        font.pixelSize: 14
        font.weight: Font.Bold
    }
}