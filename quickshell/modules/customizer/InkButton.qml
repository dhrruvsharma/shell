import QtQuick
import qs.colors
import qs.modules.lock

// A small action set in the page's type: a glyph and a word, underlined
// when the pointer's on it. `quiet` sets it in the soft ink.
Item {
    id: button

    property string text: ""
    property string icon: ""
    property bool quiet: false
    property int fontSize: 13

    signal clicked

    implicitWidth: row.implicitWidth + 4
    implicitHeight: 26

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Glyph {
            visible: button.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: button.icon
            font.pixelSize: button.fontSize + 3
            color: label.color
        }

        BookText {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: button.text
            font.family: BookStyle.ui
            font.pixelSize: button.fontSize
            font.italic: button.quiet
            font.capitalization: BookStyle.labelCaps
            font.letterSpacing: BookStyle.labelSpacing * 0.5
            color: area.containsMouse ? BookStyle.accent : button.quiet ? BookStyle.inkSoft : BookStyle.ink

            Rectangle {
                anchors.top: parent.bottom
                width: parent.width
                height: 1
                color: BookStyle.accent
                visible: area.containsMouse
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
