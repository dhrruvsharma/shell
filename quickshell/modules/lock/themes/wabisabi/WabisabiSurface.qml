pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs.modules.lock
import qs.services as Services

// "Ensō" theme: wabi-sabi, the beauty of the imperfect and the passing.
//
// Lock-in: the desktop yellows like an old print along an uneven front, a
// tea stain gathers at its edge, and it fades into washi paper with your
// wallpaper printed on it faintly in sumi, the things of the season drifting
// down. The passcode is an ensō: each keystroke carries the brush further
// round the circle (every lock's circle is a little different). A wrong one
// cracks the stroke where the brush was, and the cracks stay; a lockout
// closes the gate. Coming home completes the circle, fills the cracks with
// gold (kintsugi), and the desktop comes back out of the paper.
//
// Theme contract (see ThemeHost): ctx, shot, shown, still, minScale.
Item {
    id: sabi

    required property LockContext ctx
    property url shot
    property bool shown: true
    property bool still: false
    property real minScale: 0.7

    readonly property real sc: Math.max(minScale, Math.min(2, Math.min(width / 1920, height / 1080)))
    readonly property real edge: 64 * sc
    readonly property point center: Qt.point(width * 0.4, height * 0.45)

    // Choreography.
    property real age: 0
    property real uiIn: 0
    property real ghostIn: 0
    property real gold: 0
    property real bleed: 0
    property real shakeX: 0
    property real grantIn: 0
    property real rewardIn: 0
    property real promote: 0

    // Where the brush has got to: a little further per keystroke, back to
    // the start when a passcode is rejected, all the way round on success.
    readonly property real target: granted ? 0.955 : still ? 0.7 : Math.min(0.9, ctx.cells * 0.055)
    property real sweep: target
    Behavior on sweep {
        NumberAnimation {
            duration: sabi.granted ? 650 : 240
            easing.type: Easing.OutCubic
        }
    }

    // Cracks, in turns along the stroke, one per rejected passcode.
    property var crackList: []
    readonly property vector4d crackAt: Qt.vector4d(crackList[0] ?? 0, crackList[1] ?? 0, crackList[2] ?? 0, crackList[3] ?? 0)

    // Practice (XP) on the card: follows the stored XP, but runs up from the
    // old value during the reward.
    property real shownXp: Services.LockStats.xp
    readonly property int shownLevel: Services.LockStats.levelFor(shownXp)
    readonly property var grade: Wabi.grade(shownLevel)
    readonly property int levelFloor: Services.LockStats.xpForLevel(shownLevel)
    readonly property int levelCeil: Services.LockStats.xpForLevel(shownLevel + 1)
    property bool rewarding: false
    property int _seenLevel: 0

    readonly property bool granted: ctx.phase === "granted" || ctx.phase === "exiting"
    readonly property var reward: ctx.reward
    readonly property var kou: Wabi.season72(ctx.now)

    Component.onCompleted: {
        _seenLevel = shownLevel;
        if (still) {
            age = 1;
            uiIn = 1;
            ghostIn = 1;
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
        onTriggered: sabi.startIntro()
    }

    Connections {
        target: sabi.ctx

        function onPhaseChanged() {
            if (sabi.ctx.phase === "exiting") {
                intro.stop();
                outro.start();
            }
        }

        function onDenied(costLife) {
            if (sabi.crackList.length < 4 && sabi.sweep > 0.02) {
                const list = sabi.crackList.slice();
                list.push(sabi.sweep * (0.35 + 0.5 * Math.random()));
                sabi.crackList = list;
            }
            deniedFx.restart();
        }

        function onGranted() {
            if (sabi.reward) {
                sabi.rewarding = true;
                sabi.shownXp = sabi.reward.xpBefore;
                practiceFill.restart();
            }
            grantFx.restart();
        }
    }

    SequentialAnimation on bleed {
        running: sabi.ctx.phase === "verifying"
        loops: Animation.Infinite
        onRunningChanged: if (!running) sabi.bleed = 0
        NumberAnimation { from: 0; to: 1; duration: 520; easing.type: Easing.OutQuad }
        NumberAnimation { to: 0.3; duration: 520; easing.type: Easing.InOutQuad }
    }

    // ── Paper ────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Wabi.paper
    }

    Item {
        width: 0
        height: 0
        clip: true

        Image {
            id: wallpaper
            width: sabi.width
            height: sabi.height
            source: "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
            sourceSize: Qt.size(Math.max(1, sabi.width), Math.max(1, sabi.height))
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
        property real time: sabi.ctx.ambientTime
        property real season: Wabi.season(sabi.ctx.now)
        property real inkPrint: 0.34
        property color paperColor: Wabi.paper
        property color inkColor: Wabi.sumi
        property color ageColor: "#9c7a52"

        fragmentShader: Qt.resolvedUrl("../../../../shaders/lock_washi.frag.qsb")
    }

    LockInput {
        ctx: sabi.ctx
        active: !sabi.still
        onEscapePressed: sabi.ctx.clearInput()
    }

    // ── The painting ─────────────────────────────────────────────────
    component Ink: Text {
        font.family: Wabi.serif
        font.pixelSize: 16 * sabi.sc
        color: Wabi.sumi
    }

    component Vertical: Column {
        id: vert
        property string text
        property real size: 24
        property color color: Wabi.sumi
        property int weight: Font.Normal

        Repeater {
            model: vert.text.split("")

            Text {
                required property string modelData
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData
                font.family: Wabi.serif
                font.pixelSize: vert.size
                font.weight: vert.weight
                color: vert.color
            }
        }
    }

    Item {
        id: painting
        anchors.fill: parent
        transform: Translate { x: sabi.shakeX }

        Enso {
            id: circle
            x: sabi.center.x - width / 2
            y: sabi.center.y - height / 2
            width: 560 * sabi.sc
            height: width
            sweep: sabi.sweep
            ghost: sabi.ghostIn
            bleed: sabi.bleed
            thickness: 0.15
            seed: (sabi.ctx.lockedAt % 1000) / 97
            cracks: sabi.crackList.length
            crackAt: sabi.crackAt
            gold: sabi.gold
            inkColor: Wabi.sumi
            goldColor: Wabi.gold
        }

        // The time, inside the circle.
        Column {
            anchors.horizontalCenter: circle.horizontalCenter
            anchors.verticalCenter: circle.verticalCenter
            spacing: 2 * sabi.sc
            opacity: sabi.uiIn

            Ink {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(sabi.ctx.now, "H:mm")
                font.weight: Font.Light
                font.pixelSize: 116 * sabi.sc
            }

            Ink {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Wabi.weekdays[sabi.ctx.now.getDay()] + "  ·  " + Qt.formatDate(sabi.ctx.now, "dddd").toLowerCase()
                font.pixelSize: 16 * sabi.sc
                font.letterSpacing: 1 * sabi.sc
                color: Wabi.sumiSoft
            }
        }

        // The inscription beside it, read right to left: this week's
        // micro-season, then the date, signed with a seal.
        Row {
            id: inscription
            x: circle.x + circle.width + 30 * sabi.sc
            y: circle.y + 56 * sabi.sc
            spacing: 22 * sabi.sc
            layoutDirection: Qt.RightToLeft
            opacity: sabi.uiIn

            Vertical {
                text: sabi.kou.ja
                size: 40 * sabi.sc
            }

            Column {
                spacing: 16 * sabi.sc

                Vertical {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Wabi.eraYear(sabi.ctx.now) + Wabi.date(sabi.ctx.now)
                    size: 20 * sabi.sc
                    color: Wabi.sumiSoft
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 38 * sabi.sc
                    height: width
                    radius: 3 * sabi.sc
                    rotation: -3
                    color: Wabi.shu

                    Text {
                        anchors.centerIn: parent
                        text: "円"
                        font.family: Wabi.serif
                        font.weight: Font.Black
                        font.pixelSize: 24 * sabi.sc
                        color: Wabi.paper
                    }
                }
            }
        }

        Column {
            anchors.left: inscription.left
            y: inscription.y + inscription.height + 24 * sabi.sc
            spacing: 4 * sabi.sc
            opacity: sabi.uiIn

            Ink {
                text: sabi.kou.en.toLowerCase()
                font.pixelSize: 17 * sabi.sc
            }

            Ink {
                text: sabi.kou.sekki.ja + "  ·  " + sabi.kou.sekki.en.toLowerCase()
                font.pixelSize: 14 * sabi.sc
                color: Wabi.sumiSoft
            }
        }

        // Under the circle: what the brush is doing, or the welcome home.
        Item {
            id: prompt
            x: sabi.center.x - width / 2
            y: circle.y + circle.height + 6 * sabi.sc
            width: 760 * sabi.sc
            height: 120 * sabi.sc
            opacity: sabi.uiIn

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6 * sabi.sc
                visible: !sabi.granted

                Ink {
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property var c: sabi.ctx
                    text: c.phase === "verifying" ? "墨が乾くのを待つ"
                        : c.denying ? "ひびが入る"
                        : c.lockedOut && c.cells === 0 ? "閉門"
                        : c.cells > 0 ? Wabi.numeral(Math.min(c.cells, 99)) + "筆"
                        : "筆を執る"
                    font.pixelSize: 26 * sabi.sc
                    font.letterSpacing: 6 * sabi.sc
                    color: c.denying || (c.lockedOut && c.cells === 0) ? Wabi.shu : Wabi.sumi
                }

                Ink {
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property var c: sabi.ctx
                    text: c.phase === "verifying" ? "waiting for the ink to dry…"
                        : c.denying ? "the circle cracks"
                        : c.lockedOut && c.cells === 0 ? "the gate is closed · it opens in " + (c.lockoutClock || "a while")
                        : c.cells > 0 ? c.cells + (c.cells === 1 ? " stroke" : " strokes") + (c.combo >= 5 ? "  ·  one unbroken breath" : "")
                        : "take up the brush · type your password"
                    font.pixelSize: 16 * sabi.sc
                    font.letterSpacing: 0.5 * sabi.sc
                    color: Wabi.sumiSoft
                }

                Ink {
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property var c: sabi.ctx
                    text: c.message.length > 0 ? c.message
                        : c.capsLock ? "caps lock is on"
                        : c.lastLife ? "one more crack and the gate closes for " + Math.round(c.unlockTime / 60) + " minutes"
                        : ""
                    font.pixelSize: 15 * sabi.sc
                    color: Wabi.shu
                }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6 * sabi.sc
                visible: sabi.granted
                opacity: sabi.grantIn

                Ink {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "おかえりなさい"
                    font.pixelSize: 34 * sabi.sc
                    font.letterSpacing: 8 * sabi.sc
                }

                Ink {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "welcome home, " + sabi.ctx.userName
                    font.pixelSize: 16 * sabi.sc
                    color: Wabi.sumiSoft
                }

                Ink {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: sabi.reward !== null
                    opacity: sabi.rewardIn
                    text: "稽古 +" + Math.round((sabi.reward ? sabi.reward.total : 0) * Math.min(1, sabi.rewardIn * 1.3))
                        + (sabi.promote > 0 ? "   " + (sabi.shownLevel >= 10 ? "昇段" : "昇級") + " · " + sabi.grade.ja : "")
                    font.pixelSize: 20 * sabi.sc
                    color: sabi.promote > 0 ? Wabi.gold : Wabi.sumi
                }

                Ink {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(implicitWidth, prompt.width)
                    elide: Text.ElideRight
                    visible: sabi.reward !== null
                    opacity: sabi.rewardIn
                    text: sabi.reward
                        ? sabi.reward.lines.map(l => l.label.toLowerCase() + " +" + l.xp).join("  ·  ")
                          + (sabi.reward.multiplier > 1 ? "  ·  streak ×" + sabi.reward.multiplier.toFixed(2) : "")
                        : ""
                    font.pixelSize: 14 * sabi.sc
                    color: Wabi.sumiSoft
                }
            }
        }
    }

    // ── Around the edges ─────────────────────────────────────────────
    Item {
        anchors.fill: parent
        opacity: sabi.uiIn

        // Title, top left.
        Column {
            x: sabi.edge
            y: 46 * sabi.sc
            spacing: 4 * sabi.sc

            Ink {
                text: "円相"
                font.pixelSize: 30 * sabi.sc
                font.letterSpacing: 6 * sabi.sc
            }

            Ink {
                readonly property int s: Math.max(0, Math.floor((sabi.ctx.now.getTime() - sabi.ctx.lockedAt) / 1000))
                text: "ensō  ·  at rest " + Math.floor(s / 3600) + ":" + String(Math.floor(s / 60) % 60).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0")
                font.pixelSize: 14 * sabi.sc
                font.letterSpacing: 1 * sabi.sc
                color: Wabi.sumiSoft
            }
        }

        // Battery and caps, top right.
        Column {
            anchors.right: parent.right
            anchors.rightMargin: sabi.edge
            y: 48 * sabi.sc
            spacing: 4 * sabi.sc

            Ink {
                anchors.right: parent.right
                readonly property real pct: Services.Battery.percentage
                text: "電 " + Math.round(pct) + "%" + (Services.Battery.charging ? " · charging" : "")
                font.pixelSize: 15 * sabi.sc
                color: pct <= 20 && !Services.Battery.charging ? Wabi.shu : Wabi.sumiSoft
            }

            Ink {
                anchors.right: parent.right
                visible: sabi.ctx.capsLock
                text: "caps lock"
                font.pixelSize: 14 * sabi.sc
                color: Wabi.shu
            }
        }

        // Gifts of the visit (achievements), top right.
        Column {
            anchors.right: parent.right
            anchors.rightMargin: sabi.edge
            y: 120 * sabi.sc
            spacing: 10 * sabi.sc
            visible: sabi.granted

            Repeater {
                model: sabi.reward ? sabi.reward.achievements.slice(0, 3) : []

                Rectangle {
                    id: slip
                    required property int index
                    required property var modelData
                    readonly property real appear: LockTheme.seg(sabi.rewardIn, 0.15 + index * 0.18, 0.45 + index * 0.18)
                    width: 400 * sabi.sc
                    height: 58 * sabi.sc
                    radius: 10 * sabi.sc
                    topRightRadius: 5 * sabi.sc
                    bottomLeftRadius: 7 * sabi.sc
                    color: Qt.lighter(Wabi.paper, 1.04)
                    border.width: 1
                    border.color: Wabi.alpha(Wabi.sumi, 0.25)
                    opacity: appear
                    transform: Translate { y: (1 - slip.appear) * -14 * sabi.sc }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 18 * sabi.sc
                        spacing: 14 * sabi.sc

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            text: slip.modelData.icon
                            font.pixelSize: 20 * sabi.sc
                            color: Wabi.gold
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter

                            Ink {
                                text: slip.modelData.name.toLowerCase()
                                font.pixelSize: 15 * sabi.sc
                            }

                            Ink {
                                text: slip.modelData.desc
                                font.pixelSize: 12 * sabi.sc
                                color: Wabi.sumiSoft
                            }
                        }
                    }
                }
            }
        }

        // The one practising, bottom left.
        Row {
            x: sabi.edge
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 50 * sabi.sc
            spacing: 20 * sabi.sc

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 78 * sabi.sc
                height: width

                Rectangle {
                    id: avatarMask
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                    layer.enabled: true
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
                    maskSource: avatarMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                    saturation: -0.7
                    colorization: 0.3
                    colorizationColor: "#a07c50"
                }

                Enso {
                    anchors.fill: parent
                    anchors.margins: -16 * sabi.sc
                    sweep: 0.9
                    thickness: 0.09
                    seed: 11
                    inkColor: Wabi.sumi
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4 * sabi.sc

                Row {
                    spacing: 12 * sabi.sc

                    Ink {
                        id: nameText
                        text: sabi.ctx.userName
                        font.pixelSize: 22 * sabi.sc
                        font.letterSpacing: 2 * sabi.sc
                    }

                    Ink {
                        anchors.baseline: nameText.baseline
                        text: sabi.grade.ja + " · " + sabi.grade.en.toLowerCase()
                        font.pixelSize: 15 * sabi.sc
                        color: Wabi.accent.hslLightness > 0.55 ? Qt.darker(Wabi.accent, 1.8) : Wabi.accent
                    }
                }

                // Practice towards the next grade, as a line of ink.
                Item {
                    width: 300 * sabi.sc
                    height: 8 * sabi.sc
                    readonly property real progress: Math.max(0, Math.min(1, (sabi.shownXp - sabi.levelFloor) / Math.max(1, sabi.levelCeil - sabi.levelFloor)))

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 1
                        color: Wabi.alpha(Wabi.sumi, 0.2)
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * parent.progress
                        height: 3 * sabi.sc
                        radius: height / 2
                        color: Wabi.sumi
                    }
                }

                Ink {
                    text: "稽古 " + Math.floor(sabi.shownXp - sabi.levelFloor) + " / " + (sabi.levelCeil - sabi.levelFloor)
                        + "    " + Services.LockStats.liveStreak + " days of practice"
                        + "    " + Services.LockStats.achievements.length + "/" + Services.LockStats.achievementDefs.length + " gifts"
                    font.pixelSize: 13 * sabi.sc
                    color: Wabi.sumiSoft
                }
            }
        }

        // What's playing, bottom centre.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 56 * sabi.sc
            spacing: 12 * sabi.sc
            visible: Services.Media.activePlayer !== null

            Ink {
                anchors.verticalCenter: parent.verticalCenter
                text: "音"
                font.pixelSize: 20 * sabi.sc
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
                    font.pixelSize: 18 * sabi.sc
                    color: mediaArea.containsMouse ? Wabi.sumi : Wabi.sumiSoft

                    MouseArea {
                        id: mediaArea
                        anchors.fill: parent
                        anchors.margins: -6 * sabi.sc
                        enabled: !sabi.still
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.Media[mediaKey.modelData]()
                    }
                }
            }

            Ink {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 440 * sabi.sc)
                elide: Text.ElideRight
                text: Services.Media.title + (Services.Media.artist ? "  —  " + Services.Media.artist : "")
                font.pixelSize: 15 * sabi.sc
            }
        }

        // Stones, bottom right: hold one and the brush circles it.
        Row {
            anchors.right: parent.right
            anchors.rightMargin: sabi.edge
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 40 * sabi.sc
            spacing: 18 * sabi.sc

            Repeater {
                model: [
                    { ja: "眠", en: "sleep", act: "suspend" },
                    { ja: "巡", en: "restart", act: "reboot" },
                    { ja: "終", en: "rest", act: "poweroff" }
                ]

                Column {
                    id: stone
                    required property var modelData
                    spacing: 6 * sabi.sc

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 48 * sabi.sc
                        height: width

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            topRightRadius: width * 0.36
                            bottomLeftRadius: width * 0.42
                            color: Wabi.alpha(Wabi.sumi, stoneHold.containsMouse ? 0.14 : 0.07)
                            border.width: 1
                            border.color: Wabi.alpha(Wabi.sumi, 0.35)
                        }

                        Shape {
                            anchors.fill: parent
                            anchors.margins: -5 * sabi.sc
                            visible: stoneHold.progress > 0
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: Wabi.sumi
                                strokeWidth: 3 * sabi.sc
                                capStyle: ShapePath.RoundCap
                                PathAngleArc {
                                    centerX: 29 * sabi.sc
                                    centerY: 29 * sabi.sc
                                    radiusX: 27 * sabi.sc
                                    radiusY: 27 * sabi.sc
                                    startAngle: 130
                                    sweepAngle: 330 * stoneHold.progress
                                }
                            }
                        }

                        Ink {
                            anchors.centerIn: parent
                            text: stone.modelData.ja
                            font.pixelSize: 21 * sabi.sc
                        }

                        HoldArea {
                            id: stoneHold
                            anchors.fill: parent
                            enabled: !sabi.still
                            onConfirmed: sabi.ctx[stone.modelData.act]()
                        }
                    }

                    Ink {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: stone.modelData.en
                        font.pixelSize: 12 * sabi.sc
                        color: Wabi.sumiSoft
                    }
                }
            }
        }
    }

    // ── The desktop, ageing into paper ───────────────────────────────
    CaptureImage {
        id: capture
        source: sabi.shot
        imageWidth: sabi.width
        imageHeight: sabi.height
    }

    ShaderEffect {
        anchors.fill: parent
        visible: capture.ready && sabi.age < 1

        property variant source: capture.image
        property real itemWidth: width
        property real itemHeight: height
        property real progress: sabi.age
        property color paperColor: Wabi.paper
        property color stainColor: "#8a6a44"

        fragmentShader: Qt.resolvedUrl("../../../../shaders/lock_sabi.frag.qsb")
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        visible: !capture.ready && opacity > 0
        opacity: 1 - sabi.age
    }

    // ── Choreography ─────────────────────────────────────────────────
    ParallelAnimation {
        id: intro
        SequentialAnimation {
            PauseAnimation { duration: 80 }
            NumberAnimation { target: sabi; property: "age"; from: 0; to: 1; duration: 1050; easing.type: Easing.InOutSine }
        }
        SequentialAnimation {
            PauseAnimation { duration: 700 }
            NumberAnimation { target: sabi; property: "ghostIn"; from: 0; to: 1; duration: 600; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 820 }
            NumberAnimation { target: sabi; property: "uiIn"; from: 0; to: 1; duration: 650; easing.type: Easing.OutCubic }
        }
    }

    // The desktop comes back out of the paper: the last frame is the desktop
    // exactly.
    ParallelAnimation {
        id: outro
        NumberAnimation { target: sabi; property: "uiIn"; to: 0; duration: 300; easing.type: Easing.InQuad }
        NumberAnimation { target: sabi; property: "ghostIn"; to: 0; duration: 300 }
        SequentialAnimation {
            PauseAnimation { duration: 180 }
            NumberAnimation { target: sabi; property: "age"; to: 0; duration: 900; easing.type: Easing.OutCubic }
        }
    }

    SequentialAnimation {
        id: deniedFx
        NumberAnimation { target: sabi; property: "shakeX"; to: -10 * sabi.sc; duration: 60 }
        NumberAnimation { target: sabi; property: "shakeX"; to: 8 * sabi.sc; duration: 80 }
        NumberAnimation { target: sabi; property: "shakeX"; to: -4 * sabi.sc; duration: 80 }
        NumberAnimation { target: sabi; property: "shakeX"; to: 0; duration: 90 }
    }

    ParallelAnimation {
        id: grantFx
        NumberAnimation { target: sabi; property: "grantIn"; from: 0; to: 1; duration: 400 }
        SequentialAnimation {
            PauseAnimation { duration: 350 }
            NumberAnimation { target: sabi; property: "gold"; from: 0; to: 1; duration: 700; easing.type: Easing.InOutSine }
        }
        SequentialAnimation {
            PauseAnimation { duration: 300 }
            NumberAnimation { target: sabi; property: "rewardIn"; from: 0; to: 1; duration: 750 }
        }
    }

    SequentialAnimation {
        id: practiceFill
        PauseAnimation { duration: 450 }
        NumberAnimation {
            target: sabi
            property: "shownXp"
            to: sabi.reward ? sabi.reward.xpAfter : 0
            duration: 800
            easing.type: Easing.InOutCubic
        }
        PropertyAction { target: sabi; property: "rewarding"; value: false }
    }

    NumberAnimation {
        id: promoteFx
        target: sabi
        property: "promote"
        from: 0
        to: 1
        duration: 300
    }
}
