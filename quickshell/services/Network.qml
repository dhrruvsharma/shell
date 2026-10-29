pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Wi-Fi and wired connections through nmcli. `connections` holds one entry
// per SSID (the access point in use, else its strongest) plus the wired and
// tethered profiles (read by scripts/network-links.py); `accessPoints` is
// every radio nmcli hears, hidden ones included, which the network panel
// sets out on its fan. NetworkManager's own changes (a phone plugged in, a
// cable pulled) are followed through `nmcli monitor`.
Singleton {
    id: root

    readonly property list<Connection> connections: []
    readonly property list<string> savedNetworks: []
    readonly property Connection active: connections.find(c => c.active) ?? null
    readonly property Connection activeWifi: connections.find(c => c.active && c.type === "wifi") ?? null
    // the wired, USB-tethered, Bluetooth-tethered and mobile profiles, the
    // ones up first
    readonly property var wiredLinks: connections.filter(c => c.type !== "wifi")
    // the device the default route goes through (what carries the traffic),
    // and the connection on it
    property string primaryDevice: ""
    readonly property Connection primary: connections.find(c => c.active && c.device !== "" && c.device === primaryDevice) ?? active
    // Every access point in the last scan: { ssid, bssid, signal, frequency,
    // band ("2.4" | "5" | "6"), channel, bandwidth (MHz), rate (Mbit/s),
    // security, device, active, saved }. Hidden networks have no ssid.
    property var accessPoints: []

    property bool wifiEnabled: true
    readonly property bool scanning: rescanProc.running
    readonly property bool connecting: connectProc.running
    // a wired or tethered link being brought up or taken down
    readonly property bool linking: ethConnectProc.running || ethDisconnectProc.running
    // When the last scan finished (ms since the epoch); 0 before the first.
    property real lastScan: 0

    property string lastNetworkAttempt: ""
    // the band asked for in the last attempt ("" if NetworkManager chose)
    property string lastBandAttempt: ""
    property string lastErrorMessage: ""
    property string message: ""
    // a profile just made on one access point, to be let go of it once up
    property string _unpin: ""

    // The Wi-Fi interface in use, and its IPv4 address and gateway.
    readonly property string wifiDevice: accessPoints.find(a => a.active)?.device ?? ""
    property string ipAddress: ""
    property string gateway: ""

    // Bytes a second through wifiDevice, sampled every second while
    // `watchTraffic` is set (the network panel, while it shows them), and
    // the last minute of samples, oldest first.
    property bool watchTraffic: false
    property real rxRate: 0
    property real txRate: 0
    property var rxHistory: []
    property var txHistory: []
    property var _lastTraffic: null

    readonly property string icon: {
        const p = primary;
        if (!p) return "󰤭";
        if (p.type !== "wifi") return kindIcon(p.kind);

        if (p.strength >= 75) return "󰤨";
        else if (p.strength >= 50) return "󰤥";
        else if (p.strength >= 25) return "󰤢";
        else return "󰤟";
    }

    readonly property string wifiLabel: {
        if (primary && primary.type !== "wifi") return primary.title;
        if (activeWifi) return activeWifi.name;
        return "Wi-Fi";
    }

    readonly property string wifiStatus: {
        if (activeWifi) return "Connected";
        if (wifiEnabled) return "On";
        return "Off";
    }

    readonly property string label: {
        if (active) return active.name;
        if (wifiEnabled) return "Wi-Fi";
        return "Wi-Fi";
    }

    readonly property string status: {
        if (active) return "Connected";
        if (wifiEnabled) return "On";
        return "Off";
    }

    onWifiDeviceChanged: refreshAddress()
    onActiveChanged: refreshAddress()

    // A link's glyph by its kind ("ethernet" | "usb" | "bluetooth" | "mobile").
    function kindIcon(kind: string): string {
        if (kind === "usb") return "󰕓";
        if (kind === "bluetooth") return "󰂯";
        if (kind === "mobile") return "󰄜";
        return "󰈀";
    }

    function enableWifi(enabled: bool): void {
        enableWifiProc.exec(["nmcli", "radio", "wifi", enabled ? "on" : "off"]);
    }

    function toggleWifi(): void {
        enableWifi(!wifiEnabled);
    }

    function rescan(): void {
        rescanProc.running = true;
    }

    // Fresh state for the panel: what NetworkManager knows now, then a scan
    // if the last one is more than half a minute old.
    function refresh(): void {
        getWifiStatus();
        updateConnections();
        refreshAddress();
        if (wifiEnabled && Date.now() - lastScan > 30000)
            rescan();
    }

    function refreshAddress(): void {
        if (wifiDevice === "") {
            ipAddress = "";
            gateway = "";
            return;
        }
        addressProc.exec(["nmcli", "-g", "IP4.ADDRESS,IP4.GATEWAY", "device", "show", wifiDevice]);
    }

    // The strongest access point of `ssid` on each band it's on, in band
    // order: [{ band, signal, channel, bssid, active }].
    function reachOf(ssid: string): var {
        const best = {};
        for (const a of accessPoints) {
            if (a.ssid !== ssid)
                continue;
            const seen = best[a.band];
            if (!seen || (a.active && !seen.active) || (!seen.active && a.signal > seen.signal))
                best[a.band] = a;
        }
        return ["2.4", "5", "6"].filter(b => best[b]).map(b => ({
            band: b,
            signal: best[b].signal,
            channel: best[b].channel,
            bssid: best[b].bssid,
            active: best[b].active
        }));
    }

    // Joins a network: on `band` ("2.4" | "5" | "6") by way of its strongest
    // access point there, else ("") wherever NetworkManager likes.
    function connect(connection: Connection, password: string, band: string): void {
        if (connection.type === "wifi") {
            root.lastNetworkAttempt = connection.name;
            root.lastBandAttempt = band;
            root.lastErrorMessage = "";
            root.message = "";
            root._unpin = "";

            const ap = band !== "" ? reachOf(connection.name).find(r => r.band === band) : null;
            if (ap && connection.saved) {
                // the profile as it is, on that access point this once
                connectProc.exec(["nmcli", "connection", "up", "id", connection.name, "ap", ap.bssid]);
                return;
            }
            const command = ["nmcli", "dev", "wifi", "connect", connection.name];
            if (password && password.length > 0)
                command.push("password", password);
            if (ap) {
                // a new profile made this way is tied to the access point;
                // it's let go once up, so it isn't held to one band for good
                command.push("bssid", ap.bssid, "name", connection.name);
                root._unpin = connection.name;
            }
            connectProc.exec(command);
        } else {
            root.lastNetworkAttempt = connection.name;
            root.lastBandAttempt = "";
            root.lastErrorMessage = "";
            ethConnectProc.exec(["nmcli", "connection", "up", connection.uuid]);
        }
    }

    function forget(name: string): void {
        forgetProc.exec(["nmcli", "connection", "delete", name]);
    }

    // Takes down `connection`, else the active one.
    function disconnect(connection: var): void {
        const c = connection ?? active;
        if (!c) return;

        if (c.type === "wifi") {
            disconnectProc.exec(["nmcli", "connection", "down", c.name]);
        } else {
            ethDisconnectProc.exec(["nmcli", "connection", "down", c.uuid]);
        }
    }

    function getWifiStatus(): void {
        wifiStatusProc.running = true;
    }

    function updateConnections(): void {
        getSavedNetworks.running = true;
    }

    function bandOf(frequency: int): string {
        return frequency < 3000 ? "2.4" : frequency < 5925 ? "5" : "6";
    }

    function mergeConnections(newConns: var, connType: string): void {
        const rConns = root.connections;
        const same = (a, b) => connType === "wifi"
            ? (a.frequency === b.frequency && a.name === b.name && a.bssid === b.bssid)
            : a.uuid === b.uuid;
        const ofType = c => connType === "wifi" ? c.type === "wifi" : c.type !== "wifi";
        const destroyed = rConns.filter(rc => ofType(rc) && !newConns.find(nc => same(nc, rc)));

        for (const conn of destroyed)
            rConns.splice(rConns.indexOf(conn), 1).forEach(c => c.destroy());

        for (const conn of newConns) {
            const match = rConns.find(c => same(c, conn));
            if (match) {
                match.lastIpcObject = conn;
            } else {
                rConns.push(connComp.createObject(root, { lastIpcObject: conn }));
            }
        }
    }

    Process {
        id: wifiStatusProc
        running: true
        command: ["nmcli", "radio", "wifi"]
        environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiEnabled = text.trim() === "enabled";
                if (!root.wifiEnabled) {
                    root.lastErrorMessage = "";
                    root.message = "";
                    root.lastNetworkAttempt = "";
                }
            }
        }
    }

    Process {
        id: enableWifiProc
        onExited: {
            getWifiStatus();
            updateConnections();
        }
    }

    Process {
        id: rescanProc
        command: ["nmcli", "dev", "wifi", "list", "--rescan", "yes"]
        onExited: {
            root.lastScan = Date.now();
            updateConnections();
        }
    }

    Process {
        id: connectProc
        stdout: StdioCollector { }
        stderr: StdioCollector {
            onStreamFinished: {
                if (/secrets were required|incorrect|password|psk/i.test(text))
                    root.lastErrorMessage = "Incorrect password";
                else if (text.includes("Error"))
                    root.lastErrorMessage = "Couldn't connect";
            }
        }
        onExited: {
            if (exitCode === 0) {
                root.message = "ok";
                root.lastErrorMessage = "";
            } else {
                root.message = root.lastErrorMessage !== "" ? root.lastErrorMessage : "Connection failed";
            }
            // (also after a failure, in case the new profile was kept)
            if (root._unpin !== "")
                unpinProc.exec(["nmcli", "connection", "modify", "id", root._unpin, "802-11-wireless.bssid", ""]);
            root._unpin = "";
            updateConnections();
        }
    }

    // a profile made on one access point, let go of it (see connect())
    Process {
        id: unpinProc
    }

    Process {
        id: forgetProc
        onExited: updateConnections()
    }

    Process {
        id: disconnectProc
        onExited: updateConnections()
    }

    Process {
        id: ethConnectProc
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.includes("Error"))
                    root.lastErrorMessage = /no suitable device|not available|carrier/i.test(text)
                        ? "Not plugged in" : "Couldn't connect";
            }
        }
        onExited: updateConnections()
    }

    Process {
        id: ethDisconnectProc
        onExited: updateConnections()
    }

    Process {
        id: addressProc
        environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
        stdout: StdioCollector {
            onStreamFinished: {
                // "10.0.0.5/24" (several are joined by " | "), then the gateway
                const lines = text.trim().split("\n");
                root.ipAddress = (lines[0] ?? "").split(" | ")[0].split("/")[0];
                root.gateway = (lines[1] ?? "").trim();
            }
        }
    }

    Process {
        id: getSavedNetworks
        running: true
        command: ["nmcli", "-g", "NAME,TYPE", "connection", "show"]
        environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const wifiConnections = lines
                    .map(line => line.split(":"))
                    .filter(parts => parts[1] === "802-11-wireless")
                    .map(parts => parts[0]);
                root.savedNetworks = wifiConnections;
            }
        }
        onExited: {
            getWifiNetworks.running = true;
            getEthConnections.running = true;
        }
    }

    // NetworkManager's list as it stands; scans are rescan()'s business.
    Process {
        id: getWifiNetworks
        running: true
        command: ["nmcli", "-g", "ACTIVE,SIGNAL,FREQ,SSID,BSSID,SECURITY,CHAN,BANDWIDTH,RATE,DEVICE", "d", "w", "list", "--rescan", "no"]
        environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
        stdout: StdioCollector {
            onStreamFinished: {
                const PLACEHOLDER = "STRINGWHICHHOPEFULLYWONTBEUSED";
                const rep = new RegExp("\\\\:", "g");
                const rep2 = new RegExp(PLACEHOLDER, "g");

                const heard = text.trim().split("\n").filter(n => n.length > 0).map(n => {
                    const net = n.replace(rep, PLACEHOLDER).split(":");
                    const name = net[3]?.replace(rep2, ":") ?? "";
                    const frequency = parseInt(net[2]) || 0;
                    return {
                        type: "wifi",
                        active: net[0] === "yes",
                        strength: parseInt(net[1]) || 0,
                        frequency: frequency,
                        band: root.bandOf(frequency),
                        name: name,
                        bssid: net[4]?.replace(rep2, ":") ?? "",
                        security: net[5] ?? "",
                        channel: parseInt(net[6]) || 0,
                        bandwidth: parseInt(net[7]) || 20,
                        rate: parseInt(net[8]) || 0,
                        device: net[9] ?? "",
                        saved: name !== "" && root.savedNetworks.includes(name),
                        uuid: ""
                    };
                });

                root.accessPoints = heard.map(n => ({
                    ssid: n.name,
                    bssid: n.bssid,
                    signal: n.strength,
                    frequency: n.frequency,
                    band: n.band,
                    channel: n.channel,
                    bandwidth: n.bandwidth,
                    rate: n.rate,
                    security: n.security,
                    device: n.device,
                    active: n.active,
                    saved: n.saved
                }));

                // One entry per SSID: the access point in use, else the
                // strongest; it also lists every band the SSID is on.
                const networkMap = new Map();
                const bands = new Map();
                for (const network of heard.filter(n => n.name.length > 0)) {
                    bands.set(network.name, (bands.get(network.name) ?? []).concat([network.band]));
                    const existing = networkMap.get(network.name);
                    if (!existing) {
                        networkMap.set(network.name, network);
                    } else {
                        if (network.active && !existing.active) {
                            networkMap.set(network.name, network);
                        } else if (!network.active && !existing.active && network.strength > existing.strength) {
                            networkMap.set(network.name, network);
                        }
                    }
                }
                for (const [name, network] of networkMap)
                    network.bands = ["2.4", "5", "6"].filter(b => bands.get(name).includes(b));

                mergeConnections(Array.from(networkMap.values()), "wifi");
            }
        }
    }

    Process {
        id: getEthConnections
        running: true
        command: [Quickshell.shellPath("scripts/network-links.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                let out;
                try {
                    out = JSON.parse(text);
                } catch (e) {
                    return;
                }
                root.primaryDevice = out.primary ?? "";
                mergeConnections(out.links.map(l => ({
                    type: l.type,
                    kind: l.kind,
                    name: l.name,
                    title: l.title,
                    uuid: l.uuid,
                    device: l.device,
                    active: l.active,
                    available: l.available,
                    address: l.address,
                    strength: 100,
                    frequency: 0,
                    bssid: "",
                    security: "",
                    saved: true
                })), "wired");
            }
        }
    }

    // NetworkManager's changes, a moment after they settle
    Process {
        running: true
        command: ["nmcli", "monitor"]
        environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
        stdout: SplitParser {
            onRead: settle.restart()
        }
    }

    Timer {
        id: settle
        interval: 600
        onTriggered: {
            root.updateConnections();
            root.refreshAddress();
        }
    }

    Timer {
        interval: 1000
        running: root.watchTraffic && root.wifiDevice !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: trafficFile.reload()
        onRunningChanged: {
            if (running)
                return;
            root._lastTraffic = null;
            root.rxRate = 0;
            root.txRate = 0;
            root.rxHistory = [];
            root.txHistory = [];
        }
    }

    // "  wlo1: rx_bytes rx_packets … (8 receive fields) tx_bytes …"
    FileView {
        id: trafficFile
        path: "/proc/net/dev"
        onLoaded: {
            const prefix = root.wifiDevice + ":";
            const line = text().split("\n").find(l => l.trim().startsWith(prefix));
            if (!line)
                return;
            const f = line.slice(line.indexOf(":") + 1).trim().split(/\s+/);
            const now = Date.now();
            const rx = parseFloat(f[0]) || 0;
            const tx = parseFloat(f[8]) || 0;
            const last = root._lastTraffic;
            if (last && now > last.t && root.watchTraffic) {
                root.rxRate = Math.max(0, (rx - last.rx) * 1000 / (now - last.t));
                root.txRate = Math.max(0, (tx - last.tx) * 1000 / (now - last.t));
                root.rxHistory = root.rxHistory.concat([root.rxRate]).slice(-60);
                root.txHistory = root.txHistory.concat([root.txRate]).slice(-60);
            }
            root._lastTraffic = { t: now, rx: rx, tx: tx };
        }
    }

    component Connection: QtObject {
        required property var lastIpcObject
        readonly property string type: lastIpcObject.type
        readonly property string name: lastIpcObject.name
        readonly property string uuid: lastIpcObject.uuid
        readonly property string device: lastIpcObject.device
        readonly property bool active: lastIpcObject.active
        readonly property int strength: lastIpcObject.strength
        readonly property int frequency: lastIpcObject.frequency
        readonly property string bssid: lastIpcObject.bssid
        readonly property string security: lastIpcObject.security
        readonly property bool isSecure: security.length > 0
        readonly property bool saved: lastIpcObject.saved
        readonly property string band: lastIpcObject.band ?? ""
        readonly property var bands: lastIpcObject.bands ?? []
        readonly property int channel: lastIpcObject.channel ?? 0
        readonly property int bandwidth: lastIpcObject.bandwidth ?? 0
        readonly property int rate: lastIpcObject.rate ?? 0
        // wired and tethered links: what it is, a name to show for it,
        // whether it can come up (a cable is in) and its address while up
        readonly property string kind: lastIpcObject.kind ?? "wifi"
        readonly property string title: lastIpcObject.title ?? name
        readonly property bool available: lastIpcObject.available ?? true
        readonly property string address: lastIpcObject.address ?? ""
    }

    Component { id: connComp; Connection { } }
}
