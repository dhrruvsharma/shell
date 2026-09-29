pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs.components
import qs.modules.lock
import qs.services as Services

// "Samudra Manthan" theme: the churning of the ocean of milk.
//
// Lock-in: the desktop is churned: it turns round the foot of the mountain,
// whitens to milk and thins away on the scene behind (shaders/lock_churn):
// the ocean of milk under a dusk sky, Mount Mandara standing in it as the
// churning rod, and the serpent Vasuki wound round it as the rope, his
// hooded head rising on the side of the asuras, his tail running off to the
// devas (shaders/manthan). The passcode is the churning: each keystroke
// pulls the rope one way or the other, turns the mountain, throws up a ring
// of foam, and brings a treasure up out of the sea to hang in a garland
// over the mountain: the Moon, the wish-granting cow, the seven-headed
// horse, the white elephant, the jewel Kaustubha and the rest (Deva.ratnas).
// A wrong passcode brings up the Halahala: the poison spreads across the
// sea, the treasures sink, and a kalash of amrita is spoiled (the faillock
// lives are kalashas); a lockout leaves the whole sea poisoned while
// Shiva holds it in his throat. The right one brings up the amrita: a
// pillar of light, the sea turned to gold, every treasure alight; merit
// (XP) is counted as punya and you may rise among the sages; then the sea
// is churned back into the desktop.
//
// Theme contract (see ThemeHost): ctx, shot, shown, still, minScale.
Item {
    id: sea

    required property LockContext ctx
    property url shot
    property bool shown: true
    property bool still: false
    property real minScale: 0.7

    readonly property real sc: Math.max(minScale, Math.min(2, Math.min(width / 1920, height / 1080)))
    readonly property real edge: 64 * sc
    // Where the mountain stands, across the screen, and the churn at its
    // foot (the shader's FOOT).
    readonly property real mountainX: 0.33
    readonly property point churnPoint: Qt.point(width * mountainX, height * 0.655)

    // Choreography.
    property real stir: 0
    property real uiIn: 0
    property real glow: 1
    property real poison: 0
    property real amrita: 0
    property real splash: 0
    property real shakeX: 0
    property real grantIn: 0
    property real rewardIn: 0
    property real promote: 0

    // The rod turns one way, then the other, as the two sides pull by
    // turns; the rope slides with it.
    readonly property int pulls: ctx.cells
    readonly property real churnTarget: granted ? 0 : still ? 0.4 : pulls === 0 ? 0 : (pulls % 2 === 1 ? 0.75 : -0.75)
    property real churn: churnTarget
    Behavior on churn {
        NumberAnimation {
            duration: 460
            easing.type: Easing.OutBack
        }
    }
    readonly property real pull: pulls === 0 ? 0 : (pulls % 2 === 1 ? 1 : -1)
    property real shownPull: pull
    Behavior on shownPull {
        NumberAnimation {
            duration: 420
            easing.type: Easing.OutCubic
        }
    }
    // While the reckoning's made the churning runs on by itself: the sea
    // wheels faster round the mountain.
    property real spinning: 0
    NumberAnimation on spinning {
        running: sea.ctx.phase === "verifying"
        from: 0
        to: 6.2832
        duration: 1600
        loops: Animation.Infinite
    }

    // Treasures up, in the garland.
    readonly property int risen: granted ? 12 : still ? 5 : Math.min(ctx.cells, 12)

    // Merit (XP) on the card: follow the stored XP, but run up from the old
    // value during the reward.
    property real shownXp: Services.LockStats.xp
    readonly property int shownLevel: Services.LockStats.levelFor(shownXp)
    readonly property int levelFloor: Services.LockStats.xpForLevel(shownLevel)
    readonly property int levelCeil: Services.LockStats.xpForLevel(shownLevel + 1)
    property bool rewarding: false
    property int _seenLevel: 0

    readonly property bool granted: ctx.phase === "granted" || ctx.phase === "exiting"
    readonly property var reward: ctx.reward
    readonly property bool poisoned: ctx.lockedOut && ctx.cells === 0
    readonly property string latest: ctx.cells > 0 ? Deva.ratnas[(ctx.cells - 1) % 12][0] : ""

    // The almanac moves on once a minute (the context's clock ticks every
    // second; the panchang needn't).
    property date minute: new Date()
    readonly property var pan: Deva.panchang(minute)
    readonly property var mu: Deva.muhurta(minute)
    readonly property var pr: Deva.prahar(minute)

    Connections {
        target: sea.ctx

        function onNowChanged() {
            const n = sea.ctx.now;
            if (n.getMinutes() !== sea.minute.getMinutes() || n.getHours() !== sea.minute.getHours())
                sea.minute = n;
        }

        function onTyped(index) {
            splashFx.restart();
        }
    }

    Component.onCompleted: {
        _seenLevel = shownLevel;
        if (still) {
            stir = 1;
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
        onTriggered: sea.startIntro()
    }

    Connections {
        target: sea.ctx

        function onPhaseChanged() {
            if (sea.ctx.phase === "exiting") {
                intro.stop();
                outro.start();
            }
        }

        function onDenied(costLife) {
            deniedFx.restart();
        }

        function onGranted() {
            if (sea.reward) {
                sea.rewarding = true;
                sea.shownXp = sea.reward.xpBefore;
                meritFill.restart();
            }
            grantFx.restart();
        }
    }

    // The gems breathe while the reckoning's made (verifying).
    SequentialAnimation on glow {
        running: sea.ctx.phase === "verifying"
        loops: Animation.Infinite
        onRunningChanged: if (!running) sea.glow = 1
        NumberAnimation { to: 1.35; duration: 420; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.7; duration: 420; easing.type: Easing.InOutSine }
    }

    // A lockout leaves the sea poisoned until it ends.
    onPoisonedChanged: {
        poisonBase.to = poisoned ? 0.62 : 0;
        poisonBase.restart();
    }

    NumberAnimation {
        id: poisonBase
        target: sea
        property: "poison"
        duration: 1400
        easing.type: Easing.InOutSine
    }

    // ── The ocean of milk ────────────────────────────────────────────
    ShaderEffect {
        anchors.fill: parent

        property real itemWidth: width
        property real itemHeight: height
        property real time: sea.ctx.ambientTime + sea.spinning * 0.4
        property real churn: sea.churn
        property real pull: sea.shownPull
        property real splash: sea.splash
        property real poison: sea.poison
        property real amrita: sea.amrita
        property real mx: sea.mountainX
        property color goldColor: Deva.gold
        property color pigmentColor: Deva.pigment
        property color poisonColor: Deva.poison
        property color amritaColor: Deva.amrita

        fragmentShader: Qt.resolvedUrl("../../../../shaders/manthan.frag.qsb")
    }

    // Shade behind the words.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.5; color: "transparent" }
            GradientStop { position: 0.64; color: Deva.alpha("#0c0612", 0.5) }
            GradientStop { position: 1; color: Deva.alpha("#0c0612", 0.72) }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * 0.3
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: Deva.alpha("#0c0612", 0.55) }
        }
    }

    LockInput {
        ctx: sea.ctx
        active: !sea.still
        onEscapePressed: sea.ctx.clearInput()
    }

    // ── The treasures, in a garland over the mountain ────────────────
    Item {
        id: garland
        anchors.fill: parent
        transform: Translate { x: sea.shakeX }

        readonly property real cx: sea.width * sea.mountainX
        readonly property real cy: sea.height * 0.58
        readonly property real rx: 440 * sea.sc
        readonly property real ry: sea.height * 0.46

        Repeater {
            model: 12

            Item {
                id: slot
                required property int index
                readonly property var ratna: Deva.ratnas[index]
                readonly property real ang: (150 - index * (120 / 11)) * Math.PI / 180
                readonly property real sx: garland.cx + Math.cos(ang) * garland.rx
                readonly property real sy: garland.cy - Math.sin(ang) * garland.ry
                // 0 in the sea .. 1 in its place in the garland.
                property real up: index < sea.risen ? 1 : 0
                Behavior on up {
                    NumberAnimation {
                        duration: sea.granted ? 900 + slot.index * 40 : 650
                        easing.type: Easing.OutCubic
                    }
                }
                readonly property real px: sea.churnPoint.x + (sx - sea.churnPoint.x) * up
                readonly property real py: sea.churnPoint.y + (sy - sea.churnPoint.y) * up - Math.sin(up * Math.PI) * 70 * sea.sc
                // The newest keeps twinkling.
                readonly property bool newest: !sea.granted && index === (sea.ctx.cells - 1) % 12 && sea.ctx.cells > 0

                x: px - width / 2
                y: py - height / 2
                width: 76 * sea.sc
                height: width
                visible: up > 0.01
                opacity: Math.min(1, up * 3)
                scale: 0.35 + 0.65 * up

                Ratna {
                    id: gem
                    anchors.fill: parent
                    gem: slot.ratna[2]
                    lit: Math.min(1.35, (sea.granted ? 1.25 : 0.75) * sea.glow)
                    spoil: sea.ctx.denying ? 1 : 0
                    twinkle: slot.newest || sea.granted ? tw.value : 0

                    Behavior on spoil {
                        NumberAnimation { duration: 300 }
                    }
                }

                QtObject {
                    id: tw
                    property real value: 0
                }

                SequentialAnimation {
                    running: (slot.newest || sea.granted) && !sea.still && slot.visible
                    loops: Animation.Infinite
                    NumberAnimation { target: tw; property: "value"; from: 0; to: 1; duration: 380; easing.type: Easing.OutQuad }
                    NumberAnimation { target: tw; property: "value"; to: 0; duration: 700; easing.type: Easing.InQuad }
                    PauseAnimation { duration: 500 + slot.index * 60 }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.84
                    opacity: Math.max(0, slot.up * 1.6 - 0.6)
                    text: slot.ratna[1]
                    font.family: Deva.display
                    font.pixelSize: 16 * sea.sc
                    color: sea.ctx.denying ? Deva.alpha(Deva.poisonGlow, 0.9) : Deva.ivory
                    style: Text.Outline
                    styleColor: Deva.alpha("#0c0612", 0.6)
                }
            }
        }

        // Past twelve the churning goes on: how many more.
        Text {
            readonly property int extra: sea.granted ? 0 : Math.max(0, sea.ctx.cells - 12)
            visible: extra > 0
            x: garland.cx + Math.cos(26 * Math.PI / 180) * garland.rx + 34 * sea.sc
            y: garland.cy - Math.sin(26 * Math.PI / 180) * garland.ry - height / 2
            text: "+" + extra
            font.family: Deva.display
            font.pixelSize: 26 * sea.sc
            color: Deva.gold
        }
    }

    // ── The hour, and the panchang ───────────────────────────────────
    component Book: Text {
        font.family: Deva.book
        font.pixelSize: 22 * sea.sc
        color: Deva.ivory
    }

    Column {
        id: hours
        x: sea.width * 0.6
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -30 * sea.sc
        spacing: 4 * sea.sc
        opacity: sea.uiIn

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
            spacing: 16 * sea.sc

            Text {
                id: time
                text: Deva.numerals(Qt.formatTime(sea.ctx.now, "h:mm AP").split(" ")[0])
                font.family: Deva.display
                font.weight: Font.DemiBold
                font.pixelSize: 140 * sea.sc
                color: Deva.ivory
            }

            Text {
                anchors.baseline: time.baseline
                text: Deva.dayPart(sea.ctx.now)[1]
                font.family: Deva.display
                font.pixelSize: 40 * sea.sc
                color: Deva.gold
            }
        }

        Book {
            text: sea.pan.varaName + ", the " + Deva.ordinal(sea.ctx.now.getDate()) + " of " + Qt.formatDate(sea.ctx.now, "MMMM") + "  ·  " + Qt.formatTime(sea.ctx.now, "h:mm AP").toLowerCase()
            font.pixelSize: 24 * sea.sc
        }

        Book {
            text: sea.pan.masaName + " " + sea.pan.tithiLine + "  ·  " + sea.pan.nakshatraName + " nakshatra"
            font.italic: true
            font.pixelSize: 22 * sea.sc
            color: Deva.gold
        }

        // A temple border with a lotus at its middle.
        Item {
            width: 460 * sea.sc
            height: 36 * sea.sc

            Repeater {
                model: 2

                TempleBorder {
                    required property int index
                    x: index === 0 ? 0 : parent.width / 2 + 22 * sea.sc
                    y: parent.height / 2 - height
                    width: parent.width / 2 - 22 * sea.sc
                    height: 6 * sea.sc
                    step: 9 * sea.sc
                    rule: Math.max(1, sea.sc)
                    color: Deva.alpha(Deva.gold, 0.7)
                }
            }

            Lotus {
                x: (parent.width - width) / 2
                y: (parent.height - height) / 2 - 2 * sea.sc
                width: 36 * sea.sc
                height: 24 * sea.sc
                stroke: Deva.gold
                fill: Deva.alpha(Deva.pigment, 0.5)
                lineWidth: Math.max(1, sea.sc)
            }
        }

        // What the churning has brought up.
        Text {
            readonly property var c: sea.ctx
            text: sea.granted ? "Amrita, " + c.userName
                : c.phase === "verifying" ? "The ocean churns…"
                : c.denying ? "Halahala!"
                : sea.poisoned ? "The ocean is poison"
                : c.cells > 12 ? "The churning goes on"
                : c.cells > 0 ? sea.latest + " rises"
                : "Churn the ocean"
            font.family: Deva.display
            font.weight: Font.Medium
            font.pixelSize: 46 * sea.sc
            color: c.denying || sea.poisoned ? Deva.poisonGlow : sea.granted ? Deva.amrita : Deva.ivory
        }

        Book {
            readonly property var c: sea.ctx
            text: sea.granted
                ? (sea.reward ? "+" + Math.round(sea.reward.total * Math.min(1, sea.rewardIn * 1.3)) + " punya" + (sea.promote > 0 ? "  ·  now " + Deva.rank(sea.shownLevel) : "") : "")
                : c.message.length > 0 ? c.message
                : sea.poisoned ? "Neelakantha holds the poison in his throat for " + (c.lockoutClock || "a while")
                : c.capsLock ? "caps lock is on"
                : c.lastLife ? "one more and the poison takes the sea for " + Math.round(c.unlockTime / 60) + " minutes"
                : c.denying ? "the treasures sink back into the sea"
                : c.cells > 0 && c.cells <= 12 ? Deva.ratnaLines[(c.cells - 1) % 12] + (c.combo >= 6 ? ": the devas and asuras pull as one" : ": keep churning, then press Enter")
                : c.cells > 12 ? (c.combo >= 6 ? "the devas and asuras pull as one" : "keep churning, then press Enter")
                : "type your password; each letter brings up a treasure"
            font.pixelSize: 21 * sea.sc
            font.italic: true
            opacity: sea.granted ? sea.rewardIn : 1
            color: !sea.granted && (c.message.length > 0 || sea.poisoned || c.capsLock || c.lastLife) ? Deva.danger : Deva.alpha(Deva.ivory, 0.82)
        }

        Book {
            visible: sea.granted && sea.reward !== null
            width: Math.min(implicitWidth, sea.width * 0.36)
            elide: Text.ElideRight
            opacity: sea.rewardIn
            text: sea.reward
                ? sea.reward.lines.map(l => l.label.toLowerCase() + " +" + l.xp).join("  ·  ")
                  + (sea.reward.multiplier > 1 ? "  ·  streak ×" + sea.reward.multiplier.toFixed(2) : "")
                : ""
            font.pixelSize: 17 * sea.sc
            color: Deva.alpha(Deva.ivory, 0.65)
        }

        // The kalashas of amrita: the faillock lives.
        Row {
            topPadding: 14 * sea.sc
            spacing: 16 * sea.sc
            visible: !sea.granted && sea.ctx.maxLives > 0

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * sea.sc

                Repeater {
                    model: Math.min(sea.ctx.maxLives, 6)

                    Kalash {
                        required property int index
                        width: 40 * sea.sc
                        height: 56 * sea.sc
                        full: sea.poisoned ? 0 : index < sea.ctx.lives ? 1 : 0

                        Behavior on full {
                            NumberAnimation { duration: 900; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2 * sea.sc

                Text {
                    text: sea.poisoned ? "Every kalash is poisoned" : sea.ctx.lives >= sea.ctx.maxLives ? "The amrita is safe" : "The poison has spoiled " + (sea.ctx.maxLives - sea.ctx.lives === 1 ? "a kalash" : (sea.ctx.maxLives - sea.ctx.lives) + " kalashas")
                    font.family: Deva.display
                    font.pixelSize: 18 * sea.sc
                    font.weight: Font.Medium
                    color: sea.poisoned ? Deva.poisonGlow : Deva.gold
                }

                Book {
                    text: sea.poisoned ? "until " + (sea.ctx.lockoutClock || "the sea runs clear")
                        : sea.ctx.lives === 1 ? "one kalash of amrita left"
                        : sea.ctx.lives + " kalashas of amrita left"
                    font.pixelSize: 17 * sea.sc
                    font.italic: true
                    color: Deva.alpha(Deva.ivory, 0.7)
                }
            }
        }
    }

    // ── Around the edges ─────────────────────────────────────────────
    Item {
        anchors.fill: parent
        opacity: sea.uiIn

        Column {
            x: sea.edge
            y: 40 * sea.sc
            spacing: 2 * sea.sc

            Text {
                text: "समुद्र मन्थन"
                font.family: Deva.display
                font.weight: Font.Medium
                font.pixelSize: 34 * sea.sc
                color: Deva.ivory
            }

            Book {
                text: "the churning of the ocean of milk"
                font.pixelSize: 18 * sea.sc
                font.italic: true
                color: Deva.alpha(Deva.gold, 0.9)
            }

            Book {
                readonly property int s: Math.max(0, Math.floor((sea.ctx.now.getTime() - sea.ctx.lockedAt) / 1000))
                text: "churning for " + Math.floor(s / 3600) + ":" + String(Math.floor(s / 60) % 60).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0")
                font.pixelSize: 16 * sea.sc
                font.italic: true
                color: Deva.alpha(Deva.ivory, 0.62)
            }
        }

        Column {
            anchors.right: parent.right
            anchors.rightMargin: sea.edge
            y: 42 * sea.sc
            spacing: 2 * sea.sc

            Book {
                anchors.right: parent.right
                readonly property real pct: Services.Battery.percentage
                text: "oil in the lamp " + Math.round(pct) + "%" + (Services.Battery.charging ? ", filling" : "")
                font.pixelSize: 17 * sea.sc
                font.italic: true
                color: pct <= 20 && !Services.Battery.charging ? Deva.danger : Deva.alpha(Deva.ivory, 0.7)
            }

            Text {
                anchors.right: parent.right
                text: (sea.mu.name + " muhurta  ·  raga " + sea.pr.raga + "  ·  Vikram " + sea.pan.vikram).toUpperCase()
                font.family: Deva.display
                font.pixelSize: 13 * sea.sc
                font.weight: Font.Medium
                font.letterSpacing: 1.8 * sea.sc
                color: Deva.alpha(Deva.gold, 0.85)
            }

            Book {
                anchors.right: parent.right
                visible: sea.ctx.capsLock
                text: "caps lock"
                font.pixelSize: 16 * sea.sc
                font.italic: true
                color: Deva.danger
            }
        }

        // Siddhis attained (achievements), top right.
        Column {
            anchors.right: parent.right
            anchors.rightMargin: sea.edge
            y: 120 * sea.sc
            spacing: 12 * sea.sc
            visible: sea.granted

            Repeater {
                model: sea.reward ? sea.reward.achievements.slice(0, 3) : []

                Item {
                    id: slip
                    required property int index
                    required property var modelData
                    readonly property real appear: LockTheme.seg(sea.rewardIn, 0.15 + index * 0.18, 0.45 + index * 0.18)
                    width: 430 * sea.sc
                    height: 68 * sea.sc
                    opacity: appear
                    transform: Translate { y: (1 - slip.appear) * -16 * sea.sc }

                    Rectangle {
                        anchors.fill: parent
                        radius: 8 * sea.sc
                        color: Deva.alpha(Deva.ground, 0.92)
                        border.width: Math.max(1, 1.5 * sea.sc)
                        border.color: Deva.gold

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4 * sea.sc
                            radius: 5 * sea.sc
                            color: "transparent"
                            border.width: Math.max(1, sea.sc)
                            border.color: Deva.alpha(Deva.gold, 0.35)
                        }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 22 * sea.sc
                        spacing: 14 * sea.sc

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            text: slip.modelData.icon
                            filled: true
                            font.pixelSize: 24 * sea.sc
                            color: Deva.gold
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: "A siddhi attained: " + slip.modelData.name
                                font.family: Deva.display
                                font.pixelSize: 19 * sea.sc
                                color: Deva.ivory
                            }

                            Text {
                                text: slip.modelData.desc
                                font.family: Deva.book
                                font.pixelSize: 14 * sea.sc
                                font.italic: true
                                color: Deva.alpha(Deva.ivory, 0.72)
                            }
                        }
                    }
                }
            }
        }

        // The seeker, bottom left.
        Row {
            x: sea.edge
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 50 * sea.sc
            spacing: 24 * sea.sc

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 104 * sea.sc
                height: width

                // A ring of lotus petals round the portrait.
                Repeater {
                    model: 16

                    Shape {
                        id: petal
                        required property int index
                        readonly property real a: index * 22.5 * Math.PI / 180
                        readonly property real r: 44 * sea.sc
                        x: parent.width / 2 + Math.sin(a) * r - width / 2
                        y: parent.height / 2 - Math.cos(a) * r - height / 2
                        width: 10 * sea.sc
                        height: 14 * sea.sc
                        rotation: index * 22.5
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: Deva.alpha(Deva.pigment, 0.55)
                            strokeColor: Deva.gold
                            strokeWidth: Math.max(1, sea.sc)
                            startX: petal.width / 2
                            startY: petal.height

                            PathQuad { x: petal.width / 2; y: 0; controlX: -petal.width * 0.2; controlY: petal.height * 0.45 }
                            PathQuad { x: petal.width / 2; y: petal.height; controlX: petal.width * 1.2; controlY: petal.height * 0.45 }
                        }
                    }
                }

                Rectangle {
                    id: portraitMask
                    anchors.centerIn: parent
                    width: 72 * sea.sc
                    height: width
                    radius: width / 2
                    visible: false
                    layer.enabled: true
                }

                Image {
                    id: avatar
                    anchors.fill: portraitMask
                    source: "file://" + Quickshell.env("HOME") + "/.cache/current_avatar"
                    sourceSize: Qt.size(width * 2, height * 2)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    visible: false
                }

                MultiEffect {
                    anchors.fill: portraitMask
                    source: avatar
                    visible: avatar.status === Image.Ready
                    maskEnabled: true
                    maskSource: portraitMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                    saturation: -0.1
                    colorization: 0.12
                    colorizationColor: "#b86f35"
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 78 * sea.sc
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 3 * sea.sc
                    border.color: Deva.gold
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5 * sea.sc

                Row {
                    spacing: 12 * sea.sc

                    Text {
                        id: nameText
                        text: sea.ctx.userName
                        font.family: Deva.display
                        font.weight: Font.Medium
                        font.pixelSize: 34 * sea.sc
                        color: Deva.ivory
                    }

                    Book {
                        anchors.baseline: nameText.baseline
                        text: Deva.rank(sea.shownLevel) + "  " + Deva.rankDev(sea.shownLevel)
                        font.pixelSize: 19 * sea.sc
                        font.italic: true
                        color: sea.promote > 0 ? Deva.amrita : Deva.gold
                    }
                }

                // Merit towards the next rank, told on a mala.
                Item {
                    id: mala
                    readonly property real progress: Math.max(0, Math.min(1, (sea.shownXp - sea.levelFloor) / Math.max(1, sea.levelCeil - sea.levelFloor)))
                    readonly property int beads: 27
                    width: 300 * sea.sc
                    height: 14 * sea.sc

                    Rectangle {
                        y: mala.height / 2
                        width: mala.width - 12 * sea.sc
                        height: Math.max(1, sea.sc)
                        color: Deva.alpha(Deva.gold, 0.45)
                    }

                    Repeater {
                        model: mala.beads

                        Rectangle {
                            required property int index
                            readonly property bool told: (index + 0.5) / mala.beads <= mala.progress
                            x: (index + 0.5) * (mala.width - 12 * sea.sc) / mala.beads - width / 2
                            y: mala.height / 2 - height / 2
                            width: 8 * sea.sc
                            height: width
                            radius: width / 2
                            color: told ? Deva.gold : Deva.alpha(Deva.gold, 0.14)
                            border.width: Math.max(1, sea.sc)
                            border.color: told ? Deva.goldHi : Deva.alpha(Deva.gold, 0.45)
                        }
                    }

                    Rectangle {
                        x: mala.width - 10 * sea.sc
                        y: mala.height / 2 - height / 2
                        width: 11 * sea.sc
                        height: width
                        radius: width / 2
                        color: Deva.pigment
                        border.width: Math.max(1, sea.sc)
                        border.color: Deva.gold
                    }
                }

                Book {
                    text: Deva.count(Math.floor(sea.shownXp - sea.levelFloor)) + " / " + Deva.count(sea.levelCeil - sea.levelFloor) + " punya"
                        + "  ·  " + Services.LockStats.liveStreak + " days of sadhana"
                        + "  ·  " + Services.LockStats.achievements.length + "/" + Services.LockStats.achievementDefs.length + " siddhis"
                    font.pixelSize: 15 * sea.sc
                    color: Deva.alpha(Deva.ivory, 0.65)
                }
            }
        }

        // The Gandharvas' music, bottom centre.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: 60 * sea.sc
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 58 * sea.sc
            spacing: 12 * sea.sc
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
                    font.pixelSize: 20 * sea.sc
                    color: mediaArea.containsMouse ? Deva.gold : Deva.alpha(Deva.ivory, 0.75)

                    MouseArea {
                        id: mediaArea
                        anchors.fill: parent
                        anchors.margins: -6 * sea.sc
                        enabled: !sea.still
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.Media[mediaKey.modelData]()
                    }
                }
            }

            Book {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 460 * sea.sc)
                elide: Text.ElideRight
                text: "the Gandharvas play " + Services.Media.title + (Services.Media.artist ? ", by " + Services.Media.artist : "")
                font.pixelSize: 17 * sea.sc
                font.italic: true
            }
        }

        // Rest, rebirth, release, bottom right: hold one to choose it.
        Row {
            anchors.right: parent.right
            anchors.rightMargin: sea.edge
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 42 * sea.sc
            spacing: 22 * sea.sc

            Repeater {
                model: [
                    { label: "nidra", icon: "bedtime", act: "suspend" },
                    { label: "punarjanma", icon: "restart_alt", act: "reboot" },
                    { label: "moksha", icon: "power_settings_new", act: "poweroff" }
                ]

                Column {
                    id: knob
                    required property var modelData
                    spacing: 6 * sea.sc

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 54 * sea.sc
                        height: width

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: knobHold.containsMouse ? "#2a1410" : Deva.ground
                            border.width: Math.max(1, 2 * sea.sc)
                            border.color: Deva.gold
                        }

                        // Held: a gold arc runs round it.
                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            visible: knobHold.progress > 0

                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: Deva.amrita
                                strokeWidth: 3 * sea.sc
                                capStyle: ShapePath.RoundCap

                                PathAngleArc {
                                    centerX: 27 * sea.sc
                                    centerY: 27 * sea.sc
                                    radiusX: 22 * sea.sc
                                    radiusY: 22 * sea.sc
                                    startAngle: -90
                                    sweepAngle: 360 * knobHold.progress
                                }
                            }
                        }

                        Glyph {
                            anchors.centerIn: parent
                            text: knob.modelData.icon
                            font.pixelSize: 21 * sea.sc
                            color: Deva.ivory
                        }

                        HoldArea {
                            id: knobHold
                            anchors.fill: parent
                            enabled: !sea.still
                            onConfirmed: sea.ctx[knob.modelData.act]()
                        }
                    }

                    Book {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: knob.modelData.label
                        font.pixelSize: 14 * sea.sc
                        font.italic: true
                        color: Deva.alpha(Deva.ivory, 0.7)
                    }
                }
            }
        }
    }

    // ── The desktop, churned ─────────────────────────────────────────
    CaptureImage {
        id: capture
        source: sea.shot
        imageWidth: sea.width
        imageHeight: sea.height
    }

    ShaderEffect {
        anchors.fill: parent
        visible: capture.ready && sea.stir < 1

        property variant source: capture.image
        property real itemWidth: width
        property real itemHeight: height
        property real progress: sea.stir
        property point centre: Qt.point(sea.mountainX, 0.655)
        property color milkColor: "#e9e5dc"

        fragmentShader: Qt.resolvedUrl("../../../../shaders/lock_churn.frag.qsb")
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        visible: !capture.ready && opacity > 0
        opacity: 1 - sea.stir
    }

    // ── Choreography ─────────────────────────────────────────────────
    ParallelAnimation {
        id: intro
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation { target: sea; property: "stir"; from: 0; to: 1; duration: 1350; easing.type: Easing.InOutSine }
        }
        SequentialAnimation {
            PauseAnimation { duration: 950 }
            NumberAnimation { target: sea; property: "uiIn"; from: 0; to: 1; duration: 550; easing.type: Easing.OutCubic }
        }
    }

    // The sea is churned back into the desktop: the last frame is the
    // desktop exactly.
    ParallelAnimation {
        id: outro
        NumberAnimation { target: sea; property: "uiIn"; to: 0; duration: 280 }
        SequentialAnimation {
            PauseAnimation { duration: 140 }
            NumberAnimation { target: sea; property: "stir"; to: 0; duration: 1000; easing.type: Easing.InOutSine }
        }
    }

    NumberAnimation {
        id: splashFx
        target: sea
        property: "splash"
        from: 0.001
        to: 1
        duration: 800
        easing.type: Easing.OutCubic
    }

    ParallelAnimation {
        id: deniedFx
        SequentialAnimation {
            NumberAnimation { target: sea; property: "shakeX"; to: -9 * sea.sc; duration: 50 }
            NumberAnimation { target: sea; property: "shakeX"; to: 7 * sea.sc; duration: 70 }
            NumberAnimation { target: sea; property: "shakeX"; to: -3 * sea.sc; duration: 70 }
            NumberAnimation { target: sea; property: "shakeX"; to: 0; duration: 80 }
        }
        SequentialAnimation {
            NumberAnimation { target: sea; property: "poison"; to: 0.85; duration: 600; easing.type: Easing.OutCubic }
            PauseAnimation { duration: 800 }
            NumberAnimation { target: sea; property: "poison"; to: sea.poisoned ? 0.62 : 0; duration: 1500; easing.type: Easing.InOutSine }
        }
        SequentialAnimation {
            NumberAnimation { target: sea; property: "glow"; to: 0.3; duration: 80 }
            NumberAnimation { target: sea; property: "glow"; to: 1; duration: 900 }
        }
    }

    ParallelAnimation {
        id: grantFx
        NumberAnimation { target: sea; property: "grantIn"; from: 0; to: 1; duration: 400 }
        NumberAnimation { target: sea; property: "poison"; to: 0; duration: 500 }
        SequentialAnimation {
            PauseAnimation { duration: 350 }
            NumberAnimation { target: sea; property: "amrita"; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }
            NumberAnimation { target: sea; property: "amrita"; to: 0.7; duration: 700; easing.type: Easing.InOutSine }
        }
        SequentialAnimation {
            PauseAnimation { duration: 350 }
            NumberAnimation { target: sea; property: "rewardIn"; from: 0; to: 1; duration: 750 }
        }
    }

    SequentialAnimation {
        id: meritFill
        PauseAnimation { duration: 450 }
        NumberAnimation {
            target: sea
            property: "shownXp"
            to: sea.reward ? sea.reward.xpAfter : 0
            duration: 800
            easing.type: Easing.InOutCubic
        }
        PropertyAction { target: sea; property: "rewarding"; value: false }
    }

    NumberAnimation {
        id: promoteFx
        target: sea
        property: "promote"
        from: 0
        to: 1
        duration: 300
    }
}
