import QtQuick
import qs.modules.lock

// Big HH:MM clock whose digits roll on change, a colon that blinks with the
// seconds, and the date underneath.
Column {
    id: clock

    required property date now
    property real sc: 1
    readonly property string hhmm: Qt.formatTime(now, "hhmm")

    spacing: 4 * sc

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 2 * clock.sc

        RollDigit {
            value: clock.hhmm.charAt(0)
            font.family: LockTheme.display
            font.pixelSize: 150 * clock.sc
        }

        RollDigit {
            value: clock.hhmm.charAt(1)
            font.family: LockTheme.display
            font.pixelSize: 150 * clock.sc
        }

        Text {
            width: 58 * clock.sc
            horizontalAlignment: Text.AlignHCenter
            text: ":"
            font.family: LockTheme.display
            font.pixelSize: 150 * clock.sc
            color: LockTheme.accent
            opacity: clock.now.getSeconds() % 2 === 0 ? 1 : 0.25
        }

        RollDigit {
            value: clock.hhmm.charAt(2)
            font.family: LockTheme.display
            font.pixelSize: 150 * clock.sc
        }

        RollDigit {
            value: clock.hhmm.charAt(3)
            font.family: LockTheme.display
            font.pixelSize: 150 * clock.sc
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDate(clock.now, "dddd  ·  d MMMM").toUpperCase()
        font.family: LockTheme.mono
        font.pixelSize: 17 * clock.sc
        font.weight: Font.Bold
        font.letterSpacing: 6 * clock.sc
        color: LockTheme.inkDim
    }
}
