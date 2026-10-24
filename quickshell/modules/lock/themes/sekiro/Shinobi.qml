pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.desktoptheme
import qs.services as Services

// Palette, type and lore for the Sekiro desktop theme and its "Deathblow"
// lock screen, after FromSoftware's Sekiro: Shadows Die Twice (2019): the
// crimson of a deathblow beside the wallpaper's colour as the season on
// the land (services/DesktopTheme.qml accentOf/accent2Of, tone "shinobi"),
// the posture gauge's gold running to orange as it fills, the resurrection
// nodes' rose, ink, paper, moonlight; where the shinobi is at each hour of
// the day (an area of Ashina, the Sculptor's Idol he rests at there, the
// foe he faces) and the season falling on the land; the shinobi's ranks
// for the shared lock level, XP as skill experience and achievements as
// memories.
Singleton {
    id: root

    // Type: an antique Mincho for numerals and names, a book Mincho for
    // the rest, and a brush face for the big characters.
    readonly property string display: "Zen Antique"
    readonly property string book: "Zen Old Mincho"
    readonly property string brush: "Yuji Boku"

    // ── Colours ─────────────────────────────────────────────────────────
    // The theme's accents: the deathblow's crimson, and the season.
    readonly property color blood: Services.DesktopTheme.accentOf("sekiro")
    readonly property color land: Services.DesktopTheme.accent2Of("sekiro")
    readonly property color landLight: Qt.hsla(Math.max(0, Qt.color(land).hslHue), 0.55, 0.76, 1)
    // The red of the big characters, deeper than the accent.
    readonly property color kanji: "#c41e2a"
    // The posture gauge, filling: gold, orange, and red as it breaks.
    readonly property color postureGold: "#e6b23c"
    readonly property color postureOrange: "#ee7a24"
    readonly property color postureRed: "#e8452c"
    // The vitality gauge's copper, and the resurrection nodes' rose.
    readonly property color vitality: "#c2582c"
    readonly property color vitalityLow: "#e23b2b"
    readonly property color node: "#d8417a"
    readonly property color nodeGlow: "#ff86b2"
    readonly property color ink: "#0c0a0a"
    readonly property color lacquer: "#151112"
    readonly property color paper: "#e8e0cd"
    readonly property color ivory: "#efe7d6"
    readonly property color gold: "#c9a55c"
    readonly property color steel: "#b8bcc2"
    readonly property color moon: "#d6deea"
    readonly property color night: "#0a0d15"
    readonly property color sakura: "#f3b9c8"
    readonly property color momiji: "#d9542c"
    readonly property color susuki: "#dcc890"
    readonly property color danger: "#ff5a48"

    function alpha(c, x) {
        const q = Qt.color(c);
        return Qt.rgba(q.r, q.g, q.b, x);
    }

    function hueOf(c) {
        return Math.max(0, Qt.color(c).hslHue);
    }

    // 3687 -> "3,687".
    function count(n) {
        return String(Math.max(0, Math.round(n))).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    }

    function cap(s) {
        return s.length > 0 ? s.charAt(0).toUpperCase() + s.slice(1) : s;
    }

    // The posture gauge's colour at a fill of `v` (0..1): gold, turning
    // orange as it nears breaking, red at the very end.
    function postureColor(v) {
        const g = Qt.color(postureGold), o = Qt.color(postureOrange), r = Qt.color(postureRed);
        const a = Math.max(0, Math.min(1, (v - 0.45) / 0.4));
        const b = Math.max(0, Math.min(1, (v - 0.9) / 0.1));
        const m = (x, y, t) => x + (y - x) * t;
        const c1 = Qt.rgba(m(g.r, o.r, a), m(g.g, o.g, a), m(g.b, o.b, a), 1);
        return Qt.rgba(m(c1.r, r.r, b), m(c1.g, r.g, b), m(c1.b, r.b, b), 1);
    }

    // ── Who, and where ──────────────────────────────────────────────────
    readonly property string userName: Quickshell.env("USER") || "wolf"
    property string host: ""
    readonly property string hold: cap(host || userName)

    FileView {
        path: "/etc/hostname"
        printErrors: false
        onLoaded: root.host = text().trim().split(".")[0]
    }

    // ── The day in Ashina ───────────────────────────────────────────────
    // Twelve stretches of two hours from midnight: the area the shinobi is
    // in, the Sculptor's Idol he rests at there, what is happening, and
    // the foe he faces (the lock screen's).
    readonly property var stretches: [
        { area: "Ashina Depths", idol: "Hidden Forest", deed: "the mist hides the way", foe: "Headless Ape" },
        { area: "Mibu Village", idol: "Wedding Cave Door", deed: "the villagers tend crops no one can see", foe: "Corrupted Monk" },
        { area: "Dilapidated Temple", idol: "Dilapidated Temple", deed: "the Sculptor carves by the fire", foe: "Demon of Hatred" },
        { area: "Ashina Outskirts", idol: "Outskirts Wall – Stairway", deed: "the soldiers stand to on the walls", foe: "Gyoubu Masataka Oniwa" },
        { area: "Ashina Castle", idol: "Ashina Castle Gate", deed: "the gate opens on the day", foe: "Genichiro Ashina" },
        { area: "Ashina Castle", idol: "Upper Tower – Ashina Dojo", deed: "swordsmen drill in the dojo", foe: "Emma, the Gentle Blade" },
        { area: "Senpou Temple, Mt. Kongo", idol: "Main Hall", deed: "the monks seek the waters of life", foe: "Folding Screen Monkeys" },
        { area: "Sunken Valley", idol: "Gun Fort", deed: "musketeers watch the cliffs", foe: "Guardian Ape" },
        { area: "Ashina Castle", idol: "Castle Tower Lookout", deed: "the sun goes down behind the keep", foe: "Great Shinobi Owl" },
        { area: "Hirata Estate", idol: "Bamboo Thicket Slope", deed: "the estate burns, in a memory", foe: "Lady Butterfly" },
        { area: "Fountainhead Palace", idol: "Flower Viewing Stage", deed: "petals fall in the divine realm", foe: "Divine Dragon" },
        { area: "Ashina Reservoir", idol: "Ashina Reservoir", deed: "the Sword Saint waits in the silver grass", foe: "Isshin, the Sword Saint" }
    ]

    function stretch(d) {
        return stretches[Math.floor(d.getHours() / 2)];
    }

    // "Ashina Castle  ·  Castle Tower Lookout", or just the area where its
    // idol bears its name.
    function place(s) {
        return s.idol === s.area ? s.area : s.area + "  ·  " + s.idol;
    }

    // The season falling on Ashina, by month: sakura, the green summer,
    // the maples turning, snow; `fall` is what drifts down the screen.
    function season(d) {
        const m = d.getMonth();
        if (m >= 2 && m <= 4)
            return { name: "Sakura season", line: "petals fall at the Fountainhead", kanji: "桜", fall: 0 };
        if (m >= 5 && m <= 7)
            return { name: "Green summer", line: "fireflies over the Sunken Valley", kanji: "蛍", fall: 1 };
        if (m >= 8 && m <= 10)
            return { name: "Momiji season", line: "the maples of Ashina burn red", kanji: "紅葉", fall: 2 };
        return { name: "Snow on Ashina", line: "snow lies on the castle roofs", kanji: "雪", fall: 3 };
    }

    // "Thursday, the 23rd of October"
    function date(d) {
        return Qt.formatDate(d, "dddd") + ", the " + Clocks.ordinal(d.getDate()) + " of " + Qt.formatDate(d, "MMMM");
    }

    // ── Words ───────────────────────────────────────────────────────────
    readonly property string motto: "Hesitation is defeat."
    // The big characters: death, the shinobi execution, resurrection,
    // peril, the Sculptor's Idol (a "demon Buddha"), and the one-armed wolf.
    readonly property string death: "死"
    readonly property string execution: "忍殺"
    readonly property string resurrection: "回生"
    readonly property string peril: "危"
    readonly property string idolKanji: "鬼仏"
    readonly property string wolfKanji: "隻狼"

    // ── The shinobi's path, by lock level (thresholds as LockStats' ranks)
    readonly property var ranks: [
        [1, "Nameless orphan"], [3, "Wolf"], [5, "Shinobi"], [8, "Nightjar"], [12, "Lone Shadow"], [16, "Sekiro"],
        [20, "Ashina Elite"], [25, "One of the Seven Spears"], [30, "Great Shinobi"], [40, "Sword Saint"], [50, "Shura"]
    ]

    function rank(level) {
        let name = ranks[0][1];
        for (let i = 0; i < ranks.length; i++)
            if (level >= ranks[i][0])
                name = ranks[i][1];
        return name;
    }
}
