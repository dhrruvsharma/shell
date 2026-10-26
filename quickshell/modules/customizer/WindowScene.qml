pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.colors
import qs.services as Services

// The desktop as Hyprland would lay it out with the window settings in
// force (services/WindowLook): the wallpaper, the bar's room, and three
// tiled windows (one tall on the left, focused, two stacked on the right),
// their gaps, borders and corners (rounded to `rounding_power`, a circle
// at 2, a squircle at 4) drawn at `zoom` screen pixels per pixel from
// `origin` (a screen point at the top-left), so the same scene serves the
// whole screen and a magnified detail.
Item {
    id: scene

    property real zoom: 0.3
    property point origin: Qt.point(0, 0)
    // The key on the facing page, to light the part it sets.
    property string lit: ""

    readonly property real sw: 1920
    readonly property real sh: 1200
    readonly property var wl: Services.WindowLook
    readonly property real gapsIn: Number(scene.wl.value("general.gaps_in") ?? 5)
    readonly property real gapsOut: Number(scene.wl.value("general.gaps_out") ?? 20)
    readonly property real border: Number(scene.wl.value("general.border_size") ?? 2)
    readonly property real rounding: Number(scene.wl.value("decoration.rounding") ?? 10)
    readonly property real power: Number(scene.wl.value("decoration.rounding_power") ?? 2)
    readonly property real activeOpacity: Number(scene.wl.value("decoration.active_opacity") ?? 1)
    readonly property real inactiveOpacity: Number(scene.wl.value("decoration.inactive_opacity") ?? 1)

    // The windows, in screen pixels.
    readonly property real x0: Services.BarLayout.reserveLeft + scene.gapsOut
    readonly property real y0: Services.BarLayout.reserveTop + scene.gapsOut
    readonly property real x1: scene.sw - Services.BarLayout.reserveRight - scene.gapsOut
    readonly property real y1: scene.sh - Services.BarLayout.reserveBottom - scene.gapsOut
    readonly property real split: scene.x0 + (scene.x1 - scene.x0) * 0.56
    readonly property real midY: scene.y0 + (scene.y1 - scene.y0) * 0.5
    readonly property var windows: [
        { x: scene.x0, y: scene.y0, w: scene.split - scene.gapsIn - scene.x0, h: scene.y1 - scene.y0, focused: true },
        { x: scene.split + scene.gapsIn, y: scene.y0, w: scene.x1 - scene.split - scene.gapsIn, h: scene.midY - scene.gapsIn - scene.y0, focused: false },
        { x: scene.split + scene.gapsIn, y: scene.midY + scene.gapsIn, w: scene.x1 - scene.split - scene.gapsIn, h: scene.y1 - scene.midY - scene.gapsIn, focused: false }
    ]

    function px(v) {
        return v * scene.zoom;
    }

    function sx(v) {
        return (v - scene.origin.x) * scene.zoom;
    }

    function sy(v) {
        return (v - scene.origin.y) * scene.zoom;
    }

    // A rounded rectangle's outline, its corners superellipses of `n`.
    function outline(x, y, w, h, r, n) {
        const pts = [];
        const rr = Math.max(0, Math.min(r, w / 2, h / 2));
        const steps = rr * scene.zoom > 6 ? 10 : 4;
        const corner = (cx, cy, a0) => {
            for (let i = 0; i <= steps; i++) {
                const a = a0 + (Math.PI / 2) * i / steps;
                const c = Math.cos(a), s = Math.sin(a);
                const ex = Math.sign(c) * Math.pow(Math.abs(c), 2 / n);
                const ey = Math.sign(s) * Math.pow(Math.abs(s), 2 / n);
                pts.push(Qt.point(cx + ex * rr, cy + ey * rr));
            }
        };
        corner(x + w - rr, y + rr, -Math.PI / 2);
        corner(x + w - rr, y + h - rr, 0);
        corner(x + rr, y + h - rr, Math.PI / 2);
        corner(x + rr, y + rr, Math.PI);
        pts.push(pts[0]);
        return pts;
    }

    clip: true

    // The wallpaper at the scene's scale.
    Image {
        x: scene.sx(0)
        y: scene.sy(0)
        width: scene.px(scene.sw)
        height: scene.px(scene.sh)
        source: "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
        sourceSize: Qt.size(Math.min(1920, Math.max(480, width)), Math.min(1200, Math.max(300, height)))
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    // The bar's room.
    Rectangle {
        x: Services.BarLayout.atRight ? scene.sx(scene.sw - Services.BarLayout.reserveRight) : scene.sx(0)
        y: Services.BarLayout.atBottom ? scene.sy(scene.sh - Services.BarLayout.reserveBottom) : scene.sy(0)
        width: scene.px(Services.BarLayout.vertical ? Services.BarLayout.reserveLeft + Services.BarLayout.reserveRight : scene.sw)
        height: scene.px(Services.BarLayout.vertical ? scene.sh : Services.BarLayout.reserveTop + Services.BarLayout.reserveBottom)
        color: Colors.withAlpha(Colors.background, 0.9)
    }

    Repeater {
        model: scene.windows

        Item {
            id: win

            required property var modelData
            required property int index
            readonly property var w: win.modelData
            readonly property var path: scene.outline(scene.sx(win.w.x), scene.sy(win.w.y), scene.px(win.w.w), scene.px(win.w.h), scene.px(scene.rounding), Math.max(1, scene.power))

            anchors.fill: parent

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: Colors.withAlpha(Colors.surface_container_low, win.w.focused ? scene.activeOpacity : scene.inactiveOpacity)
                    strokeColor: win.w.focused ? Colors.primary : Colors.withAlpha(Colors.outline, 0.8)
                    strokeWidth: Math.max(scene.border > 0 ? 0.6 : 0, scene.px(scene.border))
                    joinStyle: ShapePath.RoundJoin

                    PathPolyline {
                        path: win.path
                    }
                }
            }

            // A little of what's in it: a title line and some text.
            Column {
                x: scene.sx(win.w.x) + scene.px(Math.max(scene.rounding, 18))
                y: scene.sy(win.w.y) + scene.px(Math.max(scene.rounding * 0.6, 16))
                spacing: scene.px(26)
                opacity: win.w.focused ? 0.6 : 0.35

                Repeater {
                    model: Math.max(0, Math.min(6, Math.floor((win.w.h - 60) / 60)))

                    Rectangle {
                        required property int index
                        width: scene.px(win.w.w - 2 * Math.max(scene.rounding, 18)) * (index === 0 ? 0.4 : 0.55 + 0.4 * ((index * 7 + win.index * 3) % 10) / 10)
                        height: Math.max(1, scene.px(index === 0 ? 16 : 10))
                        radius: height / 2
                        color: index === 0 ? Colors.primary : Colors.on_surface
                        opacity: index === 0 ? 0.8 : 0.35
                    }
                }
            }
        }
    }
}
