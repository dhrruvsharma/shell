import QtQuick
import qs.services as Services
import qs.colors
import qs.components

Item {
    id: root
    width: 30; height: 30

    property string icon: ""
    property string tooltip: ""
    property bool   active: false
    signal clicked()

    Rectangle {
        anchors.fill: parent
        radius: Services.DesktopTheme.rad(8)
        color: active
            ? Colors.primary_container
            : (area.containsMouse ? Colors.surface_container_high : "transparent")

        Behavior on color { ColorAnimation { duration: 110 } }

        StyledText {
            anchors.centerIn: parent
            text: root.icon
            font.pixelSize: 14
            color: active
                ? Colors.on_primary_container
                : Colors.on_surface_variant
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    // Tooltip
    Rectangle {
        visible: area.containsMouse && root.tooltip.length > 0
        anchors { bottom: parent.top; horizontalCenter: parent.horizontalCenter; bottomMargin: 4 }
        width: tipText.implicitWidth + 12; height: 22
        radius: Services.DesktopTheme.rad(6)
        color: Colors.surface_container_highest
        z: 99

        StyledText {
            id: tipText
            anchors.centerIn: parent
            text: root.tooltip
            font.pixelSize: 10
        }
    }
}
