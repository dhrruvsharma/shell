import QtQuick
import qs.components
import qs.colors
import qs.services as Services

BarPill {
    id: pill

    readonly property bool active: Services.CalendarState.open

    text: Services.Time.format("d MMM • hh:mm AP")
    interactive: true
    cursorShape: Qt.PointingHandCursor

    // Blend toward primary_container while the calendar is open so the pill and
    // its popup read as one connected surface.
    color: pill.active ? Colors.primary_container : Colors.surface_container
    textColor: pill.active ? Colors.on_primary_container : Colors.on_surface

    Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on textColor { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

    onClicked: {
        // Resolve the pill's on-screen x so the popup can center under it.
        const global = pill.mapToGlobal(0, 0)
        const px = (global && !isNaN(global.x)) ? global.x : pill.x
        Services.CalendarState.toggleAt(px, pill.width)
    }
}
