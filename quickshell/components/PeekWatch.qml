import QtQuick
import qs.services as Services

// Put inside a panel that can open on hover (services/Opening, set in the
// customizer): it tells Opening while the pointer is over the panel, and
// when the panel is clicked into, so a peek stays while it's in use. It
// fills its parent and lets every press through to what's under it.
MouseArea {
    id: watch

    // The panel's Opening target ("system", "network", "notes"…).
    property string target: ""

    anchors.fill: parent
    z: 1000

    onPressed: mouse => {
        Services.Opening.panelPressed(watch.target);
        mouse.accepted = false;
    }

    HoverHandler {
        onHoveredChanged: Services.Opening.panelHovered(watch.target, hovered)
    }
}
