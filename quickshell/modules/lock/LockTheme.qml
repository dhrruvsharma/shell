pragma Singleton
import QtQuick
import Quickshell
import qs.colors

// Palette and type for the lock screen HUD. The HUD always sits on a darkened
// backdrop, so on a light matugen scheme the ink/base roles flip to their
// inverse and the accents use the *_fixed_dim tones, which are the same in
// light and dark schemes.
Singleton {
    id: root

    readonly property string display: "Orbitron"
    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property string icons: "Material Symbols Rounded"

    readonly property bool dark: Qt.color(Colors.background).hslLightness < 0.5

    readonly property color base: dark ? Colors.background : Colors.inverse_surface
    readonly property color ink: dark ? Colors.on_surface : Colors.inverse_on_surface
    readonly property color inkDim: Colors.withAlpha(ink, 0.62)
    readonly property color inkFaint: Colors.withAlpha(ink, 0.32)
    readonly property color accent: Colors.primary_fixed_dim
    readonly property color accentSoft: Colors.withAlpha(accent, 0.18)
    readonly property color gold: Colors.tertiary_fixed_dim
    readonly property color danger: dark ? Colors.error : "#ffb4ab"
    readonly property color panel: Colors.withAlpha(base, 0.58)
    readonly property color panelHi: Colors.withAlpha(base, 0.78)
    readonly property color line: Colors.withAlpha(ink, 0.14)

    function alpha(c, a) {
        return Colors.withAlpha(c, a);
    }

    // Eased 0..1 slice of a 0..1 timeline: how far an element whose entrance
    // runs from `from` to `to` has got when the whole choreography is at `p`.
    function seg(p, from, to) {
        const x = Math.max(0, Math.min(1, (p - from) / (to - from)));
        return 1 - Math.pow(1 - x, 3);
    }
}
