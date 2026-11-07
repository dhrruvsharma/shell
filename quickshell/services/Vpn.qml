pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// VPN tunnels through NetworkManager, for the edge line's VPN pane:
// WireGuard ones (NetworkManager has WireGuard built in; a provider's
// .conf goes in through scripts/vpn-import.py), and any other kind it has a
// plugin for (OpenVPN with networkmanager-openvpn, …), which show up here
// too once there's a profile.
//
// Connecting says why it couldn't, here and in a notification. A WireGuard
// tunnel comes up whether or not its server is there, so once it's up the
// tunnel's own DNS server is asked something (scripts/dns-probe.py): no
// answer, and it says nothing comes back through it.
Singleton {
    id: root

    readonly property string importer: Quickshell.shellPath("scripts/vpn-import.py")
    // (a stand-in can be put here to try it out)
    property string probe: Quickshell.shellPath("scripts/dns-probe.py")

    // [{ uuid, name, type ("wireguard", or "vpn" for a plugin's), active,
    // state ("activated", "activating", "deactivating", ""), device,
    // address }]
    property var profiles: []
    property bool ready: false
    readonly property var current: root.profiles.find(p => p.active) ?? null

    // What's being done to a profile: uuid → "connecting" | "disconnecting"
    // | "removing".
    property var busy: ({})
    // How the tunnel up answered: uuid → "ok" | "silent" ("" not asked, or
    // couldn't tell).
    property var answers: ({})
    property bool importing: false

    // Why the last thing asked of it didn't happen ("" it did).
    property string failureTitle: ""
    property string failure: ""

    signal added(string name)

    function refresh() {
        if (listProc.running)
            root._again = true;
        else
            listProc.running = true;
    }

    function dismiss() {
        root.failureTitle = "";
        root.failure = "";
    }

    function toggle(p) {
        if (p.active || p.state === "activating")
            root.disconnect(p);
        else
            root.connect(p);
    }

    function connect(p) {
        if (root.busy[p.uuid])
            return;
        root.dismiss();
        root._set("busy", p.uuid, "connecting");
        root._set("answers", p.uuid, "");
        root._run(["nmcli", "connection", "up", "uuid", p.uuid], (code, out, err) => {
            root._set("busy", p.uuid, undefined);
            if (code !== 0) {
                root._fail("Couldn't connect to " + p.name, root.reason(err || out));
                root.refresh();
                return;
            }
            root.refresh();
            root._check(p);
        });
    }

    function disconnect(p) {
        if (root.busy[p.uuid])
            return;
        root.dismiss();
        root._set("busy", p.uuid, "disconnecting");
        root._run(["nmcli", "connection", "down", "uuid", p.uuid], (code, out, err) => {
            root._set("busy", p.uuid, undefined);
            root._set("answers", p.uuid, "");
            if (code !== 0)
                root._fail("Couldn't disconnect " + p.name, root.reason(err || out));
            root.refresh();
        });
    }

    function remove(p) {
        if (root.busy[p.uuid])
            return;
        root.dismiss();
        root._set("busy", p.uuid, "removing");
        root._run(["nmcli", "connection", "delete", "uuid", p.uuid], (code, out, err) => {
            root._set("busy", p.uuid, undefined);
            if (code !== 0)
                root._fail("Couldn't remove " + p.name, root.reason(err || out));
            root.refresh();
        });
    }

    // A file chosen in a dialog (zenity), then imported.
    function browse() {
        if (root.importing || pick.running)
            return;
        pick.running = true;
    }

    function importFile(path) {
        if (root.importing)
            return;
        root.dismiss();
        root.importing = true;
        root._run([root.importer, path], (code, out, err) => {
            root.importing = false;
            let r = null;
            try {
                r = JSON.parse(out);
            } catch (e) {}
            if (!r || !r.ok) {
                root._fail("Couldn't import it", (r && r.error) || root.reason(err) || "The importer didn't answer.");
                return;
            }
            root.refresh();
            root.added(r.name);
            Quickshell.execDetached(["notify-send", "-a", "VPN", "-i", "network-vpn", "VPN added: " + r.name, "It's in the edge line's VPN panel; a click there connects it."]);
        });
    }

    // nmcli's error, in words.
    function reason(text) {
        const t = String(text ?? "").trim().replace(/^Error:\s*/i, "");
        if (t === "")
            return "";
        if (/secrets were required|no secrets|password/i.test(t))
            return "It needs a password or key it doesn't have.";
        if (/no suitable device|not available/i.test(t))
            return "There's nothing for it to go through.";
        if (/timeout|timed out/i.test(t))
            return "It took too long to answer.";
        const last = t.split("\n").filter(l => l.trim() !== "").pop() ?? t;
        return last.charAt(0).toUpperCase() + last.slice(1) + (/[.!?]$/.test(last) ? "" : ".");
    }

    function _fail(title, body) {
        root.failureTitle = title;
        root.failure = body;
        Quickshell.execDetached(["notify-send", "-a", "VPN", "-i", "dialog-warning", title, body]);
    }

    function _set(which, key, value) {
        const next = Object.assign({}, root[which]);
        if (value === undefined)
            delete next[key];
        else
            next[key] = value;
        root[which] = next;
    }

    // Once a tunnel's up: is anything at its other end? Its own DNS server
    // is asked (inside the tunnel when it carries everything); with none
    // set, or when the answer could have come from the network instead,
    // there's no telling.
    function _check(p) {
        root._run(["nmcli", "-g", "ipv4.dns", "connection", "show", "uuid", p.uuid], (code, out) => {
            const dns = String(out ?? "").split(/[,\s]+/).map(s => s.replace(/\\:/g, ":").split("#")[0]).filter(s => /^\d+\.\d+\.\d+\.\d+$/.test(s));
            if (code !== 0 || dns.length === 0)
                return;
            root._run([root.probe, "check", dns[0]], (c2, out2) => {
                let r = null;
                try {
                    r = JSON.parse(out2);
                } catch (e) {}
                if (!r || r.intercepted)
                    return;
                const ok = (r.results ?? []).some(x => x.ok);
                root._set("answers", p.uuid, ok ? "ok" : "silent");
                if (!ok)
                    root._fail(p.name + " isn't answering", "It's connected, but nothing comes back through it: the server may be down, or the config's keys or address are out of date.");
            });
        });
    }

    // ── Running nmcli ────────────────────────────────────────────────────────
    function _run(command, done) {
        const p = runner.createObject(root, { command: command, done: done });
        p.running = true;
    }

    Component {
        id: runner

        Process {
            id: proc

            property var done: null
            property string out: ""
            property string err: ""
            property int code: -1
            property int waiting: 3

            function step() {
                if (--proc.waiting > 0)
                    return;
                if (proc.done)
                    proc.done(proc.code, proc.out, proc.err);
                proc.destroy();
            }

            environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
            stdout: StdioCollector {
                onStreamFinished: {
                    proc.out = text;
                    proc.step();
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    proc.err = text;
                    proc.step();
                }
            }
            onExited: code => {
                proc.code = code;
                proc.step();
            }
        }
    }

    property bool _again: false

    // NAME:UUID:TYPE:ACTIVE:DEVICE:STATE, with ':' in a name escaped.
    Process {
        id: listProc
        running: true
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,ACTIVE,DEVICE,STATE", "connection", "show"]
        environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
        stdout: StdioCollector {
            onStreamFinished: {
                const mark = "\u0001";
                const found = [];
                for (const line of text.split("\n")) {
                    if (line.trim() === "")
                        continue;
                    const f = line.replace(/\\\\/g, "\u0002").replace(/\\:/g, mark).split(":").map(s => s.split(mark).join(":").split("\u0002").join("\\"));
                    if (f.length < 6 || (f[2] !== "wireguard" && f[2] !== "vpn"))
                        continue;
                    const old = root.profiles.find(p => p.uuid === f[1]);
                    found.push({
                        name: f[0],
                        uuid: f[1],
                        type: f[2],
                        active: f[3] === "yes" && f[5] === "activated",
                        device: f[4],
                        state: f[5],
                        address: old && old.active ? old.address : ""
                    });
                }
                found.sort((a, b) => (b.active - a.active) || a.name.localeCompare(b.name));
                root.profiles = found;
                root.ready = true;
                const up = found.find(p => p.active);
                if (up && !addressProc.running)
                    addressProc.exec(["nmcli", "-g", "IP4.ADDRESS", "connection", "show", "uuid", up.uuid]);
            }
        }
        onExited: {
            if (root._again) {
                root._again = false;
                Qt.callLater(root.refresh);
            }
        }
    }

    // The address the tunnel up has.
    Process {
        id: addressProc
        environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
        stdout: StdioCollector {
            onStreamFinished: {
                const address = text.trim().split(/\s*\|\s*/)[0].split("/")[0];
                root.profiles = root.profiles.map(p => p.active ? Object.assign({}, p, { address: address }) : p);
            }
        }
    }

    Process {
        id: pick
        command: ["zenity", "--file-selection", "--title=Choose a WireGuard config", "--file-filter=WireGuard configs | *.conf", "--file-filter=All files | *"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path !== "")
                    root.importFile(path);
            }
        }
    }

    // NetworkManager's changes (a tunnel up or down elsewhere).
    Connections {
        target: Network

        function onSettled() {
            root.refresh();
        }
    }
}
