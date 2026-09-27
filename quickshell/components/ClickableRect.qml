import QtQuick
import qs.services as Services

// A Rectangle that knows whether the pointer is over it. Replaces the
// `Rectangle { ... MouseArea { id: ma; hoverEnabled: true } }` +
// `ma.containsMouse ? a : b` pairing that was written out ~96 times.
//
// The MouseArea is declared first so anything the call site adds renders above it,
// and a nested interactive child still wins the event.
Rectangle {
    id: root

    property alias hovered: mouse.containsMouse
    property alias pressed: mouse.containsPress
    property alias cursorShape: mouse.cursorShape
    property alias acceptedButtons: mouse.acceptedButtons
    property alias propagateComposedEvents: mouse.propagateComposedEvents
    // Set false for a hover-only surface that must let clicks through.
    property bool interactive: true

    signal clicked(var mouse)
    signal entered
    signal exited

    // A desktop theme squares these off (or, Astral, rounds them into
    // capsules) while it's on, restoring the caller's radius when it's off.
    Binding {
        target: root
        property: "radius"
        value: Services.DesktopTheme.roundControls ? Math.min(root.height / 2, 22) : Services.DesktopTheme.controlRadius
        when: Services.DesktopTheme.controlRadius >= 0 || Services.DesktopTheme.roundControls
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        onClicked: m => root.clicked(m)
        onEntered: root.entered()
        onExited: root.exited()
    }
}
