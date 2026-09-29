pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs.components
import qs.modules.desktoptheme
import qs.modules.lock
import qs.services as Services

// "Astrolabe" theme: a night at the old observatory.
//
// Lock-in: night falls on the desktop, darkening from the top with stars
// pricking out in its shadows, and the picture parts down the middle like
// the shutters of the dome, opening on tonight's sky over the observing
// site as an engraved chart (StarChart). An astrolabe set for your latitude
// hangs there, its rete turned to the sidereal time. The passcode sights
// the stars: each keystroke turns the rete an hour and lights the next of
// its twelve star pointers, then the signs of the zodiac round the ecliptic.
// A wrong one clouds the sky over and brings the Moon further across the
// Sun (the faillock lives as an eclipse); a lockout is totality. Coming
// home clears the heavens: the rete swings back to the true sky, every star
// blazes, the observations (XP) are logged and you may be raised in the
// observatory; then the shutters close on the desktop.
//
// Theme contract (see ThemeHost): ctx, shot, shown, still, minScale.
Item {
    id: dome

    required property LockContext ctx
    property url shot
    property bool shown: true
    property bool still: false
    property real minScale: 0.7

    readonly property real sc: Math.max(minScale, Math.min(2, Math.min(width / 1920, height / 1080)))
    readonly property real edge: 64 * sc

    // Choreography.
    property real opening: 0
    property real uiIn: 0
    property real glow: 1
    property real bloom: 0
    property real cloud: 0
    property real drift: 0
    property real shakeX: 0
    property real grantIn: 0
    property real rewardIn: 0
    property real promote: 0

    // The rete turns an hour a keystroke, and swings back to the sky on the
    // way in.
    readonly property real turnTarget: granted ? 0 : still ? 0 : Math.min(ctx.cells, 24) * 15
    property real turn: turnTarget
    Behavior on turn {
        NumberAnimation {
            duration: dome.granted ? 900 : 320
            easing.type: dome.granted ? Easing.InOutCubic : Easing.OutBack
        }
    }

    // Stars sighted, then the signs.
    readonly property real litTarget: granted ? 12 : still ? 5 : Math.min(ctx.cells, 12)
    readonly property real signsTarget: granted ? 12 : still ? 0 : Math.max(0, Math.min(ctx.cells - 12, 12))
    property real lit: litTarget
    property real litSigns: signsTarget
    Behavior on lit {
        NumberAnimation {
            duration: dome.granted ? 600 : 260
            easing.type: Easing.OutCubic
        }
    }
    Behavior on litSigns {
        NumberAnimation { duration: 260 }
    }

    // The order the stars are sighted in: clockwise from the top, as the
    // rete stood when the lock came down.
    property var order: []
    readonly property var litStars: {
        const out = [];
        for (let i = 0; i < Sky.reteStars.length; i++) {
            const k = order.indexOf(i);
            out.push(k < 0 ? 0 : Math.max(0, Math.min(1, lit - k)));
        }
        return out;
    }

    function sightingOrder() {
        const l = Sky.lst(new Date());
        const idx = [];
        for (let i = 0; i < Sky.reteStars.length; i++)
            idx.push(i);
        const key = i => ((l - Sky.reteStars[i][1] * 15) % 360 + 360) % 360;
        idx.sort((a, b) => key(a) - key(b));
        return idx;
    }

    // Observations (XP) on the card: follow the stored XP, but run up from
    // the old value during the reward.
    property real shownXp: Services.LockStats.xp
    readonly property int shownLevel: Services.LockStats.levelFor(shownXp)
    readonly property int levelFloor: Services.LockStats.xpForLevel(shownLevel)
    readonly property int levelCeil: Services.LockStats.xpForLevel(shownLevel + 1)
    property bool rewarding: false
    property int _seenLevel: 0

    readonly property bool granted: ctx.phase === "granted" || ctx.phase === "exiting"
    readonly property var reward: ctx.reward
    readonly property bool totality: ctx.lockedOut && ctx.cells === 0
    readonly property var hm: Qt.formatDateTime(ctx.now, "h:mm AP").split(" ")
    // How far the Moon has come across the Sun: a quarter of the way at the
    // first wrong passcode's cost, all of it at a lockout.
    readonly property real eclipse: totality ? 1 : ctx.maxLives > 0 ? (ctx.maxLives - ctx.lives) / ctx.maxLives * 0.86 : 0
    property real shownEclipse: eclipse
    Behavior on shownEclipse {
        NumberAnimation {
            duration: 1100
            easing.type: Easing.InOutSine
        }
    }
    readonly property string culminating: Sky.culminating(minute)

    // The sky moves on once a minute (the context's clock ticks every
    // second; the chart and the rete needn't).
    property date minute: new Date()

    Connections {
        target: dome.ctx

        function onNowChanged() {
            const n = dome.ctx.now;
            if (n.getMinutes() !== dome.minute.getMinutes() || n.getHours() !== dome.minute.getHours())
                dome.minute = n;
        }
    }

    Component.onCompleted: {
        _seenLevel = shownLevel;
        order = sightingOrder();
        if (still) {
            opening = 1;
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
        onTriggered: dome.startIntro()
    }

    Connections {
        target: dome.ctx

        function onPhaseChanged() {
            if (dome.ctx.phase === "exiting") {
                intro.stop();
                outro.start();
            }
        }

        function onDenied(costLife) {
            deniedFx.restart();
        }

        function onGranted() {
            if (dome.reward) {
                dome.rewarding = true;
                dome.shownXp = dome.reward.xpBefore;
                observationsFill.restart();
            }
            grantFx.restart();
        }
    }

    // The instrument breathes while the reckoning's made (verifying).
    SequentialAnimation on glow {
        running: dome.ctx.phase === "verifying"
        loops: Animation.Infinite
        onRunningChanged: if (!running) dome.glow = dome.totality ? 0.4 : 1
        NumberAnimation { to: 1.35; duration: 420; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.75; duration: 420; easing.type: Easing.InOutSine }
    }

    onTotalityChanged: glow = totality ? 0.4 : 1

    // ── The sky ──────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#04060c"
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

    // The wallpaper under the night, faint.
    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        visible: wallpaper.status === Image.Ready
        saturation: -0.5
        brightness: -0.62
        contrast: 0.05
        colorization: 0.35
        colorizationColor: Sky.enamelDeep
        opacity: 1 - dome.shownEclipse * 0.4
    }

    // Laid out at the design size and scaled, so a thumbnail shows the same
    // chart in miniature.
    StarChart {
        width: dome.width / dome.sc
        height: dome.height / dome.sc
        scale: dome.sc
        transformOrigin: Item.TopLeft
        now: dome.minute
        strength: 1 - dome.cloud * 0.6
        veil: 1
        pxScale: dome.sc
        opacity: 1 - (dome.totality ? 0.35 : 0)
    }

    // Shade behind the words.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.45; color: "transparent" }
            GradientStop { position: 0.62; color: Sky.alpha(Sky.night, 0.55) }
            GradientStop { position: 1; color: Sky.alpha(Sky.night, 0.7) }
        }
    }

    LockInput {
        ctx: dome.ctx
        active: !dome.still
        onEscapePressed: dome.ctx.clearInput()
    }

    // Clouds drift in with a wrong passcode.
    NumberAnimation on drift {
        running: dome.cloud > 0.01 && !dome.still
        from: 0
        to: 3
        duration: 6000
        loops: Animation.Infinite
    }

    // ── The astrolabe ────────────────────────────────────────────────
    Item {
        id: holder
        readonly property real size: 620 * dome.sc
        x: dome.width * 0.31 - size / 2
        y: dome.height * 0.47 - size / 2
        width: size
        height: size
        transform: Translate { x: dome.shakeX }

        // Lamplight behind it.
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 1.3
            height: width
            radius: width / 2
            color: Qt.rgba(1, 0.84, 0.55, 0.05 + 0.08 * Math.min(1, dome.lit / 12) * dome.glow + 0.22 * dome.bloom)
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1
                blurMax: 64
            }
        }

        Astrolabe {
            anchors.fill: parent
            rete: Sky.lst(dome.minute) + dome.turn
            rule: (dome.ctx.now.getHours() + dome.ctx.now.getMinutes() / 60 - 12) * 15
            lit: dome.litStars
            litSigns: dome.litSigns
            glow: Math.min(1.35, dome.glow)
            bloom: dome.bloom
            cloud: dome.cloud
            drift: dome.drift
            starNames: true
        }
    }

    // ── The hour, and what the heavens are doing ─────────────────────
    component Book: Text {
        font.family: Sky.book
        font.pixelSize: 22 * dome.sc
        color: Sky.parchment
    }

    Column {
        id: hours
        x: dome.width * 0.6
        anchors.verticalCenter: holder.verticalCenter
        spacing: 4 * dome.sc
        opacity: dome.uiIn

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
            spacing: 16 * dome.sc

            Text {
                id: time
                text: dome.hm[0]
                font.family: Sky.display
                font.pixelSize: 150 * dome.sc
                color: Sky.parchment
            }

            Text {
                anchors.baseline: time.baseline
                text: (dome.hm[1] ?? "").toLowerCase().split("").join(".") + "."
                font.family: Sky.caps
                font.pixelSize: 34 * dome.sc
                color: Sky.brass
            }
        }

        Text {
            text: "Sidereal " + Sky.hm(Sky.lst(dome.ctx.now)) + (dome.culminating ? "  ·  " + dome.culminating + " on the meridian" : "")
            font.family: Sky.display
            font.italic: true
            font.pixelSize: 27 * dome.sc
            color: Sky.brass
        }

        Book {
            text: Qt.formatDate(dome.ctx.now, "dddd") + ", the " + Clocks.ordinal(dome.ctx.now.getDate()) + " of " + Qt.formatDate(dome.ctx.now, "MMMM")
            font.pixelSize: 24 * dome.sc
        }

        Text {
            topPadding: 4 * dome.sc
            text: "JD " + Sky.jd(dome.ctx.now).toFixed(3) + "  ·  ANNO " + Clocks.roman(dome.ctx.now.getFullYear())
            font.family: Sky.caps
            font.pixelSize: 16 * dome.sc
            font.letterSpacing: 3 * dome.sc
            color: Sky.alpha(Sky.parchment, 0.72)
        }

        // A rule with a little dial at its middle.
        Item {
            width: 440 * dome.sc
            height: 36 * dome.sc

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: Math.max(1, dome.sc)
                color: Sky.alpha(Sky.brass, 0.55)
            }

            ScaleTicks {
                x: 0
                y: parent.height / 2
                width: parent.width
                height: 6 * dome.sc
                step: 11 * dome.sc
                major: 4
                minorLength: 3 * dome.sc
                majorLength: 6 * dome.sc
                color: Sky.alpha(Sky.brass, 0.55)
            }

            Rectangle {
                anchors.centerIn: parent
                width: 16 * dome.sc
                height: width
                radius: width / 2
                color: Sky.night
                border.width: Math.max(1, dome.sc)
                border.color: Sky.brass

                Rectangle {
                    anchors.centerIn: parent
                    width: 4 * dome.sc
                    height: width
                    radius: width / 2
                    color: Sky.brass
                }
            }
        }

        // What the heavens are doing.
        Text {
            readonly property var c: dome.ctx
            text: dome.granted ? "Clear skies, " + c.userName
                : c.phase === "verifying" ? "Reckoning the heavens…"
                : c.denying ? "Clouds roll in"
                : dome.totality ? "Totality"
                : c.cells > 0 ? (c.cells === 1 ? "One star sighted" : c.cells <= 12 ? c.cells + " stars sighted" : "The zodiac turns: " + (c.cells - 12) + (c.cells === 13 ? " sign" : " signs"))
                : "Sight the stars"
            font.family: Sky.display
            font.pixelSize: 44 * dome.sc
            color: c.denying || dome.totality ? Sky.danger : dome.granted ? Sky.lamp : Sky.parchment
        }

        Book {
            readonly property var c: dome.ctx
            text: dome.granted
                ? (dome.reward ? "+" + Math.round(dome.reward.total * Math.min(1, dome.rewardIn * 1.3)) + " observations logged" + (dome.promote > 0 ? "  ·  now " + Sky.rank(dome.shownLevel) : "") : "")
                : c.message.length > 0 ? c.message
                : dome.totality ? "the Sun returns in " + (c.lockoutClock || "a while")
                : c.capsLock ? "caps lock is on"
                : c.lastLife ? "one more and the Moon covers the Sun for " + Math.round(c.unlockTime / 60) + " minutes"
                : c.denying ? "the stars are lost; sight them again"
                : c.cells > 0 ? (c.combo >= 6 ? "a steady hand on the alidade" : "keep going, then press Enter")
                : "type your password; each letter sights a star"
            font.pixelSize: 21 * dome.sc
            font.italic: true
            opacity: dome.granted ? dome.rewardIn : 1
            color: !dome.granted && (c.message.length > 0 || dome.totality || c.capsLock || c.lastLife) ? Sky.danger : Sky.alpha(Sky.parchment, 0.82)
        }

        Book {
            visible: dome.granted && dome.reward !== null
            width: Math.min(implicitWidth, dome.width * 0.36)
            elide: Text.ElideRight
            opacity: dome.rewardIn
            text: dome.reward
                ? dome.reward.lines.map(l => l.label.toLowerCase() + " +" + l.xp).join("  ·  ")
                  + (dome.reward.multiplier > 1 ? "  ·  streak ×" + dome.reward.multiplier.toFixed(2) : "")
                : ""
            font.pixelSize: 17 * dome.sc
            color: Sky.alpha(Sky.parchment, 0.65)
        }

        // The eclipse: the faillock lives.
        Row {
            topPadding: 12 * dome.sc
            spacing: 14 * dome.sc
            visible: !dome.granted && dome.ctx.maxLives > 0

            Orb {
                anchors.verticalCenter: parent.verticalCenter
                width: 86 * dome.sc
                height: width
                eclipse: true
                cover: dome.shownEclipse
                glow: 0.8
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2 * dome.sc

                Text {
                    text: dome.totality ? "Totality" : dome.ctx.lives >= dome.ctx.maxLives ? "The Sun is clear" : "The Moon draws across the Sun"
                    font.family: Sky.caps
                    font.pixelSize: 17 * dome.sc
                    font.letterSpacing: 1.5 * dome.sc
                    color: dome.totality ? Sky.danger : Sky.brass
                }

                Book {
                    text: dome.totality ? "until " + (dome.ctx.lockoutClock || "the sky clears")
                        : dome.ctx.lives === 1 ? "one clear hour left"
                        : dome.ctx.lives + " clear hours left"
                    font.pixelSize: 17 * dome.sc
                    font.italic: true
                    color: Sky.alpha(Sky.parchment, 0.7)
                }
            }
        }
    }

    // ── Around the edges ─────────────────────────────────────────────
    Item {
        anchors.fill: parent
        opacity: dome.uiIn

        Column {
            x: dome.edge
            y: 40 * dome.sc
            spacing: 2 * dome.sc

            Text {
                text: "The Astrolabe"
                font.family: Sky.display
                font.pixelSize: 30 * dome.sc
                color: Sky.parchment
            }

            Book {
                readonly property int s: Math.max(0, Math.floor((dome.ctx.now.getTime() - dome.ctx.lockedAt) / 1000))
                text: "a watch of " + Math.floor(s / 3600) + ":" + String(Math.floor(s / 60) % 60).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0")
                font.pixelSize: 17 * dome.sc
                font.italic: true
                color: Sky.alpha(Sky.parchment, 0.65)
            }
        }

        Column {
            anchors.right: parent.right
            anchors.rightMargin: dome.edge
            y: 42 * dome.sc
            spacing: 2 * dome.sc

            Book {
                anchors.right: parent.right
                readonly property real pct: Services.Battery.percentage
                text: "clockwork wound " + Math.round(pct) + "%" + (Services.Battery.charging ? ", winding" : "")
                font.pixelSize: 17 * dome.sc
                font.italic: true
                color: pct <= 20 && !Services.Battery.charging ? Sky.danger : Sky.alpha(Sky.parchment, 0.7)
            }

            Text {
                anchors.right: parent.right
                text: Sky.siteLine
                font.family: Sky.caps
                font.pixelSize: 13 * dome.sc
                font.letterSpacing: 1.5 * dome.sc
                color: Sky.alpha(Sky.brass, 0.8)
            }

            Book {
                anchors.right: parent.right
                visible: dome.ctx.capsLock
                text: "caps lock"
                font.pixelSize: 16 * dome.sc
                font.italic: true
                color: Sky.danger
            }
        }

        // New stars in the catalogue (achievements), top right.
        Column {
            anchors.right: parent.right
            anchors.rightMargin: dome.edge
            y: 120 * dome.sc
            spacing: 12 * dome.sc
            visible: dome.granted

            Repeater {
                model: dome.reward ? dome.reward.achievements.slice(0, 3) : []

                Item {
                    id: slip
                    required property int index
                    required property var modelData
                    readonly property real appear: LockTheme.seg(dome.rewardIn, 0.15 + index * 0.18, 0.45 + index * 0.18)
                    width: 430 * dome.sc
                    height: 68 * dome.sc
                    opacity: appear
                    transform: Translate { y: (1 - slip.appear) * -16 * dome.sc }

                    Rectangle {
                        anchors.fill: parent
                        radius: 8 * dome.sc
                        color: Sky.parchment
                        border.width: Math.max(1, 1.5 * dome.sc)
                        border.color: Sky.brass

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4 * dome.sc
                            radius: 5 * dome.sc
                            color: "transparent"
                            border.width: Math.max(1, dome.sc)
                            border.color: Sky.alpha(Sky.brassDeep, 0.35)
                        }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 22 * dome.sc
                        spacing: 14 * dome.sc

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            text: slip.modelData.icon
                            filled: true
                            font.pixelSize: 24 * dome.sc
                            color: Sky.brassDeep
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: "A new star catalogued: " + slip.modelData.name
                                font.family: Sky.display
                                font.pixelSize: 19 * dome.sc
                                color: Sky.ink
                            }

                            Text {
                                text: slip.modelData.desc
                                font.family: Sky.book
                                font.pixelSize: 14 * dome.sc
                                font.italic: true
                                color: Sky.alpha(Sky.ink, 0.75)
                            }
                        }
                    }
                }
            }
        }

        // The observer, bottom left.
        Row {
            x: dome.edge
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 50 * dome.sc
            spacing: 22 * dome.sc

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 96 * dome.sc
                height: width

                Rectangle {
                    id: medallionMask
                    anchors.fill: parent
                    anchors.margins: 7 * dome.sc
                    radius: width / 2
                    visible: false
                    layer.enabled: true
                }

                Image {
                    id: avatar
                    anchors.fill: medallionMask
                    source: "file://" + Quickshell.env("HOME") + "/.cache/current_avatar"
                    sourceSize: Qt.size(width * 2, height * 2)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    visible: false
                }

                MultiEffect {
                    anchors.fill: medallionMask
                    source: avatar
                    visible: avatar.status === Image.Ready
                    maskEnabled: true
                    maskSource: medallionMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                    saturation: -0.3
                    colorization: 0.15
                    colorizationColor: "#a0784a"
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 5 * dome.sc
                    border.color: Sky.brass
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 6 * dome.sc
                    radius: width / 2
                    color: "transparent"
                    border.width: Math.max(1, dome.sc)
                    border.color: Sky.alpha(Sky.brassDeep, 0.8)
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5 * dome.sc

                Row {
                    spacing: 12 * dome.sc

                    Text {
                        id: nameText
                        text: dome.ctx.userName
                        font.family: Sky.display
                        font.pixelSize: 34 * dome.sc
                        color: Sky.parchment
                    }

                    Book {
                        anchors.baseline: nameText.baseline
                        text: Sky.rank(dome.shownLevel)
                        font.pixelSize: 19 * dome.sc
                        font.italic: true
                        color: dome.promote > 0 ? Sky.lamp : Sky.brass
                    }
                }

                // Observations towards the next rank, read off a vernier.
                Item {
                    id: vernier
                    readonly property real progress: Math.max(0, Math.min(1, (dome.shownXp - dome.levelFloor) / Math.max(1, dome.levelCeil - dome.levelFloor)))
                    width: 300 * dome.sc
                    height: 14 * dome.sc

                    Rectangle {
                        y: 4 * dome.sc
                        width: parent.width
                        height: Math.max(1, dome.sc)
                        color: Sky.alpha(Sky.brass, 0.5)
                    }

                    ScaleTicks {
                        y: 4 * dome.sc
                        width: parent.width
                        height: 8 * dome.sc
                        step: parent.width / 20
                        major: 5
                        minorLength: 4 * dome.sc
                        majorLength: 8 * dome.sc
                        color: Sky.alpha(Sky.brass, 0.55)
                    }

                    Rectangle {
                        y: 3 * dome.sc
                        width: parent.width * vernier.progress
                        height: 3 * dome.sc
                        color: Sky.brass
                    }
                }

                Book {
                    text: Math.floor(dome.shownXp - dome.levelFloor) + " / " + (dome.levelCeil - dome.levelFloor) + " observations"
                        + "  ·  " + Services.LockStats.liveStreak + " nights running"
                        + "  ·  " + Services.LockStats.achievements.length + "/" + Services.LockStats.achievementDefs.length + " stars named"
                    font.pixelSize: 15 * dome.sc
                    color: Sky.alpha(Sky.parchment, 0.65)
                }
            }
        }

        // The music of the spheres, bottom centre.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: 60 * dome.sc
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 58 * dome.sc
            spacing: 12 * dome.sc
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
                    font.pixelSize: 20 * dome.sc
                    color: mediaArea.containsMouse ? Sky.brass : Sky.alpha(Sky.parchment, 0.75)

                    MouseArea {
                        id: mediaArea
                        anchors.fill: parent
                        anchors.margins: -6 * dome.sc
                        enabled: !dome.still
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.Media[mediaKey.modelData]()
                    }
                }
            }

            Book {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 460 * dome.sc)
                elide: Text.ElideRight
                text: "the spheres play " + Services.Media.title + (Services.Media.artist ? ", by " + Services.Media.artist : "")
                font.pixelSize: 17 * dome.sc
                font.italic: true
            }
        }

        // The knobs, bottom right: hold one to turn it.
        Row {
            anchors.right: parent.right
            anchors.rightMargin: dome.edge
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 42 * dome.sc
            spacing: 22 * dome.sc

            Repeater {
                model: [
                    { label: "rest", icon: "bedtime", act: "suspend" },
                    { label: "turn again", icon: "restart_alt", act: "reboot" },
                    { label: "close the dome", icon: "power_settings_new", act: "poweroff" }
                ]

                Column {
                    id: knob
                    required property var modelData
                    spacing: 6 * dome.sc

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 54 * dome.sc
                        height: width

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: knobHold.containsMouse ? "#1a1d28" : "#10131c"
                            border.width: Math.max(1, 2 * dome.sc)
                            border.color: Sky.brass
                        }

                        // Held: a brass arc runs round it.
                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            visible: knobHold.progress > 0

                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: Sky.lamp
                                strokeWidth: 3 * dome.sc
                                capStyle: ShapePath.RoundCap

                                PathAngleArc {
                                    centerX: 27 * dome.sc
                                    centerY: 27 * dome.sc
                                    radiusX: 22 * dome.sc
                                    radiusY: 22 * dome.sc
                                    startAngle: -90
                                    sweepAngle: 360 * knobHold.progress
                                }
                            }
                        }

                        Glyph {
                            anchors.centerIn: parent
                            text: knob.modelData.icon
                            font.pixelSize: 21 * dome.sc
                            color: Sky.parchment
                        }

                        HoldArea {
                            id: knobHold
                            anchors.fill: parent
                            enabled: !dome.still
                            onConfirmed: dome.ctx[knob.modelData.act]()
                        }
                    }

                    Book {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: knob.modelData.label
                        font.pixelSize: 14 * dome.sc
                        font.italic: true
                        color: Sky.alpha(Sky.parchment, 0.7)
                    }
                }
            }
        }
    }

    // ── The desktop, under the dome ──────────────────────────────────
    CaptureImage {
        id: capture
        source: dome.shot
        imageWidth: dome.width
        imageHeight: dome.height
    }

    ShaderEffect {
        anchors.fill: parent
        visible: capture.ready && dome.opening < 1

        property variant source: capture.image
        property real itemWidth: width
        property real itemHeight: height
        property real progress: dome.opening
        property color nightColor: Sky.night
        property color brassColor: Sky.brass

        fragmentShader: Qt.resolvedUrl("../../../../shaders/lock_dome.frag.qsb")
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        visible: !capture.ready && opacity > 0
        opacity: 1 - dome.opening
    }

    // ── Choreography ─────────────────────────────────────────────────
    ParallelAnimation {
        id: intro
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation { target: dome; property: "opening"; from: 0; to: 1; duration: 1400; easing.type: Easing.InOutSine }
        }
        SequentialAnimation {
            PauseAnimation { duration: 1000 }
            NumberAnimation { target: dome; property: "uiIn"; from: 0; to: 1; duration: 550; easing.type: Easing.OutCubic }
        }
    }

    // The shutters close and day breaks: the last frame is the desktop
    // exactly.
    ParallelAnimation {
        id: outro
        NumberAnimation { target: dome; property: "uiIn"; to: 0; duration: 280 }
        SequentialAnimation {
            PauseAnimation { duration: 140 }
            NumberAnimation { target: dome; property: "opening"; to: 0; duration: 1000; easing.type: Easing.InOutSine }
        }
    }

    ParallelAnimation {
        id: deniedFx
        SequentialAnimation {
            NumberAnimation { target: dome; property: "shakeX"; to: -9 * dome.sc; duration: 50 }
            NumberAnimation { target: dome; property: "shakeX"; to: 7 * dome.sc; duration: 70 }
            NumberAnimation { target: dome; property: "shakeX"; to: -3 * dome.sc; duration: 70 }
            NumberAnimation { target: dome; property: "shakeX"; to: 0; duration: 80 }
        }
        SequentialAnimation {
            NumberAnimation { target: dome; property: "cloud"; to: 0.9; duration: 380; easing.type: Easing.OutCubic }
            PauseAnimation { duration: 700 }
            NumberAnimation { target: dome; property: "cloud"; to: dome.totality ? 0.5 : 0; duration: 1400; easing.type: Easing.InOutSine }
        }
        SequentialAnimation {
            NumberAnimation { target: dome; property: "glow"; to: 0.3; duration: 80 }
            NumberAnimation { target: dome; property: "glow"; to: dome.totality ? 0.4 : 1; duration: 900 }
        }
    }

    ParallelAnimation {
        id: grantFx
        NumberAnimation { target: dome; property: "grantIn"; from: 0; to: 1; duration: 400 }
        NumberAnimation { target: dome; property: "cloud"; to: 0; duration: 500 }
        SequentialAnimation {
            PauseAnimation { duration: 500 }
            NumberAnimation { target: dome; property: "bloom"; from: 0; to: 0.8; duration: 500; easing.type: Easing.OutCubic }
            NumberAnimation { target: dome; property: "bloom"; to: 0.3; duration: 700; easing.type: Easing.InOutSine }
        }
        SequentialAnimation {
            PauseAnimation { duration: 350 }
            NumberAnimation { target: dome; property: "rewardIn"; from: 0; to: 1; duration: 750 }
        }
    }

    SequentialAnimation {
        id: observationsFill
        PauseAnimation { duration: 450 }
        NumberAnimation {
            target: dome
            property: "shownXp"
            to: dome.reward ? dome.reward.xpAfter : 0
            duration: 800
            easing.type: Easing.InOutCubic
        }
        PropertyAction { target: dome; property: "rewarding"; value: false }
    }

    NumberAnimation {
        id: promoteFx
        target: dome
        property: "promote"
        from: 0
        to: 1
        duration: 300
    }
}
