pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.lock

// "Pause Menu" theme: one monitor's lock screen.
//
// Lock-in: the first frame is the pre-lock capture of this screen, so locking
// starts exactly on the desktop. It flashes and greys out like a game pausing,
// then breaks into tiles that fly away in a wave to reveal the HUD, which
// assembles itself piece by piece.
// Unlock: the HUD packs away, the tiles fly back centre-first, colour returns
// and the session lock is dropped on a frame identical to the desktop again.
//
// Theme contract (see ThemeHost): ctx, shot, shown, still, minScale. All
// timing that matters for security lives in LockContext; this only animates.
Item {
    id: surface

    required property LockContext ctx
    property url shot
    // Lock surfaces are created before the compositor shows them; the intro
    // waits for this so its first frames aren't spent off-screen.
    property bool shown: true
    // Thumbnail mode (theme picker): fully assembled, no intro, no input.
    property bool still: false
    property real minScale: 0.7

    readonly property real sc: Math.max(minScale, Math.min(2, Math.min(width / 1920, height / 1080)))
    readonly property real edge: 64 * sc

    // Choreography, driven by the intro / outro animations below.
    property real hudIn: 0
    property real tiles: 0
    property real desat: 0
    property real flash: 0
    property color flashColor: "white"
    property real punch: 1
    property real cover: transition.ready ? 0 : 1
    property real dimLevel: ctx.awake ? 1 : 0.35

    Behavior on dimLevel {
        NumberAnimation { duration: 900; easing.type: Easing.InOutQuad }
    }

    function enter(from, to) {
        return LockTheme.seg(hudIn, from, to);
    }

    property bool _introStarted: false

    function startIntro() {
        if (_introStarted)
            return;
        _introStarted = true;
        introFallback.stop();
        intro.start();
    }

    onShownChanged: if (shown && !still) startIntro()
    Component.onCompleted: {
        if (still) {
            hudIn = 1;
            tiles = 1;
            cover = 0;
        } else if (shown) {
            startIntro();
        } else {
            introFallback.start();
        }
    }

    Timer {
        id: introFallback
        interval: 500
        onTriggered: surface.startIntro()
    }

    Connections {
        target: surface.ctx

        function onPhaseChanged() {
            if (surface.ctx.phase === "exiting") {
                intro.stop();
                outro.start();
            }
        }

        function onGranted() {
            if (surface.ctx.reward)
                card.playReward(surface.ctx.reward);
            surface.flashColor = LockTheme.gold;
            flashPulse.restart();
        }

        function onDenied(costLife) {
            surface.flashColor = LockTheme.danger;
            flashPulse.restart();
        }
    }

    LockBackdrop {
        anchors.fill: parent
        sc: surface.sc
    }

    // Keyboard + catch-all clicks; declared before the HUD so its controls
    // stay on top.
    LockInput {
        ctx: surface.ctx
        active: !surface.still
        onBackgroundPressed: sysMenu.open = false
        onEscapePressed: {
            if (sysMenu.open)
                sysMenu.open = false;
            else
                surface.ctx.clearInput();
        }
    }

    // ── HUD ──────────────────────────────────────────────────────────
    Item {
        id: hud
        anchors.fill: parent

        HudCorners {
            anchors.fill: parent
            size: 46 * surface.sc
            margin: 22 * surface.sc
            enter: surface.enter(0, 0.5)
            opacity: surface.dimLevel
        }

        SessionStatus {
            id: sessionStatus
            readonly property real e: surface.enter(0.1, 0.55)
            x: surface.edge
            y: 56 * surface.sc
            ctx: surface.ctx
            sc: surface.sc
            opacity: e * surface.dimLevel
            transform: Translate { y: -(1 - sessionStatus.e) * 30 * surface.sc }
        }

        SystemStatus {
            id: systemStatus
            readonly property real e: surface.enter(0.12, 0.57)
            anchors.right: parent.right
            anchors.rightMargin: surface.edge
            y: 60 * surface.sc
            ctx: surface.ctx
            sc: surface.sc
            opacity: e * surface.dimLevel
            transform: Translate { y: -(1 - systemStatus.e) * 30 * surface.sc }
        }

        AchievementToasts {
            anchors.right: parent.right
            anchors.rightMargin: surface.edge
            y: 116 * surface.sc
            ctx: surface.ctx
            sc: surface.sc
            opacity: surface.enter(0, 0.3)
        }

        Column {
            id: center
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -24 * surface.sc
            spacing: 34 * surface.sc

            ArcadeClock {
                id: clock
                readonly property real e: surface.enter(0.18, 0.66)
                anchors.horizontalCenter: parent.horizontalCenter
                now: surface.ctx.now
                sc: surface.sc
                opacity: e
                transform: Translate { y: -(1 - clock.e) * 26 * surface.sc }
            }

            PlayerCard {
                id: card
                readonly property real e: surface.enter(0.28, 0.78)
                anchors.horizontalCenter: parent.horizontalCenter
                ctx: surface.ctx
                sc: surface.sc
                opacity: e * (0.4 + 0.6 * surface.dimLevel)
                transform: Translate { y: (1 - card.e) * 34 * surface.sc }
            }

            PasscodeBar {
                id: passcode
                readonly property real e: surface.enter(0.38, 0.88)
                anchors.horizontalCenter: parent.horizontalCenter
                width: card.width
                ctx: surface.ctx
                sc: surface.sc
                opacity: e
                transform: Translate { y: (1 - passcode.e) * 34 * surface.sc }
            }
        }

        LockMedia {
            id: media
            readonly property real e: surface.enter(0.45, 0.95)
            anchors.left: parent.left
            anchors.leftMargin: surface.edge
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 56 * surface.sc
            sc: surface.sc
            opacity: e * surface.dimLevel
            transform: Translate { y: (1 - media.e) * 30 * surface.sc }
        }

        Row {
            id: corner
            readonly property real e: surface.enter(0.48, 1)
            anchors.right: parent.right
            anchors.rightMargin: surface.edge
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 56 * surface.sc
            spacing: 26 * surface.sc
            opacity: e * surface.dimLevel
            transform: Translate { y: (1 - corner.e) * 30 * surface.sc }

            TrophyStrip {
                anchors.verticalCenter: parent.verticalCenter
                sc: surface.sc
            }

            SystemMenu {
                id: sysMenu
                anchors.verticalCenter: parent.verticalCenter
                ctx: surface.ctx
                sc: surface.sc
            }
        }
    }

    // ── Transition layers ────────────────────────────────────────────
    LockTransition {
        id: transition
        anchors.fill: parent
        source: surface.shot
        progress: surface.tiles
        desat: surface.desat
        inward: surface.ctx.phase === "exiting"
        tileSize: Math.round(64 * surface.sc)
        scale: surface.punch
    }

    // Fallback when there's no capture: fade in from black instead.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: surface.cover
        visible: opacity > 0
    }

    Rectangle {
        anchors.fill: parent
        color: surface.flashColor
        opacity: surface.flash
        visible: opacity > 0
    }

    // ── Choreography ─────────────────────────────────────────────────
    ParallelAnimation {
        id: intro

        // Hold the untouched capture for a beat, then the "pause" flash + punch.
        SequentialAnimation {
            PauseAnimation { duration: 80 }
            ParallelAnimation {
                NumberAnimation { target: surface; property: "flash"; to: 0.22; duration: 70; easing.type: Easing.OutQuad }
                NumberAnimation { target: surface; property: "punch"; to: 1.014; duration: 90; easing.type: Easing.OutQuad }
            }
            ParallelAnimation {
                NumberAnimation { target: surface; property: "flash"; to: 0; duration: 280; easing.type: Easing.OutCubic }
                NumberAnimation { target: surface; property: "punch"; to: 1; duration: 340; easing.type: Easing.OutCubic }
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 120 }
            NumberAnimation { target: surface; property: "desat"; to: 0.85; duration: 380; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 260 }
            NumberAnimation { target: surface; property: "tiles"; from: 0; to: 1; duration: 900; easing.type: Easing.InOutSine }
        }
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation { target: surface; property: "cover"; to: 0; duration: 450; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 480 }
            NumberAnimation { target: surface; property: "hudIn"; from: 0; to: 1; duration: 760 }
        }
    }

    ParallelAnimation {
        id: outro

        NumberAnimation { target: surface; property: "hudIn"; to: 0; duration: 300; easing.type: Easing.InQuad }
        SequentialAnimation {
            PauseAnimation { duration: 120 }
            NumberAnimation { target: surface; property: "tiles"; to: 0; duration: 620; easing.type: Easing.InOutSine }
        }
        SequentialAnimation {
            PauseAnimation { duration: 600 }
            PropertyAction { target: surface; property: "flashColor"; value: "white" }
            ParallelAnimation {
                NumberAnimation { target: surface; property: "desat"; to: 0; duration: 260; easing.type: Easing.OutCubic }
                SequentialAnimation {
                    NumberAnimation { target: surface; property: "flash"; to: 0.1; duration: 60 }
                    NumberAnimation { target: surface; property: "flash"; to: 0; duration: 200 }
                }
            }
        }
    }

    SequentialAnimation {
        id: flashPulse
        NumberAnimation { target: surface; property: "flash"; to: 0.1; duration: 70; easing.type: Easing.OutQuad }
        NumberAnimation { target: surface; property: "flash"; to: 0; duration: 380; easing.type: Easing.OutCubic }
    }
}
