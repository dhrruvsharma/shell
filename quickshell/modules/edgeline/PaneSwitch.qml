import QtQuick
import qs.colors
import qs.modules.control

// A small switch for a pane's title line (Wi-Fi, Bluetooth, do not
// disturb).
Item {
    id: sw

    property bool checked: false
    signal toggled

    implicitWidth: 38
    implicitHeight: 22

    Rectangle {
        anchors.fill: parent
        radius: ControlStyle.radius(11)
        color: sw.checked ? ControlStyle.accent : area.containsMouse ? ControlStyle.wellHover : ControlStyle.well
        border.width: 1
        border.color: sw.checked ? ControlStyle.accent : ControlStyle.line

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
    }

    Rectangle {
        x: sw.checked ? sw.width - width - 3 : 3
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        radius: ControlStyle.radius(8)
        color: sw.checked ? ControlStyle.inkOn(ControlStyle.accent) : Colors.withAlpha(ControlStyle.ink, 0.7)

        Behavior on x {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled()
    }
}
