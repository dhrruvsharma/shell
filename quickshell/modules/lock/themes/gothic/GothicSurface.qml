pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs.components
import qs.modules.lock
import qs.services as Services

// "Rose Window" theme: a Gothic cathedral at vespers.
//
// Lock-in: the desktop turns to leaded glass, each pane settling into one
// colour, then darkens and falls away into the nave: your wallpaper in
// shadow and stone, shafts of coloured light and dust falling through it,
// and a great rose window glazed in the wallpaper's colours. The passcode
// lights the window: a lancet per keystroke, then the roundels. A wrong one
// cracks a pane (the cracks stay) and snuffs a candle, the faillock lives;
// a lockout bars the doors. Coming home floods the window with light, lays
// the stones (XP) and raises you in the masons' lodge; then the glass falls
// back into place as the desktop.
//
// Theme contract (see ThemeHost): ctx, shot, shown, still, minScale.
Item {
    id: nave

    required property LockContext ctx
    property url shot
    property bool shown: true
    property bool still: false
    property real minScale: 0.7

    readonly property real sc: Math.max(minScale, Math.min(2, Math.min(width / 1920, height / 1080)))
    readonly property real edge: 64 * sc

    // Choreography.
    property real glass: 0
    property real uiIn: 0
    property real glow: 1
    property real bloom: 0
    property real shakeX: 0
    property real grantIn: 0
    property real rewardIn: 0
    property real promote: 0

    // Lancets lit, a keystroke at a time; then the roundels.
    readonly property real litTarget: granted ? 12 : still ? 7 : Math.min(ctx.cells, 12)
    readonly property real innerTarget: granted ? 12 : still ? 0 : Math.max(0, Math.min(ctx.cells - 12, 12))
    property real lit: litTarget
    property real litInner: innerTarget
    Behavior on lit {
        NumberAnimation {
            duration: nave.granted ? 600 : 260
            easing.type: Easing.OutCubic
        }
    }
    Behavior on litInner {
        NumberAnimation { duration: 260 }
    }

    // Cracked lancets, one per rejected passcode (up to four).
    property var crackList: []
    readonly property vector4d cracks: Qt.vector4d(crackList[0] ?? -1, crackList[1] ?? -1, crackList[2] ?? -1, crackList[3] ?? -1)

    // Stones laid (XP) on the card: follow the stored XP, but run up from the
    // old value during the reward.
    property real shownXp: Services.LockStats.xp
    readonly property int shownLevel: Services.LockStats.levelFor(shownXp)
    readonly property int levelFloor: Services.LockStats.xpForLevel(shownLevel)
    readonly property int levelCeil: Services.LockStats.xpForLevel(shownLevel + 1)
    property bool rewarding: false
    property int _seenLevel: 0

    readonly property bool granted: ctx.phase === "granted" || ctx.phase === "exiting"
    readonly property var reward: ctx.reward
    readonly property bool barred: ctx.lockedOut && ctx.cells === 0
    readonly property var hm: Qt.formatDateTime(ctx.now, "h:mm AP").split(" ")
    readonly property var hour: Gothic.canonicalHour(ctx.now)
    readonly property var season: Gothic.season(ctx.now)
    readonly property color ruby: "#e0584a"

    Component.onCompleted: {
        _seenLevel = shownLevel;
        if (still) {
            glass = 1;
            uiIn = 1;
        } else if (shown) {
            startIntro();
        } else {
            introFallback.start();
        }
    }

    onShownLevelChanged: {
        if (rewarding && _seenLevel > 0 && shownLevel > _seenLevel)
            promoteFx.restart();
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
        onTriggered: nave.startIntro()
    }

    Connections {
        target: nave.ctx

        function onPhaseChanged() {
            if (nave.ctx.phase === "exiting") {
                intro.stop();
                outro.start();
            }
        }

        function onDenied(costLife) {
            if (nave.crackList.length < 4 && nave.lit > 0.5) {
                const k = Math.max(0, Math.min(11, Math.ceil(nave.lit) - 1));
                if (!nave.crackList.includes(k)) {
                    const list = nave.crackList.slice();
                    list.push(k);
                    nave.crackList = list;
                }
            }
            deniedFx.restart();
        }

        function onGranted() {
            if (nave.reward) {
                nave.rewarding = true;
                nave.shownXp = nave.reward.xpBefore;
                stonesFill.restart();
            }
            grantFx.restart();
        }
    }

    // The window breathes while the bells ring (verifying).
    SequentialAnimation on glow {
        running: nave.ctx.phase === "verifying"
        loops: Animation.Infinite
        onRunningChanged: if (!running) nave.glow = nave.barred ? 0.35 : 1
        NumberAnimation { to: 1.35; duration: 420; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.8; duration: 420; easing.type: Easing.InOutSine }
    }

    onBarredChanged: glow = barred ? 0.35 : 1

    // ── The nave ─────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#07070a"
    }

    Image {
        id: wallpaper
        anchors.fill: parent
        source: "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
        sourceSize: Qt.size(Math.max(1, width), Math.max(1, height))
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: false
    }

    // The wallpaper in shadow and stone.
    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        visible: wallpaper.status === Image.Ready
        saturation: -0.55
        brightness: -0.42
        contrast: 0.08
        colorization: 0.18
        colorizationColor: "#6d6452"
    }

    // Coloured light and dust through the high windows.
    ShaderEffect {
        anchors.fill: parent

        property real itemWidth: width
        property real itemHeight: height
        property real light: 1
        property real lineScale: nave.sc
        property color glassA: Gothic.glassA
        property color glassB: Gothic.glassB
        property color glassC: Gothic.glassC
        property color glassD: Gothic.glassD
        property color stoneColor: "#050505"
        property color candleColor: Gothic.candle

        fragmentShader: Qt.resolvedUrl("../../../../shaders/desktop_glass.frag.qsb")
    }

    LockInput {
        ctx: nave.ctx
        active: !nave.still
        onEscapePressed: nave.ctx.clearInput()
    }

    // ── The rose ─────────────────────────────────────────────────────
    Item {
        id: roseHolder
        readonly property real size: 590 * nave.sc
        x: nave.width * 0.33 - size / 2
        y: nave.height * 0.46 - size / 2
        width: size
        height: size
        transform: Translate { x: nave.shakeX }

        // The light behind it.
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 1.25
            height: width
            radius: width / 2
            color: Qt.rgba(1, 0.86, 0.6, 0.12 + 0.1 * Math.min(1, nave.lit / 12) * nave.glow + 0.25 * nave.bloom)
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1
                blurMax: 64
            }
        }

        RoseWindow {
            anchors.fill: parent
            lit: nave.lit
            litInner: nave.litInner
            glow: Math.min(1.35, nave.glow)
            bloom: nave.bloom
            wallMix: 0.72
            cracks: nave.cracks
        }
    }

    // ── The hours, and what the window is doing ──────────────────────
    component Book: Text {
        font.family: Gothic.book
        font.pixelSize: 22 * nave.sc
        color: Gothic.parchment
    }

    Column {
        id: hours
        x: nave.width * 0.6
        anchors.verticalCenter: roseHolder.verticalCenter
        spacing: 4 * nave.sc
        opacity: nave.uiIn

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.8
            shadowBlur: 0.8
            blurMax: 32
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 2
        }

        Row {
            spacing: 16 * nave.sc

            Text {
                id: time
                text: nave.hm[0]
                font.family: Gothic.blackletter
                font.pixelSize: 150 * nave.sc
                color: Gothic.parchment
            }

            Text {
                anchors.baseline: time.baseline
                text: nave.hm[1] ?? ""
                font.family: Gothic.caps
                font.pixelSize: 30 * nave.sc
                font.weight: Font.Bold
                color: Gothic.glassC
            }
        }

        Book {
            text: nave.hour.en + "  ·  " + nave.hour.gloss
            font.pixelSize: 28 * nave.sc
            font.italic: true
            color: Gothic.glassC
        }

        Book {
            text: Gothic.date(nave.ctx.now)
            font.pixelSize: 24 * nave.sc
        }

        Text {
            topPadding: 4 * nave.sc
            text: (Gothic.year(nave.ctx.now) + "  ·  " + nave.season.la).toUpperCase()
            font.family: Gothic.caps
            font.pixelSize: 15 * nave.sc
            font.weight: Font.Bold
            font.letterSpacing: 3 * nave.sc
            color: Gothic.alpha(Gothic.parchment, 0.75)
        }

        // A rule with a quatrefoil.
        Item {
            width: 440 * nave.sc
            height: 40 * nave.sc

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: Math.max(1, nave.sc)
                color: Gothic.alpha(Gothic.glassC, 0.55)
            }

            Rectangle {
                anchors.centerIn: parent
                width: 14 * nave.sc
                height: width
                rotation: 45
                color: "#0b0a09"
                border.width: Math.max(1, nave.sc)
                border.color: Gothic.glassC
            }
        }

        // What the window is doing.
        Text {
            readonly property var c: nave.ctx
            text: nave.granted ? "Welcome home, " + c.userName
                : c.phase === "verifying" ? "The bells are ringing…"
                : c.denying ? "A pane cracks"
                : nave.barred ? "The doors are barred"
                : c.cells > 0 ? (c.cells === 1 ? "One pane alight" : c.cells + " panes alight")
                : "Light the window"
            font.family: Gothic.gotisch
            font.pixelSize: 40 * nave.sc
            font.weight: Font.Medium
            color: c.denying || nave.barred ? nave.ruby : nave.granted ? Gothic.glassC : Gothic.parchment
        }

        Book {
            readonly property var c: nave.ctx
            text: nave.granted
                ? (nave.reward ? "+" + Math.round(nave.reward.total * Math.min(1, nave.rewardIn * 1.3)) + " stones laid" + (nave.promote > 0 ? "  ·  raised to " + Gothic.rank(nave.shownLevel) : "") : "")
                : c.message.length > 0 ? c.message
                : nave.barred ? "they open again in " + (c.lockoutClock || "a while")
                : c.capsLock ? "caps lock is on"
                : c.lastLife ? "one more crack and the doors are barred for " + Math.round(c.unlockTime / 60) + " minutes"
                : c.denying ? "the light goes out; try again"
                : c.cells > 0 ? (c.combo >= 6 ? "a steady hand" : "keep going, then press Enter")
                : "type your password; each letter lights a pane"
            font.pixelSize: 20 * nave.sc
            font.italic: true
            opacity: nave.granted ? nave.rewardIn : 1
            color: !nave.granted && (c.message.length > 0 || nave.barred || c.capsLock || c.lastLife) ? nave.ruby : Gothic.alpha(Gothic.parchment, 0.8)
        }

        Book {
            visible: nave.granted && nave.reward !== null
            width: Math.min(implicitWidth, nave.width * 0.36)
            elide: Text.ElideRight
            opacity: nave.rewardIn
            text: nave.reward
                ? nave.reward.lines.map(l => l.label.toLowerCase() + " +" + l.xp).join("  ·  ")
                  + (nave.reward.multiplier > 1 ? "  ·  streak ×" + nave.reward.multiplier.toFixed(2) : "")
                : ""
            font.pixelSize: 16 * nave.sc
            color: Gothic.alpha(Gothic.parchment, 0.65)
        }

        // The candles: the faillock lives.
        Row {
            topPadding: 14 * nave.sc
            spacing: 18 * nave.sc
            visible: !nave.granted && nave.ctx.maxLives > 0

            Repeater {
                model: nave.ctx.maxLives

                Candle {
                    required property int index
                    size: nave.sc * 0.8
                    lit: index < nave.ctx.lives
                    time: nave.ctx.ambientTime
                    seed: index * 1.7
                }
            }
        }
    }

    // ── Around the edges ─────────────────────────────────────────────
    Item {
        anchors.fill: parent
        opacity: nave.uiIn

        Column {
            x: nave.edge
            y: 40 * nave.sc
            spacing: 2 * nave.sc

            Text {
                text: "The Rose Window"
                font.family: Gothic.gotisch
                font.pixelSize: 26 * nave.sc
                color: Gothic.parchment
            }

            Book {
                readonly property int s: Math.max(0, Math.floor((nave.ctx.now.getTime() - nave.ctx.lockedAt) / 1000))
                text: "a vigil of " + Math.floor(s / 3600) + ":" + String(Math.floor(s / 60) % 60).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0")
                font.pixelSize: 16 * nave.sc
                font.italic: true
                color: Gothic.alpha(Gothic.parchment, 0.65)
            }
        }

        Column {
            anchors.right: parent.right
            anchors.rightMargin: nave.edge
            y: 42 * nave.sc
            spacing: 2 * nave.sc

            Book {
                anchors.right: parent.right
                readonly property real pct: Services.Battery.percentage
                text: "lamp oil " + Math.round(pct) + "%" + (Services.Battery.charging ? ", filling" : "")
                font.pixelSize: 17 * nave.sc
                font.italic: true
                color: pct <= 20 && !Services.Battery.charging ? nave.ruby : Gothic.alpha(Gothic.parchment, 0.7)
            }

            Book {
                anchors.right: parent.right
                visible: nave.ctx.capsLock
                text: "caps lock"
                font.pixelSize: 16 * nave.sc
                font.italic: true
                color: nave.ruby
            }
        }

        // New carvings (achievements), top right.
        Column {
            anchors.right: parent.right
            anchors.rightMargin: nave.edge
            y: 110 * nave.sc
            spacing: 12 * nave.sc
            visible: nave.granted

            Repeater {
                model: nave.reward ? nave.reward.achievements.slice(0, 3) : []

                Item {
                    id: slip
                    required property int index
                    required property var modelData
                    readonly property real appear: LockTheme.seg(nave.rewardIn, 0.15 + index * 0.18, 0.45 + index * 0.18)
                    width: 420 * nave.sc
                    height: 66 * nave.sc
                    opacity: appear
                    transform: Translate { y: (1 - slip.appear) * -16 * nave.sc }

                    CuspFrame {
                        cut: 10 * nave.sc
                        fill: Gothic.parchment
                        stroke: Gothic.glassC
                        strokeWidth: Math.max(1, 1.5 * nave.sc)
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 22 * nave.sc
                        spacing: 14 * nave.sc

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            text: slip.modelData.icon
                            filled: true
                            font.pixelSize: 24 * nave.sc
                            color: "#8a5a18"
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: "A new carving: " + slip.modelData.name
                                font.family: Gothic.gotisch
                                font.pixelSize: 19 * nave.sc
                                color: Gothic.ink
                            }

                            Text {
                                text: slip.modelData.desc
                                font.family: Gothic.book
                                font.pixelSize: 14 * nave.sc
                                font.italic: true
                                color: Gothic.alpha(Gothic.ink, 0.75)
                            }
                        }
                    }
                }
            }
        }

        // The mason, bottom left.
        Row {
            x: nave.edge
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 50 * nave.sc
            spacing: 22 * nave.sc

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 82 * nave.sc
                height: 104 * nave.sc

                Shape {
                    id: archMask
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: "white"
                        strokeColor: "transparent"

                        PathPolyline {
                            path: ThemeShapes.arch(0, 0, archMask.width, archMask.height, archMask.width * 0.5)
                        }
                    }
                }

                Image {
                    id: avatar
                    anchors.fill: parent
                    source: "file://" + Quickshell.env("HOME") + "/.cache/current_avatar"
                    sourceSize: Qt.size(width * 2, height * 2)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    visible: false
                }

                MultiEffect {
                    anchors.fill: parent
                    source: avatar
                    visible: avatar.status === Image.Ready
                    maskEnabled: true
                    maskSource: archMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                    saturation: -0.3
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: "#060505"
                        strokeWidth: 4 * nave.sc
                        joinStyle: ShapePath.RoundJoin

                        PathPolyline {
                            path: ThemeShapes.arch(1, 1, archMask.width - 2, archMask.height - 2, archMask.width * 0.5)
                        }
                    }

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Gothic.glassC
                        strokeWidth: 1.5 * nave.sc
                        joinStyle: ShapePath.RoundJoin

                        PathPolyline {
                            path: ThemeShapes.arch(4 * nave.sc, 4 * nave.sc, archMask.width - 8 * nave.sc, archMask.height - 8 * nave.sc, archMask.width * 0.5 - 4 * nave.sc)
                        }
                    }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5 * nave.sc

                Row {
                    spacing: 12 * nave.sc

                    Text {
                        id: nameText
                        text: nave.ctx.userName
                        font.family: Gothic.gotisch
                        font.pixelSize: 32 * nave.sc
                        color: Gothic.parchment
                    }

                    Book {
                        anchors.baseline: nameText.baseline
                        text: Gothic.rank(nave.shownLevel) + " of the lodge"
                        font.pixelSize: 18 * nave.sc
                        font.italic: true
                        color: nave.promote > 0 ? Gothic.candle : Gothic.glassC
                    }
                }

                // Stones towards the next rank, as a strip of leaded glass.
                Row {
                    id: stones
                    spacing: 2 * nave.sc
                    readonly property real progress: Math.max(0, Math.min(1, (nave.shownXp - nave.levelFloor) / Math.max(1, nave.levelCeil - nave.levelFloor)))

                    Repeater {
                        model: 18

                        Rectangle {
                            required property int index
                            readonly property var panes: [Gothic.glassA, Gothic.glassC, Gothic.glassB, Gothic.glassD]
                            width: 16 * nave.sc
                            height: 9 * nave.sc
                            color: panes[index % 4]
                            opacity: (index + 0.5) / 18 <= stones.progress ? 0.95 : 0.16
                            border.width: Math.max(1, nave.sc)
                            border.color: "#060505"
                        }
                    }
                }

                Book {
                    text: Math.floor(nave.shownXp - nave.levelFloor) + " / " + (nave.levelCeil - nave.levelFloor) + " stones laid"
                        + "  ·  " + Services.LockStats.liveStreak + " days in a row"
                        + "  ·  " + Services.LockStats.achievements.length + "/" + Services.LockStats.achievementDefs.length + " carvings"
                    font.pixelSize: 15 * nave.sc
                    color: Gothic.alpha(Gothic.parchment, 0.65)
                }
            }
        }

        // The choir, bottom centre.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: 60 * nave.sc
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 58 * nave.sc
            spacing: 12 * nave.sc
            visible: Services.Media.activePlayer !== null

            Repeater {
                // Static model: only the icon follows play/pause.
                model: ["previous", "playPause", "next"]

                Glyph {
                    id: mediaKey
                    required property string modelData
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData === "playPause" ? (Services.Media.isPlaying ? "pause" : "play_arrow") : modelData === "previous" ? "skip_previous" : "skip_next"
                    filled: true
                    font.pixelSize: 20 * nave.sc
                    color: mediaArea.containsMouse ? Gothic.glassC : Gothic.alpha(Gothic.parchment, 0.75)

                    MouseArea {
                        id: mediaArea
                        anchors.fill: parent
                        anchors.margins: -6 * nave.sc
                        enabled: !nave.still
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.Media[mediaKey.modelData]()
                    }
                }
            }

            Book {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 460 * nave.sc)
                elide: Text.ElideRight
                text: "the choir sings " + Services.Media.title + (Services.Media.artist ? ", by " + Services.Media.artist : "")
                font.pixelSize: 17 * nave.sc
                font.italic: true
            }
        }

        // The doors, bottom right: hold one to go through it.
        Row {
            anchors.right: parent.right
            anchors.rightMargin: nave.edge
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 42 * nave.sc
            spacing: 20 * nave.sc

            Repeater {
                model: [
                    { label: "rest", icon: "bedtime", act: "suspend" },
                    { label: "toll again", icon: "restart_alt", act: "reboot" },
                    { label: "close the doors", icon: "power_settings_new", act: "poweroff" }
                ]

                Column {
                    id: door
                    required property var modelData
                    spacing: 6 * nave.sc

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 46 * nave.sc
                        height: 58 * nave.sc

                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                fillColor: doorHold.containsMouse ? "#1c1814" : "#0f0d0b"
                                strokeColor: Gothic.alpha(Gothic.glassC, 0.8)
                                strokeWidth: Math.max(1, 1.5 * nave.sc)
                                joinStyle: ShapePath.RoundJoin

                                PathPolyline {
                                    path: ThemeShapes.arch(1, 1, 44 * nave.sc, 56 * nave.sc, 22 * nave.sc)
                                }
                            }
                        }

                        // Held: light fills the doorway from the floor.
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2 * nave.sc
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - 6 * nave.sc
                            height: (parent.height * 0.62) * doorHold.progress
                            color: Gothic.alpha(Gothic.candle, 0.55)
                        }

                        Glyph {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 12 * nave.sc
                            text: door.modelData.icon
                            font.pixelSize: 20 * nave.sc
                            color: Gothic.parchment
                        }

                        HoldArea {
                            id: doorHold
                            anchors.fill: parent
                            enabled: !nave.still
                            onConfirmed: nave.ctx[door.modelData.act]()
                        }
                    }

                    Book {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: door.modelData.label
                        font.pixelSize: 14 * nave.sc
                        font.italic: true
                        color: Gothic.alpha(Gothic.parchment, 0.7)
                    }
                }
            }
        }
    }

    // ── The desktop, turning to glass ────────────────────────────────
    CaptureImage {
        id: capture
        source: nave.shot
        imageWidth: nave.width
        imageHeight: nave.height
    }

    ShaderEffect {
        anchors.fill: parent
        visible: capture.ready && nave.glass < 1

        property variant source: capture.image
        property real itemWidth: width
        property real itemHeight: height
        property real progress: nave.glass
        property real cell: 70 * nave.sc
        property color leadColor: Gothic.lead

        fragmentShader: Qt.resolvedUrl("../../../../shaders/lock_leaded.frag.qsb")
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        visible: !capture.ready && opacity > 0
        opacity: 1 - nave.glass
    }

    // ── Choreography ─────────────────────────────────────────────────
    ParallelAnimation {
        id: intro
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation { target: nave; property: "glass"; from: 0; to: 1; duration: 1300; easing.type: Easing.InOutSine }
        }
        SequentialAnimation {
            PauseAnimation { duration: 950 }
            NumberAnimation { target: nave; property: "uiIn"; from: 0; to: 1; duration: 550; easing.type: Easing.OutCubic }
        }
    }

    // The glass falls back into place as the desktop: the last frame is the
    // desktop exactly.
    ParallelAnimation {
        id: outro
        NumberAnimation { target: nave; property: "uiIn"; to: 0; duration: 280 }
        SequentialAnimation {
            PauseAnimation { duration: 160 }
            NumberAnimation { target: nave; property: "glass"; to: 0; duration: 940; easing.type: Easing.InOutSine }
        }
    }

    ParallelAnimation {
        id: deniedFx
        SequentialAnimation {
            NumberAnimation { target: nave; property: "shakeX"; to: -9 * nave.sc; duration: 50 }
            NumberAnimation { target: nave; property: "shakeX"; to: 7 * nave.sc; duration: 70 }
            NumberAnimation { target: nave; property: "shakeX"; to: -3 * nave.sc; duration: 70 }
            NumberAnimation { target: nave; property: "shakeX"; to: 0; duration: 80 }
        }
        SequentialAnimation {
            NumberAnimation { target: nave; property: "glow"; to: 0.3; duration: 80 }
            NumberAnimation { target: nave; property: "glow"; to: nave.barred ? 0.35 : 1; duration: 700 }
        }
    }

    ParallelAnimation {
        id: grantFx
        NumberAnimation { target: nave; property: "grantIn"; from: 0; to: 1; duration: 400 }
        SequentialAnimation {
            PauseAnimation { duration: 450 }
            NumberAnimation { target: nave; property: "bloom"; from: 0; to: 0.85; duration: 500; easing.type: Easing.OutCubic }
            NumberAnimation { target: nave; property: "bloom"; to: 0.35; duration: 700; easing.type: Easing.InOutSine }
        }
        SequentialAnimation {
            PauseAnimation { duration: 350 }
            NumberAnimation { target: nave; property: "rewardIn"; from: 0; to: 1; duration: 750 }
        }
    }

    SequentialAnimation {
        id: stonesFill
        PauseAnimation { duration: 450 }
        NumberAnimation {
            target: nave
            property: "shownXp"
            to: nave.reward ? nave.reward.xpAfter : 0
            duration: 800
            easing.type: Easing.InOutCubic
        }
        PropertyAction { target: nave; property: "rewarding"; value: false }
    }

    NumberAnimation {
        id: promoteFx
        target: nave
        property: "promote"
        from: 0
        to: 1
        duration: 300
    }
}
