import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import Quickshell
import qs.services as Services
import qs.colors
import qs.components

Item {
    id: btRoot

    readonly property bool adapterPresent: Services.Bluetooth.defaultAdapter !== null
    readonly property bool bluetoothEnabled: Services.Bluetooth.defaultAdapter?.enabled ?? false
    readonly property var activeDevice: Services.Bluetooth.activeDevice
    readonly property color accent: Colors.primary
    property bool scanning: false

    Timer {
        id: scanStopTimer
        interval: 10000
        onTriggered: {
            btRoot.scanning = false
            if (Services.Bluetooth.defaultAdapter)
                Services.Bluetooth.defaultAdapter.discovering = false
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // ── Hero status card ──
        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: 78
            radius: 18
            color: Colors.surface_container_high

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 14
                spacing: 14

                Rectangle {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    radius: 24
                    color: btRoot.bluetoothEnabled
                        ? Qt.rgba(btRoot.accent.r, btRoot.accent.g, btRoot.accent.b, 0.16)
                        : Colors.surface_container_highest
                    Behavior on color { ColorAnimation { duration: 200 } }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: btRoot.bluetoothEnabled ? "󰂯" : "󰂲"
                        font.pixelSize: 24
                        color: btRoot.bluetoothEnabled
                            ? Colors.primary
                            : Colors.on_surface_variant
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: btRoot.activeDevice ? (btRoot.activeDevice.name || "Connected device") : "Bluetooth"
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        text: !btRoot.adapterPresent ? "No adapter"
                            : btRoot.activeDevice ? "Connected"
                            : btRoot.bluetoothEnabled ? "On"
                            : "Off"
                        font.pixelSize: 12
                        color: btRoot.activeDevice
                            ? Colors.primary
                            : Colors.on_surface_variant
                    }
                }

                // toggle switch
                Rectangle {
                    Layout.preferredWidth: 50
                    Layout.preferredHeight: 28
                    radius: 14
                    opacity: btRoot.adapterPresent ? 1 : 0.4
                    color: btRoot.bluetoothEnabled
                        ? Colors.primary
                        : Colors.surface_container_highest
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        width: 22; height: 22; radius: 11
                        y: 3
                        x: btRoot.bluetoothEnabled ? parent.width - width - 3 : 3
                        color: btRoot.bluetoothEnabled
                            ? Colors.on_primary
                            : Colors.on_surface_variant
                        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!btRoot.adapterPresent) return
                            Services.Bluetooth.defaultAdapter.enabled =
                                !Services.Bluetooth.defaultAdapter.enabled
                        }
                    }
                }
            }
        }

        // ── list header ──
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 8
            visible: btRoot.bluetoothEnabled

            StyledText {
                Layout.fillWidth: true
                text: btRoot.scanning ? "Scanning for devices…" : "Devices"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                font.letterSpacing: 0.3
                color: Colors.on_surface_variant
            }

            ClickableRect {
                id: scanRect
                Layout.preferredWidth: 30; Layout.preferredHeight: 30
                radius: 15
                color: scanRect.hovered ? Colors.surface_container_highest : "transparent"
                MaterialIcon {
                    anchors.centerIn: parent
                    text: "󰑐"
                    font.pixelSize: 16
                    color: btRoot.scanning ? Colors.primary : Colors.on_surface_variant
                    RotationAnimator on rotation {
                        from: 0; to: 360; duration: 900; loops: Animation.Infinite
                        running: btRoot.scanning
                    }
                }
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                        if (!btRoot.bluetoothEnabled) return
                        Services.Bluetooth.defaultAdapter.discovering = true
                        btRoot.scanning = true
                        scanStopTimer.restart()
                    }
            }
        }

        // ── device list ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 16
            color: Colors.surface_container_low
            clip: true

            // empty / off state
            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 40
                spacing: 6
                visible: Services.Bluetooth.devices.length === 0

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: btRoot.bluetoothEnabled ? "󰂯" : "󰂲"
                    font.pixelSize: 42
                    opacity: 0.5
                    color: Colors.on_surface_variant
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: !btRoot.adapterPresent ? "No Bluetooth adapter"
                        : btRoot.bluetoothEnabled ? "No devices found"
                        : "Bluetooth is off"
                    color: Colors.on_surface_variant
                    font.pixelSize: 13
                }
            }

            ScrollView {
                anchors.fill: parent
                anchors.margins: 6
                clip: true
                visible: btRoot.bluetoothEnabled
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ColumnLayout {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: Services.Bluetooth.devices
                            .filter(d => true)
                            .sort((a, b) => {
                                if (a.connected !== b.connected) return a.connected ? -1 : 1
                                if (a.paired !== b.paired) return a.paired ? -1 : 1
                                return (a.name || "").localeCompare(b.name || "")
                            })

                        delegate: Rectangle {
                            id: dev
                            Layout.fillWidth: true
                            Layout.preferredHeight: 60
                            radius: 12

                            color: modelData.connected
                                ? Qt.rgba(btRoot.accent.r, btRoot.accent.g, btRoot.accent.b, 0.14)
                                : (devMa.containsMouse ? Colors.surface_container_highest
                                                       : Colors.surface_container)
                            border.width: modelData.connected ? 1 : 0
                            border.color: Colors.primary
                            Behavior on color { ColorAnimation { duration: 150 } }

                            MouseArea {
                                id: devMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!btRoot.bluetoothEnabled) return
                                    if (modelData.connected) {
                                        modelData.disconnect()
                                    } else {
                                        if (!modelData.paired) modelData.pair()
                                        modelData.connect()
                                    }
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 9
                                anchors.rightMargin: 8
                                spacing: 12

                                Rectangle {
                                    Layout.preferredWidth: 38; Layout.preferredHeight: 38
                                    radius: 19
                                    color: modelData.connected
                                        ? Qt.rgba(btRoot.accent.r, btRoot.accent.g, btRoot.accent.b, 0.18)
                                        : Colors.surface_container_highest
                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: "󰂯"
                                        font.pixelSize: 20
                                        color: modelData.connected
                                            ? Colors.primary
                                            : Colors.on_surface_variant
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData.name || "Unknown device"
                                        elide: Text.ElideRight
                                        font.pixelSize: 14
                                        font.weight: modelData.connected ? Font.DemiBold : Font.Normal
                                    }

                                    StyledText {
                                        text: {
                                            var base = modelData.connected ? "Connected"
                                                : modelData.paired ? "Paired"
                                                : "Available"
                                            if (modelData.connected && !!modelData.batteryAvailable)
                                                base += " · " + Math.round((modelData.battery ?? 0) * 100) + "%"
                                            return base
                                        }
                                        font.pixelSize: 11
                                        color: modelData.connected ? Colors.primary
                                                                   : Colors.on_surface_variant
                                    }
                                }

                                // unpair (paired devices)
                                ClickableRect {
                                    id: unpairRect
                                    visible: modelData.paired
                                    Layout.preferredWidth: 30; Layout.preferredHeight: 30
                                    radius: 15
                                    opacity: (unpairRect.hovered || devMa.containsMouse) ? 1 : 0
                                    color: unpairRect.hovered ? Colors.error_container : "transparent"
                                    Behavior on opacity { NumberAnimation { duration: 120 } }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: "󰚃"
                                        font.pixelSize: 15
                                        color: unpairRect.hovered
                                            ? Colors.on_error_container
                                            : Colors.on_surface_variant
                                    }
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                            mouse.accepted = true
                                            if (modelData.connected) modelData.disconnect()
                                            modelData.forget()
                                        }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
