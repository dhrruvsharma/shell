pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.components
import qs.modules.lock
import qs.modules.lock.themes.arcade
import qs.services as Services

// HUD: the game is paused. The desktop freezes behind a dark, drained
// pause screen with the HUD's dot grid and corner brackets; a pause menu
// with a blinking cursor runs down the left (Resume, then Lock, Sleep,
// Quit to title, Restart, Quit game) and your player card stands on the
// right: level, rank, XP, playtime (the uptime), streak and trophies.
// Choosing plays the arcade's last screens: GAME OVER for a shutdown, a
// CONTINUE? countdown for a restart, "Player 1 has left the game" for a
// log out.
PowerScene {
    id: scene

    introMs: 720
    outroMs: 320
    riteMs: 2500
    quickMs: 300
    ambient: true
    defaultCurrent: 0

    readonly property color accent: LockTheme.accent
    readonly property color ink: LockTheme.ink
    readonly property color base: LockTheme.base
    readonly property color danger: LockTheme.danger
    readonly property string display: "Orbitron"
    readonly property string mono: LockTheme.mono

    readonly property var labels: ["LOCK", "SLEEP", "QUIT TO TITLE", "RESTART", "QUIT GAME"]
    readonly property var keyCaps: ["L", "S", "O", "R", "P"]
    readonly property var blurbs: [
        "Lock the screen. Everything stays as you left it.",
        "Save to memory and rest. Any key wakes it.",
        "End the session and return to the login screen.",
        "Reboot the machine. Continue from the title screen.",
        "Shut down the machine. Thanks for playing!"
    ]

    readonly property bool blink: Math.floor(menu.time * 2.6) % 2 === 0
    readonly property real k: ease(intro, 0, 0.6)

    readonly property real listX: 300 * sc
    readonly property real listY: 452 * sc
    readonly property real rowW: 620 * sc
    readonly property real rowH: 60 * sc
    readonly property real rowStep: 74 * sc

    function clock(s) {
        const t = Math.floor(s);
        const p = n => String(n).padStart(2, "0");
        return p(Math.floor(t / 3600)) + ":" + p(Math.floor(t / 60) % 60) + ":" + p(t % 60);
    }

    // ── The world, paused ────────────────────────────────────────────────

    PowerGrade {
        menu: scene.menu
        amount: scene.k
        saturation: 0.12
        brightness: 0.36
        contrast: 1.05
        tint: 0.08
        tintColor: scene.accent
        vignette: 0.55
        scan: 0.22
        scanPx: 3
    }

    ShaderEffect {
        anchors.fill: parent
        opacity: scene.seg(scene.intro, 0.15, 0.7)

        property real itemWidth: width
        property real itemHeight: height
        property real gridSize: 30 * scene.sc
        property real dotAlpha: 0.2
        property real scanAlpha: 0
        property real tintAlpha: 0
        property real vignette: 0
        property color tintColor: "black"
        property color dotColor: scene.accent

        fragmentShader: Qt.resolvedUrl("../../shaders/lock_backdrop.frag.qsb")
    }

    HudCorners {
        anchors.fill: parent
        size: 64 * scene.sc
        margin: 40 * scene.sc
        thickness: 2.5 * scene.sc
        color: LockTheme.alpha(scene.accent, 0.8)
        enter: scene.seg(scene.intro, 0.1, 0.7) * (1 - scene.aside)
    }

    // ── PAUSED ───────────────────────────────────────────────────────────

    Item {
        id: title

        readonly property real shown: scene.seg(scene.intro, 0.12, 0.62)
        // A flicker as it comes on, like a tube catching.
        readonly property real flicker: scene.intro < 0.5 ? (Math.sin(scene.intro * 90) > -0.2 ? 1 : 0.35) : 1

        x: scene.listX - (1 - shown) * 60 * scene.sc
        y: 238 * scene.sc
        width: 700 * scene.sc
        height: 190 * scene.sc
        opacity: shown * flicker * (1 - scene.aside)

        Text {
            text: "■  GAME PAUSED  ·  " + Qt.formatTime(scene.menu.now, "hh:mm")
            font.family: scene.mono
            font.pixelSize: 14 * scene.sc
            font.weight: Font.Bold
            font.letterSpacing: 4 * scene.sc
            color: scene.accent
        }

        Text {
            id: paused
            y: 22 * scene.sc
            text: "PAUSED"
            font.family: scene.display
            font.pixelSize: 104 * scene.sc
            font.weight: Font.Black
            font.letterSpacing: 10 * scene.sc
            color: scene.ink
        }

        // A ghost of it in the accent, a step out of register.
        Text {
            x: 4 * scene.sc
            y: paused.y + 3 * scene.sc
            z: -1
            text: paused.text
            font: paused.font
            color: LockTheme.alpha(scene.accent, 0.5)
        }

        HudFrame {
            anchors.fill: undefined
            y: paused.y + paused.height + 4 * scene.sc
            width: 300 * scene.sc
            height: 8 * scene.sc
            cut: 4 * scene.sc
            fill: scene.accent
            stroke: "transparent"
            tick: false
        }
    }

    // ── The menu ─────────────────────────────────────────────────────────

    // Resume: what Esc does, at the head of the list.
    Item {
        readonly property real shown: scene.seg(scene.intro, 0.22, 0.66)

        x: scene.listX - (1 - shown) * 80 * scene.sc
        y: scene.listY
        width: scene.rowW
        height: scene.rowH
        opacity: shown * (1 - scene.aside) * 0.75

        HudFrame {
            cut: 12 * scene.sc
            fill: LockTheme.alpha(scene.base, resumeHit.containsMouse ? 0.75 : 0.5)
            stroke: LockTheme.alpha(scene.ink, 0.14)
            tick: false
        }

        Glyph {
            x: 22 * scene.sc
            anchors.verticalCenter: parent.verticalCenter
            text: "play_arrow"
            font.pixelSize: 24 * scene.sc
            color: scene.ink
        }

        Text {
            x: 66 * scene.sc
            anchors.verticalCenter: parent.verticalCenter
            text: "RESUME"
            font.family: scene.display
            font.pixelSize: 21 * scene.sc
            font.weight: Font.Bold
            font.letterSpacing: 4 * scene.sc
            color: scene.ink
        }

        KeyCap {
            anchors.right: parent.right
            anchors.rightMargin: 18 * scene.sc
            anchors.verticalCenter: parent.verticalCenter
            text: "ESC"
        }

        MouseArea {
            id: resumeHit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: scene.menu.close()
        }
    }

    Repeater {
        model: scene.actions.length

        Item {
            id: row

            required property int index
            readonly property bool lit: scene.current === index
            readonly property bool picked: scene.chosen === index
            readonly property bool bad: index === 4
            readonly property color hue: bad ? scene.danger : scene.accent
            readonly property real shown: scene.seg(scene.intro, 0.27 + index * 0.05, 0.7 + index * 0.05)
            // A lock or sleep blinks the row three times before the menu goes.
            readonly property bool flashing: picked && scene.quickChosen && Math.floor(scene.rite * 6) % 2 === 1

            property real on: lit ? 1 : 0
            Behavior on on {
                NumberAnimation {
                    duration: 140
                }
            }

            x: scene.listX - (1 - shown) * 80 * scene.sc + on * 14 * scene.sc
            y: scene.listY + (index + 1) * scene.rowStep
            width: scene.rowW
            height: scene.rowH
            opacity: shown * (picked && scene.quickChosen ? 1 : 1 - scene.aside)

            HudFrame {
                cut: 12 * scene.sc
                fill: row.flashing ? row.hue : Qt.tint(LockTheme.alpha(scene.base, 0.6), LockTheme.alpha(row.hue, 0.2 * row.on))
                stroke: LockTheme.alpha(row.on > 0.5 ? row.hue : scene.ink, 0.14 + 0.66 * row.on)
                tickColor: row.hue
                tick: row.on > 0.5
            }

            // A shine running along the lit row.
            Rectangle {
                visible: row.lit
                x: 12 * scene.sc + ((scene.menu.time * 0.6) % 1.4) * (row.width - 24 * scene.sc) - 80 * scene.sc
                y: 1
                width: 80 * scene.sc
                height: row.height - 2
                opacity: 0.18
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 0.5; color: row.hue }
                    GradientStop { position: 1; color: "transparent" }
                }
            }

            // The cursor.
            Text {
                x: -34 * scene.sc
                anchors.verticalCenter: parent.verticalCenter
                visible: row.lit && (scene.blink || scene.chosen >= 0)
                text: "▶"
                font.pixelSize: 22 * scene.sc
                color: row.hue
            }

            Glyph {
                x: 22 * scene.sc
                anchors.verticalCenter: parent.verticalCenter
                text: scene.actions[row.index].icon
                filled: row.lit
                font.pixelSize: 24 * scene.sc
                color: row.flashing ? scene.base : row.lit ? row.hue : LockTheme.alpha(scene.ink, 0.8)
            }

            Text {
                x: 66 * scene.sc
                anchors.verticalCenter: parent.verticalCenter
                text: scene.labels[row.index]
                font.family: scene.display
                font.pixelSize: 21 * scene.sc
                font.weight: Font.Bold
                font.letterSpacing: 4 * scene.sc
                color: row.flashing ? scene.base : row.lit ? Qt.lighter(row.hue, 1.25) : LockTheme.alpha(scene.ink, 0.88)
            }

            KeyCap {
                anchors.right: parent.right
                anchors.rightMargin: 18 * scene.sc
                anchors.verticalCenter: parent.verticalCenter
                text: scene.keyCaps[row.index]
                hue: row.lit ? row.hue : scene.ink
            }

            PowerHit {
                anchors.fill: parent
                menu: scene.menu
                index: row.index
            }
        }
    }

    // What the lit one does.
    Text {
        x: scene.listX + 4 * scene.sc
        y: scene.listY + 6 * scene.rowStep + 16 * scene.sc
        opacity: scene.seg(scene.intro, 0.55, 0.95) * (1 - scene.aside) * (scene.current >= 0 ? 1 : 0)
        text: "▸ " + (scene.blurbs[Math.max(0, scene.current)] ?? "")
        font.family: scene.mono
        font.pixelSize: 15 * scene.sc
        color: LockTheme.alpha(scene.ink, 0.7)
    }

    // ── Player card ──────────────────────────────────────────────────────

    Item {
        id: card

        readonly property real shown: scene.seg(scene.intro, 0.35, 0.9)
        readonly property int level: Services.LockStats.level
        readonly property int floorXp: Services.LockStats.xpForLevel(level)
        readonly property int ceilXp: Services.LockStats.xpForLevel(level + 1)
        readonly property real fill: Math.max(0, Math.min(1, (Services.LockStats.xp - floorXp) / Math.max(1, ceilXp - floorXp)))

        x: 1160 * scene.sc + (1 - shown) * 90 * scene.sc
        y: 300 * scene.sc
        width: 460 * scene.sc
        height: 590 * scene.sc
        opacity: shown * (1 - scene.aside)

        HudFrame {
            cut: 22 * scene.sc
            fill: LockTheme.alpha(scene.base, 0.66)
            stroke: LockTheme.alpha(scene.accent, 0.4)
            tickColor: scene.accent
        }

        Column {
            x: 34 * scene.sc
            y: 30 * scene.sc
            width: parent.width - 68 * scene.sc
            spacing: 18 * scene.sc

            Text {
                text: "PLAYER 1"
                font.family: scene.mono
                font.pixelSize: 13 * scene.sc
                font.weight: Font.Bold
                font.letterSpacing: 4 * scene.sc
                color: scene.accent
            }

            Row {
                spacing: 22 * scene.sc

                Item {
                    width: 112 * scene.sc
                    height: width

                    PowerAvatar {
                        anchors.fill: parent
                        radius: 0
                    }

                    HudFrame {
                        cut: 14 * scene.sc
                        fill: "transparent"
                        stroke: scene.accent
                        strokeWidth: 2 * scene.sc
                        tickColor: scene.accent
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8 * scene.sc

                    Text {
                        text: scene.menu.userName.toUpperCase()
                        font.family: scene.display
                        font.pixelSize: 30 * scene.sc
                        font.weight: Font.Bold
                        font.letterSpacing: 3 * scene.sc
                        color: scene.ink
                    }

                    Text {
                        text: "LV " + card.level + "  ·  " + Services.LockStats.rank.toUpperCase()
                        font.family: scene.mono
                        font.pixelSize: 14 * scene.sc
                        font.weight: Font.Bold
                        font.letterSpacing: 2 * scene.sc
                        color: scene.accent
                    }
                }
            }

            // XP, in segments.
            Column {
                width: parent.width
                spacing: 8 * scene.sc

                Row {
                    spacing: 4 * scene.sc

                    Repeater {
                        model: 20

                        Rectangle {
                            required property int index
                            width: (card.width - 68 * scene.sc - 19 * 4 * scene.sc) / 20
                            height: 12 * scene.sc
                            color: (index + 0.5) / 20 <= card.fill ? scene.accent : LockTheme.alpha(scene.ink, 0.12)
                        }
                    }
                }

                Text {
                    text: "XP " + Services.LockStats.xp + " / " + card.ceilXp
                    font.family: scene.mono
                    font.pixelSize: 12 * scene.sc
                    font.letterSpacing: 2 * scene.sc
                    color: LockTheme.alpha(scene.ink, 0.6)
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: LockTheme.alpha(scene.ink, 0.12)
            }

            Repeater {
                model: [
                    ["PLAYTIME", scene.clock(scene.menu.uptime)],
                    ["STAGE", Qt.formatDate(scene.menu.now, "ddd d MMM").toUpperCase()],
                    ["STREAK", Services.LockStats.liveStreak + (Services.LockStats.liveStreak === 1 ? " DAY" : " DAYS")],
                    ["TROPHIES", Services.LockStats.unlockedDefs.length + " / " + Services.LockStats.achievementDefs.length]
                ]

                Item {
                    id: stat
                    required property var modelData
                    width: parent.width
                    height: 22 * scene.sc

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: stat.modelData[0]
                        font.family: scene.mono
                        font.pixelSize: 13 * scene.sc
                        font.letterSpacing: 3 * scene.sc
                        color: LockTheme.alpha(scene.ink, 0.55)
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: stat.modelData[1]
                        font.family: scene.mono
                        font.pixelSize: 15 * scene.sc
                        font.weight: Font.Bold
                        color: scene.ink
                    }
                }
            }
        }
    }

    // ── Controls ─────────────────────────────────────────────────────────

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.height - 112 * scene.sc
        spacing: 34 * scene.sc
        opacity: scene.seg(scene.intro, 0.6, 1) * (1 - scene.aside) * 0.85

        Repeater {
            model: [["↑↓", "SELECT"], ["ENTER", "CONFIRM"], ["ESC", "RESUME"]]

            Row {
                id: hint
                required property var modelData
                spacing: 10 * scene.sc

                KeyCap {
                    anchors.verticalCenter: parent.verticalCenter
                    text: hint.modelData[0]
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: hint.modelData[1]
                    font.family: scene.mono
                    font.pixelSize: 13 * scene.sc
                    font.weight: Font.Bold
                    font.letterSpacing: 3 * scene.sc
                    color: LockTheme.alpha(scene.ink, 0.7)
                }
            }
        }
    }

    // ── The last screens ─────────────────────────────────────────────────

    Rectangle {
        anchors.fill: parent
        visible: scene.chosen >= 0 && !scene.quickChosen
        color: "black"
        opacity: scene.ease(scene.rite, 0, 0.22) * 0.9
    }

    // GAME OVER, a letter at a time.
    Column {
        anchors.centerIn: parent
        visible: scene.chosenId === "poweroff"
        spacing: 26 * scene.sc

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6 * scene.sc

            Repeater {
                model: "GAME OVER".split("")

                Text {
                    required property string modelData
                    required property int index
                    text: modelData
                    opacity: scene.rite > 0.12 + index * 0.035 ? 1 : 0
                    font.family: scene.display
                    font.pixelSize: 132 * scene.sc
                    font.weight: Font.Black
                    font.letterSpacing: 12 * scene.sc
                    color: Qt.hsla(0.995, 0.9, 0.6, 1)
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: scene.seg(scene.rite, 0.5, 0.7)
            text: "THANKS FOR PLAYING, " + scene.menu.userName.toUpperCase()
            font.family: scene.mono
            font.pixelSize: 20 * scene.sc
            font.weight: Font.Bold
            font.letterSpacing: 6 * scene.sc
            color: scene.ink
        }

        SaveBar {
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: scene.seg(scene.rite, 0.6, 0.75)
            label: "SAVING PROGRESS"
            fill: scene.lin(scene.rite, 0.62, 0.96)
        }
    }

    // CONTINUE? 3, 2, 1.
    Column {
        anchors.centerIn: parent
        visible: scene.chosenId === "reboot"
        spacing: 18 * scene.sc

        readonly property int count: scene.rite < 0.32 ? 3 : scene.rite < 0.52 ? 3 - Math.floor((scene.rite - 0.32) / 0.1) : scene.rite < 0.62 ? 1 : 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: scene.seg(scene.rite, 0.1, 0.25)
            text: "CONTINUE?"
            font.family: scene.display
            font.pixelSize: 96 * scene.sc
            font.weight: Font.Black
            font.letterSpacing: 10 * scene.sc
            color: scene.accent
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: scene.rite > 0.2 && scene.rite < 0.68 ? 1 : 0
            text: String(Math.max(1, parent.count))
            font.family: scene.display
            font.pixelSize: 150 * scene.sc
            font.weight: Font.Black
            color: scene.ink
            // each number lands big and settles
            scale: 1 + 0.25 * (1 - scene.seg(((scene.rite - 0.2) % 0.16) / 0.16, 0, 0.4))
        }

        SaveBar {
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: scene.seg(scene.rite, 0.68, 0.8)
            label: "LOADING"
            fill: scene.lin(scene.rite, 0.7, 0.98)
        }
    }

    // Player 1 has left the game.
    Column {
        anchors.centerIn: parent
        visible: scene.chosenId === "logout"
        spacing: 40 * scene.sc

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: scene.seg(scene.rite, 0.12, 0.35)
            text: "PLAYER 1 HAS LEFT THE GAME"
            font.family: scene.display
            font.pixelSize: 54 * scene.sc
            font.weight: Font.Black
            font.letterSpacing: 6 * scene.sc
            color: scene.ink
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: scene.rite > 0.5 && (scene.blink || scene.rite < 0.6) ? 1 : 0
            text: "PRESS START"
            font.family: scene.mono
            font.pixelSize: 24 * scene.sc
            font.weight: Font.Bold
            font.letterSpacing: 8 * scene.sc
            color: scene.accent
        }
    }

    // ── Pieces ───────────────────────────────────────────────────────────

    component KeyCap: Item {
        id: cap

        property string text
        property color hue: scene.ink

        width: Math.max(30 * scene.sc, capText.implicitWidth + 16 * scene.sc)
        height: 26 * scene.sc

        HudFrame {
            cut: 5 * scene.sc
            fill: LockTheme.alpha(cap.hue, 0.08)
            stroke: LockTheme.alpha(cap.hue, 0.5)
            tick: false
        }

        Text {
            id: capText
            anchors.centerIn: parent
            text: cap.text
            font.family: scene.mono
            font.pixelSize: 12 * scene.sc
            font.weight: Font.Bold
            color: cap.hue
        }
    }

    component SaveBar: Column {
        id: bar

        property string label
        property real fill: 0

        spacing: 10 * scene.sc

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: bar.label + (scene.blink ? " ..." : "")
            font.family: scene.mono
            font.pixelSize: 14 * scene.sc
            font.weight: Font.Bold
            font.letterSpacing: 4 * scene.sc
            color: LockTheme.alpha(scene.ink, 0.75)
        }

        Row {
            spacing: 5 * scene.sc

            Repeater {
                model: 16

                Rectangle {
                    required property int index
                    width: 18 * scene.sc
                    height: 14 * scene.sc
                    color: (index + 1) / 16 <= bar.fill ? scene.accent : LockTheme.alpha(scene.ink, 0.12)
                }
            }
        }
    }
}
