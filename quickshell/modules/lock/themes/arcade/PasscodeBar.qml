pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.lock

// The passcode zone. Idle it shows a blinking PRESS ANY KEY (or GAME OVER with
// the faillock countdown). Typing lights up a row of energy cells with sparks
// and a combo counter. While PAM verifies, a charge wave runs through the
// cells. A wrong password shakes them red under a glitching ACCESS DENIED. A
// correct one bursts them gold into ACCESS GRANTED and the XP read-out.
Item {
    id: bar

    required property LockContext ctx
    property real sc: 1

    readonly property string phase: ctx.phase
    readonly property bool rewarding: phase === "granted" || phase === "exiting"
    readonly property int maxCells: 32
    readonly property int shownCells: Math.min(ctx.cells, maxCells)
    readonly property real cellSize: 15 * sc
    readonly property real step: Math.min(30 * sc, (width - 150 * sc) / Math.max(1, shownCells))
    readonly property real rowY: 44 * sc
    readonly property bool idle: ctx.cells === 0 && !ctx.denying && !rewarding && phase !== "verifying"

    property real shakeX: 0
    property real verifyT: 0
    property real grantT: 0
    property bool blinkOn: true
    property bool comboFresh: false

    implicitWidth: 640 * sc
    implicitHeight: 176 * sc

    function cellX(i) {
        return width / 2 + (i - (shownCells - 1) / 2) * step;
    }

    function burst(x, y, count, color, speed, upward, life) {
        for (let i = 0; i < count; i++) {
            const a = upward ? -Math.PI / 2 + (Math.random() - 0.5) * 2.2 : Math.random() * Math.PI * 2;
            const v = speed * (0.5 + Math.random() * 0.8);
            sparkComp.createObject(fx, {
                x: x - 2,
                y: y - 2,
                vx: Math.cos(a) * v,
                vy: Math.sin(a) * v,
                color: color,
                spin: (Math.random() - 0.5) * 540,
                life: life * (0.8 + Math.random() * 0.4)
            });
        }
    }

    Component {
        id: sparkComp
        Spark {}
    }

    Connections {
        target: bar.ctx

        function onTyped(index) {
            bar.comboFresh = true;
            comboTimer.restart();
            comboPop.restart();
            if (index < bar.maxCells)
                bar.burst(bar.cellX(index), bar.rowY, 6, LockTheme.accent, 70 * bar.sc, true, 520);
        }

        function onErased(index) {
            if (index < bar.maxCells)
                bar.burst(bar.cellX(Math.min(index, bar.shownCells)), bar.rowY, 3, LockTheme.inkDim, 40 * bar.sc, false, 420);
        }

        function onDenied(costLife) {
            shake.restart();
            deniedFx.restart();
            lifeLost.visible = costLife && bar.ctx.maxLives > 0;
            for (let i = 0; i < bar.shownCells; i++)
                bar.burst(bar.cellX(i), bar.rowY, 2, LockTheme.danger, 50 * bar.sc, false, 600);
        }

        function onGranted() {
            grantFx.restart();
            for (let i = 0; i < bar.shownCells; i++)
                bar.burst(bar.cellX(i), bar.rowY, 4, LockTheme.gold, 110 * bar.sc, false, 700);
        }
    }

    Timer {
        id: comboTimer
        interval: 1500
        onTriggered: bar.comboFresh = false
    }

    Timer {
        interval: 700
        repeat: true
        running: bar.idle && bar.ctx.awake && !bar.ctx.lockedOut
        onRunningChanged: if (!running) bar.blinkOn = true
        onTriggered: bar.blinkOn = !bar.blinkOn
    }

    NumberAnimation on verifyT {
        running: bar.phase === "verifying"
        from: 0
        to: 1
        duration: 800
        loops: Animation.Infinite
    }

    SequentialAnimation {
        id: shake
        NumberAnimation { target: bar; property: "shakeX"; to: -18 * bar.sc; duration: 50; easing.type: Easing.OutQuad }
        NumberAnimation { target: bar; property: "shakeX"; to: 15 * bar.sc; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: bar; property: "shakeX"; to: -11 * bar.sc; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: bar; property: "shakeX"; to: 7 * bar.sc; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: bar; property: "shakeX"; to: -3 * bar.sc; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: bar; property: "shakeX"; to: 0; duration: 80; easing.type: Easing.OutQuad }
    }

    // ── Idle prompt / game over ──────────────────────────────────────
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: bar.rowY - height / 2
        spacing: 16 * bar.sc
        visible: bar.idle && !bar.ctx.lockedOut
        opacity: bar.blinkOn ? (bar.ctx.awake ? 1 : 0.45) : 0.12

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: "play_arrow"
            filled: true
            font.pixelSize: 18 * bar.sc
            color: LockTheme.accent
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "PRESS ANY KEY"
            font.family: LockTheme.mono
            font.pixelSize: 17 * bar.sc
            font.weight: Font.Bold
            font.letterSpacing: 9 * bar.sc
            color: LockTheme.ink
        }

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: "play_arrow"
            filled: true
            rotation: 180
            font.pixelSize: 18 * bar.sc
            color: LockTheme.accent
        }
    }

    // Takes over once the ACCESS DENIED that caused it has played out.
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: bar.rowY - 26 * bar.sc
        spacing: 2 * bar.sc
        visible: bar.idle && bar.ctx.lockedOut && !denied.visible

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "GAME OVER"
            font.family: LockTheme.display
            font.pixelSize: 30 * bar.sc
            font.letterSpacing: 4 * bar.sc
            color: LockTheme.danger
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property int secs: bar.ctx.lockoutLeft
            text: bar.ctx.lockoutUntil < 0 ? "ACCOUNT LOCKED · ASK AN ADMIN TO RESET IT"
                : "CONTINUE IN " + Math.floor(secs / 60) + ":" + String(secs % 60).padStart(2, "0")
            font.family: LockTheme.mono
            font.pixelSize: 14 * bar.sc
            font.weight: Font.Bold
            font.letterSpacing: 4 * bar.sc
            color: LockTheme.ink
        }
    }

    // ── Cells ────────────────────────────────────────────────────────
    Item {
        id: cells
        anchors.fill: parent
        transform: Translate { x: bar.shakeX }

        Repeater {
            model: bar.maxCells

            Item {
                id: cell

                required property int index
                readonly property bool active: index < bar.shownCells
                // A bump of light travelling left to right while verifying.
                readonly property real charge: bar.phase === "verifying"
                    ? Math.max(0, 1 - Math.abs(bar.verifyT * (bar.shownCells + 5) - 2.5 - index) / 2.5) : 0
                readonly property color tone: bar.ctx.denying ? LockTheme.danger
                    : bar.rewarding ? LockTheme.gold : LockTheme.accent

                width: bar.cellSize
                height: width
                x: bar.cellX(index) - width / 2
                y: bar.rowY - height / 2
                scale: 0
                visible: scale > 0.01

                Behavior on x {
                    enabled: cell.active
                    NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                }

                onActiveChanged: {
                    if (active) {
                        popOut.stop();
                        popIn.restart();
                    } else {
                        popIn.stop();
                        popOut.restart();
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 2.1
                    height: width
                    rotation: 45
                    color: cell.tone
                    opacity: 0.14 + cell.charge * 0.3
                }

                Rectangle {
                    anchors.fill: parent
                    rotation: 45
                    color: Qt.tint(cell.tone, LockTheme.alpha("#ffffff", cell.charge * 0.75))
                    border.width: 1
                    border.color: LockTheme.alpha("#ffffff", 0.35)
                }

                NumberAnimation {
                    id: popIn
                    target: cell
                    property: "scale"
                    from: 0
                    to: 1
                    duration: 260
                    easing.type: Easing.OutBack
                    easing.overshoot: 3
                }

                NumberAnimation {
                    id: popOut
                    target: cell
                    property: "scale"
                    to: 0
                    duration: 160
                    easing.type: Easing.InBack
                }
            }
        }

        Text {
            visible: bar.ctx.cells > bar.maxCells
            x: bar.cellX(bar.shownCells - 1) + 18 * bar.sc
            y: bar.rowY - height / 2
            text: "+" + (bar.ctx.cells - bar.maxCells)
            font.family: LockTheme.mono
            font.pixelSize: 13 * bar.sc
            color: LockTheme.accent
        }
    }

    // ── Combo ────────────────────────────────────────────────────────
    Column {
        id: combo

        readonly property int n: bar.ctx.combo
        readonly property color tone: n >= 16 ? LockTheme.gold : n >= 8 ? LockTheme.accent : LockTheme.ink

        anchors.right: parent.right
        y: bar.rowY - 30 * bar.sc
        spacing: -2 * bar.sc
        opacity: n >= 3 && bar.comboFresh && !bar.rewarding && bar.phase !== "verifying" ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 220 }
        }

        Text {
            id: comboNum
            anchors.right: parent.right
            text: "×" + combo.n
            font.family: LockTheme.display
            font.pixelSize: 30 * bar.sc
            color: combo.tone
        }

        Text {
            anchors.right: parent.right
            text: combo.n >= 24 ? "GODLIKE" : combo.n >= 16 ? "EXCELLENT" : combo.n >= 8 ? "GREAT" : "COMBO"
            font.family: LockTheme.mono
            font.pixelSize: 10 * bar.sc
            font.weight: Font.Bold
            font.letterSpacing: 3 * bar.sc
            color: combo.tone
        }

        NumberAnimation {
            id: comboPop
            target: comboNum
            property: "scale"
            from: 1.45
            to: 1
            duration: 200
            easing.type: Easing.OutBack
        }
    }

    // ── Verifying ────────────────────────────────────────────────────
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: bar.rowY + 26 * bar.sc
        visible: bar.phase === "verifying"
        text: "VERIFYING" + ".".repeat(1 + Math.floor(bar.verifyT * 3))
        font.family: LockTheme.mono
        font.pixelSize: 13 * bar.sc
        font.weight: Font.Bold
        font.letterSpacing: 6 * bar.sc
        color: LockTheme.accent
    }

    // ── Access denied (RGB-split glitch) ─────────────────────────────
    Item {
        id: denied

        property real jitter: 0

        anchors.horizontalCenter: parent.horizontalCenter
        y: bar.rowY + 20 * bar.sc
        width: deniedText.implicitWidth
        height: deniedText.implicitHeight
        opacity: 0
        visible: opacity > 0

        Text {
            x: -denied.jitter * 3
            text: deniedText.text
            font: deniedText.font
            color: "#ff3b5c"
            opacity: 0.7
        }

        Text {
            x: denied.jitter * 3
            text: deniedText.text
            font: deniedText.font
            color: "#3bd9ff"
            opacity: 0.6
        }

        Text {
            id: deniedText
            text: "ACCESS DENIED"
            font.family: LockTheme.display
            font.pixelSize: 24 * bar.sc
            font.letterSpacing: 5 * bar.sc
            color: LockTheme.danger
        }

        Text {
            id: lifeLost
            anchors.left: parent.right
            anchors.leftMargin: 14 * bar.sc
            anchors.verticalCenter: parent.verticalCenter
            text: "−1 LIFE"
            font.family: LockTheme.mono
            font.pixelSize: 13 * bar.sc
            font.weight: Font.Bold
            font.letterSpacing: 2 * bar.sc
            color: LockTheme.danger
        }
    }

    SequentialAnimation {
        id: deniedFx
        PropertyAction { target: denied; property: "opacity"; value: 1 }
        NumberAnimation { target: denied; property: "jitter"; to: 2; duration: 40 }
        NumberAnimation { target: denied; property: "jitter"; to: -1.5; duration: 50 }
        NumberAnimation { target: denied; property: "jitter"; to: 1.2; duration: 50 }
        NumberAnimation { target: denied; property: "jitter"; to: -0.6; duration: 60 }
        NumberAnimation { target: denied; property: "jitter"; to: 0; duration: 80 }
        PauseAnimation { duration: 900 }
        NumberAnimation { target: denied; property: "opacity"; to: 0; duration: 300 }
    }

    // ── Access granted + XP read-out ─────────────────────────────────
    Item {
        id: granted
        anchors.fill: parent
        visible: bar.rewarding

        readonly property var reward: bar.ctx.reward

        Rectangle {
            id: shockwave
            anchors.horizontalCenter: parent.horizontalCenter
            y: bar.rowY - height / 2
            width: 120 * bar.sc
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 3 * bar.sc
            border.color: LockTheme.gold
            opacity: 1 - LockTheme.seg(bar.grantT, 0, 0.45)
            scale: 0.3 + 4 * LockTheme.seg(bar.grantT, 0, 0.45)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: bar.rowY - height / 2
            text: "ACCESS GRANTED"
            font.family: LockTheme.display
            font.pixelSize: 32 * bar.sc
            font.letterSpacing: 6 * bar.sc
            color: LockTheme.gold
            opacity: LockTheme.seg(bar.grantT, 0.02, 0.16)
            scale: 1.5 - 0.5 * LockTheme.seg(bar.grantT, 0.02, 0.2)
        }

        Row {
            id: totalRow
            anchors.horizontalCenter: parent.horizontalCenter
            y: bar.rowY + 32 * bar.sc
            spacing: 12 * bar.sc
            visible: granted.reward !== null
            opacity: LockTheme.seg(bar.grantT, 0.12, 0.26)

            Text {
                id: totalText
                text: "+" + Math.round((granted.reward ? granted.reward.total : 0) * LockTheme.seg(bar.grantT, 0.15, 0.7)) + " XP"
                font.family: LockTheme.display
                font.pixelSize: 22 * bar.sc
                color: LockTheme.ink
            }

            Text {
                anchors.baseline: totalText.baseline
                visible: granted.reward !== null && granted.reward.multiplier > 1
                text: granted.reward ? "STREAK ×" + granted.reward.multiplier.toFixed(2) : ""
                font.family: LockTheme.mono
                font.pixelSize: 12 * bar.sc
                font.weight: Font.Bold
                font.letterSpacing: 2 * bar.sc
                color: LockTheme.gold
            }
        }

        Flow {
            anchors.horizontalCenter: parent.horizontalCenter
            y: totalRow.y + totalRow.height + 12 * bar.sc
            width: Math.min(parent.width, implicitW)
            spacing: 8 * bar.sc

            // Flow has no implicit width of its own, so size it to one line
            // of chips (capped at the bar width) to keep it centred.
            property real implicitW: {
                let w = 0;
                for (let i = 0; i < children.length; i++)
                    if (children[i].width > 0)
                        w += children[i].width + spacing;
                return Math.max(0, w - spacing);
            }

            Repeater {
                model: granted.reward ? granted.reward.lines : []

                HudPanel {
                    id: chip

                    required property int index
                    required property var modelData
                    readonly property real appear: LockTheme.seg(bar.grantT, 0.2 + index * 0.06, 0.34 + index * 0.06)

                    width: chipRow.implicitWidth + 20 * bar.sc
                    height: 26 * bar.sc
                    cut: 6 * bar.sc
                    accentLength: 10 * bar.sc
                    accent: LockTheme.gold
                    opacity: appear
                    transform: Translate { y: (1 - chip.appear) * 10 * bar.sc }

                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 8 * bar.sc

                        Text {
                            text: chip.modelData.label
                            font.family: LockTheme.mono
                            font.pixelSize: 11 * bar.sc
                            font.weight: Font.Bold
                            font.letterSpacing: 1.5 * bar.sc
                            color: LockTheme.inkDim
                        }

                        Text {
                            text: "+" + chip.modelData.xp
                            font.family: LockTheme.mono
                            font.pixelSize: 11 * bar.sc
                            font.weight: Font.Bold
                            color: LockTheme.gold
                        }
                    }
                }
            }
        }
    }

    NumberAnimation {
        id: grantFx
        target: bar
        property: "grantT"
        from: 0
        to: 1
        duration: 1300
    }

    // ── Status line ──────────────────────────────────────────────────
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        visible: !bar.rewarding
        readonly property bool lastLife: bar.ctx.maxLives > 1 && bar.ctx.lives === 1 && !bar.ctx.lockedOut
        text: bar.ctx.message.length > 0 ? bar.ctx.message.toUpperCase()
            : bar.ctx.capsLock ? "⚠  CAPS LOCK IS ON"
            : lastLife ? "LAST LIFE  ·  ONE MORE MISS LOCKS YOU OUT FOR " + Math.round(bar.ctx.unlockTime / 60) + " MIN"
            : bar.ctx.lockedOut ? "WRONG OR RIGHT, ATTEMPTS FAIL UNTIL THE TIMER ENDS"
            : ""
        font.family: LockTheme.mono
        font.pixelSize: 12 * bar.sc
        font.weight: Font.Bold
        font.letterSpacing: 2.5 * bar.sc
        color: bar.ctx.capsLock || lastLife || bar.ctx.lockedOut ? LockTheme.danger : LockTheme.inkDim
    }

    Item {
        id: fx
        anchors.fill: parent
    }
}
