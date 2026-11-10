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
    property int popoutHeight: 320
    // Slides in from the bar's edge (shell.qml hangs it from the middle of
    // the bar): down, up, or in from the side of a standing bar. Out of the
    // bar as one strip it unfolds from the strip instead, a drawer of it
    // (`unfold` 0 to 1), so it never comes loose from it.
    readonly property string edge: Services.BarLayout.edge
    readonly property bool vertical: Services.BarLayout.vertical
    readonly property bool joined: popout.joined
    property real unfold: opened ? 1 : 0
    implicitWidth: vertical && joined ? 520 * unfold : 520
    // Beside a standing bar the bubble's body is inset at both ends (hanging
    // down, it runs to the far edge), so it's a radius longer there for the
    // same room: the cava strip and lyrics stay inside it.
    implicitHeight: vertical ? popoutHeight + popout.radius : popoutHeight * (joined ? unfold : 1)
    visible: implicitHeight > 1 && implicitWidth > 1
    x: opened || !vertical || joined ? 0 : (edge === "left" ? -1 : 1) * (implicitWidth + 20)
    y: opened || vertical || joined ? 0 : (edge === "bottom" ? 1 : -1) * (popoutHeight + 20)

    Behavior on unfold {
        NumberAnimation {
            duration: 340
            easing.type: Easing.OutCubic
        }
    }

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

    // (Not while it unfolds from the strip: that's animated already.)
    Behavior on implicitHeight {
        enabled: !mediaPanel.joined || mediaPanel.unfold === 1
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
            fromBar: "media"
            MediaControl {
                id: panel
                anchors.horizontalCenter: parent.horizontalCenter

                opened: mediaPanel.opened
                flat: mediaPanel.joined

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

    // A peek (opened on hover) stays while it's in use.
    PeekWatch {
        target: "media"
    }
}
