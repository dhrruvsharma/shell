import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import Quickshell
import qs.services as Services
import "../../colors" as ColorsModule

Item {
    id: btRoot

    readonly property bool adapterPresent: Services.Bluetooth.defaultAdapter !== null
    readonly property bool bluetoothEnabled: Services.Bluetooth.defaultAdapter?.enabled ?? false
    readonly property var activeDevice: Services.Bluetooth.activeDevice
    readonly property color accent: ColorsModule.Colors.primary
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
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 78
            radius: 18
            color: ColorsModule.Colors.surface_container_high
            border.width: 1
            border.color: ColorsModule.Colors.outline_variant

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
                        : ColorsModule.Colors.surface_container_highest
                    Behavior on color { ColorAnimation { duration: 200 } }

                    Text {
                        anchors.centerIn: parent
                        text: btRoot.bluetoothEnabled ? "󰂯" : "󰂲"
                        font.family: "Material Design Icons"
                        font.pixelSize: 24
                        color: btRoot.bluetoothEnabled
                            ? ColorsModule.Colors.primary
                            : ColorsModule.Colors.on_surface_variant
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: btRoot.activeDevice ? (btRoot.activeDevice.name || "Connected device") : "Bluetooth"
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        color: ColorsModule.Colors.on_surface
                    }
                    Text {
                        text: !btRoot.adapterPresent ? "No adapter"
                            : btRoot.activeDevice ? "Connected"
                            : btRoot.bluetoothEnabled ? "On"
                            : "Off"
                        font.pixelSize: 12
                        color: btRoot.activeDevice
                            ? ColorsModule.Colors.primary
                            : ColorsModule.Colors.on_surface_variant
                    }
                }

                // toggle switch
                Rectangle {
                    Layout.preferredWidth: 50
                    Layout.preferredHeight: 28
                    radius: 14
                    opacity: btRoot.adapterPresent ? 1 : 0.4
                    color: btRoot.bluetoothEnabled
                        ? ColorsModule.Colors.primary
                        : ColorsModule.Colors.surface_container_highest
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        width: 22; height: 22; radius: 11
                        y: 3
                        x: btRoot.bluetoothEnabled ? parent.width - width - 3 : 3
                        color: btRoot.bluetoothEnabled
                            ? ColorsModule.Colors.on_primary
                            : ColorsModule.Colors.on_surface_variant
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

            Text {
                Layout.fillWidth: true
                text: btRoot.scanning ? "Scanning for devices…" : "Devices"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                font.letterSpacing: 0.3
                color: ColorsModule.Colors.on_surface_variant
            }

            Rectangle {
                Layout.preferredWidth: 30; Layout.preferredHeight: 30
                radius: 15
                color: scanMa.containsMouse ? ColorsModule.Colors.surface_container_highest : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "󰑐"
                    font.family: "Material Design Icons"
                    font.pixelSize: 16
                    color: btRoot.scanning ? ColorsModule.Colors.primary : ColorsModule.Colors.on_surface_variant
                    RotationAnimator on rotation {
                        from: 0; to: 360; duration: 900; loops: Animation.Infinite
                        running: btRoot.scanning
                    }
                }
                MouseArea {
                    id: scanMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!btRoot.bluetoothEnabled) return
                        Services.Bluetooth.defaultAdapter.discovering = true
                        btRoot.scanning = true
                        scanStopTimer.restart()
                    }
                }
            }
        }

        // ── device list ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 16
            color: ColorsModule.Colors.surface_container_low
            clip: true

            // empty / off state
            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 40
                spacing: 6
                visible: Services.Bluetooth.devices.length === 0

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: btRoot.bluetoothEnabled ? "󰂯" : "󰂲"
                    font.family: "Material Design Icons"
                    font.pixelSize: 42
                    opacity: 0.5
                    color: ColorsModule.Colors.on_surface_variant
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: !btRoot.adapterPresent ? "No Bluetooth adapter"
                        : btRoot.bluetoothEnabled ? "No devices found"
                        : "Bluetooth is off"
                    color: ColorsModule.Colors.on_surface_variant
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
                                : (devMa.containsMouse ? ColorsModule.Colors.surface_container_highest
                                                       : ColorsModule.Colors.surface_container)
                            border.width: modelData.connected ? 1 : 0
                            border.color: ColorsModule.Colors.primary
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
                                        : ColorsModule.Colors.surface_container_highest
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰂯"
                                        font.family: "Material Design Icons"
                                        font.pixelSize: 20
                                        color: modelData.connected
                                            ? ColorsModule.Colors.primary
                                            : ColorsModule.Colors.on_surface_variant
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name || "Unknown device"
                                        elide: Text.ElideRight
                                        font.pixelSize: 14
                                        font.weight: modelData.connected ? Font.DemiBold : Font.Normal
                                        color: ColorsModule.Colors.on_surface
                                    }

                                    Text {
                                        text: {
                                            var base = modelData.connected ? "Connected"
                                                : modelData.paired ? "Paired"
                                                : "Available"
                                            if (modelData.connected && !!modelData.batteryAvailable)
                                                base += " · " + Math.round((modelData.battery ?? 0) * 100) + "%"
                                            return base
                                        }
                                        font.pixelSize: 11
                                        color: modelData.connected ? ColorsModule.Colors.primary
                                                                   : ColorsModule.Colors.on_surface_variant
                                    }
                                }

                                // unpair (paired devices)
                                Rectangle {
                                    visible: modelData.paired
                                    Layout.preferredWidth: 30; Layout.preferredHeight: 30
                                    radius: 15
                                    opacity: (unpairMa.containsMouse || devMa.containsMouse) ? 1 : 0
                                    color: unpairMa.containsMouse ? ColorsModule.Colors.error_container : "transparent"
                                    Behavior on opacity { NumberAnimation { duration: 120 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰚃"
                                        font.family: "Material Design Icons"
                                        font.pixelSize: 15
                                        color: unpairMa.containsMouse
                                            ? ColorsModule.Colors.on_error_container
                                            : ColorsModule.Colors.on_surface_variant
                                    }
                                    MouseArea {
                                        id: unpairMa
                                        anchors.fill: parent
                                        hoverEnabled: true
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
}
