pragma Singleton
import QtQuick
import Quickshell
import qs.colors
import qs.services as Services
import qs.modules.desktopwidgets

// How the control centre dresses under the desktop theme. It's made like the
// theme's desktop widgets (WidgetStyle): the same frame for its surface, the
// same type, wording, meters and art, the theme's toned accents. Its text is
// set in `ink`, and every control is a wash of that ink, so the same parts
// read on black lacquer, rusted scrap or a sheet of newsprint.
Singleton {
    id: root

    readonly property string themeId: Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""
    readonly property var st: WidgetStyle.of(themeId)
    readonly property string frame: st.frame
    readonly property bool paper: st.paper === true
    readonly property bool darkScheme: Qt.color(Colors.background).hslLightness < 0.5
    // Frames painted dark whatever the scheme (lacquer, stone, scrap,
    // enamel, sea glass, banner cloth, black lacquer).
    readonly property bool darkFrame: ["gilt", "lancet", "scrap", "brass", "instrument", "patta", "banner", "sumi"].includes(frame)

    readonly property color ink: paper ? "#1b1a17" : darkFrame && !darkScheme ? Colors.inverse_on_surface : Colors.on_surface
    readonly property color accent: WidgetStyle.accent(themeId)
    // The second accent; on newsprint (whose second is the paper's own ink)
    // the spot colour again.
    readonly property color accent2: paper ? accent : Services.DesktopTheme.accent2Of(themeId)
    readonly property color labelColor: paper ? ink : WidgetStyle.labelColor(themeId)
    readonly property color danger: paper ? "#a3241c" : Colors.error

    // Washes of ink for wells, hovers and rules.
    readonly property color well: Colors.withAlpha(ink, paper ? 0.07 : 0.06)
    readonly property color wellHover: Colors.withAlpha(ink, paper ? 0.12 : 0.1)
    readonly property color line: Colors.withAlpha(ink, paper ? 0.22 : 0.12)

    // Type: body text, labels and titles, big numerals, figures.
    readonly property string body: st.font || Qt.application.font.family
    readonly property string ui: st.ui ?? st.cjk ?? (frame === "chamfer" ? st.mono : body)
    readonly property string display: st.display || body
    readonly property string mono: st.mono
    readonly property int caps: WidgetStyle.caps(st)
    readonly property real labelSpacing: st.labelSpacing
    readonly property bool upper: st.labelCase === "upper"

    // How far the theme's art frame (WidgetArt) reaches past its box: a
    // ring, a porthole's bolts, a prabhavali's flames, tape at the corners.
    readonly property real artBleed: ({ circle: 6, medallion: 9, porthole: 9, prabha: 13, taped: 6, neon: 3, tsuba: 10 })[st.art] ?? 0

    function label(text) {
        return WidgetStyle.label(text, st);
    }

    function word(key) {
        return WidgetStyle.word(key, themeId).replace("%u", Quickshell.env("USER") || "you");
    }

    // A control's corner radius, given the plain design's: square on HUD,
    // console, neon, gilt, newsprint and lacquer, a little round on scroll, stone,
    // brass and lacquer, rounder on glass.
    function radius(normal) {
        switch (frame) {
        case "chamfer":
        case "console":
        case "neon":
        case "gilt":
        case "clipping":
        case "sumi":
            return 0;
        case "banner":
            return 1;
        case "scrap":
            return 2;
        case "scroll":
        case "lancet":
        case "brass":
            return Math.min(normal, 4);
        case "patta":
            return Math.min(normal, 5);
        case "glass":
            return Math.round(normal * 1.4);
        default:
            return normal;
        }
    }

    // One corner (clockwise from top left) of that radius: Wabi-sabi's are
    // pebbles, no two alike.
    function corner(normal, i) {
        const r = radius(normal);
        return frame === "washi" ? r * Services.DesktopTheme.pebbleCorners[i] : r;
    }

    // Text that reads on a fill of `c`.
    function inkOn(c) {
        const q = Qt.color(c);
        return 0.2126 * q.r + 0.7152 * q.g + 0.0722 * q.b > 0.55 ? Qt.color("#16130f") : Qt.color("#fbf8f3");
    }
}
