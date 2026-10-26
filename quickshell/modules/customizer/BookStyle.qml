pragma Singleton
import QtQuick
import Quickshell
import qs.colors
import qs.services as Services
import qs.modules.desktoptheme
import qs.modules.desktopwidgets

// How the customizer's book is bound under each desktop theme ("" = none):
// its title, the stock its pages are printed on, the ink, the type, the
// cover, how its pages are numbered and how a choice is marked on them.
// Everything on a page is drawn from these, so one set of pages reads on
// newsprint, vellum, black lacquer or a console.
//
//   paper:  "scheme" (the wallpaper's surfaces, light or dark as the scheme
//           is), "night" (a dark page whatever the scheme), or a colour
//           (a stock, tinted a breath towards the wallpaper)
//   mark:   how a chosen option is marked: ring (circled in ink), box
//           (bracketed), underline, brush (a stroke of the brush under it)
//   rule:   single | double | thick (thick over thin) | dashed | none
//   folio:  the page number's setting, %n where the numeral goes
//   lower:  lower-case numerals (i, ii, iii) rather than capitals
Singleton {
    id: root

    readonly property string themeId: Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""
    readonly property var st: WidgetStyle.of(themeId)
    readonly property bool darkScheme: Qt.color(Colors.background).hslLightness < 0.5

    readonly property var bindings: ({
        "": { title: "Customize", subtitle: "A handbook for your desktop", paper: "scheme", display: "Playfair Display", body: "EB Garamond", ui: "EB Garamond", mark: "ring", rule: "single", folio: "— %n —", lower: true, fleuron: "❦", radius: 6, grain: 0.45, fibres: 0.35, age: 0.12, cover: "scheme" },
        hud: { title: "INSTRUCTION MANUAL", subtitle: "Read this before you play", paper: "night", display: "Orbitron", body: "JetBrainsMono Nerd Font", ui: "JetBrainsMono Nerd Font", mark: "box", rule: "dashed", folio: "PAGE %n", lower: false, fleuron: "◆", radius: 0, grain: 0.18, fibres: 0, age: 0, pattern: "dots" },
        terminal: { title: "QUICKSHELL(7)", subtitle: "Quickshell Programmer's Manual", paper: "night", display: "Iosevka Nerd Font", body: "Iosevka Nerd Font", ui: "Iosevka Nerd Font", mark: "box", rule: "dashed", folio: "%n", lower: true, fleuron: "--", radius: 0, grain: 0.1, fibres: 0, age: 0, pattern: "scanlines" },
        cosmos: { title: "STAR ATLAS", subtitle: "Charts of your desktop", paper: "night", display: "ESPACION", body: "Adwaita Sans", ui: "Adwaita Sans", mark: "ring", rule: "single", folio: "✦ %n ✦", lower: false, fleuron: "✦", radius: 12, grain: 0.15, fibres: 0, age: 0, pattern: "stars" },
        zen: { title: "stillness", subtitle: "a small book of settings", paper: "scheme", display: "Adwaita Sans", body: "Adwaita Sans", ui: "Adwaita Sans", mark: "underline", rule: "none", folio: "%n", lower: true, fleuron: "·", radius: 4, grain: 0.12, fibres: 0.1, age: 0, light: true },
        xianxia: { title: "秘笈", subtitle: "The Secret Manual of the Cave Abode", paper: "#efe5cf", ink: "#2a221b", display: "Noto Serif", body: "Noto Serif", ui: "Noto Serif", cjk: "Ma Shan Zheng", mark: "ring", rule: "double", folio: "· %n ·", lower: true, fleuron: "❀", radius: 3, grain: 0.6, fibres: 0.8, age: 0.35, cover: "#3b2a22" },
        cyberpunk: { title: "BLACK ICE", subtitle: "// field manual · 現場マニュアル", paper: "night", display: "Fragile Bombers", numeral: "Rubik", body: "Rubik", ui: "Rubik", mark: "box", rule: "single", folio: "// %n", lower: false, fleuron: "//", radius: 0, grain: 0.2, fibres: 0, age: 0, pattern: "rain" },
        wabisabi: { title: "手引", subtitle: "tebiki · a guide, worn by use", paper: "#ece4d5", ink: "#2b2520", display: "Noto Serif CJK JP", body: "Noto Serif CJK JP", ui: "Noto Serif CJK JP", cjk: "Noto Serif CJK JP", mark: "brush", rule: "none", folio: "%n", lower: true, fleuron: "〇", radius: 4, grain: 0.7, fibres: 1.0, age: 0.25, light: true, cover: "#4a4038" },
        artdeco: { title: "THE GRAND DIRECTORY", subtitle: "of the Desktop Hotel · every floor", paper: "#f0e8d5", ink: "#1d1a16", display: "Poiret One", body: "Josefin Sans", ui: "Josefin Sans", mark: "box", rule: "double", folio: "— %n —", lower: false, fleuron: "◆", radius: 0, grain: 0.3, fibres: 0.2, age: 0.12, cover: "#16130f" },
        gothic: { title: "The Book of Hours", subtitle: "of the desktop, set down by hand", paper: "#ebdcbd", ink: "#241b12", display: "UnifrakturMaguntia", numeral: "Alegreya", body: "Alegreya", ui: "Alegreya", mark: "ring", rule: "double", folio: "· %n ·", lower: true, fleuron: "❧", radius: 0, grain: 0.6, fibres: 0.45, age: 0.55, dropCap: true, cover: "#2b1712" },
        newspaper: { title: "The Style Book", subtitle: "Rules of the house · printed for the desk", paper: "#ebe5d4", ink: "#1b1a17", display: "Playfair Display", body: "Old Standard TT", ui: "Old Standard TT", mark: "underline", rule: "thick", folio: "Page %n", lower: true, fleuron: "★", radius: 0, grain: 0.85, fibres: 0.3, age: 0.28, dropCap: true, cover: "#1f1d1a" },
        wasteland: { title: "SURVIVAL MANUAL", subtitle: "Field Manual FM 26 · keep this book dry", paper: "#d8c9a2", ink: "#1e1a14", display: "Stardos Stencil", body: "Special Elite", ui: "Barlow Condensed", mark: "box", rule: "dashed", folio: "FM 26 · %n", lower: false, fleuron: "▲", radius: 2, grain: 0.75, fibres: 0.3, age: 0.75, cover: "#3d3a2c" },
        observatory: { title: "The Almanack", subtitle: "of the desktop, calculated for this year of grace", paper: "#e8dec4", ink: "#221a11", display: "IM FELL English", body: "EB Garamond", ui: "IM FELL English SC", mark: "ring", rule: "double", folio: "%n", lower: true, fleuron: "☉", radius: 4, grain: 0.6, fibres: 0.5, age: 0.6, dropCap: true, cover: "#1f2a33" },
        abyss: { title: "SHIP'S MANUAL", subtitle: "Bathysphere · operating instructions", paper: "night", display: "Michroma", body: "B612", ui: "B612", mark: "box", rule: "single", folio: "— %n —", lower: false, fleuron: "◉", radius: 8, grain: 0.15, fibres: 0, age: 0, pattern: "sonar" },
        devaloka: { title: "शास्त्र", subtitle: "Shastra · the treatise of the desktop", paper: "#e6d2a3", ink: "#2a1b0f", display: "Eczar", body: "Tiro Devanagari Sanskrit", ui: "Eczar", mark: "ring", rule: "double", folio: "॥ %n ॥", lower: true, fleuron: "✿", radius: 6, grain: 0.5, fibres: 0.9, age: 0.4, cover: "#5a1d14" },
        siege: { title: "The Book of Arms", subtitle: "a chronicle kept at the keep", paper: "#e6d9b9", ink: "#1f1913", display: "Germania One", body: "Texturina", ui: "Texturina", mark: "ring", rule: "double", folio: "· %n ·", lower: false, fleuron: "✠", radius: 1, grain: 0.6, fibres: 0.4, age: 0.5, dropCap: true, cover: "#2a2522" },
        sekiro: { title: "忍びの書", subtitle: "The Shinobi's Book", paper: "night", ink: "#e8dfcc", display: "Zen Antique", body: "Zen Old Mincho", ui: "Zen Old Mincho", cjk: "Zen Antique", mark: "brush", rule: "gold", folio: "— %n —", lower: true, fleuron: "◆", radius: 0, grain: 0.3, fibres: 0.45, age: 0.15, cover: "#0d0b0b", gold: "#c9a35b" }
    })

    readonly property var b: root.bindings[root.themeId] ?? root.bindings[""]

    // ── Stock and ink ────────────────────────────────────────────────────────
    // A stock is tinted a breath towards the wallpaper so it belongs to it.
    readonly property bool lightPaper: root.b.paper === "scheme" ? !root.darkScheme : root.b.paper !== "night"
    readonly property color paper: {
        const p = root.b.paper;
        if (p === "scheme")
            return root.darkScheme ? Qt.tint(Colors.surface_container_low, Colors.withAlpha(Colors.primary, 0.03)) : Qt.tint(Colors.surface_container_lowest, Colors.withAlpha(Colors.primary, 0.04));
        if (p === "night")
            return root.themeId === "sekiro" ? Qt.tint("#151211", Colors.withAlpha(Services.DesktopTheme.accent, 0.04))
                : Qt.tint(Colors.surface_container_lowest, Colors.withAlpha(Colors.primary, 0.05));
        return Qt.tint(p, Colors.withAlpha(Colors.primary, 0.06));
    }
    // The gutter's shadow and an old page's darkened edges.
    readonly property color shade: root.lightPaper ? Qt.darker(root.paper, 2.4) : "#000000"
    readonly property color ink: root.b.ink ? root.b.ink : root.lightPaper && root.b.paper !== "scheme" ? "#1c1914" : Colors.on_surface
    readonly property color inkSoft: Colors.withAlpha(root.ink, 0.66)
    readonly property color inkFaint: Colors.withAlpha(root.ink, 0.42)
    readonly property color line: Colors.withAlpha(root.ink, root.lightPaper ? 0.26 : 0.2)
    readonly property color well: Colors.withAlpha(root.ink, root.lightPaper ? 0.06 : 0.055)
    readonly property color wellHover: Colors.withAlpha(root.ink, root.lightPaper ? 0.1 : 0.09)

    // The theme's accents, made to read on the stock: a gold that's ink on
    // black lacquer would vanish on cream, so it's taken darker there.
    readonly property color accent: root.readable(Services.DesktopTheme.accentOf(root.themeId), root.paper, 3.2)
    readonly property color accent2: root.readable(Services.DesktopTheme.accent2Of(root.themeId), root.paper, 3.0)
    // Gilt hairlines (Sekiro's gold), else the accent.
    readonly property color gold: root.b.gold ? root.readable(root.b.gold, root.paper, 2.6) : root.accent
    readonly property color onAccent: root.inkOn(root.accent)

    // ── Type ─────────────────────────────────────────────────────────────────
    readonly property string display: root.b.display || root.st.display || Qt.application.font.family
    readonly property string body: root.b.body || root.st.font || Qt.application.font.family
    readonly property string ui: root.b.ui || root.body
    readonly property string cjk: root.b.cjk || root.display
    // Roman numerals for chapters: the display face, unless it's a
    // blackletter or the like where I reads as J.
    readonly property string numeral: root.b.numeral || root.display
    readonly property int labelCaps: root.themeId === "newspaper" || root.themeId === "observatory" ? Font.SmallCaps
        : ["hud", "cyberpunk", "abyss", "wasteland", "artdeco"].includes(root.themeId) ? Font.AllUppercase : Font.MixedCase
    readonly property real labelSpacing: ["hud", "cyberpunk", "abyss", "artdeco", "wasteland"].includes(root.themeId) ? 1.4 : 0.3
    // Body type a size larger in faces that run small.
    readonly property int bodySize: ["Josefin Sans", "Special Elite", "IM FELL English", "Alegreya", "EB Garamond", "Texturina"].includes(root.body) ? 15 : 14

    // ── Cover ────────────────────────────────────────────────────────────────
    readonly property color cover: {
        const c = root.b.cover;
        if (!c || c === "scheme")
            return root.b.paper === "night" ? Qt.darker(Colors.surface_container_lowest, 1.25) : Colors.primary_container;
        return Qt.tint(c, Colors.withAlpha(Services.DesktopTheme.accentOf(root.themeId), 0.08));
    }
    readonly property color coverInk: root.b.cover === "scheme" || !root.b.cover && root.b.paper !== "night" ? Colors.on_primary_container
        : root.readable(root.themeId === "sekiro" ? root.b.gold : Services.DesktopTheme.accentOf(root.themeId), root.cover, 3.5)
    // The page block's edges: gilt on fine books, red on the shinobi's.
    readonly property color edge: ["artdeco", "gothic", "observatory", "devaloka"].includes(root.themeId) ? Services.DesktopTheme.accentOf(root.themeId)
        : root.themeId === "sekiro" ? "#8e1f1c" : Qt.darker(root.paper, root.lightPaper ? 1.12 : 0.8)
    readonly property color ribbon: root.themeId === "sekiro" || root.themeId === "gothic" || root.themeId === "siege" ? "#8f1d1d"
        : root.readable(Services.DesktopTheme.accentOf(root.themeId), root.paper, 2.2)

    // ── Numbering ────────────────────────────────────────────────────────────
    function roman(n) {
        const r = Clocks.roman(n);
        return root.b.lower ? r.toLowerCase() : r;
    }

    function folio(n) {
        return root.b.folio.replace("%n", root.roman(n));
    }

    // ── Colour helpers ───────────────────────────────────────────────────────
    function luminance(c) {
        const q = Qt.color(c);
        const lin = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        return 0.2126 * lin(q.r) + 0.7152 * lin(q.g) + 0.0722 * lin(q.b);
    }

    function contrast(a, b) {
        const la = root.luminance(a), lb = root.luminance(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }

    // `c`, darkened or lightened (hue and saturation kept) until it stands
    // out on `bg` by `ratio`.
    function readable(c, bg, ratio) {
        let q = Qt.color(c);
        const darken = root.luminance(bg) > 0.4;
        let l = q.hslLightness;
        for (let i = 0; i < 24 && root.contrast(q, bg) < ratio; i++) {
            l = darken ? Math.max(0, l - 0.04) : Math.min(1, l + 0.04);
            q = Qt.hsla(Math.max(0, q.hslHue), q.hslSaturation, l, 1);
        }
        return q;
    }

    // Text that reads on a fill of `c`.
    function inkOn(c) {
        return root.luminance(c) > 0.35 ? Qt.color("#16130f") : Qt.color("#fbf8f3");
    }
}
