pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.control
import qs.modules.lock

// A button on the editor's bars: an icon in a well, in the accent when it's
// the one in hand (`active`), and after a moment's hover what it is and its
// key, above it (below on the top bar).
MouseArea {
    id: button

    property string glyph
    property string tip
    property string key
    property bool active: false
    property bool tipBelow: false

    width: 36
    height: 36
    hoverEnabled: true
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    opacity: enabled ? 1 : 0.35

    Rectangle {
        anchors.fill: parent
        radius: ControlStyle.radius(10)
        color: button.active ? Colors.withAlpha(ControlStyle.accent, 0.2) : button.containsMouse ? ControlStyle.wellHover : "transparent"
        border.width: button.active ? 1 : 0
        border.color: Colors.withAlpha(ControlStyle.accent, 0.6)

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
    }

    Glyph {
        anchors.centerIn: parent
        text: button.glyph
        filled: button.active
        font.pixelSize: 20
        color: button.active ? ControlStyle.accent : ControlStyle.ink
    }

    Timer {
        id: wait
        interval: 450
        running: button.containsMouse && button.tip.length > 0
    }

    Rectangle {
        visible: button.containsMouse && !wait.running && button.tip.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: button.tipBelow ? parent.height + 8 : -height - 8
        width: tipRow.implicitWidth + 16
        height: 26
        radius: ControlStyle.radius(8)
        color: Colors.withAlpha(Colors.inverse_surface, 0.95)
        z: 10

        Row {
            id: tipRow
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: button.tip
                font.family: ControlStyle.body
                font.pixelSize: 12
                color: Colors.inverse_on_surface
            }

            Text {
                visible: button.key.length > 0
                text: button.key
                font.family: ControlStyle.mono
                font.pixelSize: 11
                color: Colors.withAlpha(Colors.inverse_on_surface, 0.6)
            }
        }
    }
}
