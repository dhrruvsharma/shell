pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Hyprland
import qs.colors
import qs.services as Svc
import qs.components
import "Projection.js" as Proj

// Under each card in the overview: its workspace and what's open on it,
// following the card round the strip.
Item {
    id: lbl

    required property var surface
    required property int slot
    required property var params

    readonly property int n: Math.max(1, lbl.surface.ring.length)
    readonly property int ws: lbl.surface.ring[lbl.slot] ?? 0
    // The card's place on the strip nearest the camera.
    readonly property real idx: Proj.nearest(lbl.slot, lbl.surface.pos, lbl.n)
    readonly property var at: Proj.project(lbl.params, lbl.idx * lbl.params.pitch, lbl.params.cardH / 2 + 40)
    readonly property bool lit: Math.round(lbl.surface.litIdx) === lbl.idx
    readonly property var hws: lbl.surface._wsOf(lbl.ws)
    readonly property bool here: lbl.ws === lbl.surface.activeId()

    readonly property string title: {
        if (!lbl.hws)
            return "+";
        const name = String(lbl.hws.name ?? "");
        return name && name !== String(lbl.ws) ? name : String(lbl.ws);
    }

    readonly property string apps: {
        if (!lbl.hws)
            return "a new workspace";
        const names = [];
        for (const t of Hyprland.toplevels.values) {
            if (!t || !t.workspace || t.workspace.id !== lbl.ws)
                continue;
            let a = t.wayland && t.wayland.appId ? String(t.wayland.appId) : String(t.lastIpcObject?.class ?? "");
            a = a.split(".").pop().toLowerCase();
            if (a && !names.includes(a))
                names.push(a);
        }
        if (names.length === 0)
            return "empty";
        return names.slice(0, 3).join(" · ") + (names.length > 3 ? "  +" + (names.length - 3) : "");
    }

    visible: lbl.at !== null && Math.abs(lbl.idx - lbl.surface.pos) <= lbl.n / 2
    x: lbl.at ? lbl.at.x - lbl.width / 2 : 0
    y: lbl.at ? lbl.at.y : 0
    width: col.implicitWidth
    height: col.implicitHeight
    // a little smaller round the sides, but readable
    scale: lbl.at ? Math.max(0.75, Math.min(1.1, 0.5 + lbl.at.scale)) : 1
    transformOrigin: Item.Top
    opacity: Math.max(0, 1 - Math.abs(lbl.idx - lbl.surface.pos) * 0.4)

    Column {
        id: col
        spacing: 1

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: lbl.title
            font.pixelSize: 34
            font.weight: Font.DemiBold
            color: lbl.lit ? Svc.DesktopTheme.accent : Colors.on_surface
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: lbl.here ? lbl.apps + "  ·  here" : lbl.apps
            font.pixelSize: 15
            color: Colors.withAlpha(Colors.on_surface, 0.7)
        }
    }
}
