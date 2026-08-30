import QtQuick
import Quickshell.Io
import qs.colors

// One island atom in the top bar: a 28px rounded pill with centred text.
//
// `maxWidth` (0 = unbounded) turns on the truncating behaviour — clip + elide —
// that only the pills with variable-length labels used.
Rectangle {
    id: root

    property alias text: label.text
    property color textColor: Colors.on_surface
    property int fontPixelSize: 17
    property int horizontalPadding: 16
    property int maxWidth: 0
    // Optional command to run on click, e.g. ["qs", "ipc", "call", "systemPanel", "toggle"].
    property var command: null
    property bool interactive: root.command !== null
    property alias cursorShape: mouse.cursorShape

    signal clicked

    radius: 13
    color: Colors.surface_container
    implicitHeight: 28
    clip: root.maxWidth > 0
    implicitWidth: root.maxWidth > 0
        ? Math.min(label.implicitWidth + root.horizontalPadding, root.maxWidth)
        : label.implicitWidth + root.horizontalPadding

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive
        onClicked: {
            if (root.command)
                proc.running = true;
            root.clicked();
        }
    }

    StyledText {
        id: label
        anchors.centerIn: parent
        color: root.textColor
        font.pixelSize: root.fontPixelSize
        elide: root.maxWidth > 0 ? Text.ElideRight : Text.ElideNone
        maximumLineCount: 1
    }

    Process {
        id: proc
        command: root.command ?? []
    }
}
