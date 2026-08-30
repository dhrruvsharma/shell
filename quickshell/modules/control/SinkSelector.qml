import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services as Services
import qs.colors
import qs.components

ColumnLayout {
    id: root

    Layout.fillWidth: true
    spacing: 0

    Item {
        Layout.fillWidth: true
        Layout.topMargin: 8
        implicitHeight: 36

        StyledText {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: "Audio Output"
            color: Colors.on_surface_variant
            font.pixelSize: 11
            font.letterSpacing: 1.2
            font.weight: Font.Medium
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        Layout.bottomMargin: 12
        spacing: 3

        Repeater {
            model: Services.Volume.sinks

            delegate: Item {
                id: delegate

                required property var modelData
                property bool isDefault: modelData === Services.Volume.defaultSink
                property string sinkName: modelData?.name ?? ""
                property string displayName: {
                    let name = sinkName
                    name = name.replace(/^alsa_output\./, "")
                    name = name.replace(/\.(analog-stereo|stereo|mono|surround.*)$/, "")
                    name = name.replace(/\./g, " ")
                    return name.charAt(0).toUpperCase() + name.slice(1)
                }
                property string description: modelData?.audio?.description ?? modelData?.description ?? ""
                property string label: description !== "" ? description : displayName

                Layout.fillWidth: true
                implicitHeight: 48

                Process {
                    id: pactlSetSink
                    command: ["pactl", "set-default-sink", delegate.sinkName]
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 8

                    color: delegate.isDefault
                        ? Colors.withAlpha(Colors.primary_container, 0.85)
                        : hoverHandler.hovered
                            ? Colors.surface_container_high
                            : Colors.surface_container

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    Rectangle {
                        width: 3
                        height: parent.height * 0.55
                        radius: 1.5
                        anchors.left: parent.left
                        anchors.leftMargin: 0
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colors.primary
                        opacity: delegate.isDefault ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: 150 }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                Layout.fillWidth: true
                                text: delegate.label
                                color: delegate.isDefault
                                    ? Colors.on_primary_container
                                    : Colors.on_surface
                                font.pixelSize: 13
                                font.weight: delegate.isDefault ? Font.Medium : Font.Normal
                                elide: Text.ElideRight

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: delegate.sinkName
                                color: delegate.isDefault
                                    ? Colors.withAlpha(Colors.on_primary_container, 0.55)
                                    : Colors.on_surface_variant
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                visible: delegate.description !== ""
                                opacity: 0.85

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                        }

                        StyledText {
                            text: "✓"
                            color: Colors.primary
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            opacity: delegate.isDefault ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }
                        }
                    }

                    HoverHandler {
                        id: hoverHandler
                    }

                    TapHandler {
                        onTapped: {
                            if (!delegate.isDefault) {
                                pactlSetSink.running = true
                                Services.Volume.setDefaultSink(delegate.modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    Divider {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        opacity: 0.4
    }
}
