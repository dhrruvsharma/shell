pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs.colors

// Desktop themes: one coordinated look across the rice, still coloured by
// the wallpaper. A theme touches three layers:
//   - Hyprland: corner rounding, a glow on the focused window, optional
//     window borders, and an optional static screen shader
//     (shaders/<id>_screen.frag.in, baked with the current colours). Applied
//     at runtime with `hyprctl eval`; switching themes or turning them off
//     runs `hyprctl reload` first, which restores the config exactly.
//   - the desktop: a static layer drawn over the wallpaper
//     (modules/desktoptheme, one <Name>Layer.qml per theme); desktop widgets
//     restyle themselves too (modules/desktopwidgets/WidgetStyle)
//   - shell UI: bar primitives take their shape and type from `look`.
// Nothing here animates continuously, so an idle desktop costs nothing extra.
//
// Only the main shell sets `manage`; other instances (the lock screen) just
// read the choice, e.g. `lockTheme` to match the lock to the desktop.
Singleton {
    id: root

    // hypr: rounding, shadow range/render_power, `glow` (a colour role with a
    //       hex alpha) or a fixed `shadow` colour, inactive shadow colour, an
    //       optional dim for unfocused windows, optional hard-edged (`sharp`)
    //       and `offset` [x, y] shadows, and optional window borders
    //       (`border`: active roles as a gradient, inactive role + hex alpha).
    // bar:  shape (round | chamfer | square | pill | soft | seal | neon |
    //       pebble | deco | cusp | print | plate | scale | lume | zari |
    //       crenel), font,
    //       weight, size delta, letter spacing, `caps` (true: capitals,
    //       "small": small capitals), hairline border; `uiFont` sets panel
    //       text when the bar font is too decorative for it.
    // tone: how the theme colours the wallpaper's accents (see accentOf):
    //       "" as they are, "neon", "muted", "gilt", "jewel", "print",
    //       "dusty", "brass", "lume", "temple" or "heraldic".
    // A colour role is a Colors name, or "accent" / "accent2" for the
    // theme's toned accents.
    readonly property var themes: [
        {
            id: "hud",
            name: "HUD",
            tagline: "Arcade HUD desktop",
            icon: "sports_esports",
            lockTheme: "arcade",
            description: "Your desktop as a game HUD: sharp windows with an accent glow on the focused one, a chamfered HUD bar, a dot grid and corner brackets over the wallpaper, a stage clock and your player level.",
            hypr: { rounding: 0, range: 22, power: 2, glow: "primary", glowAlpha: "70", inactive: "00000066" },
            bar: { shape: "chamfer", font: "JetBrainsMono Nerd Font", weight: Font.DemiBold, sizeDelta: -2, letterSpacing: 0, border: 0 },
            effects: {
                subtle: "A soft vignette, accent light at the screen edges and a hint of accent in the shadows.",
                strong: "A stronger grade plus faint CRT scanlines over everything."
            },
            changes: [
                { icon: "crop_square", text: "Sharp window corners; the focused window glows in your accent" },
                { icon: "view_agenda", text: "HUD bar: chamfered tags, mono type, diamond workspace pips" },
                { icon: "grid_4x4", text: "Dot grid, corner brackets and a player readout over the wallpaper" },
                { icon: "timer", text: "Stage clock with a day-progress meter" }
            ]
        },
        {
            id: "terminal",
            name: "Mainframe",
            tagline: "Phosphor terminal desktop",
            icon: "terminal",
            lockTheme: "terminal",
            description: "A mainframe console in your accent colour: square windows with a faint phosphor halo, a boxed monospace bar, scanlines and a console frame over the wallpaper, and a shell-prompt clock.",
            hypr: { rounding: 0, range: 12, power: 3, glow: "primary", glowAlpha: "48", inactive: "00000000" },
            bar: { shape: "square", font: "Iosevka Nerd Font", weight: Font.Medium, sizeDelta: -1, letterSpacing: 0.3, border: 1, borderRole: "primary", borderAlpha: 0.45 },
            effects: {
                subtle: "Fine scanlines and a phosphor tint in the shadows.",
                strong: "Heavier scanlines, phosphor tint across the picture and a darker tube vignette."
            },
            changes: [
                { icon: "crop_square", text: "Square windows with a faint phosphor halo on the focused one" },
                { icon: "check_box_outline_blank", text: "Boxed monospace bar tags, square workspace pips" },
                { icon: "tv", text: "Scanlines and a console frame over the wallpaper" },
                { icon: "schedule", text: "Shell-prompt clock" }
            ]
        },
        {
            id: "cosmos",
            name: "Astral",
            tagline: "Deep-space desktop",
            icon: "rocket_launch",
            lockTheme: "cosmos",
            description: "Space over your wallpaper: a still starfield and nebula in your colours, rounded windows with a soft nebula glow, hairline pills on the bar, and an orbital clock.",
            hypr: { rounding: 18, range: 30, power: 3, glow: "primary", glowAlpha: "50", inactive: "00000059" },
            bar: { shape: "pill", font: "Adwaita Sans", weight: Font.Medium, sizeDelta: -1, letterSpacing: 0.6, border: 1, borderRole: "primary", borderAlpha: 0.3 },
            effects: {
                subtle: "A deep vignette and nebula-tinted shadows.",
                strong: "A stronger vignette, richer colour and deep-space shadows."
            },
            changes: [
                { icon: "rounded_corner", text: "Rounded windows; the focused one has a soft nebula glow" },
                { icon: "radio_button_unchecked", text: "Hairline pill tags with airy type on the bar" },
                { icon: "auto_awesome", text: "A still starfield and nebula over the wallpaper" },
                { icon: "track_changes", text: "Orbital clock: the minutes trace an orbit" }
            ]
        },
        {
            id: "zen",
            name: "Still",
            tagline: "Quiet, minimal desktop",
            icon: "spa",
            lockTheme: "zen",
            description: "Calm and uncluttered: soft corners, gentle shadows and slightly dimmed background windows, light type in the bar, and a large, quiet clock.",
            hypr: { rounding: 14, range: 34, power: 4, shadow: "0000003a", inactive: "0000002e", dim: 0.08 },
            bar: { shape: "soft", font: "Adwaita Sans", weight: Font.Light, sizeDelta: 0, letterSpacing: 0.3, border: 0 },
            effects: {
                subtle: "Slightly softened colour with a fine film grain.",
                strong: "A muted, filmic grade with warmer highlights and more grain."
            },
            changes: [
                { icon: "rounded_corner", text: "Soft corners and gentle shadows; background windows dim a little" },
                { icon: "text_fields", text: "Light type in the bar" },
                { icon: "blur_on", text: "A faint vignette over the wallpaper, nothing else" },
                { icon: "schedule", text: "A large, quiet clock" }
            ]
        },
        {
            id: "xianxia",
            name: "Cave Abode",
            tagline: "Ink-wash cultivation desktop",
            icon: "landscape",
            lockTheme: "xianxia",
            description: "A cultivator's cave abode: mist and ink gathering over the wallpaper, seal-cut serif tags on the bar, windows lit by a spirit glow, and a hanging-scroll clock that tells the double-hour (shichen) and your cultivation realm.",
            hypr: { rounding: 4, range: 26, power: 3, glow: "tertiary", glowAlpha: "60", inactive: "00000055" },
            bar: { shape: "seal", font: "Noto Serif", weight: Font.Medium, sizeDelta: -1, letterSpacing: 0.4, border: 1, borderRole: "tertiary", borderAlpha: 0.5 },
            effects: {
                subtle: "A light ink-and-paper tone with a darker ink vignette.",
                strong: "A strong ink-wash grade: faded colour, paper grain and heavy ink edges."
            },
            changes: [
                { icon: "crop_square", text: "Nearly square windows lit by a spirit glow" },
                { icon: "approval", text: "Seal-cut tags with serif type on the bar" },
                { icon: "water", text: "Mist and ink over the wallpaper" },
                { icon: "hourglass_top", text: "Hanging-scroll clock: shichen, date and cultivation realm" }
            ]
        },
        {
            id: "cyberpunk",
            name: "Neon Noir",
            tagline: "Cyberpunk city desktop",
            icon: "location_city",
            lockTheme: "cyberpunk",
            tone: "neon",
            description: "A rain-slick city at night: your wallpaper's colours pushed to glowing neon, windows edged in a neon duotone, cut-corner tags on the bar, rain and a katakana sign over the wallpaper, your street cred, and a glitching neon-sign clock.",
            hypr: { rounding: 0, range: 26, power: 2, glow: "accent", glowAlpha: "80", inactive: "000000aa", dim: 0.12, border: { active: ["accent", "accent2"], angle: 135, inactive: "background", inactiveAlpha: "cc" } },
            bar: { shape: "neon", font: "Fragile Bombers", uiFont: "Rubik", weight: Font.Normal, sizeDelta: 2, letterSpacing: 0.6, border: 1, borderRole: "accent", borderAlpha: 0.7 },
            effects: {
                subtle: "Neon split-toning (your second neon in the shadows), a noir vignette and a hint of chromatic aberration at the screen edges.",
                strong: "Deeper split-toning, stronger aberration and a fine neon film grain."
            },
            changes: [
                { icon: "crop_square", text: "Square windows edged in a neon duotone; the rest sink into the dark" },
                { icon: "sell", text: "Cut-corner neon tags with condensed type on the bar" },
                { icon: "grain", text: "Rain, city haze and a katakana neon sign over the wallpaper" },
                { icon: "schedule", text: "A glitching neon-sign clock" }
            ]
        },
        {
            id: "wabisabi",
            name: "Wabi-sabi",
            tagline: "Traditional Japanese desktop",
            icon: "brush",
            lockTheme: "wabisabi",
            tone: "muted",
            description: "The beauty of the imperfect and the passing: your wallpaper's colours as muted Edo tones, washi paper and a seam of kintsugi gold over the wallpaper, pebble-shaped tags in Mincho type, and an ensō clock that keeps the old calendar and its 72 micro-seasons.",
            hypr: { rounding: 10, range: 30, power: 3, shadow: "140c0655", inactive: "0000002e", dim: 0.05, border: { active: ["accent"], inactive: "outline_variant", inactiveAlpha: "66" } },
            bar: { shape: "pebble", font: "Noto Serif CJK JP", weight: Font.Normal, sizeDelta: -1, letterSpacing: 0.3, border: 1, borderRole: "accent", borderAlpha: 0.35 },
            effects: {
                subtle: "Softly faded, warmer colour with a fine paper grain and gently aged edges.",
                strong: "An old woodblock print: faded colour, warm paper and heavier grain."
            },
            changes: [
                { icon: "rounded_corner", text: "Softly rounded windows with quiet, earthy borders" },
                { icon: "text_fields", text: "Pebble-shaped tags in Mincho type: no two corners alike" },
                { icon: "texture", text: "Washi paper and a kintsugi seam over the wallpaper" },
                { icon: "schedule", text: "Ensō clock with the old calendar and the micro-season" }
            ]
        },
        {
            id: "artdeco",
            name: "Art Deco",
            tagline: "Jazz Age skyline desktop",
            icon: "apartment",
            lockTheme: "artdeco",
            tone: "gilt",
            description: "The machine age in black lacquer and gold: your wallpaper's colour set as a jewel in gilt, windows framed in a gold hairline, stepped-corner tags in spaced capitals, a sunburst and a stepped gilt frame over the wallpaper, the floor you've risen to, and an elevator-dial clock.",
            hypr: { rounding: 0, range: 26, power: 3, glow: "accent", glowAlpha: "3a", inactive: "00000077", border: { active: ["accent"], inactive: "background", inactiveAlpha: "dd" } },
            bar: { shape: "deco", font: "Josefin Sans", weight: Font.DemiBold, sizeDelta: -3, letterSpacing: 1.2, caps: true, border: 1, borderRole: "accent", borderAlpha: 0.8 },
            effects: {
                subtle: "A gilded grade: deeper blacks, a gold sheen in the highlights and a soft vignette.",
                strong: "A black-and-gold poster print: colour drained towards lacquer and gilt, with a fine grain."
            },
            changes: [
                { icon: "crop_square", text: "Square windows framed in a gold hairline" },
                { icon: "stairs", text: "Stepped-corner gilt tags in spaced capitals on the bar" },
                { icon: "wb_twilight", text: "A sunburst and a stepped gilt frame over the wallpaper" },
                { icon: "elevator", text: "Elevator-dial clock; your level is the floor you've risen to" }
            ]
        },
        {
            id: "gothic",
            name: "Cathedral",
            tagline: "Gothic stained-glass desktop",
            icon: "church",
            lockTheme: "gothic",
            tone: "jewel",
            description: "A cathedral at vespers: your wallpaper's colours as stained glass, shafts of coloured light and drifting dust over the wallpaper, windows leaded in two jewel tones, cusped blackletter tags on the bar, and a rose-window clock that keeps the canonical hours.",
            hypr: { rounding: 3, range: 30, power: 3, glow: "accent", glowAlpha: "50", inactive: "000000aa", dim: 0.1, border: { active: ["accent", "accent2"], angle: 45, inactive: "surface_container_highest", inactiveAlpha: "bb" } },
            bar: { shape: "cusp", font: "Grenze Gotisch", uiFont: "Alegreya", weight: Font.Medium, sizeDelta: 0, letterSpacing: 0.3, border: 1, borderRole: "accent", borderAlpha: 0.55 },
            effects: {
                subtle: "Candlelight and stone: warm highlights, cool shadows and a deeper vignette.",
                strong: "The nave at dusk: darker, with the windows' coloured light pooling in the midtones."
            },
            changes: [
                { icon: "crop_square", text: "Near-square windows leaded in two jewel tones" },
                { icon: "text_fields", text: "Cusped tags with blackletter type on the bar" },
                { icon: "flare", text: "Shafts of stained-glass light and dust over the wallpaper" },
                { icon: "church", text: "Rose-window clock with the canonical hours and the church year" }
            ]
        },
        {
            id: "newspaper",
            name: "Broadsheet",
            tagline: "Newsprint desktop",
            icon: "newspaper",
            lockTheme: "newspaper",
            tone: "print",
            description: "The morning paper: your wallpaper printed in halftone on newsprint, windows cut out like clippings with hard offset shadows, ruled small-caps tags on the bar, desktop widgets as clippings, and a front-page clock that knows which edition is on the street.",
            hypr: { rounding: 0, range: 2, power: 1, sharp: true, offset: [7, 7], shadow: "000000a0", inactive: "00000070", border: { active: ["accent2"], inactive: "outline", inactiveAlpha: "aa" } },
            bar: { shape: "print", font: "Old Standard TT", weight: Font.Bold, sizeDelta: -2, letterSpacing: 0.6, caps: "small", border: 1, borderRole: "accent2", borderAlpha: 0.85 },
            effects: {
                subtle: "Newsprint: softened colour, a grey paper tone in the highlights and a fine paper grain.",
                strong: "Yesterday's paper: black-and-white newsprint with inky shadows and a heavier grain."
            },
            changes: [
                { icon: "crop_square", text: "Square windows cut out like clippings, with hard offset shadows" },
                { icon: "view_week", text: "Ruled small-caps tags in Old Standard on the bar" },
                { icon: "texture", text: "Your wallpaper printed in halftone on newsprint" },
                { icon: "schedule", text: "Front-page clock with the dateline and the edition" }
            ]
        },
        {
            id: "wasteland",
            name: "Wasteland",
            tagline: "Post-apocalyptic desktop",
            icon: "skull",
            lockTheme: "wasteland",
            tone: "dusty",
            description: "After the fall: your wallpaper's colours as weathered paint under a sky of dust, riveted scrap-metal tags stencilled on the bar, rust, grit and hazard tape over the wallpaper, widgets bolted to salvaged plates, and a survival clock that counts the days without incident.",
            hypr: { rounding: 1, range: 18, power: 3, shadow: "0c070399", inactive: "00000066", dim: 0.06, border: { active: ["accent2", "accent"], angle: 135, inactive: "surface_container_high", inactiveAlpha: "cc" } },
            bar: { shape: "plate", font: "Big Shoulders Stencil", uiFont: "Barlow Semi Condensed", weight: Font.Bold, sizeDelta: 0, letterSpacing: 1.1, caps: true, border: 1, borderRole: "accent", borderAlpha: 0.55 },
            effects: {
                subtle: "Dust in the air: a bleached, warm grade with amber highlights and fine grit.",
                strong: "A dust storm: harsh bleach-bypass contrast, a rust-orange cast and heavy grit."
            },
            changes: [
                { icon: "crop_square", text: "Rough square windows edged from hazard amber to rust" },
                { icon: "hardware", text: "Riveted scrap-metal tags stencilled on the bar" },
                { icon: "warning", text: "Dust, rust and hazard tape over the wallpaper" },
                { icon: "schedule", text: "Survival clock: the day, and the days without incident" }
            ]
        },
        {
            id: "observatory",
            name: "Observatory",
            tagline: "Ancient observatory desktop",
            icon: "explore",
            lockTheme: "observatory",
            tone: "brass",
            description: "A night at the old observatory: engraved brass with your wallpaper's colour as the enamel of the sky, the real sky over the wallpaper as a copperplate star chart facing the meridian (the stars where they stand right now, with the Moon and the planets among them), graduated tags in Fell type on the bar, and an astrolabe clock whose rete turns with the stars.",
            hypr: { rounding: 8, range: 26, power: 3, glow: "accent", glowAlpha: "3c", inactive: "00000077", dim: 0.07, border: { active: ["accent", "accent2"], angle: 90, inactive: "surface_container_high", inactiveAlpha: "cc" } },
            bar: { shape: "scale", font: "IM FELL English SC", uiFont: "EB Garamond", weight: Font.Normal, sizeDelta: 0, letterSpacing: 0.5, border: 1, borderRole: "accent", borderAlpha: 0.6 },
            effects: {
                subtle: "Nightfall under the dome: cool, blue shadows, warm lamplight in the highlights and a soft vignette.",
                strong: "An old copperplate plate: colour faded to ink and warm paper, with a fine engraver's hatching in the shadows."
            },
            changes: [
                { icon: "rounded_corner", text: "Softly rounded windows edged from brass to the sky's enamel" },
                { icon: "straighten", text: "Graduated brass tags in Fell type on the bar" },
                { icon: "stars", text: "The real sky over the wallpaper, engraved like an old star chart" },
                { icon: "explore", text: "Astrolabe clock: the rete turns with the stars" }
            ]
        },
        {
            id: "abyss",
            name: "Abyss",
            tagline: "Deep-sea submarine desktop",
            icon: "scuba_diving",
            lockTheme: "abyss",
            tone: "lume",
            description: "The deep, as deep as the hour: your wallpaper sunk under water, sunlit at noon and down in the trenches by midnight, with caustics, marine snow and bioluminescence in its colours; backlit instrument tags on the bar and a dive-watch clock.",
            hypr: { rounding: 14, range: 30, power: 3, glow: "accent", glowAlpha: "50", inactive: "00060c88", dim: 0.1, border: { active: ["accent2", "accent"], angle: 270, inactive: "surface_container_high", inactiveAlpha: "aa" } },
            bar: { shape: "lume", font: "B612", weight: Font.Bold, sizeDelta: -2, letterSpacing: 0.8, caps: true, border: 1, borderRole: "accent2", borderAlpha: 0.45 },
            effects: {
                subtle: "Under water: the reds soaked up by the sea, cool blue-green shadows and a dark rim like a porthole's.",
                strong: "The deep: colour drained to blue and green, a hazy veil of water and a heavier porthole rim."
            },
            changes: [
                { icon: "rounded_corner", text: "Rounded windows lit by a bioluminescent glow" },
                { icon: "radar", text: "Backlit instrument tags with a light strip on the bar" },
                { icon: "water", text: "Your wallpaper under water: caustics, depth haze and marine snow" },
                { icon: "scuba_diving", text: "Dive-watch clock with the zone of the ocean for the hour" }
            ]
        },
        {
            id: "devaloka",
            name: "Devaloka",
            tagline: "Indian mythology desktop",
            icon: "temple_hindu",
            lockTheme: "devaloka",
            tone: "temple",
            description: "The realm of the devas in marigold gold, your wallpaper's colour beside it as a painter's pigment: a small yantra seal with today's panchang in the corner, temple-border tags on the bar, and a Konark sun-wheel clock.",
            hypr: { rounding: 6, range: 28, power: 3, glow: "accent", glowAlpha: "44", inactive: "0c050388", dim: 0.08, border: { active: ["accent", "accent2"], angle: 90, inactive: "surface_container_high", inactiveAlpha: "cc" } },
            bar: { shape: "zari", font: "Eczar", uiFont: "Tiro Devanagari Sanskrit", weight: Font.DemiBold, sizeDelta: -1, letterSpacing: 0.3, border: 1, borderRole: "accent", borderAlpha: 0.6 },
            effects: {
                subtle: "Lamplight in the temple: marigold warmth in the highlights, the shadows deepened towards lac red, and a soft vignette.",
                strong: "An old pattachitra: colour settled into painted pigments on cloth, a fine weave and darkened edges."
            },
            changes: [
                { icon: "rounded_corner", text: "Gently rounded windows edged from temple gold to your pigment" },
                { icon: "temple_hindu", text: "Temple-border tags in Eczar on the bar" },
                { icon: "filter_vintage", text: "A yantra seal and today's panchang in the corner of the wallpaper" },
                { icon: "wb_sunny", text: "Konark sun-wheel clock: the prahar, the tithi and the nakshatra" }
            ]
        },
        {
            id: "siege",
            name: "Siege",
            tagline: "Medieval war desktop",
            icon: "swords",
            lockTheme: "siege",
            tone: "heraldic",
            description: "A castle at war: your wallpaper's colour as a heraldic tincture beside burnished steel, your coat of arms and the day of the siege in the corner, smoke and embers, crenellated tags on the bar, and a sword-and-buckler clock.",
            hypr: { rounding: 0, range: 22, power: 3, glow: "accent", glowAlpha: "3a", inactive: "0a060488", dim: 0.08, border: { active: ["accent2", "accent"], angle: 90, inactive: "surface_container_high", inactiveAlpha: "cc" } },
            bar: { shape: "crenel", font: "Germania One", uiFont: "Texturina", weight: Font.Normal, sizeDelta: -2, letterSpacing: 0.5, border: 1, borderRole: "accent", borderAlpha: 0.6 },
            effects: {
                subtle: "Smoke over the field: colour dulled towards steel and ash while your tincture keeps its colour like a banner, firelight in the highlights and a dark vignette.",
                strong: "The Bayeux Tapestry: the picture worked in wool on linen, in the few dyes the embroiderers had, with the stitches showing."
            },
            changes: [
                { icon: "crop_square", text: "Square windows edged from steel to your tincture" },
                { icon: "fort", text: "Crenellated tags in Germania One on the bar" },
                { icon: "shield", text: "Your coat of arms and the day of the siege in the corner of the wallpaper, under smoke and embers" },
                { icon: "swords", text: "Sword-and-buckler clock that keeps the watches of the siege" }
            ]
        }
    ]

    readonly property var plainLook: ({ shape: "round", font: "", weight: Font.Normal, sizeDelta: 0, letterSpacing: 0, border: 0 })

    readonly property alias theme: adapter.theme
    readonly property alias screenEffect: adapter.screenEffect
    readonly property alias matchLock: adapter.matchLock
    readonly property bool enabled: has(adapter.theme)
    readonly property var current: enabled ? themeFor(adapter.theme) : null
    readonly property var look: lookFor(adapter.theme)
    readonly property bool hud: look.shape === "chamfer"
    readonly property string lockTheme: enabled && adapter.matchLock ? (current.lockTheme ?? "") : ""
    property bool ready: false
    property bool manage: false
    property string lastError: ""

    function has(id) {
        return themes.some(t => t.id === id);
    }

    function themeFor(id) {
        return themes.find(t => t.id === id) ?? themes[0];
    }

    function lookFor(id) {
        return has(id) ? themeFor(id).bar : plainLook;
    }

    // Shapes drawn square (their corners, if any, are cut by masks and
    // frames: HudMask, NeonMask, DecoMask, CuspMask, CrenelMask).
    readonly property var squareShapes: ["chamfer", "square", "neon", "deco", "cusp", "print", "crenel"]

    // Corner radius for a bar shape, given the plain design's radius.
    function radius(lk, normal, h) {
        switch (lk.shape) {
        case "chamfer":
        case "square":
        case "neon":
        case "deco":
        case "cusp":
        case "print":
        case "crenel":
            return 0;
        case "plate":
            return Math.min(normal, 2);
        case "seal":
            return Math.min(normal, 3);
        case "scale":
            return Math.min(normal, 4);
        case "lume":
            return Math.min(normal, 8);
        case "zari":
            return Math.min(normal, 6);
        case "soft":
            return Math.min(normal, 9);
        case "pebble":
            return Math.min(normal, h * 0.42);
        case "pill":
            return h / 2;
        default:
            return normal;
        }
    }

    // Wabi-sabi's pebbles: each corner of a shape rounded differently, like
    // a river stone. Factors on the radius, clockwise from top left.
    readonly property var pebbleCorners: [1, 0.5, 1.15, 0.65]

    // One corner (0 top left, 1 top right, 2 bottom right, 3 bottom left) of
    // a shape whose radius is `r` under the look `lk`.
    function corner(lk, r, i) {
        return lk.shape === "pebble" ? r * pebbleCorners[i] : r;
    }

    // Corner radius for a panel's outer surface, given its plain radius:
    // square for HUD, Mainframe, Neon Noir, Art Deco, Cathedral, Broadsheet
    // and Siege, a slight round for Cave Abode and Wasteland, an
    // instrument plate's for Observatory, a lacquered plaque's for
    // Devaloka, unchanged for the round themes.
    function panelRadius(normal) {
        const sh = look.shape;
        return squareShapes.includes(sh) ? 0 : sh === "seal" || sh === "plate" ? Math.min(normal, sh === "seal" ? 4 : 3)
            : sh === "scale" ? Math.min(normal, 10) : sh === "zari" ? Math.min(normal, 8) : normal;
    }

    // Corner radius the theme imposes on controls inside panels (buttons,
    // cards, chips, fields), or -1 to leave them as designed.
    readonly property real controlRadius: squareShapes.includes(look.shape) ? 0 : look.shape === "seal" ? 3 : look.shape === "plate" ? 2 : look.shape === "scale" ? 4 : look.shape === "zari" ? 5 : -1

    // Astral rounds controls into capsules instead; Still drops card borders.
    // (Wabi-sabi's cards turn into pebbles through corner().)
    readonly property bool roundControls: look.shape === "pill"
    readonly property bool borderless: look.shape === "soft"

    // `normal`, squared off, sealed or rounded further by the theme.
    function rad(normal) {
        return controlRadius >= 0 ? controlRadius : roundControls ? Math.round(normal * 1.5) : normal;
    }

    // Font for text that doesn't choose its own ("" = the default).
    readonly property string font: look.uiFont ?? look.font

    // The hairline of a look; `id` is the theme it belongs to when that
    // isn't the active one (a preview).
    function borderColor(lk, id) {
        return lk.border ? Colors.withAlpha(roleColor(lk.borderRole ?? "primary", id), lk.borderAlpha ?? 0.4) : "transparent";
    }

    // ── Palette ──────────────────────────────────────────────────────────────
    // Every theme takes its accents from the wallpaper (Colors.primary and
    // .tertiary). A theme's `tone` changes how it wears them:
    //   neon:  full saturation, lit like a tube, and always a duotone: if the
    //          two hues are too close, the second swings round the wheel.
    //   muted: drained to the dusty greys and browns of Edo dyeing (its "48
    //          browns and 100 greys"), keeping each hue.
    //   gilt:  Art Deco's gold leaf (a breath of the wallpaper in it), with
    //          the wallpaper's colour as a deep jewel tone beside it.
    //   jewel: stained glass: rich, deep and saturated; the second pane
    //          swings round the wheel when the two hues are too close.
    //   print: a newspaper's spot colour, and the ink it's printed with
    //          (whichever of ink or newsprint stands out on the scheme).
    //   dusty: weathered paint gone chalky under dust, and hazard amber.
    //   brass: an instrument maker's aged brass (a breath of the wallpaper
    //          in it), with the wallpaper's colour as the enamel of the sky
    //          beside it (never golden: that would read as more brass).
    //   lume:  the wallpaper's colour as a creature's glow in the deep (drawn
    //          a little towards the sea's blue-green), and the pale sea-glow
    //          of a dive watch's lume beside it.
    //   temple: marigold and temple gold (a breath of the wallpaper in it),
    //          with the wallpaper's colour beside it as a painter's pigment:
    //          indigo, lac, malachite; never golden, and kumkum vermilion
    //          when the wallpaper has no colour to give.
    //   heraldic: the wallpaper's colour drawn most of the way to the
    //          heraldic tincture a herald would call it (gules, tenné, vert,
    //          azure, purpure or murrey; gules when there is none; see
    //          Heraldry), and argent beside it as burnished steel: a colour
    //          and a metal, as the rule of tincture wants.
    // accent/accent2 are the active theme's; accentOf/accent2Of any theme's
    // (previews show themes that aren't on).
    readonly property color accent: accentOf(adapter.theme)
    readonly property color accent2: accent2Of(adapter.theme)

    function toneOf(id) {
        return has(id) ? (themeFor(id).tone ?? "") : "";
    }

    function accentOf(id) {
        switch (toneOf(id)) {
        case "neon":
            return _neon(_hue(Colors.primary, 0.86));
        case "muted":
            return _muted(Colors.primary);
        case "gilt":
            return Qt.tint(Qt.hsla(0.118, 0.62, _dark ? 0.62 : 0.4, 1), Colors.withAlpha(Colors.primary, 0.08));
        case "jewel":
            return _jewel(_hue(Colors.primary, 0.62));
        case "print":
            return Qt.hsla(_hue(Colors.primary, 0), 0.66, _dark ? 0.62 : 0.42, 1);
        case "dusty":
            return _weathered(Colors.primary);
        case "brass":
            return Qt.tint(Qt.hsla(0.108, 0.5, _dark ? 0.6 : 0.36, 1), Colors.withAlpha(Colors.primary, 0.1));
        case "lume":
            return _biolum(_toSea(_hue(Colors.primary, 0.52)));
        case "temple":
            return Qt.tint(Qt.hsla(0.1, 0.84, _dark ? 0.58 : 0.4, 1), Colors.withAlpha(Colors.primary, 0.08));
        case "heraldic": {
            const t = Heraldry.tincture;
            return Qt.hsla(t.h, t.sat, _dark ? 0.6 : 0.4, 1);
        }
        default:
            return Qt.color(Colors.primary);
        }
    }

    function accent2Of(id) {
        switch (toneOf(id)) {
        case "neon": {
            const a = _hue(Colors.primary, 0.86);
            const b = _hue(Colors.tertiary, 0.52);
            return _neon(_hueGap(a, b) < 0.2 ? (a + 0.42) % 1 : b);
        }
        case "muted":
            return _muted(Colors.tertiary);
        case "gilt": {
            // A jewel beside the gold: never gold itself.
            const golden = h => h > 0.06 && h < 0.18;
            const p = _hue(Colors.primary, -1);
            const t = _hue(Colors.tertiary, -1);
            const h = p >= 0 && !golden(p) ? p : t >= 0 && !golden(t) ? t : 0.47;
            return Qt.hsla(h, 0.58, _dark ? 0.5 : 0.34, 1);
        }
        case "jewel": {
            const g = _hue(Colors.primary, 0.62);
            const b = _hue(Colors.tertiary, 0.95);
            return _jewel(_hueGap(g, b) < 0.12 ? (g + 0.36) % 1 : b);
        }
        case "print":
            return _dark ? Qt.color("#ece6d6") : Qt.color("#1c1b19");
        case "dusty":
            return Qt.tint(Qt.hsla(0.118, 0.82, _dark ? 0.56 : 0.42, 1), Colors.withAlpha(Colors.tertiary, 0.1));
        case "brass": {
            // The sky's enamel beside the brass: never golden itself.
            const golden = h => h > 0.05 && h < 0.2;
            const p = _hue(Colors.primary, -1);
            const t = _hue(Colors.tertiary, -1);
            const h = p >= 0 && !golden(p) ? p : t >= 0 && !golden(t) ? t : 0.62;
            return Qt.hsla(h, 0.46, _dark ? 0.58 : 0.34, 1);
        }
        case "lume":
            return Qt.tint(Qt.hsla(0.46, 0.7, _dark ? 0.7 : 0.34, 1), Colors.withAlpha(Colors.tertiary, 0.08));
        case "temple": {
            // A pigment beside the gold: never golden itself.
            const golden = h => h > 0.05 && h < 0.17;
            const p = _hue(Colors.primary, -1);
            const t = _hue(Colors.tertiary, -1);
            const h = p >= 0 && !golden(p) ? p : t >= 0 && !golden(t) ? t : 0.015;
            return Qt.hsla(h, 0.66, _dark ? 0.56 : 0.4, 1);
        }
        case "heraldic":
            return Qt.tint(Qt.hsla(0.6, 0.09, _dark ? 0.8 : 0.34, 1), Colors.withAlpha(Colors.primary, 0.06));
        default:
            return Qt.color(Colors.tertiary);
        }
    }

    // A colour role: a Colors name, or a theme's toned "accent" / "accent2".
    function roleColor(role, id) {
        const themeId = id ?? adapter.theme;
        return role === "accent" ? accentOf(themeId) : role === "accent2" ? accent2Of(themeId) : Qt.color(Colors[role]);
    }

    readonly property bool _dark: Qt.color(Colors.background).hslLightness < 0.5

    // Hue of `c` (0..1), or `fallback` when it's a grey.
    function _hue(c, fallback) {
        const q = Qt.color(c);
        return q.hslHue < 0 || q.hslSaturation < 0.06 ? fallback : q.hslHue;
    }

    function _neon(h) {
        return Qt.hsla(h, 1, _dark ? 0.62 : 0.42, 1);
    }

    function _muted(c) {
        const q = Qt.color(c);
        const m = Qt.hsla(_hue(c, 0.08), Math.min(0.32, 0.08 + q.hslSaturation * 0.24), _dark ? 0.66 : 0.4, 1);
        // A touch of warmth, like dye on undyed cloth.
        return Qt.tint(m, Qt.rgba(0.62, 0.47, 0.33, 0.14));
    }

    // Distance between two hues round the wheel (0..0.5).
    function _hueGap(a, b) {
        const d = Math.abs(a - b);
        return Math.min(d, 1 - d);
    }

    function _jewel(h) {
        return Qt.hsla(h, 0.74, _dark ? 0.6 : 0.42, 1);
    }

    function _weathered(c) {
        const q = Qt.color(c);
        const m = Qt.hsla(_hue(c, 0.07), Math.min(0.42, 0.14 + q.hslSaturation * 0.3), _dark ? 0.58 : 0.4, 1);
        // Sun-bleached and dusted: a warm, chalky cast.
        return Qt.tint(m, Qt.rgba(0.75, 0.52, 0.28, 0.22));
    }

    // A hue drawn a third of the way towards the sea's blue-green (0.5), the
    // colour light keeps longest under water. Hues across the wheel from it
    // (the reds a few deep-sea fish glow in) are left alone.
    function _toSea(h) {
        let d = 0.5 - h;
        if (d > 0.5)
            d -= 1;
        if (d < -0.5)
            d += 1;
        return Math.abs(d) > 0.34 ? h : (h + d * 0.33 + 1) % 1;
    }

    function _biolum(h) {
        return Qt.hsla(h, 0.8, _dark ? 0.66 : 0.38, 1);
    }

    function setTheme(id) {
        const next = has(id) ? id : "";
        if (next)
            adapter.lastTheme = next;
        adapter.theme = next;
    }

    function toggle() {
        setTheme(enabled ? "" : (has(adapter.lastTheme) ? adapter.lastTheme : themes[0].id));
    }

    function setScreenEffect(mode) {
        if (["off", "subtle", "strong"].includes(mode))
            adapter.screenEffect = mode;
    }

    function setMatchLock(on) {
        adapter.matchLock = on;
    }

    // ── Compositor ───────────────────────────────────────────────────────────
    readonly property string shaderPath: Quickshell.env("HOME") + "/.cache/quickshell/desktop-theme.frag"
    property bool _reverting: false
    // Theme whose screen shader template is loaded; "" while loading, "-" if
    // it has none.
    property string _templateId: ""

    function _hex(c) {
        const q = Qt.color(c);
        const h = v => Math.round(v * 255).toString(16).padStart(2, "0");
        return h(q.r) + h(q.g) + h(q.b);
    }

    function _vec3(c) {
        const q = Qt.color(c);
        return q.r.toFixed(4) + ", " + q.g.toFixed(4) + ", " + q.b.toFixed(4);
    }

    function _sync() {
        if (!manage || !ready)
            return;
        if (enabled)
            _apply();
        else if (adapter.appliedTheme)
            _revert();
    }

    function _lua(t, shader) {
        const h = t.hypr;
        const color = h.glow ? _hex(roleColor(h.glow, t.id)) + h.glowAlpha : h.shadow;
        let shadow = "enabled = true, range = " + h.range + ", render_power = " + h.power
            + ", color = \"rgba(" + color + ")\", color_inactive = \"rgba(" + h.inactive + ")\"";
        if (h.sharp)
            shadow += ", sharp = true";
        if (h.offset)
            shadow += ", offset = \"" + h.offset[0] + " " + h.offset[1] + "\"";
        let deco = "rounding = " + h.rounding + ", shadow = { " + shadow + " }";
        if (h.dim)
            deco += ", dim_inactive = true, dim_strength = " + h.dim;
        let lua = "hl.config({ decoration = { " + deco + ", screen_shader = \"" + shader + "\" }";
        if (h.border) {
            // Gradients as hyprland.lua writes them (two stops, even for one colour).
            const gradient = (roles, alpha) => {
                const stops = roles.map(r => "\"rgba(" + _hex(roleColor(r, t.id)) + alpha + ")\"");
                if (stops.length === 1)
                    stops.push(stops[0]);
                return "{ colors = { " + stops.join(", ") + " }, angle = " + (h.border.angle ?? 45) + " }";
            };
            lua += ", general = { col = { active_border = " + gradient(h.border.active, "ff")
                + ", inactive_border = " + gradient([h.border.inactive], h.border.inactiveAlpha ?? "ff") + " } }";
        }
        return lua + " })";
    }

    function _apply() {
        const id = adapter.theme;
        const effect = adapter.screenEffect;
        let shader = "";
        if (effect !== "off") {
            if (_templateId === "")
                return; // template still loading; its onLoaded syncs again
            if (_templateId === id) {
                const strong = effect === "strong";
                const text = template.text()
                    .split("@ACCENT@").join(_vec3(accentOf(id)))
                    .split("@ACCENT2@").join(_vec3(accent2Of(id)))
                    .split("@STRENGTH@").join(strong ? "1.8" : "1.0")
                    .split("@STRONG@").join(strong ? "1.0" : "0.0")
                    .split("@SCANLINES@").join(strong ? "1.0" : "0.0");
                shaderFile.setText(text);
                shader = shaderPath;
            }
        }
        const lua = _lua(themeFor(id), shader);
        if (adapter.appliedTheme && adapter.appliedTheme !== id) {
            // Another theme's overrides are live: start from the real config.
            _reverting = true;
            revertGuard.restart();
            hyprctl.exec(["sh", "-c", "hyprctl reload >/dev/null && hyprctl eval \"$1\"", "sh", lua]);
        } else {
            hyprctl.exec(["hyprctl", "eval", lua]);
        }
        adapter.appliedTheme = id;
    }

    function _revert() {
        _reverting = true;
        revertGuard.restart();
        adapter.appliedTheme = "";
        hyprctl.exec(["hyprctl", "reload"]);
    }

    // If the reload's event never arrives, don't swallow the next real one.
    Timer {
        id: revertGuard
        interval: 3000
        onTriggered: root._reverting = false
    }

    // Coalesces bursts (a new wallpaper rewrites every colour at once).
    Timer {
        id: syncTimer
        interval: 250
        onTriggered: root._sync()
    }

    onManageChanged: syncTimer.restart()
    onReadyChanged: syncTimer.restart()
    onThemeChanged: syncTimer.restart()
    onScreenEffectChanged: syncTimer.restart()

    Connections {
        target: Colors

        function onPrimaryChanged() {
            if (root.enabled)
                syncTimer.restart();
        }

        function onTertiaryChanged() {
            if (root.enabled)
                syncTimer.restart();
        }
    }

    // A config reload wipes the runtime overrides: put them back, unless the
    // reload was ours.
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "configreloaded")
                return;
            if (root._reverting) {
                root._reverting = false;
            } else if (root.manage && root.enabled) {
                adapter.appliedTheme = "";
                syncTimer.restart();
            }
        }
    }

    Process {
        id: hyprctl
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                root.lastError = out.startsWith("error") ? out : "";
                if (root.lastError)
                    console.warn("desktop theme:", root.lastError);
            }
        }
    }

    FileView {
        id: template
        path: Quickshell.shellPath("shaders/" + (adapter.theme || "none") + "_screen.frag.in")
        printErrors: false
        onPathChanged: root._templateId = ""
        onLoaded: {
            root._templateId = adapter.theme;
            if (root.enabled)
                syncTimer.restart();
        }
        onLoadFailed: {
            root._templateId = "-";
            if (root.enabled)
                syncTimer.restart();
        }
    }

    FileView {
        id: shaderFile
        path: root.shaderPath
        blockWrites: true
        printErrors: false
    }

    // ── Settings ─────────────────────────────────────────────────────────────
    Timer {
        id: writeTimer
        interval: 100
        repeat: false
        onTriggered: settingsFile.writeAdapter()
    }

    Timer {
        id: reloadTimer
        interval: 100
        repeat: false
        onTriggered: settingsFile.reload()
    }

    FileView {
        id: settingsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/desktoptheme.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reloadTimer.restart()
        onAdapterUpdated: writeTimer.restart()
        onLoaded: root.ready = true
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound)
                root.ready = true;
        }

        adapter: JsonAdapter {
            id: adapter
            property string theme: ""
            // What the Themes tile / toggle turns back on.
            property string lastTheme: "hud"
            property string screenEffect: "subtle"
            property bool matchLock: true
            // Theme whose overrides are (or may still be) live in Hyprland, so
            // switching or turning off knows a reload is needed.
            property string appliedTheme: ""
        }
    }
}
