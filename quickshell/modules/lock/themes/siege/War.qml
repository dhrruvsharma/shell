pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.desktoptheme
import qs.modules.lock.themes.gothic
import qs.services as Services

// Palette, type and lore for the Siege desktop theme and its "Portcullis"
// lock screen: the wallpaper's colour as a heraldic tincture beside
// burnished steel (services/DesktopTheme.qml accentOf/accent2Of, tone
// "heraldic"), iron, oak, stone and firelight; your coat of arms, drawn
// from your name and blazoned as a herald would; the watches of a day under
// siege, the campaigning season and the Truce of God; the knights who
// answer the muster (the lock's passcode, a shield a keystroke); and the
// ranks of a feudal host for the shared lock level. XP is renown.
Singleton {
    id: root

    readonly property string display: "Germania One"
    readonly property string book: "Texturina"

    // The tincture (the wallpaper's colour) as the theme's accent, and as
    // paint on a shield; burnished steel; the other metal, Or.
    readonly property var tinctureInfo: Services.Heraldry.tincture
    readonly property string tinctureName: tinctureInfo.name
    readonly property color tincture: Services.DesktopTheme.accentOf("siege")
    readonly property color tinctureLight: Qt.hsla(tinctureInfo.h, tinctureInfo.sat, 0.74, 1)
    readonly property color field: Qt.hsla(tinctureInfo.h, Math.min(0.78, tinctureInfo.sat + 0.06), 0.4, 1)
    readonly property color fieldDeep: Qt.hsla(tinctureInfo.h, tinctureInfo.sat * 0.8, 0.13, 1)
    readonly property color steel: Services.DesktopTheme.accent2Of("siege")
    readonly property color argent: "#e4e6e6"
    readonly property color or: "#e3b24a"
    readonly property color orDeep: "#8a6420"
    readonly property color sable: "#1c1b1d"
    readonly property color iron: "#2c2b2d"
    readonly property color ironHi: "#8d8f93"
    readonly property color oak: "#3b2718"
    // Dark oak, nearly black: the ground of the plaques and boards.
    readonly property color ground: "#140e0a"
    readonly property color stone: "#6b665e"
    readonly property color parchment: "#eadfc4"
    readonly property color ink: "#2a1f16"
    readonly property color ivory: "#efe6d2"
    readonly property color wax: "#a3241d"
    readonly property color ember: "#ff8a2e"
    readonly property color fire: "#ffc86e"
    readonly property color moon: "#9fb3cf"
    readonly property color danger: "#ff6b50"

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

    // ── Whose castle ────────────────────────────────────────────────────
    readonly property string userName: Services.Heraldry.userName
    property string host: ""
    // The keep under siege: the machine's name, or yours.
    readonly property string hold: cap(host || userName)

    FileView {
        path: "/etc/hostname"
        printErrors: false
        onLoaded: root.host = text().trim().split(".")[0]
    }

    // ── Your arms (services/Heraldry.qml) ───────────────────────────────
    readonly property var arms: Services.Heraldry.arms

    // ── The day under siege ─────────────────────────────────────────────
    // Eight watches of three hours, from midnight.
    readonly property var watches: [
        { name: "The middle watch", deed: "sentries walk the walls" },
        { name: "The dawn watch", deed: "the garrison stands to before first light" },
        { name: "The muster", deed: "the host is called to arms" },
        { name: "The advance", deed: "banners forward" },
        { name: "The assault", deed: "ladders against the walls" },
        { name: "The rally", deed: "the knights rally to the standard" },
        { name: "The campfires", deed: "the wounded are tended" },
        { name: "The first watch", deed: "beacons burn on the towers" }
    ]

    function watch(d) {
        return watches[Math.floor(d.getHours() / 3)];
    }

    // The siege began at New Year: today is its day of the year.
    function siegeDay(d) {
        return Clocks.dayOfYear(d);
    }

    // Wars were fought between the spring muster and the harvest; the
    // armies sat out the winter.
    function season(d) {
        const m = d.getMonth();
        if (m >= 10 || m <= 1)
            return { name: "Winter quarters", deed: "the armies sit out the winter" };
        if (m <= 3)
            return { name: "The spring muster", deed: "vassals are called up for their forty days" };
        if (m <= 7)
            return { name: "The campaigning season", deed: "the roads are dry and the war is on" };
        return { name: "The harvest", deed: "the levies go home to bring it in" };
    }

    // The Truce of God (Treuga Dei): no fighting from Wednesday's sunset to
    // Monday's sunrise, nor through Advent and Christmastide or Lent and
    // Holy Week (Gothic's church year).
    function truce(d) {
        const s = Gothic.season(d).en;
        if (s === "Advent" || s === "Christmastide" || s === "Lent" || s === "Holy Week")
            return true;
        const day = d.getDay();
        const h = d.getHours();
        return (day === 3 && h >= 18) || day === 4 || day === 5 || day === 6 || day === 0 || (day === 1 && h < 6);
    }

    function truceLine(d) {
        return truce(d) ? "The Truce of God holds" : "A day of war";
    }

    // "Tuesday, the 29th of September"; "Anno Domini MMXXVI"
    function date(d) {
        return Qt.formatDate(d, "dddd") + ", the " + Clocks.ordinal(d.getDate()) + " of " + Qt.formatDate(d, "MMMM");
    }

    function year(d) {
        return "Anno Domini " + Clocks.roman(d.getFullYear());
    }

    // ── The muster ──────────────────────────────────────────────────────
    // The knights who answer it, one a keystroke of the passcode, each
    // with a shield in the manner of the romances: [name, field, ordinary,
    // its tincture] (Gawain's pentangle as a mullet).
    readonly property var paints: ({
        gules: "#b3261e", azure: "#26489a", vert: "#2e7a3e", purpure: "#6b3a86", sable: "#1d1b1c",
        "tenné": "#b5622a", or: "#e3b24a", argent: "#e4e6e6"
    })
    readonly property var knights: [
        ["Sir Gawain", "gules", 0, "or"], ["Sir Galahad", "argent", 5, "gules"], ["Sir Lancelot", "argent", 2, "gules"],
        ["Sir Percival", "purpure", 5, "or"], ["Sir Tristan", "vert", 3, "or"], ["Sir Kay", "azure", 4, "argent"],
        ["Sir Bedivere", "azure", 1, "or"], ["Sir Gareth", "sable", 6, "argent"], ["Sir Bors", "gules", 7, "argent"],
        ["Sir Lamorak", "tenné", 3, "argent"], ["Sir Gaheris", "or", 1, "azure"], ["Sir Ywain", "or", 2, "sable"]
    ]

    // ── The host, by lock level (thresholds as LockStats' ranks) ────────
    readonly property var ranks: [
        [1, "Levy"], [3, "Bowman"], [5, "Man-at-arms"], [8, "Serjeant"], [12, "Squire"], [16, "Knight"],
        [20, "Knight banneret"], [25, "Castellan"], [30, "Marshal"], [40, "Constable"], [50, "Warlord"]
    ]

    function rank(level) {
        let name = ranks[0][1];
        for (let i = 0; i < ranks.length; i++)
            if (level >= ranks[i][0])
                name = ranks[i][1];
        return name;
    }
}
