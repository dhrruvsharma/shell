pragma Singleton
import Quickshell
import QtQuick

// Shared state that tethers the calendar popup to the clock pill in the bar.
// Both the pill (services consumer) and the CalendarWindow live in the same
// process, so they talk through this singleton instead of an IPC round-trip.
Singleton {
    id: root

    property bool open: false

    // Where the pill that owns the popup lies along the bar (screen x on a
    // lying bar, y on a standing one) and its length, reported by the Clock
    // when it is clicked. The window aligns itself to this so the popup
    // reads as coming straight out of the pill.
    property real anchorPos: 240
    property real anchorLength: 0

    function openAt(pos, length) {
        anchorPos = pos
        anchorLength = length
        open = true
    }

    function toggleAt(pos, length) {
        if (open) {
            open = false
        } else {
            openAt(pos, length)
        }
    }

    function close() {
        open = false
    }
}
