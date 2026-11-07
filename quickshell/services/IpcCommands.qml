pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// The shell's IPC commands, for the edge line's commands tile
// (modules/edgeline/CommandsPane): every one the running shell takes
// (`catalogue`, read from `qs ipc show`, plus the zero-argument ones the
// installer found in the source, ipc-commands.json, whose part of the shell
// may not be loaded just now), the ones pinned to the tile (`pinned`), and
// running them: `qs ipc call target function args…`, the same thing a
// keybind does. What a command gives back (`edge` → "top") or why it
// couldn't run is kept per command (`runs`); a failure is also said in a
// notification while the edge line is folded.
//
// Pinned commands: ~/.config/quickshell/edgecommands.json.
Singleton {
    id: root

    readonly property int maxPinned: 30

    // ── Every command there is ───────────────────────────────────────────────
    // [{ target, fn, params: [{ name, type }], returns, live }], by target
    // (in name order), each target's functions as the shell declares them.
    property var catalogue: []
    readonly property bool loading: showProc.running
    property string catalogueError: ""

    // ── Pinned ───────────────────────────────────────────────────────────────
    // [{ target, fn, args: [strings], name }]: `name` is yours ("" for the
    // one made up from the command).
    readonly property var pinned: root._tidy(store.commands)

    // ── Runs ─────────────────────────────────────────────────────────────────
    // By command (key()): { state: "running" | "ok" | "failed", output, error, at }
    property var runs: ({})
    // The last command run (its key), and how it went.
    property string lastKey: ""

    signal ran(string key, bool ok, string output, string error)

    // ── Reading the catalogue ────────────────────────────────────────────────
    function refresh() {
        if (!showProc.running)
            showProc.running = true;
    }

    function _parseShow(text) {
        const found = [];
        let target = "";
        for (const line of String(text ?? "").split("\n")) {
            const t = line.match(/^target\s+(\S+)/);
            if (t) {
                target = t[1];
                continue;
            }
            const f = line.match(/^\s+function\s+(\w+)\((.*)\)\s*:\s*(\w+)/);
            if (!f || target === "")
                continue;
            const params = f[2].trim() === "" ? [] : f[2].split(",").map(p => {
                const [name, type] = p.split(":").map(s => s.trim());
                return { name: name ?? "", type: type ?? "string" };
            });
            found.push({ target: target, fn: f[1], params: params, returns: f[3], live: true });
        }
        return found;
    }

    function _withStatic(found) {
        const have = {};
        for (const c of found)
            have[c.target + " " + c.fn] = true;
        const all = found.slice();
        for (const e of root._static) {
            const m = String(e?.text ?? "").match(/^qs ipc call (\S+) (\S+)$/);
            if (m && !have[m[1] + " " + m[2]]) {
                have[m[1] + " " + m[2]] = true;
                all.push({ target: m[1], fn: m[2], params: [], returns: "void", live: false });
            }
        }
        // by target name (as said), keeping each target's own order
        const order = {};
        all.forEach((c, i) => order[c.target] = Math.min(order[c.target] ?? i, i));
        return all.map((c, i) => ({ c: c, i: i })).sort((a, b) => {
            const na = root.words(a.c.target).toLowerCase(), nb = root.words(b.c.target).toLowerCase();
            return na < nb ? -1 : na > nb ? 1 : a.i - b.i;
        }).map(x => x.c);
    }

    // What the catalogue says of a command ({ params, returns, live }), or null.
    function find(target, fn) {
        return root.catalogue.find(c => c.target === target && c.fn === fn) ?? null;
    }

    // ── Words and glyphs ─────────────────────────────────────────────────────
    // "edgeLine" → "Edge Line"
    function words(camel) {
        const s = String(camel ?? "").replace(/([a-z0-9])([A-Z])/g, "$1 $2").replace(/[_-]+/g, " ").trim();
        return s.split(" ").map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
    }

    // The two lines a pinned command shows: what it does, and where.
    function titleOf(cmd) {
        if (cmd.name)
            return cmd.name;
        if (["toggle", "changeVisible", "open", "show"].includes(cmd.fn) && cmd.args.length === 0)
            return root.words(cmd.target);
        return root.words(cmd.fn) + (cmd.args.length > 0 ? " " + cmd.args.join(" ") : "");
    }

    function detailOf(cmd) {
        if (cmd.name)
            return cmd.target + " " + cmd.fn + (cmd.args.length > 0 ? " " + cmd.args.join(" ") : "");
        if (["toggle", "changeVisible", "open", "show"].includes(cmd.fn) && cmd.args.length === 0)
            return cmd.fn === "changeVisible" ? "toggle" : cmd.fn;
        return root.words(cmd.target);
    }

    function commandLine(cmd) {
        return ["qs ipc call", cmd.target, cmd.fn].concat(cmd.args.map(a => /[\s"'\\]/.test(a) || a === "" ? JSON.stringify(a) : a)).join(" ");
    }

    // A glyph for a part of the shell, by what its name says.
    readonly property var _glyphs: [
        [/launcher|apps|dial/i, "apps"],
        [/wallpaper|wallhaven/i, "wallpaper"],
        [/clipboard/i, "content_paste"],
        [/notepad|notes/i, "sticky_note_2"],
        [/power|session/i, "power_settings_new"],
        [/lock/i, "lock"],
        [/screenshot|screen(shot|cap)/i, "screenshot_region"],
        [/network|wifi/i, "wifi"],
        [/bluetooth/i, "bluetooth"],
        [/volume|audio|sound/i, "volume_up"],
        [/lyric/i, "lyrics"],
        [/media|music|player|spotify/i, "music_note"],
        [/anime|video/i, "movie"],
        [/manga/i, "auto_stories"],
        [/novel|reader|book/i, "menu_book"],
        [/customizer/i, "tune"],
        [/theme|palette|scheme/i, "palette"],
        [/keybind|keys/i, "keyboard"],
        [/calendar|clock|time/i, "calendar_month"],
        [/control/i, "toggle_on"],
        [/pet/i, "pets"],
        [/cava|vis/i, "graphic_eq"],
        [/timer/i, "timer"],
        [/github|git/i, "code"],
        [/update/i, "system_update_alt"],
        [/edge/i, "horizontal_rule"],
        [/bar/i, "toolbar"],
        [/workspace|expose|switcher|window/i, "grid_view"],
        [/avatar|profile/i, "account_circle"],
        [/chat|aikira|ollama|ai\b/i, "chat"],
        [/system|monitor/i, "monitor_heart"],
        [/notif/i, "notifications"],
        [/night/i, "nightlight"],
        [/radio|airplane/i, "airplanemode_active"],
        [/widget|desktop/i, "widgets"]
    ]

    function glyphOf(target) {
        const hit = root._glyphs.find(g => g[0].test(String(target)));
        return hit ? hit[1] : "terminal";
    }

    // ── Pinning ──────────────────────────────────────────────────────────────
    function key(cmd) {
        return JSON.stringify([cmd.target, cmd.fn].concat(cmd.args ?? []));
    }

    function isPinned(target, fn, args) {
        const k = root.key({ target: target, fn: fn, args: args ?? [] });
        return root.pinned.some(c => root.key(c) === k);
    }

    // How many of a function's pins there are (each with its own arguments).
    function pinCount(target, fn) {
        return root.pinned.filter(c => c.target === target && c.fn === fn).length;
    }

    // Why these arguments don't suit the function ("" they do).
    function check(entry, args) {
        const params = entry?.params ?? [];
        for (let i = 0; i < params.length; i++) {
            const v = String(args[i] ?? "").trim();
            const p = params[i];
            if (p.type === "int" && !/^-?\d+$/.test(v))
                return "“" + p.name + "” has to be a whole number";
            if (p.type === "real" && (v === "" || !isFinite(Number(v))))
                return "“" + p.name + "” has to be a number";
            if (p.type === "bool" && !["true", "false"].includes(v))
                return "“" + p.name + "” has to be true or false";
        }
        return "";
    }

    // Pins a command at the end. False when it's pinned already (or the tile
    // is full).
    function pin(target, fn, args, name) {
        const cmd = { target: String(target), fn: String(fn), args: (args ?? []).map(a => String(a).trim()), name: String(name ?? "").trim().slice(0, 40) };
        if (cmd.target === "" || cmd.fn === "" || root.pinned.length >= root.maxPinned || root.isPinned(cmd.target, cmd.fn, cmd.args))
            return false;
        store.commands = root.pinned.concat([cmd]);
        return true;
    }

    function unpin(i) {
        const next = root.pinned.slice();
        if (i < 0 || i >= next.length)
            return;
        next.splice(i, 1);
        store.commands = next;
    }

    function unpinCommand(target, fn, args) {
        const k = root.key({ target: target, fn: fn, args: args ?? [] });
        const i = root.pinned.findIndex(c => root.key(c) === k);
        if (i >= 0)
            root.unpin(i);
    }

    function move(from, to) {
        const next = root.pinned.slice();
        if (from < 0 || from >= next.length || to < 0 || to >= next.length || from === to)
            return;
        const [c] = next.splice(from, 1);
        next.splice(to, 0, c);
        store.commands = next;
    }

    function rename(i, name) {
        const next = root.pinned.slice();
        if (!next[i])
            return;
        next[i] = Object.assign({}, next[i], { name: String(name ?? "").trim().slice(0, 40) });
        store.commands = next;
    }

    // ── Running ──────────────────────────────────────────────────────────────
    function run(cmd) {
        const k = root.key(cmd);
        if (root.runs[k]?.state === "running")
            return;
        root._setRun(k, { state: "running", output: "", error: "", at: Date.now() });
        root.lastKey = k;
        const p = runner.createObject(root, {
            key: k,
            label: root.titleOf(cmd),
            command: ["qs", "ipc", "call", cmd.target, cmd.fn].concat(cmd.args)
        });
        p.running = true;
    }

    function _setRun(k, r) {
        const next = Object.assign({}, root.runs);
        next[k] = r;
        root.runs = next;
    }

    // `qs ipc call` says what went wrong on stdout and still exits 0.
    function _outcome(text, code) {
        const out = String(text ?? "").trim();
        const first = out.split("\n")[0] ?? "";
        if (code === 0 && !/^(Target not found|Function not found|Too (few|many) arguments|Unable to parse argument|No running instance|Could not open config)/i.test(first))
            return { ok: true, output: out, error: "" };
        let why = first || ("It stopped with code " + code + ".");
        if (/^Target not found/i.test(first))
            why = "That part of the shell isn't loaded just now.";
        else if (/^Function not found/i.test(first))
            why = "The shell doesn't take that command any more.";
        return { ok: false, output: "", error: why };
    }

    function _finished(proc) {
        const r = root._outcome(proc.text, proc.code);
        root._setRun(proc.key, { state: r.ok ? "ok" : "failed", output: r.output, error: r.error, at: Date.now() });
        root.ran(proc.key, r.ok, r.output, r.error);
        // (the tile says so itself while the edge line is open)
        if (!r.ok && !EdgeLine.open)
            Quickshell.execDetached(["notify-send", "-a", "Commands", "-i", "dialog-warning", "Couldn't run " + proc.label, r.error]);
    }

    function dismiss(k) {
        if (!root.runs[k])
            return;
        const next = Object.assign({}, root.runs);
        delete next[k];
        root.runs = next;
    }

    // ── Kept ─────────────────────────────────────────────────────────────────
    // Lists read back from the file are array-like, not arrays.
    function _list(v) {
        if (Array.isArray(v))
            return v;
        if (v && typeof v === "object" && typeof v.length === "number")
            return Array.from(v);
        return null;
    }

    function _tidy(raw) {
        const seen = {};
        const out = [];
        for (const c of root._list(raw) ?? []) {
            if (!c || !c.target || !c.fn)
                continue;
            const cmd = { target: String(c.target), fn: String(c.fn), args: (root._list(c.args) ?? []).map(String), name: String(c.name ?? "") };
            const k = root.key(cmd);
            if (seen[k])
                continue;
            seen[k] = true;
            out.push(cmd);
        }
        return out.slice(0, root.maxPinned);
    }

    Process {
        id: showProc
        command: ["qs", "ipc", "show"]
        environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
        stdout: StdioCollector {
            onStreamFinished: {
                const found = root._parseShow(text);
                root.catalogueError = found.length === 0 ? "The shell didn't list its commands." : "";
                if (found.length > 0)
                    root.catalogue = root._withStatic(found);
            }
        }
    }

    Component {
        id: runner

        Process {
            id: proc

            property string key
            property string label
            property string text: ""
            property int code: -1
            property bool _out: false
            property bool _exit: false

            function _maybeDone() {
                if (proc._out && proc._exit) {
                    root._finished(proc);
                    proc.destroy();
                }
            }

            environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
            stdout: StdioCollector {
                onStreamFinished: {
                    proc.text = text;
                    proc._out = true;
                    proc._maybeDone();
                }
            }
            onExited: code => {
                proc.code = code;
                proc._exit = true;
                proc._maybeDone();
            }
        }
    }

    // the zero-argument commands found in the source (scripts/gen-ipc-commands.py)
    property var _static: []

    FileView {
        path: Quickshell.shellPath("ipc-commands.json")
        printErrors: false
        onLoaded: {
            try {
                const all = JSON.parse(text());
                root._static = Array.isArray(all) ? all : [];
            } catch (e) {
                root._static = [];
            }
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/edgecommands.json"
        blockLoading: true
        printErrors: false
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: store
            property var commands: []
        }
    }
}
