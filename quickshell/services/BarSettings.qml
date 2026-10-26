pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick
import qs.colors

// The bar's own settings (its chapter in the customizer's book, SUPER+B or
// the gear on the bar): which of its widgets show, the colour, transparency
// and outline of their containers, and how wide each is. Where the widgets
// sit is BarLayout's; the pet's showing is the pet's own (Pet.shown).
//
// Colours come from the wallpaper (a tone of matugen's scheme, "default"
// being the bar's usual surfaces) or are picked by hand; the text follows
// them, readable on whatever the containers are, unless it's picked too.
// Transparency fades the containers, never the text.
//
// Settings: ~/.config/quickshell/barsettings.json.
Singleton {
    id: root

    // Everything the bar can show, in the order the panel lists it. Those
    // with a `file` (under modules/bar/) are BarLayout's draggable widgets;
    // the media pill stays in the middle, the tray at the end, and the pet
    // walks in between. A new widget goes here and in BarLayout.knownIds.
    readonly property var widgets: [
        { id: "clock", name: "Clock", icon: "schedule", description: "Date and time", file: "components/Clock.qml" },
        { id: "battery", name: "Battery", icon: "battery_5_bar", description: "Charge level", file: "components/Battery.qml" },
        { id: "cpu", name: "CPU", icon: "memory", description: "Processor load", file: "components/Cpu.qml" },
        { id: "memory", name: "Memory", icon: "memory_alt", description: "RAM in use", file: "components/Memory.qml" },
        { id: "temp", name: "Temperature", icon: "device_thermostat", description: "CPU heat, red when hot", file: "components/Temp.qml" },
        { id: "volume", name: "Volume", icon: "volume_up", description: "Output level", file: "components/Volume.qml" },
        { id: "network", name: "Wi-Fi", icon: "wifi", description: "The network you're on", file: "components/Network.qml" },
        { id: "bluetooth", name: "Bluetooth", icon: "bluetooth", description: "Connected device", file: "components/Bluetooth.qml" },
        { id: "updates", name: "Updates", icon: "system_update_alt", description: "Packages to update", file: "components/Updates.qml" },
        { id: "settings", name: "Settings button", icon: "settings", description: "Opens these settings", file: "components/Settings.qml" },
        { id: "media", name: "Now playing", icon: "music_note", description: "The track, in the middle" },
        { id: "tray", name: "System tray", icon: "apps", description: "Apps' icons, at the end" },
        { id: "pet", name: "Pet", icon: "pets", description: "Walks along the bar" }
    ]

    // id -> widget file, for the draggable ones (TopBar loads them).
    readonly property var atomSources: {
        const m = {};
        for (const w of root.widgets)
            if (w.file)
                m[w.id] = w.file;
        return m;
    }

    function info(id) {
        return root.widgets.find(w => w.id === id) ?? null;
    }

    // ── Which widgets show ───────────────────────────────────────────────────

    function shown(id) {
        return id === "pet" ? Pet.shown : !adapter.hidden.includes(id);
    }

    function setShown(id, on) {
        if (id === "pet") {
            Pet.setShown(on);
            return;
        }
        if (!root.info(id) || root.shown(id) === on)
            return;
        adapter.hidden = on ? adapter.hidden.filter(h => h !== id) : adapter.hidden.concat([id]);
    }

    function toggle(id) {
        root.setShown(id, !root.shown(id));
    }

    function showAll() {
        adapter.hidden = [];
        Pet.setShown(true);
    }

    readonly property int shownCount: root.widgets.filter(w => root.shown(w.id)).length

    // ── Colours ──────────────────────────────────────────────────────────────

    // The wallpaper's tones for the containers: a fill and the text that
    // goes on it. "default" is the bar as it always was: pills on the
    // container surface, groups on the one above, the media pill on the
    // background. The others put groups a shade towards their text and the
    // media pill in the same fill.
    readonly property var tones: [
        { id: "default", name: "Default", fill: Colors.surface_container, group: Colors.surface_container_high, capsule: Colors.background, ink: Colors.on_surface },
        { id: "deep", name: "Deep", fill: Colors.surface_container_lowest, ink: Colors.on_surface },
        { id: "raised", name: "Raised", fill: Colors.surface_container_highest, ink: Colors.on_surface },
        { id: "primary", name: "Primary", fill: Colors.primary_container, ink: Colors.on_primary_container },
        { id: "secondary", name: "Secondary", fill: Colors.secondary_container, ink: Colors.on_secondary_container },
        { id: "tertiary", name: "Tertiary", fill: Colors.tertiary_container, ink: Colors.on_tertiary_container },
        { id: "vivid", name: "Vivid", fill: Colors.primary, ink: Colors.on_primary }
    ]

    // The wallpaper's tones for the text: "auto" is whatever reads on the
    // containers (the tone's own text, or the scheme's light or dark text
    // on a colour picked by hand).
    readonly property var textTones: [
        { id: "auto", name: "Readable" },
        { id: "primary", name: "Primary", color: Colors.primary },
        { id: "secondary", name: "Secondary", color: Colors.secondary },
        { id: "tertiary", name: "Tertiary", color: Colors.tertiary }
    ]

    readonly property alias colorMode: adapter.colorMode
    readonly property alias toneId: adapter.tone
    readonly property alias customColor: adapter.customColor
    readonly property alias textMode: adapter.textMode
    readonly property alias textToneId: adapter.textTone
    readonly property alias customText: adapter.customText
    readonly property real transparency: Math.max(0, Math.min(1, adapter.transparency))
    readonly property alias outline: adapter.outline

    readonly property var tone: root.tones.find(t => t.id === adapter.tone) ?? root.tones[0]
    readonly property var textTone: root.textTones.find(t => t.id === adapter.textTone) ?? root.textTones[0]
    readonly property bool customFill: adapter.colorMode === "custom" && root.isHex(adapter.customColor)
    readonly property bool customInk: adapter.textMode === "custom" && root.isHex(adapter.customText)

    // The containers' colour and their text, before any transparency.
    readonly property color fill: root.customFill ? adapter.customColor : root.tone.fill
    readonly property color autoInk: root.customFill ? root.readableOn(root.fill) : root.tone.ink
    readonly property color ink: root.customInk ? adapter.customText : (root.textTone.color ?? root.autoInk)

    // What the bar paints with: a lone widget's pill, the tray a group of
    // them sits in, the media pill (and the tray's button), and the
    // outline drawn round them when it's on.
    readonly property real fillOpacity: 1 - root.transparency
    readonly property color pill: Colors.withAlpha(root.fill, root.fillOpacity)
    readonly property color group: Colors.withAlpha(!root.customFill && root.tone.group ? root.tone.group : Qt.tint(root.fill, Colors.withAlpha(root.autoInk, 0.08)), root.fillOpacity)
    readonly property color capsule: Colors.withAlpha(!root.customFill && root.tone.capsule ? root.tone.capsule : root.fill, root.fillOpacity)
    readonly property color outlineColor: Colors.withAlpha(root.ink, 0.3)
    // An accent that still reads on the containers (the updates count), or
    // the text when the wallpaper's primary doesn't.
    readonly property color highlight: root.contrast(Colors.primary, root.fill) >= 2.6 ? Colors.primary : root.ink

    function isHex(s) {
        return /^#[0-9a-fA-F]{6}$/.test(String(s ?? ""));
    }

    // "#rrggbb" of a colour, dropping its alpha.
    function hex(c) {
        const q = Qt.color(c);
        const h = v => ("0" + Math.round(v * 255).toString(16)).slice(-2);
        return "#" + h(q.r) + h(q.g) + h(q.b);
    }

    // WCAG relative luminance and contrast ratio.
    function luminance(c) {
        const q = Qt.color(c);
        const lin = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        return 0.2126 * lin(q.r) + 0.7152 * lin(q.g) + 0.0722 * lin(q.b);
    }

    function contrast(a, b) {
        const la = root.luminance(a), lb = root.luminance(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }

    // The scheme's light or dark text, whichever reads better on `c`.
    function readableOn(c) {
        return root.contrast(Colors.on_surface, c) >= root.contrast(Colors.inverse_on_surface, c) ? Colors.on_surface : Colors.inverse_on_surface;
    }

    function setColorMode(mode) {
        if (mode !== "wallpaper" && mode !== "custom")
            return;
        // A first visit to the picker starts from the colour on the bar.
        if (mode === "custom" && !root.isHex(adapter.customColor))
            adapter.customColor = root.hex(root.fill);
        adapter.colorMode = mode;
    }

    function setTone(id) {
        if (root.tones.some(t => t.id === id)) {
            adapter.tone = id;
            adapter.colorMode = "wallpaper";
        }
    }

    // Whether `c` is a colour: a colour value, or "#rrggbb".
    function _usable(c) {
        return typeof c !== "string" || root.isHex(c);
    }

    // A colour picked by hand ("" goes back to the wallpaper's).
    function setCustomColor(c) {
        if (c === "") {
            adapter.colorMode = "wallpaper";
            return;
        }
        if (!root._usable(c))
            return;
        const h = root.hex(c);
        if (adapter.customColor !== h)
            adapter.customColor = h;
        adapter.colorMode = "custom";
    }

    function setTextMode(mode) {
        if (mode !== "wallpaper" && mode !== "custom")
            return;
        if (mode === "custom" && !root.isHex(adapter.customText))
            adapter.customText = root.hex(root.ink);
        adapter.textMode = mode;
    }

    function setTextTone(id) {
        if (root.textTones.some(t => t.id === id)) {
            adapter.textTone = id;
            adapter.textMode = "wallpaper";
        }
    }

    function setCustomText(c) {
        if (c === "") {
            adapter.textMode = "wallpaper";
            return;
        }
        if (!root._usable(c))
            return;
        const h = root.hex(c);
        if (adapter.customText !== h)
            adapter.customText = h;
        adapter.textMode = "custom";
    }

    // 0 solid .. 1 clear.
    function setTransparency(t) {
        const v = Math.round(Math.max(0, Math.min(1, t)) * 100) / 100;
        if (adapter.transparency !== v)
            adapter.transparency = v;
    }

    function setOutline(on) {
        adapter.outline = on;
    }

    // The bar's usual look (which widgets show is left as it is). The
    // colours picked by hand are kept for the next visit to the picker.
    function resetLook() {
        adapter.colorMode = "wallpaper";
        adapter.tone = "default";
        adapter.textMode = "wallpaper";
        adapter.textTone = "auto";
        adapter.transparency = 0;
        adapter.outline = false;
    }

    readonly property bool lookIsDefault: adapter.colorMode === "wallpaper" && adapter.tone === "default"
        && adapter.textMode === "wallpaper" && adapter.textTone === "auto" && root.transparency === 0 && !adapter.outline

    // ── Widths ───────────────────────────────────────────────────────────────
    // How wide each container is on a bar lying along the top or bottom: a
    // width in px, or 0 for "auto", as wide as its text (the media pill's
    // auto is a fixed 200 px). Text that doesn't fit is cut short with "…"
    // and scrolled through as `overflow` says: "hover" (as the media pill
    // always did), "always" or "cut" (never), at `scrollSpeed`.

    // What can be sized, in the panel's order (the tray and pet can't).
    readonly property var sizedIds: root.widgets.filter(w => w.id !== "tray" && w.id !== "pet").map(w => w.id)
    readonly property var autoWidths: ({ media: 200 })
    readonly property int widthMin: 24
    readonly property int widthMax: 480
    readonly property alias overflow: adapter.overflow
    readonly property alias scrollSpeed: adapter.scrollSpeed
    // Pixels a second; "normal" is the media pill's old pace.
    readonly property int scrollPxPerSecond: ({ slow: 30, normal: 50, fast: 90 })[adapter.scrollSpeed] ?? 50
    readonly property bool widthsAreDefault: Object.keys(adapter.widths).length === 0 && adapter.overflow === "hover" && adapter.scrollSpeed === "normal"

    function widthOf(id) {
        const w = adapter.widths[id];
        return typeof w === "number" && w > 0 ? w : 0;
    }

    // Several at once, { id: px } (0 or less: back to auto), in one write.
    function setWidths(changes) {
        const next = Object.assign({}, adapter.widths);
        let changed = false;
        for (const id of Object.keys(changes)) {
            if (!root.sizedIds.includes(id))
                continue;
            const w = Math.round(changes[id]);
            if (w > 0) {
                const v = Math.max(root.widthMin, Math.min(root.widthMax, w));
                if (next[id] !== v) {
                    next[id] = v;
                    changed = true;
                }
            } else if (id in next) {
                delete next[id];
                changed = true;
            }
        }
        if (changed)
            adapter.widths = next;
    }

    function setWidth(id, w) {
        root.setWidths({ [id]: w });
    }

    function setOverflow(mode) {
        if (["hover", "always", "cut"].includes(mode))
            adapter.overflow = mode;
    }

    function setScrollSpeed(speed) {
        if (["slow", "normal", "fast"].includes(speed))
            adapter.scrollSpeed = speed;
    }

    // All auto again, scrolling on hover at the usual pace.
    function resetWidths() {
        adapter.widths = ({});
        adapter.overflow = "hover";
        adapter.scrollSpeed = "normal";
    }

    // ── Settings file ────────────────────────────────────────────────────────
    // Our own writes come back as file changes; one read straight after a
    // write would undo a colour that was dragged on meanwhile, so those
    // are let pass.
    property double _quietUntil: 0

    Timer {
        id: writeTimer
        interval: 150
        onTriggered: {
            root._quietUntil = Date.now() + 600;
            settingsFile.writeAdapter();
        }
    }

    FileView {
        id: settingsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/barsettings.json"
        // Read before the bar's first frame, so it never shows the default
        // look first.
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: {
            if (Date.now() > root._quietUntil)
                reload();
        }
        onAdapterUpdated: writeTimer.restart()

        adapter: JsonAdapter {
            id: adapter
            property var hidden: []
            property string colorMode: "wallpaper"
            property string tone: "default"
            property string customColor: ""
            property string textMode: "wallpaper"
            property string textTone: "auto"
            property string customText: ""
            property real transparency: 0
            property bool outline: false
            property var widths: ({})
            property string overflow: "hover"
            property string scrollSpeed: "normal"
        }
    }
}
