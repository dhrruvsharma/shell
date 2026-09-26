pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Pacman/AUR update tracker.
//
// Detection is passwordless and never touches the real database:
//   * `checkupdates` (pacman-contrib) diffs against a throwaway synced db  -> repo updates
//   * `yay -Qua`                                                            -> AUR updates
// Both emit lines of the form "name oldver -> newver", which we parse into
// { name, oldVer, newVer, aur } records.
//
// Applying updates DOES need root, so we never handle the password ourselves:
// updateAll()/updateOne() just launch a terminal running `yay`, which wraps
// pacman and prompts for sudo (and any conflict/replace confirmations) right
// there in the terminal. When that terminal window closes we re-check.
Singleton {
    id: root

    // Parsed update records for each source, and the merged list the UI binds to.
    property var repoUpdates: []
    property var aurUpdates: []
    readonly property var updates: root.repoUpdates.concat(root.aurUpdates)
    readonly property int count: root.updates.length

    // True while either probe is in flight. Both must finish before it clears.
    property bool checking: false
    property bool _repoDone: true
    property bool _aurDone: true

    property double lastChecked: 0        // ms epoch of the last completed check
    property string terminal: "kitty"     // terminal used to run the actual upgrade

    // Re-check every 30 minutes, plus once shortly after startup.
    Timer {
        interval: 30 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    function refresh() {
        if (root.checking)
            return;
        root.checking = true;
        root._repoDone = false;
        root._aurDone = false;
        repoProc.running = true;
        aurProc.running = true;
    }

    // "name old -> new" lines -> record array. Blank/garbage lines are skipped.
    function _parse(text, isAur) {
        var out = [];
        if (!text)
            return out;
        var lines = text.trim().split("\n");
        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].trim().split(/\s+/);
            if (parts.length < 4 || parts[2] !== "->")
                continue;
            out.push({
                name: parts[0],
                oldVer: parts[1],
                newVer: parts[3],
                aur: isAur
            });
        }
        return out;
    }

    function _finish() {
        if (root._repoDone && root._aurDone) {
            root.checking = false;
            root.lastChecked = Date.now();
        }
    }

    // Full system upgrade (repo + AUR) in a terminal. yay prompts for the sudo
    // password and any confirmations itself; --hold keeps the window open so the
    // result stays visible, and closing it triggers a re-check.
    function updateAll() {
        upgradeProc.command = [root.terminal, "--hold", "-e", "yay", "-Syu"];
        upgradeProc.running = true;
    }

    // Upgrade a single package. Works for both repo and AUR packages via yay.
    function updateOne(name) {
        if (!name)
            return;
        root.updateMany([name]);
    }

    // Upgrade a specific set of packages in one terminal run.
    function updateMany(names) {
        if (!names || names.length === 0)
            return;
        upgradeProc.command = [root.terminal, "--hold", "-e", "yay", "-S"].concat(names);
        upgradeProc.running = true;
    }

    // checkupdates exits 2 when there are simply no updates; that is not an error,
    // and stdout is empty, so parsing handles it naturally.
    Process {
        id: repoProc
        command: ["checkupdates"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.repoUpdates = root._parse(text, false);
                root._repoDone = true;
                root._finish();
            }
        }
    }

    Process {
        id: aurProc
        command: ["yay", "-Qua"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.aurUpdates = root._parse(text, true);
                root._aurDone = true;
                root._finish();
            }
        }
    }

    Process {
        id: upgradeProc
        // Terminal closed -> the upgrade run is over, refresh the list.
        onExited: root.refresh()
    }
}
