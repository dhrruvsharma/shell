pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// Night light: warms the screen through hyprsunset, which sets Hyprland's
// colour transform (applied on scanout, so it costs no rendering and sits
// under the desktop theme's screen effect). On, it sets hyprsunset's
// temperature, starting the daemon when it isn't running; off, it puts the
// screen back and stops the daemon. The choice and the temperature live in
// nightlight.json and are put back when the shell starts.
//
// Needs hyprsunset (`sudo pacman -S hyprsunset`); `available` says whether
// it's installed, and is checked again whenever the control centre opens.
Singleton {
    id: root

    readonly property bool enabled: adapter.enabled
    readonly property int temperature: adapter.temperature
    readonly property int coolest: 6500
    readonly property int warmest: 2500
    property bool available: false

    function setEnabled(on: bool): void {
        if (adapter.enabled === on)
            return;
        adapter.enabled = on;
        _apply();
    }

    function toggle(): void {
        setEnabled(!adapter.enabled);
    }

    // Kelvin, kept between warmest and coolest in steps of 50. Moving it
    // turns the night light on.
    function setTemperature(kelvin: real): void {
        const k = Math.round(Math.max(warmest, Math.min(coolest, kelvin)) / 50) * 50;
        if (k === adapter.temperature && adapter.enabled)
            return;
        adapter.temperature = k;
        adapter.enabled = true;
        _apply();
    }

    function checkAvailable(): void {
        if (!probeProc.running)
            probeProc.running = true;
    }

    // At startup the settings and the check for hyprsunset both have to be
    // in before a night light left on is put back.
    property bool _loaded: false
    property bool _probed: false
    property bool _restored: false

    function _restore(): void {
        if (_restored || !_loaded || !_probed)
            return;
        _restored = true;
        // Off stays off: nothing runs unless it was left on.
        if (adapter.enabled)
            _apply();
    }

    // One run at a time, and a breath between runs (each is a fork of this
    // large process); a change made meanwhile, a drag of the fader, waits
    // and then goes out as the latest state.
    property bool _pending: false
    // (set by hand: inside the timer's own handler its `running` can still
    // read true, and a Process is still running inside its `exited`)
    property bool _working: false

    function _apply(): void {
        if (!available)
            return;
        if (_working) {
            _pending = true;
            return;
        }
        _pending = false;
        _working = true;
        if (adapter.enabled)
            setProc.exec(["hyprctl", "hyprsunset", "temperature", String(adapter.temperature)]);
        else
            offProc.running = true;
    }

    // hyprctl fails when nothing listens on hyprsunset's socket: start it.
    Process {
        id: setProc
        onExited: code => {
            if (code === 0)
                cooldown.start();
            else
                startProc.exec(["sh", "-c",
                    'setsid -f hyprsunset -t "$1" </dev/null >/dev/null 2>&1\n' +
                    // answering, before anything else is sent to it
                    'for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do\n' +
                    '    sleep 0.1\n' +
                    '    hyprctl hyprsunset temperature "$1" >/dev/null 2>&1 && exit 0\n' +
                    'done\n' +
                    'exit 1',
                    "sh", String(adapter.temperature)]);
        }
    }

    Process {
        id: startProc
        onExited: cooldown.start()
    }

    // Back to plain colours first, in case the colour transform were to
    // outlive the daemon.
    Process {
        id: offProc
        command: ["sh", "-c", "hyprctl hyprsunset identity >/dev/null 2>&1 || exit 0; sleep 0.3; pkill -x hyprsunset; exit 0"]
        onExited: cooldown.start()
    }

    Timer {
        id: cooldown
        interval: 90
        onTriggered: {
            root._working = false;
            if (root._pending)
                root._apply();
        }
    }

    Process {
        id: probeProc
        running: true
        command: ["sh", "-c", "command -v hyprsunset"]
        onExited: (code, status) => {
            const was = root.available;
            root.available = code === 0;
            if (!root._probed) {
                root._probed = true;
                root._restore();
            } else if (root.available && !was && adapter.enabled) {
                // installed since: on it goes
                root._apply();
            }
        }
    }

    Timer {
        id: writeTimer
        interval: 300
        onTriggered: stateFile.writeAdapter()
    }

    FileView {
        id: stateFile
        path: Quickshell.env("HOME") + "/.config/quickshell/nightlight.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeTimer.restart()
        onLoaded: {
            root._loaded = true;
            root._restore();
        }
        onLoadFailed: error => {
            root._loaded = true;
            root._restore();
        }

        adapter: JsonAdapter {
            id: adapter
            property bool enabled: false
            property int temperature: 4500
        }
    }
}
