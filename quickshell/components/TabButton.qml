import QtQuick
import qs.colors
import qs.components

Rectangle {
    id: root
    property string text
    property bool active: false

    width: 90
    height: 32
    radius: 8
    color: active ? Colors.primary_container : Colors.secondary_container

    signal clicked()

    StyledText {
        anchors.centerIn: parent
        text: root.text
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
