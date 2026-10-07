pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick
import qs.settings

// The wallpaper, drawn by Quickshell itself (modules/wallpaper/WallpaperLayer)
// instead of a separate daemon. `set()` starts the transition on every screen
// and runs scripts/wallpaper-apply: ~/.cache/current_wallpaper_source points at
// the file, ~/.cache/current_wallpaper at a still of it (the lock screens and
// the Themes panel read that) and matugen makes the colour scheme from the
// still. A wallpaper can be an image, an animated GIF/WebP or a video; a
// video's still is a frame grabbed from it (scripts/wallpaper-still).
//
// With a wallpaper command set (the picker's settings, e.g. `swww img {}`)
// another program draws the wallpaper instead: WallpaperLayer makes no
// windows, and `set()` runs the command with the file in place of `{}`.
//
// `qs ipc call wallpaper set <path>` and scripts/setwall end up here too.
Singleton {
    id: root

    // The wallpaper folder (the picker's setting), as an absolute path.
    readonly property string dir: expandHome(SettingsConfig.wallpaperDir).replace(/\/+$/, "") || Quickshell.env("HOME") + "/Pictures/wallpapers"
    readonly property string link: Quickshell.env("HOME") + "/.cache/current_wallpaper"
    readonly property string sourceLink: Quickshell.env("HOME") + "/.cache/current_wallpaper_source"

    // The wallpaper command ("" when Quickshell draws the wallpaper).
    readonly property string command: SettingsConfig.wallpaperCommand.trim()
    readonly property bool external: command !== ""
    // Why the last run of the command failed ("" when it didn't).
    property string commandError: ""

    // Each run of the command: ok, or not with the reason.
    signal commandFinished(bool ok, string message)

    // Absolute path of the wallpaper on screen ("" until the link is read).
    property string current: ""
    // Bumped on every change; layers run their transition on it.
    property int serial: 0
    property bool ready: false

    signal changed(string path)

    // What a file is drawn as: "video", "animated" (GIF/WebP, which may
    // still be one frame) or "image".
    function kind(path) {
        const p = String(path ?? "").toLowerCase();
        if (/\.(mp4|webm|mkv|mov|m4v)$/.test(p))
            return "video";
        if (/\.(gif|webp)$/.test(p))
            return "animated";
        return "image";
    }

    // "~" and "~/…" to absolute paths.
    function expandHome(path) {
        const p = String(path ?? "").trim();
        if (p === "~" || p.startsWith("~/"))
            return Quickshell.env("HOME") + p.substring(1);
        return p;
    }

    // A path the other way round, for showing.
    function tildeHome(path) {
        const home = Quickshell.env("HOME");
        return path === home || path.startsWith(home + "/") ? "~" + path.substring(home.length) : path;
    }

    function resolve(path) {
        let p = expandHome(String(path ?? "").trim().replace(/^file:\/\//, ""));
        if (p.length > 0 && !p.startsWith("/"))
            p = dir + "/" + p;
        return p;
    }

    function set(path) {
        const p = resolve(path);
        if (!p)
            return;
        current = p;
        serial++;
        changed(p);
        if (external)
            runCommand(p);
        apply.exec([Quickshell.shellPath("scripts/wallpaper-apply"), p]);
    }

    // The command as a script taking the file as $1: each `{}` becomes it,
    // quoted for wherever the `{}` stands (bare, in "…" or in '…'), and with
    // no `{}` the file goes last.
    function fileInCommand(cmd) {
        let out = "";
        let quote = "";
        let found = false;
        for (let i = 0; i < cmd.length; i++) {
            const c = cmd[i];
            if (c === "{" && cmd[i + 1] === "}") {
                found = true;
                i++;
                out += quote === "'" ? "'\"$1\"'" : quote === "\"" ? "$1" : "\"$1\"";
                continue;
            }
            if (c === "\\" && quote !== "'") {
                out += c + (cmd[i + 1] ?? "");
                i++;
                continue;
            }
            if (quote === "" && (c === "'" || c === "\""))
                quote = c;
            else if (c === quote)
                quote = "";
            out += c;
        }
        return found ? out : out + ' "$1"';
    }

    // Runs the wallpaper command on a file (see fileInCommand). A command still
    // running after two seconds is taken for a daemon (swaybg, mpvpaper) and
    // left running on its own; one that ends sooner reports how it went.
    function runCommand(path) {
        if (!external || !path)
            return;
        const cmd = fileInCommand(command);
        // Prints "<exit code>\t<last line of its errors>" when it's done.
        const script = 'err=$(mktemp)\n'
            + '{ ' + cmd + '\n} </dev/null >/dev/null 2>"$err" &\n'
            + 'pid=$!\n'
            + 'for i in $(seq 20); do kill -0 $pid 2>/dev/null || break; sleep 0.1; done\n'
            + 'if kill -0 $pid 2>/dev/null; then code=0; else wait $pid; code=$?; fi\n'
            + 'printf "%s\\t%s" "$code" "$(grep . "$err" | tail -n 1)"; rm -f "$err"\n';
        commandRun.exec(["sh", "-c", script, "sh", path]);
    }

    Process {
        id: commandRun
        stdout: StdioCollector {
            onStreamFinished: {
                const tab = text.indexOf("\t");
                const code = parseInt(text.substring(0, tab));
                const ok = code === 0;
                root.commandError = ok ? "" : text.substring(tab + 1).trim() || "exit code " + code;
                if (!ok)
                    console.warn("wallpaper command:", root.commandError);
                root.commandFinished(ok, root.commandError);
            }
        }
    }

    Process {
        id: apply
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.warn("wallpaper:", text.trim());
            }
        }
    }

    // What was on screen last session (the still's link, from before
    // videos had their own).
    Process {
        running: true
        command: ["sh", "-c", "for l in \"$1\" \"$2\"; do [ -e \"$l\" ] && exec readlink -f \"$l\"; done", "sh", root.sourceLink, root.link]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.current) {
                    root.current = text.trim();
                    // Tools that don't remember (swaybg, hyprpaper) get
                    // last session's wallpaper back.
                    root.runCommand(root.current);
                }
                root.ready = true;
            }
        }
    }
}
