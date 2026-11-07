import QtQuick
import qs.colors
import qs.modules.lock

// One of the screen tools at the end of the edge line's pill (PeekFace): a
// glyph in a ring that lights while the pointer's on it (`hot`). The pill
// presses it through the line's grip (it has no mouse area of its own).
Item {
    id: tool

    required property string tool
    property string glyph
    property bool lit: false
    property bool hot: false
    property color ink
    property color tint
    property bool dim: false

    width: 24
    height: 24

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: tool.hot ? Colors.withAlpha(tool.ink, 0.14) : "transparent"
    }

    Glyph {
        anchors.centerIn: parent
        text: tool.glyph
        filled: tool.lit || tool.hot
        font.pixelSize: 17
        color: tool.tint
        opacity: tool.dim ? 0.45 : 1
    }
}
