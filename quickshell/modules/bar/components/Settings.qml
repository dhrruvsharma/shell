import QtQuick
import qs.components
import qs.colors
import qs.services as Services
import qs.Core

// Bar atom: a gear that opens the customizer's book at its chapter on the
// bar (modules/customizer), lit while the book is open. It can be hidden
// there; SUPER+B opens it either way.
BarPill {
    id: pill

    readonly property bool active: Services.Customizer.open

    text: Icons.settings
    horizontalPadding: 18
    interactive: true
    cursorShape: Qt.PointingHandCursor

    color: pill.active ? Colors.primary_container : Services.BarSettings.pill
    textColor: pill.active ? Colors.on_primary_container : Services.BarSettings.ink

    Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on textColor { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

    onClicked: Services.Customizer.request("bar")
}
