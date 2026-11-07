pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services as Services

// The edge line's surface (what it shows and does is EdgeLineView).
//
// Small at rest: a box round the line, which the pill fits in. It covers
// the screen while the line is open, opening, folding or held, and its mask
// is only what shows (the line's grip; the popout), or nothing
// while it's held: it grows before its next frame brings a mask for the new
// size, and a press outside a stale mask would be lost.
//
// The view is laid out in screen coordinates and sits at the screen's
// origin: moved back by the box's place while the surface is the box, so
// nothing moves on the screen when the surface changes size. The new size
// reaches the compositor with the next frame, which still has the old
// buffer, so the view goes by the size asked for, not the size there is:
// growing, that one small frame shows the screen's corner (where there's
// nothing) and the line blinks for a frame; shrinking, the line is already
// where it belongs.
PanelWindow {
    id: win

    // A panel of the shell's is up over this part of the screen: the line
    // drops beneath it (as the bar does) unless it's open.
    property bool covered: false

    readonly property bool full: win.width >= view.sw - 1 && win.height >= view.sh - 1
    // (for test hooks)
    readonly property Item lineView: view
    readonly property bool big: view.big
    readonly property string edge: view.edge

    WlrLayershell.namespace: "quickshell:edgeline"
    WlrLayershell.layer: win.covered && !win.big ? WlrLayer.Bottom : WlrLayer.Top
    // Typing (notes, a Wi-Fi password) once it's up: turned on after it has
    // opened, which grabs nothing; a click in it then gives it the keyboard.
    WlrLayershell.keyboardFocus: view.keyboardReady ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: win.big || win.edge !== "bottom"
        bottom: win.big || win.edge === "bottom"
        left: win.big || win.edge !== "right"
        right: win.big || win.edge === "right"
    }
    margins.top: win.big ? 0 : win.edge === "top" ? view.inset : view.horizontal ? 0 : view.boxStart
    margins.bottom: win.big ? 0 : win.edge === "bottom" ? view.inset : 0
    margins.left: win.big ? 0 : win.edge === "left" ? view.inset : view.horizontal ? view.boxStart : 0
    margins.right: win.big ? 0 : win.edge === "right" ? view.inset : 0
    implicitWidth: view.horizontal ? view.boxAlong : view.boxOut
    implicitHeight: view.horizontal ? view.boxOut : view.boxAlong

    mask: view.held ? null : view.panelUp ? openMask : restMask

    Region {
        id: restMask
        x: view.gripRect.x - view.box.x
        y: view.gripRect.y - view.box.y
        width: view.gripRect.width
        height: view.gripRect.height
    }

    // (Given by the popout's place, not by its item: a Region follows an
    // item's own geometry only, and the popout slides in with the sheet
    // it's on, so the region taken as it opened was left out past the
    // border, and the pointer over the popout wasn't on the surface.)
    Region {
        id: openMask
        x: view.frameRect.x
        y: view.frameRect.y
        width: view.panelUp ? view.frameRect.width : 0
        height: view.panelUp ? view.frameRect.height : 0
    }

    EdgeLineView {
        id: view
        sw: win.screen ? win.screen.width : 1920
        sh: win.screen ? win.screen.height : 1200
        full: win.full
        covered: win.covered
        x: view.big ? 0 : -view.box.x
        y: view.big ? 0 : -view.box.y
        width: view.sw
        height: view.sh
    }
}
