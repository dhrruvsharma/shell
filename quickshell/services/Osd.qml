pragma Singleton
import QtQuick
import Quickshell

// What the volume / brightness OSD shows (Osd/OsdWindow.qml draws it).
// Sources report every step with show(); the OSD stays up while steps keep
// coming and hides a moment after the last.
Singleton {
    id: root

    // "volume" | "brightness"
    property string type: ""
    // The last level of each, in percent. The volume can pass 100: wpctl's
    // keys run on past it.
    property real volume: 0
    property real brightness: 0
    property bool visible: false
    // Counts the steps, so the OSD answers one that leaves the level where
    // it was (a key pressed at the end of the range).
    property int pulse: 0
    readonly property real value: type === "volume" ? volume : brightness

    Timer {
        id: hideTimer
        interval: 1700
        onTriggered: root.visible = false
    }

    function show(t, v) {
        if (t === "volume")
            volume = v;
        else
            brightness = v;
        type = t;
        pulse++;
        visible = true;
        hideTimer.restart();
    }
}
