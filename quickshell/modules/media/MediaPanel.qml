import QtQuick
import Quickshell
import qs.components
import Quickshell.Io
import Quickshell.Wayland
import qs.services as Services

Rectangle {
    id: mediaPanel
    property bool opened: false

    color: "transparent"
    focus: true
    implicitWidth: 520
    property int popoutHeight: 320
    // Beside a standing bar the bubble's body is inset at both ends (hanging
    // down, it runs to the far edge), so it's a radius longer there for the
    // same room: the cava strip and lyrics stay inside it.
    implicitHeight: vertical ? popoutHeight + popout.radius : popoutHeight
    visible: implicitHeight > 1
    // Slides in from the bar's edge (shell.qml hangs it from the middle of
    // the bar): down, up, or in from the side of a standing bar.
    readonly property string edge: Services.BarLayout.edge
    readonly property bool vertical: Services.BarLayout.vertical
    x: opened || !vertical ? 0 : (edge === "left" ? -1 : 1) * (implicitWidth + 20)
    y: opened || vertical ? 0 : (edge === "bottom" ? 1 : -1) * (popoutHeight + 20)

    Behavior on x {
        NumberAnimation {
            duration: 500
            easing.type: Easing.OutCubic
        }
    }

    Behavior on y {
        NumberAnimation {
            duration: 500
            easing.type: Easing.OutCubic
        }
    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            onClicked: mediaPanel.opened = false
        }
    }

    FocusScope {
        anchors.fill: parent
        focus: mediaPanel.opened
        layer.enabled: true
        layer.smooth: true

        Keys.onEscapePressed: {
            mediaPanel.opened = false
        }

        Popout {
            id: popout
            anchors.fill: parent
            alignment: Services.BarLayout.middleAlignment
            MediaControl {
                id: panel
                anchors.horizontalCenter: parent.horizontalCenter

                opened: mediaPanel.opened

                // Slides in from the bar's side, behind the panel's own slide.
                property real slide: opened ? 0 : 1
                transform: Translate {
                    x: mediaPanel.vertical ? (mediaPanel.edge === "left" ? -1 : 1) * panel.slide * (panel.width + 30) : 0
                    y: mediaPanel.vertical ? 0 : (mediaPanel.edge === "bottom" ? 1 : -1) * panel.slide * (panel.implicitHeight + 30)
                }

                Behavior on slide {
                    NumberAnimation {
                        duration: 350
                        easing.type: Easing.OutCubic
                    }
                }

                scale: opened ? 1.0 : 0.95

                Behavior on scale {
                    NumberAnimation {
                        duration: 350
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}