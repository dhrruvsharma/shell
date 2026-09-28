pragma Singleton
import QtQuick
import Quickshell
import qs.services as Services

// Palette, type and street lore for the Neon Noir desktop theme and its
// "Black ICE" lock screen. The two neons are the wallpaper's accents toned
// by the theme (services/DesktopTheme.qml accentOf/accent2Of): full
// saturation, and always a duotone.
Singleton {
    id: root

    // Numbers and big type; `logo` (katakana-shaped Latin) only for words.
    readonly property string display: "KogniGear"
    readonly property string logo: "Electroharmonix"
    readonly property string ui: "Fragile Bombers"
    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property string kana: "Noto Sans CJK JP"

    readonly property color a: Services.DesktopTheme.accentOf("cyberpunk")
    readonly property color b: Services.DesktopTheme.accent2Of("cyberpunk")
    // The night everything glows in: near black, with a breath of neon.
    readonly property color night: Qt.tint("#05060a", alpha(b, 0.05))
    readonly property color ink: "#e8ecf6"
    readonly property color inkDim: "#8d93a8"
    readonly property color danger: "#ff2e63"
    readonly property color hazard: "#f7e018"

    function alpha(c, x) {
        return Qt.rgba(c.r, c.g, c.b, x);
    }

    readonly property var weekdays: ["日曜日", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日"]

    // The city's clock.
    function shift(d) {
        const h = d.getHours();
        return h < 5 ? "DEAD HOURS" : h < 9 ? "MORNING SHIFT" : h < 17 ? "DAY CYCLE" : h < 21 ? "PRIME TIME" : "NIGHT SHIFT";
    }

    // Breach buffer codes. Chosen by position and a per-lock seed only, so
    // they never say anything about what was typed.
    readonly property var codes: ["1C", "55", "BD", "E9", "7A", "FF"]

    function code(i, seed) {
        const h = Math.sin((i + 1) * 12.9898 + seed * 78.233) * 43758.5453;
        return codes[Math.floor((h - Math.floor(h)) * codes.length)];
    }
}
