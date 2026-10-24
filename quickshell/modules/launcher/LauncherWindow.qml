pragma ComponentBehavior: Bound
import QtQuick

// The app launcher: SUPER+R, the left screen edge, or
// `qs ipc call launcherWindow toggle`. The wheel itself (LauncherDial, in
// the desktop theme's look) is built for each opening and dropped once it
// has played out, so nothing of it stays behind the closed launcher.
Item {
    id: root

    // Up, or on its way out (the panels' surface is full screen meanwhile).
    property bool isOpen: false
    // Playing its way out.
    property bool closing: false

    anchors.fill: parent
    enabled: isOpen && !closing

    function toggle() {
        if (isOpen && !closing)
            close();
        else
            open();
    }

    function open() {
        if (isOpen && !closing)
            return;
        // (back from closing, the panel plays itself in again)
        closing = false;
        isOpen = true;
    }

    function close() {
        if (!isOpen || closing)
            return;
        closing = true;
    }

    // The panel has played out.
    function closed() {
        closing = false;
        isOpen = false;
    }

    Loader {
        anchors.fill: parent
        active: root.isOpen
        focus: true

        sourceComponent: LauncherDial {
            launcher: root
        }
    }
}
