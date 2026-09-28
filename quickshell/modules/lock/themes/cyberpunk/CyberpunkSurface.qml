pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import qs.components
import qs.modules.lock
import qs.services as Services

// "Black ICE" theme: your deck behind attack barriers (攻性防壁) in a
// rain-slick neon city.
//
// Lock-in: the desktop breaks up like a bad signal (bands tear, the channels
// split, blocks flash and drop out) onto your wallpaper regraded as a
// neon-noir city, rain falling and haze drifting, and the neon stutters on.
// The passcode is a breach: each keystroke drops a code into the buffer (by
// position only, never by what was typed). A wrong one raises the trace (the
// faillock lives); a full trace is an ICE lockout. Getting in pays street
// cred (XP) and data shards (achievements), then the desktop reassembles out
// of the glitch.
//
// Theme contract (see ThemeHost): ctx, shot, shown, still, minScale.
Item {
    id: ice

    required property LockContext ctx
    property url shot
    property bool shown: true
    property bool still: false
    property real minScale: 0.7

    readonly property real sc: Math.max(minScale, Math.min(2, Math.min(width / 1920, height / 1080)))
    readonly property real edge: 60 * sc
    // Picks this lock's buffer codes.
    readonly property real seed: (ctx.lockedAt % 9973) / 9973

    // Choreography.
    property real breakIn: 0
    property real uiIn: 0
    property real alarm: 0
    property real jitter: 0
    property real shakeX: 0
    property real grantIn: 0
    property real rewardIn: 0
    property real levelUp: 0
    property real pulse: 0
    property bool cursorOn: true

    // Street cred on the runner card: follows the stored XP, but counts up
    // from the old value during the reward.
    property real shownXp: Services.LockStats.xp
    readonly property int shownLevel: Services.LockStats.levelFor(shownXp)
    readonly property int levelFloor: Services.LockStats.xpForLevel(shownLevel)
    readonly property int levelCeil: Services.LockStats.xpForLevel(shownLevel + 1)
    property bool rewarding: false
    property int _seenLevel: 0

    readonly property bool granted: ctx.phase === "granted" || ctx.phase === "exiting"
    readonly property var reward: ctx.reward
    readonly property int traced: ctx.maxLives > 0 ? ctx.maxLives - ctx.lives : 0
    readonly property bool hot: ctx.denying || (ctx.lockedOut && ctx.cells === 0)

    // Neon doesn't fade, it stutters: the HUD's opacity as uiIn runs.
    readonly property real lit: {
        const x = uiIn;
        if (x <= 0 || x >= 1)
            return x <= 0 ? 0 : 1;
        return [0.8, 0, 0.3, 1, 0.1, 0.8, 0.4, 1][Math.floor(x * 8)];
    }

    function burst(x, y, count, speed) {
        for (let i = 0; i < count; i++) {
            const a = Math.random() * Math.PI * 2;
            const v = speed * (0.4 + Math.random() * 0.9);
            sparkComp.createObject(fx, {
                x: x - 2,
                y: y - 2,
                vx: Math.cos(a) * v,
                vy: Math.sin(a) * v,
                color: Math.random() < 0.5 ? Neon.a : Neon.b,
                width: (2 + Math.random() * 4) * ice.sc,
                height: (2 + Math.random() * 2) * ice.sc,
                spin: (Math.random() - 0.5) * 360,
                life: 600 + Math.random() * 400
            });
        }
    }

    Component {
        id: sparkComp
        Spark {}
    }

    Component.onCompleted: {
        _seenLevel = shownLevel;
        if (still) {
            breakIn = 1;
            uiIn = 1;
        } else if (shown) {
            startIntro();
        } else {
            introFallback.start();
        }
    }

    onShownLevelChanged: {
        if (rewarding && _seenLevel > 0 && shownLevel > _seenLevel)
            levelUpFx.restart();
        _seenLevel = shownLevel;
    }

    onShownChanged: if (shown && !still) startIntro()

    property bool _introStarted: false

    function startIntro() {
        if (_introStarted)
            return;
        _introStarted = true;
        introFallback.stop();
        intro.start();
    }

    Timer {
        id: introFallback
        interval: 500
        onTriggered: ice.startIntro()
    }

    Connections {
        target: ice.ctx

        function onPhaseChanged() {
            if (ice.ctx.phase === "exiting") {
                intro.stop();
                outro.start();
            }
        }

        function onDenied(costLife) {
            deniedFx.restart();
        }

        function onGranted() {
            const n = Math.min(ice.ctx.cells, breach.slots);
            for (let i = 0; i < n; i++) {
                const p = cellRow.mapToItem(fx, breach.cellX(i) + breach.cellW / 2, breach.cellH / 2);
                ice.burst(p.x, p.y, 5, 160 * ice.sc);
            }
            if (ice.reward) {
                ice.rewarding = true;
                ice.shownXp = ice.reward.xpBefore;
                credFill.restart();
            }
            grantFx.restart();
        }
    }

    NumberAnimation on pulse {
        running: ice.ctx.phase === "verifying"
        from: 0
        to: 1
        duration: 900
        loops: Animation.Infinite
    }

    Timer {
        interval: 530
        repeat: true
        running: !ice.still && ice.ctx.awake && ice.ctx.phase === "ready"
        onRunningChanged: if (!running) ice.cursorOn = true
        onTriggered: ice.cursorOn = !ice.cursorOn
    }

    // ── The city ─────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Neon.night
    }

    Item {
        width: 0
        height: 0
        clip: true

        Image {
            id: wallpaper
            width: ice.width
            height: ice.height
            source: "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
            sourceSize: Qt.size(Math.max(1, ice.width), Math.max(1, ice.height))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }
    }

    ShaderEffect {
        anchors.fill: parent
        visible: wallpaper.status === Image.Ready

        property variant wall: wallpaper
        property real itemWidth: width
        property real itemHeight: height
        property real time: ice.ctx.ambientTime
        property real rain: 1
        property color nightColor: Neon.night
        property color neonA: Neon.a
        property color neonB: Neon.b

        fragmentShader: Qt.resolvedUrl("../../../../shaders/lock_neon_city.frag.qsb")
    }

    LockInput {
        ctx: ice.ctx
        active: !ice.still
        onEscapePressed: ice.ctx.clearInput()
    }

    // ── HUD ──────────────────────────────────────────────────────────
    component Label: Text {
        font.family: Neon.ui
        font.pixelSize: 16 * ice.sc
        font.letterSpacing: 2.5 * ice.sc
        color: Neon.inkDim
    }

    Item {
        id: hud
        anchors.fill: parent
        opacity: ice.lit
        visible: opacity > 0
        transform: Translate { x: ice.shakeX }

        // Title, top left.
        Column {
            x: ice.edge
            y: 44 * ice.sc
            spacing: 6 * ice.sc

            NeonText {
                text: "BLACK ICE"
                family: Neon.logo
                size: 34 * ice.sc
                letterSpacing: 3 * ice.sc
                split: (2 + 8 * ice.jitter) * ice.sc
            }

            Text {
                text: "ブラックアイス  //  攻性防壁"
                font.family: Neon.kana
                font.weight: Font.Bold
                font.pixelSize: 15 * ice.sc
                color: Neon.b
            }

            Row {
                spacing: 12 * ice.sc

                Label {
                    id: sealedLabel
                    text: "DECK SEALED"
                }

                Text {
                    readonly property int s: Math.max(0, Math.floor((ice.ctx.now.getTime() - ice.ctx.lockedAt) / 1000))
                    anchors.baseline: sealedLabel.baseline
                    text: String(Math.floor(s / 3600)).padStart(2, "0") + ":" + String(Math.floor(s / 60) % 60).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0")
                    font.family: Neon.mono
                    font.pixelSize: 14 * ice.sc
                    color: Neon.ink
                }
            }
        }

        // Status, top right.
        Column {
            anchors.right: parent.right
            anchors.rightMargin: ice.edge
            y: 48 * ice.sc
            spacing: 8 * ice.sc

            Row {
                anchors.right: parent.right
                spacing: 10 * ice.sc

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property real pct: Services.Battery.percentage
                    text: "POWER " + Math.round(pct) + "%" + (Services.Battery.charging ? "  AC" : "")
                    color: pct <= 20 && !Services.Battery.charging ? Neon.danger : Neon.inkDim
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2 * ice.sc

                    Repeater {
                        model: 10

                        Rectangle {
                            required property int index
                            width: 6 * ice.sc
                            height: 10 * ice.sc
                            color: (index + 0.5) / 10 <= Services.Battery.percentage / 100 ? Neon.a : Neon.alpha(Neon.ink, 0.15)
                        }
                    }
                }
            }

            Label {
                anchors.right: parent.right
                visible: ice.ctx.layout.length > 0
                text: "KEYMAP " + ice.ctx.layout
            }

            Label {
                anchors.right: parent.right
                visible: ice.ctx.capsLock
                text: "CAPS LOCK ENGAGED"
                color: Neon.hazard
            }
        }

        // The clock, a sign over the street.
        Column {
            id: clockBlock
            anchors.horizontalCenter: parent.horizontalCenter
            y: ice.height * 0.17
            spacing: 10 * ice.sc

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16 * ice.sc

                NeonText {
                    id: clockText
                    text: Qt.formatTime(ice.ctx.now, "hh:mm")
                    size: 150 * ice.sc
                    split: (5 + 16 * ice.jitter) * ice.sc
                }

                Text {
                    anchors.bottom: clockText.bottom
                    anchors.bottomMargin: clockText.height * 0.16
                    text: Qt.formatTime(ice.ctx.now, "ss")
                    font.family: Neon.display
                    font.pixelSize: 38 * ice.sc
                    color: Neon.b
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14 * ice.sc

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Neon.weekdays[ice.ctx.now.getDay()]
                    font.family: Neon.kana
                    font.weight: Font.Black
                    font.pixelSize: 20 * ice.sc
                    color: Neon.b
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "//  " + Qt.formatDate(ice.ctx.now, "ddd d MMM yyyy").toUpperCase() + "  //  " + Neon.shift(ice.ctx.now)
                    font.pixelSize: 20 * ice.sc
                    color: Neon.ink
                }
            }
        }

        // ── The breach ────────────────────────────────────────────────
        Item {
            id: breach

            readonly property int slots: 16
            readonly property real cellW: 42 * ice.sc
            readonly property real cellH: 34 * ice.sc
            readonly property real gap: 8 * ice.sc
            readonly property int count: Math.min(ice.ctx.cells, slots)
            readonly property color tone: ice.hot ? Neon.danger : Neon.a

            function cellX(i) {
                return i * (cellW + gap);
            }

            anchors.horizontalCenter: parent.horizontalCenter
            y: ice.height * 0.52
            width: slots * cellW + (slots - 1) * gap + 64 * ice.sc
            height: 214 * ice.sc

            NeonFrame {
                cut: 26 * ice.sc
                fill: Neon.alpha(Neon.night, 0.82)
                stroke: breach.tone
                edge: ice.hot ? Neon.danger : Neon.b
                strokeWidth: 1.5 * ice.sc
                glow: 1
            }

            // A tab on the left edge, like a connector.
            Rectangle {
                x: 1
                y: 24 * ice.sc
                width: 4 * ice.sc
                height: 40 * ice.sc
                color: breach.tone
            }

            // Header.
            Label {
                x: 32 * ice.sc
                y: 20 * ice.sc
                text: ice.granted ? "BREACH COMPLETE" : "BREACH PROTOCOL"
                color: Neon.b
            }

            Label {
                anchors.right: parent.right
                anchors.rightMargin: 44 * ice.sc
                y: 20 * ice.sc
                text: ice.ctx.lockedOut && ice.ctx.cells === 0 ? "ICE: LOCKED" : ice.granted ? "ICE: DOWN" : "ICE: BLACK"
                color: ice.hot ? Neon.danger : Neon.inkDim
            }

            // The buffer, then the status line and the trace.
            Column {
                x: 32 * ice.sc
                y: 56 * ice.sc
                spacing: 16 * ice.sc
                visible: !ice.granted

                Item {
                    id: cellRow
                    width: breach.slots * breach.cellW + (breach.slots - 1) * breach.gap
                    height: breach.cellH

                    Repeater {
                        model: breach.slots

                        Item {
                            id: cell

                            required property int index
                            readonly property bool filled: index < breach.count
                            // A bump of light running along the buffer while verifying.
                            readonly property real lit: ice.ctx.phase === "verifying"
                                ? Math.max(0, 1 - Math.abs(ice.pulse * (breach.count + 3) - 1.5 - index) / 1.5) : 0

                            x: breach.cellX(index)
                            width: breach.cellW
                            height: breach.cellH

                            onFilledChanged: {
                                if (filled)
                                    pop.restart();
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: cell.filled ? Neon.alpha(breach.tone, 0.12 + 0.3 * cell.lit) : "transparent"
                                border.width: 1
                                border.color: cell.filled ? breach.tone : Neon.alpha(Neon.ink, 0.16)
                            }

                            Text {
                                id: codeText
                                anchors.centerIn: parent
                                visible: cell.filled
                                text: Neon.code(cell.index, ice.seed)
                                font.family: Neon.mono
                                font.pixelSize: 15 * ice.sc
                                font.weight: Font.Bold
                                color: ice.hot ? Neon.danger : Qt.lighter(Neon.a, 1.2 + 0.4 * cell.lit)
                            }

                            NumberAnimation {
                                id: pop
                                target: codeText
                                property: "scale"
                                from: 1.6
                                to: 1
                                duration: 220
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Label {
                        anchors.left: parent.right
                        anchors.leftMargin: 8 * ice.sc
                        anchors.verticalCenter: parent.verticalCenter
                        visible: ice.ctx.cells > breach.slots
                        text: "+" + (ice.ctx.cells - breach.slots)
                        color: Neon.a
                    }
                }

                // Status line.
                Row {
                    spacing: 10 * ice.sc

                    Label {
                        font.pixelSize: 18 * ice.sc
                        text: {
                            const c = ice.ctx;
                            if (c.phase === "verifying")
                                return "UPLOADING DAEMON";
                            if (c.denying)
                                return "ACCESS DENIED  //  侵入失敗";
                            if (c.lockedOut && c.cells === 0)
                                return "TRACED  //  ICE LOCKOUT " + (c.lockoutClock || "");
                            if (c.message.length > 0)
                                return c.message.toUpperCase();
                            if (c.capsLock)
                                return "CAPS LOCK ENGAGED";
                            if (c.lastLife)
                                return "ONE MORE TRACE LOCKS THE DECK FOR " + Math.round(c.unlockTime / 60) + " MIN";
                            if (c.cells > 0)
                                return "BREACHING  //  " + c.cells + (c.cells === 1 ? " BYTE" : " BYTES") + (c.combo >= 5 ? "  ·  CHAIN ×" + c.combo : "");
                            return "> JACK IN: ENTER ACCESS CODE" + (ice.cursorOn ? "_" : " ");
                        }
                        color: ice.hot ? Neon.danger
                            : ice.ctx.message.length > 0 || ice.ctx.capsLock || ice.ctx.lastLife ? Neon.hazard
                            : ice.ctx.phase === "verifying" ? Neon.b : Neon.ink
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: ice.ctx.phase === "verifying"
                        spacing: 3 * ice.sc

                        Repeater {
                            model: 12

                            Rectangle {
                                required property int index
                                width: 8 * ice.sc
                                height: 12 * ice.sc
                                color: index <= Math.floor(ice.pulse * 12) ? Neon.b : Neon.alpha(Neon.ink, 0.12)
                            }
                        }
                    }
                }

                // Trace: how many wrong codes the ICE has seen.
                Row {
                    spacing: 10 * ice.sc

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: 14 * ice.sc
                        text: "TRACE"
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: ice.ctx.maxLives > 0
                        spacing: 3 * ice.sc

                        Repeater {
                            model: Math.min(ice.ctx.maxLives, 6)

                            Rectangle {
                                required property int index
                                width: 26 * ice.sc
                                height: 8 * ice.sc
                                color: index < ice.traced ? Neon.danger : "transparent"
                                border.width: 1
                                border.color: index < ice.traced ? Neon.danger : Neon.alpha(Neon.ink, 0.3)
                            }
                        }
                    }

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: 14 * ice.sc
                        text: ice.ctx.maxLives > 0 ? Math.round(100 * ice.traced / ice.ctx.maxLives) + "%" : "OFF"
                        color: ice.traced > 0 ? Neon.danger : Neon.inkDim
                    }
                }
            }

            // Access granted, and the street cred it paid.
            Column {
                x: 32 * ice.sc
                y: 52 * ice.sc
                spacing: 8 * ice.sc
                visible: ice.granted
                opacity: ice.grantIn

                Row {
                    spacing: 18 * ice.sc

                    NeonText {
                        id: grantedText
                        text: "ACCESS GRANTED"
                        family: Neon.logo
                        size: 40 * ice.sc
                        letterSpacing: 2 * ice.sc
                        split: 3 * ice.sc
                    }

                    Text {
                        anchors.bottom: grantedText.bottom
                        anchors.bottomMargin: 6 * ice.sc
                        text: "接続完了  //  WELCOME BACK, " + ice.ctx.userName.toUpperCase()
                        font.family: Neon.kana
                        font.weight: Font.Bold
                        font.pixelSize: 15 * ice.sc
                        color: Neon.b
                    }
                }

                Column {
                    visible: ice.reward !== null
                    opacity: ice.rewardIn
                    spacing: 6 * ice.sc

                    Text {
                        text: "+" + Math.round((ice.reward ? ice.reward.total : 0) * Math.min(1, ice.rewardIn * 1.3)) + " STREET CRED"
                        font.family: Neon.display
                        font.pixelSize: 26 * ice.sc
                        color: Neon.a
                    }

                    Text {
                        width: breach.width - 64 * ice.sc
                        elide: Text.ElideRight
                        text: ice.reward
                            ? ice.reward.lines.map(l => l.label.toLowerCase() + " +" + l.xp).join("  ·  ")
                              + (ice.reward.multiplier > 1 ? "  ·  streak ×" + ice.reward.multiplier.toFixed(2) : "")
                            : ""
                        font.family: Neon.mono
                        font.pixelSize: 13 * ice.sc
                        color: Neon.inkDim
                    }

                    Label {
                        visible: ice.levelUp > 0
                        opacity: ice.levelUp
                        text: "CRED LEVEL UP  //  " + ice.shownLevel + "  ·  " + Services.LockStats.rankFor(ice.shownLevel)
                        color: Neon.hazard
                    }
                }
            }
        }

        // Data shards (achievements), top right.
        Column {
            anchors.right: parent.right
            anchors.rightMargin: ice.edge
            y: 150 * ice.sc
            spacing: 10 * ice.sc
            visible: ice.granted

            Repeater {
                model: ice.reward ? ice.reward.achievements.slice(0, 3) : []

                Item {
                    id: shard
                    required property int index
                    required property var modelData
                    readonly property real appear: LockTheme.seg(ice.rewardIn, 0.15 + index * 0.18, 0.45 + index * 0.18)
                    width: 420 * ice.sc
                    height: 60 * ice.sc
                    opacity: appear
                    transform: Translate { x: (1 - shard.appear) * 40 * ice.sc }

                    NeonFrame {
                        cut: 14 * ice.sc
                        fill: Neon.alpha(Neon.night, 0.88)
                        glow: 0.8
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 18 * ice.sc
                        spacing: 14 * ice.sc

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            text: shard.modelData.icon
                            filled: true
                            font.pixelSize: 22 * ice.sc
                            color: Neon.a
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter

                            Label {
                                text: "DATA SHARD  //  " + shard.modelData.name.toUpperCase()
                                font.pixelSize: 15 * ice.sc
                                color: Neon.ink
                            }

                            Text {
                                text: shard.modelData.desc
                                font.family: Neon.mono
                                font.pixelSize: 11 * ice.sc
                                color: Neon.inkDim
                            }
                        }
                    }
                }
            }
        }

        // The runner, bottom left.
        Row {
            x: ice.edge
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 46 * ice.sc
            spacing: 20 * ice.sc

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 84 * ice.sc
                height: width

                Image {
                    id: avatar
                    anchors.fill: parent
                    anchors.margins: 4 * ice.sc
                    source: "file://" + Quickshell.env("HOME") + "/.cache/current_avatar"
                    sourceSize: Qt.size(width * 2, height * 2)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    visible: false
                }

                MultiEffect {
                    anchors.fill: avatar
                    source: avatar
                    visible: avatar.status === Image.Ready
                    maskEnabled: true
                    maskSource: avatarMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                    saturation: -0.4
                    colorization: 0.25
                    colorizationColor: Neon.b
                }

                NeonMask {
                    id: avatarMask
                    anchors.fill: avatar
                    cut: 14 * ice.sc
                    active: true
                }

                NeonFrame {
                    cut: 16 * ice.sc
                    fill: "transparent"
                    glow: 0.8
                    strokeWidth: 1.5 * ice.sc
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5 * ice.sc

                Row {
                    spacing: 10 * ice.sc

                    Label {
                        anchors.baseline: runnerName.baseline
                        text: "NETRUNNER  //"
                        color: Neon.b
                    }

                    Text {
                        id: runnerName
                        text: ice.ctx.userName.toUpperCase()
                        font.family: Neon.logo
                        font.pixelSize: 20 * ice.sc
                        color: Neon.ink
                    }
                }

                Label {
                    text: "STREET CRED " + ice.shownLevel + "  ·  " + Services.LockStats.rankFor(ice.shownLevel)
                    color: Neon.a
                }

                Row {
                    id: credRow
                    spacing: 8 * ice.sc

                    readonly property real progress: Math.max(0, Math.min(1, (ice.shownXp - ice.levelFloor) / Math.max(1, ice.levelCeil - ice.levelFloor)))

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2 * ice.sc

                        Repeater {
                            model: 20

                            Rectangle {
                                required property int index
                                width: 9 * ice.sc
                                height: 6 * ice.sc
                                color: (index + 0.5) / 20 <= credRow.progress ? Neon.a : Neon.alpha(Neon.ink, 0.15)
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.floor(ice.shownXp - ice.levelFloor) + " / " + (ice.levelCeil - ice.levelFloor)
                        font.family: Neon.mono
                        font.pixelSize: 11 * ice.sc
                        color: Neon.inkDim
                    }
                }

                Label {
                    font.pixelSize: 13 * ice.sc
                    text: "STREAK " + Services.LockStats.liveStreak + "D  ·  SHARDS " + Services.LockStats.achievements.length + "/" + Services.LockStats.achievementDefs.length
                }
            }
        }

        // Now playing, bottom centre.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 54 * ice.sc
            spacing: 12 * ice.sc
            visible: Services.Media.activePlayer !== null

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: "NOW PLAYING  //"
                color: Neon.b
            }

            Repeater {
                // Static model: only the icon follows play/pause.
                model: ["previous", "playPause", "next"]

                Glyph {
                    id: mediaKey
                    required property string modelData
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData === "playPause" ? (Services.Media.isPlaying ? "pause" : "play_arrow") : modelData === "previous" ? "skip_previous" : "skip_next"
                    filled: true
                    font.pixelSize: 20 * ice.sc
                    color: mediaArea.containsMouse ? Neon.a : Neon.ink

                    MouseArea {
                        id: mediaArea
                        anchors.fill: parent
                        anchors.margins: -6 * ice.sc
                        enabled: !ice.still
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.Media[mediaKey.modelData]()
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 440 * ice.sc)
                elide: Text.ElideRight
                text: Services.Media.title + (Services.Media.artist ? "  —  " + Services.Media.artist : "")
                font.family: Neon.ui
                font.pixelSize: 17 * ice.sc
                font.letterSpacing: 1 * ice.sc
                color: Neon.ink
            }
        }

        // Power, bottom right: hold to confirm.
        Column {
            anchors.right: parent.right
            anchors.rightMargin: ice.edge
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 40 * ice.sc
            spacing: 8 * ice.sc

            Row {
                spacing: 12 * ice.sc

                Repeater {
                    model: [
                        { label: "SLEEP", act: "suspend" },
                        { label: "REBOOT", act: "reboot" },
                        { label: "HALT", act: "poweroff" }
                    ]

                    Item {
                        id: key
                        required property var modelData
                        width: 108 * ice.sc
                        height: 40 * ice.sc

                        NeonFrame {
                            cut: 10 * ice.sc
                            fill: Neon.alpha(Neon.night, keyHold.containsMouse ? 0.95 : 0.75)
                            glow: keyHold.containsMouse ? 1 : 0.4
                        }

                        Rectangle {
                            x: 3 * ice.sc
                            y: 3 * ice.sc
                            width: (parent.width - 6 * ice.sc) * keyHold.progress
                            height: parent.height - 6 * ice.sc
                            color: Neon.alpha(Neon.a, 0.3)
                        }

                        Label {
                            anchors.centerIn: parent
                            text: key.modelData.label
                            color: keyHold.containsMouse || keyHold.progress > 0 ? Neon.a : Neon.ink
                        }

                        HoldArea {
                            id: keyHold
                            anchors.fill: parent
                            enabled: !ice.still
                            onConfirmed: ice.ctx[key.modelData.act]()
                        }
                    }
                }
            }

            Label {
                anchors.right: parent.right
                font.pixelSize: 12 * ice.sc
                text: "HOLD TO EXECUTE"
                color: Neon.alpha(Neon.ink, 0.4)
            }
        }
    }

    // Shards of ICE.
    Item {
        id: fx
        anchors.fill: parent
    }

    // A red wash when the ICE bites back.
    Rectangle {
        anchors.fill: parent
        color: Neon.danger
        opacity: ice.alarm * 0.16
        visible: opacity > 0
    }

    // ── The desktop, glitching out ───────────────────────────────────
    CaptureImage {
        id: capture
        source: ice.shot
        imageWidth: ice.width
        imageHeight: ice.height
    }

    ShaderEffect {
        anchors.fill: parent
        visible: capture.ready && ice.breakIn < 1

        property variant source: capture.image
        property real itemWidth: width
        property real itemHeight: height
        property real progress: ice.breakIn
        property color neonA: Neon.a
        property color neonB: Neon.b

        fragmentShader: Qt.resolvedUrl("../../../../shaders/lock_glitch.frag.qsb")
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        visible: !capture.ready && opacity > 0
        opacity: 1 - ice.breakIn
    }

    // ── Choreography ─────────────────────────────────────────────────
    ParallelAnimation {
        id: intro
        SequentialAnimation {
            PauseAnimation { duration: 80 }
            NumberAnimation { target: ice; property: "breakIn"; from: 0; to: 1; duration: 720; easing.type: Easing.InQuad }
        }
        SequentialAnimation {
            PauseAnimation { duration: 640 }
            NumberAnimation { target: ice; property: "uiIn"; from: 0; to: 1; duration: 560 }
        }
    }

    // The neon stutters off and the desktop reassembles out of the glitch:
    // the last frame is the desktop exactly.
    ParallelAnimation {
        id: outro
        NumberAnimation { target: ice; property: "uiIn"; to: 0; duration: 300 }
        SequentialAnimation {
            PauseAnimation { duration: 220 }
            NumberAnimation { target: ice; property: "breakIn"; to: 0; duration: 700; easing.type: Easing.OutQuad }
        }
    }

    ParallelAnimation {
        id: deniedFx
        SequentialAnimation {
            NumberAnimation { target: ice; property: "alarm"; to: 1; duration: 60 }
            NumberAnimation { target: ice; property: "alarm"; to: 0; duration: 600 }
        }
        SequentialAnimation {
            NumberAnimation { target: ice; property: "jitter"; to: 1; duration: 50 }
            PauseAnimation { duration: 160 }
            NumberAnimation { target: ice; property: "jitter"; to: 0; duration: 300 }
        }
        SequentialAnimation {
            NumberAnimation { target: ice; property: "shakeX"; to: -14 * ice.sc; duration: 40 }
            NumberAnimation { target: ice; property: "shakeX"; to: 11 * ice.sc; duration: 60 }
            NumberAnimation { target: ice; property: "shakeX"; to: -6 * ice.sc; duration: 60 }
            NumberAnimation { target: ice; property: "shakeX"; to: 3 * ice.sc; duration: 60 }
            NumberAnimation { target: ice; property: "shakeX"; to: 0; duration: 70 }
        }
    }

    ParallelAnimation {
        id: grantFx
        NumberAnimation { target: ice; property: "grantIn"; from: 0; to: 1; duration: 260 }
        SequentialAnimation {
            PauseAnimation { duration: 250 }
            NumberAnimation { target: ice; property: "rewardIn"; from: 0; to: 1; duration: 750 }
        }
    }

    SequentialAnimation {
        id: credFill
        PauseAnimation { duration: 400 }
        NumberAnimation {
            target: ice
            property: "shownXp"
            to: ice.reward ? ice.reward.xpAfter : 0
            duration: 800
            easing.type: Easing.InOutCubic
        }
        PropertyAction { target: ice; property: "rewarding"; value: false }
    }

    NumberAnimation {
        id: levelUpFx
        target: ice
        property: "levelUp"
        from: 0
        to: 1
        duration: 300
    }
}
