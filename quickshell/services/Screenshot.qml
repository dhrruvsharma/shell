pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Screenshots. scripts/screenshot takes them (Print, SHIFT+Print, CTRL+Print
// and the System panel's Screen tab) and announces each with a notification
// that names the file in its hints. Those notifications are answered here,
// not by the script (Services.Notification hands them over): a click or
// Edit opens the shot in the editor (modules/screenshot), Copy puts it on
// the clipboard, and Rename (a reply typed on the toast) renames the file.
// A shot taken only to the clipboard waits in the cache as a draft until
// Save or Save as moves it into the folder.
//
// The editor is up while `session` is set: { file, dir, draft }, the image,
// the folder it's saved to and whether it's a draft.
// `qs ipc call screenshot edit <file>` opens any image; `last` the newest shot.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string dir: Quickshell.env("SCREENSHOT_DIR") || home + "/Pictures/screenshots"
    readonly property string drafts: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/quickshell/screenshots"
    readonly property string script: Quickshell.shellPath("scripts/screenshot")

    property var session: null
    // The editor has changes nobody saved (another shot then waits).
    property bool unsaved: false

    // What the editor was left with, for the next shot.
    property string tool: "arrow"
    property color ink: "#ff3b30"
    property int size: 1
    property bool fill: false

    // The shot a notification is about ({ file, dir, draft }), or null for
    // any other notification.
    function info(n): var {
        const hints = n?.notification?.hints;
        if (!hints || hints.category !== "x-quickshell.screenshot" || !hints["x-quickshell-file"])
            return null;
        const file = String(hints["x-quickshell-file"]);
        return {
            file: file,
            dir: String(hints["x-quickshell-dir"] || root.dirOf(file)),
            draft: hints["x-quickshell-draft"] === true
        };
    }

    function owns(n): bool {
        return info(n) !== null;
    }

    // A button on its toast or card ("default" for a click on it).
    function act(n, id: string): void {
        const shot = info(n);
        if (!shot)
            return;
        n.popup = false;
        if (id === "copy")
            copy(shot.file);
        else if (id === "save")
            _saveDraft(shot, "");
        else
            edit(shot.file, shot.dir, shot.draft);
    }

    // A name typed on it: Rename, or Save as for a draft.
    function reply(n, text: string): void {
        const shot = info(n);
        if (!shot)
            return;
        n.popup = false;
        if (shot.draft)
            _saveDraft(shot, text);
        else
            _rename(shot, text);
    }

    // Opens the editor on an image. While the editor has unsaved changes
    // it keeps them, and the new one waits.
    function edit(file: string, dir: string, draft: bool): void {
        if (!file || (session && unsaved))
            return;
        session = {
            file: file,
            dir: dir || dirOf(file),
            draft: !!draft
        };
    }

    function editLast(): void {
        _run(["sh", "-c", 'ls -t -- "$1"/*.png 2>/dev/null | head -n 1', "sh", dir], (code, out) => {
            if (out.trim())
                edit(out.trim(), "", false);
        });
    }

    function close(): void {
        session = null;
        unsaved = false;
    }

    // ── Files ────────────────────────────────────────────────────────────────

    function copy(file: string): void {
        Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png < "$1"', "sh", file]);
    }

    function exists(path: string, done): void {
        _run(["test", "-e", path], code => done(code === 0));
    }

    function makeDir(path: string, done): void {
        _run(["mkdir", "-p", "--", path], code => done(code === 0));
    }

    // Moves `from` to dir/stem+ext; with `free`, to the first name that's
    // free (stem-1, stem-2…) if that one's taken, else it fails (3). `done`
    // gets the exit code and where it went.
    function move(from: string, dir: string, stem: string, ext: string, free: bool, done): void {
        _run(["sh", "-c", `
            to=$2/$3$4
            if [ -e "$to" ]; then
                [ "$5" = free ] || exit 3
                i=1
                while [ -e "$2/$3-$i$4" ]; do i=$((i + 1)); done
                to=$2/$3-$i$4
            fi
            mkdir -p -- "$2" && mv -- "$1" "$to" && printf %s "$to"`, "sh", from, dir, stem, ext, free ? "free" : ""], done);
    }

    function remove(path: string): void {
        _run(["rm", "-f", "--", path], null);
    }

    // To the bin (a draft's just deleted).
    function trash(path: string, done): void {
        _run(path.startsWith(drafts + "/") ? ["rm", "-f", "--", path] : ["gio", "trash", "--", path], done);
    }

    // The notifications about a file go: it was renamed, saved over or binned.
    function forget(file: string): void {
        for (const n of Notification.data.slice()) {
            if (info(n)?.file === file)
                Notification.dismiss(n);
        }
    }

    function announce(file: string, summary: string): void {
        Quickshell.execDetached([script, "notify", file, summary]);
    }

    // ── Names ────────────────────────────────────────────────────────────────

    function dirOf(path: string): string {
        const i = path.lastIndexOf("/");
        return i > 0 ? path.slice(0, i) : "/";
    }

    function nameOf(path: string): string {
        return path.slice(path.lastIndexOf("/") + 1);
    }

    function extOf(path: string): string {
        const name = nameOf(path);
        const i = name.lastIndexOf(".");
        return i > 0 ? name.slice(i) : "";
    }

    function stemOf(path: string): string {
        const name = nameOf(path);
        return name.slice(0, name.length - extOf(path).length);
    }

    // A typed name as a file name without its extension: trimmed, slashes
    // made dashes, the extension dropped if it was typed too, no leading
    // dots (a hidden file). "" when nothing's left.
    function cleanStem(text: string, ext: string): string {
        let s = String(text ?? "").replace(/[\/\x00-\x1f]/g, "-").trim();
        if (ext && s.toLowerCase().endsWith(ext.toLowerCase()))
            s = s.slice(0, s.length - ext.length).trim();
        return s.replace(/^\.+/, "").trim();
    }

    // ~ for the home folder.
    function pretty(path: string): string {
        return path === home ? "~" : path.startsWith(home + "/") ? "~" + path.slice(home.length) : path;
    }

    // ── From the toast ───────────────────────────────────────────────────────

    function _rename(shot, text: string): void {
        const ext = extOf(shot.file);
        const stem = cleanStem(text, ext);
        if (!stem || stem === stemOf(shot.file))
            return;
        move(shot.file, dirOf(shot.file), stem, ext, false, (code, to) => {
            if (code !== 0) {
                // Said on a fresh one, which can be renamed again.
                forget(shot.file);
                announce(shot.file, code === 3 ? `There's already a ${stem}${ext}` : "Couldn't rename it");
                return;
            }
            forget(shot.file);
            announce(to, "Renamed");
        });
    }

    // Into the folder, under its own name (the next free one), or the one typed.
    function _saveDraft(shot, text: string): void {
        const ext = extOf(shot.file);
        const stem = cleanStem(text, ext);
        move(shot.file, shot.dir, stem || stemOf(shot.file), ext, !stem, (code, to) => {
            forget(shot.file);
            if (code !== 0) {
                announce(shot.file, code === 3 ? `There's already a ${stem}${ext}` : "Couldn't save it");
                return;
            }
            announce(to, "Screenshot saved");
        });
    }

    // A command run to its end; `done` gets its exit code and output.
    function _run(command, done): void {
        const job = jobComp.createObject(root, {
            command: command,
            done: done
        }) as Process;
        job.running = true;
    }

    Component {
        id: jobComp

        Process {
            id: job

            property var done: null

            stdout: StdioCollector {
                id: out
            }

            onExited: code => {
                const done = job.done;
                const text = out.text;
                job.destroy();
                if (done)
                    done(code, text);
            }
        }
    }
}
