pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

// Lock screen progression: XP, level, rank, daily streak, records and
// achievements. Lock.qml asks for a reward on every successful unlock
// (evaluate) and then stores it (commit). Persisted in its own file so it never
// touches settings.json.
Singleton {
    id: root

    readonly property alias xp: adapter.xp
    readonly property alias unlocks: adapter.unlocks
    readonly property alias streak: adapter.streak
    readonly property alias bestStreak: adapter.bestStreak
    readonly property alias lastDay: adapter.lastDay
    readonly property alias bestKeysPerSec: adapter.bestKeysPerSec
    readonly property alias achievements: adapter.achievements

    // False until the file has been read (or found missing), so a slow or
    // failed read can never be overwritten with defaults.
    property bool ready: false

    readonly property int level: levelFor(adapter.xp)
    readonly property string rank: rankFor(level)

    // Streak as it stands right now: it only survives if the last unlock was
    // today or yesterday.
    readonly property int liveStreak: {
        const today = dayKey(new Date());
        const d = new Date();
        d.setDate(d.getDate() - 1);
        return adapter.lastDay === today || adapter.lastDay === dayKey(d) ? adapter.streak : 0;
    }

    readonly property var achievementDefs: [
        { id: "player_one",    name: "Player One",      desc: "Unlock for the first time",                icon: "sports_esports" },
        { id: "night_owl",     name: "Night Owl",       desc: "Unlock between midnight and 5 AM",         icon: "nightlight" },
        { id: "early_bird",    name: "Early Bird",      desc: "Unlock between 5 and 7 AM",                icon: "wb_twilight" },
        { id: "weekend",       name: "Weekend Warrior", desc: "Unlock on a Saturday or Sunday",           icon: "weekend" },
        { id: "blink",         name: "Changed My Mind", desc: "Unlock within 10 seconds of locking",      icon: "timer" },
        { id: "well_rested",   name: "Well Rested",     desc: "Come back after 2+ hours away",            icon: "bedtime" },
        { id: "speed_demon",   name: "Speed Demon",     desc: "Type your passcode at 8+ keys per second", icon: "bolt" },
        { id: "clutch",        name: "Clutch",          desc: "Unlock with a single life left",           icon: "favorite" },
        { id: "perfectionist", name: "Perfectionist",   desc: "10 flawless unlocks in a row",             icon: "verified" },
        { id: "on_fire",       name: "On Fire",         desc: "Reach a 7-day unlock streak",              icon: "local_fire_department" },
        { id: "unstoppable",   name: "Unstoppable",     desc: "Reach a 30-day unlock streak",             icon: "all_inclusive" },
        { id: "centurion",     name: "Centurion",       desc: "Unlock 100 times",                         icon: "military_tech" },
        { id: "gatekeeper",    name: "Gatekeeper",      desc: "Unlock 1,000 times",                       icon: "shield" },
        { id: "double_digits", name: "Double Digits",   desc: "Reach level 10",                           icon: "stars" },
        { id: "veteran",       name: "Veteran",         desc: "Reach level 25",                           icon: "workspace_premium" },
        { id: "legend",        name: "Legend",          desc: "Reach level 50",                           icon: "diamond" }
    ]

    // Unlocked achievement definitions, most recent first.
    readonly property var unlockedDefs: {
        const out = [];
        const ids = adapter.achievements;
        for (let i = ids.length - 1; i >= 0; i--) {
            const def = defFor(ids[i]);
            if (def)
                out.push(def);
        }
        return out;
    }

    readonly property var ranks: [
        [1, "ROOKIE"], [3, "LOCKPICK"], [5, "KEYSMITH"], [8, "CODEBREAKER"],
        [12, "GATEKEEPER"], [16, "CIPHER KNIGHT"], [20, "VAULT WARDEN"],
        [25, "SHADOW OPERATIVE"], [30, "ARCHON"], [40, "ASCENDANT"], [50, "MYTHIC"]
    ]

    // Level L starts at 50·L·(L-1) XP: 100 for L2, 1000 for L5, 4500 for L10.
    function xpForLevel(level) {
        return 50 * level * (level - 1);
    }

    function levelFor(xp) {
        return Math.max(1, Math.floor((1 + Math.sqrt(1 + 0.08 * Math.max(0, xp))) / 2));
    }

    function rankFor(level) {
        let name = ranks[0][1];
        for (let i = 0; i < ranks.length; i++)
            if (level >= ranks[i][0])
                name = ranks[i][1];
        return name;
    }

    function dayKey(date) {
        return Qt.formatDate(date, "yyyy-MM-dd");
    }

    function defFor(id) {
        for (let i = 0; i < achievementDefs.length; i++)
            if (achievementDefs[i].id === id)
                return achievementDefs[i];
        return null;
    }

    function has(id) {
        const ids = adapter.achievements;
        for (let i = 0; i < ids.length; i++)
            if (ids[i] === id)
                return true;
        return false;
    }

    function earned(id, p) {
        switch (id) {
        case "player_one":    return p.unlocks >= 1;
        case "night_owl":     return p.hour < 5;
        case "early_bird":    return p.hour >= 5 && p.hour < 7;
        case "weekend":       return p.weekday === 0 || p.weekday === 6;
        case "blink":         return p.awayMs < 10000;
        case "well_rested":   return p.awayMs >= 2 * 3600000;
        case "speed_demon":   return p.kps >= 8;
        case "clutch":        return p.clutch;
        case "perfectionist": return p.flawlessRun >= 10;
        case "on_fire":       return p.streak >= 7;
        case "unstoppable":   return p.streak >= 30;
        case "centurion":     return p.unlocks >= 100;
        case "gatekeeper":    return p.unlocks >= 1000;
        case "double_digits": return p.level >= 10;
        case "veteran":       return p.level >= 25;
        case "legend":        return p.level >= 50;
        }
        return false;
    }

    // Works out the reward for one unlock without changing anything.
    //   s = { lockedAt, unlockedAt, failures, backspaces, typeMs, length, livesLeft, maxLives }
    function evaluate(s) {
        const now = new Date(s.unlockedAt);
        const today = dayKey(now);
        const y = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
        const yesterday = dayKey(y);
        const lines = [];

        lines.push({ label: "UNLOCKED", xp: 20 });
        if (adapter.lastDay !== today)
            lines.push({ label: "DAILY BONUS", xp: 25 });

        const flawless = s.failures === 0 && s.backspaces === 0;
        if (flawless)
            lines.push({ label: "FLAWLESS", xp: 10 });

        const kps = s.length >= 4 && s.typeMs > 0 ? s.length / (s.typeMs / 1000) : 0;
        if (kps >= 8)
            lines.push({ label: "LIGHTNING FINGERS", xp: 15 });
        else if (kps >= 5)
            lines.push({ label: "QUICK HANDS", xp: 8 });
        const record = kps > 0 && adapter.bestKeysPerSec > 0 && kps > adapter.bestKeysPerSec;
        if (record)
            lines.push({ label: "NEW RECORD", xp: 10 });

        const clutch = s.failures > 0 && s.maxLives > 1 && s.livesLeft === 1;
        if (clutch)
            lines.push({ label: "CLUTCH", xp: 15 });
        else if (s.failures > 0)
            lines.push({ label: "COMEBACK", xp: 5 });

        const awayMs = Math.max(0, s.unlockedAt - s.lockedAt);
        if (awayMs >= 2 * 3600000)
            lines.push({ label: "WELL RESTED", xp: 30 });
        else if (awayMs >= 30 * 60000)
            lines.push({ label: "RESTED", xp: 12 });

        let streak = 1;
        if (adapter.lastDay === today)
            streak = Math.max(1, adapter.streak);
        else if (adapter.lastDay === yesterday)
            streak = adapter.streak + 1;
        const mult = 1 + Math.min(streak - 1, 10) * 0.05;

        const flawlessRun = flawless ? adapter.flawlessRun + 1 : 0;
        let base = 0;
        for (let i = 0; i < lines.length; i++)
            base += lines[i].xp;
        let total = Math.round(base * mult);

        const post = {
            unlocks: adapter.unlocks + 1,
            level: levelFor(adapter.xp + total),
            hour: now.getHours(),
            weekday: now.getDay(),
            awayMs: awayMs,
            kps: kps,
            clutch: clutch,
            flawlessRun: flawlessRun,
            streak: streak
        };
        const newAchievements = [];
        for (let i = 0; i < achievementDefs.length; i++) {
            const def = achievementDefs[i];
            if (!has(def.id) && earned(def.id, post))
                newAchievements.push(def);
        }
        // Every trophy is worth 40 XP on top, outside the streak multiplier.
        total += newAchievements.length * 40;

        return {
            lines: lines,
            multiplier: mult,
            streak: streak,
            total: total,
            xpBefore: adapter.xp,
            xpAfter: adapter.xp + total,
            levelBefore: levelFor(adapter.xp),
            levelAfter: levelFor(adapter.xp + total),
            achievements: newAchievements,
            record: record,
            kps: kps,
            flawlessRun: flawlessRun,
            awayMs: awayMs,
            failures: s.failures,
            day: today
        };
    }

    // Stores a reward from evaluate(). The write is synchronous (blockWrites),
    // so the lock process can quit right after without losing it.
    function commit(r) {
        if (!ready)
            return false;
        adapter.xp = r.xpAfter;
        adapter.unlocks = adapter.unlocks + 1;
        adapter.failedAttempts = adapter.failedAttempts + r.failures;
        adapter.streak = r.streak;
        adapter.bestStreak = Math.max(adapter.bestStreak, r.streak);
        adapter.lastDay = r.day;
        adapter.flawlessRun = r.flawlessRun;
        adapter.bestFlawlessRun = Math.max(adapter.bestFlawlessRun, r.flawlessRun);
        if (r.kps > adapter.bestKeysPerSec)
            adapter.bestKeysPerSec = r.kps;
        adapter.longestAwayMs = Math.max(adapter.longestAwayMs, r.awayMs);
        adapter.totalAwayMs = adapter.totalAwayMs + r.awayMs;
        if (r.achievements.length > 0) {
            const next = [];
            const cur = adapter.achievements;
            for (let i = 0; i < cur.length; i++)
                next.push(cur[i]);
            for (let i = 0; i < r.achievements.length; i++)
                next.push(r.achievements[i].id);
            adapter.achievements = next;
        }
        statsFile.writeAdapter();
        return true;
    }

    Timer {
        id: reloadTimer
        interval: 100
        repeat: false
        onTriggered: statsFile.reload()
    }

    FileView {
        id: statsFile
        path: Quickshell.env("HOME") + "/.cache/quickshell/lockstats.json"
        watchChanges: true
        blockWrites: true
        printErrors: false
        onFileChanged: reloadTimer.restart()
        onLoaded: root.ready = true
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound)
                root.ready = true;
        }

        adapter: JsonAdapter {
            id: adapter
            property int xp: 0
            property int unlocks: 0
            property int failedAttempts: 0
            property int streak: 0
            property int bestStreak: 0
            property string lastDay: ""
            property int flawlessRun: 0
            property int bestFlawlessRun: 0
            property real bestKeysPerSec: 0
            property real longestAwayMs: 0
            property real totalAwayMs: 0
            property list<string> achievements: []
        }
    }
}
