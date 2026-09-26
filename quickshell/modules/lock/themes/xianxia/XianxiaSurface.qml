pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs.modules.lock
import qs.services as Services

// "Sealed Cave Abode" theme: a cultivator sealing their cave for
// closed-door cultivation.
//
// Lock-in: a golden formation draws itself over the desktop, a cinnabar 封
// seal slams down, and the desktop dissolves into ink, revealing the
// wallpaper redrawn as a moonlit ink painting with drifting mist and qi motes.
// Typing lights the formation's runes; a wrong password is a qi deviation
// (走火入魔) that burns an incense stick (lives); a lockout is closed-door
// seclusion. Unlocking stamps 开, raises a pillar of light, shows cultivation
// gained (and a 突破 breakthrough when the realm advances), then the formation
// bursts and the ink recedes from the centre back into the desktop.
//
// Theme contract (see ThemeHost): ctx, shot, shown, still, minScale.
Item {
    id: xian

    required property LockContext ctx
    property url shot
    property bool shown: true
    property bool still: false
    property real minScale: 0.7

    readonly property real sc: Math.max(minScale, Math.min(2, Math.min(width / 1920, height / 1080)))
    readonly property real edge: 60 * sc
    readonly property real formationY: height * 0.42

    // Choreography.
    property real draw: 0
    property real dissolve: 0
    property real wash: 0
    property bool inward: false
    property real uiIn: 0
    property real sealIn: 0
    property real sealOut: 0
    property real openIn: 0
    property real pillar: 0
    property real alarm: 0
    property real surge: 0
    property real burst: 0
    property real deviation: 0
    property real breakthrough: 0
    property real rewardIn: 0
    property real shakeX: 0
    property real shakeY: 0
    property real spin: 0
    property real _lastAmbient: 0

    // Cultivation shown on the card: follows the stored XP, but runs up
    // from the old value during the reward (a crossing is a breakthrough).
    property real shownXp: Services.LockStats.xp
    readonly property int shownLevel: Services.LockStats.levelFor(shownXp)
    readonly property var realm: Xian.realm(shownLevel)
    readonly property int levelFloor: Services.LockStats.xpForLevel(shownLevel)
    readonly property int levelCeil: Services.LockStats.xpForLevel(shownLevel + 1)
    property bool rewarding: false
    property int _seenLevel: 0

    readonly property bool granted: ctx.phase === "granted" || ctx.phase === "exiting"
    readonly property var reward: ctx.reward

    Component.onCompleted: {
        _seenLevel = shownLevel;
        if (still) {
            draw = 1;
            dissolve = 1;
            uiIn = 1;
            sealOut = 1;
        } else if (shown) {
            startIntro();
        } else {
            introFallback.start();
        }
    }

    onShownLevelChanged: {
        if (rewarding && _seenLevel > 0 && shownLevel > _seenLevel)
            breakthroughFx.restart();
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
        onTriggered: xian.startIntro()
    }

    Connections {
        target: xian.ctx

        function onAmbientTimeChanged() {
            const t = xian.ctx.ambientTime;
            const dt = Math.max(0, Math.min(0.1, t - xian._lastAmbient));
            xian._lastAmbient = t;
            xian.spin += dt * (xian.ctx.phase === "verifying" ? 75 : 7);
        }

        function onPhaseChanged() {
            if (xian.ctx.phase === "exiting") {
                intro.stop();
                outro.start();
            }
        }

        function onDenied(costLife) {
            deviationFx.restart();
        }

        function onGranted() {
            if (xian.reward) {
                xian.rewarding = true;
                xian.shownXp = xian.reward.xpBefore;
                qiFill.restart();
            }
            grantFx.restart();
        }
    }

    // ── The ink world ────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Xian.ink
    }

    Item {
        width: 0
        height: 0
        clip: true

        Image {
            id: wallpaper
            width: xian.width
            height: xian.height
            source: "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
            sourceSize: Qt.size(Math.max(1, xian.width), Math.max(1, xian.height))
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
        property real time: xian.ctx.ambientTime
        property real motes: 1
        property color inkColor: Xian.ink
        property color mistColor: Xian.mist
        property color goldColor: Xian.gold

        fragmentShader: Qt.resolvedUrl("../../../../shaders/lock_ink_backdrop.frag.qsb")
    }

    LockInput {
        ctx: xian.ctx
        active: !xian.still
        onEscapePressed: xian.ctx.clearInput()
    }

    // ── The desktop, dissolving into ink (under the formation) ───────
    CaptureImage {
        id: capture
        source: xian.shot
        imageWidth: xian.width
        imageHeight: xian.height
    }

    ShaderEffect {
        anchors.fill: parent
        visible: capture.ready && xian.dissolve < 1

        property variant source: capture.image
        property real itemWidth: width
        property real itemHeight: height
        property real progress: xian.dissolve
        property real desat: xian.wash
        property real inward: xian.inward ? 1 : 0
        property point origin: Qt.point(0.5, xian.formationY / Math.max(1, xian.height))
        property color inkColor: Xian.ink
        property color goldColor: Xian.gold

        fragmentShader: Qt.resolvedUrl("../../../../shaders/lock_ink_dissolve.frag.qsb")
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        visible: !capture.ready && opacity > 0
        opacity: 1 - xian.dissolve
    }

    // ── HUD ──────────────────────────────────────────────────────────
    Item {
        id: hud
        anchors.fill: parent
        transform: Translate {
            x: xian.shakeX
            y: xian.shakeY
        }

        // A pillar of light for the breakthrough, behind the formation.
        Rectangle {
            x: (parent.width - width) / 2
            y: 0
            width: 170 * xian.sc * (0.55 + 0.45 * xian.pillar)
            height: parent.height
            opacity: xian.pillar
            visible: opacity > 0
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.3; color: Xian.alpha(Xian.gold, 0.35) }
                GradientStop { position: 0.5; color: Xian.alpha(Xian.goldHi, 0.9) }
                GradientStop { position: 0.7; color: Xian.alpha(Xian.gold, 0.35) }
                GradientStop { position: 1; color: "transparent" }
            }
        }

        Formation {
            id: formation
            anchors.horizontalCenter: parent.horizontalCenter
            y: xian.formationY - height / 2
            ctx: xian.ctx
            sc: xian.sc
            draw: xian.draw
            spin: xian.spin
            alarm: xian.alarm
            surge: xian.surge
            hush: Math.max(xian.deviation, Math.min(1, xian.breakthrough), xian.openIn, xian.sealIn * (1 - xian.sealOut))
            scale: 1 + 0.35 * xian.burst
            opacity: 1 - xian.burst
        }

        // Title, top left: 洞府封印 in a vertical column.
        Row {
            x: xian.edge
            y: 44 * xian.sc
            spacing: 16 * xian.sc
            opacity: xian.uiIn

            Text {
                text: "洞\n府\n封\n印"
                font.family: Xian.cjk
                font.weight: Font.Black
                font.pixelSize: 30 * xian.sc
                lineHeight: 1.05
                color: Xian.paper
            }

            Rectangle {
                width: 1 * xian.sc
                height: 142 * xian.sc
                color: Xian.alpha(Xian.gold, 0.5)
            }

            Column {
                spacing: 6 * xian.sc

                Text {
                    text: "SEALED CAVE ABODE"
                    font.family: Xian.serif
                    font.pixelSize: 15 * xian.sc
                    font.letterSpacing: 5 * xian.sc
                    color: Xian.gold
                }

                Text {
                    text: "Closed-door cultivation"
                    font.family: Xian.serif
                    font.italic: true
                    font.pixelSize: 14 * xian.sc
                    color: Xian.paperDim
                }

                Text {
                    readonly property int s: Math.max(0, Math.floor((xian.ctx.now.getTime() - xian.ctx.lockedAt) / 1000))
                    text: Math.floor(s / 3600) + ":" + String(Math.floor(s / 60) % 60).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0")
                    font.family: Xian.serif
                    font.weight: Font.Light
                    font.pixelSize: 24 * xian.sc
                    color: Xian.paper
                }
            }
        }

        // The hour, top right: 时辰 in a vertical column.
        Row {
            anchors.right: parent.right
            anchors.rightMargin: xian.edge
            y: 44 * xian.sc
            spacing: 16 * xian.sc
            opacity: xian.uiIn
            layoutDirection: Qt.RightToLeft

            Text {
                text: Xian.shichen(xian.ctx.now).zh.split("").join("\n")
                font.family: Xian.cjk
                font.weight: Font.Black
                font.pixelSize: 30 * xian.sc
                lineHeight: 1.05
                color: Xian.gold
            }

            Rectangle {
                width: 1 * xian.sc
                height: 142 * xian.sc
                color: Xian.alpha(Xian.gold, 0.5)
            }

            Column {
                spacing: 6 * xian.sc

                Text {
                    anchors.right: parent.right
                    text: Xian.shichen(xian.ctx.now).en
                    font.family: Xian.serif
                    font.pixelSize: 15 * xian.sc
                    font.letterSpacing: 2 * xian.sc
                    color: Xian.paper
                }

                Text {
                    anchors.right: parent.right
                    text: Xian.chineseDate(xian.ctx.now) + "  ·  " + Qt.formatDate(xian.ctx.now, "dddd")
                    font.family: Xian.cjk
                    font.pixelSize: 14 * xian.sc
                    color: Xian.paperDim
                }

                Text {
                    anchors.right: parent.right
                    text: "灵力 " + Math.round(Services.Battery.percentage) + "%" + (Services.Battery.charging ? " · 聚气" : "")
                    font.family: Xian.cjk
                    font.pixelSize: 14 * xian.sc
                    color: Services.Battery.percentage <= 20 && !Services.Battery.charging ? Xian.cinnabar : Xian.paperDim
                }

                Text {
                    anchors.right: parent.right
                    visible: xian.ctx.capsLock
                    text: "CAPS LOCK"
                    font.family: Xian.serif
                    font.pixelSize: 12 * xian.sc
                    font.letterSpacing: 3 * xian.sc
                    color: Xian.cinnabar
                }
            }
        }

        // Prompt / reward, under the formation.
        Item {
            id: promptArea
            anchors.horizontalCenter: parent.horizontalCenter
            y: formation.y + formation.height - 6 * xian.sc
            width: 900 * xian.sc
            height: 86 * xian.sc
            opacity: xian.uiIn

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6 * xian.sc
                visible: !xian.granted

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property var c: xian.ctx
                    text: c.phase === "verifying" ? "破阵中"
                        : c.lockedOut && c.cells === 0 ? "闭关"
                        : c.cells > 0 ? "运转周天"
                        : "诵咒解封"
                    font.family: Xian.cjk
                    font.weight: Font.Medium
                    font.pixelSize: 22 * xian.sc
                    font.letterSpacing: 8 * xian.sc
                    color: c.lockedOut && c.cells === 0 ? Xian.cinnabar : Xian.gold
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property var c: xian.ctx
                    text: c.phase === "verifying" ? "The formation weighs your incantation…"
                        : c.lockedOut && c.cells === 0 ? "Closed-door seclusion. The seal reopens in " + (c.lockoutClock || "time")
                        : c.cells > 0 ? c.cells + (c.cells === 1 ? " rune" : " runes") + " kindled" + (c.combo >= 5 ? "  ·  unbroken circulation ×" + c.combo : "")
                        : "Recite the incantation to break the seal"
                    font.family: Xian.serif
                    font.italic: true
                    font.pixelSize: 15 * xian.sc
                    color: Xian.paperDim
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property var c: xian.ctx
                    text: c.message.length > 0 ? c.message
                        : c.capsLock ? "Caps Lock is on. Incantations are case-sensitive"
                        : c.lastLife ? "One incense stick remains. Another failure means " + Math.round(c.unlockTime / 60) + " minutes of seclusion"
                        : ""
                    font.family: Xian.serif
                    font.pixelSize: 14 * xian.sc
                    color: Xian.cinnabar
                }
            }

            // Cultivation gained.
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6 * xian.sc
                visible: xian.granted && xian.reward !== null
                opacity: xian.rewardIn

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "修为 +" + Math.round((xian.reward ? xian.reward.total : 0) * Math.min(1, xian.rewardIn * 1.3))
                    font.family: Xian.cjk
                    font.weight: Font.Black
                    font.pixelSize: 34 * xian.sc
                    color: Xian.goldHi
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(implicitWidth, promptArea.width)
                    elide: Text.ElideRight
                    text: xian.reward
                        ? xian.reward.lines.map(l => l.label.toLowerCase() + " +" + l.xp).join("  ·  ")
                          + (xian.reward.multiplier > 1 ? "  ·  streak ×" + xian.reward.multiplier.toFixed(2) : "")
                        : ""
                    font.family: Xian.serif
                    font.italic: true
                    font.pixelSize: 14 * xian.sc
                    color: Xian.paperDim
                }
            }
        }

        // The cultivator, bottom centre.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 58 * xian.sc
            spacing: 24 * xian.sc
            opacity: xian.uiIn

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 86 * xian.sc
                height: width

                Rectangle {
                    id: avatarMask
                    anchors.fill: parent
                    anchors.margins: 7 * xian.sc
                    radius: width / 2
                    visible: false
                    layer.enabled: true
                }

                Image {
                    id: avatar
                    anchors.fill: parent
                    anchors.margins: 7 * xian.sc
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
                    saturation: -0.35
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 1.5 * xian.sc
                    border.color: Xian.gold
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4 * xian.sc
                    radius: width / 2
                    color: "transparent"
                    border.width: 1 * xian.sc
                    border.color: Xian.alpha(Xian.jade, 0.7)
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5 * xian.sc

                Row {
                    spacing: 10 * xian.sc

                    Text {
                        id: nameText
                        text: xian.ctx.userName.toUpperCase()
                        font.family: Xian.serif
                        font.pixelSize: 22 * xian.sc
                        font.letterSpacing: 6 * xian.sc
                        color: Xian.paper
                    }

                    Text {
                        anchors.baseline: nameText.baseline
                        text: "道友"
                        font.family: Xian.cjk
                        font.pixelSize: 15 * xian.sc
                        color: Xian.gold
                    }
                }

                Row {
                    spacing: 12 * xian.sc

                    Text {
                        id: realmText
                        text: xian.realm.zh + (xian.realm.stageZh ? " · " + xian.realm.stageZh : "")
                        font.family: Xian.cjk
                        font.weight: Font.Medium
                        font.pixelSize: 19 * xian.sc
                        color: Xian.gold
                    }

                    Text {
                        anchors.baseline: realmText.baseline
                        text: xian.realm.en + (xian.realm.stageEn ? ", " + xian.realm.stageEn : "")
                        font.family: Xian.serif
                        font.italic: true
                        font.pixelSize: 13 * xian.sc
                        color: Xian.paperDim
                    }
                }

                // Cultivation as a brush stroke.
                Item {
                    id: stroke
                    width: 320 * xian.sc
                    height: 12 * xian.sc
                    readonly property real progress: Math.max(0, Math.min(1, (xian.shownXp - xian.levelFloor) / Math.max(1, xian.levelCeil - xian.levelFloor)))

                    component Brush: Shape {
                        id: brush
                        property color tone
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeColor: "transparent"
                            fillColor: brush.tone
                            startX: 0
                            startY: stroke.height * 0.55
                            PathCubic {
                                x: stroke.width
                                y: stroke.height * 0.4
                                control1X: stroke.width * 0.3
                                control1Y: -stroke.height * 0.15
                                control2X: stroke.width * 0.75
                                control2Y: stroke.height * 0.05
                            }
                            PathCubic {
                                x: 0
                                y: stroke.height * 0.55
                                control1X: stroke.width * 0.7
                                control1Y: stroke.height * 1.05
                                control2X: stroke.width * 0.25
                                control2Y: stroke.height * 1.2
                            }
                        }
                    }

                    Brush {
                        anchors.fill: parent
                        tone: Xian.alpha(Xian.paper, 0.14)
                    }

                    Item {
                        width: parent.width * stroke.progress
                        height: parent.height
                        clip: true

                        Brush {
                            width: stroke.width
                            height: stroke.height
                            tone: Xian.gold
                        }
                    }
                }

                Text {
                    text: "修为 " + Math.floor(xian.shownXp - xian.levelFloor) + " / " + (xian.levelCeil - xian.levelFloor)
                        + "    " + Services.LockStats.liveStreak + "-day streak"
                        + "    悟道 " + Services.LockStats.achievements.length + "/" + Services.LockStats.achievementDefs.length
                    font.family: Xian.cjk
                    font.pixelSize: 13 * xian.sc
                    color: Xian.paperDim
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                visible: xian.ctx.maxLives > 0
                spacing: 2 * xian.sc

                IncenseSticks {
                    anchors.horizontalCenter: parent.horizontalCenter
                    ctx: xian.ctx
                    sc: xian.sc
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "香 · incense"
                    font.family: Xian.cjk
                    font.pixelSize: 12 * xian.sc
                    color: Xian.paperDim
                }
            }
        }

        // Guqin: what's playing, bottom left.
        Row {
            x: xian.edge
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 50 * xian.sc
            spacing: 14 * xian.sc
            visible: Services.Media.activePlayer !== null
            opacity: xian.uiIn

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "琴"
                font.family: Xian.cjk
                font.weight: Font.Black
                font.pixelSize: 26 * xian.sc
                color: Xian.gold
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2 * xian.sc

                Text {
                    width: Math.min(implicitWidth, 340 * xian.sc)
                    elide: Text.ElideRight
                    text: Services.Media.title
                    font.family: Xian.serif
                    font.pixelSize: 15 * xian.sc
                    color: Xian.paper
                }

                Row {
                    spacing: 12 * xian.sc

                    Repeater {
                        // Static model: only the icon follows play/pause.
                        model: ["previous", "playPause", "next"]

                        Glyph {
                            id: mediaKey
                            required property string modelData
                            text: modelData === "playPause" ? (Services.Media.isPlaying ? "pause" : "play_arrow") : modelData === "previous" ? "skip_previous" : "skip_next"
                            filled: true
                            font.pixelSize: 18 * xian.sc
                            color: mediaArea.containsMouse ? Xian.goldHi : Xian.paperDim

                            MouseArea {
                                id: mediaArea
                                anchors.fill: parent
                                anchors.margins: -6 * xian.sc
                                enabled: !xian.still
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Services.Media[mediaKey.modelData]()
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, 240 * xian.sc)
                        elide: Text.ElideRight
                        text: Services.Media.artist
                        font.family: Xian.serif
                        font.italic: true
                        font.pixelSize: 13 * xian.sc
                        color: Xian.paperDim
                    }
                }
            }
        }

        // Jade tokens, bottom right: hold to confirm.
        Row {
            anchors.right: parent.right
            anchors.rightMargin: xian.edge
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 40 * xian.sc
            spacing: 18 * xian.sc
            opacity: xian.uiIn

            Repeater {
                model: [
                    { zh: "眠", en: "Rest", act: "suspend" },
                    { zh: "轮", en: "Rebirth", act: "reboot" },
                    { zh: "寂", en: "Nirvana", act: "poweroff" }
                ]

                Column {
                    id: token
                    required property var modelData
                    spacing: 6 * xian.sc

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 46 * xian.sc
                        height: width

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: Xian.alpha(Xian.jade, tokenHold.containsMouse ? 0.24 : 0.12)
                            border.width: 1 * xian.sc
                            border.color: Xian.alpha(Xian.jade, 0.65)
                        }

                        Shape {
                            anchors.fill: parent
                            visible: tokenHold.progress > 0
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: Xian.goldHi
                                strokeWidth: 2 * xian.sc
                                capStyle: ShapePath.RoundCap
                                PathAngleArc {
                                    centerX: 23 * xian.sc
                                    centerY: 23 * xian.sc
                                    radiusX: 21.5 * xian.sc
                                    radiusY: 21.5 * xian.sc
                                    startAngle: -90
                                    sweepAngle: 360 * tokenHold.progress
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: token.modelData.zh
                            font.family: Xian.cjk
                            font.weight: Font.Black
                            font.pixelSize: 20 * xian.sc
                            color: Xian.jade
                        }

                        HoldArea {
                            id: tokenHold
                            anchors.fill: parent
                            enabled: !xian.still
                            onConfirmed: xian.ctx[token.modelData.act]()
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: token.modelData.en
                        font.family: Xian.serif
                        font.italic: true
                        font.pixelSize: 11 * xian.sc
                        color: Xian.paperDim
                    }
                }
            }
        }

        // Dao insights (achievements), top centre.
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 36 * xian.sc
            spacing: 10 * xian.sc
            visible: xian.granted

            Repeater {
                model: xian.reward ? xian.reward.achievements.slice(0, 3) : []

                Rectangle {
                    id: insight
                    required property int index
                    required property var modelData
                    readonly property real appear: LockTheme.seg(xian.rewardIn, 0.15 + index * 0.18, 0.45 + index * 0.18)
                    width: 460 * xian.sc
                    height: 62 * xian.sc
                    radius: 4 * xian.sc
                    color: Xian.alpha(Xian.ink, 0.86)
                    border.width: 1 * xian.sc
                    border.color: Xian.alpha(Xian.gold, 0.6)
                    opacity: appear
                    transform: Translate { y: (1 - insight.appear) * -16 * xian.sc }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 18 * xian.sc
                        spacing: 16 * xian.sc

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "悟道"
                            font.family: Xian.cjk
                            font.weight: Font.Black
                            font.pixelSize: 22 * xian.sc
                            color: Xian.gold
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: "DAO INSIGHT  ·  " + insight.modelData.name.toUpperCase()
                                font.family: Xian.serif
                                font.pixelSize: 14 * xian.sc
                                font.letterSpacing: 2 * xian.sc
                                color: Xian.paper
                            }

                            Text {
                                text: insight.modelData.desc
                                font.family: Xian.serif
                                font.italic: true
                                font.pixelSize: 12 * xian.sc
                                color: Xian.paperDim
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Seals and omens over the formation ───────────────────────────
    component Seal: Rectangle {
        property string glyph
        width: 128 * xian.sc
        height: width
        radius: 12 * xian.sc
        rotation: -7
        color: Xian.cinnabar
        border.width: 3 * xian.sc
        border.color: Qt.darker(Xian.cinnabar, 1.35)

        Text {
            anchors.centerIn: parent
            text: parent.glyph
            font.family: Xian.cjk
            font.weight: Font.Black
            font.pixelSize: 88 * xian.sc
            color: Xian.paper
        }
    }

    Seal {
        glyph: "封"
        x: (xian.width - width) / 2
        y: xian.formationY - height / 2
        opacity: xian.sealIn * (1 - xian.sealOut)
        visible: opacity > 0
        scale: 2.6 - 1.6 * xian.sealIn
    }

    Seal {
        glyph: "开"
        x: (xian.width - width) / 2
        y: xian.formationY - height / 2
        opacity: xian.openIn
        visible: opacity > 0
        scale: 2.2 - 1.2 * Math.min(1, xian.openIn)
    }

    Rectangle {
        id: sealRing
        x: (xian.width - width) / 2
        y: xian.formationY - height / 2
        width: 150 * xian.sc
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 3 * xian.sc
        border.color: Xian.cinnabar
        opacity: 0
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: xian.formationY - height / 2
        opacity: xian.deviation
        visible: opacity > 0
        scale: 1.25 - 0.25 * xian.deviation

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "走火入魔"
            font.family: Xian.cjk
            font.weight: Font.Black
            font.pixelSize: 70 * xian.sc
            style: Text.Outline
            styleColor: Xian.ink
            color: Xian.cinnabar
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "QI DEVIATION"
            font.family: Xian.serif
            font.pixelSize: 16 * xian.sc
            font.letterSpacing: 8 * xian.sc
            style: Text.Outline
            styleColor: Xian.ink
            color: Xian.cinnabar
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: xian.formationY - height / 2
        opacity: xian.breakthrough
        visible: opacity > 0
        scale: 1.6 - 0.6 * Math.min(1, xian.breakthrough)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "突破"
            font.family: Xian.cjk
            font.weight: Font.Black
            font.pixelSize: 116 * xian.sc
            style: Text.Outline
            styleColor: Xian.alpha(Xian.ink, 0.8)
            color: Xian.goldHi
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "BREAKTHROUGH  ·  " + (xian.realm.en + (xian.realm.stageEn ? ", " + xian.realm.stageEn : "")).toUpperCase()
            font.family: Xian.serif
            font.pixelSize: 17 * xian.sc
            font.letterSpacing: 4 * xian.sc
            style: Text.Outline
            styleColor: Xian.ink
            color: Xian.paper
        }
    }

    // ── Choreography ─────────────────────────────────────────────────
    ParallelAnimation {
        id: intro
        SequentialAnimation {
            PauseAnimation { duration: 80 }
            NumberAnimation { target: xian; property: "draw"; from: 0; to: 1; duration: 650; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 380 }
            NumberAnimation { target: xian; property: "sealIn"; from: 0; to: 1; duration: 190; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            ScriptAction { script: { sealRingFx.restart(); stampShake.restart(); } }
        }
        SequentialAnimation {
            PauseAnimation { duration: 460 }
            NumberAnimation { target: xian; property: "wash"; from: 0; to: 1; duration: 420 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 540 }
            NumberAnimation { target: xian; property: "dissolve"; from: 0; to: 1; duration: 900; easing.type: Easing.InOutSine }
        }
        SequentialAnimation {
            PauseAnimation { duration: 1100 }
            NumberAnimation { target: xian; property: "sealOut"; from: 0; to: 1; duration: 380 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 950 }
            NumberAnimation { target: xian; property: "uiIn"; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }
        }
    }

    // The formation bursts and the ink recedes from the centre: the last
    // frame is the desktop exactly.
    ParallelAnimation {
        id: outro
        NumberAnimation { target: xian; property: "uiIn"; to: 0; duration: 280; easing.type: Easing.InQuad }
        NumberAnimation { target: xian; property: "burst"; to: 1; duration: 520; easing.type: Easing.OutCubic }
        NumberAnimation { target: xian; property: "openIn"; to: 0; duration: 300 }
        NumberAnimation { target: xian; property: "breakthrough"; to: 0; duration: 300 }
        NumberAnimation { target: xian; property: "rewardIn"; to: 0; duration: 250 }
        NumberAnimation { target: xian; property: "pillar"; to: 0; duration: 300 }
        SequentialAnimation {
            PauseAnimation { duration: 140 }
            PropertyAction { target: xian; property: "inward"; value: true }
            NumberAnimation { target: xian; property: "dissolve"; to: 0; duration: 820; easing.type: Easing.InOutSine }
        }
        SequentialAnimation {
            PauseAnimation { duration: 680 }
            NumberAnimation { target: xian; property: "wash"; to: 0; duration: 420 }
        }
    }

    ParallelAnimation {
        id: sealRingFx
        NumberAnimation { target: sealRing; property: "scale"; from: 0.6; to: 3.4; duration: 650; easing.type: Easing.OutCubic }
        NumberAnimation { target: sealRing; property: "opacity"; from: 0.9; to: 0; duration: 650 }
    }

    SequentialAnimation {
        id: stampShake
        NumberAnimation { target: xian; property: "shakeY"; to: 7 * xian.sc; duration: 45 }
        NumberAnimation { target: xian; property: "shakeY"; to: -4 * xian.sc; duration: 70 }
        NumberAnimation { target: xian; property: "shakeY"; to: 0; duration: 90 }
    }

    ParallelAnimation {
        id: deviationFx
        SequentialAnimation {
            NumberAnimation { target: xian; property: "alarm"; to: 1; duration: 80 }
            NumberAnimation { target: xian; property: "alarm"; to: 0; duration: 700 }
        }
        SequentialAnimation {
            NumberAnimation { target: xian; property: "deviation"; to: 1; duration: 120 }
            PauseAnimation { duration: 750 }
            NumberAnimation { target: xian; property: "deviation"; to: 0; duration: 350 }
        }
        SequentialAnimation {
            NumberAnimation { target: xian; property: "shakeX"; to: -16 * xian.sc; duration: 50 }
            NumberAnimation { target: xian; property: "shakeX"; to: 13 * xian.sc; duration: 70 }
            NumberAnimation { target: xian; property: "shakeX"; to: -8 * xian.sc; duration: 70 }
            NumberAnimation { target: xian; property: "shakeX"; to: 4 * xian.sc; duration: 70 }
            NumberAnimation { target: xian; property: "shakeX"; to: 0; duration: 80 }
        }
    }

    ParallelAnimation {
        id: grantFx
        NumberAnimation { target: xian; property: "surge"; to: 1; duration: 220 }
        SequentialAnimation {
            NumberAnimation { target: xian; property: "openIn"; from: 0; to: 1; duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            PauseAnimation { duration: 450 }
            NumberAnimation { target: xian; property: "openIn"; to: 0; duration: 300 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 120 }
            NumberAnimation { target: xian; property: "pillar"; to: 1; duration: 240; easing.type: Easing.OutQuad }
            NumberAnimation { target: xian; property: "pillar"; to: 0; duration: 950; easing.type: Easing.InQuad }
        }
        SequentialAnimation {
            PauseAnimation { duration: 250 }
            NumberAnimation { target: xian; property: "rewardIn"; from: 0; to: 1; duration: 800 }
        }
    }

    SequentialAnimation {
        id: qiFill
        PauseAnimation { duration: 450 }
        NumberAnimation {
            target: xian
            property: "shownXp"
            to: xian.reward ? xian.reward.xpAfter : 0
            duration: 800
            easing.type: Easing.InOutCubic
        }
        PropertyAction { target: xian; property: "rewarding"; value: false }
    }

    NumberAnimation {
        id: breakthroughFx
        target: xian
        property: "breakthrough"
        from: 0
        to: 1
        duration: 320
        easing.type: Easing.OutBack
    }
}
