pragma Singleton
import QtQuick
import Quickshell
import qs.services as Services

// Palette, type and the ocean for the Abyss desktop theme and its
// "Bathysphere" lock screen: the wallpaper's colour as bioluminescence and a
// sea-glow of lume beside it (services/DesktopTheme.qml accentOf/accent2Of,
// tone "lume"), dark water, painted steel and the red of the alarm lamps;
// the zone of the ocean each hour belongs to (noon at the surface, midnight
// at the bottom of the Challenger Deep) with its depth, temperature and
// pressure; and the boat's crew for the shared lock level. XP is leagues
// logged.
Singleton {
    id: root

    readonly property string display: "Michroma"
    readonly property string ui: "B612"
    readonly property string mono: "B612 Mono"

    readonly property color glow: Services.DesktopTheme.accentOf("abyss")
    readonly property color lume: Services.DesktopTheme.accent2Of("abyss")
    readonly property color water: "#062a36"
    readonly property color abyss: "#02090e"
    readonly property color steel: "#15232a"
    readonly property color steelHi: "#4a6570"
    readonly property color glass: "#0b1d24"
    readonly property color foam: "#dcf5f2"
    readonly property color alarm: "#ff5145"
    readonly property color sodium: "#ffbb66"

    function alpha(c, x) {
        return Qt.rgba(c.r, c.g, c.b, x);
    }

    // 1240 -> "1,240"
    function count(n) {
        return Math.round(n).toLocaleString(Qt.locale("en_US"), "f", 0);
    }

    // ── The water column ────────────────────────────────────────────────────
    // The day as a dive: noon at periscope depth, sinking through the
    // evening to the bottom of the Challenger Deep at midnight and rising
    // again by morning. Metres.
    readonly property real deepest: 10994
    readonly property real periscope: 18

    function depthAt(d) {
        const h = d.getHours() + d.getMinutes() / 60;
        return periscope + (deepest - periscope) * Math.pow(Math.abs(h - 12) / 12, 4);
    }

    // How deep that looks, 0 (surface) .. 1 (the trenches): light fades
    // with the log of the depth.
    function shade(m) {
        return Math.log(1 + Math.max(0, m) / 50) / Math.log(1 + deepest / 50);
    }

    readonly property var zones: [
        { floor: 200, name: "Sunlight Zone", latin: "Epipelagic" },
        { floor: 1000, name: "Twilight Zone", latin: "Mesopelagic" },
        { floor: 4000, name: "Midnight Zone", latin: "Bathypelagic" },
        { floor: 6000, name: "The Abyss", latin: "Abyssopelagic" },
        { floor: 1e9, name: "The Trenches", latin: "Hadal" }
    ]

    function zoneAt(m) {
        for (let i = 0; i < zones.length; i++)
            if (m < zones[i].floor)
                return zones[i];
        return zones[zones.length - 1];
    }

    // Warm at the top, near freezing below the thermocline. °C.
    function temperature(m) {
        return 2 + 24 * Math.exp(-m / 260);
    }

    // Atmospheres: one of air, one more every ten metres of sea.
    function pressure(m) {
        return 1 + m / 10.06;
    }

    // 1240.4 -> "1,240 m"
    function metres(m) {
        return count(m) + " m";
    }

    // ── The crew, by lock level (thresholds as LockStats' ranks) ────────────
    readonly property var ranks: [
        [1, "Landlubber"], [3, "Deckhand"], [5, "Able Seaman"], [8, "Sonar Operator"],
        [12, "Helmsman"], [16, "Diving Officer"], [20, "Navigator"], [25, "Chief of the Boat"],
        [30, "Executive Officer"], [40, "Captain"], [50, "Admiral of the Deep"]
    ]

    function rank(level) {
        let name = ranks[0][1];
        for (let i = 0; i < ranks.length; i++)
            if (level >= ranks[i][0])
                name = ranks[i][1];
        return name;
    }
}
