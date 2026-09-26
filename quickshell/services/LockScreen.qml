pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

// Lock screen themes: the registry of available designs and which ones are
// active. Lock.qml asks pick() for the theme of each lock; the picker panel
// (modules/lockthemes) edits the selection. With shuffle off the first active
// theme is always used; with it on, each lock draws a random one from the
// active set (never the same twice in a row when there's a choice).
//
// Timings are the theme's choreography lengths, which LockContext uses to run
// the intro, the reward hold and the exit.
Singleton {
    id: root

    readonly property string defaultTheme: "arcade"

    readonly property var themes: [
        {
            id: "arcade",
            name: "Pause Menu",
            tagline: "Arcade HUD",
            description: "Sci-fi game HUD with XP, ranks, combos, lives and trophies. Tiles fly away on lock; an XP read-out on unlock.",
            source: Qt.resolvedUrl("../modules/lock/themes/arcade/ArcadeSurface.qml"),
            introMs: 1250, outroMs: 900, rewardBaseMs: 1150, rewardLevelUpMs: 900, rewardAchievementMs: 450,
            ambient: false
        },
        {
            id: "xianxia",
            name: "Sealed Cave Abode",
            tagline: "Xianxia · 洞府封印",
            description: "Your wallpaper as a moonlit ink painting, sealed by a golden formation. Incense sticks are lives; unlocking is a breakthrough.",
            source: Qt.resolvedUrl("../modules/lock/themes/xianxia/XianxiaSurface.qml"),
            introMs: 1700, outroMs: 1150, rewardBaseMs: 1400, rewardLevelUpMs: 1000, rewardAchievementMs: 450,
            ambient: true
        },
        {
            id: "terminal",
            name: "Mainframe",
            tagline: "Phosphor CRT terminal",
            description: "A glowing CRT console: the desktop collapses to a line and a dot, and you log in like it's 1985.",
            source: Qt.resolvedUrl("../modules/lock/themes/terminal/TerminalSurface.qml"),
            introMs: 1350, outroMs: 1050, rewardBaseMs: 1500, rewardLevelUpMs: 500, rewardAchievementMs: 350,
            ambient: true
        },
        {
            id: "cosmos",
            name: "Astral",
            tagline: "Deep space",
            description: "The desktop spirals into a singularity; your passcode charts a constellation across a living starfield.",
            source: Qt.resolvedUrl("../modules/lock/themes/cosmos/CosmosSurface.qml"),
            introMs: 1600, outroMs: 1100, rewardBaseMs: 1300, rewardLevelUpMs: 900, rewardAchievementMs: 450,
            ambient: true
        },
        {
            id: "zen",
            name: "Still",
            tagline: "Minimal glass",
            description: "Just the time, a soft focus pull and a glass field. The quickest unlock of the set.",
            source: Qt.resolvedUrl("../modules/lock/themes/zen/ZenSurface.qml"),
            introMs: 900, outroMs: 520, rewardBaseMs: 280, rewardLevelUpMs: 0, rewardAchievementMs: 0,
            ambient: false
        }
    ]

    readonly property alias active: adapter.active
    readonly property alias shuffle: adapter.shuffle
    readonly property alias last: adapter.last
    property bool ready: false

    // The active ids that still exist, in order; never empty.
    readonly property var activeIds: {
        const out = [];
        const ids = adapter.active;
        for (let i = 0; i < ids.length; i++)
            if (has(ids[i]) && !out.includes(ids[i]))
                out.push(ids[i]);
        return out.length > 0 ? out : [defaultTheme];
    }

    // The theme used when shuffle is off.
    readonly property string current: activeIds[0]

    function has(id) {
        return themes.some(t => t.id === id);
    }

    function theme(id) {
        return themes.find(t => t.id === id) ?? themes.find(t => t.id === defaultTheme);
    }

    function isActive(id) {
        return adapter.shuffle ? activeIds.includes(id) : current === id;
    }

    // Single mode: make `id` the theme. Shuffle mode: add it to / remove it
    // from the rotation (which always keeps at least one theme).
    function select(id) {
        if (!has(id))
            return;
        if (!adapter.shuffle) {
            adapter.active = [id];
            return;
        }
        const next = activeIds.slice();
        const i = next.indexOf(id);
        if (i < 0)
            next.push(id);
        else if (next.length > 1)
            next.splice(i, 1);
        adapter.active = next;
    }

    function setShuffle(on) {
        adapter.shuffle = on;
    }

    function pick() {
        const ids = activeIds;
        if (!adapter.shuffle || ids.length === 1)
            return ids[0];
        const fresh = ids.filter(id => id !== adapter.last);
        const pool = fresh.length > 0 ? fresh : ids;
        return pool[Math.floor(Math.random() * pool.length)];
    }

    // Lock.qml records what it showed, so shuffle can avoid repeats.
    function remember(id) {
        if (adapter.shuffle && adapter.last !== id)
            adapter.last = id;
    }

    Timer {
        id: writeTimer
        interval: 100
        repeat: false
        onTriggered: settingsFile.writeAdapter()
    }

    Timer {
        id: reloadTimer
        interval: 100
        repeat: false
        onTriggered: settingsFile.reload()
    }

    FileView {
        id: settingsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/lockscreen.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reloadTimer.restart()
        onAdapterUpdated: writeTimer.restart()
        onLoaded: root.ready = true
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound)
                root.ready = true;
        }

        adapter: JsonAdapter {
            id: adapter
            property list<string> active: ["arcade"]
            property bool shuffle: false
            property string last: ""
        }
    }
}
