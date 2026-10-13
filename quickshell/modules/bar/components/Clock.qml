import QtQuick
import qs.components
import qs.colors
import qs.services as Services

BarPill {
    id: pill

    readonly property bool active: Services.CalendarState.open

    text: Services.Time.format("d MMM • hh:mm AP")
    // Upright, on a standing bar: the hour over the minutes (12-hour, like
    // the full face; "hh" alone would count to 23).
    vIcon: Services.Time.format("hh AP").split(" ")[0]
    vLabel: Services.Time.format("mm")
    vIconSize: 14
    vLabelSize: 14
    interactive: true
    cursorShape: Qt.PointingHandCursor

    // Blend toward primary_container while the calendar is open so the pill and
    // its popup read as one connected surface.
    color: pill.active ? Colors.primary_container : Colors.surface_container
    textColor: pill.active ? Colors.on_primary_container : Colors.on_surface

    Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on textColor { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

    onClicked: {
        // Where the pill sits along the bar, so the popup can hang from it.
        Services.CalendarState.toggleAt(Services.BarLayout.along(pill, 0, 0), pill.vertical ? pill.height : pill.width)
    }
}
