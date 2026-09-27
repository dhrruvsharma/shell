pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

// The wallpaper, drawn by Quickshell itself (modules/wallpaper/WallpaperLayer)
// instead of a separate daemon. `set()` starts the transition on every screen,
// points ~/.cache/current_wallpaper at the new image (the lock screens and the
// Themes panel read it) and regenerates the colour scheme with matugen.
//
// `qs ipc call wallpaper set <path>` and scripts/setwall end up here too.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/Pictures/wallpapers"
    readonly property string link: Quickshell.env("HOME") + "/.cache/current_wallpaper"

    // Absolute path of the wallpaper on screen ("" until the link is read).
    property string current: ""
    // Bumped on every change; layers run their transition on it.
    property int serial: 0
    property bool ready: false

    signal changed(string path)

    function resolve(path) {
        let p = String(path ?? "").trim().replace(/^file:\/\//, "");
        if (p.startsWith("~/"))
            p = Quickshell.env("HOME") + p.substring(1);
        else if (p.length > 0 && !p.startsWith("/"))
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
        apply.exec(["sh", "-c", "[ -f \"$1\" ] || exit 1; ln -sfn \"$1\" \"$HOME/.cache/current_wallpaper\"; matugen image \"$1\" --source-color-index 0", "sh", p]);
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

    // What was on screen last session.
    Process {
        running: true
        command: ["readlink", "-f", root.link]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.current)
                    root.current = text.trim();
                root.ready = true;
            }
        }
    }
}
