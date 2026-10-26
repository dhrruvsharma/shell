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
    cursorShape: Qt.PointingHandCursor
    // The calendar hangs from where the pill sits along the bar.
    opens: "calendar"
    opensArg: () => ({ pos: Services.BarLayout.along(pill, 0, 0), length: pill.vertical ? pill.height : pill.width })

    // Blend toward primary_container while the calendar is open so the pill and
    // its popup read as one connected surface.
    color: pill.active ? Colors.primary_container : Services.BarSettings.pill
    textColor: pill.active ? Colors.on_primary_container : Services.BarSettings.ink

    Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on textColor { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
}
