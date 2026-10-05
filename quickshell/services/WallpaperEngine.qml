pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

// The wallpaper, drawn by Quickshell itself (modules/wallpaper/WallpaperLayer)
// instead of a separate daemon. `set()` starts the transition on every screen
// and runs scripts/wallpaper-apply: ~/.cache/current_wallpaper_source points at
// the file, ~/.cache/current_wallpaper at a still of it (the lock screens and
// the Themes panel read that) and matugen makes the colour scheme from the
// still. A wallpaper can be an image, an animated GIF/WebP or a video; a
// video's still is a frame grabbed from it (scripts/wallpaper-still).
//
// `qs ipc call wallpaper set <path>` and scripts/setwall end up here too.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/Pictures/wallpapers"
    readonly property string link: Quickshell.env("HOME") + "/.cache/current_wallpaper"
    readonly property string sourceLink: Quickshell.env("HOME") + "/.cache/current_wallpaper_source"

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
        apply.exec([Quickshell.shellPath("scripts/wallpaper-apply"), p]);
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
                if (!root.current)
                    root.current = text.trim();
                root.ready = true;
            }
        }
    }
}
