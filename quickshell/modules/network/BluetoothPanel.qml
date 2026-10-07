pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Bluetooth
import qs.services as Services
import qs.colors
import qs.components

// The Bluetooth tab: the devices in orbit round this computer (OrbitMap),
// what bluetoothd is asking (BluetoothPrompt), and the devices by how
// they stand: connected, paired, nearby. Click a device to pair it (which
// also trusts and connects it), connect it or disconnect it; hover a
// paired one for trust and remove. The device pointed at is ringed in the
// orbits and lit in the list.
Item {
    id: btRoot

    readonly property var adapter: Services.Bluetooth.defaultAdapter
    readonly property bool adapterPresent: adapter !== null
    readonly property bool bluetoothEnabled: adapter?.enabled ?? false
    readonly property color accent: Services.DesktopTheme.accent
    readonly property color accent2: Services.DesktopTheme.accent2
    // the row under the pointer (a D-Bus path)
    property string hoveredPath: ""

    // Nameless devices (beacons, other people's gadgets) can't be told
    // apart, so only named ones show until they're paired.
    readonly property var shownDevices: Services.Bluetooth.devices
        .filter(d => d.paired || d.connected || d.deviceName !== "")
        .sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1
            if (a.paired !== b.paired) return a.paired ? -1 : 1
            return (a.name || "").localeCompare(b.name || "")
        })
    readonly property var groups: [
        { title: "Connected", devices: shownDevices.filter(d => d.connected && d.paired) },
        { title: "Paired", devices: shownDevices.filter(d => d.paired && !d.connected) },
        { title: "Nearby", devices: shownDevices.filter(d => !d.paired) }
    ]

    // A device clicked here or in the orbits.
    function activate(device) {
        if (!bluetoothEnabled || !device)
            return
        const busy = Services.Bluetooth.busy[device.dbusPath] ?? ""
        if (busy !== "" || device.pairing
            || device.state === BluetoothDeviceState.Connecting
            || device.state === BluetoothDeviceState.Disconnecting)
            return
        if (device.connected)
            device.disconnect()
        else if (device.paired)
            Services.Bluetooth.connectDevice(device)
        else
            Services.Bluetooth.pair(device)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // ── The orbits ──
        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: 206
            radius: Services.DesktopTheme.rad(18)
            color: Colors.surface_container_low

            RowLayout {
                id: orbitHead
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    leftMargin: 14
                    rightMargin: 8
                    topMargin: 6
                }
                height: 30
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: !btRoot.adapterPresent ? "No adapter"
                        : Services.Bluetooth.scanning ? "Looking for devices…"
                        : btRoot.adapter.discoverable ? "Visible as " + (btRoot.adapter.name || "this computer")
                        : (btRoot.adapter.name || "This computer")
                    textFormat: Text.PlainText
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Services.Bluetooth.scanning || btRoot.adapter?.discoverable
                        ? btRoot.accent2 : Colors.withAlpha(Colors.on_surface_variant, 0.75)
                }

                // discoverable: lets a phone find this computer and pair from there
                ClickableRect {
                    id: visibleRect
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: Services.DesktopTheme.rad(14)
                    enabled: btRoot.bluetoothEnabled
                    opacity: enabled ? 1 : 0.4
                    color: visibleRect.hovered ? Colors.surface_container_high : "transparent"
                    MaterialIcon {
                        anchors.centerIn: parent
                        text: btRoot.adapter?.discoverable ? "󰈈" : "󰈉"
                        font.pixelSize: 15
                        color: btRoot.adapter?.discoverable ? btRoot.accent2 : Colors.on_surface_variant
                    }
                    cursorShape: Qt.PointingHandCursor
                    onClicked: btRoot.adapter.discoverable = !btRoot.adapter.discoverable
                }

                ClickableRect {
                    id: scanRect
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: Services.DesktopTheme.rad(14)
                    enabled: btRoot.bluetoothEnabled
                    opacity: enabled ? 1 : 0.4
                    color: scanRect.hovered ? Colors.surface_container_high : "transparent"
                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "󰑐"
                        font.pixelSize: 15
                        color: Services.Bluetooth.scanning ? btRoot.accent2 : Colors.on_surface_variant
                        RotationAnimator on rotation {
                            from: 0; to: 360; duration: 900; loops: Animation.Infinite
                            running: Services.Bluetooth.scanning
                        }
                    }
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Services.Bluetooth.scan()
                }
            }

            OrbitMap {
                id: orbitMap
                anchors {
                    left: parent.left
                    right: parent.right
                    top: orbitHead.bottom
                    bottom: parent.bottom
                    leftMargin: 10
                    rightMargin: 10
                    bottomMargin: 10
                }
                devices: btRoot.bluetoothEnabled ? btRoot.shownDevices : []
                powered: btRoot.bluetoothEnabled
                scanning: Services.Bluetooth.scanning
                discoverable: btRoot.adapter?.discoverable ?? false
                busy: Services.Bluetooth.busy
                highlight: btRoot.hoveredPath
                onPicked: device => btRoot.activate(device)
            }

            // nothing in orbit
            Column {
                anchors.horizontalCenter: orbitMap.horizontalCenter
                y: orbitMap.y + orbitMap.cy + 30
                spacing: 8
                visible: !btRoot.bluetoothEnabled || btRoot.shownDevices.length === 0

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: !btRoot.adapterPresent ? "No Bluetooth adapter"
                        : !btRoot.bluetoothEnabled ? "Bluetooth is off"
                        : Services.Bluetooth.scanning ? "Looking…"
                        : "Nothing paired yet: scan to find a device"
                    font.pixelSize: 11
                    color: Colors.withAlpha(Colors.on_surface_variant, 0.8)
                }
                ClickableRect {
                    id: btOn
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: btRoot.adapterPresent && !btRoot.bluetoothEnabled
                    width: btOnText.implicitWidth + 28
                    height: 28
                    radius: Services.DesktopTheme.rad(14)
                    color: btOn.hovered ? btRoot.accent : "transparent"
                    border.width: 1
                    border.color: Colors.withAlpha(btRoot.accent, 0.7)
                    StyledText {
                        id: btOnText
                        anchors.centerIn: parent
                        text: "Turn on Bluetooth"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: btOn.hovered ? Colors.on_primary : btRoot.accent
                    }
                    cursorShape: Qt.PointingHandCursor
                    onClicked: btRoot.adapter.enabled = true
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

        // ── The devices, by how they stand ──
        Flickable {
            id: deviceList
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: btRoot.bluetoothEnabled
            clip: true
            contentWidth: width
            contentHeight: groupColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: StyledScrollBar { handleColor: btRoot.accent }

            Column {
                id: groupColumn
                width: deviceList.width
                spacing: 8

                Repeater {
                    model: btRoot.groups

                    delegate: Column {
                        id: group
                        required property var modelData
                        width: groupColumn.width
                        visible: modelData.devices.length > 0
                        spacing: 2

                        RowLayout {
                            width: parent.width
                            height: 22
                            spacing: 6

                            StyledText {
                                Layout.leftMargin: 4
                                text: group.modelData.title
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                font.letterSpacing: 1.4
                                font.capitalization: Font.AllUppercase
                                color: Colors.withAlpha(Colors.on_surface_variant, 0.8)
                            }
                            StyledText {
                                text: group.modelData.devices.length
                                font.pixelSize: 10
                                font.features: ({ "tnum": 1 })
                                color: Colors.withAlpha(Colors.on_surface_variant, 0.5)
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                Layout.leftMargin: 4
                                color: Colors.withAlpha(Colors.outline_variant, 0.6)
                            }
                        }

                        Repeater {
                            model: group.modelData.devices
                            delegate: DeviceRow {}
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !btRoot.bluetoothEnabled
        }
    }

    // A device: its disc as in the orbits, its name and how it stands.
    component DeviceRow: Rectangle {
        id: dev

        required property var modelData

        readonly property string path: modelData.dbusPath
        readonly property string busy: Services.Bluetooth.busy[path] ?? ""
        readonly property bool pairing: busy === "pairing" || modelData.pairing
        readonly property bool connecting: busy === "connecting"
            || modelData.state === BluetoothDeviceState.Connecting
        readonly property bool working: pairing || connecting
            || modelData.state === BluetoothDeviceState.Disconnecting
        readonly property string error: Services.Bluetooth.errors[path]?.text ?? ""
        readonly property bool linked: modelData.connected && modelData.paired
        readonly property bool lit: devMouse.containsMouse || orbitMap.hoverPath === path

        width: groupColumn.width
        height: 52
        radius: Services.DesktopTheme.rad(12)
        color: lit ? Colors.surface_container_high : "transparent"
        Behavior on color { ColorAnimation { duration: 140 } }

        MouseArea {
            id: devMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: dev.working ? Qt.ArrowCursor : Qt.PointingHandCursor
            onContainsMouseChanged: {
                if (containsMouse)
                    btRoot.hoveredPath = dev.path
                else if (btRoot.hoveredPath === dev.path)
                    btRoot.hoveredPath = ""
            }
            onClicked: btRoot.activate(dev.modelData)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 8
            spacing: 12

            Item {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: dev.linked ? btRoot.accent
                        : dev.modelData.paired ? Colors.surface_container_highest
                        : "transparent"
                    border.width: dev.lit ? 1.5 : 1
                    border.color: dev.lit ? btRoot.accent2
                        : dev.linked ? "transparent"
                        : Colors.withAlpha(Colors.on_surface_variant, 0.3)

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: Services.Bluetooth.glyphFor(dev.modelData)
                        font.pixelSize: 17
                        color: dev.linked ? Colors.on_primary
                            : dev.modelData.paired ? Colors.on_surface
                            : Colors.on_surface_variant
                    }
                }
                Spinner {
                    anchors.centerIn: parent
                    width: parent.width + 6
                    visible: dev.working
                    border.width: 1.5
                    arcColor: btRoot.accent2
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: dev.modelData.name || "Unknown device"
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font.pixelSize: 14
                    font.weight: dev.linked ? Font.DemiBold : Font.Normal
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
                            return dev.modelData.trusted ? "Trusted · click to revoke" : "Trust: let it connect by itself"
                        if (unpairRect.hovered) return "Remove this device"
                        if (dev.modelData.connected)
                            return devMouse.containsMouse ? "Click to disconnect" : "Connected"
                        if (dev.modelData.paired) {
                            if (devMouse.containsMouse) return "Click to connect"
                            return dev.modelData.trusted ? "Paired" : "Paired · not trusted"
                        }
                        return devMouse.containsMouse ? "Click to pair" : "Not paired"
                    }
                    font.pixelSize: 11
                    color: dev.error && !dev.working ? Colors.error
                        : dev.working ? btRoot.accent2
                        : dev.modelData.connected ? btRoot.accent
                        : Colors.withAlpha(Colors.on_surface_variant, 0.8)
                }
            }

            // the battery, while connected
            Row {
                visible: dev.linked && dev.modelData.batteryAvailable && !devMouse.containsMouse
                spacing: 4

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 9
                    radius: 2
                    color: "transparent"
                    border.width: 1
                    border.color: Colors.withAlpha(btRoot.accent2, 0.7)

                    Rectangle {
                        x: 2
                        y: 2
                        height: parent.height - 4
                        width: (parent.width - 4) * Math.max(0, Math.min(1, dev.modelData.battery ?? 0))
                        radius: 1
                        color: btRoot.accent2
                    }
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round((dev.modelData.battery ?? 0) * 100) + "%"
                    font.pixelSize: 11
                    font.features: ({ "tnum": 1 })
                    color: btRoot.accent2
                }
            }

            // stop a pairing in progress
            ClickableRect {
                id: cancelRect
                visible: dev.pairing
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: Services.DesktopTheme.rad(14)
                color: cancelRect.hovered ? Colors.surface_container_highest : "transparent"

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "󰅖"
                    font.pixelSize: 15
                    color: Colors.on_surface_variant
                }
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.Bluetooth.cancelPairing(dev.modelData)
            }

            // trust: may it connect by itself, without asking
            ClickableRect {
                id: trustRect
                visible: dev.modelData.paired && !dev.working
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: Services.DesktopTheme.rad(14)
                opacity: (trustRect.hovered || devMouse.containsMouse) ? 1 : 0
                color: trustRect.hovered ? Colors.surface_container_highest : "transparent"
                Behavior on opacity { NumberAnimation { duration: 120 } }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: dev.modelData.trusted ? "󰕥" : "󰒙"
                    font.pixelSize: 15
                    color: dev.modelData.trusted ? btRoot.accent : Colors.on_surface_variant
                }
                cursorShape: Qt.PointingHandCursor
                onClicked: dev.modelData.trusted = !dev.modelData.trusted
            }

            // unpair (paired devices)
            ClickableRect {
                id: unpairRect
                visible: dev.modelData.paired && !dev.working
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: Services.DesktopTheme.rad(14)
                opacity: (unpairRect.hovered || devMouse.containsMouse) ? 1 : 0
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
                onClicked: {
                    if (dev.modelData.connected) dev.modelData.disconnect()
                    dev.modelData.forget()
                }
            }
        }
    }
}
