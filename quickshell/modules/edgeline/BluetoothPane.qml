pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.colors
import qs.services as Services
import qs.modules.control

// Bluetooth: the adapter's switch and the devices paired with it (the
// connected ones first, with their battery); a click connects one or lets
// it go. Pairing a new one happens in the network panel's orbit map
// ("Pair a device"), where bluetoothd's questions are answered.
PaneSection {
    id: pane

    title: EdgeWords.word("bluetooth")
    preferredWidth: 296

    readonly property var adapter: Services.Bluetooth.defaultAdapter
    readonly property bool powered: pane.adapter?.enabled ?? false
    readonly property var paired: Services.Bluetooth.devices.filter(d => d.paired || d.bonded).sort((a, b) => (b.connected - a.connected) || String(a.name).localeCompare(String(b.name)))

    function glyph(d) {
        return ({
                "audio-headset": "headset_mic",
                "audio-headphones": "headphones",
                "audio-card": "speaker",
                "multimedia-player": "speaker",
                "phone": "smartphone",
                "modem": "smartphone",
                "computer": "computer",
                "video-display": "tv",
                "input-keyboard": "keyboard",
                "input-mouse": "mouse",
                "input-gaming": "sports_esports",
                "input-tablet": "tablet",
                "printer": "print",
                "camera-photo": "photo_camera",
                "camera-video": "videocam"
            })[d?.icon ?? ""] ?? "bluetooth";
    }

    trailing: [
        PaneSwitch {
            visible: pane.adapter !== null
            checked: pane.powered
            onToggled: {
                if (pane.adapter)
                    pane.adapter.enabled = !pane.adapter.enabled;
            }
        }
    ]

    Column {
        visible: pane.powered
        width: parent.width
        spacing: 4

        Repeater {
            model: ScriptModel {
                values: pane.paired.slice(0, 7)
            }

            PaneRow {
                id: dev
                required property var modelData
                readonly property string work: Services.Bluetooth.busy[dev.modelData.dbusPath] ?? ""
                readonly property bool moving: dev.work !== "" || dev.modelData.state === BluetoothDeviceState.Connecting || dev.modelData.state === BluetoothDeviceState.Disconnecting
                width: parent.width
                icon: pane.glyph(dev.modelData)
                title: dev.modelData.name || dev.modelData.address
                subtitle: dev.moving ? (dev.modelData.connected ? "Letting go…" : "Connecting…")
                    : dev.modelData.connected ? "Connected" : "Paired"
                figure: dev.modelData.connected && dev.modelData.batteryAvailable ? Math.round((dev.modelData.battery ?? 0) * 100) + "%" : ""
                on: dev.modelData.connected
                busy: dev.moving
                onClicked: {
                    if (dev.moving)
                        return;
                    if (dev.modelData.connected)
                        dev.modelData.disconnect();
                    else
                        Services.Bluetooth.connectDevice(dev.modelData);
                }
            }
        }

        Text {
            visible: pane.paired.length === 0
            width: parent.width
            topPadding: 6
            bottomPadding: 6
            horizontalAlignment: Text.AlignHCenter
            text: "Nothing paired yet"
            font.family: ControlStyle.body
            font.pixelSize: 12
            color: Colors.withAlpha(ControlStyle.ink, 0.6)
        }
    }

    Text {
        visible: !pane.powered
        width: parent.width
        topPadding: 4
        bottomPadding: 4
        horizontalAlignment: Text.AlignHCenter
        text: pane.adapter ? "Bluetooth is off" : "No Bluetooth adapter"
        font.family: ControlStyle.body
        font.pixelSize: 12
        color: Colors.withAlpha(ControlStyle.ink, 0.6)
    }

    Item {
        width: parent.width
        height: 26

        PaneChip {
            anchors.right: parent.right
            icon: "add"
            text: "Pair a device"
            onClicked: Services.EdgeLine.request("bluetooth")
        }
    }
}
