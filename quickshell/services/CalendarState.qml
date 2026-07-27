pragma Singleton
import Quickshell
import QtQuick

// Shared state that tethers the calendar popup to the clock pill in the bar.
// Both the pill (services consumer) and the CalendarWindow live in the same
// process, so they talk through this singleton instead of an IPC round-trip.
Singleton {
    id: root

    property bool open: false

    // Screen-space geometry of the pill that owns the popup, reported by the
    // Clock when it is clicked. The window aligns itself to this so the popup
    // reads as dropping straight out of the pill.
    property real anchorX: 240
    property real anchorWidth: 0

    function openAt(x, w) {
        anchorX = x
        anchorWidth = w
        open = true
    }

    function toggleAt(x, w) {
        if (open) {
            open = false
        } else {
            openAt(x, w)
        }
    }

    function close() {
        open = false
    }
}
