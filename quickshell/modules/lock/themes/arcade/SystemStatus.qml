pragma ComponentBehavior: Bound
import QtQuick
import qs.services as Services
import qs.modules.lock

// Top-right: caps lock warning, keyboard layout (only with several layouts)
// and the battery as a segmented energy bar.
Row {
    id: status

    required property LockContext ctx
    property real sc: 1

    readonly property real pct: Services.Battery.percentage
    readonly property bool charging: Services.Battery.charging
    readonly property color energy: charging ? LockTheme.gold : pct <= 20 ? LockTheme.danger : LockTheme.ink

    spacing: 14 * sc

    HudPanel {
        anchors.verticalCenter: parent.verticalCenter
        visible: status.ctx.capsLock
        width: capsRow.implicitWidth + 22 * status.sc
        height: 30 * status.sc
        cut: 7 * status.sc
        accent: LockTheme.danger
        accentLength: 10 * status.sc

        Row {
            id: capsRow
            anchors.centerIn: parent
            spacing: 6 * status.sc

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: "keyboard_capslock"
                font.pixelSize: 16 * status.sc
                color: LockTheme.danger
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "CAPS"
                font.family: LockTheme.mono
                font.pixelSize: 11 * status.sc
                font.weight: Font.Bold
                font.letterSpacing: 2.5 * status.sc
                color: LockTheme.danger
            }
        }
    }

    HudPanel {
        anchors.verticalCenter: parent.verticalCenter
        visible: status.ctx.multiLayout && status.ctx.layout.length > 0
        width: layoutRow.implicitWidth + 22 * status.sc
        height: 30 * status.sc
        cut: 7 * status.sc
        accentLength: 10 * status.sc

        Row {
            id: layoutRow
            anchors.centerIn: parent
            spacing: 6 * status.sc

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: "keyboard"
                font.pixelSize: 16 * status.sc
                color: LockTheme.inkDim
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: status.ctx.layout
                font.family: LockTheme.mono
                font.pixelSize: 11 * status.sc
                font.weight: Font.Bold
                font.letterSpacing: 2 * status.sc
                color: LockTheme.ink
            }
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3 * status.sc

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: status.charging ? "bolt" : "battery_full"
            filled: true
            font.pixelSize: 18 * status.sc
            color: status.energy
        }

        Repeater {
            model: 10

            Rectangle {
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                width: 6 * status.sc
                height: 16 * status.sc
                color: index < Math.ceil(status.pct / 10) ? status.energy : LockTheme.alpha(LockTheme.ink, 0.14)
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 6 * status.sc
            text: Math.round(status.pct) + "%"
            font.family: LockTheme.mono
            font.pixelSize: 13 * status.sc
            font.weight: Font.Bold
            color: status.energy
        }
    }
}
