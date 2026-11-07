pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// The screen tools' side of things (the edge line's pill, the system
// panel's Screen tab): recording the screen through scripts/screenrecord
// (wf-recorder), with the system's sound or without (`withSound`, kept for
// the next recording), and screenshots through scripts/screenshot.
//
// The script runs on its own, so a recording outlives the shell reloading;
// what it's doing comes back through its state file in $XDG_RUNTIME_DIR
// (`recording`, since when, with sound or not). A wf-recorder started some
// other way counts as recording too (`external`), and Stop stops it.
//
// When a recording is saved the script posts a notification that's the
// shell's to answer (services/Notification hands it here): a click or Play
// opens the video, Show in folder its folder.
//
// The choice of sound: ~/.config/quickshell/screenrecord.json.
Singleton {
    id: root

    // (stand-ins can be put here to try it out)
    property string script: Quickshell.shellPath("scripts/screenrecord")
    property string shotScript: Quickshell.shellPath("scripts/screenshot")
    property string statePath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-screenrecord.json"

    // Record the system's sound next time (what the default output plays).
    readonly property bool withSound: settings.sound

    // What the script says: { recording, pid, file, since (ms), sound,
    // source } while it records; { recording: false, file, error } after.
    property var current: ({ recording: false })
    // wf-recorder running without the script having started it.
    property bool external: false
    readonly property bool recording: !!root.current.recording || root.external
    // The recording going now has the system's sound.
    readonly property bool soundNow: !!root.current.recording && !!root.current.sound
    // Asked to start, and not yet under way (a moment, while the script
    // finds the sound's source).
    property bool starting: false
    // How long it's been recording, in seconds, and as "1:23".
    property int elapsed: 0
    readonly property string clock: root.format(root.elapsed)

    function format(secs) {
        const s = Math.max(0, Math.floor(secs));
        const pad = n => (n < 10 ? "0" : "") + n;
        return s >= 3600 ? Math.floor(s / 3600) + ":" + pad(Math.floor(s % 3600 / 60)) + ":" + pad(s % 60) : Math.floor(s / 60) + ":" + pad(s % 60);
    }

    function start() {
        if (root.recording || root.starting)
            return;
        root.starting = true;
        startWait.restart();
        Quickshell.execDetached([root.script, "start", root.withSound ? "sound" : "mute"]);
    }

    function stop() {
        root.starting = false;
        Quickshell.execDetached([root.script, "stop"]);
        // (one started elsewhere leaves no state to say it stopped)
        if (root.external)
            recheck.restart();
    }

    function toggle() {
        if (root.recording)
            root.stop();
        else
            root.start();
    }

    function setSound(on) {
        settings.sound = !!on;
    }

    // (only for the next recording: one going on keeps what it has)
    function toggleSound() {
        if (!root.recording && !root.starting)
            root.setSound(!root.withSound);
    }

    // area | output | active | screen (scripts/screenshot); copied and
    // saved, and its notification opens the editor.
    function screenshot(target) {
        Quickshell.execDetached([root.shotScript, "copysave", target || "area"]);
    }

    // Whether wf-recorder runs, for one started some other way (and to
    // drop a state left saying it records by a recording that died).
    function look() {
        if (!pgrep.running)
            pgrep.running = true;
    }

    // ── Its notification ─────────────────────────────────────────────────────
    function info(n) {
        const hints = n?.notification?.hints;
        if (!hints || hints.category !== "x-quickshell.recording" || !hints["x-quickshell-file"])
            return null;
        const file = String(hints["x-quickshell-file"]);
        return { file: file, dir: String(hints["x-quickshell-dir"] || file.slice(0, file.lastIndexOf("/"))) };
    }

    function owns(n) {
        return root.info(n) !== null;
    }

    // A button on its toast or card ("default" for a click on it).
    function act(n, id) {
        const rec = root.info(n);
        if (!rec)
            return;
        n.popup = false;
        Quickshell.execDetached(["xdg-open", id === "folder" ? rec.dir : rec.file]);
    }

    // ── Kept up to date ──────────────────────────────────────────────────────
    function _read(text) {
        let s;
        try {
            s = JSON.parse(text);
        } catch (e) {
            return;
        }
        if (!s || typeof s !== "object")
            return;
        root.current = s;
        if (s.recording) {
            root.starting = false;
            root.external = false;
            root.elapsed = s.since ? Math.max(0, Math.floor((Date.now() - s.since) / 1000)) : 0;
        } else if (root.starting && (s.error ?? "") !== "") {
            root.starting = false;
        }
    }

    Component.onCompleted: root.look()

    Timer {
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.elapsed = root.current.since ? Math.max(0, Math.floor((Date.now() - root.current.since) / 1000)) : root.elapsed + 1
        onRunningChanged: {
            if (!running)
                root.elapsed = 0;
        }
    }

    // (the script says it's under way within a moment, or that it failed)
    Timer {
        id: startWait
        interval: 6000
        onTriggered: root.starting = false
    }

    Timer {
        id: recheck
        interval: 800
        onTriggered: root.look()
    }

    Process {
        id: pgrep
        command: ["pgrep", "-x", "wf-recorder"]
        onExited: code => {
            const on = code === 0;
            root.external = on && !root.current.recording;
            if (!on && root.current.recording)
                root.current = { recording: false, file: root.current.file ?? "", error: "" };
        }
    }

    FileView {
        id: stateFile
        path: root.statePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root._read(text())
        // (made, so there's a file to watch for the script's writes)
        onLoadFailed: setText(JSON.stringify({ recording: false, file: "", error: "" }) + "\n")
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/screenrecord.json"
        blockLoading: true
        printErrors: false
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: settings
            property bool sound: true
        }
    }
}
