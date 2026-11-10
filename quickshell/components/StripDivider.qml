import QtQuick
import qs.colors
import qs.services as Services

// The mark between two islands on the bar as one strip (StripBand): a
// short rule across the bar, or the desktop theme's own: a slash for HUD
// and Neon Noir, a lozenge for Art Deco, Cathedral, Devaloka, Sekiro and
// Xianxia, a rivet for Wasteland, a dot for Abyss, Wabi-sabi, Still and
// Astral, a merlon for Siege. In the theme's hairline colour, or a faint
// one of the text's. It's a point: what it draws is centred on where it's
// put.
Item {
    id: mark

    // On a standing bar the rule lies across it the other way.
    property bool vertical: false

    readonly property var look: Services.DesktopTheme.look
    readonly property string kind: ({
            chamfer: "slash",
            neon: "slash",
            deco: "lozenge",
            cusp: "lozenge",
            zari: "lozenge",
            posture: "lozenge",
            seal: "lozenge",
            plate: "rivet",
            lume: "dot",
            pebble: "dot",
            soft: "dot",
            pill: "dot",
            crenel: "merlon"
        })[mark.look.shape] ?? "rule"
    readonly property color color: mark.look.shape === "chamfer" ? Colors.withAlpha(Services.DesktopTheme.accent, 0.75)
        : mark.look.border ? Services.DesktopTheme.borderColor(mark.look) : Services.BarSettings.divider
    // Its length across the bar, and its weight.
    readonly property real length: mark.kind === "rule" || mark.kind === "slash" ? 16
        : mark.kind === "lozenge" ? 5 : mark.kind === "merlon" ? 4 : 3
    readonly property real weight: mark.kind === "slash" ? 1.5 : mark.kind === "rule" ? 1 : mark.length

    width: 0
    height: 0

    Rectangle {
        visible: mark.kind !== "rivet"
        x: -width / 2
        y: -height / 2
        width: mark.vertical ? mark.length : mark.weight
        height: mark.vertical ? mark.weight : mark.length
        radius: mark.kind === "dot" ? width / 2 : 0
        rotation: mark.kind === "lozenge" ? 45 : mark.kind === "slash" ? 22 : 0
        antialiasing: mark.kind === "lozenge" || mark.kind === "slash"
        color: mark.color
    }

    Rivet {
        visible: mark.kind === "rivet"
        size: 5
        x: -width / 2
        y: -height / 2
    }
}
