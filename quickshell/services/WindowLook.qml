pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// The windows' look in Hyprland, set in the customizer's book: gaps,
// borders, corners, opacity, blur, shadows, dimming, animations and the
// layout. Each is either left to the desktop theme or hypr/hyprland.lua, or
// set here; what's set here goes on top of them.
//
// Applied at runtime with `hyprctl eval`, like the desktop theme's own
// overrides: DesktopTheme puts these after its own whenever it applies
// (switching themes, after a reload), and without a theme they're put back
// here after a reload. Letting one go back to the theme's or the config's
// takes a reload (which DesktopTheme answers by applying itself again).
//
// Settings: ~/.config/quickshell/windowlook.json ({ "decoration.rounding":
// 12, … }).
Singleton {
    id: root

    // What can be set: its Hyprland option, kind, and range.
    readonly property var options: ({
        "general.gaps_in": { kind: "int", min: 0, max: 40 },
        "general.gaps_out": { kind: "int", min: 0, max: 80 },
        "general.border_size": { kind: "int", min: 0, max: 12 },
        "general.layout": { kind: "str", values: ["dwindle", "master", "scrolling"] },
        "decoration.rounding": { kind: "int", min: 0, max: 40 },
        "decoration.rounding_power": { kind: "float", min: 1, max: 10 },
        "decoration.active_opacity": { kind: "float", min: 0.2, max: 1 },
        "decoration.inactive_opacity": { kind: "float", min: 0.2, max: 1 },
        "decoration.dim_inactive": { kind: "bool" },
        "decoration.dim_strength": { kind: "float", min: 0, max: 0.8 },
        "decoration.blur.enabled": { kind: "bool" },
        "decoration.blur.size": { kind: "int", min: 1, max: 24 },
        "decoration.blur.passes": { kind: "int", min: 1, max: 6 },
        "decoration.blur.vibrancy": { kind: "float", min: 0, max: 1 },
        "decoration.shadow.enabled": { kind: "bool" },
        "decoration.shadow.range": { kind: "int", min: 0, max: 80 },
        "decoration.shadow.render_power": { kind: "int", min: 1, max: 4 },
        "animations.enabled": { kind: "bool" }
    })

    // Only the main shell applies them.
    property bool manage: false

    readonly property var overrides: adapter.overrides
    readonly property int count: Object.keys(adapter.overrides).length

    // What Hyprland had for each while it wasn't set here (the theme's or
    // the config's), as last read; and what it has now.
    property var base: ({})
    property var live: ({})

    function has(key) {
        return key in adapter.overrides;
    }

    // The value in force: set here, or as Hyprland has it.
    function value(key) {
        if (key in adapter.overrides)
            return adapter.overrides[key];
        return root.live[key] ?? root.base[key];
    }

    function set(key, v) {
        const o = root.options[key];
        if (!o)
            return;
        let val = v;
        if (o.kind === "int")
            val = Math.round(Math.max(o.min, Math.min(o.max, Number(v))));
        else if (o.kind === "float")
            val = Math.round(Math.max(o.min, Math.min(o.max, Number(v))) * 100) / 100;
        else if (o.kind === "bool")
            val = !!v;
        else if (!o.values.includes(v))
            return;
        if (adapter.overrides[key] === val)
            return;
        if (!(key in adapter.overrides) && root.live[key] !== undefined) {
            const b = Object.assign({}, root.base);
            b[key] = root.live[key];
            root.base = b;
        }
        const next = Object.assign({}, adapter.overrides);
        next[key] = val;
        adapter.overrides = next;
        applyTimer.restart();
    }

    // Back to the theme's or the config's.
    function clear(keys) {
        const list = Array.isArray(keys) ? keys : [keys];
        const next = Object.assign({}, adapter.overrides);
        let changed = false;
        for (const k of list) {
            if (k in next) {
                delete next[k];
                changed = true;
            }
        }
        if (!changed)
            return;
        adapter.overrides = next;
        root._reload();
    }

    function clearAll() {
        root.clear(Object.keys(adapter.overrides));
    }

    // The overrides as Lua: one hl.config({...}) call, or "".
    function lua() {
        const keys = Object.keys(adapter.overrides).filter(k => k in root.options);
        if (keys.length === 0)
            return "";
        const tree = {};
        for (const k of keys) {
            const parts = k.split(".");
            let node = tree;
            for (let i = 0; i < parts.length - 1; i++)
                node = node[parts[i]] = node[parts[i]] ?? {};
            node[parts[parts.length - 1]] = adapter.overrides[k];
        }
        const emit = node => "{ " + Object.keys(node).map(k => {
            const v = node[k];
            if (typeof v === "object")
                return k + " = " + emit(v);
            if (typeof v === "string")
                return k + " = \"" + v.replace(/[^a-z_]/g, "") + "\"";
            if (typeof v === "boolean")
                return k + " = " + (v ? "true" : "false");
            return k + " = " + Number(v);
        }).join(", ") + " }";
        return "hl.config(" + emit(tree) + ")";
    }

    function apply() {
        if (!root.manage)
            return;
        const lua = root.lua();
        if (lua)
            hyprctl.exec(["hyprctl", "eval", lua]);
        root._applied = Object.keys(adapter.overrides);
        refreshTimer.restart();
    }

    // What was last put in force here: a key gone from the file since (an
    // edit by hand) needs the reload that lets the theme's or config's back.
    property var _applied: []

    // One by its option, from text (IPC): "true"/"false", a number, a word.
    function setText(key, text) {
        const t = String(text).trim();
        root.set(key, t === "true" ? true : t === "false" ? false : isNaN(Number(t)) ? t : Number(t));
    }

    // A reload drops every runtime override; the theme (or we, without one)
    // put theirs back once it's done.
    property bool _reloading: false

    function _reload() {
        if (!root.manage)
            return;
        root._reloading = true;
        reloadGuard.restart();
        hyprctl.exec(["hyprctl", "reload"]);
    }

    // Reads what Hyprland has for each option now.
    function refresh() {
        const names = Object.keys(root.options).map(k => k.split(".").join(":"));
        reader.exec(["sh", "-c", "printf '['; s=; for o in \"$@\"; do printf '%s' \"$s\"; s=,; hyprctl -j getoption \"$o\"; done; printf ']'", "sh"].concat(names));
    }

    Timer {
        id: applyTimer
        interval: 70
        onTriggered: root.apply()
    }

    Timer {
        id: refreshTimer
        interval: 400
        onTriggered: root.refresh()
    }

    Timer {
        id: reloadGuard
        interval: 3000
        onTriggered: root._reloading = false
    }

    // After a reload (ours, the theme's, a new wallpaper's colours): put
    // ours back if no theme is going to.
    Timer {
        id: reapply
        interval: 350
        onTriggered: {
            if (!(DesktopTheme.manage && DesktopTheme.enabled))
                root.apply();
            else
                refreshTimer.restart();
        }
    }

    onManageChanged: if (root.manage) reapply.restart()

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "configreloaded")
                return;
            root._reloading = false;
            if (root.manage)
                reapply.restart();
        }
    }

    Process {
        id: hyprctl
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                if (out.startsWith("error"))
                    console.warn("window look:", out);
            }
        }
    }

    Process {
        id: reader
        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try {
                    list = JSON.parse(text);
                } catch (e) {
                    return;
                }
                const now = {};
                for (const o of list) {
                    const key = String(o.option ?? "").split(":").join(".");
                    if (!(key in root.options))
                        continue;
                    let v = o.int ?? o.float ?? o.bool ?? o.str;
                    if (v === undefined && typeof o.css === "string")
                        v = Number(o.css.trim().split(/\s+/)[0]);
                    if (v !== undefined)
                        now[key] = v;
                }
                root.live = now;
                const b = Object.assign({}, root.base);
                for (const k of Object.keys(now))
                    if (!(k in adapter.overrides))
                        b[k] = now[k];
                root.base = b;
            }
        }
    }

    // ── Settings file ────────────────────────────────────────────────────────
    property double _quietUntil: 0

    Timer {
        id: writeTimer
        interval: 200
        onTriggered: {
            root._quietUntil = Date.now() + 600;
            settingsFile.writeAdapter();
        }
    }

    FileView {
        id: settingsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/windowlook.json"
        watchChanges: true
        printErrors: false
        onFileChanged: {
            if (Date.now() > root._quietUntil)
                reload();
        }
        onLoaded: {
            if (root._applied.some(k => !(k in adapter.overrides)))
                root._reload();
            else
                applyTimer.restart();
        }
        onAdapterUpdated: writeTimer.restart()

        adapter: JsonAdapter {
            id: adapter
            property var overrides: ({})
        }
    }
}
