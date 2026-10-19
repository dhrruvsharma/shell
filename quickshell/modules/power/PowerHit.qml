import QtQuick

// The pointer's way into a power menu action: pointing at it makes it
// current, a click chooses it. Size it to what the scene draws.
MouseArea {
    id: hit

    required property var menu
    required property int index

    hoverEnabled: true
    cursorShape: menu.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
    onContainsMouseChanged: if (containsMouse) menu.hover(index)
    onPositionChanged: if (menu.current !== index) menu.hover(index)
    onClicked: {
        if (menu.phase === "rite")
            menu.cancel();
        else
            menu.choose(index);
    }
}
