import "root:/modules/common"
import "root:/services"
import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    property int contribution_number
    // Username lives outside the repo so each install shows its own profile;
    // empty disables the widget. Set with `qs ipc call github setUser <name>`.
    property string author: config.username.trim()
    readonly property bool enabled: author !== ""
    property var contributions: []

    function refresh() {
        if (enabled) getContributions.running = true
    }

    onAuthorChanged: {
        contributions = []
        contribution_number = 0
        refresh()
    }

    IpcHandler {
        target: "github"

        function setUser(name: string): void {
            config.username = name.trim()
        }

        function refresh(): void {
            root.refresh()
        }
    }

    FileView {
        id: configFile
        path: Quickshell.env("HOME") + "/.local/share/quickshell/github.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: config
            property string username: ""
        }
    }

    Timer {
        interval: 600000 // 10 minutes
        running: root.enabled
        repeat: true
        onTriggered: root.refresh()
    }

    // A failed fetch (typically at login, before the network is up) retries
    // soon instead of leaving the calendar empty until the 10-minute refresh.
    Timer {
        id: retryTimer
        interval: 30000
        onTriggered: root.refresh()
    }

    Process {
        id: getContributions
        command: ["curl", `https://github-contributions-api.jogruber.de/v4/${root.author}`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const json = JSON.parse(text);

                    if (!json.contributions || !Array.isArray(json.contributions)) {
                        console.error("Invalid API response:", json);
                        retryTimer.restart();
                        return;
                    }

                    // Calculate level based on contribution count
                    function getContributionLevel(count) {
                        if (count === 0) return 0;
                        if (count <= 3) return 1;
                        if (count <= 6) return 2;
                        if (count <= 9) return 3;
                        return 4;
                    }

                    // Total contributions in the last 365 days
                    const oneYearAgo = new Date();
                    oneYearAgo.setDate(oneYearAgo.getDate() - 365);

                    root.contribution_number = json.contributions
                        .filter(c => new Date(c.date) >= oneYearAgo)
                        .reduce((sum, c) => sum + (c.count || 0), 0);

                    // Last 280 days for the calendar grid (40 weeks × 7 days)
                    const today = new Date();
                    today.setHours(0, 0, 0, 0); // Normalize to start of day

                    const cutoff = new Date(today);
                    cutoff.setDate(cutoff.getDate() - 279); // -279 to include today? Let's check

                    // Transform contributions to include level
                    root.contributions = json.contributions
                        .filter(c => {
                        const date = new Date(c.date);
                        return date >= cutoff && date <= today;
                    })
                        .sort((a, b) => new Date(a.date) - new Date(b.date))
                        .map(c => ({
                        date: c.date,
                        count: c.count || 0,
                        level: getContributionLevel(c.count || 0),
                        intensity: c.intensity || 0 // Keep original if needed
                    }));

                    console.log(`Loaded ${root.contributions.length} contributions, total: ${root.contribution_number}`);

                } catch (e) {
                    console.error("Failed to parse GitHub contributions:", e);
                    retryTimer.restart();
                }
            }
        }
    }
}