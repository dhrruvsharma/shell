pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs.colors

// Desktop themes: one coordinated look across the rice, still coloured by
// the wallpaper. A theme touches three layers:
//   - Hyprland: corner rounding, a glow on the focused window, and an
//     optional static screen shader (shaders/<id>_screen.frag.in, baked with
//     the current colours). Applied at runtime with `hyprctl eval`; switching
//     themes or turning them off runs `hyprctl reload` first, which restores
//     the config exactly.
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

    // hypr: rounding, shadow range/render_power, `glow` (a Colors role with a
    //       hex alpha) or a fixed `shadow` colour, inactive shadow colour, and
    //       an optional dim for unfocused windows.
    // bar:  shape (round | chamfer | square | pill | soft | seal), font,
    //       weight, size delta, letter spacing, hairline border.
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

    // Corner radius for a bar shape, given the plain design's radius.
    function radius(lk, normal, h) {
        switch (lk.shape) {
        case "chamfer":
        case "square":
            return 0;
        case "seal":
            return Math.min(normal, 3);
        case "soft":
            return Math.min(normal, 9);
        case "pill":
            return h / 2;
        default:
            return normal;
        }
    }

    // Corner radius for a panel's outer surface, given its plain radius:
    // square for HUD and Mainframe, a slight round for Cave Abode, unchanged
    // for the round themes.
    function panelRadius(normal) {
        const sh = look.shape;
        return sh === "chamfer" || sh === "square" ? 0 : sh === "seal" ? Math.min(normal, 4) : normal;
    }

    // Corner radius the theme imposes on controls inside panels (buttons,
    // cards, chips, fields), or -1 to leave them as designed.
    readonly property real controlRadius: look.shape === "chamfer" || look.shape === "square" ? 0 : look.shape === "seal" ? 3 : -1

    // Astral rounds controls into capsules instead; Still drops card borders.
    readonly property bool roundControls: look.shape === "pill"
    readonly property bool borderless: look.shape === "soft"

    // `normal`, squared off, sealed or rounded further by the theme.
    function rad(normal) {
        return controlRadius >= 0 ? controlRadius : roundControls ? Math.round(normal * 1.5) : normal;
    }

    // Font for text that doesn't choose its own ("" = the default).
    readonly property string font: look.font

    function borderColor(lk) {
        return lk.border ? Colors.withAlpha(Colors[lk.borderRole ?? "primary"], lk.borderAlpha ?? 0.4) : "transparent";
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
        const color = h.glow ? _hex(Colors[h.glow]) + h.glowAlpha : h.shadow;
        let deco = "rounding = " + h.rounding + ", shadow = { enabled = true, range = " + h.range
            + ", render_power = " + h.power + ", color = \"rgba(" + color + ")\", color_inactive = \"rgba(" + h.inactive + ")\" }";
        if (h.dim)
            deco += ", dim_inactive = true, dim_strength = " + h.dim;
        return "hl.config({ decoration = { " + deco + ", screen_shader = \"" + shader + "\" } })";
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
                    .split("@ACCENT@").join(_vec3(Colors.primary))
                    .split("@ACCENT2@").join(_vec3(Colors.tertiary))
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
