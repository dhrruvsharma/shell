pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs.components
import qs.modules.desktoptheme
import qs.modules.lock
import qs.services as Services

// "Blast Door" theme: a survivors' bunker after the fall.
//
// Lock-in: a corrugated blast shutter slams down over the desktop and
// throws up the dust: rusting steel with your wallpaper spray-painted
// across it, the time stencilled on, and a riveted keypad box. The passcode
// lights the code lamps one by one; a wrong code flashes the red lamp,
// rattles the shutter and pushes the Geiger counter up (the faillock lives
// as radiation exposure), and too many put the bunker into lockdown for
// decontamination. The right code turns the lamp green, pays out scrap
// (XP) and a new rank on the road, and the shutter rolls back up on the
// desktop.
//
// Theme contract (see ThemeHost): ctx, shot, shown, still, minScale.
Item {
    id: bunker

    required property LockContext ctx
    property url shot
    property bool shown: true
    property bool still: false
    property real minScale: 0.7

    readonly property real sc: Math.max(minScale, Math.min(2, Math.min(width / 1920, height / 1080)))
    readonly property real edge: 66 * sc

    // Choreography.
    property real drop: 0
    property real dust: 0
    property real uiIn: 0
    property real shakeX: 0
    property real shakeY: 0
    property real alarm: 0
    property real grantIn: 0
    property real rewardIn: 0
    property real promote: 0

    // Scrap (XP) on the tag: follows the stored XP, but runs up from the old
    // value during the reward.
    property real shownXp: Services.LockStats.xp
    readonly property int shownLevel: Services.LockStats.levelFor(shownXp)
    readonly property int levelFloor: Services.LockStats.xpForLevel(shownLevel)
    readonly property int levelCeil: Services.LockStats.xpForLevel(shownLevel + 1)
    property bool rewarding: false
    property int _seenLevel: 0

    readonly property bool granted: ctx.phase === "granted" || ctx.phase === "exiting"
    readonly property var reward: ctx.reward
    readonly property bool lockdown: ctx.lockedOut && ctx.cells === 0
    readonly property var hm: Qt.formatDateTime(ctx.now, "h:mm AP").split(" ")
    // The Geiger counter: exposure climbs with every wrong code.
    readonly property real exposure: lockdown ? 1 : ctx.maxLives > 0 ? (ctx.maxLives - ctx.lives) / ctx.maxLives : 0

    Component.onCompleted: {
        _seenLevel = shownLevel;
        if (still) {
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
        onTriggered: bunker.startIntro()
    }

    Connections {
        target: bunker.ctx

        function onPhaseChanged() {
            if (bunker.ctx.phase === "exiting") {
                intro.stop();
                outro.start();
            }
        }

        function onDenied(costLife) {
            deniedFx.restart();
        }

        function onGranted() {
            if (bunker.reward) {
                bunker.rewarding = true;
                bunker.shownXp = bunker.reward.xpBefore;
                scrapFill.restart();
            }
            grantFx.restart();
        }
    }

    // ── The desktop, until the shutter's down ────────────────────────
    CaptureImage {
        id: capture
        source: bunker.shot
        imageWidth: bunker.width
        imageHeight: bunker.height
    }

    ShaderEffect {
        anchors.fill: parent
        visible: capture.ready && bunker.drop < 1

        // The default shader draws `source` as it is.
        property variant source: capture.image
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        visible: !capture.ready && bunker.drop < 1
    }

    Item {
        width: 0
        height: 0
        clip: true

        Image {
            id: wallpaper
            width: bunker.width
            height: bunker.height
            source: "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
            sourceSize: Qt.size(Math.max(1, bunker.width), Math.max(1, bunker.height))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }
    }

    LockInput {
        ctx: bunker.ctx
        active: !bunker.still
        onEscapePressed: bunker.ctx.clearInput()
    }

    // ── Paint and stencils ───────────────────────────────────────────
    component Stencil: Text {
        font.family: Waste.stencilCond
        font.pixelSize: 22 * bunker.sc
        font.weight: Font.Bold
        font.letterSpacing: 2 * bunker.sc
        color: Waste.bone
    }

    component Typed: Text {
        font.family: Waste.type
        font.pixelSize: 15 * bunker.sc
        color: Waste.tapeInk
    }

    component Tape: Rectangle {
        property alias text: tapeText.text
        property alias font: tapeText.font
        width: tapeText.implicitWidth + 20 * bunker.sc
        height: tapeText.implicitHeight + 8 * bunker.sc
        color: Waste.tape
        opacity: 0.95

        Typed {
            id: tapeText
            anchors.centerIn: parent
        }
    }

    // ── The shutter ──────────────────────────────────────────────────
    Item {
        id: shutter
        width: parent.width
        height: parent.height
        y: -height * (1 - bunker.drop)
        visible: bunker.drop > 0
        transform: Translate {
            x: bunker.shakeX
            y: bunker.shakeY
        }

        ShaderEffect {
            anchors.fill: parent

            property variant wall: wallpaper
            property real itemWidth: width
            property real itemHeight: height
            property real uiScale: bunker.sc
            property real mural: 0.85
            property real rail: 64 * bunker.sc
            property color steelColor: Waste.steel
            property color rustColor: Waste.rust
            property color hazardColor: Waste.hazard
            property color grimeColor: Waste.grime
            property color paintColor: Waste.paint

            fragmentShader: Qt.resolvedUrl("../../../../shaders/lock_shutter.frag.qsb")
        }

        // Alarm light washing over the steel.
        Rectangle {
            anchors.fill: parent
            color: bunker.granted ? Waste.safe : Waste.danger
            opacity: bunker.alarm * 0.22
        }

        Item {
            anchors.fill: parent
            opacity: bunker.uiIn

            // Stencilled on the steel: whose bunker, and the time.
            Column {
                x: bunker.edge
                y: 54 * bunker.sc
                spacing: 2 * bunker.sc

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "black"
                    shadowOpacity: 0.75
                    shadowBlur: 0.35
                    blurMax: 12
                    shadowHorizontalOffset: 2
                    shadowVerticalOffset: 2
                }

                Text {
                    text: "BUNKER 7"
                    font.family: Waste.stencil
                    font.pixelSize: 58 * bunker.sc
                    font.weight: Font.Bold
                    font.letterSpacing: 4 * bunker.sc
                    color: Waste.bone
                }

                Stencil {
                    text: "AUTHORIZED SURVIVORS ONLY  ·  NO ENTRY WITHOUT CODE"
                    font.pixelSize: 21 * bunker.sc
                    color: Waste.hazard
                }

                Item {
                    width: 1
                    height: 34 * bunker.sc
                }

                Row {
                    spacing: 16 * bunker.sc

                    Text {
                        id: time
                        text: bunker.hm[0]
                        font.family: Waste.stencil
                        font.pixelSize: 190 * bunker.sc
                        font.weight: Font.Bold
                        color: Waste.bone
                    }

                    Text {
                        anchors.baseline: time.baseline
                        text: bunker.hm[1] ?? ""
                        font.family: Waste.stencilCond
                        font.pixelSize: 48 * bunker.sc
                        font.weight: Font.Bold
                        color: Waste.hazard
                    }
                }

                Stencil {
                    text: "DAY " + Clocks.dayOfYear(bunker.ctx.now) + "  ·  " + Qt.formatDate(bunker.ctx.now, "dddd d MMMM yyyy").toUpperCase()
                    font.pixelSize: 30 * bunker.sc
                }
            }

            Tape {
                x: bunker.edge + 6 * bunker.sc
                y: 548 * bunker.sc
                rotation: -2
                text: Waste.watch(bunker.ctx.now).toLowerCase()
                font.pixelSize: 19 * bunker.sc
            }

            // The time locked in, and the power cell, top right.
            Column {
                anchors.right: parent.right
                anchors.rightMargin: bunker.edge
                y: 40 * bunker.sc
                spacing: 4 * bunker.sc

                Stencil {
                    anchors.right: parent.right
                    readonly property real pct: Services.Battery.percentage
                    text: "POWER CELL " + Math.round(pct) + "%" + (Services.Battery.charging ? " · CHARGING" : "")
                    font.pixelSize: 19 * bunker.sc
                    color: pct <= 20 && !Services.Battery.charging ? Waste.danger : Waste.bone
                }

                Stencil {
                    anchors.right: parent.right
                    readonly property int s: Math.max(0, Math.floor((bunker.ctx.now.getTime() - bunker.ctx.lockedAt) / 1000))
                    text: "SEALED " + Math.floor(s / 3600) + ":" + String(Math.floor(s / 60) % 60).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0")
                    font.pixelSize: 17 * bunker.sc
                    color: Waste.alpha(Waste.bone, 0.7)
                }
            }

            // ── The keypad box ───────────────────────────────────────
            Item {
                id: keypad
                anchors.right: parent.right
                anchors.rightMargin: bunker.edge + 40 * bunker.sc
                y: 150 * bunker.sc
                width: 500 * bunker.sc
                height: 640 * bunker.sc

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "black"
                    shadowOpacity: 0.7
                    shadowBlur: 0.7
                    blurMax: 32
                    shadowHorizontalOffset: 6
                    shadowVerticalOffset: 10
                }

                ScrapPlate {
                    anchors.fill: parent
                    seed: 5
                    rust: 0.6
                    fill: 1
                    rivetSize: 11 * bunker.sc
                    rivetInset: 18 * bunker.sc
                }

                HazardStripes {
                    x: 40 * bunker.sc
                    y: 0
                    width: parent.width - 80 * bunker.sc
                    height: 12 * bunker.sc
                    stripe: 10 * bunker.sc
                    colorA: Waste.hazard
                    colorB: Waste.grime
                }

                Tape {
                    x: 40 * bunker.sc
                    y: 30 * bunker.sc
                    rotation: -1.5
                    text: "access code"
                    font.pixelSize: 18 * bunker.sc
                }

                // The status lamp.
                Rectangle {
                    id: lamp
                    anchors.right: parent.right
                    anchors.rightMargin: 44 * bunker.sc
                    y: 30 * bunker.sc
                    width: 30 * bunker.sc
                    height: width
                    radius: width / 2
                    readonly property color on: bunker.granted ? Waste.safe : bunker.ctx.denying || bunker.lockdown ? Waste.danger : Waste.hazard
                    color: on
                    border.width: Math.max(1, 3 * bunker.sc)
                    border.color: "#1a1714"
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: lamp.on
                        shadowOpacity: 1
                        shadowBlur: 0.8
                        blurMax: 24
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                    }
                }

                // The display: a recessed black window with the code lamps.
                Rectangle {
                    id: display
                    x: 36 * bunker.sc
                    y: 82 * bunker.sc
                    width: parent.width - 72 * bunker.sc
                    height: 150 * bunker.sc
                    color: "#0a0908"
                    border.width: Math.max(1, 3 * bunker.sc)
                    border.color: "#2c2924"

                    Column {
                        anchors.centerIn: parent
                        spacing: 16 * bunker.sc

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            readonly property var c: bunker.ctx
                            text: bunker.granted ? "ACCESS GRANTED"
                                : c.phase === "verifying" ? "VERIFYING…"
                                : c.denying ? "ACCESS DENIED"
                                : bunker.lockdown ? "LOCKDOWN"
                                : c.cells > 0 ? "CODE " + c.cells
                                : "ENTER CODE"
                            font.family: Waste.stencilCond
                            font.pixelSize: 44 * bunker.sc
                            font.weight: Font.Bold
                            font.letterSpacing: 4 * bunker.sc
                            color: bunker.granted ? Waste.safe : c.denying || bunker.lockdown ? Waste.danger : Waste.hazard
                        }

                        // A lamp per keystroke (never what was typed).
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 8 * bunker.sc

                            Repeater {
                                model: 14

                                Rectangle {
                                    required property int index
                                    readonly property bool on: bunker.granted || index < bunker.ctx.cells
                                    width: 16 * bunker.sc
                                    height: width
                                    radius: width / 2
                                    color: on ? (bunker.granted ? Waste.safe : bunker.ctx.denying ? Waste.danger : Waste.hazard) : "#211d19"
                                    border.width: Math.max(1, bunker.sc)
                                    border.color: "#3a352e"
                                }
                            }
                        }
                    }
                }

                // Messages, scratched under the display.
                Typed {
                    x: 40 * bunker.sc
                    y: display.y + display.height + 12 * bunker.sc
                    width: parent.width - 80 * bunker.sc
                    readonly property var c: bunker.ctx
                    text: bunker.granted
                        ? (bunker.reward ? "+" + Math.round(bunker.reward.total * Math.min(1, bunker.rewardIn * 1.3)) + " scrap" + (bunker.promote > 0 ? "  ·  promoted: " + Waste.rank(bunker.shownLevel).toLowerCase() : "") : "welcome back")
                        : c.message.length > 0 ? c.message
                        : bunker.lockdown ? "decontamination in progress · " + (c.lockoutClock || "stand by")
                        : c.capsLock ? "caps lock is on"
                        : c.lastLife ? "one more bad code and the bunker locks down for " + Math.round(c.unlockTime / 60) + " min"
                        : c.cells > 0 ? "press enter to try the code"
                        : "type the code. every key lights a lamp"
                    wrapMode: Text.WordWrap
                    font.pixelSize: 17 * bunker.sc
                    color: !bunker.granted && (c.message.length > 0 || bunker.lockdown || c.lastLife || c.capsLock) ? Waste.danger : Waste.bone
                }

                // The Geiger counter: exposure climbs with every bad code.
                Item {
                    id: geiger
                    x: 40 * bunker.sc
                    y: 300 * bunker.sc
                    width: 200 * bunker.sc
                    height: 118 * bunker.sc

                    readonly property real r: 88 * bunker.sc
                    readonly property real cx: width / 2
                    readonly property real cy: 100 * bunker.sc

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        component Zone: ShapePath {
                            id: zone
                            property real from: 0
                            property real to: 1
                            fillColor: "transparent"
                            strokeWidth: 12 * bunker.sc
                            capStyle: ShapePath.FlatCap

                            PathAngleArc {
                                centerX: geiger.cx
                                centerY: geiger.cy
                                radiusX: geiger.r
                                radiusY: geiger.r
                                startAngle: 180 + 180 * zone.from
                                sweepAngle: 180 * (zone.to - zone.from)
                            }
                        }

                        Zone { from: 0; to: 0.45; strokeColor: Waste.safe }
                        Zone { from: 0.45; to: 0.75; strokeColor: Waste.hazard }
                        Zone { from: 0.75; to: 1; strokeColor: Waste.danger }

                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: Waste.bone
                            strokeWidth: Math.max(2, 3 * bunker.sc)
                            capStyle: ShapePath.RoundCap
                            startX: geiger.cx
                            startY: geiger.cy
                            PathLine {
                                readonly property real a: Math.PI + Math.PI * (0.06 + 0.9 * geiger.needle)
                                x: geiger.cx + Math.cos(a) * geiger.r * 0.95
                                y: geiger.cy + Math.sin(a) * geiger.r * 0.95
                            }
                        }
                    }

                    property real needle: bunker.exposure
                    Behavior on needle {
                        NumberAnimation {
                            duration: 500
                            easing.type: Easing.OutElastic
                        }
                    }

                    Rectangle {
                        x: geiger.cx - width / 2
                        y: geiger.cy - height / 2
                        width: 16 * bunker.sc
                        height: width
                        radius: width / 2
                        color: Waste.steelHi
                        border.width: Math.max(1, 2 * bunker.sc)
                        border.color: "#15120e"
                    }
                }

                Column {
                    x: geiger.x + geiger.width + 24 * bunker.sc
                    y: geiger.y + 18 * bunker.sc
                    spacing: 4 * bunker.sc

                    Stencil {
                        text: "RAD EXPOSURE"
                        font.pixelSize: 22 * bunker.sc
                    }

                    Stencil {
                        text: bunker.lockdown ? "DECON " + (bunker.ctx.lockoutClock || "") : bunker.ctx.maxLives > 0 ? bunker.ctx.lives + " / " + bunker.ctx.maxLives + " SAFE TRIES LEFT" : "NO LIMIT"
                        font.pixelSize: 17 * bunker.sc
                        color: bunker.lockdown || bunker.ctx.lastLife ? Waste.danger : Waste.hazard
                    }

                    Typed {
                        text: bunker.exposure <= 0 ? "all clear" : bunker.exposure < 0.7 ? "elevated" : "critical"
                        font.pixelSize: 15 * bunker.sc
                        color: Waste.alpha(Waste.bone, 0.75)
                    }
                }

                // The heavy switches: hold one to throw it.
                Row {
                    x: 40 * bunker.sc
                    y: parent.height - height - 44 * bunker.sc
                    spacing: 18 * bunker.sc

                    Repeater {
                        model: [
                            { label: "SLEEP", icon: "bedtime", act: "suspend" },
                            { label: "REBOOT", icon: "restart_alt", act: "reboot" },
                            { label: "SHUTDOWN", icon: "power_settings_new", act: "poweroff" }
                        ]

                        Item {
                            id: toggle
                            required property var modelData
                            width: 128 * bunker.sc
                            height: 104 * bunker.sc

                            Rectangle {
                                anchors.fill: parent
                                radius: 3 * bunker.sc
                                color: toggleHold.containsMouse ? "#2c2823" : "#1f1c18"
                                border.width: Math.max(1, 2 * bunker.sc)
                                border.color: "#0f0d0b"
                                clip: true

                                // Held: hazard tape fills it up from the bottom.
                                HazardStripes {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: parent.height * toggleHold.progress
                                    stripe: 9 * bunker.sc
                                    colorA: Waste.hazard
                                    colorB: Waste.grime
                                    opacity: 0.85
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 6 * bunker.sc

                                Glyph {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: toggle.modelData.icon
                                    font.pixelSize: 30 * bunker.sc
                                    color: Waste.bone
                                }

                                Stencil {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: toggle.modelData.label
                                    font.pixelSize: 18 * bunker.sc
                                }
                            }

                            HoldArea {
                                id: toggleHold
                                anchors.fill: parent
                                enabled: !bunker.still
                                holdMs: 900
                                onConfirmed: bunker.ctx[toggle.modelData.act]()
                            }
                        }
                    }
                }
            }

            // ── The survivor's tag, bottom left ──────────────────────
            Row {
                x: bunker.edge
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 110 * bunker.sc
                spacing: 34 * bunker.sc

                // A faded photograph, taped up.
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 132 * bunker.sc
                    height: 152 * bunker.sc
                    rotation: -3

                    Rectangle {
                        anchors.fill: parent
                        color: "#e2d8c2"
                        border.width: Math.max(1, bunker.sc)
                        border.color: "#b9ad93"
                    }

                    Image {
                        id: avatar
                        x: 10 * bunker.sc
                        y: 10 * bunker.sc
                        width: parent.width - 20 * bunker.sc
                        height: width
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
                        saturation: -0.65
                        colorization: 0.35
                        colorizationColor: "#9c7442"
                        contrast: 0.1
                    }

                    Rectangle {
                        x: parent.width * 0.3
                        y: -10 * bunker.sc
                        width: 56 * bunker.sc
                        height: 20 * bunker.sc
                        rotation: 4
                        color: Waste.tape
                        opacity: 0.9
                    }
                }

                // The tag itself, on its chain.
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 330 * bunker.sc
                    height: 170 * bunker.sc

                    Rectangle {
                        id: tag
                        anchors.fill: parent
                        radius: 26 * bunker.sc
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#a5a095" }
                            GradientStop { position: 0.5; color: "#7f7a70" }
                            GradientStop { position: 1; color: "#5d5850" }
                        }
                        border.width: Math.max(1, 2 * bunker.sc)
                        border.color: "#3f3b35"
                    }

                    Rectangle {
                        x: 22 * bunker.sc
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18 * bunker.sc
                        height: width
                        radius: width / 2
                        color: Waste.grime
                        border.width: Math.max(1, 2 * bunker.sc)
                        border.color: "#4a463f"
                    }

                    Column {
                        x: 58 * bunker.sc
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2 * bunker.sc

                        component Embossed: Text {
                            font.family: Waste.cond
                            font.pixelSize: 22 * bunker.sc
                            font.weight: Font.Bold
                            font.letterSpacing: 2 * bunker.sc
                            color: "#34302a"
                            style: Text.Raised
                            styleColor: Qt.rgba(1, 1, 1, 0.35)
                        }

                        Embossed {
                            text: bunker.ctx.userName.toUpperCase()
                            font.pixelSize: 28 * bunker.sc
                        }

                        Embossed {
                            text: Waste.rank(bunker.shownLevel) + "  ·  LVL " + bunker.shownLevel
                            color: bunker.promote > 0 ? "#6b3d10" : "#34302a"
                        }

                        Embossed {
                            text: "SCRAP " + Waste.count(bunker.shownXp) + "  ·  " + Services.LockStats.liveStreak + " DAYS OK"
                            font.pixelSize: 18 * bunker.sc
                        }

                        // Scrap towards the next rank.
                        Item {
                            width: 230 * bunker.sc
                            height: 12 * bunker.sc
                            readonly property real progress: Math.max(0, Math.min(1, (bunker.shownXp - bunker.levelFloor) / Math.max(1, bunker.levelCeil - bunker.levelFloor)))

                            Rectangle {
                                anchors.fill: parent
                                color: "#2a2622"
                                border.width: Math.max(1, bunker.sc)
                                border.color: "#4a463f"
                            }

                            HazardStripes {
                                x: 1
                                y: 1
                                width: (parent.width - 2) * parent.progress
                                height: parent.height - 2
                                stripe: 5 * bunker.sc
                                colorA: Waste.hazard
                                colorB: Waste.grime
                            }
                        }
                    }
                }
            }

            // The radio, bottom centre.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: -120 * bunker.sc
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 96 * bunker.sc
                spacing: 12 * bunker.sc
                visible: Services.Media.activePlayer !== null

                Tape {
                    anchors.verticalCenter: parent.verticalCenter
                    rotation: 1.5
                    text: "radio · 88.1"
                    font.pixelSize: 16 * bunker.sc
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
                        font.pixelSize: 24 * bunker.sc
                        color: mediaArea.containsMouse ? Waste.hazard : Waste.bone

                        MouseArea {
                            id: mediaArea
                            anchors.fill: parent
                            anchors.margins: -6 * bunker.sc
                            enabled: !bunker.still
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.Media[mediaKey.modelData]()
                        }
                    }
                }

                Stencil {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 420 * bunker.sc)
                    elide: Text.ElideRight
                    text: (Services.Media.title + (Services.Media.artist ? " — " + Services.Media.artist : "")).toUpperCase()
                    font.pixelSize: 19 * bunker.sc
                }
            }

            // Notes left on the shutter: what this return turned up.
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: -160 * bunker.sc
                y: 150 * bunker.sc
                spacing: 14 * bunker.sc
                visible: bunker.granted

                Repeater {
                    model: bunker.reward ? bunker.reward.achievements.slice(0, 3) : []

                    Rectangle {
                        id: note
                        required property int index
                        required property var modelData
                        readonly property real appear: LockTheme.seg(bunker.rewardIn, 0.15 + index * 0.18, 0.45 + index * 0.18)
                        width: 400 * bunker.sc
                        height: 64 * bunker.sc
                        rotation: [-2, 1.5, -1][index % 3]
                        color: "#e4d9bd"
                        opacity: appear
                        transform: Translate { y: (1 - note.appear) * -16 * bunker.sc }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 16 * bunker.sc

                            Typed {
                                text: "found: " + note.modelData.name.toLowerCase()
                                font.pixelSize: 18 * bunker.sc
                            }

                            Typed {
                                text: note.modelData.desc.toLowerCase()
                                font.pixelSize: 13 * bunker.sc
                                color: Waste.alpha(Waste.tapeInk, 0.7)
                            }
                        }

                        Rectangle {
                            x: parent.width / 2 - width / 2
                            y: -8 * bunker.sc
                            width: 60 * bunker.sc
                            height: 16 * bunker.sc
                            rotation: -3
                            color: Waste.tape
                            opacity: 0.9
                        }
                    }
                }
            }
        }
    }

    // The dust the slam throws up.
    ShaderEffect {
        x: 0
        width: parent.width
        height: 360 * bunker.sc
        y: parent.height - height
        visible: bunker.dust > 0 && bunker.dust < 1

        property real itemWidth: width
        property real itemHeight: height
        property real progress: bunker.dust
        property color dustColor: Waste.dust

        fragmentShader: Qt.resolvedUrl("../../../../shaders/lock_dustburst.frag.qsb")
    }

    // ── Choreography ─────────────────────────────────────────────────
    ParallelAnimation {
        id: intro
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation { target: bunker; property: "drop"; from: 0; to: 1; duration: 620; easing.type: Easing.OutBounce }
        }
        SequentialAnimation {
            PauseAnimation { duration: 330 }
            NumberAnimation { target: bunker; property: "dust"; from: 0; to: 1; duration: 1300; easing.type: Easing.OutQuad }
        }
        SequentialAnimation {
            PauseAnimation { duration: 320 }
            NumberAnimation { target: bunker; property: "shakeY"; to: 9 * bunker.sc; duration: 40 }
            NumberAnimation { target: bunker; property: "shakeY"; to: -5 * bunker.sc; duration: 60 }
            NumberAnimation { target: bunker; property: "shakeY"; to: 2 * bunker.sc; duration: 60 }
            NumberAnimation { target: bunker; property: "shakeY"; to: 0; duration: 70 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 700 }
            NumberAnimation { target: bunker; property: "uiIn"; from: 0; to: 1; duration: 500; easing.type: Easing.OutCubic }
        }
    }

    // The shutter rolls back up: the last frame is the desktop exactly.
    ParallelAnimation {
        id: outro
        NumberAnimation { target: bunker; property: "uiIn"; to: 0; duration: 260 }
        SequentialAnimation {
            PauseAnimation { duration: 180 }
            NumberAnimation { target: bunker; property: "drop"; to: 0; duration: 850; easing.type: Easing.InOutCubic }
        }
    }

    ParallelAnimation {
        id: deniedFx
        SequentialAnimation {
            NumberAnimation { target: bunker; property: "alarm"; to: 1; duration: 60 }
            NumberAnimation { target: bunker; property: "alarm"; to: 0.2; duration: 180 }
            NumberAnimation { target: bunker; property: "alarm"; to: 1; duration: 60 }
            NumberAnimation { target: bunker; property: "alarm"; to: 0; duration: 500 }
        }
        SequentialAnimation {
            NumberAnimation { target: bunker; property: "shakeX"; to: -8 * bunker.sc; duration: 40 }
            NumberAnimation { target: bunker; property: "shakeX"; to: 7 * bunker.sc; duration: 50 }
            NumberAnimation { target: bunker; property: "shakeX"; to: -5 * bunker.sc; duration: 50 }
            NumberAnimation { target: bunker; property: "shakeX"; to: 3 * bunker.sc; duration: 50 }
            NumberAnimation { target: bunker; property: "shakeX"; to: 0; duration: 60 }
        }
    }

    ParallelAnimation {
        id: grantFx
        NumberAnimation { target: bunker; property: "grantIn"; from: 0; to: 1; duration: 350 }
        SequentialAnimation {
            NumberAnimation { target: bunker; property: "alarm"; to: 1; duration: 120 }
            NumberAnimation { target: bunker; property: "alarm"; to: 0; duration: 700 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 300 }
            NumberAnimation { target: bunker; property: "rewardIn"; from: 0; to: 1; duration: 750 }
        }
    }

    SequentialAnimation {
        id: scrapFill
        PauseAnimation { duration: 450 }
        NumberAnimation {
            target: bunker
            property: "shownXp"
            to: bunker.reward ? bunker.reward.xpAfter : 0
            duration: 800
            easing.type: Easing.InOutCubic
        }
        PropertyAction { target: bunker; property: "rewarding"; value: false }
    }

    NumberAnimation {
        id: promoteFx
        target: bunker
        property: "promote"
        from: 0
        to: 1
        duration: 300
    }
}
