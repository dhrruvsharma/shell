pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs.components
import qs.modules.lock
import qs.services as Services

// "Express Elevator" theme: Art Deco, a 1920s skyscraper's lift.
//
// Lock-in: the transom comes down and the lift doors slide shut over the
// desktop: black lacquer and gold, each leaf engraved with its half of your
// wallpaper, a sunburst on the kick plates. The passcode takes you up: each
// keystroke moves the floor dial's needle up a floor and lights a diamond.
// A wrong one is the wrong floor (the needle drops back to the lobby and
// the down lantern flashes); the faillock lives are the service lamps, and a
// lockout puts the lift out of service. Getting in takes you to the
// penthouse: the needle swings over, the bell rings (the doors gild), you
// gain prestige (XP), and the doors open on the desktop.
//
// Theme contract (see ThemeHost): ctx, shot, shown, still, minScale.
Item {
    id: lift

    required property LockContext ctx
    property url shot
    property bool shown: true
    property bool still: false
    property real minScale: 0.7

    readonly property real sc: Math.max(minScale, Math.min(2, Math.min(width / 1920, height / 1080)))
    readonly property real transomH: Math.round(300 * sc)

    // Choreography.
    property real doorsIn: 0
    property real transomIn: 0
    property real uiIn: 0
    property real flash: 0
    property real alarm: 0
    property real shakeX: 0
    property real grantIn: 0
    property real rewardIn: 0
    property real levelUp: 0

    // The floors on the dial, lobby to penthouse.
    readonly property var floorLabels: ["L", "M", "2", "3", "4", "5", "6", "7", "8", "9", "10", "PH"]
    // The needle: a floor per keystroke, never the penthouse until you're
    // in; back to the lobby on a wrong floor.
    readonly property real target: granted ? 1 : still ? 0.42 : Math.min(ctx.cells, floorLabels.length - 2) / (floorLabels.length - 1)
    property real needle: target
    Behavior on needle {
        NumberAnimation {
            duration: lift.granted ? 900 : lift.ctx.denying ? 700 : 320
            easing.type: lift.ctx.denying ? Easing.OutBounce : Easing.OutBack
        }
    }

    // Prestige on the card: follows the stored XP, but counts up from the
    // old value during the reward.
    property real shownXp: Services.LockStats.xp
    readonly property int shownLevel: Services.LockStats.levelFor(shownXp)
    readonly property int levelFloor: Services.LockStats.xpForLevel(shownLevel)
    readonly property int levelCeil: Services.LockStats.xpForLevel(shownLevel + 1)
    property bool rewarding: false
    property int _seenLevel: 0

    readonly property bool granted: ctx.phase === "granted" || ctx.phase === "exiting"
    readonly property var reward: ctx.reward
    readonly property bool outOfService: ctx.lockedOut && ctx.cells === 0
    readonly property var hm: Qt.formatDateTime(ctx.now, "h:mm AP").split(" ")

    Component.onCompleted: {
        _seenLevel = shownLevel;
        if (still) {
            doorsIn = 1;
            transomIn = 1;
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
        onTriggered: lift.startIntro()
    }

    Connections {
        target: lift.ctx

        function onPhaseChanged() {
            if (lift.ctx.phase === "exiting") {
                intro.stop();
                outro.start();
            }
        }

        function onDenied(costLife) {
            deniedFx.restart();
        }

        function onGranted() {
            if (lift.reward) {
                lift.rewarding = true;
                lift.shownXp = lift.reward.xpBefore;
                prestigeFill.restart();
            }
            grantFx.restart();
        }
    }

    // ── The desktop, behind the doors while they move ────────────────
    CaptureImage {
        id: capture
        source: lift.shot
        imageWidth: lift.width
        imageHeight: lift.height
    }

    ShaderEffect {
        anchors.fill: parent
        visible: capture.ready && (lift.doorsIn < 1 || lift.transomIn < 1)

        // The default shader draws `source` as it is.
        property variant source: capture.image
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        visible: !capture.ready && (lift.doorsIn < 1 || lift.transomIn < 1)
    }

    // The wallpaper the doors are engraved with.
    Item {
        width: 0
        height: 0
        clip: true

        Image {
            id: wallpaper
            width: lift.width
            height: lift.height
            source: "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
            sourceSize: Qt.size(Math.max(1, lift.width), Math.max(1, lift.height))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }
    }

    LockInput {
        ctx: lift.ctx
        active: !lift.still
        onEscapePressed: lift.ctx.clearInput()
    }

    // ── The doors ────────────────────────────────────────────────────
    component Leaf: ShaderEffect {
        property bool rightLeaf: false
        property variant wall: wallpaper
        property real itemWidth: width
        property real itemHeight: height
        property real screenWidth: lift.width
        property real closedX: rightLeaf ? lift.width / 2 : 0
        property real mirror: rightLeaf ? 1 : 0
        property real uiScale: lift.sc
        property real flash: lift.flash
        property real alarm: lift.alarm
        property color goldColor: Deco.gold
        property color jewelColor: Deco.jewel
        property color lacquerColor: Deco.lacquer

        y: lift.transomH
        width: Math.ceil(lift.width / 2)
        height: lift.height - lift.transomH
        visible: lift.doorsIn > 0
        fragmentShader: Qt.resolvedUrl("../../../../shaders/lock_deco_door.frag.qsb")
    }

    Item {
        id: doors
        anchors.fill: parent
        transform: Translate { x: lift.shakeX }

        Leaf {
            x: -width * (1 - lift.doorsIn)
        }

        Leaf {
            rightLeaf: true
            x: lift.width / 2 + width * (1 - lift.doorsIn)
        }
    }

    // ── Brass plaques on the right leaf: what this visit earned ──────
    Column {
        x: lift.width * 0.75 - width / 2 + lift.width / 2 * (1 - lift.doorsIn)
        y: lift.transomH + 110 * lift.sc
        spacing: 12 * lift.sc
        visible: lift.granted

        Repeater {
            model: lift.reward ? lift.reward.achievements.slice(0, 3) : []

            Item {
                id: plaque
                required property int index
                required property var modelData
                readonly property real appear: LockTheme.seg(lift.rewardIn, 0.15 + index * 0.18, 0.45 + index * 0.18)
                width: 440 * lift.sc
                height: 70 * lift.sc
                opacity: appear
                transform: Translate { y: (1 - plaque.appear) * -18 * lift.sc }

                DecoFrame {
                    cut: 6 * lift.sc
                    steps: 2
                    fill: Qt.darker(Deco.gold, 1.9)
                    stroke: Deco.goldHi
                    strokeWidth: Math.max(1, lift.sc)
                    gap: 4 * lift.sc
                    innerStroke: Deco.alpha(Deco.goldHi, 0.45)
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 24 * lift.sc
                    spacing: 16 * lift.sc

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        text: plaque.modelData.icon
                        filled: true
                        font.pixelSize: 24 * lift.sc
                        color: Deco.goldHi
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: plaque.modelData.name.toUpperCase()
                            font.family: Deco.ui
                            font.pixelSize: 16 * lift.sc
                            font.weight: Font.Bold
                            font.letterSpacing: 3 * lift.sc
                            color: Deco.ivory
                        }

                        Text {
                            text: plaque.modelData.desc
                            font.family: Deco.ui
                            font.pixelSize: 13 * lift.sc
                            color: Deco.alpha(Deco.ivory, 0.7)
                        }
                    }
                }
            }
        }
    }

    // ── The transom ──────────────────────────────────────────────────
    component Caps: Text {
        font.family: Deco.ui
        font.pixelSize: 15 * lift.sc
        font.weight: Font.DemiBold
        font.letterSpacing: 3 * lift.sc
        color: Deco.ivory
    }

    Item {
        id: transom
        width: parent.width
        height: lift.transomH
        y: -height * (1 - lift.transomIn)

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.lighter(Deco.lacquer, 1.4) }
                GradientStop { position: 1; color: Deco.lacquer }
            }
        }

        // Gold rules along its foot, and a sunburst fanning behind the dial.
        Rectangle {
            y: parent.height - 3 * lift.sc
            width: parent.width
            height: Math.max(1, 2 * lift.sc)
            color: Deco.gold
        }

        Rectangle {
            y: parent.height - 9 * lift.sc
            width: parent.width
            height: Math.max(1, lift.sc)
            color: Deco.alpha(Deco.gold, 0.5)
        }

        Shape {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            width: 900 * lift.sc
            height: parent.height - 12 * lift.sc
            preferredRendererType: Shape.CurveRenderer
            opacity: 0.45

            ShapePath {
                fillColor: "transparent"
                strokeColor: Deco.alpha(Deco.gold, 0.7)
                strokeWidth: Math.max(1, lift.sc)

                PathMultiline {
                    paths: {
                        const out = [];
                        const cx = 450 * lift.sc;
                        const cy = transom.height - 12 * lift.sc;
                        for (let i = 1; i < 24; i++) {
                            const a = Math.PI + i * Math.PI / 24;
                            const r0 = 200 * lift.sc;
                            const r1 = (i % 2 === 0 ? 470 : 380) * lift.sc;
                            out.push([Qt.point(cx + Math.cos(a) * r0, cy + Math.sin(a) * r0), Qt.point(cx + Math.cos(a) * r1, cy + Math.sin(a) * r1)]);
                        }
                        return out;
                    }
                }
            }
        }

        // The floor dial, flanked by the hall lanterns.
        DecoDial {
            id: dial
            anchors.horizontalCenter: parent.horizontalCenter
            y: 26 * lift.sc
            width: 340 * lift.sc
            value: lift.needle
            ticks: lift.floorLabels.length
            labels: lift.floorLabels
            labelFont: Deco.ui
            labelSize: 15 * lift.sc
            line: Math.max(1.2, 1.8 * lift.sc)
            color: Deco.gold
            needleColor: lift.ctx.denying || lift.outOfService ? Deco.ruby : Deco.goldHi
        }

        component Lantern: Shape {
            id: lantern
            property bool up: true
            property bool lit: false
            property color litColor: Deco.goldHi
            width: 34 * lift.sc
            height: 26 * lift.sc
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: lantern.lit ? lantern.litColor : Deco.alpha(Deco.gold, 0.12)
                strokeColor: Deco.gold
                strokeWidth: Math.max(1, lift.sc)

                PathPolyline {
                    path: lantern.up
                        ? [Qt.point(lantern.width / 2, 0), Qt.point(lantern.width, lantern.height), Qt.point(0, lantern.height), Qt.point(lantern.width / 2, 0)]
                        : [Qt.point(0, 0), Qt.point(lantern.width, 0), Qt.point(lantern.width / 2, lantern.height), Qt.point(0, 0)]
                }
            }
        }

        Lantern {
            x: dial.x - width - 30 * lift.sc
            y: dial.y + dial.height - height - 6 * lift.sc
            up: true
            lit: lift.ctx.cells > 0 || lift.granted
        }

        Lantern {
            x: dial.x + dial.width + 30 * lift.sc
            y: dial.y + dial.height - height - 6 * lift.sc
            up: false
            lit: lift.ctx.denying || lift.outOfService
            litColor: Deco.ruby
        }

        // What the lift is doing, under the dial.
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: dial.y + dial.height + 14 * lift.sc
            spacing: 6 * lift.sc
            opacity: lift.uiIn

            Caps {
                anchors.horizontalCenter: parent.horizontalCenter
                readonly property var c: lift.ctx
                text: lift.granted ? "PENTHOUSE  ·  WELCOME HOME, " + c.userName.toUpperCase()
                    : c.phase === "verifying" ? "HOLD TIGHT  ·  GOING UP"
                    : c.denying ? "WRONG FLOOR"
                    : lift.outOfService ? "OUT OF SERVICE"
                    : c.cells > 0 ? "GOING UP  ·  FLOOR " + lift.floorLabels[Math.min(c.cells, lift.floorLabels.length - 2)]
                    : "TYPE YOUR PASSWORD TO GO UP"
                font.pixelSize: 19 * lift.sc
                font.letterSpacing: 5 * lift.sc
                color: c.denying || lift.outOfService ? Deco.ruby : lift.granted ? Deco.goldHi : Deco.ivory
            }

            // A diamond per keystroke.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 9 * lift.sc
                visible: !lift.granted
                height: 12 * lift.sc

                Repeater {
                    model: Math.min(lift.ctx.cells, 24)

                    Rectangle {
                        width: 8 * lift.sc
                        height: 8 * lift.sc
                        y: 2 * lift.sc
                        rotation: 45
                        color: lift.ctx.denying ? Deco.ruby : Deco.gold
                    }
                }
            }

            Caps {
                anchors.horizontalCenter: parent.horizontalCenter
                readonly property var c: lift.ctx
                visible: text.length > 0
                text: lift.granted
                    ? (lift.reward ? "+" + Math.round(lift.reward.total * Math.min(1, lift.rewardIn * 1.3)) + " PRESTIGE" + (lift.levelUp > 0 ? "  ·  RISEN TO FLOOR " + lift.shownLevel + ", " + Deco.floorName(lift.shownLevel) : "") : "")
                    : c.message.length > 0 ? c.message.toUpperCase()
                    : lift.outOfService ? "SERVICE RESUMES IN " + (c.lockoutClock || "A WHILE")
                    : c.capsLock ? "CAPS LOCK IS ON"
                    : c.lastLife ? "ONE MORE WRONG FLOOR AND THE LIFT STOPS FOR " + Math.round(c.unlockTime / 60) + " MINUTES"
                    : ""
                font.pixelSize: 13 * lift.sc
                opacity: lift.granted ? lift.rewardIn : 1
                color: lift.granted ? Deco.gold : Deco.ruby
            }

            // The service lamps: the faillock lives.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12 * lift.sc
                visible: !lift.granted && lift.ctx.maxLives > 0

                Repeater {
                    model: lift.ctx.maxLives

                    Rectangle {
                        required property int index
                        readonly property bool on: index < lift.ctx.lives
                        width: 11 * lift.sc
                        height: width
                        radius: width / 2
                        color: on ? Deco.goldHi : "transparent"
                        border.width: Math.max(1, lift.sc)
                        border.color: on ? Deco.gold : Deco.ruby
                    }
                }
            }
        }

        // The time, left.
        Column {
            x: 70 * lift.sc
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -6 * lift.sc
            spacing: 2 * lift.sc
            opacity: lift.uiIn

            Row {
                spacing: 12 * lift.sc

                Text {
                    id: time
                    text: lift.hm[0]
                    font.family: Deco.display
                    font.pixelSize: 118 * lift.sc
                    font.weight: Font.Bold
                    color: Deco.gold
                }

                Caps {
                    anchors.baseline: time.baseline
                    text: lift.hm[1] ?? ""
                    font.pixelSize: 24 * lift.sc
                }
            }

            Caps {
                text: Deco.date(lift.ctx.now)
                font.pixelSize: 15 * lift.sc
            }

            Text {
                topPadding: 6 * lift.sc
                text: Deco.hour(lift.ctx.now)
                font.family: Deco.marquee
                font.pixelSize: 19 * lift.sc
                font.letterSpacing: 4 * lift.sc
                color: Deco.gold
            }
        }

        // The resident, right.
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 70 * lift.sc
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -6 * lift.sc
            spacing: 22 * lift.sc
            layoutDirection: Qt.RightToLeft
            opacity: lift.uiIn

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 96 * lift.sc
                height: width

                DecoMask {
                    id: avatarMask
                    cut: 10 * lift.sc
                    steps: 2
                    active: true
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
                    saturation: -0.4
                    colorization: 0.25
                    colorizationColor: Deco.gold
                }

                DecoFrame {
                    cut: 10 * lift.sc
                    steps: 2
                    fill: "transparent"
                    stroke: Deco.gold
                    strokeWidth: Math.max(1, 1.5 * lift.sc)
                    gap: 5 * lift.sc
                    innerStroke: Deco.alpha(Deco.gold, 0.4)
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5 * lift.sc

                Text {
                    anchors.right: parent.right
                    text: lift.ctx.userName.toUpperCase()
                    font.family: Deco.display
                    font.pixelSize: 34 * lift.sc
                    font.weight: Font.Bold
                    font.letterSpacing: 4 * lift.sc
                    color: Deco.ivory
                }

                Caps {
                    anchors.right: parent.right
                    text: "FLOOR " + lift.shownLevel + "  ·  " + Deco.floorName(lift.shownLevel)
                    font.pixelSize: 14 * lift.sc
                    color: lift.levelUp > 0 ? Deco.goldHi : Deco.gold
                }

                // Prestige towards the next floor.
                Item {
                    anchors.right: parent.right
                    width: 260 * lift.sc
                    height: 10 * lift.sc
                    readonly property real progress: Math.max(0, Math.min(1, (lift.shownXp - lift.levelFloor) / Math.max(1, lift.levelCeil - lift.levelFloor)))

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: Math.max(1, lift.sc)
                        color: Deco.alpha(Deco.gold, 0.4)
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * parent.progress
                        height: 4 * lift.sc
                        color: Deco.gold
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: parent.width * parent.progress - width / 2
                        width: 9 * lift.sc
                        height: width
                        rotation: 45
                        color: Deco.goldHi
                    }
                }

                Caps {
                    anchors.right: parent.right
                    text: Math.floor(lift.shownXp - lift.levelFloor) + " / " + (lift.levelCeil - lift.levelFloor) + " PRESTIGE  ·  "
                        + Services.LockStats.liveStreak + "-DAY STREAK  ·  " + Services.LockStats.achievements.length + "/" + Services.LockStats.achievementDefs.length + " PLAQUES"
                    font.pixelSize: 11 * lift.sc
                    font.letterSpacing: 2 * lift.sc
                    color: Deco.alpha(Deco.ivory, 0.65)
                }
            }
        }

        // Battery and the time locked, top corners.
        Caps {
            x: 70 * lift.sc
            y: 20 * lift.sc
            opacity: lift.uiIn
            readonly property int s: Math.max(0, Math.floor((lift.ctx.now.getTime() - lift.ctx.lockedAt) / 1000))
            text: "EXPRESS ELEVATOR  ·  WAITING " + Math.floor(s / 3600) + ":" + String(Math.floor(s / 60) % 60).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0")
            font.pixelSize: 11 * lift.sc
            color: Deco.alpha(Deco.ivory, 0.55)
        }

        Caps {
            anchors.right: parent.right
            anchors.rightMargin: 70 * lift.sc
            y: 20 * lift.sc
            opacity: lift.uiIn
            readonly property real pct: Services.Battery.percentage
            text: "POWER " + Math.round(pct) + "%" + (Services.Battery.charging ? " · CHARGING" : "") + (lift.ctx.capsLock ? "  ·  CAPS LOCK" : "")
            font.pixelSize: 11 * lift.sc
            color: pct <= 20 && !Services.Battery.charging || lift.ctx.capsLock ? Deco.ruby : Deco.alpha(Deco.ivory, 0.55)
        }
    }

    // ── On the doors: the gramophone and the lift buttons ────────────
    Item {
        anchors.fill: parent
        opacity: lift.uiIn * (lift.granted ? 1 - lift.grantIn * 0.6 : 1)

        // What's playing, over the seam at the foot.
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 58 * lift.sc
            width: mediaRow.implicitWidth + 44 * lift.sc
            height: 52 * lift.sc
            visible: Services.Media.activePlayer !== null

            DecoFrame {
                cut: 6 * lift.sc
                steps: 2
                fill: Deco.alpha(Deco.lacquer, 0.92)
                stroke: Deco.gold
                strokeWidth: Math.max(1, lift.sc)
            }

            Row {
                id: mediaRow
                anchors.centerIn: parent
                spacing: 14 * lift.sc

                Repeater {
                    // Static model: only the icon follows play/pause.
                    model: ["previous", "playPause", "next"]

                    Glyph {
                        id: mediaKey
                        required property string modelData
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData === "playPause" ? (Services.Media.isPlaying ? "pause" : "play_arrow") : modelData === "previous" ? "skip_previous" : "skip_next"
                        filled: true
                        font.pixelSize: 22 * lift.sc
                        color: mediaArea.containsMouse ? Deco.goldHi : Deco.gold

                        MouseArea {
                            id: mediaArea
                            anchors.fill: parent
                            anchors.margins: -6 * lift.sc
                            enabled: !lift.still
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.Media[mediaKey.modelData]()
                        }
                    }
                }

                Caps {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 520 * lift.sc)
                    elide: Text.ElideRight
                    text: "ON THE GRAMOPHONE  ·  " + Services.Media.title + (Services.Media.artist ? "  —  " + Services.Media.artist : "")
                    font.pixelSize: 13 * lift.sc
                    font.letterSpacing: 2 * lift.sc
                }
            }
        }

        // The lift buttons, bottom right: hold one to press it home.
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 64 * lift.sc
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 50 * lift.sc
            spacing: 22 * lift.sc

            Repeater {
                model: [
                    { label: "SLEEP", icon: "bedtime", act: "suspend" },
                    { label: "RESTART", icon: "restart_alt", act: "reboot" },
                    { label: "SHUT DOWN", icon: "power_settings_new", act: "poweroff" }
                ]

                Column {
                    id: button
                    required property var modelData
                    spacing: 7 * lift.sc

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 54 * lift.sc
                        height: width

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            gradient: Gradient {
                                GradientStop { position: 0; color: Deco.goldHi }
                                GradientStop { position: 1; color: Deco.goldDeep }
                            }
                            border.width: Math.max(1, 2 * lift.sc)
                            border.color: Deco.lacquer
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 7 * lift.sc
                            radius: width / 2
                            color: buttonHold.containsMouse ? Qt.lighter(Deco.lacquerHi, 1.4) : Deco.lacquerHi
                            border.width: Math.max(1, lift.sc)
                            border.color: Deco.alpha(Deco.gold, 0.6)
                        }

                        Shape {
                            anchors.fill: parent
                            anchors.margins: -5 * lift.sc
                            visible: buttonHold.progress > 0
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: Deco.goldHi
                                strokeWidth: 3 * lift.sc
                                capStyle: ShapePath.FlatCap

                                PathAngleArc {
                                    centerX: 32 * lift.sc
                                    centerY: 32 * lift.sc
                                    radiusX: 30 * lift.sc
                                    radiusY: 30 * lift.sc
                                    startAngle: -90
                                    sweepAngle: 360 * buttonHold.progress
                                }
                            }
                        }

                        Glyph {
                            anchors.centerIn: parent
                            text: button.modelData.icon
                            font.pixelSize: 20 * lift.sc
                            color: Deco.gold
                        }

                        HoldArea {
                            id: buttonHold
                            anchors.fill: parent
                            enabled: !lift.still
                            onConfirmed: lift.ctx[button.modelData.act]()
                        }
                    }

                    Caps {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: button.modelData.label
                        font.pixelSize: 11 * lift.sc
                        font.letterSpacing: 2 * lift.sc
                        color: Deco.alpha(Deco.ivory, 0.75)
                    }
                }
            }
        }
    }

    // ── Choreography ─────────────────────────────────────────────────
    ParallelAnimation {
        id: intro
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation { target: lift; property: "transomIn"; from: 0; to: 1; duration: 520; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 160 }
            NumberAnimation { target: lift; property: "doorsIn"; from: 0; to: 1; duration: 820; easing.type: Easing.OutBack; easing.overshoot: 0.6 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 900 }
            NumberAnimation { target: lift; property: "uiIn"; from: 0; to: 1; duration: 500; easing.type: Easing.OutCubic }
        }
    }

    // The doors open on the desktop: the last frame is the desktop exactly.
    ParallelAnimation {
        id: outro
        NumberAnimation { target: lift; property: "uiIn"; to: 0; duration: 260 }
        SequentialAnimation {
            PauseAnimation { duration: 140 }
            NumberAnimation { target: lift; property: "doorsIn"; to: 0; duration: 820; easing.type: Easing.InOutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 460 }
            NumberAnimation { target: lift; property: "transomIn"; to: 0; duration: 560; easing.type: Easing.InCubic }
        }
    }

    ParallelAnimation {
        id: deniedFx
        SequentialAnimation {
            NumberAnimation { target: lift; property: "alarm"; to: 1; duration: 70 }
            NumberAnimation { target: lift; property: "alarm"; to: 0; duration: 650 }
        }
        SequentialAnimation {
            NumberAnimation { target: lift; property: "shakeX"; to: -9 * lift.sc; duration: 50 }
            NumberAnimation { target: lift; property: "shakeX"; to: 7 * lift.sc; duration: 70 }
            NumberAnimation { target: lift; property: "shakeX"; to: -3 * lift.sc; duration: 70 }
            NumberAnimation { target: lift; property: "shakeX"; to: 0; duration: 80 }
        }
    }

    ParallelAnimation {
        id: grantFx
        NumberAnimation { target: lift; property: "grantIn"; from: 0; to: 1; duration: 400 }
        SequentialAnimation {
            PauseAnimation { duration: 620 }
            NumberAnimation { target: lift; property: "flash"; from: 0; to: 1; duration: 120 }
            NumberAnimation { target: lift; property: "flash"; to: 0; duration: 700; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 400 }
            NumberAnimation { target: lift; property: "rewardIn"; from: 0; to: 1; duration: 750 }
        }
    }

    SequentialAnimation {
        id: prestigeFill
        PauseAnimation { duration: 500 }
        NumberAnimation {
            target: lift
            property: "shownXp"
            to: lift.reward ? lift.reward.xpAfter : 0
            duration: 800
            easing.type: Easing.InOutCubic
        }
        PropertyAction { target: lift; property: "rewarding"; value: false }
    }

    NumberAnimation {
        id: levelUpFx
        target: lift
        property: "levelUp"
        from: 0
        to: 1
        duration: 300
    }
}
