pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

// Bluetooth state from Quickshell.Bluetooth, plus the pairing agent in
// scripts/bluetooth_agent.py. Quickshell registers no BlueZ agent, and
// without one bluetoothd refuses PIN/passkey pairing and turns away the
// connections an untrusted device makes by itself. The agent passes
// bluetoothd's questions to `requests` (answered with respond()) and runs
// Pair/Connect so their errors land in `errors`. If it can't run, pairing
// falls back to Quickshell's own pair(), which only manages "just works".
Singleton {
    id: root

    readonly property BluetoothAdapter defaultAdapter: Bluetooth.defaultAdapter
    readonly property list<BluetoothDevice> devices: defaultAdapter?.devices?.values ?? []
    // A device being paired is connected too; prefer one that's set up.
    readonly property BluetoothDevice activeDevice: devices.find(d => d.connected && d.paired)
        ?? devices.find(d => d.connected) ?? null
    readonly property string icon: {
        if (!defaultAdapter?.enabled) {
            return "bluetooth_disabled"
        }

        if (activeDevice) {
            return "bluetooth_connected"
        }

        return defaultAdapter.discovering ? "bluetooth_searching" : "bluetooth"
    }

    readonly property bool scanning: defaultAdapter?.discovering ?? false

    // The agent is registered with bluetoothd.
    property bool agentReady: false
    // bluetoothd's questions waiting on the user, oldest first: {id, kind,
    // device, …} as scripts/bluetooth_agent.py describes. The panel shows
    // `request`.
    property var requests: []
    readonly property var request: requests.length > 0 ? requests[0] : null
    // dbusPath -> "pairing" | "connecting" while the agent works on a device
    property var busy: ({})
    // dbusPath -> {text, until}: why its last pair or connect failed
    property var errors: ({})

    // A new question came in; shell.qml brings up the Bluetooth tab for it.
    signal requestArrived()

    function deviceFor(path: string): BluetoothDevice {
        return devices.find(d => d.dbusPath === path) ?? null
    }

    // The device's name, else its address ("…/dev_AA_BB_…" -> "AA:BB:…").
    function nameOf(path: string): string {
        return deviceFor(path)?.name
            || path.slice(path.lastIndexOf("/") + 1).replace(/^dev_/, "").replace(/_/g, ":")
    }

    // A glyph for BlueZ's device class icon name.
    function glyphFor(device: BluetoothDevice): string {
        switch (device?.icon ?? "") {
        case "audio-headset": return "󰋎"
        case "audio-headphones": return "󰋋"
        case "audio-card":
        case "multimedia-player": return "󰓃"
        case "phone":
        case "modem": return "󰄜"
        case "computer": return "󰌢"
        case "video-display": return "󰍹"
        case "input-keyboard": return "󰌌"
        case "input-mouse": return "󰍽"
        case "input-gaming": return "󰊗"
        case "input-tablet": return "󰓶"
        case "printer":
        case "scanner": return "󰐪"
        case "camera-photo":
        case "camera-video": return "󰄀"
        case "network-wireless": return "󰀃"
        default: return "󰂯"
        }
    }

    function scan(): void {
        if (!defaultAdapter?.enabled)
            return
        defaultAdapter.discovering = true
        scanTimer.restart()
    }

    // Stops a scan started by scan(); inquiry slows pairing and connecting.
    function stopScan(): void {
        if (!scanTimer.running)
            return
        scanTimer.stop()
        if (defaultAdapter?.discovering)
            defaultAdapter.discovering = false
    }

    // Pairs, trusts, then connects.
    function pair(device: BluetoothDevice): void {
        if (!device || device.paired || busy[device.dbusPath])
            return
        stopScan()
        setError(device.dbusPath, "")
        if (agentReady) {
            setBusy(device.dbusPath, "pairing")
            send({ cmd: "pair", device: device.dbusPath })
            return
        }
        // Trusted up front: with no agent nothing could allow the device's
        // own connections once it's paired.
        device.trusted = true
        fallback.target = device
        device.pair()
    }

    function connectDevice(device: BluetoothDevice): void {
        if (!device || device.connected || busy[device.dbusPath])
            return
        stopScan()
        setError(device.dbusPath, "")
        if (agentReady) {
            setBusy(device.dbusPath, "connecting")
            send({ cmd: "connect", device: device.dbusPath })
        } else {
            device.connect()
        }
    }

    function cancelPairing(device: BluetoothDevice): void {
        if (agentReady) {
            send({ cmd: "cancel", device: device.dbusPath })
            return
        }
        if (fallback.target === device)
            fallback.target = null
        device.cancelPair()
    }

    // Answers `request`: value is a typed PIN/passkey, always also trusts
    // a device asking for a service. Refusing a code on show stops pairing.
    function respond(accept: bool, value: string, always: bool): void {
        const req = request
        if (!req)
            return
        requests = requests.filter(r => r.id !== req.id)
        send({ cmd: "reply", id: req.id, accept: accept, value: value, always: always })
    }

    function send(msg: var): void {
        if (agent.running)
            agent.write(JSON.stringify(msg) + "\n")
    }

    function setBusy(path: string, what: string): void {
        const next = Object.assign({}, busy)
        if (what)
            next[path] = what
        else
            delete next[path]
        busy = next
    }

    function setError(path: string, text: string): void {
        if (!text && !(path in errors))
            return
        const next = Object.assign({}, errors)
        if (text)
            next[path] = { text: text, until: Date.now() + 15000 }
        else
            delete next[path]
        errors = next
    }

    function handle(line: string): void {
        let msg
        try {
            msg = JSON.parse(line)
        } catch (e) {
            console.warn("bluetooth agent:", line)
            return
        }

        switch (msg.event) {
        case "ready":
            agentReady = true
            restartTimer.interval = 2000
            break
        case "down":
            agentReady = false
            requests = []
            busy = ({})
            break
        case "request": {
            // show-passkey comes again under its id as digits are typed
            const i = requests.findIndex(r => r.id === msg.id)
            if (i >= 0) {
                const next = requests.slice()
                next[i] = msg
                requests = next
            } else {
                requests = requests.concat([msg])
                requestArrived()
            }
            break
        }
        case "cancel":
            requests = requests.filter(r => r.id !== msg.id)
            break
        case "result":
            // a pairing goes straight on to connecting
            setBusy(msg.device, msg.op === "pair" && msg.ok ? "connecting" : "")
            setError(msg.device, msg.error)
            break
        }
    }

    Process {
        id: agent
        command: ["python3", Quickshell.shellDir + "/scripts/bluetooth_agent.py"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => root.handle(line)
        }
        stderr: SplitParser {
            onRead: line => console.warn("bluetooth agent:", line)
        }
        onExited: code => {
            root.agentReady = false
            root.requests = []
            root.busy = ({})
            // 2: PyGObject is missing, and will still be on the next try
            if (code !== 2)
                restartTimer.start()
        }
    }

    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: {
            interval = Math.min(interval * 2, 300000)
            agent.running = true
        }
    }

    Timer {
        id: scanTimer
        interval: 10000
        onTriggered: {
            if (root.defaultAdapter?.discovering)
                root.defaultAdapter.discovering = false
        }
    }

    // Drops errors once they've had their time on screen.
    Timer {
        interval: 1000
        repeat: true
        running: Object.keys(root.errors).length > 0
        onTriggered: {
            const now = Date.now()
            const live = {}
            let dropped = false
            for (const path in root.errors) {
                if (root.errors[path].until > now)
                    live[path] = root.errors[path]
                else
                    dropped = true
            }
            if (dropped)
                root.errors = live
        }
    }

    // Without the agent: once Quickshell's pair() lands, connect.
    Connections {
        id: fallback
        target: null

        function onPairedChanged() {
            const device = fallback.target
            if (!device?.paired)
                return
            fallback.target = null
            device.connect()
        }

        function onPairingChanged() {
            const device = fallback.target
            if (!device || device.pairing)
                return
            // bluetoothd's reply can beat the Paired change; look again after
            Qt.callLater(() => {
                if (fallback.target !== device || device.paired)
                    return
                fallback.target = null
                root.setError(device.dbusPath, "Pairing failed")
            })
        }
    }
}
