import QtQuick
import qs.colors

// The screen's being recorded: a red dot, breathing (the edge line's pill).
Rectangle {
    id: dot

    property bool running: false

    width: 7
    height: 7
    radius: 3.5
    color: Colors.error

    SequentialAnimation on opacity {
        running: dot.running
        loops: Animation.Infinite
        NumberAnimation {
            to: 0.25
            duration: 650
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            to: 1
            duration: 650
            easing.type: Easing.InOutQuad
        }
    }
}
