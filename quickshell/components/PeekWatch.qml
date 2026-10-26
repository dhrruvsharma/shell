import QtQuick
import qs.services as Services

// Put inside a panel that can open on hover (services/Opening, set in the
// customizer): it tells Opening while the pointer is over the panel, and
// when the panel is clicked into, so a peek stays while it's in use. It
// fills its parent and lets every press through to what's under it.
//
// The hover is watched on the panel itself (`area`), not from up here: a
// HoverHandler on an item stacked over the panel's contents takes the hover
// from everything under it (Qt 6 hands hover to the topmost hovered item and
// its ancestors only, blocking or not), so no button in the panel would
// light up. A MouseArea without hoverEnabled doesn't, so presses are
// watched from up here.
Item {
    id: watch

    // The panel's Opening target ("system", "network", "notes"…).
    property string target: ""
    // What counts as over the panel: an item holding the panel's contents.
    property Item area: parent

    anchors.fill: parent
    z: 1000

    MouseArea {
        anchors.fill: parent
        onPressed: mouse => {
            Services.Opening.panelPressed(watch.target);
            mouse.accepted = false;
        }
    }

    HoverHandler {
        parent: watch.area
        onHoveredChanged: Services.Opening.panelHovered(watch.target, hovered)
    }
}
