pragma Singleton
import QtQuick
import Quickshell
import qs.modules.desktoptheme
import qs.services as Services

// Palette, type and the house style of the Broadsheet desktop theme and its
// "Extra! Extra!" lock screen: newsprint and ink, with the wallpaper's
// colour as the paper's one spot colour (services/DesktopTheme.qml accentOf,
// tone "print"); the paper's name, dateline, volume and number; which
// edition is on the street; and the newsroom's ladder for the shared lock
// level. XP is the paper's circulation.
Singleton {
    id: root

    readonly property string masthead: "Playfair Display"
    readonly property string headline: "Anton"
    readonly property string body: "Old Standard TT"

    readonly property color paper: "#ebe6d9"
    readonly property color paperDeep: "#d8d0bd"
    readonly property color ink: "#1b1a17"
    readonly property color inkSoft: "#57534a"
    readonly property color inkFaint: "#8d887b"
    // The spot colour for screens (accent) and printed on newsprint.
    readonly property color spot: Services.DesktopTheme.accentOf("newspaper")
    readonly property color spotInk: Qt.hsla(Math.max(0, spot.hslHue), 0.68, 0.4, 1)

    function alpha(c, x) {
        return Qt.rgba(c.r, c.g, c.b, x);
    }

    // "The Daily Igris"
    function paperName(user) {
        const u = user || "Desktop";
        return "The Daily " + u.charAt(0).toUpperCase() + u.slice(1);
    }

    // "SATURDAY, SEPTEMBER 27, 2026"
    function dateline(d) {
        return Qt.formatDate(d, "dddd, MMMM d, yyyy").toUpperCase();
    }

    // Founded with the epoch: one volume a year, one number a day.
    function volume(d) {
        return "VOL. " + Clocks.roman(d.getFullYear() - 1969);
    }

    function number(d) {
        const days = Math.floor((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - new Date(1970, 0, 1)) / 86400000) + 1;
        return "No. " + days.toLocaleString(Qt.locale("en_US"), "f", 0);
    }

    // Which edition is on the street.
    function edition(d) {
        const h = d.getHours();
        return h < 5 ? "LATE CITY FINAL" : h < 11 ? "MORNING EDITION" : h < 15 ? "NOON EDITION"
            : h < 19 ? "AFTERNOON EDITION" : h < 23 ? "EVENING EDITION" : "LATE CITY FINAL";
    }

    // The newsroom, by lock level (thresholds as LockStats' ranks).
    readonly property var careers: [
        [1, "Copy Runner"], [3, "Cub Reporter"], [5, "Stringer"], [8, "Staff Writer"],
        [12, "Correspondent"], [16, "Columnist"], [20, "Desk Editor"], [25, "Managing Editor"],
        [30, "Editor-in-Chief"], [40, "Publisher"], [50, "Press Baron"]
    ]

    function career(level) {
        let name = careers[0][1];
        for (let i = 0; i < careers.length; i++)
            if (level >= careers[i][0])
                name = careers[i][1];
        return name;
    }

    // 12480 -> "12,480"
    function count(n) {
        return Math.round(n).toLocaleString(Qt.locale("en_US"), "f", 0);
    }

    // "9:41 p.m.", the way the paper sets times.
    function time(d) {
        const h = d.getHours();
        return ((h + 11) % 12 + 1) + ":" + String(d.getMinutes()).padStart(2, "0") + (h < 12 ? " a.m." : " p.m.");
    }
}
