pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland as Hypr

// The panorama: your workspaces as cards on a strip that bends round you.
// A switch swings the strip from one card to the next (workspace keys, the
// three-finger swipe, the workspace disc), and the overview (ALT+TAB) can
// show the whole ring to choose from. The idea and its shader come from
// Panaroma Workspace Switcher (MIT, hawike22405); this is the shell's own.
// The pictures are taken and drawn by modules/panorama (one surface per
// screen); this file holds the settings and the Hyprland side.
//
// Settings: ~/.config/quickshell/panorama.json, written by the customizer's
// book (chapter X) and live-reloaded when edited by hand:
//   switching    how a switch looks: "panorama" (the strip), "hyprland"
//                (Hyprland's own animation, as hyprland.lua has it) or "off"
//                (none, it cuts straight across); an older `transitions`
//                true/false reads as "panorama"/"hyprland"
//   gestures     the three-finger swipe drives it, a card under your fingers
//   view         the overview's look, "panorama" or "grid"
//   duration     a switch's length in ms (300–1200)
//   curve        how far the strip bends round you (0–1)
//   depth        how far it draws back from the screen (0.15–0.7)
//
// How a switch gets covered. Hyprland switches the moment a key is pressed,
// before anything could cover the screen, so while switching is "panorama" the
// shell takes over your workspace binds at runtime (scripts/keybinds.py
// lists them; nothing in hypr/ is rewritten). Each becomes a Lua function
// that hands the switch to the shell as a custom event, and switches by
// itself when the shell isn't there (no panorama surface) or hasn't taken
// it within half a second. The shell snapshots the screen, covers it with
// the panorama's first frame (the snapshot, flat: the very same picture)
// and only then lets Hyprland switch, underneath. Hyprland's own workspace
// animation is off meanwhile (the special workspace keeps its own), and the
// swipe is the shell's too. "off" only turns Hyprland's workspace animation
// off (the binds and the swipe stay Hyprland's). "hyprland" reloads the
// config, which puts every bind, gesture and animation back as the files
// say; a reload made elsewhere has the overrides put back.
Singleton {
    id: root

    // ── Settings ───────────────────────────────────────────────────────────
    readonly property var switchModes: ["panorama", "hyprland", "off"]
    readonly property string switching: root.switchModes.includes(adapter.switching) ? adapter.switching : (adapter.transitions ? "panorama" : "hyprland")
    // The panorama plays as you switch.
    readonly property bool transitions: root.switching === "panorama"
    readonly property bool gestures: adapter.gestures
    readonly property string view: adapter.view === "grid" ? "grid" : "panorama"
    readonly property int duration: Math.round(root._clamp(adapter.duration, 300, 1200))
    readonly property real curve: root._clamp(adapter.curve, 0, 1)
    readonly property real depth: root._clamp(adapter.depth, 0.15, 0.7)

    // The surfaces are built while anything here needs them.
    readonly property bool wanted: root.transitions || root.view === "panorama"

    // QS_PANORAMA_DEBUG=1 in the shell's environment logs each step ("PANO").
    readonly property bool debug: Quickshell.env("QS_PANORAMA_DEBUG") === "1"

    function log(...args) {
        if (root.debug)
            console.log("PANO", Date.now() % 100000, ...args);
    }

    // Only the main shell touches Hyprland (shell.qml sets it).
    property bool manage: false
    // A shell panel is up (rootPanel): switches then go plainly, and no
    // pictures are taken of it (shell.qml keeps it current).
    property bool panelsUp: false

    // An overview is open on some screen (its surface sets it).
    property bool overviewOpen: false

    // The swipe as Hyprland is set for it (read when the overrides go in).
    property int swipeDistance: 300
    property real swipeCancel: 0.5
    property bool swipeInvert: true
    property bool swipeCreateNew: true
    property real swipeForce: 30

    readonly property var settingKeys: ["switching", "gestures", "view", "duration", "curve", "depth"]

    function set(key, value) {
        if (key === "transitions")
            return root.set("switching", value ? "panorama" : "hyprland");
        if (key === "switching") {
            if (!root.switchModes.includes(value))
                return;
            adapter.transitions = value === "panorama";
            adapter.switching = value;
            return;
        }
        let v = value;
        if (key === "gestures")
            v = !!value;
        else if (key === "view")
            v = value === "grid" ? "grid" : "panorama";
        else if (key === "duration")
            v = Math.round(root._clamp(Number(value), 300, 1200));
        else if (key === "curve")
            v = Math.round(root._clamp(Number(value), 0, 1) * 100) / 100;
        else if (key === "depth")
            v = Math.round(root._clamp(Number(value), 0.15, 0.7) * 100) / 100;
        else
            return;
        if (adapter[key] === v)
            return;
        adapter[key] = v;
    }

    function _clamp(v, lo, hi) {
        const n = Number(v);
        return isFinite(n) ? Math.max(lo, Math.min(hi, n)) : lo;
    }

    // ── Surfaces ───────────────────────────────────────────────────────────
    // screen name -> its PanoramaSurface
    property var _surfaces: ({})

    function register(name, surface) {
        const next = Object.assign({}, root._surfaces);
        next[name] = surface;
        root._surfaces = next;
    }

    function unregister(name, surface) {
        if (root._surfaces[name] !== surface)
            return;
        const next = Object.assign({}, root._surfaces);
        delete next[name];
        root._surfaces = next;
    }

    function surfaceFor(name) {
        return name ? (root._surfaces[name] ?? null) : null;
    }

    function focusedSurface() {
        const m = Hypr.Hyprland.focusedMonitor;
        return m ? root.surfaceFor(m.name) : null;
    }

    // ── What the rest of the shell calls ───────────────────────────────────
    // The overview: true when the panorama took it (the grid opens otherwise).
    function toggleOverview() {
        const s = root.focusedSurface();
        if (!s || root.view !== "panorama")
            return false;
        return s.toggleOverview();
    }

    function openOverview() {
        const s = root.focusedSurface();
        return s && root.view === "panorama" ? s.openOverview() : false;
    }

    function closeOverview() {
        for (const name in root._surfaces)
            root._surfaces[name].closeOverview();
    }

    // Switch to workspace `id` (a number) through the panorama when it can
    // play; plainly otherwise. The workspace disc comes here.
    function switchTo(id) {
        const n = Number(id);
        if (!isFinite(n) || n <= 0)
            return;
        const s = root.focusedSurface();
        if (root.transitions && s && s.localSwitch(n))
            return;
        root.dispatchFocus(n);
    }

    function dispatchFocus(id) {
        Hypr.Hyprland.dispatch("hl.dsp.focus({ workspace = " + Math.round(Number(id)) + " })");
    }

    // A routed key's switch, handed back to Hyprland (it ran the bind).
    function take(seq) {
        Hypr.Hyprland.dispatch("function() local P = qs_panorama if P and P.take then P.take(" + Math.round(seq) + ") end end");
    }

    // The swipe's outcome: `target` a workspace id, or 0 to stay.
    function gestureDone(target) {
        const t = Math.round(Number(target) || 0);
        Hypr.Hyprland.dispatch("function() local P = qs_panorama if P then P.gwait = nil end"
            + (t > 0 ? " hl.dispatch(hl.dsp.focus({ workspace = " + t + " }))" : "") + " end");
    }

    // A swipe the shell couldn't follow: Hyprland's way, at once.
    function gesturePlain(serial) {
        Hypr.Hyprland.dispatch("function() local P = qs_panorama if P and P.gplain then P.gplain(" + Math.round(Number(serial) || 0) + ") end end");
    }

    // ── Events from Hyprland ───────────────────────────────────────────────
    //   custom>>qs-panorama,go,<seq>,<hint>,<from id>
    //   custom>>qs-panorama,gesture,<start|update|finish>,<serial>,<total dx>,<dx|cancelled>
    function _onCustom(data) {
        if (!data.startsWith("qs-panorama,"))
            return;
        const p = data.split(",");
        if (p[1] === "go") {
            const seq = Number(p[2]);
            root.log("go", seq, p[3], "from", p[4]);
            const s = root.focusedSurface();
            if (!(root.transitions && s && s.routedSwitch(seq, p[3] ?? "", Number(p[4]))))
                root.take(seq);
        } else if (p[1] === "gesture") {
            const s = root.focusedSurface();
            const handled = root.transitions && root.gestures && s
                && s.gesture(p[2], Number(p[3]), Number(p[4]), p[5] ?? "");
            if (!handled && p[2] === "finish")
                root.gesturePlain(Number(p[3]));
        }
    }

    Connections {
        target: Hypr.Hyprland

        function onRawEvent(event) {
            if (event.name === "custom") {
                root._onCustom(String(event.data));
            } else if (event.name === "configreloaded") {
                // A reload wipes the runtime overrides; put them back, unless
                // the reload was the one taking them away.
                if (root._reverting)
                    root._reverting = false;
                else if (root.manage && root.switching !== "hyprland")
                    applyTimer.restart();
            }
        }
    }

    // ── Hyprland overrides ─────────────────────────────────────────────────
    property bool _applied: false
    // the switching the overrides in force were made for
    property string _appliedMode: ""
    property bool _reverting: false

    onManageChanged: syncTimer.restart()
    onSwitchingChanged: syncTimer.restart()
    // The swipe on or off: start again from the config (its own swipe),
    // the reload's event then puts the rest back with or without ours.
    onGesturesChanged: {
        if (root.manage && root.transitions && root._applied)
            root._restart();
    }

    Timer {
        id: syncTimer
        interval: 200
        onTriggered: root._sync()
    }

    Timer {
        id: applyTimer
        interval: 400
        onTriggered: root._apply()
    }

    Timer {
        id: revertGuard
        interval: 3000
        onTriggered: root._reverting = false
    }

    function _sync() {
        if (!root.manage || !adapterReady)
            return;
        if (root.switching === "hyprland") {
            if (root._applied)
                root._revert();
        } else if (root._applied && root._appliedMode !== root.switching) {
            // from one set of overrides to the other: from the config again
            root._restart();
        } else {
            root._apply();
        }
    }

    // A reload that isn't a revert: its event puts the overrides for the
    // switching now set back in.
    function _restart() {
        root._applied = false;
        root._appliedMode = "";
        hyprctl.exec(["hyprctl", "reload"]);
    }

    // Reads the binds and the settings the Lua needs, then evals it.
    function _apply() {
        if (!root.manage || root.switching === "hyprland")
            return;
        probe.exec(["sh", "-c",
            "printf '{\"binds\":'; python3 \"$1\" list 2>/dev/null || printf 'null'; "
            + "printf ',\"anims\":'; hyprctl -j animations 2>/dev/null || printf 'null'; "
            + "for o in gestures:workspace_swipe_distance gestures:workspace_swipe_cancel_ratio gestures:workspace_swipe_invert "
            + "gestures:workspace_swipe_create_new gestures:workspace_swipe_min_speed_to_force; do "
            + "printf ',\"%s\":' \"$o\"; hyprctl -j getoption \"$o\" 2>/dev/null || printf 'null'; done; printf '}'",
            "sh", Quickshell.shellPath("scripts/keybinds.py")]);
    }

    function _revert() {
        root._applied = false;
        root._appliedMode = "";
        root._reverting = true;
        revertGuard.restart();
        hyprctl.exec(["hyprctl", "reload"]);
    }

    function _opt(o, fallback) {
        if (!o)
            return fallback;
        if ("int" in o)
            return o.int;
        if ("float" in o)
            return o.float;
        if ("bool" in o)
            return o.bool;
        return fallback;
    }

    // A Lua string literal, for the few plain strings that go into the eval.
    function _q(s) {
        return "\"" + String(s).replace(/[^A-Za-z0-9 _+:.,\-]/g, "") + "\"";
    }

    // The binds to take over: global binds that switch to a workspace
    // (hl.dsp.focus) or move the window there and follow (hl.dsp.window.move,
    // not silent). Each as { keys, dsp (Lua), hint, opts (Lua) }.
    function _routes(list) {
        const out = [];
        const seen = {};
        const arr = list ? Array.from(list) : [];
        for (const b of arr)
            seen[b.keys] = (seen[b.keys] ?? 0) + 1;
        for (const b of arr) {
            if (!b || b.submap || !b.dsp || seen[b.keys] !== 1)
                continue;
            if (!/^[A-Za-z0-9 _+:.\-]+$/.test(String(b.keys)))
                continue;
            const path = b.dsp.path;
            if (path !== "focus" && path !== "window.move")
                continue;
            const args = b.dsp.args ? Array.from(b.dsp.args) : [];
            if (args.length !== 1 || typeof args[0] !== "object" || args[0] === null)
                continue;
            const a = args[0];
            if (Object.keys(a).length !== 1 || !("workspace" in a))
                continue;
            const w = a.workspace;
            let lit;
            if (typeof w === "number" && Number.isInteger(w) && w > 0)
                lit = String(w);
            else if (typeof w === "string" && /^([emr]?[+-]\d+|\d+)$/.test(w))
                lit = root._q(w);
            else
                continue;
            const kind = path === "focus" ? "focus" : "move";
            const opts = [];
            const o = b.opts ?? {};
            for (const f of ["repeating", "locked", "release", "non_consuming", "transparent", "ignore_mods", "dont_inhibit", "long_press", "click", "drag", "mouse"])
                if (o[f] === true)
                    opts.push(f + " = true");
            if (typeof b.description === "string" && b.description)
                opts.push("description = " + root._q(b.description));
            out.push({
                keys: b.keys,
                dsp: "hl.dsp." + path + "({ workspace = " + lit + " })",
                hint: kind + ":" + String(w),
                opts: opts.length ? "{ " + opts.join(", ") + " }" : "nil"
            });
        }
        return out;
    }

    function _lua(data) {
        const L = [];
        root._animationLua(data, L);
        // "off" stops there: the binds and the swipe stay Hyprland's.
        if (root.switching !== "panorama")
            return L.join("\n");
        L.push("qs_panorama = qs_panorama or {}");
        L.push("local P = qs_panorama");
        L.push("P.seq = P.seq or 0");
        L.push("P.gs = P.gs or 0");
        // The shell is there when its surface is mapped (it always is while
        // it runs: a pixel in a corner at rest).
        L.push("function P.alive() local ok, ls = pcall(hl.get_layers, { namespace = \"quickshell:panorama\" }) "
            + "if not ok or type(ls) ~= \"table\" then return false end "
            + "for _, l in ipairs(ls) do if l.mapped then return true end end return false end");
        L.push("function P.route(d, hint) if not P.alive() then hl.dispatch(d) return end "
            + "P.seq = P.seq + 1 local seq = P.seq local ws = hl.get_active_workspace() "
            + "P.pending = { seq = seq, d = d } "
            + "hl.dispatch(hl.dsp.event(\"qs-panorama,go,\" .. seq .. \",\" .. hint .. \",\" .. tostring(ws and ws.id or 0))) "
            + "hl.timer(function() local p = P.pending if p and p.seq == seq then P.pending = nil hl.dispatch(p.d) end end, { timeout = 500, type = \"oneshot\" }) end");
        L.push("function P.take(seq) local p = P.pending if p and p.seq == seq then P.pending = nil hl.dispatch(p.d) end end");

        // The workspace binds.
        for (const r of root._routes(data.binds ? data.binds.binds : null)) {
            L.push("pcall(hl.unbind, " + root._q(r.keys) + ")");
            L.push("hl.bind(" + root._q(r.keys) + ", (function() local d = " + r.dsp
                + " return function() P.route(d, " + root._q(r.hint) + ") end end)()"
                + (r.opts !== "nil" ? ", " + r.opts : "") + ")");
        }

        // The swipe: a card under the fingers. Without the shell it switches
        // like Hyprland's own swipe would.
        if (root.gestures)
            root._gestureLua(L);
        return L.join("\n");
    }

    // Hyprland's own workspace animation goes; the special workspace, which
    // inherits it unless set, keeps what it had.
    function _animationLua(data, L) {
        // `hyprctl -j animations` is [animations, beziers].
        const anims = data.anims && data.anims.length ? data.anims : [];
        const flat = anims.length && Array.isArray(anims[0]) ? anims[0] : anims;
        const byName = {};
        for (const a of flat)
            if (a && a.name)
                byName[a.name] = a;
        const ws = byName["workspaces"];
        const sp = byName["specialWorkspace"];
        if (ws && sp && !sp.overridden && ws.enabled) {
            let spec = "leaf = \"specialWorkspace\", enabled = true, speed = " + Number(ws.speed || 1);
            if (ws.bezier)
                spec += ", bezier = " + root._q(ws.bezier);
            if (ws.style)
                spec += ", style = " + root._q(ws.style);
            L.push("pcall(hl.animation, { " + spec + " })");
        }
        for (const leaf of ["workspaces", "workspacesIn", "workspacesOut"])
            L.push("pcall(hl.animation, { leaf = \"" + leaf + "\", enabled = false })");
    }

    // The swipe's Lua (P, the panorama's table, is in scope from _lua).
    function _gestureLua(L) {
        L.push("P.distance = " + Math.max(50, Number(root.swipeDistance) || 300));
        L.push("P.cancel = " + Number(root.swipeCancel));
        L.push("P.invert = " + (root.swipeInvert ? "true" : "false"));
        L.push("P.g = { active = false, shell = false, total = 0 }");
        L.push("local function fmt(v) return string.format(\"%.1f\", v) end");
        L.push("P.gesture = { "
            + "start = function(e) local g = P.g P.gs = P.gs + 1 g.serial = P.gs g.total = 0 g.active = true g.shell = P.alive() "
            + "if g.shell then hl.dispatch(hl.dsp.event(\"qs-panorama,gesture,start,\" .. g.serial .. \",0,0\")) end end, "
            + "update = function(e) local g = P.g if not g.active then return end "
            + "local dx = (e and e.delta and tonumber(e.delta.x)) or 0 g.total = g.total + dx "
            + "if g.shell then hl.dispatch(hl.dsp.event(\"qs-panorama,gesture,update,\" .. g.serial .. \",\" .. fmt(g.total) .. \",\" .. fmt(dx))) end end, "
            + "finish = function(e) local g = P.g if not g.active then return end g.active = false "
            + "local cancelled = (e and e.cancelled) and true or false "
            + "local function plain() if not cancelled and math.abs(g.total) >= P.distance * P.cancel then "
            + "local fwd = (g.total < 0) == P.invert hl.dispatch(hl.dsp.focus({ workspace = fwd and \"r+1\" or \"r-1\" })) end end "
            + "if not g.shell then plain() return end "
            + "local serial = g.serial P.gwait = serial P.gplainfn = plain "
            + "hl.dispatch(hl.dsp.event(\"qs-panorama,gesture,finish,\" .. serial .. \",\" .. fmt(g.total) .. \",\" .. (cancelled and \"1\" or \"0\"))) "
            + "hl.timer(function() if P.gwait == serial then P.gwait = nil plain() end end, { timeout = 600, type = \"oneshot\" }) end }");
        L.push("function P.gplain(serial) if P.gwait == serial then P.gwait = nil if P.gplainfn then P.gplainfn() end end end");
        L.push("pcall(hl.gesture, { fingers = 3, direction = \"horizontal\", action = \"unset\" })");
        L.push("hl.gesture({ fingers = 3, direction = \"horizontal\", action = P.gesture })");
    }

    Process {
        id: probe
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.manage || root.switching === "hyprland")
                    return;
                let data;
                try {
                    data = JSON.parse(text);
                } catch (e) {
                    console.warn("panorama: couldn't read the binds:", e);
                    return;
                }
                root.swipeDistance = Math.round(root._opt(data["gestures:workspace_swipe_distance"], 300));
                root.swipeCancel = Number(root._opt(data["gestures:workspace_swipe_cancel_ratio"], 0.5));
                root.swipeInvert = !!root._opt(data["gestures:workspace_swipe_invert"], true);
                root.swipeCreateNew = !!root._opt(data["gestures:workspace_swipe_create_new"], true);
                root.swipeForce = Number(root._opt(data["gestures:workspace_swipe_min_speed_to_force"], 30));
                const lua = root._lua(data);
                root._applied = true;
                root._appliedMode = root.switching;
                hyprctl.exec(["hyprctl", "eval", lua]);
            }
        }
    }

    Process {
        id: hyprctl
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                if (out && out !== "ok")
                    console.warn("panorama:", out);
            }
        }
    }

    // ── IPC ────────────────────────────────────────────────────────────────
    //   qs ipc call panorama overview|close|go <id>|turn <±n>|pick|transitions on|off|toggle
    //   qs ipc call panorama switching panorama|hyprland|off
    //   qs ipc call panorama view panorama|grid ; state
    IpcHandler {
        target: "panorama"

        function overview(): void {
            if (!root.toggleOverview())
                console.warn("panorama: no overview here");
        }
        function close(): void {
            root.closeOverview();
        }
        function go(id: string): void {
            root.switchTo(Number(id));
        }
        // The overview without a keyboard: turn by `step` cards, go to the lit one.
        function turn(step: int): void {
            const s = root.focusedSurface();
            if (s)
                s.browse(step);
        }
        function pick(): void {
            const s = root.focusedSurface();
            if (s)
                s.choose(Math.round(s.litIdx));
        }
        function transitions(how: string): void {
            root.set("transitions", how === "toggle" ? !root.transitions : how === "on" || how === "true");
        }
        function switching(mode: string): void {
            root.set("switching", mode);
        }
        function view(which: string): void {
            root.set("view", which);
        }
        function state(): string {
            const s = {};
            for (const name in root._surfaces)
                s[name] = root._surfaces[name].describe();
            return JSON.stringify({
                switching: root.switching, transitions: root.transitions, gestures: root.gestures,
                view: root.view, appliedMode: root._appliedMode,
                duration: root.duration, curve: root.curve, depth: root.depth,
                applied: root._applied, overview: root.overviewOpen, surfaces: s
            });
        }
    }

    // ── Settings file ──────────────────────────────────────────────────────
    property bool adapterReady: false
    property double _quietUntil: 0

    Timer {
        id: writeTimer
        interval: 150
        onTriggered: {
            root._quietUntil = Date.now() + 600;
            settingsFile.writeAdapter();
        }
    }

    FileView {
        id: settingsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/panorama.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: {
            if (Date.now() > root._quietUntil)
                reload();
        }
        onAdapterUpdated: writeTimer.restart()
        onLoaded: root.adapterReady = true
        onLoadFailed: root.adapterReady = true

        adapter: JsonAdapter {
            id: adapter
            // `switching` came later: "" falls back to `transitions`
            property string switching: ""
            property bool transitions: true
            property bool gestures: true
            property string view: "panorama"
            property int duration: 650
            property real curve: 1.0
            property real depth: 0.45
        }
    }

    Component.onCompleted: if (!root.adapterReady) root.adapterReady = true
}
