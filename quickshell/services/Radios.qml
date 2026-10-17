pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services as Services

// The radios' kill switches (rfkill), for airplane mode: on when every
// radio is blocked, by software or by a hardware switch. Read with
// `rfkill -J` when this starts, after each switch, when the control centre
// opens and whenever NetworkManager or bluetoothd see their radio change
// (they follow rfkill), so a key on the keyboard shows up too.
Singleton {
    id: root

    // [{ type: "wlan" | "bluetooth" | …, soft: bool, hard: bool }]
    property var devices: []
    readonly property bool airplane: devices.length > 0 && devices.every(d => d.soft || d.hard)
    readonly property bool bluetoothBlocked: devices.some(d => d.type === "bluetooth" && (d.soft || d.hard))
    readonly property bool busy: switchProc.running

    function refresh(): void {
        if (readProc.running)
            _again = true;
        else
            readProc.running = true;
    }

    function setAirplane(on: bool): void {
        if (!switchProc.running)
            switchProc.exec(["rfkill", on ? "block" : "unblock", "all"]);
    }

    function toggleAirplane(): void {
        setAirplane(!airplane);
    }

    // Turns Bluetooth on, lifting its block first if airplane mode (or a
    // key) left it blocked; bluetoothd refuses to power a blocked adapter.
    function enableBluetooth(): void {
        const adapter = Services.Bluetooth.defaultAdapter;
        if (!bluetoothBlocked) {
            if (adapter)
                adapter.enabled = true;
            return;
        }
        _powerAfterUnblock = true;
        switchProc.exec(["rfkill", "unblock", "bluetooth"]);
    }

    property bool _again: false
    property bool _powerAfterUnblock: false

    Process {
        id: readProc
        running: true
        command: ["rfkill", "-J"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text).rfkilldevices ?? [];
                    root.devices = list.map(d => ({
                        type: d.type,
                        soft: d.soft === "blocked",
                        hard: d.hard === "blocked"
                    }));
                } catch (e) {
                    root.devices = [];
                }
            }
        }
        onExited: {
            if (root._again) {
                root._again = false;
                running = true;
            }
        }
    }

    Process {
        id: switchProc
        onExited: {
            root.refresh();
            if (root._powerAfterUnblock)
                powerLater.restart();
        }
    }

    // bluetoothd takes a moment to see the block lifted.
    Timer {
        id: powerLater
        interval: 400
        onTriggered: {
            root._powerAfterUnblock = false;
            if (Services.Bluetooth.defaultAdapter)
                Services.Bluetooth.defaultAdapter.enabled = true;
        }
    }

    Connections {
        target: Services.Network
        function onWifiEnabledChanged() {
            root.refresh();
        }
    }

    Connections {
        target: Services.Bluetooth.defaultAdapter
        function onStateChanged() {
            root.refresh();
        }
    }
}
