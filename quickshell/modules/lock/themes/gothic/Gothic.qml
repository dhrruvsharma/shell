pragma Singleton
import QtQuick
import Quickshell
import qs.modules.desktoptheme
import qs.services as Services

// Palette, type and the old reckoning of time for the Cathedral desktop
// theme and its "Rose Window" lock screen: the wallpaper's colours as
// stained glass (services/DesktopTheme.qml accentOf/accent2Of, tone
// "jewel") with gold and a counter-pane beside them, lead and stone; the
// canonical hours the bells rang; the seasons of the church year (reckoned
// from Easter); dates Anno Domini; and the ranks of the masons' lodge that
// built the place, for the shared lock level.
Singleton {
    id: root

    readonly property string blackletter: "UnifrakturMaguntia"
    readonly property string gotisch: "Grenze Gotisch"
    readonly property string caps: "Cinzel"
    readonly property string book: "Alegreya"

    // The glass: two panes from the wallpaper, gold, and a counter-pane
    // across the wheel from the first.
    readonly property color glassA: Services.DesktopTheme.accentOf("gothic")
    readonly property color glassB: Services.DesktopTheme.accent2Of("gothic")
    readonly property color glassC: "#e0a83e"
    readonly property color glassD: Qt.hsla((Math.max(0, glassA.hslHue) + 0.5) % 1, 0.7, 0.46, 1)
    readonly property color lead: "#121110"
    readonly property color stone: "#948c7d"
    readonly property color stoneDark: "#29251f"
    readonly property color candle: "#ffc56a"
    readonly property color parchment: "#ece1c6"
    readonly property color ink: "#2a2017"

    function alpha(c, x) {
        return Qt.rgba(c.r, c.g, c.b, x);
    }

    // The canonical hours, as the bells rang them, three hours apiece.
    readonly property var hours: [
        { en: "Matins", la: "Matutinum", gloss: "the night office" },
        { en: "Lauds", la: "Laudes", gloss: "praise at dawn" },
        { en: "Prime", la: "Prima", gloss: "the first hour" },
        { en: "Terce", la: "Tertia", gloss: "the third hour" },
        { en: "Sext", la: "Sexta", gloss: "the sixth hour" },
        { en: "None", la: "Nona", gloss: "the ninth hour" },
        { en: "Vespers", la: "Vesperae", gloss: "the evening office" },
        { en: "Compline", la: "Completorium", gloss: "the close of day" }
    ]

    function canonicalHour(d) {
        return hours[Math.floor(d.getHours() / 3)];
    }

    // Easter Sunday (Gregorian, the anonymous algorithm).
    function easter(y) {
        const a = y % 19, b = Math.floor(y / 100), c = y % 100;
        const d = Math.floor(b / 4), e = b % 4, f = Math.floor((b + 8) / 25);
        const g = Math.floor((b - f + 1) / 3), h = (19 * a + b - d - g + 15) % 30;
        const i = Math.floor(c / 4), k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7;
        const m = Math.floor((a + 11 * h + 22 * l) / 451);
        const month = Math.floor((h + l - 7 * m + 114) / 31);
        const day = ((h + l - 7 * m + 114) % 31) + 1;
        return new Date(y, month - 1, day);
    }

    // First Sunday of Advent: the fourth Sunday before Christmas.
    function advent(y) {
        const xmas = new Date(y, 11, 25);
        return new Date(y, 11, 25 - (xmas.getDay() === 0 ? 7 : xmas.getDay()) - 21);
    }

    // The season of the church year.
    function season(now) {
        const d = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const y = d.getFullYear();
        const e = easter(y);
        const day = 86400000;
        const ash = new Date(e.getTime() - 46 * day);
        const palm = new Date(e.getTime() - 7 * day);
        const pentecost = new Date(e.getTime() + 49 * day);
        if (d >= advent(y) && d < new Date(y, 11, 25))
            return { en: "Advent", la: "Tempus Adventus" };
        if (d >= new Date(y, 11, 25) || d < new Date(y, 0, 6))
            return { en: "Christmastide", la: "Tempus Nativitatis" };
        if (d >= ash && d < palm)
            return { en: "Lent", la: "Tempus Quadragesimae" };
        if (d >= palm && d < e)
            return { en: "Holy Week", la: "Hebdomada Sancta" };
        if (d >= e && d <= pentecost)
            return { en: "Eastertide", la: "Tempus Paschale" };
        return { en: "Ordinary Time", la: "Tempus per annum" };
    }

    // "Saturday, the 27th of September"
    function date(d) {
        return Qt.formatDate(d, "dddd") + ", the " + Clocks.ordinal(d.getDate()) + " of " + Qt.formatDate(d, "MMMM");
    }

    // "Anno Domini MMXXVI"
    function year(d) {
        return "Anno Domini " + Clocks.roman(d.getFullYear());
    }

    // The masons' lodge, by lock level (thresholds as LockStats' ranks).
    readonly property var ranks: [
        [1, "Quarryman"], [3, "Apprentice"], [5, "Rough Mason"], [8, "Journeyman"],
        [12, "Setter"], [16, "Carver"], [20, "Master Mason"], [25, "Master Carver"],
        [30, "Warden of the Lodge"], [40, "Master of the Works"], [50, "Master Builder"]
    ]

    function rank(level) {
        let name = ranks[0][1];
        for (let i = 0; i < ranks.length; i++)
            if (level >= ranks[i][0])
                name = ranks[i][1];
        return name;
    }
}
