pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.lock

// Power button with a small "SYSTEM" menu above it. Every action has to be
// held until its bar fills, so a stray click can't reboot or shut down.
Item {
    id: sys

    required property LockContext ctx
    property real sc: 1
    property bool open: false

    implicitWidth: button.width
    implicitHeight: button.height

    component HoldButton: Item {
        id: hold

        property string icon
        property string label
        property color tint: LockTheme.ink
        readonly property real progress: area.progress
        signal confirmed

        width: parent ? parent.width : 0
        height: 46 * sys.sc

        Rectangle {
            anchors.fill: parent
            color: LockTheme.alpha(hold.tint, area.containsMouse ? 0.1 : 0)
        }

        Rectangle {
            width: parent.width * hold.progress
            height: parent.height
            color: LockTheme.alpha(hold.tint, 0.28)
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 16 * sys.sc
            spacing: 14 * sys.sc

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: hold.icon
                filled: true
                font.pixelSize: 20 * sys.sc
                color: hold.tint
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: hold.label
                font.family: LockTheme.mono
                font.pixelSize: 13 * sys.sc
                font.weight: Font.Bold
                font.letterSpacing: 3 * sys.sc
                color: area.containsMouse ? hold.tint : LockTheme.ink
            }
        }

        HoldArea {
            id: area
            anchors.fill: parent
            onConfirmed: hold.confirmed()
        }
    }

    HudPanel {
        id: menu

        anchors.right: button.right
        anchors.bottom: button.top
        anchors.bottomMargin: 12 * sys.sc
        width: 250 * sys.sc
        height: menuColumn.implicitHeight + 24 * sys.sc
        cut: 12 * sys.sc
        fill: LockTheme.panelHi
        opacity: sys.open ? 1 : 0
        visible: opacity > 0
        transform: Translate { y: sys.open ? 0 : 12 * sys.sc }

        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        Column {
            id: menuColumn
            anchors.left: parent.left
            anchors.right: parent.right
            y: 14 * sys.sc
            spacing: 2 * sys.sc

            Text {
                x: 16 * sys.sc
                text: "SYSTEM"
                font.family: LockTheme.display
                font.pixelSize: 14 * sys.sc
                font.letterSpacing: 3 * sys.sc
                color: LockTheme.accent
            }

            Text {
                x: 16 * sys.sc
                bottomPadding: 8 * sys.sc
                text: "HOLD TO CONFIRM"
                font.family: LockTheme.mono
                font.pixelSize: 10 * sys.sc
                font.letterSpacing: 2.5 * sys.sc
                color: LockTheme.inkDim
            }

            HoldButton {
                icon: "bedtime"
                label: "SLEEP"
                tint: LockTheme.accent
                onConfirmed: {
                    sys.open = false;
                    sys.ctx.suspend();
                }
            }

            HoldButton {
                icon: "restart_alt"
                label: "REBOOT"
                tint: LockTheme.gold
                onConfirmed: {
                    sys.open = false;
                    sys.ctx.reboot();
                }
            }

            HoldButton {
                icon: "power_settings_new"
                label: "SHUT DOWN"
                tint: LockTheme.danger
                onConfirmed: {
                    sys.open = false;
                    sys.ctx.poweroff();
                }
            }
        }
    }

    HudPanel {
        id: button

        width: 50 * sys.sc
        height: width
        cut: 10 * sys.sc
        accentLength: 14 * sys.sc
        fill: sys.open ? LockTheme.panelHi : LockTheme.panel
        scale: buttonArea.pressed ? 0.92 : 1

        Glyph {
            anchors.centerIn: parent
            text: "power_settings_new"
            font.pixelSize: 24 * sys.sc
            color: sys.open ? LockTheme.danger : buttonArea.containsMouse ? LockTheme.ink : LockTheme.inkDim
        }

        MouseArea {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sys.open = !sys.open
        }
    }
}
