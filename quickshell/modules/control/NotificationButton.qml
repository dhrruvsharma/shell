pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.lock

// One of a notification card's buttons: a wash of the accent, or
// (`primary`) the accent itself.
MouseArea {
    id: button

    property string text
    property string glyph
    property bool primary: false

    implicitWidth: label.implicitWidth + (glyph ? 22 : 0) + 24
    height: 30
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    Rectangle {
        anchors.fill: parent
        radius: ControlStyle.radius(15)
        color: button.primary ? (button.containsMouse ? Qt.lighter(ControlStyle.accent, 1.12) : ControlStyle.accent) : Colors.withAlpha(ControlStyle.accent, button.containsMouse ? 0.28 : 0.14)
        border.width: button.primary ? 0 : 1
        border.color: Colors.withAlpha(ControlStyle.accent, 0.35)

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
    }

    Row {
        anchors.centerIn: parent
        width: Math.min(implicitWidth, button.width - 16)
        spacing: 6

        Glyph {
            visible: button.glyph.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: button.glyph
            font.pixelSize: 15
            color: label.color
        }

        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, button.width - 16 - (button.glyph ? 21 : 0))
            elide: Text.ElideRight
            text: ControlStyle.label(button.text)
            font.family: ControlStyle.ui
            font.pixelSize: 12
            font.weight: Font.Medium
            font.capitalization: ControlStyle.caps
            color: button.primary ? ControlStyle.inkOn(ControlStyle.accent) : ControlStyle.paper ? ControlStyle.ink : ControlStyle.accent
        }
    }
}
