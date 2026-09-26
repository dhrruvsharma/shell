pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Persisted settings for the draggable desktop cava widget. Kept in its own
// file so it never touches shared settings. accentColor is stored as a string;
// "" means "use the theme primary".
Singleton {
    id: root

    property alias enabled: adapter.enabled
    property alias posX: adapter.posX
    property alias posY: adapter.posY
    property alias boxWidth: adapter.boxWidth
    property alias boxHeight: adapter.boxHeight
    property alias skew: adapter.skew
    property alias rotation: adapter.rotation
    property alias tiltX: adapter.tiltX          // 3D pitch (deg), rotate about horizontal axis
    property alias tiltY: adapter.tiltY          // 3D yaw (deg), rotate about vertical axis
    property alias accentColor: adapter.accentColor
    property alias orientation: adapter.orientation   // 0 bottom, 1 top, 2 left, 3 right
    property alias style: adapter.style               // 0 bars, 1 area
    property alias flip: adapter.flip
    // Bezier baseline (see components/CavaShader.qml). Control points are a
    // fraction of the bar extent, clamped to -1..1.
    property alias bezierEnabled: adapter.bezierEnabled
    property alias bezierFit: adapter.bezierFit
    property alias bezierY0: adapter.bezierY0
    property alias bezierY1: adapter.bezierY1
    property alias bezierY2: adapter.bezierY2
    property alias bezierY3: adapter.bezierY3

    function setBezierPoint(i, v) {
        v = Math.max(-1, Math.min(1, v));
        if (i === 0)
            adapter.bezierY0 = v;
        else if (i === 1)
            adapter.bezierY1 = v;
        else if (i === 2)
            adapter.bezierY2 = v;
        else
            adapter.bezierY3 = v;
    }

    function resetBezier() {
        adapter.bezierY0 = 0;
        adapter.bezierY1 = 0;
        adapter.bezierY2 = 0;
        adapter.bezierY3 = 0;
        root.save();
    }

    // Coalesce live edit-mode updates into one disk write.
    function save() {
        writeTimer.restart();
    }

    function reset() {
        adapter.enabled = true;
        adapter.posX = 40;
        adapter.posY = 880;
        adapter.boxWidth = 260;
        adapter.boxHeight = 90;
        adapter.skew = 0;
        adapter.rotation = 0;
        adapter.tiltX = 0;
        adapter.tiltY = 0;
        adapter.accentColor = "";
        adapter.orientation = 0;
        adapter.style = 0;
        adapter.flip = 0;
        adapter.bezierEnabled = false;
        adapter.bezierFit = true;
        adapter.bezierY0 = 0;
        adapter.bezierY1 = 0;
        adapter.bezierY2 = 0;
        adapter.bezierY3 = 0;
        root.save();
    }

    Timer {
        id: writeTimer
        interval: 150
        repeat: false
        onTriggered: file.writeAdapter()
    }

    Timer {
        id: reloadTimer
        interval: 100
        repeat: false
        onTriggered: file.reload()
    }

    JsonAdapter {
        id: adapter
        property bool enabled: true
        property real posX: 40
        property real posY: 880
        property real boxWidth: 260
        property real boxHeight: 90
        property real skew: 0
        property real rotation: 0
        property real tiltX: 0
        property real tiltY: 0
        property string accentColor: ""
        property int orientation: 0
        property int style: 0
        property int flip: 0
        property bool bezierEnabled: false
        property bool bezierFit: true
        property real bezierY0: 0
        property real bezierY1: 0
        property real bezierY2: 0
        property real bezierY3: 0
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/quickshell/cavawidget.json"
        watchChanges: true
        adapter: adapter
        onFileChanged: reloadTimer.restart()
    }

    Component.onCompleted: file.reload()
}
