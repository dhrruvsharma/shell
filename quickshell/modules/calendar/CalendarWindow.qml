import QtQuick
import Quickshell
import qs.components
import qs.services as Services
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: calendarWindow

    // Stay mapped while the close animation plays out, then unmap.
    visible: Services.CalendarState.open || wrapper.opacity > 0.001
    color: "transparent"

    // Keyboard focus (for the notes field) only once the surface is up.
    // Hyprland hands the pointer to a layer surface that maps with keyboard
    // interactivity, wherever the cursor is, so the clock pill missed the
    // next click (closing the calendar) until the mouse moved. Turning it on
    // after mapping grabs nothing; clicking into the calendar then focuses it.
    property bool keyboardReady: false
    WlrLayershell.keyboardFocus: keyboardReady ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Timer {
        id: keyboardDelay
        interval: 150
        onTriggered: calendarWindow.keyboardReady = Services.CalendarState.open
    }

    anchors.top: true
    anchors.left: true
    // Drop straight out of the clock pill: center the card under the pill and
    // sit snug under the bar so the popup reads as an extension of it. Clamped
    // so a pill near the screen edge can't push the card off-screen.
    margins.top: 38
    margins.left: Math.max(8, Math.round(
        Services.CalendarState.anchorX
        + Services.CalendarState.anchorWidth / 2
        - implicitWidth / 2))

    // Fixed surface size — large enough for the calendar plus a fully expanded
    // notes panel. The layer-shell surface must NOT resize per-frame on Wayland
    // (doing so leaves the newly exposed area unpainted), so we keep it constant
    // and let the calendar grow/shrink inside it.
    implicitWidth: 360
    implicitHeight: Math.min(screen.height, 760)

    // Only the visible calendar/notes content is interactive; everything else in
    // the (transparent) surface stays click-through.
    mask: Region { item: cal }

    // Start fresh (current month, today, notes closed) each time it opens.
    Connections {
        target: Services.CalendarState
        function onOpenChanged() {
            if (Services.CalendarState.open) {
                cal.resetView()
                keyboardDelay.restart()
            } else {
                calendarWindow.keyboardReady = false
            }
        }
    }

    // Wrapper drives the open/close animation. It unfurls from its top edge so
    // the card appears to grow down out of the pill above it.
    Item {
        id: wrapper
        anchors.fill: parent
        transformOrigin: Item.Top

        opacity: Services.CalendarState.open ? 1 : 0
        scale: Services.CalendarState.open ? 1 : 0.94
        y: Services.CalendarState.open ? 0 : -8

        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        Calendar {
            id: cal
            anchors.top: parent.top
            anchors.left: parent.left
        }
    }

    IpcHandler {
        target: "calendarWindow"
        function toggle(): void {
            Services.CalendarState.open = !Services.CalendarState.open
        }
    }
}
