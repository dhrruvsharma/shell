pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// The keybinds manager's model (modules/keybinds): the binds in
// ~/.config/hypr/*.lua, read and written through scripts/keybinds.py.
//
// The script tries each change before writing it and keeps a backup. Then
// Hyprland has to take it: its watch on the config usually reloads it at
// once (otherwise this runs `hyprctl reload`), and if it then reports a
// config error it didn't have before, the backup goes straight back. Undo
// restores the last change's backups the same way.
//
// Recording a shortcut parks Hyprland in an empty submap, so the keys
// pressed reach the panel instead of setting off their binds. Escape, bound
// in that submap, and a timer on Hyprland's side leave it even if the shell
// goes away mid-recording.
Singleton {
    id: root

    // Set by the panel while it's open; nothing is read or watched otherwise.
    property bool active: false

    property var binds: []
    property var files: []
    property var live: []
    property bool liveOk: false
    property string dir: ""
    property bool loading: false
    property bool loaded: false
    // "no-lua-config", or what went wrong reading the binds
    property string error: ""
    // The config raised while being read; `binds` holds those found before.
    property string probeError: ""
    // Hyprland's config errors when the list was read, so a save is only
    // blamed for new ones.
    property string baselineErrors: ""

    // "", "saving", "reloading", "checking" or "restoring"
    property string phase: ""
    readonly property bool busy: phase !== ""
    // The last change that went live, for undo: { changes, summary }
    property var lastChange: null

    // A change is live: `lines` maps each op's index to its bind's line.
    signal saved(var lines, string summary)
    signal failed(string message)
    signal undone(string summary)

    property bool recording: false
    readonly property string recordMap: "qs-keybinds"

    readonly property string script: Quickshell.shellPath("scripts/keybinds.py")

    // ── Derived ──────────────────────────────────────────────────────────────

    // Key names are matched without case, and a few have two spellings.
    readonly property var _aliases: ({ page_up: "prior", page_down: "next", enter: "return", esc: "escape" })
    readonly property var _modOrder: ["SUPER", "CTRL", "ALT", "SHIFT", "CAPS", "MOD2", "MOD3", "MOD5"]

    function norm(key) {
        const k = String(key).toLowerCase();
        return root._aliases[k] ?? k;
    }

    function sortMods(mods) {
        const out = [];
        for (const m of mods)
            if (!out.includes(m))
                out.push(m);
        return out.sort((a, b) => (root._modOrder.indexOf(a) + 100) % 100 - (root._modOrder.indexOf(b) + 100) % 100);
    }

    function layerKey(mods) {
        return root.sortMods(mods).join("+");
    }

    // layer ("SUPER+SHIFT") → key name (lower case) → binds; outside submaps.
    readonly property var byLayer: {
        const map = {};
        for (const b of root.binds) {
            if (b.submap)
                continue;
            const layer = root.layerKey(b.mods);
            const key = root.norm(b.key);
            map[layer] = map[layer] ?? {};
            (map[layer][key] = map[layer][key] ?? []).push(b);
        }
        for (const l of root.liveOnly) {
            const layer = root.layerKey(l.mods);
            const key = root.norm(l.key);
            map[layer] = map[layer] ?? {};
            (map[layer][key] = map[layer][key] ?? []).push(l);
        }
        return map;
    }

    // Binds Hyprland has that aren't in the files (another program's).
    readonly property var liveOnly: {
        if (!root.liveOk)
            return [];
        const known = new Set(root.binds.map(b => b.modmask + "|" + root.norm(b.key) + "|" + b.submap));
        return root.live.filter(l => !l.submap && !known.has(l.modmask + "|" + root.norm(l.key) + "|"))
            .map(l => ({
                id: "live:" + l.modmask + ":" + l.key, liveOnly: true, mods: root.modsOfMask(l.modmask), key: l.key,
                modmask: l.modmask, submap: "", title: "Bound elsewhere", category: "custom", glyph: "link",
                editable: false, generated: false, file: "", line: 0, section: "", opts: {}, description: ""
            }));
    }

    readonly property var liveKeys: new Set(root.live.map(l => l.modmask + "|" + root.norm(l.key) + "|" + l.submap))

    // The layers in use: fewer modifiers first, then the busier.
    readonly property var layers: {
        const counts = {};
        for (const b of root.binds) {
            if (b.submap)
                continue;
            const k = root.layerKey(b.mods);
            counts[k] = counts[k] ?? { mods: root.sortMods(b.mods), key: k, count: 0 };
            counts[k].count++;
        }
        return Object.values(counts).sort((a, b) => a.mods.length - b.mods.length || b.count - a.count);
    }

    function modsOfMask(mask) {
        const bits = [[64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"], [2, "CAPS"], [16, "MOD2"], [32, "MOD3"], [128, "MOD5"]];
        return bits.filter(b => mask & b[0]).map(b => b[1]);
    }

    function bindsAt(mods, key) {
        return (root.byLayer[root.layerKey(mods)] ?? {})[root.norm(key)] ?? [];
    }

    function isLive(b) {
        return !root.liveOk || root.liveKeys.has(b.modmask + "|" + root.norm(b.key) + "|" + (b.submap ?? ""));
    }

    function fileInfo(name) {
        return root.files.find(f => f.name === name) ?? null;
    }

    // ── Reading ──────────────────────────────────────────────────────────────

    property bool _again: false

    function refresh() {
        if (listProc.running) {
            _again = true;
            return;
        }
        loading = true;
        listProc.running = true;
    }

    onActiveChanged: {
        if (active) {
            refresh();
        } else {
            stopRecording();
        }
    }

    Process {
        id: listProc
        command: ["python3", root.script, "list"]
        stdout: StdioCollector {
            onStreamFinished: root._listed(text)
        }
        onRunningChanged: {
            if (!running && root._again) {
                root._again = false;
                root.refresh();
            }
        }
    }

    function _listed(text) {
        loading = false;
        let r;
        try {
            r = JSON.parse(text);
        } catch (e) {
            error = text.trim() || "keybinds.py didn't answer";
            return;
        }
        dir = r.dir ?? "";
        if (!r.ok) {
            error = r.error ?? "couldn't read the binds";
            binds = [];
            files = [];
            loaded = true;
            return;
        }
        error = "";
        probeError = r.probeError ?? "";
        files = r.files ?? [];
        live = r.live ?? [];
        liveOk = !!r.liveOk;
        if (!busy)
            baselineErrors = r.configErrors ?? "";
        binds = r.binds ?? [];
        loaded = true;
    }

    // Edits by hand (or another tool) show up while the panel is open.
    Instantiator {
        model: root.active ? root.files.map(f => f.path) : []
        delegate: FileView {
            required property string modelData
            path: modelData
            watchChanges: true
            printErrors: false
            onFileChanged: if (!root.busy) refreshSoon.restart()
        }
    }

    Timer {
        id: refreshSoon
        interval: 250
        onTriggered: root.refresh()
    }

    // ── Writing ──────────────────────────────────────────────────────────────

    // "apply", "undo" or "rollback": what the reload being waited on is for.
    property string _mode: ""
    property var _result: null
    property string _summary: ""
    property string _rejection: ""

    // ops as keybinds.py takes them; summary is what the toast says after.
    function apply(ops, summary) {
        if (busy || !ops.length)
            return false;
        _mode = "apply";
        _summary = summary;
        _sawReload = false;
        phase = "saving";
        writeProc.command = ["python3", script, "apply", JSON.stringify({ ops: ops })];
        writeProc.running = true;
        return true;
    }

    function undo() {
        if (busy || !lastChange)
            return;
        _mode = "undo";
        _summary = lastChange.summary;
        _sawReload = false;
        phase = "restoring";
        writeProc.command = ["python3", script, "restore", JSON.stringify({
            restores: lastChange.changes.map(c => ({ file: c.file, backup: c.backup, hash: c.hash }))
        })];
        writeProc.running = true;
    }

    Process {
        id: writeProc
        stdout: StdioCollector {
            onStreamFinished: root._written(text)
        }
    }

    function _written(text) {
        let r;
        try {
            r = JSON.parse(text);
        } catch (e) {
            r = { ok: false, error: text.trim() || "keybinds.py didn't answer" };
        }
        if (!r.ok) {
            const mode = _mode;
            phase = "";
            _mode = "";
            failed(mode === "rollback"
                ? "Hyprland rejected the change (" + _rejection + "), and putting the file back failed: " + r.error
                : r.error);
            refresh();
            return;
        }
        if (_mode !== "rollback")
            _result = r;
        phase = "reloading";
        if (_sawReload) {
            // Hyprland's watch already picked the write up; let it settle.
            _sawReload = false;
            reloadSettle.restart();
        } else {
            reloadWait.restart();
        }
    }

    // A reload while the script was still writing: Hyprland's own watch,
    // so there's no need for another.
    property bool _sawReload: false

    Timer {
        id: reloadSettle
        interval: 300
        onTriggered: if (root.phase === "reloading") root._reloaded()
    }

    // Hyprland's own watch on the file usually reloads before this.
    Timer {
        id: reloadWait
        interval: 900
        onTriggered: {
            reloadProc.running = true;
            reloadGiveUp.restart();
        }
    }

    Timer {
        id: reloadGiveUp
        interval: 4000
        onTriggered: if (root.phase === "reloading") root._reloaded()
    }

    Process {
        id: reloadProc
        command: ["hyprctl", "reload", "config-only"]
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "configreloaded" && (root.phase === "saving" || root.phase === "restoring")) {
                root._sawReload = true;
            } else if (event.name === "configreloaded" && root.phase === "reloading") {
                reloadWait.stop();
                reloadGiveUp.stop();
                reloadSettle.stop();
                root._reloaded();
            } else if (event.name === "submap" && root.recording && event.data !== root.recordMap) {
                // Escape, the timeout, or something else took Hyprland out of it
                root.recording = false;
                recordLimit.stop();
            }
        }
    }

    function _reloaded() {
        phase = "checking";
        errorsProc.running = true;
    }

    Process {
        id: errorsProc
        command: ["hyprctl", "configerrors"]
        stdout: StdioCollector {
            onStreamFinished: root._checked(text.trim())
        }
    }

    function _checked(errors) {
        const mode = _mode;
        if (errors && errors !== baselineErrors && mode !== "rollback") {
            // Hyprland didn't take it: the files go back as they were.
            _rejection = errors.split("\n")[0];
            _mode = "rollback";
            _sawReload = false;
            phase = "restoring";
            writeProc.command = ["python3", script, "restore", JSON.stringify({
                restores: _result.changes.map(c => ({ file: c.file, backup: c.backup, hash: c.hash }))
            })];
            writeProc.running = true;
            return;
        }
        phase = "";
        _mode = "";
        if (mode === "apply") {
            lastChange = { changes: _result.changes, summary: _summary };
            saved(_result.lines ?? {}, _summary);
        } else if (mode === "undo") {
            lastChange = null;
            undone(_summary);
        } else if (mode === "rollback") {
            failed("Hyprland rejected that (" + _rejection + "), so the file was put back");
        }
        refresh();
    }

    // ── Recording ────────────────────────────────────────────────────────────

    function startRecording() {
        if (recording)
            return;
        recording = true;
        recordLimit.restart();
        Quickshell.execDetached(["hyprctl", "eval",
            "if QS_KEYBINDS_ESC then pcall(function() QS_KEYBINDS_ESC:remove() end) end "
            + "hl.define_submap(\"" + recordMap + "\", function() QS_KEYBINDS_ESC = hl.bind(\"Escape\", hl.dsp.submap(\"reset\")) end) "
            + "hl.dispatch(hl.dsp.submap(\"" + recordMap + "\")) "
            + "hl.timer(function() if hl.get_current_submap() == \"" + recordMap + "\" then hl.dispatch(hl.dsp.submap(\"reset\")) end end, "
            + "{ timeout = 15000, type = \"oneshot\" })"]);
    }

    function stopRecording() {
        recordLimit.stop();
        if (!recording)
            return;
        recording = false;
        Quickshell.execDetached(["hyprctl", "eval",
            "if hl.get_current_submap() == \"" + recordMap + "\" then hl.dispatch(hl.dsp.submap(\"reset\")) end"]);
    }

    Timer {
        id: recordLimit
        interval: 14000
        onTriggered: root.stopRecording()
    }
}
