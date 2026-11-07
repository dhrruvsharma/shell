pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.control
import qs.modules.lock
import qs.modules.screenshot

// The bar over the zoomed-out desktop, on the desktop theme's frame: what
// this is, how it works, whether to remember the choice, and the way out.
Item {
    id: bar

    property string heading
    property bool remember: false

    signal rememberToggled
    signal cancelled

    readonly property real inner: 44

    implicitHeight: surface.headRoom + 2 * surface.pad + inner + surface.footRoom

    // Clicks on the bar stay on the bar.
    MouseArea {
        anchors.fill: parent
    }

    EditorSurface {
        id: surface

        anchors.fill: parent
        title: "share"
    }

    Row {
        x: surface.pad + 8
        y: surface.headRoom + surface.pad
        height: bar.inner
        spacing: 14

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: "screen_share"
            filled: true
            font.pixelSize: 26
            color: ControlStyle.accent
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: bar.heading
            font.family: ControlStyle.display
            font.pixelSize: 24
            color: ControlStyle.ink
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 24
            color: ControlStyle.line
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Click a window or the desktop, or drag out a region"
            font.family: ControlStyle.body
            font.pixelSize: 14
            color: Colors.withAlpha(ControlStyle.ink, 0.7)
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: surface.pad + 4
        y: surface.headRoom + surface.pad
        height: bar.inner
        spacing: 6

        MouseArea {
            id: rememberButton

            anchors.verticalCenter: parent.verticalCenter
            width: rememberRow.implicitWidth + 20
            height: 36
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bar.rememberToggled()

            Rectangle {
                anchors.fill: parent
                radius: ControlStyle.radius(10)
                color: rememberButton.containsMouse ? ControlStyle.wellHover : "transparent"
            }

            Row {
                id: rememberRow

                anchors.centerIn: parent
                spacing: 8

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: bar.remember ? "check_box" : "check_box_outline_blank"
                    filled: bar.remember
                    font.pixelSize: 20
                    color: bar.remember ? ControlStyle.accent : ControlStyle.ink
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Remember for this app"
                    font.family: ControlStyle.body
                    font.pixelSize: 14
                    color: ControlStyle.ink
                }
            }
        }

        MouseArea {
            id: cancelButton

            anchors.verticalCenter: parent.verticalCenter
            width: cancelRow.implicitWidth + 20
            height: 36
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bar.cancelled()

            Rectangle {
                anchors.fill: parent
                radius: ControlStyle.radius(10)
                color: cancelButton.containsMouse ? ControlStyle.wellHover : ControlStyle.well
            }

            Row {
                id: cancelRow

                anchors.centerIn: parent
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Cancel"
                    font.family: ControlStyle.body
                    font.pixelSize: 14
                    color: ControlStyle.ink
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Esc"
                    font.family: ControlStyle.mono
                    font.pixelSize: 11
                    color: Colors.withAlpha(ControlStyle.ink, 0.55)
                }
            }
        }
    }
}
