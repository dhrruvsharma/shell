pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell
import qs.services

// System stats for the bar and control center. Everything polled often is read
// straight from /proc and /sys with FileView: spawning a shell pipeline several
// times a second forks the whole (large) shell process each time and stalls the
// thread that drives animations.
Singleton {
    id: stats

    property real cpu: 0
    property real ram: 0
    property real disk: 0
    property real temp: 0
    property string uptime: "0h 0m"

    property int brightness: 0
    // A step came in (the backlight was written) and awaits the OSD.
    property bool _stepped: false

    // Resolved once at startup (see pathProbe); empty until then / if absent.
    property string backlightDir: ""
    property string tempInput: ""
    property int maxBrightness: 0

    property real _lastCpuTotal: 0
    property real _lastCpuIdle: 0

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpuFile.reload()
            memFile.reload()
            uptimeFile.reload()
            if (stats.tempInput !== "")
                tempFile.reload()
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: diskProc.running = true
    }

    // First backlight device (what `brightnessctl` picks by default) and the
    // coretemp "Package id 0" sensor (what `sensors` reported before).
    Process {
        id: pathProbe
        running: true
        command: ["sh", "-c",
            "ls -d /sys/class/backlight/* 2>/dev/null | head -n1; " +
            "l=$(grep -l '^Package id 0$' /sys/class/hwmon/hwmon*/temp*_label 2>/dev/null | head -n1); " +
            "echo \"${l%_label}_input\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n")
                stats.backlightDir = (lines[0] || "").trim()
                const t = (lines[1] || "").trim()
                stats.tempInput = t === "_input" ? "" : t
            }
        }
    }

    // Same meaning as `top`'s 100 - %id: everything but pure idle is busy.
    FileView {
        id: cpuFile
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/)
            // cpu user nice system idle iowait irq softirq steal
            let total = 0
            for (let i = 1; i <= 8; i++)
                total += parseInt(f[i]) || 0
            const idle = parseInt(f[4]) || 0
            const dTotal = total - stats._lastCpuTotal
            const dIdle = idle - stats._lastCpuIdle
            if (stats._lastCpuTotal > 0 && dTotal > 0)
                stats.cpu = 100 * (1 - dIdle / dTotal)
            stats._lastCpuTotal = total
            stats._lastCpuIdle = idle
        }
    }

    // procps-ng 4 `free` "used" = MemTotal - MemAvailable.
    FileView {
        id: memFile
        path: "/proc/meminfo"
        onLoaded: {
            const t = text()
            const total = parseInt((t.match(/MemTotal:\s+(\d+)/) || [])[1]) || 0
            const avail = parseInt((t.match(/MemAvailable:\s+(\d+)/) || [])[1]) || 0
            stats.ram = total > 0 ? (total - avail) / total * 100 : 0
        }
    }

    FileView {
        id: tempFile
        path: stats.tempInput
        onLoaded: stats.temp = (parseInt(text()) || 0) / 1000
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: {
            let seconds = parseInt(text()) || 0
            let hours = Math.floor(seconds / 3600)
            let minutes = Math.floor((seconds % 3600) / 60)
            stats.uptime = hours + "h " + minutes + "m"
        }
    }

    Process {
        id: diskProc
        command: ["df", "--output=pcent", "/"]
        stdout: StdioCollector {
            onStreamFinished: stats.disk = parseFloat(text.split("\n")[1]) || 0
        }
    }

    FileView {
        id: maxBrightnessFile
        path: stats.backlightDir !== "" ? stats.backlightDir + "/max_brightness" : ""
        onLoaded: {
            stats.maxBrightness = parseInt(text()) || 0
            brightnessFile.reload()
        }
    }

    // The kernel notifies actual_brightness on every write to the backlight
    // (a key, brightnessctl, the slider; even one that leaves it where it
    // was, at either end of the range) and on firmware hotkey changes, so
    // inotify brings each step the moment it happens, with no polling.
    FileView {
        path: stats.backlightDir !== "" ? stats.backlightDir + "/actual_brightness" : ""
        watchChanges: true
        onFileChanged: {
            stats._stepped = true
            brightnessFile.reload()
        }
    }

    // Percentage rounded the way `brightnessctl -m` reports it.
    FileView {
        id: brightnessFile
        path: stats.backlightDir !== "" ? stats.backlightDir + "/brightness" : ""
        onLoaded: {
            if (stats.maxBrightness <= 0)
                return
            stats.brightness = Math.round((parseInt(text()) || 0) * 100 / stats.maxBrightness)
            if (stats._stepped) {
                stats._stepped = false
                Osd.show("brightness", stats.brightness)
            }
        }
    }

    // One brightnessctl at a time: a level asked for while one runs (a drag
    // of the control centre's slider) waits, and only the latest is set.
    property int _pendingBrightness: -1

    function setBrightness(v) {
        stats.brightness = v
        Osd.show("brightness", v)  // Show OSD when user changes brightness
        if (setBrightnessProc.running) {
            stats._pendingBrightness = v
            return
        }
        setBrightnessProc.command = ["brightnessctl", "set", v + "%"]
        setBrightnessProc.running = true
    }

    // (sent from a fresh call: inside its own `exited` a Process still
    // counts as running)
    function _sendPendingBrightness() {
        const v = stats._pendingBrightness
        if (v < 0 || setBrightnessProc.running)
            return
        stats._pendingBrightness = -1
        setBrightnessProc.command = ["brightnessctl", "set", v + "%"]
        setBrightnessProc.running = true
    }

    Process {
        id: setBrightnessProc
        onExited: Qt.callLater(stats._sendPendingBrightness)
    }
}
