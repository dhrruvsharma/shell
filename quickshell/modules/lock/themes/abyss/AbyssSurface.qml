pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs.components
import qs.modules.lock
import qs.services as Services

// "Bathysphere" theme: half a mile down.
//
// Lock-in: the desktop floods. The water climbs the screen under a rippling
// meniscus, the picture beneath it swimming and losing its reds, and then it
// all sinks into the dark: you're sealed in a bathysphere, watching the deep
// through its porthole (your wallpaper, drowned, as deep as the hour runs).
// The passcode pings the sonar: every keystroke sends a ring across the
// glass and wakes another light in the dark. A wrong one springs a leak:
// the alarm lamps flash, bubbles stream from the rim and an air cylinder
// empties (the faillock lives); a lockout rigs the boat for silent running
// under red light. The right one blows the ballast: light pours down,
// bubbles rush up, the depth gauge runs to the surface and the leagues
// (XP) are logged, with a promotion in the crew; then the sea drains away
// down the screen, leaving the desktop.
//
// Theme contract (see ThemeHost): ctx, shot, shown, still, minScale.
Item {
    id: sphere

    required property LockContext ctx
    property url shot
    property bool shown: true
    property bool still: false
    property real minScale: 0.7

    readonly property real sc: Math.max(minScale, Math.min(2, Math.min(width / 1920, height / 1080)))
    readonly property real edge: 64 * sc

    // Choreography.
    property real flood: 0
    property real uiIn: 0
    property real ping: 0
    property real flash: 0
    property real leak: 0
    property real rise: 0
    property real shakeX: 0
    property real grantIn: 0
    property real rewardIn: 0
    property real promote: 0

    // Lights awake in the water, a keystroke apiece.
    readonly property real litTarget: granted ? 16 : still ? 6 : Math.min(ctx.cells, 16)
    property real lit: litTarget
    Behavior on lit {
        NumberAnimation {
            duration: sphere.granted ? 700 : 300
            easing.type: Easing.OutCubic
        }
    }

    // Air (the faillock lives): each cylinder drains as a life goes.
    property real air: ctx.lives
    Behavior on air {
        NumberAnimation {
            duration: 900
            easing.type: Easing.InOutSine
        }
    }

    // Leagues (XP) on the card: follow the stored XP, but run up from the old
    // value during the reward.
    property real shownXp: Services.LockStats.xp
    readonly property int shownLevel: Services.LockStats.levelFor(shownXp)
    readonly property int levelFloor: Services.LockStats.xpForLevel(shownLevel)
    readonly property int levelCeil: Services.LockStats.xpForLevel(shownLevel + 1)
    property bool rewarding: false
    property int _seenLevel: 0

    readonly property bool granted: ctx.phase === "granted" || ctx.phase === "exiting"
    readonly property var reward: ctx.reward
    readonly property bool silent: ctx.lockedOut && ctx.cells === 0
    // Red light: flashes with a leak, steady while running silent.
    readonly property real alarm: Math.max(flash, silent ? 0.55 : 0)
    readonly property real metres: Deep.depthAt(ctx.now)
    readonly property var zone: Deep.zoneAt(metres)
    // On the way up the gauge runs to the surface.
    readonly property real shownMetres: metres * (1 - rise)

    Component.onCompleted: {
        _seenLevel = shownLevel;
        if (still) {
            flood = 1;
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
        onTriggered: sphere.startIntro()
    }

    Connections {
        target: sphere.ctx

        function onPhaseChanged() {
            if (sphere.ctx.phase === "exiting") {
                intro.stop();
                outro.start();
            }
        }

        function onTyped(index) {
            pingFx.restart();
        }

        function onDenied(costLife) {
            deniedFx.restart();
        }

        function onGranted() {
            if (sphere.reward) {
                sphere.rewarding = true;
                sphere.shownXp = sphere.reward.xpBefore;
                leaguesFill.restart();
            }
            grantFx.restart();
        }
    }

    // ── Inside the sphere ────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Deep.abyss
    }

    Item {
        width: 0
        height: 0
        clip: true

        Image {
            id: wallpaper
            width: sphere.width
            height: sphere.height
            source: "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
            sourceSize: Qt.size(Math.max(1, sphere.width), Math.max(1, sphere.height))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }
    }

    LockInput {
        ctx: sphere.ctx
        active: !sphere.still
        onEscapePressed: sphere.ctx.clearInput()
    }

    // The porthole: where it is, and the glass's radius.
    readonly property real portX: width * 0.31
    readonly property real portY: height * 0.48
    readonly property real portR: 272 * sc

    // What's outside, under the hull.
    ShaderEffect {
        x: sphere.portX - sphere.portR + sphere.shakeX
        y: sphere.portY - sphere.portR
        width: sphere.portR * 2
        height: width
        visible: wallpaper.status === Image.Ready

        // The part of the cropped wallpaper texture behind the porthole.
        readonly property vector4d crop: {
            const sx = wallpaper.paintedWidth > 0 ? Math.min(1, wallpaper.width / wallpaper.paintedWidth) : 1;
            const sy = wallpaper.paintedHeight > 0 ? Math.min(1, wallpaper.height / wallpaper.paintedHeight) : 1;
            return Qt.vector4d((1 - sx) / 2, (1 - sy) / 2, sx, sy);
        }

        property variant wall: wallpaper
        property real time: sphere.ctx.ambientTime
        property real lit: sphere.lit
        property real ping: sphere.ping
        property real rise: sphere.rise
        property real leak: sphere.leak
        property real shade: Deep.shade(sphere.shownMetres)
        property vector4d wallRect: Qt.vector4d(crop.x + x / Math.max(1, sphere.width) * crop.z, crop.y + y / Math.max(1, sphere.height) * crop.w, width / Math.max(1, sphere.width) * crop.z, height / Math.max(1, sphere.height) * crop.w)
        property color glowColor: Deep.glow
        property color lumeColor: Deep.lume
        property color waterColor: Deep.water

        fragmentShader: Qt.resolvedUrl("../../../../shaders/abyss_view.frag.qsb")
    }

    // The hull and the porthole's ring, drawn once.
    ShaderEffect {
        anchors.fill: parent
        layer.enabled: true
        transform: Translate { x: sphere.shakeX }

        property real itemWidth: width
        property real itemHeight: height
        property point centre: Qt.point(sphere.portX, sphere.portY)
        property real radius: sphere.portR
        property real unit: sphere.sc
        property color steelColor: Deep.steel
        property color glowColor: Deep.glow

        fragmentShader: Qt.resolvedUrl("../../../../shaders/abyss_hull.frag.qsb")
    }

    // Red light, and daylight from above on the way up.
    Rectangle {
        anchors.fill: parent
        color: Deep.alarm
        opacity: sphere.alarm * 0.26
        visible: opacity > 0
    }

    Rectangle {
        anchors.fill: parent
        visible: sphere.rise > 0
        opacity: sphere.rise * 0.3
        gradient: Gradient {
            GradientStop { position: 0; color: "#bff4ee" }
            GradientStop { position: 0.6; color: "transparent" }
        }
    }

    // ── The instruments ──────────────────────────────────────────────
    component Label: Text {
        font.family: Deep.ui
        font.pixelSize: 20 * sphere.sc
        color: Deep.foam
    }

    component Readout: Text {
        font.family: Deep.mono
        font.pixelSize: 18 * sphere.sc
        color: Deep.alpha(Deep.foam, 0.72)
    }

    Column {
        id: panel
        x: sphere.width * 0.6
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -12 * sphere.sc
        spacing: 6 * sphere.sc
        opacity: sphere.uiIn

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

        Text {
            text: Qt.formatTime(sphere.ctx.now, "HH:mm")
            font.family: Deep.display
            font.pixelSize: 124 * sphere.sc
            color: Deep.foam
        }

        Label {
            text: Qt.formatDate(sphere.ctx.now, "dddd d MMMM yyyy").toUpperCase()
            font.pixelSize: 19 * sphere.sc
            font.weight: Font.Bold
            font.letterSpacing: 3 * sphere.sc
            color: Deep.glow
        }

        Row {
            spacing: 14 * sphere.sc

            ZoneGauge {
                anchors.verticalCenter: parent.verticalCenter
                unit: sphere.sc
                height: 64 * sphere.sc
                metres: sphere.shownMetres
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2 * sphere.sc

                Text {
                    text: (sphere.shownMetres >= 0.5 ? "−" : "") + Deep.metres(sphere.shownMetres) + "  ·  " + (sphere.rise > 0.5 ? "SURFACING" : sphere.zone.name.toUpperCase())
                    font.family: Deep.display
                    font.pixelSize: 24 * sphere.sc
                    color: Deep.lume
                }

                Readout {
                    text: Deep.temperature(sphere.shownMetres).toFixed(1) + " °C  ·  " + Math.round(Deep.pressure(sphere.shownMetres)) + " ATM  ·  " + sphere.zone.latin.toUpperCase()
                }
            }
        }

        // A range scale.
        Item {
            width: 460 * sphere.sc
            height: 30 * sphere.sc

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: Math.max(1, sphere.sc)
                color: Deep.alpha(Deep.lume, 0.45)
            }

            ScaleTicks {
                y: parent.height / 2 - height
                width: parent.width
                height: 6 * sphere.sc
                up: true
                step: 23 * sphere.sc
                major: 5
                minorLength: 3 * sphere.sc
                majorLength: 6 * sphere.sc
                color: Deep.alpha(Deep.lume, 0.45)
            }

            PingArcs {
                x: parent.width / 2 - 10 * sphere.sc
                y: 0
                width: 20 * sphere.sc
                height: parent.height
                cx: width / 2
                cy: parent.height / 2
                startAngle: 225
                sweep: 90
                gap: 5 * sphere.sc
                color: Deep.lume
                lineWidth: Math.max(1, sphere.sc)
            }
        }

        // What the boat is doing.
        Text {
            readonly property var c: sphere.ctx
            text: sphere.granted ? "BLOW BALLAST!"
                : c.phase === "verifying" ? "LISTENING…"
                : c.denying ? "HULL BREACH"
                : sphere.silent ? "SILENT RUNNING"
                : c.cells > 0 ? (c.cells === 1 ? "1 CONTACT" : c.cells + " CONTACTS")
                : "PING THE DEEP"
            font.family: Deep.display
            font.pixelSize: 36 * sphere.sc
            color: c.denying || sphere.silent ? Deep.alarm : sphere.granted ? Deep.lume : Deep.foam
        }

        Label {
            readonly property var c: sphere.ctx
            text: sphere.granted
                ? (sphere.reward ? "+" + Math.round(sphere.reward.total * Math.min(1, sphere.rewardIn * 1.3)) + " leagues logged" + (sphere.promote > 0 ? "  ·  promoted to " + Deep.rank(sphere.shownLevel) : "") : "surfacing")
                : c.message.length > 0 ? c.message
                : sphere.silent ? "rigged for silent running; " + (c.lockoutClock ? "all clear in " + c.lockoutClock : "wait for the all clear")
                : c.capsLock ? "caps lock is on"
                : c.lastLife ? "one more leak and we run silent for " + Math.round(c.unlockTime / 60) + " minutes"
                : c.denying ? "the sea got in; try again"
                : c.cells > 0 ? (c.combo >= 6 ? "steady on the sonar" : "keep going, then press Enter")
                : "type your password; every key wakes a light in the dark"
            font.pixelSize: 19 * sphere.sc
            opacity: sphere.granted ? sphere.rewardIn : 1
            color: !sphere.granted && (c.message.length > 0 || sphere.silent || c.capsLock || c.lastLife) ? Deep.alarm : Deep.alpha(Deep.foam, 0.8)
        }

        Readout {
            visible: sphere.granted && sphere.reward !== null
            width: Math.min(implicitWidth, sphere.width * 0.36)
            elide: Text.ElideRight
            opacity: sphere.rewardIn
            text: sphere.reward
                ? sphere.reward.lines.map(l => l.label.toLowerCase() + " +" + l.xp).join("  ·  ")
                  + (sphere.reward.multiplier > 1 ? "  ·  streak ×" + sphere.reward.multiplier.toFixed(2) : "")
                : ""
            font.pixelSize: 15 * sphere.sc
        }

        // The air: the faillock lives, a cylinder each.
        Row {
            topPadding: 12 * sphere.sc
            spacing: 12 * sphere.sc
            visible: !sphere.granted && sphere.ctx.maxLives > 0

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: "AIR"
                font.pixelSize: 15 * sphere.sc
                font.weight: Font.Bold
                font.letterSpacing: 3 * sphere.sc
                color: sphere.silent ? Deep.alarm : Deep.lume
            }

            Repeater {
                model: sphere.ctx.maxLives

                Item {
                    id: tank
                    required property int index
                    readonly property real level: Math.max(0, Math.min(1, sphere.air - index))
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22 * sphere.sc
                    height: 52 * sphere.sc

                    // The valve.
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 8 * sphere.sc
                        height: 6 * sphere.sc
                        radius: 1.5 * sphere.sc
                        color: Deep.steelHi
                    }

                    Rectangle {
                        y: 5 * sphere.sc
                        width: parent.width
                        height: parent.height - y
                        radius: width / 2
                        color: Deep.alpha(Deep.abyss, 0.6)
                        border.width: Math.max(1, 1.5 * sphere.sc)
                        border.color: tank.level > 0.05 ? Deep.alpha(Deep.lume, 0.8) : Deep.alpha(Deep.alarm, 0.7)

                        Rectangle {
                            x: 3 * sphere.sc
                            width: parent.width - 6 * sphere.sc
                            height: (parent.height - 6 * sphere.sc) * tank.level
                            y: parent.height - 3 * sphere.sc - height
                            radius: width / 2
                            color: Deep.alpha(Deep.lume, 0.85)
                        }
                    }
                }
            }

            Readout {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 4 * sphere.sc
                text: sphere.silent ? (sphere.ctx.lockoutClock || "—") : Math.round(sphere.ctx.lives / Math.max(1, sphere.ctx.maxLives) * 100) + "%"
                font.pixelSize: 16 * sphere.sc
                color: sphere.silent || sphere.ctx.lastLife ? Deep.alarm : Deep.alpha(Deep.foam, 0.72)
            }
        }
    }

    // ── Around the edges ─────────────────────────────────────────────
    Item {
        anchors.fill: parent
        opacity: sphere.uiIn

        Column {
            x: sphere.edge
            y: 40 * sphere.sc
            spacing: 4 * sphere.sc

            Text {
                text: "BATHYSPHERE"
                font.family: Deep.display
                font.pixelSize: 24 * sphere.sc
                font.letterSpacing: 2 * sphere.sc
                color: Deep.foam
            }

            Readout {
                readonly property int s: Math.max(0, Math.floor((sphere.ctx.now.getTime() - sphere.ctx.lockedAt) / 1000))
                text: "DIVE TIME " + Math.floor(s / 3600) + ":" + String(Math.floor(s / 60) % 60).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0")
                font.pixelSize: 15 * sphere.sc
            }
        }

        Column {
            anchors.right: parent.right
            anchors.rightMargin: sphere.edge
            y: 42 * sphere.sc
            spacing: 4 * sphere.sc

            Readout {
                anchors.right: parent.right
                readonly property real pct: Services.Battery.percentage
                text: "BATTERIES " + Math.round(pct) + "%" + (Services.Battery.charging ? " · CHARGING" : "")
                font.pixelSize: 15 * sphere.sc
                color: pct <= 20 && !Services.Battery.charging ? Deep.alarm : Deep.alpha(Deep.foam, 0.72)
            }

            Readout {
                anchors.right: parent.right
                text: sphere.ctx.denying || sphere.silent ? "HULL BREACH" : "HULL NOMINAL"
                font.pixelSize: 15 * sphere.sc
                color: sphere.ctx.denying || sphere.silent ? Deep.alarm : Deep.alpha(Deep.lume, 0.8)
            }

            Readout {
                anchors.right: parent.right
                visible: sphere.ctx.capsLock
                text: "CAPS LOCK"
                font.pixelSize: 15 * sphere.sc
                color: Deep.alarm
            }
        }

        // New specimens (achievements), top right.
        Column {
            anchors.right: parent.right
            anchors.rightMargin: sphere.edge
            y: 130 * sphere.sc
            spacing: 12 * sphere.sc
            visible: sphere.granted

            Repeater {
                model: sphere.reward ? sphere.reward.achievements.slice(0, 3) : []

                Item {
                    id: card
                    required property int index
                    required property var modelData
                    readonly property real appear: LockTheme.seg(sphere.rewardIn, 0.15 + index * 0.18, 0.45 + index * 0.18)
                    width: 440 * sphere.sc
                    height: 68 * sphere.sc
                    opacity: appear
                    transform: Translate { y: (1 - card.appear) * 16 * sphere.sc }

                    Rectangle {
                        anchors.fill: parent
                        radius: 16 * sphere.sc
                        color: Deep.alpha(Deep.glass, 0.9)
                        border.width: Math.max(1, sphere.sc)
                        border.color: Deep.alpha(Deep.lume, 0.55)
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 20 * sphere.sc
                        spacing: 14 * sphere.sc

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            text: card.modelData.icon
                            filled: true
                            font.pixelSize: 24 * sphere.sc
                            color: Deep.lume
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter

                            Label {
                                text: "NEW SPECIMEN: " + card.modelData.name.toUpperCase()
                                font.pixelSize: 15 * sphere.sc
                                font.weight: Font.Bold
                                font.letterSpacing: 1 * sphere.sc
                            }

                            Label {
                                text: card.modelData.desc
                                font.pixelSize: 14 * sphere.sc
                                color: Deep.alpha(Deep.foam, 0.7)
                            }
                        }
                    }
                }
            }
        }

        // The diver, bottom left.
        Row {
            x: sphere.edge
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 50 * sphere.sc
            spacing: 22 * sphere.sc

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 96 * sphere.sc
                height: width

                Rectangle {
                    id: portMask
                    anchors.fill: parent
                    anchors.margins: 9 * sphere.sc
                    radius: width / 2
                    visible: false
                    layer.enabled: true
                }

                Image {
                    id: avatar
                    anchors.fill: portMask
                    source: "file://" + Quickshell.env("HOME") + "/.cache/current_avatar"
                    sourceSize: Qt.size(width * 2, height * 2)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    visible: false
                }

                MultiEffect {
                    anchors.fill: portMask
                    source: avatar
                    visible: avatar.status === Image.Ready
                    maskEnabled: true
                    maskSource: portMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                    saturation: -0.2
                    colorization: 0.25
                    colorizationColor: "#1d6f82"
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 8 * sphere.sc
                    border.color: "#2c4048"
                }

                Repeater {
                    model: 8

                    Rectangle {
                        required property int index
                        readonly property real a: (index * 45 + 22.5) * Math.PI / 180
                        readonly property real r: 44 * sphere.sc
                        x: 48 * sphere.sc + Math.sin(a) * r - width / 2
                        y: 48 * sphere.sc - Math.cos(a) * r - height / 2
                        width: 5 * sphere.sc
                        height: width
                        radius: width / 2
                        color: "#a9bec5"
                    }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6 * sphere.sc

                Row {
                    spacing: 12 * sphere.sc

                    Text {
                        id: nameText
                        text: sphere.ctx.userName.toUpperCase()
                        font.family: Deep.display
                        font.pixelSize: 26 * sphere.sc
                        color: Deep.foam
                    }

                    Label {
                        anchors.baseline: nameText.baseline
                        text: Deep.rank(sphere.shownLevel).toUpperCase()
                        font.pixelSize: 15 * sphere.sc
                        font.weight: Font.Bold
                        font.letterSpacing: 1.5 * sphere.sc
                        color: sphere.promote > 0 ? Deep.foam : Deep.lume
                    }
                }

                // Leagues towards the next rank, lit cell by cell.
                Row {
                    id: cells
                    spacing: 3 * sphere.sc
                    readonly property real progress: Math.max(0, Math.min(1, (sphere.shownXp - sphere.levelFloor) / Math.max(1, sphere.levelCeil - sphere.levelFloor)))

                    Repeater {
                        model: 20

                        Rectangle {
                            required property int index
                            readonly property bool lit: (index + 0.5) / 20 <= cells.progress
                            width: 10 * sphere.sc
                            height: width
                            radius: width / 2
                            color: lit ? Deep.lume : "transparent"
                            border.width: Math.max(1, sphere.sc)
                            border.color: Deep.alpha(Deep.lume, lit ? 1 : 0.35)
                        }
                    }
                }

                Readout {
                    text: Math.floor(sphere.shownXp - sphere.levelFloor) + " / " + (sphere.levelCeil - sphere.levelFloor) + " LEAGUES"
                        + "  ·  " + Services.LockStats.liveStreak + " DIVES RUNNING"
                        + "  ·  " + Services.LockStats.achievements.length + "/" + Services.LockStats.achievementDefs.length + " SPECIMENS"
                    font.pixelSize: 14 * sphere.sc
                    color: Deep.alpha(Deep.foam, 0.6)
                }
            }
        }

        // The hydrophone, bottom centre.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: 60 * sphere.sc
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 58 * sphere.sc
            spacing: 12 * sphere.sc
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
                    font.pixelSize: 20 * sphere.sc
                    color: mediaArea.containsMouse ? Deep.lume : Deep.alpha(Deep.foam, 0.75)

                    MouseArea {
                        id: mediaArea
                        anchors.fill: parent
                        anchors.margins: -6 * sphere.sc
                        enabled: !sphere.still
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.Media[mediaKey.modelData]()
                    }
                }
            }

            Readout {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 480 * sphere.sc)
                elide: Text.ElideRight
                text: "HYDROPHONE · " + Services.Media.title + (Services.Media.artist ? " — " + Services.Media.artist : "")
                font.pixelSize: 15 * sphere.sc
            }
        }

        // The valves, bottom right: hold one to turn it.
        Row {
            anchors.right: parent.right
            anchors.rightMargin: sphere.edge
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 42 * sphere.sc
            spacing: 22 * sphere.sc

            Repeater {
                model: [
                    { label: "REST", icon: "bedtime", act: "suspend" },
                    { label: "DIVE AGAIN", icon: "restart_alt", act: "reboot" },
                    { label: "ABANDON SHIP", icon: "power_settings_new", act: "poweroff" }
                ]

                Column {
                    id: valve
                    required property var modelData
                    spacing: 7 * sphere.sc

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 54 * sphere.sc
                        height: width

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: valveHold.containsMouse ? "#12262e" : Deep.alpha(Deep.glass, 0.9)
                            border.width: Math.max(1, 1.5 * sphere.sc)
                            border.color: Deep.alpha(Deep.lume, 0.6)
                        }

                        // Held: a ring of lume runs round it.
                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            visible: valveHold.progress > 0

                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: Deep.lume
                                strokeWidth: 3 * sphere.sc
                                capStyle: ShapePath.RoundCap

                                PathAngleArc {
                                    centerX: 27 * sphere.sc
                                    centerY: 27 * sphere.sc
                                    radiusX: 22 * sphere.sc
                                    radiusY: 22 * sphere.sc
                                    startAngle: -90
                                    sweepAngle: 360 * valveHold.progress
                                }
                            }
                        }

                        Glyph {
                            anchors.centerIn: parent
                            text: valve.modelData.icon
                            font.pixelSize: 21 * sphere.sc
                            color: Deep.foam
                        }

                        HoldArea {
                            id: valveHold
                            anchors.fill: parent
                            enabled: !sphere.still
                            onConfirmed: sphere.ctx[valve.modelData.act]()
                        }
                    }

                    Readout {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: valve.modelData.label
                        font.pixelSize: 12 * sphere.sc
                        font.letterSpacing: 1 * sphere.sc
                    }
                }
            }
        }
    }

    // ── The desktop, flooding ────────────────────────────────────────
    CaptureImage {
        id: capture
        source: sphere.shot
        imageWidth: sphere.width
        imageHeight: sphere.height
    }

    ShaderEffect {
        anchors.fill: parent
        visible: capture.ready && sphere.flood < 1

        property variant source: capture.image
        property real itemWidth: width
        property real itemHeight: height
        property real progress: sphere.flood
        property color waterColor: Deep.water
        property color glowColor: Deep.glow

        fragmentShader: Qt.resolvedUrl("../../../../shaders/lock_flood.frag.qsb")
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        visible: !capture.ready && opacity > 0
        opacity: 1 - sphere.flood
    }

    // ── Choreography ─────────────────────────────────────────────────
    ParallelAnimation {
        id: intro
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation { target: sphere; property: "flood"; from: 0; to: 1; duration: 1350; easing.type: Easing.InOutSine }
        }
        SequentialAnimation {
            PauseAnimation { duration: 950 }
            NumberAnimation { target: sphere; property: "uiIn"; from: 0; to: 1; duration: 550; easing.type: Easing.OutCubic }
        }
    }

    // The sea drains away down the screen: the last frame is the desktop
    // exactly.
    ParallelAnimation {
        id: outro
        NumberAnimation { target: sphere; property: "uiIn"; to: 0; duration: 280 }
        SequentialAnimation {
            PauseAnimation { duration: 120 }
            NumberAnimation { target: sphere; property: "flood"; to: 0; duration: 1100; easing.type: Easing.InOutSine }
        }
    }

    NumberAnimation {
        id: pingFx
        target: sphere
        property: "ping"
        from: 0.001
        to: 1
        duration: 900
        easing.type: Easing.OutCubic
    }

    ParallelAnimation {
        id: deniedFx
        SequentialAnimation {
            NumberAnimation { target: sphere; property: "shakeX"; to: -10 * sphere.sc; duration: 50 }
            NumberAnimation { target: sphere; property: "shakeX"; to: 8 * sphere.sc; duration: 70 }
            NumberAnimation { target: sphere; property: "shakeX"; to: -4 * sphere.sc; duration: 70 }
            NumberAnimation { target: sphere; property: "shakeX"; to: 0; duration: 80 }
        }
        SequentialAnimation {
            NumberAnimation { target: sphere; property: "flash"; to: 1; duration: 90 }
            NumberAnimation { target: sphere; property: "flash"; to: 0.25; duration: 220 }
            NumberAnimation { target: sphere; property: "flash"; to: 0.9; duration: 120 }
            NumberAnimation { target: sphere; property: "flash"; to: 0; duration: 700 }
        }
        SequentialAnimation {
            NumberAnimation { target: sphere; property: "leak"; to: 1; duration: 250 }
            PauseAnimation { duration: 900 }
            NumberAnimation { target: sphere; property: "leak"; to: 0; duration: 900 }
        }
    }

    ParallelAnimation {
        id: grantFx
        NumberAnimation { target: sphere; property: "grantIn"; from: 0; to: 1; duration: 400 }
        SequentialAnimation {
            PauseAnimation { duration: 300 }
            NumberAnimation { target: sphere; property: "rise"; from: 0; to: 1; duration: 1300; easing.type: Easing.InOutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 350 }
            NumberAnimation { target: sphere; property: "rewardIn"; from: 0; to: 1; duration: 750 }
        }
    }

    SequentialAnimation {
        id: leaguesFill
        PauseAnimation { duration: 450 }
        NumberAnimation {
            target: sphere
            property: "shownXp"
            to: sphere.reward ? sphere.reward.xpAfter : 0
            duration: 800
            easing.type: Easing.InOutCubic
        }
        PropertyAction { target: sphere; property: "rewarding"; value: false }
    }

    NumberAnimation {
        id: promoteFx
        target: sphere
        property: "promote"
        from: 0
        to: 1
        duration: 300
    }
}
