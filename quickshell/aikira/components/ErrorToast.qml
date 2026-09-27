import QtQuick
import qs.services as Services
import qs.colors
import qs.components

Item {
    id: root
    width: toastText.implicitWidth + 40
    height: 40
    opacity: 0
    visible: opacity > 0

    function show(msg) {
        toastText.text = msg
        showAnim.restart()
    }

    SequentialAnimation {
        id: showAnim
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
        PauseAnimation  { duration: 3500 }
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: 300; easing.type: Easing.InCubic }
    }

    Rectangle {
        anchors.fill: parent
        radius: Services.DesktopTheme.rad(20)
        color: Colors.error_container
        border { width: 1; color: Colors.error }

        StyledText {
            id: toastText
            anchors.centerIn: parent
            font { pixelSize: 12; family: "monospace" }
            color: Colors.on_error_container
        }
    }
}
