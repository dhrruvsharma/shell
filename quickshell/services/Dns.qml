pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Who answers the lookups on the connection that carries the traffic (the
// default route's): the router's servers, a provider's, or ones of your own
// (a name like dns.adguard.com, or addresses), set on that connection
// through NetworkManager (scripts/dns-probe.py). Each Wi-Fi network keeps
// its own.
//
// A server is tried before it's used, and lookups are tried through it once
// it is (it goes back to what was there if they fail). Encrypted when
// NetworkManager can (it hands DNS to systemd-resolved): DNS over TLS to
// port 853, strictly, the certificate checked against the server's name.
// Otherwise plain, port 53, with a server that can't exist asked alongside:
// a network that answers that one too answers every DNS question itself,
// and plain DNS set there would never reach the server. Whatever can't be
// reached says so (`failure`) and in a notification; so does DNS set here
// that stops answering later (`health`, checked when the connection changes
// and every ten minutes).
//
// Names given to servers of your own: ~/.config/quickshell/dns.json.
Singleton {
    id: root

    // Set by the shell: keep an eye on DNS set here from the start, not only
    // once the panel has been opened.
    property bool watch: false

    // (a stand-in can be put here to try it out)
    property string script: Quickshell.shellPath("scripts/dns-probe.py")

    readonly property var providers: [
        { id: "adguard", name: "AdGuard", icon: "shield", blurb: "blocks ads and trackers", tls: "dns.adguard-dns.com", v4: ["94.140.14.14", "94.140.15.15"], v6: ["2a10:50c0::ad1:ff", "2a10:50c0::ad2:ff"] },
        { id: "cloudflare", name: "Cloudflare", icon: "cloud", blurb: "fast, and keeps few logs", tls: "cloudflare-dns.com", v4: ["1.1.1.1", "1.0.0.1"], v6: ["2606:4700:4700::1111", "2606:4700:4700::1001"] },
        { id: "quad9", name: "Quad9", icon: "verified_user", blurb: "blocks malicious sites", tls: "dns.quad9.net", v4: ["9.9.9.9", "149.112.112.112"], v6: ["2620:fe::fe", "2620:fe::9"] },
        { id: "google", name: "Google", icon: "public", blurb: "Google Public DNS", tls: "dns.google", v4: ["8.8.8.8", "8.8.4.4"], v6: ["2001:4860:4860::8888", "2001:4860:4860::8844"] }
    ]

    // ── What NetworkManager says ─────────────────────────────────────────────
    property bool ready: false
    property string device: ""
    // the connection's name and id
    property string connection: ""
    property string uuid: ""
    // the servers in use, and the ones set on the connection ([{ ip, name }])
    property var servers: []
    property var configured: []
    // servers of its own in place of the router's
    property bool own: false
    // connection.dns-over-tls: "default" | "no" | "opportunistic" | "yes"
    property string tlsSetting: "default"
    // NetworkManager hands DNS to systemd-resolved, so it can be encrypted
    property bool canEncrypt: false
    // why there's no connection to set it on ("" there is one)
    property string offline: ""

    readonly property var configuredIps: root.configured.map(c => c.ip)
    readonly property string configuredName: root.configured.find(c => c.name !== "")?.name ?? ""
    readonly property bool encrypted: root.own && root.canEncrypt && root.tlsSetting === "yes" && root.configuredName !== ""
    // What's in use: "auto", a provider's id, or "custom".
    readonly property string current: {
        if (!root.own)
            return "auto";
        const ips = root.configuredIps;
        const p = root.providers.find(p => ips.every(ip => p.v4.includes(ip) || p.v6.includes(ip)));
        return p ? p.id : "custom";
    }
    readonly property string currentName: root.current === "auto" ? "Automatic" : root.current === "custom" ? (labels.labels[root._key(root.configuredIps)] ?? (root.configuredName || root.configuredIps.join(", "))) : (root.providers.find(p => p.id === root.current)?.name ?? "")

    // ── A switch under way ───────────────────────────────────────────────────
    property bool busy: false
    // what's being switched to: "auto", a provider's id, or "custom"
    property string trying: ""
    property string tryingName: ""
    // what it's doing, said for the panel
    property string step: ""
    readonly property bool checking: healthProc.running || statusProc.running || hintProc.running

    // ── How it went ──────────────────────────────────────────────────────────
    // Why the last switch didn't happen ("" it did, or none was asked for).
    property string failureTitle: ""
    property string failure: ""
    // (it failed because the network answers DNS itself)
    property bool failureIntercepted: false
    // The servers in use, as they answered last: "ok", "fail",
    // "intercepted" (set, but the network answers in their place), or ""
    // (not asked yet).
    property string health: ""
    property string healthWhy: ""
    property int healthMs: -1
    property real checkedAt: 0
    // The network the connection is on answers every plain DNS question
    // itself (seen on the connection `interceptedOn`).
    property bool intercepted: false
    property string interceptedOn: ""
    readonly property bool interceptedHere: root.intercepted && root.uuid !== "" && root.interceptedOn === root.uuid
    // Encrypted DNS got through to a provider from here.
    property bool tlsGetsThrough: false
    property string tlsTriedOn: ""
    // Encrypted DNS through NetworkManager needs systemd-resolved to do the
    // lookups; once, as root:
    readonly property string setupCommands: "sudo systemctl enable --now systemd-resolved\nsudo ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf\nsudo systemctl restart NetworkManager\n"

    // A switch went through (to "auto", a provider's id or "custom").
    signal switched(string id)

    property var _plan: null
    property var _before: null
    property bool _statusAgain: false
    property bool _checkAfter: false
    property bool _checkIfOwn: false
    property string _healthFor: ""
    property bool _healthTls: false
    property string _warned: ""

    onWatchChanged: {
        if (root.watch) {
            root._checkIfOwn = true;
            root.refresh();
        }
    }

    // ── Asking ───────────────────────────────────────────────────────────────
    // What's set now.
    function refresh() {
        if (statusProc.running)
            root._statusAgain = true;
        else
            statusProc.exec([root.script, "status"]);
    }

    // The panel's opened: what's set, and how it answers (asked again after
    // a minute).
    function look() {
        if (Date.now() - root.checkedAt > 60000)
            root._checkAfter = true;
        root.refresh();
    }

    // Asks the servers in use again, now.
    function recheck() {
        root._checkAfter = true;
        root.refresh();
    }

    function dismiss() {
        root.failureTitle = "";
        root.failure = "";
        root.failureIntercepted = false;
    }

    function copySetup() {
        Quickshell.execDetached(["wl-copy", root.setupCommands]);
    }

    // ── Switching ────────────────────────────────────────────────────────────
    function use(id) {
        const p = root.providers.find(p => p.id === id);
        if (!p)
            return;
        if (root.current === id && !root.busy) {
            root.recheck();
            return;
        }
        root._start({ id: p.id, name: p.name, v4: p.v4, v6: p.v6, tls: p.tls, label: "" });
    }

    // A server of your own: a name (dns.adguard.com; tls://, https://… and
    // a path are let go of), or addresses (several with commas or spaces;
    // "address#name" for its certificate's name).
    function useCustom(text) {
        if (root.busy || root.uuid === "")
            return;
        const q = root.parse(text);
        if (!q) {
            root._fail("Couldn't use “" + String(text).trim() + "”", "That isn't a server's name or address.", false);
            return;
        }
        if (q.ips.length > 0) {
            const label = q.name || q.ips.join(", ");
            root._start({ id: "custom", name: label, v4: q.ips.filter(ip => !ip.includes(":")), v6: q.ips.filter(ip => ip.includes(":")), tls: q.name, label: q.name });
            return;
        }
        root._begin("custom", q.host);
        root._plan = { id: "custom", name: q.host, v4: [], v6: [], tls: q.name || q.host, label: q.host };
        root.step = "Looking up " + q.host + "…";
        resolveProc.exec([root.script, "resolve", q.host]);
    }

    // Back to the router's servers.
    function automatic() {
        if (root.busy || root.uuid === "")
            return;
        if (!root.own) {
            root.recheck();
            return;
        }
        root._begin("auto", "Automatic");
        root._plan = { id: "auto", name: "Automatic" };
        root.step = "Going back to the network's own…";
        autoProc.exec([root.script, "auto", root.uuid, root.device]);
    }

    function parse(text) {
        let t = String(text ?? "").trim().replace(/^[a-z][a-z0-9+.-]*:\/\//i, "");
        const parts = t.split(/[\s,;]+/).filter(s => s !== "");
        if (parts.length === 0)
            return null;
        const ips = [];
        let host = "", name = "";
        for (const part of parts) {
            const hash = part.indexOf("#");
            let addr = hash >= 0 ? part.slice(0, hash) : part;
            if (hash >= 0)
                name = part.slice(hash + 1).toLowerCase();
            addr = addr.replace(/\/.*$/, "");
            if (/^\[.*\](:\d+)?$/.test(addr))
                addr = addr.slice(1, addr.indexOf("]"));
            else if (/^[^:\[\]]+:\d+$/.test(addr))
                addr = addr.split(":")[0];
            if (root._isIp(addr))
                ips.push(addr.toLowerCase());
            else if (!host && root._isHost(addr))
                host = addr.toLowerCase().replace(/\.$/, "");
            else
                return null;
        }
        if (name !== "" && !root._isHost(name))
            return null;
        if (ips.length > 0)
            return { ips: ips, host: "", name: name || host };
        return { ips: [], host: host, name: name };
    }

    function _isIp(s) {
        const v4 = s.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
        if (v4)
            return v4.slice(1).every(o => Number(o) <= 255);
        return /^[0-9a-f:.]+$/i.test(s) && (s.match(/:/g) ?? []).length >= 2;
    }

    function _isHost(s) {
        return /^(?=.{1,253}\.?$)([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z][a-z0-9-]{0,62}\.?$/i.test(s);
    }

    function _key(ips) {
        return ips.slice().sort().join(",");
    }

    function _start(plan) {
        if (root.busy || root.uuid === "")
            return;
        root._begin(plan.id, plan.name);
        root._plan = plan;
        root._try();
    }

    function _begin(id, name) {
        root.busy = true;
        root.trying = id;
        root.tryingName = name;
        root.dismiss();
        watchdog.restart();
    }

    function _try() {
        const p = root._plan;
        const ips = p.v4.concat(p.v6);
        if (ips.length === 0) {
            root._fail("Couldn't connect to " + p.name, "It has no addresses.");
            return;
        }
        if (root.canEncrypt && p.tls !== "") {
            root.step = "Trying " + p.name + ", encrypted…";
            tlsProc.exec([root.script, "tls", p.tls].concat(ips));
        } else {
            root.step = "Trying " + p.name + "…";
            checkProc.exec([root.script, "check"].concat(ips));
        }
    }

    // Why none of them could be used: the first IPv4 server's reason (IPv6
    // often isn't there at all).
    function _why(results, tls) {
        const v4 = results.filter(r => !String(r.server).includes(":"));
        const first = (v4.length > 0 ? v4 : results)[0];
        const err = first?.error || "no answer";
        return results.length > 1 ? "None of its servers answered" + (tls ? " over TLS" : "") + " (" + err + ")." : root._sentence(err);
    }

    function _sentence(s) {
        const t = String(s ?? "").trim();
        if (t === "")
            return "";
        return t.charAt(0).toUpperCase() + t.slice(1) + (/[.!?]$/.test(t) ? "" : ".");
    }

    function _tried(obj, tls) {
        const p = root._plan;
        if (!obj) {
            root._fail("Couldn't try " + p.name, "The DNS helper didn't answer.");
            return;
        }
        if (!tls) {
            root.intercepted = !!obj.intercepted;
            root.interceptedOn = root.uuid;
        }
        const good = obj.intercepted && !tls ? [] : (obj.results ?? []).filter(r => r.ok).map(r => r.server);
        if (good.length === 0) {
            const why = !tls && obj.intercepted ? "This network answers every DNS question itself, so your lookups would never reach " + p.name + "." : root._why(obj.results ?? [], tls);
            if (!tls && p.tls !== "" && !hintProc.running) {
                // would it answer encrypted? (then it's worth setting up)
                root.step = "Trying " + p.name + ", encrypted…";
                root._hintThen = why;
                hintProc.exec([root.script, "tls", p.tls].concat(p.v4.length > 0 ? p.v4 : p.v6));
            } else {
                root._fail("Couldn't connect to " + p.name, why);
                root.failureIntercepted = !tls && !!obj.intercepted;
            }
            return;
        }
        root._plan.ms = Math.min(...(obj.results ?? []).filter(r => r.ok).map(r => r.ms));
        root._apply(p.v4.filter(ip => good.includes(ip)), p.v6.filter(ip => good.includes(ip)), tls ? p.tls : "");
    }

    property string _hintThen: ""

    function _apply(v4, v6, tls) {
        root._before = {
            own: root.own,
            v4: root.configured.filter(c => !c.ip.includes(":")).map(c => c.ip),
            v6: root.configured.filter(c => c.ip.includes(":")).map(c => c.ip),
            tls: root.tlsSetting === "yes" ? root.configuredName : "",
            name: root.currentName
        };
        root._plan.servers = v4.concat(v6);
        root.step = "Switching to " + root._plan.name + "…";
        setProc.exec([root.script, "set", root.uuid, root.device, v4.join(","), v6.join(","), tls]);
    }

    function _done() {
        const id = root._plan?.id ?? "";
        root.busy = false;
        root.trying = "";
        root.step = "";
        watchdog.stop();
        root.refresh();
        root.switched(id);
    }

    // `more`: said in the notification only (the panel says it its own way).
    function _fail(title, body, notify, more) {
        root.busy = false;
        root.trying = "";
        root.step = "";
        root.failureTitle = title;
        root.failure = body;
        root.failureIntercepted = false;
        watchdog.stop();
        if (notify !== false)
            root.notify(title, body + (more ?? ""));
        root.refresh();
    }

    function notify(title, body) {
        Quickshell.execDetached(["notify-send", "-a", "DNS", "-i", "dialog-warning", title, body]);
    }

    function _remember(ips, label) {
        const next = Object.assign({}, labels.labels);
        next[root._key(ips)] = label;
        const keys = Object.keys(next);
        for (const k of keys.slice(0, Math.max(0, keys.length - 16)))
            delete next[k];
        labels.labels = next;
    }

    // ── Keeping an eye on it ─────────────────────────────────────────────────
    function _health() {
        if (root.busy || healthProc.running || root.uuid === "")
            return;
        const ips = root.own ? root.configuredIps : root.servers;
        if (ips.length === 0)
            return;
        root._healthTls = root.encrypted;
        root._healthFor = root.uuid + "|" + root._key(ips) + "|" + (root.encrypted ? root.configuredName : "");
        healthProc.exec(root.encrypted ? [root.script, "tls", root.configuredName].concat(ips) : [root.script, "check"].concat(ips));
    }

    function _healthCame(obj) {
        if (!obj)
            return;
        const key = root._healthFor;
        root.checkedAt = Date.now();
        if (!root._healthTls) {
            root.intercepted = !!obj.intercepted;
            root.interceptedOn = root.uuid;
        }
        const good = (obj.results ?? []).filter(r => r.ok);
        if (!root._healthTls && obj.intercepted && root.own) {
            root.health = "intercepted";
            root.healthWhy = "This network answers every DNS question itself, so your lookups go to it, not to " + root.currentName + ".";
        } else if (good.length > 0) {
            root.health = "ok";
            root.healthWhy = "";
            root.healthMs = Math.min(...good.map(r => r.ms));
        } else {
            root.health = "fail";
            root.healthWhy = root._why(obj.results ?? [], root._healthTls);
            root.healthMs = -1;
        }
        // DNS set here that isn't working: a word, once (until it works again)
        if (root.own && root.health !== "ok") {
            if (root._warned !== key) {
                root._warned = key;
                root.notify(root.currentName + (root.health === "intercepted" ? " isn't being reached on " : " isn't answering on ") + root.connection, root.healthWhy);
            }
        } else if (root.health === "ok" && root._warned === key) {
            root._warned = "";
        }
        // would encrypted DNS get through here? (for setting it up)
        if (root.interceptedHere && !root.canEncrypt && root.tlsTriedOn !== root.uuid && !hintProc.running) {
            const p = root.providers[0];
            root._hintThen = "";
            hintProc.exec([root.script, "tls", p.tls].concat(p.v4));
        }
    }

    function _parse(text) {
        try {
            return JSON.parse(text);
        } catch (e) {
            return null;
        }
    }

    Connections {
        target: Network

        function onPrimaryChanged() {
            if (root.watch || root.ready)
                settle.restart();
        }
        function onPrimaryDeviceChanged() {
            if (root.watch || root.ready)
                settle.restart();
        }
    }

    // A connection change, once it's settled: what's set on the new one.
    Timer {
        id: settle
        interval: 1500
        onTriggered: {
            root._checkIfOwn = true;
            root.refresh();
        }
    }

    // DNS set here, asked again now and then.
    Timer {
        interval: 10 * 60 * 1000
        repeat: true
        running: root.watch && root.own && !root.busy
        onTriggered: root._health()
    }

    Timer {
        id: watchdog
        interval: 60000
        onTriggered: {
            if (root.busy)
                root._fail("Couldn't switch to " + root.tryingName, "It took too long.");
        }
    }

    Process {
        id: statusProc
        environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
        stdout: StdioCollector {
            onStreamFinished: {
                const s = root._parse(text);
                if (!s)
                    return;
                const moved = s.uuid !== root.uuid;
                root.device = s.device ?? "";
                root.connection = s.connection ?? "";
                root.uuid = s.uuid ?? "";
                root.servers = s.servers ?? [];
                root.configured = s.configured ?? [];
                root.own = !!s.own;
                root.tlsSetting = s.tls ?? "default";
                root.canEncrypt = !!s.canTls;
                root.offline = s.error ?? "";
                root.ready = true;
                if (moved) {
                    root.health = "";
                    root.healthWhy = "";
                    root.healthMs = -1;
                    root.checkedAt = 0;
                }
                const check = root._checkAfter || (root._checkIfOwn && root.own) || (moved && root.own);
                root._checkAfter = false;
                root._checkIfOwn = false;
                if (check)
                    Qt.callLater(root._health);
            }
        }
        onExited: {
            if (root._statusAgain) {
                root._statusAgain = false;
                Qt.callLater(root.refresh);
            }
        }
    }

    Process {
        id: resolveProc
        environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.busy)
                    return;
                const r = root._parse(text);
                const p = root._plan;
                if (!r || !p) {
                    root._fail("Couldn't find " + (p?.name ?? "it"), "The DNS helper didn't answer.");
                    return;
                }
                if ((r.v4 ?? []).length + (r.v6 ?? []).length === 0) {
                    root._fail("Couldn't find " + p.name, root._sentence(r.error || "it has no addresses"));
                    return;
                }
                p.v4 = r.v4 ?? [];
                p.v6 = r.v6 ?? [];
                root._try();
            }
        }
    }

    Process {
        id: checkProc
        environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.busy)
                    root._tried(root._parse(text), false);
            }
        }
    }

    Process {
        id: tlsProc
        environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.busy)
                    root._tried(root._parse(text), true);
            }
        }
    }

    // Encrypted DNS from here, for the setup it would need: after a plain
    // try met a network that answers DNS itself (`_hintThen`: the failure
    // to give then), or after a check found that.
    Process {
        id: hintProc
        environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
        stdout: StdioCollector {
            onStreamFinished: {
                const r = root._parse(text);
                const ok = !!r?.ok;
                // (one server answering encrypted is enough to know the
                // network lets it through)
                if (ok || root._hintThen === "") {
                    root.tlsGetsThrough = ok;
                    root.tlsTriedOn = root.uuid;
                }
                if (root._hintThen !== "" && root.busy) {
                    const why = root._hintThen;
                    const hint = ok && !root.canEncrypt ? " It does answer encrypted DNS, which needs systemd-resolved to handle lookups." : "";
                    root._hintThen = "";
                    // (on a network that answers DNS itself, the panel's note
                    // under it says how encrypted DNS would get through)
                    if (root.interceptedHere) {
                        root._fail("Couldn't connect to " + root._plan.name, why, true, hint);
                        root.failureIntercepted = true;
                    } else {
                        root._fail("Couldn't connect to " + root._plan.name, why + hint);
                    }
                }
            }
        }
    }

    Process {
        id: setProc
        environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.busy)
                    return;
                const r = root._parse(text);
                const p = root._plan;
                if (!r || !r.ok) {
                    root._fail("Couldn't switch to " + p.name, root._sentence(r?.error || "NetworkManager refused the change"));
                    return;
                }
                if (p.label)
                    root._remember(p.servers, p.label);
                root.step = "Trying lookups through " + p.name + "…";
                worksProc.exec([root.script, "works"]);
            }
        }
    }

    // Lookups through what was just set: if they fail it goes back.
    Process {
        id: worksProc
        environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.busy)
                    return;
                const r = root._parse(text);
                const p = root._plan;
                if (r && r.ok) {
                    root.health = "ok";
                    root.healthWhy = "";
                    root.healthMs = p.ms ?? -1;
                    root.checkedAt = Date.now();
                    root._done();
                    return;
                }
                if (p.id === "auto") {
                    root._fail("Lookups aren't working", "It's back on the network's own DNS, but lookups through it fail.");
                    return;
                }
                const b = root._before;
                root.step = "Going back to " + b.name + "…";
                root._revertWhy = "It answered when asked, but lookups failed once it was in use, so it's back to " + b.name + ".";
                if (b.own)
                    revertProc.exec([root.script, "set", root.uuid, root.device, b.v4.join(","), b.v6.join(","), b.tls]);
                else
                    revertProc.exec([root.script, "auto", root.uuid, root.device]);
            }
        }
    }

    property string _revertWhy: ""

    Process {
        id: revertProc
        environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.busy)
                    return;
                const r = root._parse(text);
                root._fail("Couldn't connect to " + root._plan.name, r && r.ok ? root._revertWhy : root._revertWhy.replace(/, so it's back to .*$/, ", and going back failed too: ") + root._sentence(r?.error ?? ""));
            }
        }
    }

    Process {
        id: autoProc
        environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.busy)
                    return;
                const r = root._parse(text);
                if (!r || !r.ok) {
                    root._fail("Couldn't go back to the network's DNS", root._sentence(r?.error || "NetworkManager refused the change"));
                    return;
                }
                root.step = "Trying lookups…";
                worksProc.exec([root.script, "works"]);
            }
        }
    }

    Process {
        id: healthProc
        environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
        stdout: StdioCollector {
            onStreamFinished: root._healthCame(root._parse(text))
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/dns.json"
        blockLoading: true
        printErrors: false
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: labels
            // the name a server of your own was given, by its addresses
            property var labels: ({})
        }
    }
}
