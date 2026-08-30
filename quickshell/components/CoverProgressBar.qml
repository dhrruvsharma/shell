import QtQuick
import qs.colors

// The "▶ Ch. 12" / "▶ Not started" strip along the bottom of a CoverCard.
// `started` drives the whole read/unread treatment (colour + opacity).
Rectangle {
    id: root

    // Deliberately `var`, not `bool`: call sites pass the chapter/episode number
    // straight through and the ternaries below apply JS truthiness, exactly as the
    // inlined versions did. A `bool` property would route through Qt's string
    // conversion instead, which turns "0" into false.
    property var started: false
    property string label: ""
    property string bodyFont: ""
    property int rowSpacing: 6

    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
    height: 30
    color: Colors.surface_container_high
    radius: 12

    // Square off the top corners so only the card's bottom edge stays rounded.
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: parent.radius
        color: parent.color
    }

    Row {
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left; leftMargin: 10
        }
        spacing: root.rowSpacing

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: "▶"
            font.pixelSize: 7
            color: root.started ? Colors.primary : Colors.outline
            opacity: root.started ? 1 : 0.4
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.family: root.bodyFont
            font.pixelSize: 10
            font.letterSpacing: 0.4
            color: root.started ? Colors.on_surface : Colors.on_surface_variant
            opacity: root.started ? 0.85 : 0.45
        }
    }
}
