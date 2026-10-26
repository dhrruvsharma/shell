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

    // The card comes out of the clock pill, away from the bar's edge: down
    // from a top bar, up from a bottom one, sideways from a standing one.
    readonly property string edge: Services.BarLayout.edge
    readonly property bool vertical: Services.BarLayout.vertical
    // Its distance from the bar (the surface stops at the bar's exclusive
    // zone).
    readonly property int gap: 38
    // The pill's middle along the bar.
    readonly property real centre: Services.CalendarState.anchorPos + Services.CalendarState.anchorLength / 2
    readonly property real screenW: screen ? screen.width : 1920
    readonly property real screenH: screen ? screen.height : 1200

    // Respects the bar's exclusive zone but reserves none of its own: beside
    // a standing bar it spans three edges, where Quickshell's automatic zone
    // would push the open windows aside.
    exclusiveZone: 0

    anchors.top: edge !== "bottom"
    anchors.bottom: edge !== "top"
    anchors.left: edge !== "right"
    anchors.right: edge === "right"
    // Centred on the pill along the bar, clamped so a pill near either end
    // can't push the card off-screen. A standing bar's surface runs the
    // screen's height and the card is placed inside it (cardY).
    margins.top: edge === "top" ? gap : 0
    margins.bottom: edge === "bottom" ? gap : 0
    margins.left: edge === "left" ? gap
        : vertical ? 0
        : Math.max(8, Math.min(screenW - implicitWidth - 8, Math.round(centre - implicitWidth / 2)))
    margins.right: edge === "right" ? gap : 0

    // Fixed surface size — large enough for the calendar plus a fully expanded
    // notes panel. The layer-shell surface must NOT resize per-frame on Wayland
    // (doing so leaves the newly exposed area unpainted), so we keep it constant
    // and let the calendar grow/shrink inside it.
    implicitWidth: 360
    implicitHeight: Math.min(screenH, 760)

    // Beside a standing bar: the card's top, centred on the pill and kept on
    // screen with its notes open.
    readonly property real cardY: Math.max(8, Math.min(height - cal.height - 8, Math.round(centre - cal.cardHeight / 2)))

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

    // Wrapper drives the open/close animation. It unfurls from the side
    // facing the bar so the card appears to grow out of the pill. On a
    // standing bar it covers just the card's stretch of the surface.
    Item {
        id: wrapper
        y: calendarWindow.vertical ? calendarWindow.cardY : 0
        width: parent.width
        height: calendarWindow.vertical ? cal.height : parent.height
        transformOrigin: ({ top: Item.Top, bottom: Item.Bottom, left: Item.Left, right: Item.Right })[calendarWindow.edge]

        opacity: Services.CalendarState.open ? 1 : 0
        scale: Services.CalendarState.open ? 1 : 0.94
        // Slides in from the bar.
        property real slide: Services.CalendarState.open ? 0 : 8
        transform: Translate {
            x: calendarWindow.edge === "left" ? -wrapper.slide : calendarWindow.edge === "right" ? wrapper.slide : 0
            y: calendarWindow.edge === "top" ? -wrapper.slide : calendarWindow.edge === "bottom" ? wrapper.slide : 0
        }

        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on slide { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        // Against the side facing the bar (by y: anchors swapped by a binding
        // would pass through top-and-bottom and fix its height).
        Calendar {
            id: cal
            y: calendarWindow.edge === "bottom" ? parent.height - height : 0
        }

        // A peek (opened on hover) stays while it's in use.
        PeekWatch {
            x: cal.x
            y: cal.y
            width: cal.width
            height: cal.height
            anchors.fill: undefined
            area: cal
            target: "calendar"
        }
    }

    IpcHandler {
        target: "calendarWindow"
        function toggle(): void {
            Services.CalendarState.open = !Services.CalendarState.open
        }
    }
}
