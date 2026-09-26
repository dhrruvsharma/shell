pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs.modules.lock
import qs.services as Services

// "Still" theme: minimal glass. The desktop softly loses focus and dims into
// a blurred wallpaper; a thin clock, the avatar and a glass passcode field
// fade up. Unlocking is quick: a check mark, then focus pulls back to the
// desktop.
//
// Theme contract (see ThemeHost): ctx, shot, shown, still, minScale.
Item {
    id: zen

    required property LockContext ctx
    property url shot
    property bool shown: true
    property bool still: false
    property real minScale: 0.7

    readonly property real sc: Math.max(minScale, Math.min(2, Math.min(width / 1920, height / 1080)))
    readonly property string sans: "Adwaita Sans"
    readonly property color ink: "#f7f7f9"
    readonly property color danger: "#ff9e94"

    // 0 = the capture, sharp (the desktop); 1 = the lock scene.
    property real reveal: 0
    property real uiIn: 0
    property real shakeX: 0

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
            reveal = 1;
            uiIn = 1;
        } else if (shown) {
            startIntro();
        } else {
            introFallback.start();
        }
    }

    Timer {
        id: introFallback
        interval: 500
        onTriggered: zen.startIntro()
    }

    Connections {
        target: zen.ctx

        function onPhaseChanged() {
            if (zen.ctx.phase === "exiting") {
                intro.stop();
                outro.start();
            }
        }

        function onDenied(costLife) {
            shake.restart();
        }
    }

    // ── Scene ────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#101014"
    }

    Image {
        id: wallpaper
        anchors.fill: parent
        source: "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
        sourceSize: Qt.size(Math.max(1, zen.width), Math.max(1, zen.height))
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        visible: wallpaper.status === Image.Ready
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: Math.max(8, Math.round(64 * zen.sc))
        blur: 1
        brightness: -0.12
        saturation: -0.1
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.12) }
            GradientStop { position: 0.55; color: Qt.rgba(0, 0, 0, 0.28) }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.55) }
        }
    }

    LockInput {
        id: input
        ctx: zen.ctx
        active: !zen.still
        onEscapePressed: zen.ctx.clearInput()
    }

    // ── UI ───────────────────────────────────────────────────────────
    Item {
        id: ui
        anchors.fill: parent
        opacity: zen.uiIn
        transform: Translate { y: (1 - zen.uiIn) * 16 * zen.sc }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.22
            spacing: 2 * zen.sc

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(zen.ctx.now, "hh:mm")
                font.family: zen.sans
                font.weight: Font.ExtraLight
                font.pixelSize: 176 * zen.sc
                font.letterSpacing: -3 * zen.sc
                color: zen.ink
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(zen.ctx.now, "dddd, d MMMM")
                font.family: zen.sans
                font.weight: Font.Light
                font.pixelSize: 22 * zen.sc
                color: Qt.rgba(1, 1, 1, 0.78)
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.6
            spacing: 16 * zen.sc

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 76 * zen.sc
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
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: avatar.status === Image.Ready ? "transparent" : Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.35)
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: zen.ctx.userName.charAt(0).toUpperCase() + zen.ctx.userName.slice(1)
                font.family: zen.sans
                font.weight: Font.Medium
                font.pixelSize: 20 * zen.sc
                color: zen.ink
            }

            // Glass passcode field
            Item {
                id: field
                anchors.horizontalCenter: parent.horizontalCenter
                width: 340 * zen.sc
                height: 54 * zen.sc
                transform: Translate { x: zen.shakeX }

                readonly property bool granted: zen.ctx.phase === "granted" || zen.ctx.phase === "exiting"
                readonly property bool bad: zen.ctx.denying
                property real verifyT: 0

                NumberAnimation on verifyT {
                    running: zen.ctx.phase === "verifying"
                    from: 0
                    to: 1
                    duration: 900
                    loops: Animation.Infinite
                }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, zen.ctx.cells > 0 ? 0.14 : 0.1)
                    border.width: 1
                    border.color: field.bad ? zen.danger : Qt.rgba(1, 1, 1, zen.ctx.cells > 0 ? 0.42 : 0.22)

                    Behavior on color {
                        ColorAnimation { duration: 200 }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: zen.ctx.cells === 0 && !field.granted && zen.ctx.phase !== "verifying"
                    text: zen.ctx.lockedOut ? "Locked for " + (zen.ctx.lockoutClock || "a while") : "Enter password"
                    font.family: zen.sans
                    font.pixelSize: 15 * zen.sc
                    color: zen.ctx.lockedOut ? zen.danger : Qt.rgba(1, 1, 1, 0.45)
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 12 * zen.sc
                    visible: !field.granted

                    // A fixed pool, so typing a character only pops in its own dot.
                    Repeater {
                        model: 18

                        Rectangle {
                            id: dot
                            required property int index
                            readonly property real wave: zen.ctx.phase === "verifying"
                                ? 0.35 + 0.65 * Math.abs(Math.sin((field.verifyT * 2 - index * 0.12) * Math.PI)) : 1
                            width: 10 * zen.sc
                            height: width
                            radius: width / 2
                            visible: index < zen.ctx.cells
                            color: field.bad ? zen.danger : zen.ink
                            opacity: wave
                            scale: 0

                            onVisibleChanged: {
                                if (visible)
                                    popIn.restart();
                                else
                                    scale = 0;
                            }

                            NumberAnimation {
                                id: popIn
                                target: dot
                                property: "scale"
                                from: 0.2
                                to: 1
                                duration: 180
                                easing.type: Easing.OutBack
                            }
                        }
                    }
                }

                Glyph {
                    id: check
                    anchors.centerIn: parent
                    visible: field.granted
                    text: "check"
                    weight: 300
                    font.pixelSize: 30 * zen.sc
                    color: zen.ink
                    scale: field.granted ? 1 : 0.4

                    Behavior on scale {
                        NumberAnimation { duration: 260; easing.type: Easing.OutBack }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 520 * zen.sc
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                readonly property bool warn: zen.ctx.capsLock || zen.ctx.lastLife || zen.ctx.denying
                text: zen.ctx.message.length > 0 ? zen.ctx.message
                    : zen.ctx.capsLock ? "Caps Lock is on"
                    : zen.ctx.lastLife ? "Last try before a " + Math.round(zen.ctx.unlockTime / 60) + " minute lockout"
                    : zen.ctx.denying ? "Wrong password"
                    : ""
                font.family: zen.sans
                font.pixelSize: 14 * zen.sc
                color: warn ? zen.danger : Qt.rgba(1, 1, 1, 0.7)
            }
        }

        // Battery + caps, top right
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 40 * zen.sc
            y: 34 * zen.sc
            spacing: 18 * zen.sc
            opacity: 0.8

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                visible: zen.ctx.capsLock
                text: "keyboard_capslock"
                font.pixelSize: 20 * zen.sc
                color: zen.danger
            }

            Row {
                spacing: 4 * zen.sc

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Services.Battery.charging ? "battery_charging_full" : "battery_full"
                    font.pixelSize: 18 * zen.sc
                    color: zen.ink
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(Services.Battery.percentage) + "%"
                    font.family: zen.sans
                    font.pixelSize: 15 * zen.sc
                    color: zen.ink
                }
            }
        }

        // Now playing, bottom left
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 40 * zen.sc
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 38 * zen.sc
            spacing: 12 * zen.sc
            visible: Services.Media.activePlayer !== null
            opacity: 0.85

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: Services.Media.isPlaying ? "pause" : "play_arrow"
                filled: true
                font.pixelSize: 22 * zen.sc
                color: playArea.containsMouse ? "#ffffff" : zen.ink

                MouseArea {
                    id: playArea
                    anchors.fill: parent
                    anchors.margins: -6 * zen.sc
                    enabled: !zen.still
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Services.Media.playPause()
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 420 * zen.sc)
                elide: Text.ElideRight
                text: Services.Media.title + (Services.Media.artist ? "  —  " + Services.Media.artist : "")
                font.family: zen.sans
                font.pixelSize: 15 * zen.sc
                color: zen.ink
            }
        }

        // Power, bottom right: hold to confirm
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 40 * zen.sc
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 30 * zen.sc
            spacing: 14 * zen.sc

            Repeater {
                model: [
                    { icon: "bedtime", act: "suspend" },
                    { icon: "restart_alt", act: "reboot" },
                    { icon: "power_settings_new", act: "poweroff" }
                ]

                Item {
                    id: power
                    required property var modelData
                    width: 42 * zen.sc
                    height: width

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Qt.rgba(1, 1, 1, hold.containsMouse ? 0.18 : 0.08)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.2)
                    }

                    Shape {
                        anchors.fill: parent
                        visible: hold.progress > 0
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: zen.ink
                            strokeWidth: 2 * zen.sc
                            capStyle: ShapePath.RoundCap
                            PathAngleArc {
                                centerX: power.width / 2
                                centerY: power.height / 2
                                radiusX: power.width / 2 - 1.5 * zen.sc
                                radiusY: radiusX
                                startAngle: -90
                                sweepAngle: 360 * hold.progress
                            }
                        }
                    }

                    Glyph {
                        anchors.centerIn: parent
                        text: power.modelData.icon
                        font.pixelSize: 20 * zen.sc
                        color: zen.ink
                    }

                    HoldArea {
                        id: hold
                        anchors.fill: parent
                        enabled: !zen.still
                        onConfirmed: zen.ctx[power.modelData.act]()
                    }
                }
            }
        }
    }

    // ── Capture layer (transitions) ──────────────────────────────────
    // At reveal 0 the capture is drawn as a plain image, so the first and
    // last frames are exactly the desktop; in between it's blurred and faded.
    Image {
        id: capture
        anchors.fill: parent
        source: zen.shot
        asynchronous: false
        cache: false
        visible: status === Image.Ready && zen.reveal <= 0
    }

    MultiEffect {
        anchors.fill: parent
        source: capture
        visible: capture.status === Image.Ready && zen.reveal > 0 && zen.reveal < 1
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: Math.max(8, Math.round(64 * zen.sc))
        blur: Math.min(1, zen.reveal * 1.4)
        brightness: -0.15 * zen.reveal
        opacity: 1 - Math.max(0, (zen.reveal - 0.35) / 0.65)
        scale: 1 + 0.035 * zen.reveal
    }

    // No capture: fade in from black instead.
    Rectangle {
        anchors.fill: parent
        color: "black"
        visible: capture.status !== Image.Ready && opacity > 0
        opacity: 1 - zen.reveal
    }

    // ── Choreography ─────────────────────────────────────────────────
    ParallelAnimation {
        id: intro
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation { target: zen; property: "reveal"; from: 0; to: 1; duration: 650; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 280 }
            NumberAnimation { target: zen; property: "uiIn"; from: 0; to: 1; duration: 600; easing.type: Easing.OutCubic }
        }
    }

    ParallelAnimation {
        id: outro
        NumberAnimation { target: zen; property: "uiIn"; to: 0; duration: 220; easing.type: Easing.InQuad }
        SequentialAnimation {
            PauseAnimation { duration: 70 }
            NumberAnimation { target: zen; property: "reveal"; to: 0; duration: 430; easing.type: Easing.InOutCubic }
        }
    }

    SequentialAnimation {
        id: shake
        NumberAnimation { target: zen; property: "shakeX"; to: -12 * zen.sc; duration: 50 }
        NumberAnimation { target: zen; property: "shakeX"; to: 10 * zen.sc; duration: 70 }
        NumberAnimation { target: zen; property: "shakeX"; to: -6 * zen.sc; duration: 70 }
        NumberAnimation { target: zen; property: "shakeX"; to: 3 * zen.sc; duration: 70 }
        NumberAnimation { target: zen; property: "shakeX"; to: 0; duration: 80 }
    }
}
