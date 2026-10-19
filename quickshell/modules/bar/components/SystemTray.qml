import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.Core
import qs.Widgets
import qs.colors
import qs.components
import qs.services as Services

// The tray at the bar's far end: a button that slides a card of tray icons
// out beside it. On a standing bar (`vertical`) the two stack, the card
// opening upwards. Coloured like the rest of the bar (services/BarSettings),
// which can also hide it.
GridLayout {
    id: root

    property bool trayOpen: false
    property bool vertical: false

    visible: SystemTray.items.values.length > 0 && Services.BarSettings.shown("tray")
    flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    rowSpacing: 4
    columnSpacing: 4

    Card {
        clip: true
        radius: Math.min(width, height) / 2
        color: Services.BarSettings.pill

        // 26 thick across the bar; along it, as long as its icons when open.
        Layout.preferredWidth: root.vertical ? 26 : root.trayOpen ? (trayInner.implicitWidth + 16) : 0
        Layout.preferredHeight: root.vertical ? (root.trayOpen ? (trayInner.implicitHeight + 16) : 0) : 26
        Layout.rightMargin: !root.vertical && root.trayOpen ? 4 : 0
        Layout.bottomMargin: root.vertical && root.trayOpen ? 4 : 0
        opacity: root.trayOpen ? 1 : 0

        Tray {
            id: trayInner
            anchors.centerIn: parent
            iconSize: 16
            vertical: root.vertical
        }

        /* ===== Animations restored with hardcoded values ===== */

        Behavior on Layout.preferredWidth {
            NumberAnimation {
                duration: 220
                easing.type: Easing.InOutQuad
            }
        }

        Behavior on Layout.preferredHeight {
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

        Behavior on Layout.bottomMargin {
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

        color: Services.BarSettings.capsule

        Icon {
            anchors.centerIn: parent
            icon: Icons.arrowLeft
            font.pixelSize: 14

            color: Services.BarSettings.ink
            // Points the way the card opens, then back to close it.
            rotation: root.vertical ? (root.trayOpen ? 270 : 90) : (root.trayOpen ? 180 : 0)

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

            onClicked: root.trayOpen = !root.trayOpen

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
