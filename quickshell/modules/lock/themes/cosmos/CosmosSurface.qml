pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs.modules.lock
import qs.services as Services

// "Astral" theme: deep space.
//
// Lock-in: the desktop is pulled into a singularity at the centre of the
// screen, twisting into a spiral until it burns out in a flash, leaving a
// drifting starfield and nebula. The passcode charts a constellation; a
// wrong one makes its stars fall like meteors and costs a shield. Unlocking
// engages warp (light-years gained, new ranks, constellations charted), then
// the desktop unspirals back out of a white hole.
//
// Theme contract (see ThemeHost): ctx, shot, shown, still, minScale.
Item {
    id: astral

    required property LockContext ctx
    property url shot
    property bool shown: true
    property bool still: false
    property real minScale: 0.7

    readonly property real sc: Math.max(minScale, Math.min(2, Math.min(width / 1920, height / 1080)))
    readonly property real edge: 60 * sc
    readonly property real clockY: height * 0.37
    readonly property string display: "ESPACION"
    readonly property string sans: "Adwaita Sans"
    readonly property color star: "#eef3ff"
    readonly property color dim: Qt.rgba(0.85, 0.9, 1, 0.55)
    readonly property color accent: LockTheme.accent
    readonly property color alarm: "#ff8a80"

    // Choreography.
    property real warp: 0
    property real core: 0
    property real uiIn: 0
    property real fall: 0
    property real flare: 0
    property real pulse: 0
    property real nova: 0
    property real rewardIn: 0
    property real rankUp: 0
    property real lost: 0

    property real shownXp: Services.LockStats.xp
    readonly property int shownLevel: Services.LockStats.levelFor(shownXp)
    readonly property int levelFloor: Services.LockStats.xpForLevel(shownLevel)
    readonly property int levelCeil: Services.LockStats.xpForLevel(shownLevel + 1)
    property bool rewarding: false
    property int _seenLevel: 0

    readonly property bool granted: ctx.phase === "granted" || ctx.phase === "exiting"
    readonly property var reward: ctx.reward

    readonly property var ranks: [[1, "STARGAZER"], [3, "DRIFTER"], [5, "VOYAGER"], [8, "NAVIGATOR"], [12, "PATHFINDER"],
        [16, "PIONEER"], [20, "STARWRIGHT"], [25, "VOID WALKER"], [30, "STAR SOVEREIGN"], [40, "CELESTIAL"], [50, "COSMIC"]]

    function rankFor(level) {
        let name = ranks[0][1];
        for (let i = 0; i < ranks.length; i++)
            if (level >= ranks[i][0])
                name = ranks[i][1];
        return name;
    }

    Component.onCompleted: {
        _seenLevel = shownLevel;
        if (still) {
            warp = 1;
            uiIn = 1;
        } else if (shown) {
            startIntro();
        } else {
            introFallback.start();
        }
    }

    onShownLevelChanged: {
        if (rewarding && _seenLevel > 0 && shownLevel > _seenLevel)
            rankUpFx.restart();
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
        onTriggered: astral.startIntro()
    }

    Connections {
        target: astral.ctx

        function onPhaseChanged() {
            if (astral.ctx.phase === "exiting") {
                intro.stop();
                outro.start();
            }
        }

        function onDenied(costLife) {
            deniedFx.restart();
        }

        function onTyped(index) {
            if (astral.fall > 0) {
                deniedFx.stop();
                astral.fall = 0;
            }
        }

        function onGranted() {
            if (astral.reward) {
                astral.rewarding = true;
                astral.shownXp = astral.reward.xpBefore;
                xpFill.restart();
            }
            grantFx.restart();
        }
    }

    NumberAnimation on pulse {
        running: astral.ctx.phase === "verifying"
        from: 0
        to: 1
        duration: 900
        loops: Animation.Infinite
    }

    // ── Space ────────────────────────────────────────────────────────
    ShaderEffect {
        anchors.fill: parent

        property real itemWidth: width
        property real itemHeight: height
        property real time: astral.ctx.ambientTime
        property real nebula: 1
        property color baseColor: "#03050b"
        property color tintA: astral.accent
        property color tintB: LockTheme.gold

        fragmentShader: Qt.resolvedUrl("../../../../shaders/lock_space.frag.qsb")
    }

    LockInput {
        ctx: astral.ctx
        active: !astral.still
        onEscapePressed: astral.ctx.clearInput()
    }

    // ── HUD ──────────────────────────────────────────────────────────
    Item {
        id: hud
        anchors.fill: parent
        opacity: astral.uiIn
        visible: opacity > 0

        Column {
            x: astral.edge
            y: 48 * astral.sc
            spacing: 6 * astral.sc

            Text {
                text: "ASTRAL"
                font.family: astral.display
                font.pixelSize: 24 * astral.sc
                font.letterSpacing: 10 * astral.sc
                color: astral.star
            }

            Text {
                text: "COORDINATES LOCKED  ·  ORBIT HELD"
                font.family: astral.sans
                font.pixelSize: 12 * astral.sc
                font.letterSpacing: 3 * astral.sc
                color: astral.dim
            }

            Text {
                readonly property int s: Math.max(0, Math.floor((astral.ctx.now.getTime() - astral.ctx.lockedAt) / 1000))
                text: "T+ " + String(Math.floor(s / 3600)).padStart(2, "0") + ":" + String(Math.floor(s / 60) % 60).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0")
                font.family: astral.display
                font.pixelSize: 20 * astral.sc
                color: astral.accent
            }
        }

        Column {
            anchors.right: parent.right
            anchors.rightMargin: astral.edge
            y: 48 * astral.sc
            spacing: 8 * astral.sc

            Text {
                anchors.right: parent.right
                readonly property real pct: Services.Battery.percentage
                text: "POWER " + Math.round(pct) + "%" + (Services.Battery.charging ? "  ·  CHARGING" : "")
                font.family: astral.sans
                font.pixelSize: 13 * astral.sc
                font.letterSpacing: 3 * astral.sc
                color: pct <= 20 && !Services.Battery.charging ? astral.alarm : astral.dim
            }

            Rectangle {
                anchors.right: parent.right
                width: 180 * astral.sc
                height: 3 * astral.sc
                color: Qt.rgba(1, 1, 1, 0.12)

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, Services.Battery.percentage / 100))
                    height: parent.height
                    color: astral.accent
                }
            }

            Text {
                anchors.right: parent.right
                visible: astral.ctx.capsLock
                text: "CAPS LOCK"
                font.family: astral.sans
                font.pixelSize: 12 * astral.sc
                font.letterSpacing: 3 * astral.sc
                color: astral.alarm
            }
        }

        // Orbit around the clock; the planet ticks through the minute.
        Item {
            id: orbit
            anchors.horizontalCenter: parent.horizontalCenter
            y: astral.clockY - height / 2
            width: 720 * astral.sc
            height: 250 * astral.sc
            rotation: -10

            readonly property real angle: (astral.ctx.now.getSeconds() / 60) * 2 * Math.PI - Math.PI / 2

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Qt.rgba(1, 1, 1, 0.16)
                    strokeWidth: 1 * astral.sc
                    PathAngleArc {
                        centerX: orbit.width / 2
                        centerY: orbit.height / 2
                        radiusX: orbit.width / 2
                        radiusY: orbit.height / 2
                        startAngle: 0
                        sweepAngle: 360
                    }
                }
            }

            Rectangle {
                width: 22 * astral.sc
                height: width
                radius: width / 2
                x: orbit.width / 2 + Math.cos(orbit.angle) * orbit.width / 2 - width / 2
                y: orbit.height / 2 + Math.sin(orbit.angle) * orbit.height / 2 - height / 2
                color: Qt.rgba(astral.accent.r, astral.accent.g, astral.accent.b, 0.25)

                Rectangle {
                    anchors.centerIn: parent
                    width: 8 * astral.sc
                    height: width
                    radius: width / 2
                    color: astral.accent
                }
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: astral.clockY - clockText.height / 2
            spacing: 4 * astral.sc

            Text {
                id: clockText
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(astral.ctx.now, "hh:mm")
                font.family: astral.display
                font.pixelSize: 150 * astral.sc
                color: astral.star
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(astral.ctx.now, "dddd  ·  d MMMM").toUpperCase()
                font.family: astral.sans
                font.pixelSize: 16 * astral.sc
                font.letterSpacing: 6 * astral.sc
                color: astral.dim
            }
        }

        Constellation {
            id: constellation
            anchors.horizontalCenter: parent.horizontalCenter
            y: astral.height * 0.575
            width: 1100 * astral.sc
            height: 110 * astral.sc
            ctx: astral.ctx
            sc: astral.sc
            tint: astral.star
            alarm: astral.alarm
            fall: astral.fall
            flare: astral.flare
            pulse: astral.pulse
        }

        // Prompt, shields and status / the warp read-out.
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: constellation.y + constellation.height + 8 * astral.sc
            spacing: 8 * astral.sc
            visible: !astral.granted

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                readonly property var c: astral.ctx
                text: c.phase === "verifying" ? "CALCULATING JUMP"
                    : c.denying ? "SIGNAL LOST"
                    : c.lockedOut && c.cells === 0 ? "SHIELDS DEPLETED"
                    : c.cells > 0 ? "CHARTING  ·  " + c.cells + (c.cells === 1 ? " STAR" : " STARS")
                    : "CHART YOUR CONSTELLATION"
                font.family: astral.display
                font.pixelSize: 17 * astral.sc
                font.letterSpacing: 6 * astral.sc
                color: c.denying || (c.lockedOut && c.cells === 0) ? astral.alarm : astral.star
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                readonly property var c: astral.ctx
                text: c.lockedOut && c.cells === 0 ? "recharging, next jump window in " + (c.lockoutClock || "a while")
                    : c.message.length > 0 ? c.message
                    : c.capsLock ? "caps lock is on"
                    : c.lastLife ? "one shield left: another miss grounds you for " + Math.round(c.unlockTime / 60) + " minutes"
                    : "type your passphrase  ·  enter to engage warp"
                font.family: astral.sans
                font.pixelSize: 13 * astral.sc
                font.letterSpacing: 1.5 * astral.sc
                color: c.capsLock || c.lastLife || c.message.length > 0 || (c.lockedOut && c.cells === 0) ? astral.alarm : astral.dim
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8 * astral.sc
                visible: astral.ctx.maxLives > 0

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SHIELDS"
                    font.family: astral.sans
                    font.pixelSize: 11 * astral.sc
                    font.letterSpacing: 3 * astral.sc
                    color: astral.dim
                }

                Repeater {
                    model: Math.min(astral.ctx.maxLives, 5)

                    Rectangle {
                        required property int index
                        readonly property bool up: index < astral.ctx.lives
                        anchors.verticalCenter: parent.verticalCenter
                        width: 9 * astral.sc
                        height: width
                        rotation: 45
                        color: up ? astral.accent : "transparent"
                        border.width: 1 * astral.sc
                        border.color: up ? astral.accent : astral.dim
                    }
                }
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: constellation.y + constellation.height + 4 * astral.sc
            spacing: 6 * astral.sc
            visible: astral.granted && astral.reward !== null
            opacity: astral.rewardIn

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: astral.rankUp > 0 ? "NEW RANK  ·  " + astral.rankFor(astral.shownLevel) : "WARP ENGAGED"
                font.family: astral.display
                font.pixelSize: 30 * astral.sc
                font.letterSpacing: 6 * astral.sc
                color: astral.accent
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "+" + Math.round((astral.reward ? astral.reward.total : 0) * Math.min(1, astral.rewardIn * 1.3)) + " LIGHT-YEARS"
                font.family: astral.display
                font.pixelSize: 20 * astral.sc
                font.letterSpacing: 3 * astral.sc
                color: astral.star
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: astral.reward
                    ? astral.reward.lines.map(l => l.label.toLowerCase() + " +" + l.xp).join("  ·  ")
                      + (astral.reward.multiplier > 1 ? "  ·  streak ×" + astral.reward.multiplier.toFixed(2) : "")
                    : ""
                font.family: astral.sans
                font.pixelSize: 13 * astral.sc
                color: astral.dim
            }
        }

        // Pilot, bottom left: the avatar as a planet with its atmosphere.
        Row {
            x: astral.edge
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 44 * astral.sc
            spacing: 18 * astral.sc

            Item {
                id: planet
                anchors.verticalCenter: parent.verticalCenter
                width: 86 * astral.sc
                height: width
                readonly property real progress: Math.max(0, Math.min(1, (astral.shownXp - astral.levelFloor) / Math.max(1, astral.levelCeil - astral.levelFloor)))

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: RadialGradient {
                            centerX: planet.width / 2
                            centerY: planet.height / 2
                            centerRadius: planet.width / 2
                            focalX: planet.width / 2
                            focalY: planet.height / 2
                            GradientStop { position: 0.72; color: Qt.rgba(astral.accent.r, astral.accent.g, astral.accent.b, 0.35) }
                            GradientStop { position: 1; color: "transparent" }
                        }
                        PathAngleArc {
                            centerX: planet.width / 2
                            centerY: planet.height / 2
                            radiusX: planet.width / 2
                            radiusY: planet.width / 2
                            startAngle: 0
                            sweepAngle: 360
                        }
                    }

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: astral.accent
                        strokeWidth: 2 * astral.sc
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: planet.width / 2
                            centerY: planet.height / 2
                            radiusX: planet.width / 2 - 2 * astral.sc
                            radiusY: planet.width / 2 - 2 * astral.sc
                            startAngle: -90
                            sweepAngle: 360 * planet.progress
                        }
                    }
                }

                Rectangle {
                    id: avatarMask
                    anchors.centerIn: parent
                    width: parent.width * 0.7
                    height: width
                    radius: width / 2
                    visible: false
                    layer.enabled: true
                }

                Image {
                    id: avatar
                    anchors.centerIn: parent
                    width: parent.width * 0.7
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
                    maskEnabled: true
                    maskSource: avatarMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4 * astral.sc

                Text {
                    text: astral.ctx.userName.toUpperCase()
                    font.family: astral.display
                    font.pixelSize: 20 * astral.sc
                    font.letterSpacing: 4 * astral.sc
                    color: astral.star
                }

                Text {
                    text: "RANK " + astral.shownLevel + "  ·  " + astral.rankFor(astral.shownLevel)
                    font.family: astral.sans
                    font.pixelSize: 12 * astral.sc
                    font.letterSpacing: 3 * astral.sc
                    color: astral.accent
                }

                Text {
                    text: Math.floor(astral.shownXp) + " LIGHT-YEARS  ·  " + Services.LockStats.liveStreak + " ORBITS  ·  "
                        + Services.LockStats.achievements.length + "/" + Services.LockStats.achievementDefs.length + " CONSTELLATIONS"
                    font.family: astral.sans
                    font.pixelSize: 11 * astral.sc
                    font.letterSpacing: 1.5 * astral.sc
                    color: astral.dim
                }
            }
        }

        // Transmission (media), bottom centre.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 52 * astral.sc
            spacing: 12 * astral.sc
            visible: Services.Media.activePlayer !== null

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "TRANSMISSION"
                font.family: astral.sans
                font.pixelSize: 11 * astral.sc
                font.letterSpacing: 3 * astral.sc
                color: astral.accent
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
                    font.pixelSize: 18 * astral.sc
                    color: mediaArea.containsMouse ? astral.star : astral.dim

                    MouseArea {
                        id: mediaArea
                        anchors.fill: parent
                        anchors.margins: -6 * astral.sc
                        enabled: !astral.still
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.Media[mediaKey.modelData]()
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 460 * astral.sc)
                elide: Text.ElideRight
                text: Services.Media.title + (Services.Media.artist ? "  —  " + Services.Media.artist : "")
                font.family: astral.sans
                font.pixelSize: 13 * astral.sc
                color: astral.star
            }
        }

        // Power, bottom right: hold to confirm.
        Row {
            anchors.right: parent.right
            anchors.rightMargin: astral.edge
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 40 * astral.sc
            spacing: 18 * astral.sc

            Repeater {
                model: [
                    { icon: "bedtime", label: "HIBERNATE", act: "suspend" },
                    { icon: "restart_alt", label: "RELAUNCH", act: "reboot" },
                    { icon: "power_settings_new", label: "SHUTDOWN", act: "poweroff" }
                ]

                Column {
                    id: power
                    required property var modelData
                    spacing: 6 * astral.sc

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 44 * astral.sc
                        height: width

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: Qt.rgba(1, 1, 1, powerHold.containsMouse ? 0.12 : 0.05)
                            border.width: 1 * astral.sc
                            border.color: Qt.rgba(1, 1, 1, 0.22)
                        }

                        Shape {
                            anchors.fill: parent
                            visible: powerHold.progress > 0
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: astral.accent
                                strokeWidth: 2 * astral.sc
                                capStyle: ShapePath.RoundCap
                                PathAngleArc {
                                    centerX: 22 * astral.sc
                                    centerY: 22 * astral.sc
                                    radiusX: 20.5 * astral.sc
                                    radiusY: 20.5 * astral.sc
                                    startAngle: -90
                                    sweepAngle: 360 * powerHold.progress
                                }
                            }
                        }

                        Glyph {
                            anchors.centerIn: parent
                            text: power.modelData.icon
                            font.pixelSize: 20 * astral.sc
                            color: astral.star
                        }

                        HoldArea {
                            id: powerHold
                            anchors.fill: parent
                            enabled: !astral.still
                            onConfirmed: astral.ctx[power.modelData.act]()
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: power.modelData.label
                        font.family: astral.sans
                        font.pixelSize: 10 * astral.sc
                        font.letterSpacing: 2 * astral.sc
                        color: astral.dim
                    }
                }
            }
        }

        // Constellations charted (achievements), top right.
        Column {
            anchors.right: parent.right
            anchors.rightMargin: astral.edge
            y: 150 * astral.sc
            spacing: 10 * astral.sc
            visible: astral.granted

            Repeater {
                model: astral.reward ? astral.reward.achievements.slice(0, 3) : []

                Rectangle {
                    id: charted
                    required property int index
                    required property var modelData
                    readonly property real appear: LockTheme.seg(astral.rewardIn, 0.15 + index * 0.18, 0.45 + index * 0.18)
                    width: 380 * astral.sc
                    height: 58 * astral.sc
                    radius: height / 2
                    color: Qt.rgba(0.02, 0.03, 0.07, 0.85)
                    border.width: 1 * astral.sc
                    border.color: Qt.rgba(astral.accent.r, astral.accent.g, astral.accent.b, 0.6)
                    opacity: appear
                    transform: Translate { x: (1 - charted.appear) * 40 * astral.sc }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 20 * astral.sc
                        spacing: 14 * astral.sc

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            text: charted.modelData.icon
                            filled: true
                            font.pixelSize: 22 * astral.sc
                            color: astral.accent
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                text: "CONSTELLATION CHARTED  ·  " + charted.modelData.name.toUpperCase()
                                font.family: astral.sans
                                font.pixelSize: 11 * astral.sc
                                font.letterSpacing: 2 * astral.sc
                                color: astral.star
                            }

                            Text {
                                text: charted.modelData.desc
                                font.family: astral.sans
                                font.pixelSize: 11 * astral.sc
                                color: astral.dim
                            }
                        }
                    }
                }
            }
        }
    }

    // Supernova ring when the passphrase is accepted.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: astral.clockY - height / 2
        width: 220 * astral.sc
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 2 * astral.sc
        border.color: astral.accent
        opacity: (1 - astral.nova) * (astral.nova > 0 ? 1 : 0)
        scale: 0.4 + astral.nova * 5
        visible: astral.nova > 0 && astral.nova < 1
    }

    // ── The desktop and its singularity ──────────────────────────────
    CaptureImage {
        id: capture
        source: astral.shot
        imageWidth: astral.width
        imageHeight: astral.height
    }

    ShaderEffect {
        anchors.fill: parent
        visible: capture.ready && astral.warp < 1

        property variant source: capture.image
        property real itemWidth: width
        property real itemHeight: height
        property real progress: astral.warp
        property point center: Qt.point(0.5, astral.clockY / Math.max(1, astral.height))
        property color glowColor: Qt.lighter(astral.accent, 1.3)

        fragmentShader: Qt.resolvedUrl("../../../../shaders/lock_warp.frag.qsb")
    }

    // The collapse / white-hole flash.
    Shape {
        anchors.fill: parent
        visible: astral.core > 0
        opacity: astral.core
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: astral.width / 2
                centerY: astral.clockY
                centerRadius: astral.height * 0.5
                focalX: astral.width / 2
                focalY: astral.clockY
                GradientStop { position: 0; color: "white" }
                GradientStop { position: 0.08; color: Qt.rgba(1, 1, 1, 0.8) }
                GradientStop { position: 0.35; color: Qt.rgba(astral.accent.r, astral.accent.g, astral.accent.b, 0.25) }
                GradientStop { position: 1; color: "transparent" }
            }
            PathAngleArc {
                centerX: astral.width / 2
                centerY: astral.clockY
                radiusX: astral.height * 0.5
                radiusY: astral.height * 0.5
                startAngle: 0
                sweepAngle: 360
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        visible: !capture.ready && opacity > 0
        opacity: 1 - astral.warp
    }

    // ── Choreography ─────────────────────────────────────────────────
    ParallelAnimation {
        id: intro
        SequentialAnimation {
            PauseAnimation { duration: 80 }
            NumberAnimation { target: astral; property: "warp"; from: 0; to: 1; duration: 1000; easing.type: Easing.InQuad }
        }
        SequentialAnimation {
            PauseAnimation { duration: 880 }
            NumberAnimation { target: astral; property: "core"; to: 1; duration: 110 }
            NumberAnimation { target: astral; property: "core"; to: 0; duration: 520; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 950 }
            NumberAnimation { target: astral; property: "uiIn"; from: 0; to: 1; duration: 650; easing.type: Easing.OutCubic }
        }
    }

    // Out of a white hole: the last frame is the desktop exactly.
    ParallelAnimation {
        id: outro
        NumberAnimation { target: astral; property: "uiIn"; to: 0; duration: 280; easing.type: Easing.InQuad }
        SequentialAnimation {
            PauseAnimation { duration: 180 }
            NumberAnimation { target: astral; property: "core"; to: 1; duration: 110 }
            NumberAnimation { target: astral; property: "core"; to: 0; duration: 480; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 260 }
            NumberAnimation { target: astral; property: "warp"; to: 0; duration: 780; easing.type: Easing.OutCubic }
        }
    }

    // The stars stay fallen (invisible) until the next character is typed.
    NumberAnimation {
        id: deniedFx
        target: astral
        property: "fall"
        from: 0
        to: 1
        duration: 650
        easing.type: Easing.InQuad
    }

    ParallelAnimation {
        id: grantFx
        SequentialAnimation {
            NumberAnimation { target: astral; property: "flare"; to: 1; duration: 200 }
            PauseAnimation { duration: 250 }
            NumberAnimation { target: astral; property: "flare"; to: 0; duration: 400 }
        }
        NumberAnimation { target: astral; property: "nova"; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }
        SequentialAnimation {
            PauseAnimation { duration: 200 }
            NumberAnimation { target: astral; property: "rewardIn"; from: 0; to: 1; duration: 700 }
        }
    }

    SequentialAnimation {
        id: xpFill
        PauseAnimation { duration: 350 }
        NumberAnimation {
            target: astral
            property: "shownXp"
            to: astral.reward ? astral.reward.xpAfter : 0
            duration: 800
            easing.type: Easing.InOutCubic
        }
        PropertyAction { target: astral; property: "rewarding"; value: false }
    }

    NumberAnimation {
        id: rankUpFx
        target: astral
        property: "rankUp"
        from: 0
        to: 1
        duration: 300
    }
}
