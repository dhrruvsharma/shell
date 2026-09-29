pragma Singleton
import QtQuick
import Quickshell
import qs.colors
import qs.services as Services

// How desktop widgets look under each desktop theme ("" = no theme). Widgets
// read a token set with `of(themeId)` and draw their frame, type, labels,
// meters and artwork from it; per-widget wording lives in `words`.
//   frame: card | chamfer | console | glass | bare | scroll | neon | washi |
//          gilt | lancet | clipping | scrap | brass | instrument
//   bar:   line | segments | ascii | orbit | hairline | brush | neon | ink |
//          deco | glass | rule | hazard | vernier | sonar
//   art:   rounded | chamfer | square | circle | soft | seal | neon | pebble |
//          deco | arch | halftone | taped | medallion | porthole
// Colour roles are Colors names, or "accent" / "accent2" for the theme's
// toned accents (services/DesktopTheme.qml roleColor); use accent(),
// labelColor() and ink() rather than reading them directly. `paper` frames
// (Broadsheet's clippings) are light whatever the scheme: their text is
// printer's ink ("ink" as a label role) and their accent is printed dark.
// labelCase is "upper", "lower", "small" (small capitals) or "none".
Singleton {
    readonly property var styles: ({
        "": { frame: "card", font: "", display: "", mono: "JetBrainsMono Nerd Font", weight: Font.Normal, labelCase: "none", labelSpacing: 0.4, labelRole: "on_surface_variant", accentRole: "primary", bar: "line", art: "rounded", pad: 18 },
        hud: { frame: "chamfer", font: "JetBrainsMono Nerd Font", display: "Orbitron", mono: "JetBrainsMono Nerd Font", weight: Font.Medium, labelCase: "upper", labelSpacing: 3.5, labelRole: "primary", accentRole: "primary", bar: "segments", art: "chamfer", pad: 18 },
        terminal: { frame: "console", font: "Iosevka Nerd Font", display: "Iosevka Nerd Font", mono: "Iosevka Nerd Font", weight: Font.Normal, labelCase: "lower", labelSpacing: 0.5, labelRole: "primary", accentRole: "primary", bar: "ascii", art: "square", pad: 16 },
        cosmos: { frame: "glass", font: "Adwaita Sans", display: "ESPACION", mono: "JetBrainsMono Nerd Font", weight: Font.Normal, labelCase: "upper", labelSpacing: 3, labelRole: "on_surface_variant", accentRole: "primary", bar: "orbit", art: "circle", pad: 20 },
        zen: { frame: "bare", font: "Adwaita Sans", display: "Adwaita Sans", mono: "Adwaita Sans", weight: Font.Light, labelCase: "lower", labelSpacing: 0.6, labelRole: "on_surface_variant", accentRole: "primary", bar: "hairline", art: "soft", pad: 8 },
        xianxia: { frame: "scroll", font: "Noto Serif", display: "Noto Serif", mono: "Noto Serif", cjk: "Noto Serif CJK SC", weight: Font.Normal, labelCase: "none", labelSpacing: 1, labelRole: "tertiary", accentRole: "tertiary", bar: "brush", art: "seal", pad: 18 },
        cyberpunk: { frame: "neon", font: "Rubik", display: "KogniGear", mono: "JetBrainsMono Nerd Font", ui: "Fragile Bombers", weight: Font.Normal, labelCase: "upper", labelSpacing: 2.5, labelRole: "accent2", accentRole: "accent", bar: "neon", art: "neon", pad: 18 },
        wabisabi: { frame: "washi", font: "Noto Serif CJK JP", display: "Noto Serif CJK JP", mono: "Noto Serif CJK JP", cjk: "Noto Serif CJK JP", weight: Font.Light, labelCase: "lower", labelSpacing: 0.8, labelRole: "accent", accentRole: "accent", bar: "ink", art: "pebble", pad: 20 },
        artdeco: { frame: "gilt", font: "Josefin Sans", display: "Poiret One", mono: "Josefin Sans", weight: Font.Normal, labelCase: "upper", labelSpacing: 3, labelRole: "accent", accentRole: "accent", bar: "deco", art: "deco", pad: 22 },
        gothic: { frame: "lancet", font: "Alegreya", display: "UnifrakturMaguntia", mono: "Alegreya", ui: "Grenze Gotisch", weight: Font.Normal, labelCase: "none", labelSpacing: 0.4, labelRole: "accent", accentRole: "accent", bar: "glass", art: "arch", pad: 20 },
        newspaper: { frame: "clipping", font: "Old Standard TT", display: "Playfair Display", mono: "Old Standard TT", weight: Font.Normal, labelCase: "small", labelSpacing: 1, labelRole: "ink", accentRole: "accent", bar: "rule", art: "halftone", pad: 18, paper: true },
        wasteland: { frame: "scrap", font: "Barlow Semi Condensed", display: "Stardos Stencil", mono: "Barlow Condensed", ui: "Big Shoulders Stencil", weight: Font.Medium, labelCase: "upper", labelSpacing: 1.5, labelRole: "accent2", accentRole: "accent2", bar: "hazard", art: "taped", pad: 22 },
        observatory: { frame: "brass", font: "EB Garamond", display: "IM FELL English", mono: "EB Garamond", ui: "IM FELL English SC", weight: Font.Normal, labelCase: "none", labelSpacing: 1.2, labelRole: "accent", accentRole: "accent", bar: "vernier", art: "medallion", pad: 22 },
        abyss: { frame: "instrument", font: "B612", display: "Michroma", mono: "B612 Mono", ui: "B612", weight: Font.Normal, labelCase: "upper", labelSpacing: 2.2, labelRole: "accent2", accentRole: "accent", bar: "sonar", art: "porthole", pad: 20 }
    })

    function of(themeId) {
        return styles[themeId] ?? styles[""];
    }

    // The colour a theme's widgets are accented in, and their labels'.
    function accent(themeId) {
        const st = of(themeId);
        const a = Services.DesktopTheme.roleColor(st.accentRole, themeId);
        return st.paper ? Qt.hsla(Math.max(0, a.hslHue), 0.68, 0.4, 1) : a;
    }

    function labelColor(themeId) {
        const st = of(themeId);
        return st.labelRole === "ink" ? ink(themeId) : Services.DesktopTheme.roleColor(st.labelRole, themeId);
    }

    // The colour text is set in on a theme's widgets.
    function ink(themeId) {
        return of(themeId).paper ? Qt.color("#1b1a17") : Qt.color(Colors.on_surface);
    }

    // The capitalization labels are set in.
    function caps(style) {
        return style.labelCase === "small" ? Font.SmallCaps : Font.MixedCase;
    }

    // Per theme wording: words[widget][theme] (falls back to "").
    readonly property var words: ({
        music: { "": "Now playing", hud: "Now playing", terminal: "~/music $ playerctl status", cosmos: "Transmission", zen: "listening", xianxia: "琴音 · Qin melody", cyberpunk: "Now playing // 再生中", wabisabi: "音 · sound", artdeco: "On the gramophone", gothic: "The choir sings", newspaper: "Topping the charts", wasteland: "Salvaged radio", observatory: "Music of the spheres", abyss: "Hydrophone" },
        musicIdle: { "": "Nothing playing", hud: "No signal", terminal: "no players found", cosmos: "Silence between stars", zen: "quiet", xianxia: "琴弦静 · The strings are still", cyberpunk: "Dead air", wabisabi: "静寂 · stillness", artdeco: "The band is taking five", gothic: "The choir is silent", newspaper: "No music news today", wasteland: "Static on every frequency", observatory: "The spheres are silent", abyss: "Only whale song" },
        sysmon: { "": "System", hud: "System status", terminal: "~ $ top -b -n1", cosmos: "Ship systems", zen: "", xianxia: "气海 · Sea of Qi", cyberpunk: "Cyberdeck // 電脳", wabisabi: "炉 · the hearth", artdeco: "The engine room", gothic: "The workings", newspaper: "Market report", wasteland: "Rig status", observatory: "The orrery", abyss: "Boat systems" },
        quote: { "": "Dad joke", hud: "Side quest", terminal: "~ $ fortune", cosmos: "Incoming signal", zen: "a thought", xianxia: "箴言 · Proverb", cyberpunk: "Street talk // 噂", wabisabi: "言の葉 · words", artdeco: "Overheard at the speakeasy", gothic: "From the scriptorium", newspaper: "Funny pages", wasteland: "Scrawled on the wall", observatory: "From the almanac", abyss: "Overheard in the mess" },
        cpu: { "": "CPU", hud: "CPU", terminal: "cpu", cosmos: "Reactor", zen: "mind", xianxia: "灵力 Spirit", cyberpunk: "Neural core", wabisabi: "火 fire", artdeco: "Dynamo", gothic: "The great wheel", newspaper: "Processor index", wasteland: "Engine", observatory: "Clockwork", abyss: "Propulsion" },
        ram: { "": "Memory", hud: "MEM", terminal: "mem", cosmos: "Memory core", zen: "memory", xianxia: "神识 Sense", cyberpunk: "RAM", wabisabi: "水 water", artdeco: "Ledger", gothic: "The library", newspaper: "Memory futures", wasteland: "Supplies", observatory: "Tables", abyss: "Ballast" },
        temp: { "": "Temperature", hud: "TEMP", terminal: "tmp", cosmos: "Hull temp", zen: "warmth", xianxia: "丹火 Pill fire", cyberpunk: "Heat", wabisabi: "湯 heat", artdeco: "Boiler", gothic: "The forge", newspaper: "Weather", wasteland: "Heat", observatory: "The lamp", abyss: "Coolant" },
        disk: { "": "Disk", hud: "DISK", terminal: "dsk", cosmos: "Cargo", zen: "space", xianxia: "储物 Storage", cyberpunk: "Shards", wabisabi: "蔵 storehouse", artdeco: "Vault", gothic: "The crypt", newspaper: "Archives", wasteland: "Stash", observatory: "Star catalogue", abyss: "Hold" },
        uptime: { "": "Up", hud: "UPTIME", terminal: "up", cosmos: "Mission time", zen: "awake", xianxia: "闭关 Seclusion", cyberpunk: "Jacked in", wabisabi: "時 hours", artdeco: "Open since", gothic: "Vigil", newspaper: "In print", wasteland: "Survived", observatory: "Observing", abyss: "Submerged" }
    })

    function word(key, themeId) {
        const w = words[key];
        return w ? (w[themeId] ?? w[""]) : "";
    }

    function label(text, style) {
        return style.labelCase === "upper" ? text.toUpperCase() : style.labelCase === "lower" ? text.toLowerCase() : text;
    }
}
