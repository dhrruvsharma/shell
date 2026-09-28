import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Bluetooth
import qs.services as Services
import qs.colors
import qs.components

Item {
    id: btRoot

    readonly property var adapter: Services.Bluetooth.defaultAdapter
    readonly property bool adapterPresent: adapter !== null
    readonly property bool bluetoothEnabled: adapter?.enabled ?? false
    readonly property var activeDevice: Services.Bluetooth.activeDevice
    readonly property color accent: Colors.primary

    // Nameless devices (beacons, other people's gadgets) can't be told
    // apart, so only named ones show until they're paired.
    readonly property var shownDevices: Services.Bluetooth.devices
        .filter(d => d.paired || d.connected || d.deviceName !== "")
        .sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1
            if (a.paired !== b.paired) return a.paired ? -1 : 1
            return (a.name || "").localeCompare(b.name || "")
        })

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // ── Hero status card ──
        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: 78
            radius: Services.DesktopTheme.rad(18)
            color: Colors.surface_container_high

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 14
                spacing: 14

                Rectangle {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    radius: Services.DesktopTheme.rad(24)
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
                    radius: Services.DesktopTheme.rad(14)
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
                            btRoot.adapter.enabled = !btRoot.adapter.enabled
                        }
                    }
                }
            }
        }

        // ── what bluetoothd is asking (a code, a device wanting in) ──
        Loader {
            Layout.fillWidth: true
            active: Services.Bluetooth.request !== null
            visible: active
            sourceComponent: BluetoothPrompt {
                request: Services.Bluetooth.request
            }
        }

        // ── list header ──
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 4
            visible: btRoot.bluetoothEnabled

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: Services.Bluetooth.scanning ? "Scanning for devices…"
                    : btRoot.adapter?.discoverable ? "Visible as " + (btRoot.adapter.name || "this computer")
                    : "Devices"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                font.letterSpacing: 0.3
                color: Colors.on_surface_variant
            }

            // discoverable: lets a phone find this computer and pair from there
            ClickableRect {
                id: visibleRect
                Layout.preferredWidth: 30; Layout.preferredHeight: 30
                radius: Services.DesktopTheme.rad(15)
                color: visibleRect.hovered ? Colors.surface_container_highest : "transparent"
                MaterialIcon {
                    anchors.centerIn: parent
                    text: btRoot.adapter?.discoverable ? "󰈈" : "󰈉"
                    font.pixelSize: 16
                    color: btRoot.adapter?.discoverable ? Colors.primary : Colors.on_surface_variant
                }
                cursorShape: Qt.PointingHandCursor
                onClicked: btRoot.adapter.discoverable = !btRoot.adapter.discoverable
            }

            ClickableRect {
                id: scanRect
                Layout.preferredWidth: 30; Layout.preferredHeight: 30
                radius: Services.DesktopTheme.rad(15)
                color: scanRect.hovered ? Colors.surface_container_highest : "transparent"
                MaterialIcon {
                    anchors.centerIn: parent
                    text: "󰑐"
                    font.pixelSize: 16
                    color: Services.Bluetooth.scanning ? Colors.primary : Colors.on_surface_variant
                    RotationAnimator on rotation {
                        from: 0; to: 360; duration: 900; loops: Animation.Infinite
                        running: Services.Bluetooth.scanning
                    }
                }
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.Bluetooth.scan()
            }
        }

        // ── device list ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Services.DesktopTheme.rad(16)
            color: Colors.surface_container_low
            clip: true

            // empty / off state
            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 40
                spacing: 6
                visible: !btRoot.bluetoothEnabled || btRoot.shownDevices.length === 0

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
                        : !btRoot.bluetoothEnabled ? "Bluetooth is off"
                        : Services.Bluetooth.scanning ? "Looking for devices…"
                        : "No devices found"
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
                        model: btRoot.shownDevices

                        delegate: Rectangle {
                            id: dev
                            Layout.fillWidth: true
                            Layout.preferredHeight: 60
                            radius: Services.DesktopTheme.rad(12)

                            readonly property string path: modelData.dbusPath
                            readonly property string busy: Services.Bluetooth.busy[path] ?? ""
                            readonly property bool pairing: busy === "pairing" || modelData.pairing
                            readonly property bool connecting: busy === "connecting"
                                || modelData.state === BluetoothDeviceState.Connecting
                            readonly property bool working: pairing || connecting
                                || modelData.state === BluetoothDeviceState.Disconnecting
                            readonly property string error: Services.Bluetooth.errors[path]?.text ?? ""

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
                                cursorShape: dev.working ? Qt.ArrowCursor : Qt.PointingHandCursor
                                onClicked: {
                                    if (!btRoot.bluetoothEnabled || dev.working) return
                                    if (modelData.connected)
                                        modelData.disconnect()
                                    else if (modelData.paired)
                                        Services.Bluetooth.connectDevice(modelData)
                                    else
                                        Services.Bluetooth.pair(modelData)
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 9
                                anchors.rightMargin: 8
                                spacing: 12

                                Rectangle {
                                    Layout.preferredWidth: 38; Layout.preferredHeight: 38
                                    radius: Services.DesktopTheme.rad(19)
                                    color: modelData.connected || dev.working
                                        ? Qt.rgba(btRoot.accent.r, btRoot.accent.g, btRoot.accent.b, 0.18)
                                        : Colors.surface_container_highest
                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        visible: !dev.working
                                        text: Services.Bluetooth.glyphFor(modelData)
                                        font.pixelSize: 20
                                        color: modelData.connected
                                            ? Colors.primary
                                            : Colors.on_surface_variant
                                    }
                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        visible: dev.working
                                        text: "󰑐"
                                        font.pixelSize: 20
                                        color: Colors.primary
                                        RotationAnimator on rotation {
                                            from: 0; to: 360; duration: 900; loops: Animation.Infinite
                                            running: dev.working
                                        }
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
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        text: {
                                            if (dev.pairing) return "Pairing…"
                                            if (dev.connecting) return "Connecting…"
                                            if (dev.working) return "Disconnecting…"
                                            if (dev.error) return dev.error
                                            // the buttons explain themselves while hovered
                                            if (trustRect.hovered)
                                                return modelData.trusted ? "Trusted · click to revoke" : "Trust: let it connect by itself"
                                            if (unpairRect.hovered) return "Remove this device"
                                            if (modelData.connected) {
                                                let text = "Connected"
                                                if (modelData.batteryAvailable)
                                                    text += " · " + Math.round((modelData.battery ?? 0) * 100) + "%"
                                                return text
                                            }
                                            if (modelData.paired) {
                                                if (devMa.containsMouse) return "Click to connect"
                                                return modelData.trusted ? "Paired" : "Paired · not trusted"
                                            }
                                            return devMa.containsMouse ? "Click to pair" : "Not paired"
                                        }
                                        font.pixelSize: 11
                                        color: dev.error && !dev.working ? Colors.error
                                            : modelData.connected || dev.working ? Colors.primary
                                            : Colors.on_surface_variant
                                    }
                                }

                                // stop a pairing in progress
                                ClickableRect {
                                    id: cancelRect
                                    visible: dev.pairing
                                    Layout.preferredWidth: 30; Layout.preferredHeight: 30
                                    radius: Services.DesktopTheme.rad(15)
                                    color: cancelRect.hovered ? Colors.surface_container_highest : "transparent"

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: "󰅖"
                                        font.pixelSize: 15
                                        color: Colors.on_surface_variant
                                    }
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                            mouse.accepted = true
                                            Services.Bluetooth.cancelPairing(modelData)
                                        }
                                }

                                // trust: may it connect by itself, without asking
                                ClickableRect {
                                    id: trustRect
                                    visible: modelData.paired && !dev.working
                                    Layout.preferredWidth: 30; Layout.preferredHeight: 30
                                    radius: Services.DesktopTheme.rad(15)
                                    opacity: (trustRect.hovered || devMa.containsMouse) ? 1 : 0
                                    color: trustRect.hovered ? Colors.surface_container_highest : "transparent"
                                    Behavior on opacity { NumberAnimation { duration: 120 } }

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: modelData.trusted ? "󰕥" : "󰒙"
                                        font.pixelSize: 15
                                        color: modelData.trusted ? Colors.primary : Colors.on_surface_variant
                                    }
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                            mouse.accepted = true
                                            modelData.trusted = !modelData.trusted
                                        }
                                }

                                // unpair (paired devices)
                                ClickableRect {
                                    id: unpairRect
                                    visible: modelData.paired && !dev.working
                                    Layout.preferredWidth: 30; Layout.preferredHeight: 30
                                    radius: Services.DesktopTheme.rad(15)
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
