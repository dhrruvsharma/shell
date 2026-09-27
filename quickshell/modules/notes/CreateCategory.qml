import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.services as Services
import qs.colors
import qs.components

Dialog {
    id: categoryDialog
    title: "Create New Category"
    modal: true

    x: (root.width - width) / 2
    y: (root.height - height) / 2
    width: 400
    height: 220
    parent: root

    background: Card {
        radius: Services.DesktopTheme.rad(28)
        color: Colors.surface_container_lowest

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(151, 204, 249, 0.1)
        }
    }

    header: Rectangle {
        height: 64
        radius: Services.DesktopTheme.rad(28)
        color: Colors.surface_container_lowest

        Rectangle {
            width: 48
            height: 4
            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            radius: Services.DesktopTheme.rad(2)
            color: Colors.outline_variant
            opacity: 0.3
        }

        StyledText {
            anchors.centerIn: parent
            text: categoryDialog.title
            font.pixelSize: 20
            font.weight: Font.Bold
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 24

        StyledTextField {
            id: categoryInput
            Layout.fillWidth: true
            placeholderText: "Enter category name..."
            font.pixelSize: 14
            focus: true
            radius: Services.DesktopTheme.rad(14)
            borderWidth: 2
            backgroundColor: Colors.surface_container_high
            focusBorderColor: Colors.primary

            onAccepted: {
                if (text.trim().length > 0) {
                    Services.Notes.addCategory(text.trim())
                    categoryDialog.close()
                    text = ""
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Button {
                text: "Cancel"
                Layout.fillWidth: true
                Layout.preferredHeight: 48

                background: Card {
                    radius: Services.DesktopTheme.rad(14)
                    color: parent.hovered
                        ? Colors.surface_container_high
                        : "transparent"
                }

                contentItem: StyledText {
                    text: parent.text
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    categoryDialog.close()
                    categoryInput.text = ""
                }
            }

            Button {
                text: "Create"
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                enabled: categoryInput.text.trim().length > 0

                background: Rectangle {
                    radius: Services.DesktopTheme.rad(14)
                    color: parent.hovered && parent.enabled
                        ? Qt.darker(Colors.primary_container, 1.2)
                        : Colors.primary_container
                    border.width: 2
                    border.color: Colors.primary
                    opacity: 0.3
                }

                contentItem: StyledText {
                    text: parent.text
                    color: Colors.on_primary_container
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    if (categoryInput.text.trim().length > 0) {
                        Services.Notes.addCategory(categoryInput.text.trim())
                        categoryDialog.close()
                        categoryInput.text = ""
                    }
                }
            }
        }
    }
}