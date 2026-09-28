pragma Singleton
import QtQuick
import Quickshell
import qs.services as Services

// Palette, type and building lore for the Art Deco desktop theme and its
// "Express Elevator" lock screen: gold leaf on black lacquer, with the
// wallpaper's colour set beside it as a jewel (services/DesktopTheme.qml
// accentOf/accent2Of, tone "gilt"); the floors of a 1920s skyscraper for the
// shared lock level; and the hours of a grand hotel's day.
Singleton {
    id: root

    // Thin, glamorous capitals and numerals; signage; everything else.
    readonly property string display: "Poiret One"
    readonly property string marquee: "Limelight"
    readonly property string ui: "Josefin Sans"

    readonly property color gold: Services.DesktopTheme.accentOf("artdeco")
    readonly property color goldHi: Qt.lighter(gold, 1.3)
    readonly property color goldDeep: Qt.darker(gold, 1.6)
    readonly property color jewel: Services.DesktopTheme.accent2Of("artdeco")
    readonly property color lacquer: "#0d0b08"
    readonly property color lacquerHi: "#1d1913"
    readonly property color ivory: "#efe6cf"
    readonly property color ruby: "#c0473f"

    function alpha(c, x) {
        return Qt.rgba(c.r, c.g, c.b, x);
    }

    // The building, floor by floor: the lock level is the floor you've
    // risen to (thresholds as LockStats' ranks).
    readonly property var floors: [
        [1, "LOBBY"], [3, "MEZZANINE"], [5, "GRAND BALLROOM"], [8, "SUPPER CLUB"],
        [12, "EXECUTIVE SUITES"], [16, "BOARDROOM"], [20, "SKY LOUNGE"], [25, "PENTHOUSE"],
        [30, "OBSERVATION DECK"], [40, "THE SPIRE"], [50, "THE MOORING MAST"]
    ]

    function floorName(level) {
        let name = floors[0][1];
        for (let i = 0; i < floors.length; i++)
            if (level >= floors[i][0])
                name = floors[i][1];
        return name;
    }

    // A grand hotel's day.
    function hour(d) {
        const h = d.getHours();
        return h < 6 ? "AFTER HOURS" : h < 10 ? "MORNING RUSH" : h < 12 ? "COFFEE SERVICE"
            : h < 15 ? "LUNCHEON" : h < 17 ? "TEA DANCE" : h < 19 ? "COCKTAIL HOUR"
            : h < 23 ? "DINNER & DANCING" : "AFTER HOURS";
    }

    // "SATURDAY · 27 SEPTEMBER · 2026"
    function date(d) {
        return Qt.formatDate(d, "dddd  ·  d MMMM  ·  yyyy").toUpperCase();
    }
}
