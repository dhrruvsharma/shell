import QtQuick
import qs.components
import qs.colors
import qs.services as Services
import qs.Core

// Bar atom: a gear that opens the bar's settings (modules/barsettings),
// lit while they're open. It can be hidden there; SUPER+B opens them
// either way.
BarPill {
    id: pill

    readonly property bool active: Services.BarSettings.panelOpen

    text: Icons.settings
    horizontalPadding: 18
    interactive: true
    cursorShape: Qt.PointingHandCursor

    color: pill.active ? Colors.primary_container : Services.BarSettings.pill
    textColor: pill.active ? Colors.on_primary_container : Services.BarSettings.ink

    Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on textColor { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

    onClicked: Services.BarSettings.togglePanel()
}
