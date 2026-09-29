pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs.components
import qs.modules.lock
import qs.services as Services

// "Portcullis" theme: holding the gate of a castle under siege.
//
// Lock-in: night falls on the desktop (shaders/lock_nightfall), the stone
// of a gatehouse closes in from the edges, torches catch in their sconces,
// and the portcullis crashes down in front of it all in a burst of dust
// (shaders/lock_gatehouse): the desktop is out there beyond the bars. Your
// banner hangs from the lintel with your arms (Arms), the hour and the
// watch; the ward's board hangs beside it. The passcode is the watchword:
// each letter winches the gate up a notch and calls a knight of the Round
// Table to the muster, his shield hung on the board (War.knights). A false
// watchword drops the gate back with a crash, the shields fall and one of
// your banners is struck (the faillock lives are pennons); too many and the
// gate is chained shut until the lockout ends. The true one winches the
// portcullis all the way up, the torches flare, renown (XP) is counted and
// you may rise in the host; then the gatehouse falls away and night lifts
// off the desktop.
//
// Theme contract (see ThemeHost): ctx, shot, shown, still, minScale.
Item {
    id: gate

    required property LockContext ctx
    property url shot
    property bool shown: true
    property bool still: false
    property real minScale: 0.7

    readonly property real sc: Math.max(minScale, Math.min(2, Math.min(width / 1920, height / 1080)))
    readonly property real edge: 64 * sc
    // The stonework, as in the shader: jambs and lintel.
    readonly property real jamb: 112 * sc
    readonly property real lintel: 104 * sc
    readonly property point torchA: Qt.point(jamb / 2, height * 0.4)
    readonly property point torchB: Qt.point(width - jamb / 2, height * 0.4)

    // Choreography.
    property real night: 0
    property real frame: 0
    property real drop: 0
    property real dust: 0
    property real uiIn: 0
    property real shakeX: 0
    property real shakeY: 0
    property real flare: 0
    property real glow: 1
    property real grantIn: 0
    property real rewardIn: 0
    property real promote: 0

    // The winch: a notch a keystroke, twelve at most; the gate drops back
    // when the watchword is false.
    readonly property int notches: Math.min(ctx.cells, 12)
    readonly property real liftTarget: still ? 3 * 9 * sc : ctx.denying || granted ? 0 : notches * 9 * sc
    property real lift: liftTarget
    Behavior on lift {
        NumberAnimation {
            duration: gate.ctx.denying ? 230 : 380
            easing.type: gate.ctx.denying ? Easing.InQuad : Easing.OutBack
        }
    }

    // Knights at the muster.
    readonly property int mustered: granted ? 12 : still ? 5 : Math.min(ctx.cells, 12)

    // Renown (XP) on the card: follow the stored XP, but run up from the
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

    // The watch moves on once a minute.
    property date minute: new Date()
    readonly property var watch: War.watch(minute)

    Connections {
        target: gate.ctx

        function onNowChanged() {
            const n = gate.ctx.now;
            if (n.getMinutes() !== gate.minute.getMinutes() || n.getHours() !== gate.minute.getHours())
                gate.minute = n;
        }
    }

    Component.onCompleted: {
        _seenLevel = shownLevel;
        if (still) {
            night = 1;
            frame = 1;
            drop = 1;
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
        onTriggered: gate.startIntro()
    }

    Connections {
        target: gate.ctx

        function onPhaseChanged() {
            if (gate.ctx.phase === "exiting") {
                intro.stop();
                outro.start();
            }
        }

        function onDenied(costLife) {
            deniedFx.restart();
        }

        function onGranted() {
            if (gate.reward) {
                gate.rewarding = true;
                gate.shownXp = gate.reward.xpBefore;
                renownFill.restart();
            }
            grantFx.restart();
        }
    }

    // The shields shine while the watch confers (verifying).
    SequentialAnimation on glow {
        running: gate.ctx.phase === "verifying"
        loops: Animation.Infinite
        onRunningChanged: if (!running) gate.glow = 1
        NumberAnimation { to: 1.6; duration: 420; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.8; duration: 420; easing.type: Easing.InOutSine }
    }

    // ── The desktop, at nightfall ────────────────────────────────────
    CaptureImage {
        id: capture
        source: gate.shot
        imageWidth: gate.width
        imageHeight: gate.height
    }

    ShaderEffect {
        anchors.fill: parent
        visible: capture.ready

        property variant source: capture.image
        property real itemWidth: width
        property real itemHeight: height
        property real night: gate.night
        property real light: 0.9 + gate.flare * 0.8
        property real reach: 330 * gate.sc
        property point torchA: gate.torchA
        property point torchB: gate.torchB
        property color moonColor: War.moon
        property color fireColor: War.fire

        fragmentShader: Qt.resolvedUrl("../../../../shaders/lock_nightfall.frag.qsb")
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        visible: !capture.ready
        opacity: Math.max(gate.night, gate.frame)
    }

    // Shade under the words along the foot.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * 0.26
        opacity: gate.uiIn
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: War.alpha("#07060a", 0.7) }
        }
    }

    LockInput {
        ctx: gate.ctx
        active: !gate.still
        onEscapePressed: gate.ctx.clearInput()
    }

    // ── The gatehouse ────────────────────────────────────────────────
    component Book: Text {
        font.family: War.book
        font.pixelSize: 21 * gate.sc
        color: War.ivory
    }

    component Display: Text {
        font.family: War.display
        font.pixelSize: 26 * gate.sc
        color: War.ivory
    }

    Item {
        id: scene
        anchors.fill: parent
        transform: Translate {
            x: gate.shakeX
            y: gate.shakeY
        }

        ShaderEffect {
            anchors.fill: parent
            visible: gate.frame > 0 || gate.drop > 0

            property real itemWidth: width
            property real itemHeight: height
            property real uiScale: gate.sc
            property real frame: gate.frame
            property real drop: gate.drop
            property real lift: gate.lift
            property real light: 0.9 + gate.flare * 0.8
            property real reach: 300 * gate.sc
            property point torchA: gate.torchA
            property point torchB: gate.torchB
            property color stoneColor: War.stone
            property color oakColor: War.oak
            property color ironColor: War.iron
            property color fireColor: War.fire
            property color moonColor: War.moon

            fragmentShader: Qt.resolvedUrl("../../../../shaders/lock_gatehouse.frag.qsb")
        }

        // Barred: chains across the gate and a lock on them.
        Item {
            anchors.fill: parent
            opacity: gate.barred ? gate.uiIn : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: 500 }
            }

            // Each chain twice over: its links seen edge-on, heavy and dark,
            // and between them the ones seen face-on, a lighter ring.
            Repeater {
                model: [[gate.jamb, gate.width - gate.jamb], [gate.width - gate.jamb, gate.jamb]]

                Shape {
                    id: chain
                    required property var modelData
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    readonly property real link: 18 * gate.sc

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: "#2e2e32"
                        strokeWidth: 12 * gate.sc
                        strokeStyle: ShapePath.DashLine
                        dashPattern: [chain.link / (12 * gate.sc), chain.link / (12 * gate.sc)]
                        capStyle: ShapePath.RoundCap
                        startX: chain.modelData[0]
                        startY: gate.lintel + 40 * gate.sc
                        PathLine { x: chain.modelData[1]; y: gate.height - 90 * gate.sc }
                    }

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: "#77777d"
                        strokeWidth: 4 * gate.sc
                        strokeStyle: ShapePath.DashLine
                        dashPattern: [chain.link / (4 * gate.sc), chain.link / (4 * gate.sc)]
                        dashOffset: chain.link / (4 * gate.sc)
                        capStyle: ShapePath.RoundCap
                        startX: chain.modelData[0]
                        startY: gate.lintel + 40 * gate.sc
                        PathLine { x: chain.modelData[1]; y: gate.height - 90 * gate.sc }
                    }
                }
            }

            Glyph {
                x: (gate.width - width) / 2
                y: (gate.lintel + 40 * gate.sc + gate.height - 90 * gate.sc) / 2 - height / 2
                text: "lock"
                filled: true
                font.pixelSize: 84 * gate.sc
                color: "#8d8f93"
                style: Text.Outline
                styleColor: "#141315"
            }
        }

        // The torches.
        Repeater {
            model: [gate.torchA, gate.torchB]

            ShaderEffect {
                required property point modelData
                required property int index
                x: modelData.x - width / 2
                y: modelData.y - height * 0.94
                width: 84 * gate.sc
                height: 140 * gate.sc
                opacity: gate.frame
                visible: opacity > 0

                property real itemWidth: width
                property real itemHeight: height
                property real time: gate.ctx.ambientTime
                property real flare: gate.flare
                property real seed: index * 1.7

                fragmentShader: Qt.resolvedUrl("../../../../shaders/torch.frag.qsb")
            }
        }

        // Carved in the lintel.
        Item {
            x: 0
            y: -(1 - gate.frame) * (gate.lintel + 30 * gate.sc)
            width: gate.width
            height: gate.lintel

            Display {
                anchors.centerIn: parent
                text: ("Castle " + War.hold).toUpperCase()
                font.pixelSize: 40 * gate.sc
                font.letterSpacing: 8 * gate.sc
                color: "#c9c0ae"
                style: Text.Sunken
                styleColor: "#1a1714"
                opacity: 0.9
            }

            Column {
                anchors.right: parent.right
                anchors.rightMargin: gate.jamb + 26 * gate.sc
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2 * gate.sc
                opacity: gate.uiIn

                Book {
                    anchors.right: parent.right
                    readonly property real pct: Services.Battery.percentage
                    text: "provisions " + Math.round(pct) + "%" + (Services.Battery.charging ? ", a supply train coming" : "")
                    font.pixelSize: 17 * gate.sc
                    font.italic: true
                    color: pct <= 20 && !Services.Battery.charging ? War.danger : War.alpha(War.ivory, 0.8)
                    style: Text.Raised
                    styleColor: "#14110e"
                }

                Book {
                    anchors.right: parent.right
                    readonly property int s: Math.max(0, Math.floor((gate.ctx.now.getTime() - gate.ctx.lockedAt) / 1000))
                    text: (gate.ctx.capsLock ? "caps lock  ·  " : "") + "the gate held " + Math.floor(s / 3600) + ":" + String(Math.floor(s / 60) % 60).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0")
                    font.pixelSize: 16 * gate.sc
                    font.italic: true
                    color: gate.ctx.capsLock ? War.danger : War.alpha(War.ivory, 0.62)
                    style: Text.Raised
                    styleColor: "#14110e"
                }
            }

            Book {
                anchors.left: parent.left
                anchors.leftMargin: gate.jamb + 26 * gate.sc
                anchors.verticalCenter: parent.verticalCenter
                opacity: gate.uiIn
                text: War.season(gate.minute).name + "  ·  " + War.truceLine(gate.minute).toLowerCase()
                font.pixelSize: 17 * gate.sc
                font.italic: true
                color: War.alpha(War.ivory, 0.72)
                style: Text.Raised
                styleColor: "#14110e"
            }
        }

        // ── Your banner, hung from the lintel ────────────────────────
        Item {
            id: banner
            x: 170 * gate.sc
            y: gate.lintel - 22 * gate.sc
            width: 440 * gate.sc
            height: 740 * gate.sc
            opacity: gate.uiIn
            transform: Translate { y: -(1 - gate.uiIn) * 40 * gate.sc }

            readonly property real tail: 74 * gate.sc

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.7
                shadowBlur: 0.8
                blurMax: 32
                shadowHorizontalOffset: 6 * gate.sc
                shadowVerticalOffset: 10 * gate.sc
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: "#07060a"
                    strokeWidth: Math.max(1, 1.5 * gate.sc)
                    joinStyle: ShapePath.MiterJoin
                    fillGradient: LinearGradient {
                        x1: 0
                        y1: 0
                        x2: banner.width
                        y2: 0
                        GradientStop { position: 0; color: Qt.lighter(War.fieldDeep, 1.5) }
                        GradientStop { position: 0.4; color: War.fieldDeep }
                        GradientStop { position: 1; color: Qt.darker(War.fieldDeep, 1.4) }
                    }

                    PathPolyline {
                        path: ThemeShapes.banner(0, 10 * gate.sc, banner.width, banner.height - 10 * gate.sc, banner.tail, 1)
                    }
                }

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: War.alpha(War.or, 0.75)
                    strokeWidth: Math.max(1, 2 * gate.sc)
                    joinStyle: ShapePath.MiterJoin

                    PathPolyline {
                        path: ThemeShapes.banner(14 * gate.sc, 26 * gate.sc, banner.width - 28 * gate.sc, banner.height - 40 * gate.sc, banner.tail - 8 * gate.sc, 1)
                    }
                }
            }

            // The rod it hangs from, and the rings.
            Rectangle {
                x: -16 * gate.sc
                y: 2 * gate.sc
                width: banner.width + 32 * gate.sc
                height: 11 * gate.sc
                radius: height / 2
                border.width: Math.max(1, gate.sc)
                border.color: "#07060a"
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.lighter(War.iron, 2.2) }
                    GradientStop { position: 1; color: War.iron }
                }
            }

            Column {
                id: bannerWords
                anchors.horizontalCenter: parent.horizontalCenter
                y: 50 * gate.sc
                spacing: 4 * gate.sc

                Arms {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 142 * gate.sc
                    height: 170 * gate.sc
                    seed: 3
                    glow: gate.grantIn * 0.35
                }

                Item {
                    width: 1
                    height: 6 * gate.sc
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10 * gate.sc

                    Display {
                        id: time
                        text: Qt.formatTime(gate.ctx.now, "h:mm AP").split(" ")[0]
                        font.pixelSize: 112 * gate.sc
                    }

                    Display {
                        anchors.baseline: time.baseline
                        text: gate.ctx.now.getHours() < 12 ? "a.m." : "p.m."
                        font.pixelSize: 32 * gate.sc
                        color: War.tinctureLight
                    }
                }

                Display {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: gate.watch.name
                    font.pixelSize: 30 * gate.sc
                    color: War.or
                }

                Book {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: gate.watch.deed
                    font.italic: true
                    color: War.alpha(War.ivory, 0.85)
                }

                Item {
                    width: 1
                    height: 10 * gate.sc
                }

                Book {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: War.date(gate.ctx.now)
                    font.pixelSize: 20 * gate.sc
                }

                Display {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ("Day " + War.siegeDay(gate.ctx.now) + " of the siege  ·  " + War.year(gate.ctx.now)).toUpperCase()
                    font.pixelSize: 14 * gate.sc
                    font.letterSpacing: 2 * gate.sc
                    color: War.alpha(War.ivory, 0.7)
                }

                Book {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 8 * gate.sc
                    text: "“" + War.arms.motto + "”"
                    font.pixelSize: 18 * gate.sc
                    font.italic: true
                    color: War.alpha(War.or, 0.85)
                }
            }
        }

        // ── The ward's board: the muster, and your banners ───────────
        Item {
            id: board
            x: gate.width - gate.jamb - 64 * gate.sc - width
            y: gate.lintel + 70 * gate.sc
            width: 500 * gate.sc
            height: boardWords.implicitHeight + 64 * gate.sc
            opacity: gate.uiIn
            transform: Translate { y: -(1 - gate.uiIn) * 40 * gate.sc }

            // Hung by two chains from the lintel.
            Repeater {
                model: 2

                Column {
                    required property int index
                    x: (index === 0 ? 0.18 : 0.82) * board.width - width / 2
                    y: -76 * gate.sc
                    spacing: -3 * gate.sc

                    Repeater {
                        model: 7

                        Rectangle {
                            required property int index
                            width: (index % 2 === 0 ? 9 : 4) * gate.sc
                            height: 14 * gate.sc
                            radius: width / 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: index % 2 === 0 ? "transparent" : "#4a4a4e"
                            border.width: Math.max(1, 2 * gate.sc)
                            border.color: index % 2 === 0 ? "#55555a" : "#101012"
                        }
                    }
                }
            }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.7
                shadowBlur: 0.8
                blurMax: 32
                shadowHorizontalOffset: 6 * gate.sc
                shadowVerticalOffset: 10 * gate.sc
            }

            Board {
                anchors.fill: parent
                fill: War.alpha(War.ground, 0.94)
                line: Math.max(1, gate.sc)
                strap: 34 * gate.sc
                planks: 4
            }

            Column {
                id: boardWords
                x: 34 * gate.sc
                y: 32 * gate.sc
                width: board.width - 68 * gate.sc
                spacing: 6 * gate.sc

                Display {
                    readonly property var c: gate.ctx
                    text: gate.granted ? "Enter, " + c.userName
                        : c.phase === "verifying" ? "The watch confers…"
                        : c.denying ? "False watchword!"
                        : gate.barred ? "The gate is barred"
                        : c.cells > 0 ? "Friend or foe?"
                        : "Who goes there?"
                    font.pixelSize: 44 * gate.sc
                    color: c.denying || gate.barred ? War.danger : gate.granted ? War.fire : War.ivory
                }

                Book {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    readonly property var c: gate.ctx
                    text: gate.granted
                        ? (gate.reward ? "+" + Math.round(gate.reward.total * Math.min(1, gate.rewardIn * 1.3)) + " renown" + (gate.promote > 0 ? "  ·  now " + War.rank(gate.shownLevel).toLowerCase() : "") : "the portcullis is winched up")
                        : c.message.length > 0 ? c.message
                        : gate.barred ? "chained shut for " + (c.lockoutClock || "a while") + ": no one comes in while the siege presses"
                        : c.capsLock ? "caps lock is on"
                        : c.lastLife ? "one more false word and the gate is barred for " + Math.round(c.unlockTime / 60) + " minutes"
                        : c.denying ? "the gate crashes down and a banner is struck"
                        : c.cells > 12 ? (c.combo >= 6 ? "the whole host is at the gate" : "the host gathers; press Enter")
                        : c.cells > 0 ? War.knights[(c.cells - 1) % 12][0] + " answers the muster" + (c.combo >= 6 ? ", the host is gathering" : "")
                        : "speak the watchword: every letter winches the gate up a notch"
                    font.italic: true
                    font.pixelSize: 20 * gate.sc
                    color: !gate.granted && (c.message.length > 0 || gate.barred || c.capsLock || c.lastLife) ? War.danger : War.alpha(War.ivory, 0.82)
                }

                Item {
                    width: 1
                    height: 6 * gate.sc
                }

                // The muster: a hook for each shield, the knights' shields
                // hung on them as they come.
                Grid {
                    id: muster
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: 6
                    columnSpacing: 16 * gate.sc
                    rowSpacing: 14 * gate.sc

                    Repeater {
                        model: 12

                        Item {
                            id: slot
                            required property int index
                            readonly property var knight: War.knights[index]
                            readonly property bool hung: index < gate.mustered
                            width: 54 * gate.sc
                            height: 65 * gate.sc

                            // The hook.
                            Rectangle {
                                x: (slot.width - width) / 2
                                y: -3 * gate.sc
                                width: 7 * gate.sc
                                height: width
                                radius: width / 2
                                color: "#4a4a4e"
                                border.width: Math.max(1, gate.sc)
                                border.color: "#101012"
                            }

                            Shape {
                                anchors.fill: parent
                                visible: !slot.hung
                                preferredRendererType: Shape.CurveRenderer

                                ShapePath {
                                    fillColor: War.alpha("black", 0.25)
                                    strokeColor: War.alpha(War.steel, 0.22)
                                    strokeWidth: Math.max(1, gate.sc)
                                    strokeStyle: ShapePath.DashLine
                                    dashPattern: [3, 3]

                                    PathPolyline {
                                        path: ThemeShapes.heater(1, 1, slot.width - 2, slot.height - 2)
                                    }
                                }
                            }

                            Arms {
                                id: shield
                                anchors.fill: parent
                                visible: slot.hung || fall.running
                                field: War.paints[slot.knight[1]]
                                ordinary: slot.knight[2]
                                metal: War.paints[slot.knight[3]]
                                charge: slot.knight[2] === 0 ? 1 : 0
                                lone: slot.knight[2] === 0
                                chargeColor: War.paints[slot.knight[3]]
                                worn: 0.3
                                seed: slot.index * 2.3 + 1
                                glow: gate.granted ? 0.35 + 0.25 * gate.glow : gate.ctx.phase === "verifying" ? 0.22 * gate.glow : 0
                                transform: [
                                    Rotation {
                                        origin.x: shield.width / 2
                                        origin.y: 0
                                        angle: slot.tumble * (slot.index % 2 === 0 ? 24 : -30)
                                    },
                                    Translate { y: slot.tumble * 90 * gate.sc }
                                ]
                                opacity: 1 - slot.tumble
                            }

                            // A false watchword knocks it off its hook.
                            property real tumble: 0
                            NumberAnimation {
                                id: fall
                                target: slot
                                property: "tumble"
                                from: 0
                                to: 1
                                duration: 520
                                easing.type: Easing.InQuad
                            }

                            Connections {
                                target: gate.ctx

                                function onDenied(costLife) {
                                    if (slot.hung)
                                        fall.restart();
                                }
                            }

                            onHungChanged: if (hung) tumble = 0
                        }
                    }
                }

                Book {
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property int extra: gate.granted ? 0 : Math.max(0, gate.ctx.cells - 12)
                    visible: extra > 0
                    text: "and " + extra + " more at the gate"
                    font.pixelSize: 17 * gate.sc
                    font.italic: true
                    color: War.alpha(War.or, 0.9)
                }

                Item {
                    width: 1
                    height: 8 * gate.sc
                }

                // Your banners: the faillock lives.
                Row {
                    visible: !gate.granted && gate.ctx.maxLives > 0
                    spacing: 18 * gate.sc

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6 * gate.sc

                        Repeater {
                            model: Math.min(gate.ctx.maxLives, 6)

                            Pennon {
                                required property int index
                                width: 48 * gate.sc
                                height: 78 * gate.sc
                                line: Math.max(1, gate.sc)
                                struck: gate.barred || index >= gate.ctx.lives
                            }
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2 * gate.sc

                        Display {
                            readonly property int lost: gate.ctx.maxLives - gate.ctx.lives
                            text: gate.barred ? "Every banner struck" : lost <= 0 ? "Your banners fly" : lost === 1 ? "A banner is struck" : lost + " banners struck"
                            font.pixelSize: 21 * gate.sc
                            color: gate.barred ? War.danger : War.or
                        }

                        Book {
                            text: gate.barred ? "until " + (gate.ctx.lockoutClock || "the siege lifts")
                                : gate.ctx.lives === 1 ? "one still flies"
                                : gate.ctx.lives + " still fly"
                            font.pixelSize: 17 * gate.sc
                            font.italic: true
                            color: War.alpha(War.ivory, 0.7)
                        }
                    }
                }

                Book {
                    visible: gate.granted && gate.reward !== null
                    width: parent.width
                    elide: Text.ElideRight
                    opacity: gate.rewardIn
                    text: gate.reward
                        ? gate.reward.lines.map(l => l.label.toLowerCase() + " +" + l.xp).join("  ·  ")
                          + (gate.reward.multiplier > 1 ? "  ·  streak ×" + gate.reward.multiplier.toFixed(2) : "")
                        : ""
                    font.pixelSize: 17 * gate.sc
                    color: War.alpha(War.ivory, 0.66)
                }
            }
        }
    }

    // ── Battle honours won (achievements), between banner and board ──
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: -60 * gate.sc
        y: gate.lintel + 60 * gate.sc
        spacing: 14 * gate.sc
        visible: gate.granted

        Repeater {
            model: gate.reward ? gate.reward.achievements.slice(0, 3) : []

            Item {
                id: honour
                required property int index
                required property var modelData
                readonly property real appear: LockTheme.seg(gate.rewardIn, 0.15 + index * 0.18, 0.45 + index * 0.18)
                width: 440 * gate.sc
                height: 70 * gate.sc
                opacity: appear
                transform: Translate { y: (1 - honour.appear) * -16 * gate.sc }

                Scroll {
                    anchors.fill: parent
                    band: parent.height * 0.82
                    text: ""
                }

                Row {
                    x: 78 * gate.sc
                    y: (honour.height * 0.82 - height) / 2
                    spacing: 12 * gate.sc

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        text: honour.modelData.icon
                        filled: true
                        font.pixelSize: 24 * gate.sc
                        color: War.wax
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter

                        Display {
                            text: "A battle honour: " + honour.modelData.name
                            font.pixelSize: 19 * gate.sc
                            color: War.ink
                        }

                        Book {
                            text: honour.modelData.desc
                            font.pixelSize: 14 * gate.sc
                            font.italic: true
                            color: War.alpha(War.ink, 0.75)
                        }
                    }
                }
            }
        }
    }

    // ── Around the foot ──────────────────────────────────────────────
    Item {
        anchors.fill: parent
        opacity: gate.uiIn

        // The knight, bottom left: your portrait on a shield, your name
        // and rank, and renown towards the next.
        Row {
            x: gate.jamb + 58 * gate.sc
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 44 * gate.sc
            spacing: 22 * gate.sc

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 88 * gate.sc
                height: 106 * gate.sc

                Shape {
                    id: portraitMask
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: "white"
                        strokeColor: "transparent"

                        PathPolyline {
                            path: ThemeShapes.heater(0, 0, portraitMask.width, portraitMask.height)
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
                    maskSource: portraitMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                    saturation: -0.15
                    colorization: 0.1
                    colorizationColor: "#a0784a"
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: "#07060a"
                        strokeWidth: 6 * gate.sc
                        joinStyle: ShapePath.MiterJoin

                        PathPolyline {
                            path: ThemeShapes.heater(1.5 * gate.sc, 1.5 * gate.sc, 85 * gate.sc, 103 * gate.sc)
                        }
                    }

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: War.steel
                        strokeWidth: 3.5 * gate.sc
                        joinStyle: ShapePath.MiterJoin

                        PathPolyline {
                            path: ThemeShapes.heater(1.5 * gate.sc, 1.5 * gate.sc, 85 * gate.sc, 103 * gate.sc)
                        }
                    }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4 * gate.sc

                Row {
                    spacing: 12 * gate.sc

                    Display {
                        id: nameText
                        text: gate.ctx.userName
                        font.pixelSize: 36 * gate.sc
                    }

                    Book {
                        anchors.baseline: nameText.baseline
                        text: War.rank(gate.shownLevel)
                        font.pixelSize: 21 * gate.sc
                        font.italic: true
                        color: gate.promote > 0 ? War.fire : War.tinctureLight
                    }
                }

                // Renown towards the next rank: a sword drawn from its
                // scabbard.
                Item {
                    id: renown
                    readonly property real progress: Math.max(0, Math.min(1, (gate.shownXp - gate.levelFloor) / Math.max(1, gate.levelCeil - gate.levelFloor)))
                    readonly property real guard: 30 * gate.sc
                    readonly property real len: width - guard
                    width: 320 * gate.sc
                    height: 16 * gate.sc

                    Rectangle {
                        x: renown.guard
                        y: renown.height / 2 - height / 2
                        width: renown.len - 6 * gate.sc
                        height: 6 * gate.sc
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.lighter(War.steel, 1.2) }
                            GradientStop { position: 1; color: Qt.darker(War.steel, 1.4) }
                        }
                    }

                    Rectangle {
                        x: renown.guard + renown.len * renown.progress
                        y: renown.height / 2 - height / 2
                        width: renown.len * (1 - renown.progress)
                        height: 9 * gate.sc
                        radius: 2 * gate.sc
                        visible: renown.progress < 0.995
                        color: Qt.hsla(War.hueOf(War.tincture), 0.45, 0.2, 1)
                        border.width: Math.max(1, 0.5 * gate.sc)
                        border.color: "#07060a"

                        Rectangle {
                            width: 4 * gate.sc
                            height: parent.height
                            color: War.or
                        }

                        Rectangle {
                            anchors.right: parent.right
                            width: Math.min(8 * gate.sc, parent.width)
                            height: parent.height
                            radius: 2 * gate.sc
                            color: War.or
                        }
                    }

                    Rectangle {
                        x: 7 * gate.sc
                        y: renown.height / 2 - height / 2
                        width: renown.guard - 9 * gate.sc
                        height: 5 * gate.sc
                        color: "#3a2418"
                    }

                    Rectangle {
                        y: renown.height / 2 - height / 2
                        width: 9 * gate.sc
                        height: width
                        radius: width / 2
                        color: War.or
                    }

                    Rectangle {
                        x: renown.guard - 4 * gate.sc
                        y: 0
                        width: 4 * gate.sc
                        height: renown.height
                        radius: gate.sc
                        color: War.or
                    }
                }

                Book {
                    text: War.count(Math.floor(gate.shownXp - gate.levelFloor)) + " / " + War.count(gate.levelCeil - gate.levelFloor) + " renown"
                        + "  ·  " + Services.LockStats.liveStreak + " days in the field"
                        + "  ·  " + Services.LockStats.achievements.length + "/" + Services.LockStats.achievementDefs.length + " honours"
                    font.pixelSize: 16 * gate.sc
                    color: War.alpha(War.ivory, 0.68)
                }
            }
        }

        // The minstrel, bottom centre.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: 40 * gate.sc
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 58 * gate.sc
            spacing: 12 * gate.sc
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
                    font.pixelSize: 20 * gate.sc
                    color: mediaArea.containsMouse ? War.or : War.alpha(War.ivory, 0.75)

                    MouseArea {
                        id: mediaArea
                        anchors.fill: parent
                        anchors.margins: -6 * gate.sc
                        enabled: !gate.still
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.Media[mediaKey.modelData]()
                    }
                }
            }

            Book {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 440 * gate.sc)
                elide: Text.ElideRight
                text: "the minstrel plays " + Services.Media.title + (Services.Media.artist ? ", by " + Services.Media.artist : "")
                font.pixelSize: 17 * gate.sc
                font.italic: true
            }
        }

        // Stand down, regroup, strike camp: bucklers to hold.
        Row {
            anchors.right: parent.right
            anchors.rightMargin: gate.jamb + 40 * gate.sc
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 36 * gate.sc
            spacing: 22 * gate.sc

            Repeater {
                model: [
                    { label: "stand down", icon: "bedtime", act: "suspend" },
                    { label: "regroup", icon: "restart_alt", act: "reboot" },
                    { label: "strike camp", icon: "power_settings_new", act: "poweroff" }
                ]

                Column {
                    id: knob
                    required property var modelData
                    spacing: 6 * gate.sc

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 58 * gate.sc
                        height: width

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: knobHold.containsMouse ? Qt.lighter(War.fieldDeep, 1.6) : War.fieldDeep
                            border.width: Math.max(1, 3 * gate.sc)
                            border.color: War.steel
                        }

                        Repeater {
                            model: 8

                            Rectangle {
                                required property int index
                                readonly property real a: index * Math.PI / 4
                                x: 29 * gate.sc + Math.sin(a) * 24 * gate.sc - width / 2
                                y: 29 * gate.sc - Math.cos(a) * 24 * gate.sc - height / 2
                                width: 3.5 * gate.sc
                                height: width
                                radius: width / 2
                                color: War.ironHi
                            }
                        }

                        // Held: an arc of gold runs round it.
                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            visible: knobHold.progress > 0

                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: War.fire
                                strokeWidth: 3 * gate.sc
                                capStyle: ShapePath.RoundCap

                                PathAngleArc {
                                    centerX: 29 * gate.sc
                                    centerY: 29 * gate.sc
                                    radiusX: 29 * gate.sc
                                    radiusY: 29 * gate.sc
                                    startAngle: -90
                                    sweepAngle: 360 * knobHold.progress
                                }
                            }
                        }

                        Glyph {
                            anchors.centerIn: parent
                            text: knob.modelData.icon
                            font.pixelSize: 22 * gate.sc
                            color: War.ivory
                        }

                        HoldArea {
                            id: knobHold
                            anchors.fill: parent
                            enabled: !gate.still
                            onConfirmed: gate.ctx[knob.modelData.act]()
                        }
                    }

                    Book {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: knob.modelData.label
                        font.pixelSize: 15 * gate.sc
                        font.italic: true
                        color: War.alpha(War.ivory, 0.72)
                    }
                }
            }
        }
    }

    // The dust the gate throws up when it comes down.
    ShaderEffect {
        x: gate.jamb
        width: parent.width - 2 * gate.jamb
        height: 320 * gate.sc
        y: parent.height - height
        visible: gate.dust > 0 && gate.dust < 1

        property real itemWidth: width
        property real itemHeight: height
        property real progress: gate.dust
        property color dustColor: "#8a8074"

        fragmentShader: Qt.resolvedUrl("../../../../shaders/lock_dustburst.frag.qsb")
    }

    // ── Choreography ─────────────────────────────────────────────────
    ParallelAnimation {
        id: intro
        NumberAnimation { target: gate; property: "night"; from: 0; to: 1; duration: 900; easing.type: Easing.InOutSine }
        SequentialAnimation {
            PauseAnimation { duration: 120 }
            NumberAnimation { target: gate; property: "frame"; from: 0; to: 1; duration: 650; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 620 }
            NumberAnimation { target: gate; property: "drop"; from: 0; to: 1; duration: 560; easing.type: Easing.OutBounce }
        }
        SequentialAnimation {
            PauseAnimation { duration: 900 }
            NumberAnimation { target: gate; property: "dust"; from: 0; to: 1; duration: 1300; easing.type: Easing.OutQuad }
        }
        SequentialAnimation {
            PauseAnimation { duration: 880 }
            NumberAnimation { target: gate; property: "shakeY"; to: 10 * gate.sc; duration: 40 }
            NumberAnimation { target: gate; property: "shakeY"; to: -5 * gate.sc; duration: 60 }
            NumberAnimation { target: gate; property: "shakeY"; to: 2 * gate.sc; duration: 60 }
            NumberAnimation { target: gate; property: "shakeY"; to: 0; duration: 70 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 1050 }
            NumberAnimation { target: gate; property: "uiIn"; from: 0; to: 1; duration: 520; easing.type: Easing.OutCubic }
        }
    }

    // The gatehouse falls away and night lifts: the last frame is the
    // desktop exactly.
    ParallelAnimation {
        id: outro
        NumberAnimation { target: gate; property: "uiIn"; to: 0; duration: 300 }
        NumberAnimation { target: gate; property: "drop"; to: 0; duration: 500; easing.type: Easing.InCubic }
        SequentialAnimation {
            PauseAnimation { duration: 180 }
            NumberAnimation { target: gate; property: "frame"; to: 0; duration: 850; easing.type: Easing.InOutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 200 }
            NumberAnimation { target: gate; property: "night"; to: 0; duration: 950; easing.type: Easing.InOutSine }
        }
        NumberAnimation { target: gate; property: "flare"; to: 0; duration: 600 }
    }

    ParallelAnimation {
        id: deniedFx
        SequentialAnimation {
            PauseAnimation { duration: 200 }
            ParallelAnimation {
                NumberAnimation { target: gate; property: "dust"; from: 0; to: 1; duration: 1100; easing.type: Easing.OutQuad }
                SequentialAnimation {
                    NumberAnimation { target: gate; property: "shakeY"; to: 9 * gate.sc; duration: 40 }
                    NumberAnimation { target: gate; property: "shakeY"; to: -4 * gate.sc; duration: 60 }
                    NumberAnimation { target: gate; property: "shakeY"; to: 0; duration: 80 }
                }
                SequentialAnimation {
                    NumberAnimation { target: gate; property: "shakeX"; to: -8 * gate.sc; duration: 40 }
                    NumberAnimation { target: gate; property: "shakeX"; to: 6 * gate.sc; duration: 60 }
                    NumberAnimation { target: gate; property: "shakeX"; to: -3 * gate.sc; duration: 60 }
                    NumberAnimation { target: gate; property: "shakeX"; to: 0; duration: 70 }
                }
            }
        }
    }

    ParallelAnimation {
        id: grantFx
        NumberAnimation { target: gate; property: "grantIn"; from: 0; to: 1; duration: 400 }
        SequentialAnimation {
            PauseAnimation { duration: 150 }
            NumberAnimation { target: gate; property: "drop"; to: 0; duration: 1150; easing.type: Easing.InOutCubic }
        }
        SequentialAnimation {
            NumberAnimation { target: gate; property: "flare"; from: 0; to: 1; duration: 350; easing.type: Easing.OutCubic }
            NumberAnimation { target: gate; property: "flare"; to: 0.45; duration: 900; easing.type: Easing.InOutSine }
        }
        NumberAnimation { target: gate; property: "night"; to: 0.6; duration: 1200; easing.type: Easing.InOutSine }
        SequentialAnimation {
            PauseAnimation { duration: 350 }
            NumberAnimation { target: gate; property: "rewardIn"; from: 0; to: 1; duration: 750 }
        }
    }

    SequentialAnimation {
        id: renownFill
        PauseAnimation { duration: 450 }
        NumberAnimation {
            target: gate
            property: "shownXp"
            to: gate.reward ? gate.reward.xpAfter : 0
            duration: 800
            easing.type: Easing.InOutCubic
        }
        PropertyAction { target: gate; property: "rewarding"; value: false }
    }

    NumberAnimation {
        id: promoteFx
        target: gate
        property: "promote"
        from: 0
        to: 1
        duration: 300
    }
}
