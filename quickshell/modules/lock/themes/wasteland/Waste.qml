pragma Singleton
import QtQuick
import Quickshell
import qs.services as Services

// Palette, type and survival lore for the Wasteland desktop theme and its
// "Blast Door" lock screen: the wallpaper's colour as weathered paint and
// hazard amber (services/DesktopTheme.qml accentOf/accent2Of, tone
// "dusty"), steel, rust, dust and masking tape; the watches of a survivor's
// day; and the road from straggler to legend for the shared lock level. XP
// is scrap.
Singleton {
    id: root

    readonly property string stencil: "Stardos Stencil"
    readonly property string stencilCond: "Big Shoulders Stencil"
    readonly property string ui: "Barlow Semi Condensed"
    readonly property string cond: "Barlow Condensed"
    readonly property string type: "Special Elite"

    readonly property color paint: Services.DesktopTheme.accentOf("wasteland")
    readonly property color hazard: Services.DesktopTheme.accent2Of("wasteland")
    readonly property color rust: "#8d4b29"
    readonly property color rustDeep: "#4a2514"
    readonly property color steel: "#393733"
    readonly property color steelHi: "#6c685f"
    readonly property color grime: "#16120e"
    readonly property color dust: "#c8a676"
    readonly property color bone: "#e7dbc2"
    readonly property color tape: "#d6c6a0"
    readonly property color tapeInk: "#2a241c"
    readonly property color danger: "#d4462d"
    readonly property color safe: "#86a95e"

    function alpha(c, x) {
        return Qt.rgba(c.r, c.g, c.b, x);
    }

    // The watches of a survivor's day.
    function watch(d) {
        const h = d.getHours();
        return h < 5 ? "NIGHT WATCH" : h < 8 ? "DAWN PATROL" : h < 12 ? "SCAVENGING HOURS"
            : h < 16 ? "HIGH SUN · STAY IN THE SHADE" : h < 19 ? "DUST HOUR"
            : h < 22 ? "DUSK · BAR THE DOORS" : "NIGHT WATCH";
    }

    // The road, by lock level (thresholds as LockStats' ranks).
    readonly property var ranks: [
        [1, "STRAGGLER"], [3, "SCAVENGER"], [5, "DRIFTER"], [8, "SURVIVOR"],
        [12, "TINKERER"], [16, "TRACKER"], [20, "ROAD WARDEN"], [25, "RANGER"],
        [30, "WARLORD"], [40, "WASTELAND LEGEND"], [50, "THE LAST ONE STANDING"]
    ]

    function rank(level) {
        let name = ranks[0][1];
        for (let i = 0; i < ranks.length; i++)
            if (level >= ranks[i][0])
                name = ranks[i][1];
        return name;
    }

    // 1240 -> "1,240"
    function count(n) {
        return Math.round(n).toLocaleString(Qt.locale("en_US"), "f", 0);
    }
}
