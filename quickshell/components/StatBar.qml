import QtQuick
import QtQuick.Layouts
import qs.colors
import qs.components

ColumnLayout {
    required property string label
    required property real value
    required property string icon
    property real maxValue: 100
    property string suffix: "%"

    // primary as a real color so we can derive a translucent tint from it
    readonly property color primaryColor: Colors.primary

    Layout.fillWidth: true
    spacing: 10

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            radius: 8
            color: value > 80
                ? Qt.rgba(239/255, 83/255, 80/255, 0.2)
                : value > 60
                    ? Qt.rgba(255/255, 167/255, 38/255, 0.2)
                    : Qt.rgba(primaryColor.r, primaryColor.g, primaryColor.b, 0.2)

            MaterialIcon {
                anchors.centerIn: parent
                text: icon
                font.pixelSize: 18
                color: value > 80
                    ? "#ef5350"
                    : value > 60
                        ? "#ffa726"
                        : Colors.primary
            }

            Behavior on color {
                ColorAnimation { duration: 300 }
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: label
            font.pixelSize: 14
            font.weight: Font.Medium
        }

        StyledText {
            text: Math.round(value) + suffix
            color: value > 80
                ? "#ef5350"
                : value > 60
                    ? "#ffa726"
                    : Colors.primary
            font.pixelSize: 15
            font.weight: Font.Bold
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 8
        radius: 4
        color: Colors.surface_container_high

        Rectangle {
            width: Math.min(parent.width * (value/maxValue), parent.width)
            height: parent.height
            radius: 4

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: value > 80
                        ? "#ef5350"
                        : value > 60
                            ? "#ffa726"
                            : Colors.primary
                }
                GradientStop {
                    position: 1.0
                    color: value > 80
                        ? "#e53935"
                        : value > 60
                            ? "#ff9800"
                            : Colors.secondary
                }
            }

            Behavior on width {
                NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
            }
        }
    }
}