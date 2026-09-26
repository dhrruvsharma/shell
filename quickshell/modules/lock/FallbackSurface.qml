import QtQuick

// Last-resort lock screen, used only when no theme could be loaded. Plain on
// purpose: nothing here should be able to fail, and it still takes the
// password and shows what PAM says.
Item {
    id: fallback

    required property LockContext ctx
    property bool still: false

    Rectangle {
        anchors.fill: parent
        color: "#0b0b0d"
    }

    LockInput {
        ctx: fallback.ctx
        active: !fallback.still
        onEscapePressed: fallback.ctx.clearInput()
    }

    Column {
        anchors.centerIn: parent
        spacing: 18

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(fallback.ctx.now, "hh:mm")
            font.pixelSize: 96
            font.weight: Font.Light
            color: "#e8e8ec"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Locked. Type your password and press Enter."
            font.pixelSize: 16
            color: "#9a9aa2"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: fallback.ctx.phase === "verifying" ? "Checking…" : "•".repeat(Math.min(fallback.ctx.cells, 40))
            font.pixelSize: 28
            color: fallback.ctx.denying ? "#ff8a80" : "#e8e8ec"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: fallback.ctx.message.length > 0 ? fallback.ctx.message
                : fallback.ctx.capsLock ? "Caps Lock is on"
                : fallback.ctx.lockoutClock.length > 0 ? "Locked out, try again in " + fallback.ctx.lockoutClock
                : ""
            font.pixelSize: 14
            color: "#ff8a80"
        }
    }
}
