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
// it shrinks back to the widget at its new place. `body` only switches to
// screen coordinates once the surface really is full screen (and back), so
// nothing jumps while the compositor catches up.
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
    readonly property real restX: Math.round(frac.x * Math.max(0, sw - bw))
    readonly property real restY: Math.round(frac.y * Math.max(0, sh - bh))
    readonly property bool full: width >= sw - 1 && height >= sh - 1

    screen: Quickshell.screens[0] ?? null
    visible: Services.DesktopWidgets.enabled(widgetId)
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

        x: win.full ? (win.held ? win.dragX : win.restX) : 0
        y: win.full ? (win.held ? win.dragY : win.restY) : 0
        width: win.bw
        height: win.bh

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
                win.dragX = Math.max(0, Math.min(win.sw - win.bw, win.dragX + mouse.x - pressX));
                win.dragY = Math.max(0, Math.min(win.sh - win.bh, win.dragY + mouse.y - pressY));
            }
            onReleased: win.drop()
            onCanceled: win.drop()
        }

        Loader {
            id: loader
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
