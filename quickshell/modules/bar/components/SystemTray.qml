import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.Core
import qs.Widgets
import qs.colors
import qs.components

RowLayout {
    id: root

    property bool trayOpen: false

    visible: SystemTray.items.values.length > 0
    spacing: 4

    Card {
        clip: true
        height: 26
        radius: height / 2


        Layout.preferredWidth: trayOpen ? (trayInner.implicitWidth + 16) : 0
        Layout.rightMargin: trayOpen ? 4 : 0
        opacity: trayOpen ? 1 : 0

        RowLayout {
            id: trayInner
            anchors.centerIn: parent
            spacing: 8

            Tray {
                iconSize: 16
            }
        }

        /* ===== Animations restored with hardcoded values ===== */

        Behavior on Layout.preferredWidth {
            NumberAnimation {
                duration: 220
                easing.type: Easing.InOutQuad
            }
        }

        Behavior on Layout.rightMargin {
            NumberAnimation {
                duration: 220
                easing.type: Easing.InOutQuad
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }
    }

    Card {
        id: toggleBtn

        Layout.preferredWidth: 26
        Layout.preferredHeight: 26
        radius: height / 2

        color: Colors.background

        Icon {
            anchors.centerIn: parent
            icon: Icons.arrowLeft
            font.pixelSize: 14

            color: Colors.on_surface
            rotation: trayOpen ? 180 : 0

            Behavior on rotation {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: trayOpen = !trayOpen

            onEntered: toggleBtn.border.color = Colors.primary
            onExited: toggleBtn.border.color = Colors.outline_variant
        }

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Behavior on border.color {
            ColorAnimation { duration: 120 }
        }
    }
}
