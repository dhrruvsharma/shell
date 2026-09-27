import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.services as Services
import qs.colors
import qs.components

Dialog {
    id: commandDialog
    title: "Configure Category"
    modal: true

    property string categoryName: ""
    property string commandText: ""
    property bool keepOpen: false

    x: (root.width - width) / 2
    y: (root.height - height) / 2
    width: 500
    height: 380  // Increased height to accommodate new option
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
            text: "Configure: " + commandDialog.categoryName
            font.pixelSize: 20
            font.weight: Font.Bold
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 12

        StyledText {
            text: "Enter command to execute when clicking notes in this category.\nUse $text or $note as placeholder for the main note content."
            color: Colors.on_surface_variant
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        StyledTextField {
            id: commandInput
            Layout.fillWidth: true
            text: commandDialog.commandText
            placeholderText: "e.g., ani-cli $text"
            font.pixelSize: 14
            focus: true
            radius: Services.DesktopTheme.rad(14)
            borderWidth: 2
            backgroundColor: Colors.surface_container_high
            focusBorderColor: Colors.primary
        }

        // Keep terminal open option
        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            radius: Services.DesktopTheme.rad(12)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                StyledText {
                    text: "Keep terminal open after execution:"
                    font.pixelSize: 13
                    Layout.fillWidth: true
                }

                Switch {
                    id: keepOpenSwitch
                    checked: commandDialog.keepOpen
                    Layout.alignment: Qt.AlignRight

                    indicator: Rectangle {
                        implicitWidth: 48
                        implicitHeight: 24
                        x: keepOpenSwitch.leftPadding
                        y: parent.height / 2 - height / 2
                        radius: Services.DesktopTheme.rad(12)
                        color: keepOpenSwitch.checked
                            ? Colors.primary
                            : Colors.surface_container_highest
                        border.color: keepOpenSwitch.checked
                            ? Colors.primary
                            : Colors.outline_variant
                        border.width: 1

                        Rectangle {
                            x: keepOpenSwitch.checked ? parent.width - width : 0
                            y: (parent.height - height) / 2
                            width: 20
                            height: 20
                            radius: Services.DesktopTheme.rad(10)
                            color: Colors.on_primary
                            border.color: keepOpenSwitch.checked
                                ? Colors.primary
                                : Colors.outline_variant
                            border.width: 1

                            Behavior on x {
                                NumberAnimation { duration: 200 }
                            }
                        }
                    }
                }
            }

            ToolTip {
                text: "When enabled, terminal stays open after command (for SSH, interactive apps).\nWhen disabled, terminal closes after command (for launching apps)."
                delay: 500
                visible: parent.hovered
                width: 300
                background: Card {
                    radius: Services.DesktopTheme.rad(6)
                    color: Colors.surface_container_highest
                }
            }
        }

        // Example preview
        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: Services.DesktopTheme.rad(10)
            visible: commandInput.text.trim().length > 0

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                StyledText {
                    text: "Preview:"
                    color: Colors.on_surface_variant
                    font.pixelSize: 11
                    font.bold: true
                }

                StyledText {
                    text: commandInput.text.replace(/\$text/g, "example").replace(/\$note/g, "example")
                    color: Colors.primary
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                }
            }
        }

        // Buttons at bottom with proper spacing
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            spacing: 8

            Button {
                text: "Clear"
                Layout.fillWidth: true
                Layout.preferredHeight: 44

                background: Card {
                    radius: Services.DesktopTheme.rad(12)
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
                    commandInput.text = ""
                    keepOpenSwitch.checked = false
                }
            }

            Button {
                text: "Cancel"
                Layout.fillWidth: true
                Layout.preferredHeight: 44

                background: Card {
                    radius: Services.DesktopTheme.rad(12)
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
                    commandDialog.close()
                }
            }

            Button {
                text: "Save"
                Layout.fillWidth: true
                Layout.preferredHeight: 44

                background: Rectangle {
                    radius: Services.DesktopTheme.rad(12)
                    color: parent.hovered
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
                    Services.Notes.setCategoryCommand(commandDialog.categoryName, commandInput.text)
                    Services.Notes.setCategoryKeepOpen(commandDialog.categoryName, keepOpenSwitch.checked)
                    commandDialog.close()
                }
            }
        }
    }
}