pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs.components
import qs.modules.lock
import qs.services as Services

// "Deathblow" theme: a duel in Ashina by night, after FromSoftware's
// Sekiro: Shadows Die Twice.
//
// Lock-in: night falls on the desktop and a great moon comes up over it
// (shaders/lock_ashina), the silver grass of the Ashina Reservoir rises
// along the foot of the screen (shaders/susuki) and the season drifts down
// (shaders/desktop_sekiro, running). The foe of the hour (Shinobi.stretch)
// stands in the corner with his deathblow mark, his posture gauge across
// the top of the screen, and the shinobi's HUD at the bottom left: your
// resurrection nodes (the faillock lives), your vitality (the battery),
// your rank and skill experience (XP).
//
// The passcode is the duel: each keystroke deflects a blow in a spray of
// sparks and fills the foe's posture. Enter is the deathblow: its red mark
// burns while PAM decides. A wrong passcode is a perilous attack, 危: it
// lands, a resurrection node is struck out with a stroke of ink, and his
// posture recovers. Spend them all and it's 死 until the lockout ends,
// then 回生, and you rise. The right one is a blood-red cut across the
// screen and 忍殺, Shinobi Execution: skill experience is counted (a level
// is a skill point and maybe a new rank), achievements come as memories,
// and then the night lifts off the desktop.
//
// Theme contract (see ThemeHost): ctx, shot, shown, still, minScale.
Item {
    id: duel

    required property LockContext ctx
    property url shot
    property bool shown: true
    property bool still: false
    property real minScale: 0.7

    readonly property real sc: Math.max(minScale, Math.min(2, Math.min(width / 1920, height / 1080)))
    readonly property real margin: 64 * sc
    // Where blades meet, and where the big characters are written.
    readonly property point centre: Qt.point(width / 2, height * 0.38)
    readonly property point moonPos: Qt.point(width * 0.74, height * 0.3)
    readonly property real moonR: 118 * sc

    // Choreography.
    property real night: 0
    property real grass: 0
    property real uiIn: 0
    property real death: 0
    property real hurt: 0
    property real flash: 0
    property real gust: 0
    property real shakeX: 0
    property real shakeY: 0
    // The big characters, written (0..1) and faded (1..0).
    property real perilIn: 0
    property real perilOut: 0
    property real deathIn: 0
    property real riseIn: 0
    property real riseOut: 0
    property real cut: 0
    property real execIn: 0
    property real execOut: 1
    property real markIn: 0
    property real grantIn: 0
    property real rewardIn: 0
    property real promote: 0
    property real clash: 0

    readonly property bool granted: ctx.phase === "granted" || ctx.phase === "exiting"
    readonly property bool verifying: ctx.phase === "verifying"
    readonly property var reward: ctx.reward
    // Dead: locked out, nothing typed.
    readonly property bool dead: ctx.lockedOut && ctx.cells === 0

    // The foe's posture: a notch a keystroke, twelve to break it; it
    // recovers when the blow is turned, and breaks on the deathblow.
    readonly property real postureTarget: still ? 0.42 : granted ? 1 : ctx.denying || dead ? 0 : Math.min(1, ctx.cells / 12)
    property real posture: postureTarget
    Behavior on posture {
        NumberAnimation {
            duration: duel.ctx.denying ? 520 : 170
            easing.type: Easing.OutCubic
        }
    }

    // Skill experience (XP) on the card: follow the stored XP, but run up
    // from the old value during the reward.
    property real shownXp: Services.LockStats.xp
    readonly property int shownLevel: Services.LockStats.levelFor(shownXp)
    readonly property int levelFloor: Services.LockStats.xpForLevel(shownLevel)
    readonly property int levelCeil: Services.LockStats.xpForLevel(shownLevel + 1)
    property bool rewarding: false
    property int _seenLevel: 0

    // Vitality: the battery (full where there is none).
    readonly property bool hasBattery: Services.Battery.percentage > 0 || Services.Battery.charging
    readonly property real vitality: hasBattery ? Math.max(0, Math.min(1, Services.Battery.percentage / 100)) : 1

    // Where the shinobi is moves on every two hours; read once a minute.
    property date minute: new Date()
    readonly property var stretch: Shinobi.stretch(minute)
    readonly property var season: Shinobi.season(minute)
    readonly property var tints: [["#f7cbd6", "#e98aa8"], ["#e4ff9a", "#fff4bf"], ["#de5a2c", "#a3221a"], ["#f4f7fb", "#c9d3e2"]][season.fall]

    Connections {
        target: duel.ctx

        function onNowChanged() {
            const n = duel.ctx.now;
            if (n.getMinutes() !== duel.minute.getMinutes() || n.getHours() !== duel.minute.getHours())
                duel.minute = n;
        }
    }

    Component.onCompleted: {
        _seenLevel = shownLevel;
        if (still) {
            night = 1;
            grass = 1;
            uiIn = 1;
        } else if (shown) {
            startIntro();
        } else {
            introFallback.start();
        }
        if (dead && !still)
            deathFx.start();
    }

    onShownLevelChanged: {
        if (rewarding && _seenLevel > 0 && shownLevel > _seenLevel)
            promoteFx.restart();
        _seenLevel = shownLevel;
    }

    onShownChanged: if (shown && !still) startIntro()

    onDeadChanged: {
        if (still)
            return;
        if (dead) {
            riseFx.stop();
            riseIn = 0;
            riseOut = 0;
            deathFx.restart();
        } else if (death > 0) {
            deathFx.stop();
            riseFx.restart();
        }
    }

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
        onTriggered: duel.startIntro()
    }

    Connections {
        target: duel.ctx

        function onPhaseChanged() {
            if (duel.ctx.phase === "exiting") {
                intro.stop();
                outro.start();
            } else if (duel.ctx.phase === "verifying") {
                markFx.restart();
            } else if (duel.ctx.phase === "ready" && !duel.granted) {
                duel.markIn = 0;
            }
        }

        function onTyped(index) {
            duel.deflect(index);
        }

        function onDenied(costLife) {
            duel.markIn = 0;
            deniedFx.restart();
        }

        function onGranted() {
            if (duel.reward) {
                duel.rewarding = true;
                duel.shownXp = duel.reward.xpBefore;
                expFill.restart();
            }
            grantFx.restart();
        }
    }

    // ── A blow deflected: sparks where the blades meet ───────────────
    Component {
        id: sparkComponent
        Spark {}
    }

    function deflect(index) {
        if (still)
            return;
        clashFx.restart();
        const n = 9 + (index % 3) * 2;
        for (let i = 0; i < n; i++) {
            const a = (Math.random() - 0.5) * Math.PI * 0.9 + (i % 2 === 0 ? 0 : Math.PI);
            const v = (160 + Math.random() * 260) * sc;
            const s = (2 + Math.random() * 3) * sc;
            sparkComponent.createObject(sparks, {
                x: centre.x - s / 2,
                y: centre.y - s / 2,
                width: s * (2 + Math.random() * 3),
                height: s * 0.6,
                vx: Math.cos(a) * v,
                vy: Math.sin(a) * v * 0.55 - 40 * sc,
                spin: (Math.random() - 0.5) * 120,
                life: 320 + Math.random() * 260,
                color: Math.random() < 0.35 ? "#fff3d2" : Math.random() < 0.5 ? Shinobi.postureGold : Shinobi.postureOrange
            });
        }
    }

    // ── The world, by moonlight ──────────────────────────────────────
    CaptureImage {
        id: capture
        source: duel.shot
        imageWidth: duel.width
        imageHeight: duel.height
    }

    ShaderEffect {
        anchors.fill: parent
        visible: capture.ready

        property variant source: capture.image
        property real itemWidth: width
        property real itemHeight: height
        property real night: duel.night
        property real death: duel.death
        property real hurt: duel.hurt
        property real flash: duel.flash
        property point moonPos: duel.moonPos
        property real moonR: duel.moonR
        property color moonColor: Shinobi.moon
        property color bloodColor: Shinobi.kanji

        fragmentShader: Qt.resolvedUrl("../../../../shaders/lock_ashina.frag.qsb")
    }

    Rectangle {
        anchors.fill: parent
        color: Shinobi.night
        visible: !capture.ready
        opacity: duel.night
    }

    // The season falling.
    ShaderEffect {
        anchors.fill: parent
        visible: duel.night > 0
        opacity: 1 - duel.death * 0.7

        property real itemWidth: width
        property real itemHeight: height
        property real boot: duel.night
        property real lineScale: 1
        property real fall: duel.season.fall
        property real drift: duel.ctx.ambientTime * 34 * duel.sc
        property real chrome: 0
        property real unit: duel.sc
        property color mistColor: Shinobi.moon
        property color tintA: duel.tints[0]
        property color tintB: duel.tints[1]

        fragmentShader: Qt.resolvedUrl("../../../../shaders/desktop_sekiro.frag.qsb")
    }

    // The silver grass along the foot.
    ShaderEffect {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * 0.3
        visible: duel.grass > 0

        property real itemWidth: width
        property real itemHeight: height
        property real time: duel.ctx.ambientTime
        property real rise: duel.grass
        property real wind: 1
        property real gust: duel.gust
        property real unit: duel.sc
        property color stalkColor: Qt.tint("#0a0d14", Shinobi.alpha(Shinobi.kanji, duel.death * 0.2))
        property color plumeColor: Qt.tint("#b8c2d2", Shinobi.alpha(Shinobi.kanji, duel.death * 0.3))

        fragmentShader: Qt.resolvedUrl("../../../../shaders/susuki.frag.qsb")
    }

    // Shade under the words along the head and the foot.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height * 0.22
        opacity: duel.uiIn * 0.85
        gradient: Gradient {
            GradientStop { position: 0; color: Shinobi.alpha("#05060a", 0.7) }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    LockInput {
        ctx: duel.ctx
        active: !duel.still
        onEscapePressed: duel.ctx.clearInput()
    }

    component Book: Text {
        font.family: Shinobi.book
        font.pixelSize: 20 * duel.sc
        color: Shinobi.ivory
    }

    component Display: Text {
        font.family: Shinobi.display
        font.pixelSize: 26 * duel.sc
        color: Shinobi.ivory
    }

    Item {
        id: scene
        anchors.fill: parent
        transform: Translate {
            x: duel.shakeX
            y: duel.shakeY
        }

        // ── The foe, top left: his name, his vitality, his mark ──────
        Column {
            x: duel.margin
            y: duel.margin * 0.75
            spacing: 6 * duel.sc
            opacity: duel.uiIn
            transform: Translate { x: -(1 - duel.uiIn) * 30 * duel.sc }

            layer.enabled: !duel.still
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.85
                shadowBlur: 0.5
                blurMax: 16
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 2
            }

            Row {
                spacing: 12 * duel.sc

                Display {
                    id: foeName
                    text: duel.stretch.foe
                    font.pixelSize: 30 * duel.sc
                }

                // His deathblow mark: put out by the deathblow.
                Rectangle {
                    anchors.verticalCenter: foeName.verticalCenter
                    width: 12 * duel.sc
                    height: width
                    radius: width / 2
                    color: Shinobi.kanji
                    border.width: Math.max(1, duel.sc)
                    border.color: "#2a0507"
                    opacity: 1 - duel.grantIn
                    scale: 1 + duel.grantIn * 1.4
                }
            }

            Rectangle {
                width: 380 * duel.sc
                height: 7 * duel.sc
                color: Shinobi.alpha("black", 0.6)
                border.width: Math.max(1, duel.sc)
                border.color: Shinobi.alpha(Shinobi.steel, 0.3)

                Rectangle {
                    x: Math.max(1, duel.sc)
                    y: Math.max(1, duel.sc)
                    width: (parent.width - 2 * x) * (1 - duel.grantIn)
                    height: parent.height - 2 * y
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#ff6a4a" }
                        GradientStop { position: 1; color: "#a3221a" }
                    }
                }
            }

            Book {
                topPadding: 2 * duel.sc
                text: Shinobi.place(duel.stretch)
                font.pixelSize: 16 * duel.sc
                color: Shinobi.alpha(Shinobi.landLight, 0.9)
            }
        }

        // ── His posture, across the top ──────────────────────────────
        PostureGauge {
            id: postureGauge
            x: (duel.width - width) / 2
            y: 70 * duel.sc
            width: 640 * duel.sc
            height: 22 * duel.sc
            opacity: duel.uiIn
            value: duel.posture
            lineWidth: Math.max(1, 1.3 * duel.sc)
            gold: Shinobi.postureGold
            orange: Shinobi.postureOrange
            red: Shinobi.postureRed
            flash: duel.ctx.cells >= 12 && !duel.granted ? 0.4 + 0.4 * Math.sin(duel.ctx.ambientTime * 9) : duel.grantIn * (1 - duel.rewardIn)
        }

        // ── Where blades meet ────────────────────────────────────────
        Item {
            id: sparks
            anchors.fill: parent
        }

        // The ring of a deflection.
        Rectangle {
            x: duel.centre.x - width / 2
            y: duel.centre.y - height / 2
            width: (40 + 110 * duel.clash) * duel.sc
            height: width
            radius: width / 2
            visible: duel.clash > 0 && duel.clash < 1
            color: "transparent"
            border.width: 3 * duel.sc * (1 - duel.clash)
            border.color: "#fff1cc"
            opacity: 1 - duel.clash
        }

        // The deathblow mark, burning while the blade falls.
        Item {
            id: mark
            x: duel.centre.x - width / 2
            y: duel.centre.y - height / 2
            width: 150 * duel.sc
            height: width
            visible: duel.markIn > 0
            opacity: Math.min(1, duel.markIn * 1.4) * (1 - duel.grantIn)
            scale: 0.6 + 0.4 * duel.markIn + 0.25 * duel.grantIn

            layer.enabled: visible
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#ff2a2a"
                shadowOpacity: 0.9
                shadowBlur: 0.9
                blurMax: 32
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Shinobi.kanji
                    strokeWidth: 9 * duel.sc
                    PathAngleArc {
                        centerX: mark.width / 2
                        centerY: mark.height / 2
                        radiusX: mark.width / 2 - 8 * duel.sc
                        radiusY: radiusX
                        startAngle: 0
                        sweepAngle: 360
                    }
                }

                ShapePath {
                    fillColor: Shinobi.kanji
                    strokeColor: "transparent"
                    PathAngleArc {
                        centerX: mark.width / 2
                        centerY: mark.height / 2
                        radiusX: mark.width * 0.13
                        radiusY: radiusX
                        startAngle: 0
                        sweepAngle: 360
                    }
                }
            }

            SequentialAnimation on scale {
                running: duel.verifying
                loops: Animation.Infinite
                NumberAnimation { to: 1.08; duration: 380; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.96; duration: 380; easing.type: Easing.InOutSine }
            }
        }

        // ── The big characters ───────────────────────────────────────
        // 危: a perilous attack.
        BrushKanji {
            x: duel.centre.x - width / 2
            y: duel.centre.y - height / 2 - 40 * duel.sc
            text: Shinobi.peril
            size: 220 * duel.sc
            ink: Shinobi.kanji
            progress: duel.perilIn
            opacity: 1 - duel.perilOut
            seed: 4
            dry: 0.65
        }

        // 死: dead, until the lockout ends.
        Column {
            x: duel.centre.x - width / 2
            y: duel.centre.y - deathKanji.height / 2
            spacing: 0
            visible: duel.deathIn > 0

            BrushKanji {
                id: deathKanji
                anchors.horizontalCenter: parent.horizontalCenter
                text: Shinobi.death
                size: 290 * duel.sc
                ink: Shinobi.kanji
                progress: duel.deathIn
                opacity: 1 - duel.riseIn
                seed: 1
                dry: 0.7
            }
        }

        // 回生: rising again.
        Column {
            x: duel.centre.x - width / 2
            y: duel.centre.y - riseKanji.height / 2
            visible: duel.riseIn > 0 && duel.riseOut < 1
            opacity: 1 - duel.riseOut

            BrushKanji {
                id: riseKanji
                anchors.horizontalCenter: parent.horizontalCenter
                text: Shinobi.resurrection
                size: 200 * duel.sc
                ink: "#f3ecdf"
                progress: duel.riseIn
                seed: 3
                dry: 0.5
            }

            Book {
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: Math.max(0, duel.riseIn * 2 - 1)
                text: "RESURRECTION"
                font.family: Shinobi.display
                font.pixelSize: 26 * duel.sc
                font.letterSpacing: 10 * duel.sc
                color: Shinobi.alpha(Shinobi.ivory, 0.85)
            }
        }

        // The deathblow: a cut of blood across the screen...
        BrushStroke {
            x: duel.width * 0.5 - width / 2
            y: duel.centre.y - height / 2
            width: duel.width * 1.15
            height: 70 * duel.sc
            rotation: -24
            visible: duel.cut > 0
            reveal: duel.cut
            opacity: duel.execOut
            ink: Shinobi.alpha(Shinobi.kanji, 0.92)
            seed: 7
            dry: 0.85
            weight: 0.7
        }

        // ...and 忍殺.
        Column {
            x: duel.centre.x - width / 2
            y: duel.centre.y - execKanji.height / 2
            visible: duel.execIn > 0
            opacity: duel.execOut

            BrushKanji {
                id: execKanji
                anchors.horizontalCenter: parent.horizontalCenter
                text: Shinobi.execution
                size: 210 * duel.sc
                ink: Shinobi.kanji
                progress: duel.execIn
                seed: 2
                dry: 0.6
            }

            Book {
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: Math.max(0, duel.execIn * 2 - 1)
                text: "SHINOBI EXECUTION"
                font.family: Shinobi.display
                font.pixelSize: 30 * duel.sc
                font.letterSpacing: 12 * duel.sc
                color: Shinobi.ivory
                style: Text.Raised
                styleColor: Shinobi.alpha("black", 0.6)
            }
        }

        // ── The hour, top right ──────────────────────────────────────
        Column {
            anchors.right: parent.right
            anchors.rightMargin: duel.margin
            y: duel.margin * 0.55
            spacing: 0
            opacity: duel.uiIn * (1 - duel.death * 0.6)
            transform: Translate { x: (1 - duel.uiIn) * 30 * duel.sc }

            layer.enabled: !duel.still
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.85
                shadowBlur: 0.6
                blurMax: 20
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 3
            }

            Row {
                anchors.right: parent.right
                spacing: 10 * duel.sc

                Display {
                    id: time
                    text: Qt.formatTime(duel.ctx.now, "h:mm AP").split(" ")[0]
                    font.pixelSize: 104 * duel.sc
                }

                Book {
                    anchors.baseline: time.baseline
                    text: duel.ctx.now.getHours() < 12 ? "a.m." : "p.m."
                    font.pixelSize: 28 * duel.sc
                    color: Shinobi.landLight
                }
            }

            Book {
                anchors.right: parent.right
                text: Shinobi.date(duel.ctx.now)
                font.pixelSize: 21 * duel.sc
            }

            Book {
                anchors.right: parent.right
                topPadding: 4 * duel.sc
                text: duel.stretch.deed
                font.pixelSize: 17 * duel.sc
                color: Shinobi.alpha(Shinobi.ivory, 0.75)
            }

            Book {
                anchors.right: parent.right
                topPadding: 4 * duel.sc
                text: (duel.season.name + "  ·  " + duel.season.line).toUpperCase()
                font.pixelSize: 12 * duel.sc
                font.letterSpacing: 2 * duel.sc
                color: Shinobi.alpha(Shinobi.ivory, 0.6)
            }
        }

        // ── What's happening, bottom centre ──────────────────────────
        // A soft dark drift behind it, so it reads over the moonlit grass.
        Rectangle {
            x: status.x + status.width / 2 - width / 2
            y: status.y + status.height / 2 - height / 2
            width: Math.max(status.width + 260 * duel.sc, 700 * duel.sc)
            height: status.height + 120 * duel.sc
            radius: height / 2
            opacity: duel.uiIn * 0.75
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.3; color: Shinobi.alpha("#05060a", 0.55) }
                GradientStop { position: 0.7; color: Shinobi.alpha("#05060a", 0.55) }
                GradientStop { position: 1; color: "transparent" }
            }
        }

        Column {
            id: status
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: duel.height * 0.27
            spacing: 4 * duel.sc
            opacity: duel.uiIn

            layer.enabled: !duel.still
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.95
                shadowBlur: 0.6
                blurMax: 20
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 2
            }

            Display {
                anchors.horizontalCenter: parent.horizontalCenter
                readonly property var c: duel.ctx
                text: duel.granted ? "Welcome back, " + c.userName
                    : duel.verifying ? "Deathblow…"
                    : c.denying ? "Perilous attack!"
                    : duel.dead ? "You died"
                    : c.cells >= 12 ? "Their posture breaks: strike!"
                    : c.cells > 0 ? "Deflect!"
                    : "Draw your blade"
                font.pixelSize: 44 * duel.sc
                color: c.denying || duel.dead ? Shinobi.danger : duel.granted ? Shinobi.postureGold : Shinobi.ivory
            }

            Book {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, 900 * duel.sc)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                readonly property var c: duel.ctx
                text: duel.granted
                    ? (duel.reward ? "+" + Math.round(duel.reward.total * Math.min(1, duel.rewardIn * 1.3)) + " skill experience" + (duel.promote > 0 ? "  ·  a skill point: you are " + Shinobi.rank(duel.shownLevel) : "") : duel.stretch.foe + " falls")
                    : c.message.length > 0 ? c.message
                    : duel.verifying ? "the blade falls…"
                    : duel.dead ? "you rise again in " + (c.lockoutClock || "a while") + ": rest, and let the Dragonrot pass"
                    : c.capsLock ? "caps lock is on"
                    : c.lastLife ? "one resurrection left: hesitation is defeat"
                    : c.denying ? "it lands, and a resurrection node is spent"
                    : c.cells >= 12 ? "press Enter for the deathblow"
                    : c.cells > 0 ? duel.stretch.foe + "'s posture gives a little more with every blow"
                    : "every key you strike is a blow deflected; Enter is the deathblow"
                font.pixelSize: 20 * duel.sc
                color: !duel.granted && (c.message.length > 0 || duel.dead || c.capsLock || c.lastLife) ? Shinobi.danger : Shinobi.alpha(Shinobi.ivory, 0.85)
            }

            Book {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: duel.granted && duel.reward !== null
                opacity: duel.rewardIn
                text: duel.reward
                    ? duel.reward.lines.map(l => l.label.toLowerCase() + " +" + l.xp).join("  ·  ")
                      + (duel.reward.multiplier > 1 ? "  ·  streak ×" + duel.reward.multiplier.toFixed(2) : "")
                    : ""
                font.pixelSize: 16 * duel.sc
                color: Shinobi.alpha(Shinobi.ivory, 0.66)
            }
        }

        // Memories gained (achievements), under the characters.
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: duel.centre.y + 190 * duel.sc
            spacing: 8 * duel.sc
            visible: duel.granted

            Repeater {
                model: duel.reward ? duel.reward.achievements.slice(0, 3) : []

                Row {
                    id: memory
                    required property int index
                    required property var modelData
                    readonly property real appear: LockTheme.seg(duel.rewardIn, 0.2 + index * 0.18, 0.5 + index * 0.18)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12 * duel.sc
                    opacity: appear * duel.execOut

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        text: memory.modelData.icon
                        filled: true
                        font.pixelSize: 24 * duel.sc
                        color: Shinobi.postureGold
                    }

                    Book {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Memory: " + memory.modelData.name + "  ·  " + memory.modelData.desc
                        font.pixelSize: 18 * duel.sc
                        style: Text.Raised
                        styleColor: Shinobi.alpha("black", 0.7)
                    }
                }
            }
        }

        // ── The shinobi, bottom left ─────────────────────────────────
        Column {
            x: duel.margin
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 48 * duel.sc
            spacing: 8 * duel.sc
            opacity: duel.uiIn
            transform: Translate { x: -(1 - duel.uiIn) * 30 * duel.sc }

            layer.enabled: !duel.still
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.9
                shadowBlur: 0.55
                blurMax: 18
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 2
            }

            // Your resurrection nodes: the faillock lives.
            Row {
                spacing: 8 * duel.sc
                visible: duel.ctx.maxLives > 0

                Repeater {
                    model: Math.min(Math.max(duel.ctx.maxLives, 1), 5)

                    ResurrectionNode {
                        required property int index
                        width: 42 * duel.sc
                        height: width
                        emblem: index % 2
                        lit: !duel.dead && index < duel.ctx.lives
                        struck: duel.dead || index >= duel.ctx.lives
                        glow: duel.granted ? 1 : 0
                        seed: index + 1
                        rose: Shinobi.node
                        roseGlow: Shinobi.nodeGlow
                    }
                }
            }

            // Vitality: the battery.
            Item {
                id: vit
                width: 420 * duel.sc
                height: 13 * duel.sc
                readonly property bool low: duel.hasBattery && duel.vitality <= 0.2 && !Services.Battery.charging

                Rectangle {
                    x: 3 * duel.sc
                    width: parent.width - 6 * duel.sc
                    height: parent.height
                    color: Shinobi.alpha("black", 0.6)
                    border.width: Math.max(1, duel.sc)
                    border.color: Shinobi.alpha(Shinobi.steel, 0.35)

                    Rectangle {
                        x: 2 * duel.sc
                        y: 2 * duel.sc
                        width: Math.max(0, (parent.width - 4 * duel.sc) * duel.vitality)
                        height: parent.height - 4 * duel.sc
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.lighter(vit.low ? Shinobi.vitalityLow : Shinobi.vitality, 1.25) }
                            GradientStop { position: 0.5; color: vit.low ? Shinobi.vitalityLow : Shinobi.vitality }
                            GradientStop { position: 1; color: Qt.darker(vit.low ? Shinobi.vitalityLow : Shinobi.vitality, 1.5) }
                        }
                    }
                }

                Repeater {
                    model: 2

                    Rectangle {
                        required property int index
                        x: index === 0 ? 0 : vit.width - width
                        y: -3 * duel.sc
                        width: 3 * duel.sc
                        height: vit.height + 6 * duel.sc
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#e7e9ec" }
                            GradientStop { position: 1; color: "#7d8188" }
                        }
                    }
                }
            }

            Row {
                spacing: 12 * duel.sc

                Display {
                    id: nameText
                    text: duel.ctx.userName
                    font.pixelSize: 32 * duel.sc
                }

                Book {
                    anchors.baseline: nameText.baseline
                    text: Shinobi.rank(duel.shownLevel)
                    font.pixelSize: 20 * duel.sc
                    color: duel.promote > 0 ? Shinobi.postureGold : Shinobi.landLight
                }
            }

            // Skill experience towards the next skill point.
            Rectangle {
                readonly property real progress: Math.max(0, Math.min(1, (duel.shownXp - duel.levelFloor) / Math.max(1, duel.levelCeil - duel.levelFloor)))
                width: 340 * duel.sc
                height: 4 * duel.sc
                color: Shinobi.alpha("black", 0.55)

                Rectangle {
                    width: parent.width * parent.progress
                    height: parent.height
                    color: Shinobi.postureGold
                }
            }

            Book {
                text: Shinobi.count(Math.floor(duel.shownXp - duel.levelFloor)) + " / " + Shinobi.count(duel.levelCeil - duel.levelFloor) + " skill experience"
                    + "  ·  " + Services.LockStats.liveStreak + " days undying"
                    + "  ·  " + Services.LockStats.achievements.length + "/" + Services.LockStats.achievementDefs.length + " memories"
                    + (duel.ctx.capsLock ? "  ·  caps lock" : "")
                font.pixelSize: 15 * duel.sc
                color: Shinobi.alpha(Shinobi.ivory, 0.7)
            }
        }

        // ── The whistle, over the status ─────────────────────────────
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: status.top
            anchors.bottomMargin: 18 * duel.sc
            spacing: 12 * duel.sc
            visible: Services.Media.activePlayer !== null
            opacity: duel.uiIn * (1 - duel.grantIn)

            Repeater {
                // Static model: only the icon follows play/pause.
                model: ["previous", "playPause", "next"]

                Glyph {
                    id: mediaKey
                    required property string modelData
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData === "playPause" ? (Services.Media.isPlaying ? "pause" : "play_arrow") : modelData === "previous" ? "skip_previous" : "skip_next"
                    filled: true
                    font.pixelSize: 20 * duel.sc
                    color: mediaArea.containsMouse ? Shinobi.postureGold : Shinobi.alpha(Shinobi.ivory, 0.75)

                    MouseArea {
                        id: mediaArea
                        anchors.fill: parent
                        anchors.margins: -6 * duel.sc
                        enabled: !duel.still
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.Media[mediaKey.modelData]()
                    }
                }
            }

            Book {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 520 * duel.sc)
                elide: Text.ElideRight
                text: "笛  " + Services.Media.title + (Services.Media.artist ? ", " + Services.Media.artist : "")
                font.pixelSize: 17 * duel.sc
                color: Shinobi.alpha(Shinobi.ivory, 0.8)
            }
        }

        // ── Rest, rise again, sever: item slots to hold ──────────────
        Row {
            anchors.right: parent.right
            anchors.rightMargin: duel.margin
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 44 * duel.sc
            spacing: 16 * duel.sc
            opacity: duel.uiIn * (1 - duel.grantIn)

            Repeater {
                model: [
                    { label: "rest", icon: "bedtime", act: "suspend" },
                    { label: "resurrect", icon: "restart_alt", act: "reboot" },
                    { label: "sever", icon: "power_settings_new", act: "poweroff" }
                ]

                Column {
                    id: slot
                    required property var modelData
                    spacing: 6 * duel.sc

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 62 * duel.sc
                        height: width

                        Rectangle {
                            anchors.fill: parent
                            color: slotHold.containsMouse ? Shinobi.alpha("#2a1c1e", 0.9) : Shinobi.alpha("#0d0a0b", 0.78)
                            border.width: Math.max(1, duel.sc)
                            border.color: Shinobi.alpha(Shinobi.gold, slotHold.containsMouse ? 0.8 : 0.45)

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 4 * duel.sc
                                color: "transparent"
                                border.width: Math.max(1, duel.sc)
                                border.color: Shinobi.alpha(Shinobi.gold, 0.18)
                            }
                        }

                        // Held: the frame fills round in crimson.
                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            visible: slotHold.progress > 0

                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: Shinobi.kanji
                                strokeWidth: 3 * duel.sc
                                capStyle: ShapePath.FlatCap
                                PathAngleArc {
                                    centerX: 31 * duel.sc
                                    centerY: 31 * duel.sc
                                    radiusX: 24 * duel.sc
                                    radiusY: 24 * duel.sc
                                    startAngle: -90
                                    sweepAngle: 360 * slotHold.progress
                                }
                            }
                        }

                        Glyph {
                            anchors.centerIn: parent
                            text: slot.modelData.icon
                            font.pixelSize: 26 * duel.sc
                            color: Shinobi.ivory
                        }

                        HoldArea {
                            id: slotHold
                            anchors.fill: parent
                            enabled: !duel.still
                            onConfirmed: duel.ctx[slot.modelData.act]()
                        }
                    }

                    Book {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: slot.modelData.label
                        font.pixelSize: 15 * duel.sc
                        color: Shinobi.alpha(Shinobi.ivory, 0.72)
                        style: Text.Raised
                        styleColor: Shinobi.alpha("black", 0.7)
                    }
                }
            }
        }
    }

    // ── Choreography ─────────────────────────────────────────────────
    ParallelAnimation {
        id: intro
        NumberAnimation { target: duel; property: "night"; from: 0; to: 1; duration: 950; easing.type: Easing.InOutSine }
        SequentialAnimation {
            PauseAnimation { duration: 280 }
            NumberAnimation { target: duel; property: "grass"; from: 0; to: 1; duration: 800; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 500 }
            NumberAnimation { target: duel; property: "gust"; from: 0; to: 0.6; duration: 300; easing.type: Easing.OutQuad }
            NumberAnimation { target: duel; property: "gust"; to: 0; duration: 900; easing.type: Easing.InOutSine }
        }
        SequentialAnimation {
            PauseAnimation { duration: 950 }
            NumberAnimation { target: duel; property: "uiIn"; from: 0; to: 1; duration: 520; easing.type: Easing.OutCubic }
        }
    }

    // The duel ends and the night lifts: the last frame is the desktop
    // exactly.
    ParallelAnimation {
        id: outro
        NumberAnimation { target: duel; property: "uiIn"; to: 0; duration: 300 }
        NumberAnimation { target: duel; property: "execOut"; to: 0; duration: 380 }
        NumberAnimation { target: duel; property: "markIn"; to: 0; duration: 200 }
        NumberAnimation { target: duel; property: "flash"; to: 0; duration: 200 }
        NumberAnimation { target: duel; property: "hurt"; to: 0; duration: 200 }
        NumberAnimation { target: duel; property: "death"; to: 0; duration: 500 }
        SequentialAnimation {
            PauseAnimation { duration: 120 }
            NumberAnimation { target: duel; property: "grass"; to: 0; duration: 700; easing.type: Easing.InCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 220 }
            NumberAnimation { target: duel; property: "night"; to: 0; duration: 950; easing.type: Easing.InOutSine }
        }
    }

    // A blow deflected: a ring of white where the blades meet.
    NumberAnimation {
        id: clashFx
        target: duel
        property: "clash"
        from: 0
        to: 1
        duration: 260
        easing.type: Easing.OutQuad
    }

    // The deathblow mark, as the blade falls.
    NumberAnimation {
        id: markFx
        target: duel
        property: "markIn"
        from: 0
        to: 1
        duration: 260
        easing.type: Easing.OutBack
    }

    // A perilous attack: 危 flashes up, the blow lands (the screen jolts,
    // red at its edges), and a node is struck out.
    ParallelAnimation {
        id: deniedFx
        SequentialAnimation {
            PropertyAction { target: duel; property: "perilOut"; value: 0 }
            NumberAnimation { target: duel; property: "perilIn"; from: 0; to: 1; duration: 240; easing.type: Easing.OutCubic }
            PauseAnimation { duration: 520 }
            NumberAnimation { target: duel; property: "perilOut"; from: 0; to: 1; duration: 320 }
            PropertyAction { target: duel; property: "perilIn"; value: 0 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 260 }
            NumberAnimation { target: duel; property: "hurt"; from: 0; to: 1; duration: 70 }
            NumberAnimation { target: duel; property: "hurt"; to: 0; duration: 600; easing.type: Easing.OutQuad }
        }
        SequentialAnimation {
            PauseAnimation { duration: 260 }
            NumberAnimation { target: duel; property: "shakeX"; to: -14 * duel.sc; duration: 40 }
            NumberAnimation { target: duel; property: "shakeX"; to: 10 * duel.sc; duration: 60 }
            NumberAnimation { target: duel; property: "shakeX"; to: -5 * duel.sc; duration: 60 }
            NumberAnimation { target: duel; property: "shakeX"; to: 0; duration: 70 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 260 }
            NumberAnimation { target: duel; property: "shakeY"; to: 8 * duel.sc; duration: 40 }
            NumberAnimation { target: duel; property: "shakeY"; to: -4 * duel.sc; duration: 60 }
            NumberAnimation { target: duel; property: "shakeY"; to: 0; duration: 80 }
        }
    }

    // Dead: the colour goes out of the world and 死 is written.
    ParallelAnimation {
        id: deathFx
        NumberAnimation { target: duel; property: "death"; to: 1; duration: 900; easing.type: Easing.InOutSine }
        SequentialAnimation {
            PauseAnimation { duration: 350 }
            NumberAnimation { target: duel; property: "deathIn"; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }
        }
    }

    // Risen: 回生 is written over 死, the colour comes back.
    SequentialAnimation {
        id: riseFx
        PropertyAction { target: duel; property: "riseOut"; value: 0 }
        NumberAnimation { target: duel; property: "riseIn"; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }
        ParallelAnimation {
            NumberAnimation { target: duel; property: "death"; to: 0; duration: 800; easing.type: Easing.InOutSine }
            NumberAnimation { target: duel; property: "deathIn"; to: 0; duration: 500 }
        }
        PauseAnimation { duration: 500 }
        NumberAnimation { target: duel; property: "riseOut"; from: 0; to: 1; duration: 400 }
        PropertyAction { target: duel; property: "riseIn"; value: 0 }
    }

    // The deathblow: a white flash, a cut of blood across the screen, the
    // grass bows, and 忍殺 is written.
    ParallelAnimation {
        id: grantFx
        PropertyAction { target: duel; property: "execOut"; value: 1 }
        NumberAnimation { target: duel; property: "grantIn"; from: 0; to: 1; duration: 300 }
        SequentialAnimation {
            NumberAnimation { target: duel; property: "flash"; from: 0; to: 0.8; duration: 70 }
            NumberAnimation { target: duel; property: "flash"; to: 0; duration: 420; easing.type: Easing.OutQuad }
        }
        NumberAnimation { target: duel; property: "cut"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation { target: duel; property: "gust"; from: 0; to: -1; duration: 160; easing.type: Easing.OutQuad }
            NumberAnimation { target: duel; property: "gust"; to: 0; duration: 1200; easing.type: Easing.OutElastic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 160 }
            NumberAnimation { target: duel; property: "execIn"; from: 0; to: 1; duration: 650; easing.type: Easing.OutCubic }
        }
        NumberAnimation { target: duel; property: "night"; to: 0.8; duration: 1200; easing.type: Easing.InOutSine }
        SequentialAnimation {
            PauseAnimation { duration: 380 }
            NumberAnimation { target: duel; property: "rewardIn"; from: 0; to: 1; duration: 750 }
        }
    }

    SequentialAnimation {
        id: expFill
        PauseAnimation { duration: 450 }
        NumberAnimation {
            target: duel
            property: "shownXp"
            to: duel.reward ? duel.reward.xpAfter : 0
            duration: 800
            easing.type: Easing.InOutCubic
        }
        PropertyAction { target: duel; property: "rewarding"; value: false }
    }

    NumberAnimation {
        id: promoteFx
        target: duel
        property: "promote"
        from: 0
        to: 1
        duration: 300
    }
}
