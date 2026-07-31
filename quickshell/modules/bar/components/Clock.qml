import QtQuick
import "../../../colors" as ColorsModule
import qs.services as Services

Rectangle {
    id: pill
    radius: 13
    implicitHeight: 28
    implicitWidth: clock.implicitWidth + 16

    readonly property bool active: Services.CalendarState.open

    // Blend toward primary_container while the calendar is open so the pill and
    // its popup read as one connected surface.
    color: active ? ColorsModule.Colors.primary_container
                  : ColorsModule.Colors.surface_container
    Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            // Resolve the pill's on-screen x so the popup can center under it.
            const global = pill.mapToGlobal(0, 0)
            const px = (global && !isNaN(global.x)) ? global.x : pill.x
            Services.CalendarState.toggleAt(px, pill.width)
        }
    }

    Text {
        id: clock
        anchors.centerIn: parent
        font.pixelSize: 17

        text: Services.Time.format("d MMM • hh:mm AP")
        color: pill.active ? ColorsModule.Colors.on_primary_container
                           : ColorsModule.Colors.on_surface
        Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }
}
