import QtQuick
import qs.modules.lock

// Top-left: SESSION LOCKED chip and how long the "game" has been paused.
Column {
    id: status

    required property LockContext ctx
    property real sc: 1

    readonly property int elapsed: Math.max(0, Math.floor((ctx.now.getTime() - ctx.lockedAt) / 1000))

    function pad(n) {
        return String(n).padStart(2, "0");
    }

    spacing: 10 * sc

    HudPanel {
        width: chip.implicitWidth + 28 * status.sc
        height: 34 * status.sc
        cut: 8 * status.sc
        accentLength: 16 * status.sc

        Row {
            id: chip
            anchors.centerIn: parent
            spacing: 9 * status.sc

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: "lock"
                filled: true
                font.pixelSize: 16 * status.sc
                color: LockTheme.accent
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "SESSION LOCKED"
                font.family: LockTheme.mono
                font.pixelSize: 12 * status.sc
                font.weight: Font.Bold
                font.letterSpacing: 3.5 * status.sc
                color: LockTheme.ink
            }
        }
    }

    Row {
        x: 4 * status.sc
        spacing: 8 * status.sc

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 7 * status.sc
            height: width
            radius: width / 2
            color: LockTheme.danger
            opacity: status.elapsed % 2 === 0 ? 1 : 0.25
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "PAUSED"
            font.family: LockTheme.mono
            font.pixelSize: 11 * status.sc
            font.weight: Font.Bold
            font.letterSpacing: 3 * status.sc
            color: LockTheme.inkDim
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.floor(status.elapsed / 3600) + ":" + status.pad(Math.floor(status.elapsed / 60) % 60) + ":" + status.pad(status.elapsed % 60)
            font.family: LockTheme.mono
            font.pixelSize: 13 * status.sc
            font.weight: Font.Bold
            font.letterSpacing: 1.5 * status.sc
            color: LockTheme.ink
        }
    }
}
