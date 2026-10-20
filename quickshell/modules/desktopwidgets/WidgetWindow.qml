pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services as Services

// One desktop widget in its own small surface on the Bottom layer (above the
// wallpaper, below windows). Small on purpose: a repaint of a Bottom-layer
// surface makes Hyprland recomposite what is above it, so a clock ticking or
// a progress bar moving only costs its own rectangle.
//
// Drag it anywhere on the widget that isn't a button. While held, the surface
// grows to the whole screen, so the widget moves inside it with plain Qt
// dragging instead of waiting on the compositor for every step; on release
// it shrinks back to the widget at its new place.
//
// The new anchors and margins reach the compositor with the next frame, and
// that frame's buffer still has the old size, so `body` has to be placed for
// the new surface already: on release it goes back to 0,0 in that same frame
// (going by `full` there drew it at twice its offset for a frame or two,
// as if flying in from elsewhere). On press the small buffer briefly sits
// at the screen's corner, so the widget is hidden until the surface covers
// the screen.
PanelWindow {
    id: win

    required property string widgetId
    property Component widget

    property bool held: false
    property bool moved: false
    property real dragX: 0
    property real dragY: 0

    readonly property var frac: Services.DesktopWidgets.pos(widgetId)
    readonly property real sw: screen ? screen.width : 1920
    readonly property real sh: screen ? screen.height : 1080
    readonly property real bw: Math.max(1, Math.ceil(loader.implicitWidth))
    readonly property real bh: Math.max(1, Math.ceil(loader.implicitHeight))
    // Kept clear of the bar, on whichever edge it is.
    readonly property real minX: Services.BarLayout.reserveLeft
    readonly property real maxX: sw - Services.BarLayout.reserveRight - bw
    readonly property real minY: Services.BarLayout.reserveTop
    readonly property real maxY: sh - Services.BarLayout.reserveBottom - bh
    readonly property real restX: Math.round(Math.max(minX, Math.min(maxX, frac.x * Math.max(0, sw - bw))))
    readonly property real restY: Math.round(Math.max(minY, Math.min(maxY, frac.y * Math.max(0, sh - bh))))
    readonly property bool full: width >= sw - 1 && height >= sh - 1

    screen: Quickshell.screens[0] ?? null
    // Mapped once the widget is built at its own size (the loader only runs
    // while the widget is on, so a switched-off one costs nothing).
    visible: loader.item !== null
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell:widget"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors.left: true
    anchors.top: true
    anchors.right: held
    anchors.bottom: held
    margins.left: held ? 0 : restX
    margins.top: held ? 0 : restY
    implicitWidth: bw
    implicitHeight: bh

    mask: Region { item: body }

    Item {
        id: body

        x: win.held && win.full ? win.dragX : 0
        y: win.held && win.full ? win.dragY : 0
        width: win.bw
        height: win.bh
        opacity: win.held && !win.full ? 0 : 1

        MouseArea {
            id: grab

            property real pressX: 0
            property real pressY: 0

            anchors.fill: parent
            cursorShape: win.held && win.moved ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            onPressed: mouse => {
                win.dragX = win.restX;
                win.dragY = win.restY;
                win.moved = false;
                pressX = mouse.x;
                pressY = mouse.y;
                win.held = true;
            }
            onPositionChanged: mouse => {
                if (!win.full)
                    return;
                if (!win.moved && Math.hypot(mouse.x - pressX, mouse.y - pressY) < 4)
                    return;
                win.moved = true;
                win.dragX = Math.max(win.minX, Math.min(win.maxX, win.dragX + mouse.x - pressX));
                win.dragY = Math.max(win.minY, Math.min(win.maxY, win.dragY + mouse.y - pressY));
            }
            onReleased: win.drop()
            onCanceled: win.drop()
        }

        Loader {
            id: loader
            active: Services.DesktopWidgets.enabled(win.widgetId)
            sourceComponent: win.widget
        }
    }

    function drop() {
        if (moved)
            Services.DesktopWidgets.setPos(widgetId, dragX / Math.max(1, sw - bw), dragY / Math.max(1, sh - bh));
        held = false;
        moved = false;
    }
}
