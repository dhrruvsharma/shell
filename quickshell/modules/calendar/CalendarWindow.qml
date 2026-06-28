import QtQuick
import Quickshell
import qs.components
import Quickshell.Io

PanelWindow {
    id: calendarWindow

    visible: false
    color: "transparent"
    focusable: true

    anchors.top: true
    anchors.left: true
    margins.top: 0
    margins.left: 240

    // Fixed surface size — large enough for the calendar plus a fully expanded
    // notes panel. The layer-shell surface must NOT resize per-frame on Wayland
    // (doing so leaves the newly exposed area unpainted), so we keep it constant
    // and let the calendar grow/shrink inside it.
    implicitWidth: 360
    implicitHeight: Math.min(screen.height, 760)

    // Only the visible calendar/notes content is interactive; everything else in
    // the (transparent) surface stays click-through.
    mask: Region { item: cal }

    // Start fresh (current month, today, notes closed) each time it opens
    onVisibleChanged: if (visible) cal.resetView()

    Calendar {
        id: cal
        anchors.top: parent.top
        anchors.left: parent.left
    }

    IpcHandler {
        target: "calendarWindow"
        function toggle(): void {
            calendarWindow.visible = !calendarWindow.visible
        }

    }

}
