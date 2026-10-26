pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// How things open: on hover or on a click, set in the customizer's book.
//   - the screen-edge strips: the launcher (left edge), the notes drawer
//     (bottom) and the GitHub/timer popout (right);
//   - the bar's widgets' panels: the calendar (clock), the system panel
//     (CPU), the network panel (Wi-Fi, Bluetooth), the media panel (now
//     playing) and the updates panel. The gear and the memory widget open
//     their big panels on a click whatever this says.
//
// A panel opened by hover is a peek: it closes again a moment after the
// pointer has left it and what opened it, unless it's been clicked into
// (that keeps it, as a click on its widget does). The launcher, which takes
// the whole screen, stays until it's closed. A bar widget waits
// `barDelay` ms under the pointer first, so sweeping across the bar
// doesn't open everything on the way.
//
// Triggers report hover and clicks here, panels their hover and presses;
// shell.qml carries out `requested` and reports back what's open.
//
// Settings: ~/.config/quickshell/opening.json.
Singleton {
    id: root

    readonly property var edgeTargets: ["launcher", "notes", "github"]
    readonly property var barTargets: ["calendar", "system", "network", "bluetooth", "media", "updates"]

    readonly property alias launcher: adapter.launcher
    readonly property alias notes: adapter.notes
    readonly property alias github: adapter.github
    readonly property alias bar: adapter.bar
    readonly property int barDelay: Math.max(0, Math.min(1500, adapter.barDelay))
    readonly property alias closeOnLeave: adapter.closeOnLeave
    readonly property int closeDelay: Math.max(150, Math.min(3000, adapter.closeDelay))

    // open | close | toggle; `arg` is the trigger's (where the clock sits).
    signal requested(string target, string action, var arg)

    function mode(target) {
        if (root.barTargets.includes(target))
            return adapter.bar;
        return ({ launcher: adapter.launcher, notes: adapter.notes, github: adapter.github })[target] ?? "click";
    }

    function hovers(target) {
        return root.mode(target) === "hover";
    }

    function setMode(target, mode) {
        if (mode !== "hover" && mode !== "click")
            return;
        if (target === "bar")
            adapter.bar = mode;
        else if (target === "launcher")
            adapter.launcher = mode;
        else if (target === "notes")
            adapter.notes = mode;
        else if (target === "github")
            adapter.github = mode;
    }

    function setBarDelay(ms) {
        adapter.barDelay = Math.round(Math.max(0, Math.min(1500, ms)));
    }

    function setCloseOnLeave(on) {
        adapter.closeOnLeave = on;
    }

    function setCloseDelay(ms) {
        adapter.closeDelay = Math.round(Math.max(150, Math.min(3000, ms)));
    }

    function reset() {
        adapter.launcher = "hover";
        adapter.notes = "click";
        adapter.github = "hover";
        adapter.bar = "click";
        adapter.barDelay = 300;
        adapter.closeOnLeave = true;
        adapter.closeDelay = 600;
    }

    // ── Peeking ──────────────────────────────────────────────────────────────
    // What hover opened (closes again on leaving), and whether a click has
    // kept it.
    property string peek: ""
    property bool pinned: false
    // What's open, as shell.qml reports it.
    property var openNow: ({})
    property var _trigger: ({})
    property var _panel: ({})
    property string _waiting: ""
    property var _waitingArg: null

    function _set(map, key, on) {
        const next = Object.assign({}, map);
        next[key] = on;
        return next;
    }

    function _over(target) {
        return root._trigger[target] === true || root._panel[target] === true
            // Wi-Fi and Bluetooth share the network panel.
            || (target === "network" || target === "bluetooth") && (root._panel.network === true || root._panel.bluetooth === true);
    }

    function isOpen(target) {
        return root.openNow[target] === true;
    }

    // The pointer reached a trigger (an edge strip or a bar widget).
    function entered(target, arg) {
        root._trigger = root._set(root._trigger, target, true);
        leaveTimer.stop();
        if (!root.hovers(target))
            return;
        if (root.edgeTargets.includes(target)) {
            root._peekAt(target, arg);
        } else {
            root._waiting = target;
            root._waitingArg = arg;
            dwell.interval = Math.max(1, root.barDelay);
            dwell.restart();
        }
    }

    function left(target) {
        root._trigger = root._set(root._trigger, target, false);
        if (root._waiting === target) {
            dwell.stop();
            root._waiting = "";
        }
        root._checkLeave();
    }

    function clicked(target, arg) {
        dwell.stop();
        root._waiting = "";
        if (root.peek === target && !root.pinned && root.isOpen(target)) {
            // A click on what's peeking keeps it.
            root.pinned = true;
            return;
        }
        if (root.peek === target) {
            root.peek = "";
            root.pinned = false;
        }
        root.requested(target, "toggle", arg);
    }

    function panelHovered(target, on) {
        root._panel = root._set(root._panel, target, on);
        if (on)
            leaveTimer.stop();
        else
            root._checkLeave();
    }

    // A press inside a panel keeps a peek open.
    function panelPressed(target) {
        if (root.peek === target || (target === "network" || target === "bluetooth") && (root.peek === "network" || root.peek === "bluetooth"))
            root.pinned = true;
    }

    // shell.qml: what's open now ({ target: bool }).
    function report(states) {
        root.openNow = states;
        if (root.peek && !states[root.peek]) {
            root.peek = "";
            root.pinned = false;
            leaveTimer.stop();
        }
    }

    function _peekAt(target, arg) {
        if (root.isOpen(target))
            return;
        // One peek at a time.
        if (root.peek && root.peek !== target && !root.pinned)
            root.requested(root.peek, "close", null);
        if (target === "launcher") {
            root.peek = "";
        } else {
            root.peek = target;
            root.pinned = false;
        }
        root.requested(target, "open", arg);
    }

    function _checkLeave() {
        if (!root.peek || root.pinned || !adapter.closeOnLeave || root._over(root.peek))
            return;
        leaveTimer.restart();
    }

    Timer {
        id: dwell
        onTriggered: {
            const t = root._waiting;
            root._waiting = "";
            if (t && root._trigger[t] === true)
                root._peekAt(t, root._waitingArg);
        }
    }

    Timer {
        id: leaveTimer
        interval: root.closeDelay
        onTriggered: {
            if (root.peek && !root.pinned && !root._over(root.peek)) {
                const t = root.peek;
                root.peek = "";
                root.requested(t, "close", null);
            }
        }
    }

    // ── Settings file ────────────────────────────────────────────────────────
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
        path: Quickshell.env("HOME") + "/.config/quickshell/opening.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: {
            if (Date.now() > root._quietUntil)
                reload();
        }
        onAdapterUpdated: writeTimer.restart()

        adapter: JsonAdapter {
            id: adapter
            property string launcher: "hover"
            property string notes: "click"
            property string github: "hover"
            property string bar: "click"
            property int barDelay: 300
            property bool closeOnLeave: true
            property int closeDelay: 600
        }
    }
}
