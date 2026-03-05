import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import Quickshell
import qs.services as Services
import "../../colors" as ColorsModule

Item {
    readonly property bool adapterPresent: Services.Bluetooth.defaultAdapter !== null
    readonly property bool enabled: Services.Bluetooth.defaultAdapter?.enabled ?? false
    readonly property var devices: Services.Bluetooth.devices
    readonly property var activeDevice: Services.Bluetooth.activeDevice

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: ""
                font.family: "Material Design Icons"
                font.pixelSize: 24
                color: enabled
                    ? ColorsModule.Colors.primary
                    : ColorsModule.Colors.on_surface_variant
            }

            Text {
                text: "Bluetooth Devices"
                font.pixelSize: 18
                font.bold: true
                Layout.fillWidth: true
                color: ColorsModule.Colors.on_surface
            }

            Rectangle {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 26
                radius: height / 2

                color: enabled
                    ? ColorsModule.Colors.primary
                    : ColorsModule.Colors.surface_container_high

                Rectangle {
                    width: 20
                    height: 20
                    radius: 10
                    y: 3
                    x: enabled ? parent.width - width - 3 : 3
                    color: ColorsModule.Colors.on_surface

                    Behavior on x {
                        NumberAnimation { duration: 150 }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        if (!adapterPresent)
                            return

                        Services.Bluetooth.defaultAdapter.enabled =
                            !Services.Bluetooth.defaultAdapter.enabled
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 8

                color: refreshMouseArea.containsMouse
                    ? ColorsModule.Colors.surface_container_highest
                    : ColorsModule.Colors.surface_container_high

                Text {
                    anchors.centerIn: parent
                    text: "󰑐"
                    font.family: "Material Design Icons"
                    font.pixelSize: 20
                    color: ColorsModule.Colors.on_surface

                    rotation: Services.Bluetooth.defaultAdapter?.discovering ? 360 : 0

                    Behavior on rotation {
                        NumberAnimation {
                            duration: 1000
                            loops: Animation.Infinite
                        }
                    }
                }

                MouseArea {
                    id: refreshMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        if (enabled)
                            Services.Bluetooth.defaultAdapter.discovering = true
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 14
            color: ColorsModule.Colors.surface_container_low
            clip: true

            ListView {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8
                model: devices

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 64
                    radius: 12

                    color: mouse.containsMouse
                        ? ColorsModule.Colors.surface_container_high
                        : ColorsModule.Colors.surface

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Text {
                            text: "󰂯"
                            font.family: "Material Design Icons"
                            font.pixelSize: 20
                            color: modelData.connected
                                ? ColorsModule.Colors.primary
                                : ColorsModule.Colors.on_surface_variant
                        }

                        ColumnLayout {
                            Layout.fillWidth: true

                            Text {
                                text: modelData.name || "Unknown device"
                                font.pixelSize: 14
                                color: ColorsModule.Colors.on_surface
                                elide: Text.ElideRight
                            }

                            Text {
                                text:
                                    modelData.connected ? "Connected" :
                                        modelData.paired ? "Paired" :
                                            "Available"

                                font.pixelSize: 11
                                color: ColorsModule.Colors.on_surface_variant
                            }
                        }
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            if (!enabled)
                                return

                            if (modelData.connected) {
                                modelData.disconnect()
                            } else {
                                if (!modelData.paired)
                                    modelData.pair()

                                modelData.connect()
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: devices.length === 0
                    text: enabled
                        ? "No devices found"
                        : "Bluetooth disabled"
                    color: ColorsModule.Colors.on_surface_variant
                }
            }
        }
    }
}