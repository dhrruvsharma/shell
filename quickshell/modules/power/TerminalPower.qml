pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.lock
import qs.services as Services

// Mainframe: the desktop on a phosphor CRT (a monochrome grade, then the
// Mainframe lock's tube, shaders/lock_crt.frag, over everything), a shell
// prompt that has just run `power`, and the dialog it opened: a box drawn
// in line characters listing what the session can do with the real command
// beside each, the current one in inverse video, < OK > and < Cancel >
// under them, and a tmux status line along the foot. Choosing types the
// command at the prompt and lets systemd talk the machine down (the stop
// log scrolls past), then the tube powers off: a line, a dot, dark.
PowerScene {
    id: scene

    introMs: 820
    outroMs: 300
    riteMs: 3000
    quickMs: 300
    ambient: true
    defaultCurrent: 0

    readonly property string mono: "Iosevka Nerd Font"
    readonly property real fontPx: 20 * sc
    readonly property real lh: Math.round(fontPx * 1.45)
    readonly property real cw: metrics.advanceWidth
    readonly property real margin: 64 * sc

    readonly property color ph: LockTheme.accent
    readonly property color phHi: Qt.lighter(ph, 1.2)
    readonly property color phDim: Qt.rgba(ph.r * 0.55, ph.g * 0.55, ph.b * 0.55, 1)
    readonly property color glass: Qt.rgba(ph.r * 0.035, ph.g * 0.035, ph.b * 0.035, 1)

    readonly property string user: menu.userName
    readonly property string host: menu.hostName || "mainframe"
    readonly property string prompt: user + "@" + host + ":~$ "

    readonly property var names: ["lock", "suspend", "logout", "reboot", "poweroff"]
    readonly property var keyLetters: ["L", "S", "O", "R", "P"]
    readonly property var commands: ["loginctl lock-session", "systemctl suspend", "loginctl terminate-user " + user, "systemctl reboot", "systemctl poweroff"]
    readonly property string typed: chosen >= 0 ? (chosenId === "logout" ? "logout" : commands[chosen]) : ""

    // What systemd says on the way down.
    readonly property var stopLog: [
        ["  OK  ", "Stopped target Graphical Interface."],
        ["  OK  ", "Stopped Session 1 of User " + user + "."],
        ["  OK  ", "Stopped target Sound Card."],
        ["  OK  ", "Stopped Bluetooth service."],
        ["  OK  ", "Stopped Network Manager."],
        ["  OK  ", "Stopped User Manager for UID 1000."],
        ["  OK  ", "Removed slice User Slice of UID 1000."],
        ["  OK  ", "Stopped target Local File Systems."],
        ["  OK  ", "Unmounted /home."],
        ["  OK  ", "Stopped target Swaps."],
        ["  OK  ", "Reached target System Shutdown."],
        ["  OK  ", "Reached target Late Shutdown Services."]
    ]
    readonly property var tailLog: chosenId === "reboot" ? [["  OK  ", "Finished System Reboot."], ["", "Rebooting."]]
        : chosenId === "logout" ? [["", "Connection to " + host + " closed."]]
        : [["  OK  ", "Finished System Power Off."], ["", "Powering off."]]
    readonly property var log: chosenId === "logout" ? [["  OK  ", "Stopped Session 1 of User " + user + "."], ["  OK  ", "Stopped User Manager for UID 1000."]].concat(tailLog) : stopLog.concat(tailLog)

    readonly property bool cursorOn: Math.floor(menu.time * 1.9) % 2 === 0

    function uptime() {
        const m = Math.floor(menu.uptime / 60);
        return Math.floor(m / 60) + ":" + String(m % 60).padStart(2, "0");
    }

    function pad(s, n) {
        return s.length >= n ? s.slice(0, n) : s + " ".repeat(n - s.length);
    }

    function centred(s, n) {
        const left = Math.floor((n - s.length) / 2);
        return pad(" ".repeat(Math.max(0, left)) + s, n);
    }

    TextMetrics {
        id: metrics
        font.family: scene.mono
        font.pixelSize: scene.fontPx
        text: "M"
    }

    // ── The dialog's geometry, in character cells ────────────────────────
    readonly property int boxCols: 62
    readonly property int boxRows: 17
    readonly property real boxW: (boxCols + 2) * cw
    readonly property real boxH: frameLines.length * lh
    readonly property real boxX: Math.round((width - boxW) / 2 / cw) * cw
    readonly property real boxY: Math.round((height * 0.5 - boxH / 2) / lh) * lh
    readonly property int actionRow: 8

    // The dialog's text, a line per row (its border is drawn: line
    // characters only join up at their font's own line height).
    readonly property var frameLines: {
        const body = [
            "",
            "",
            "  " + user + "@" + host + "  ·  up " + uptime() + "  ·  " + Qt.formatDate(menu.now, "ddd d MMM").toLowerCase(),
            "",
            "  What should this session do?",
            "  Arrows move, Enter runs it, Esc backs out.",
            "", "", "", "", "", "", "", "", "", "", "", "", ""
        ];
        return body.map(l => " " + pad(l, boxCols));
    }

    // ── The tube ─────────────────────────────────────────────────────────

    // Dark behind a collapsing picture.
    Rectangle {
        anchors.fill: parent
        visible: scene.chosen >= 0 && !scene.quickChosen
        color: "black"
    }

    Item {
        id: tube
        anchors.fill: parent

        readonly property real squashY: 1 - scene.ease(scene.rite, 0.8, 0.9) * (scene.quickChosen ? 0 : 1)
        readonly property real squashX: 1 - scene.ease(scene.rite, 0.89, 0.97) * (scene.quickChosen ? 0 : 1)

        opacity: scene.quickChosen ? 1 : 1 - scene.lin(scene.rite, 0.97, 1)
        layer.enabled: true
        layer.effect: ShaderEffect {
            property real itemWidth: tube.width
            property real itemHeight: tube.height
            property real crt: scene.ease(scene.intro, 0, 0.55) * 0.85
            property real bloom: scene.ease(scene.intro, 0.1, 0.7) * 0.7
            property real squashX: tube.squashX
            property real squashY: tube.squashY
            property real flash: Math.sin(Math.PI * scene.lin(scene.rite, 0.78, 0.86)) * (scene.quickChosen ? 0 : 1)
            // A tear or two as the tube catches, and again as it dies.
            property real glitch: scene.chosen >= 0 ? Math.sin(Math.PI * scene.lin(scene.rite, 0.76, 0.84)) * (scene.quickChosen ? 0 : 0.8)
                : Math.sin(Math.PI * scene.lin(scene.intro, 0, 0.35)) * 0.6
            property real time: scene.menu.time

            fragmentShader: Qt.resolvedUrl("../../shaders/lock_crt.frag.qsb")
        }

        // The desktop, in phosphor.
        PowerGrade {
            menu: scene.menu
            amount: scene.ease(scene.intro, 0, 0.6)
            saturation: 0
            brightness: 0.5
            contrast: 1.15
            duo: 1
            shadowColor: scene.glass
            lightColor: scene.phDim
            vignette: 0.3
        }

        // The glass behind the prompt darker, so what's typed reads.
        Rectangle {
            width: scene.width * 0.6
            height: scene.height * 0.62
            opacity: scene.seg(scene.intro, 0, 0.4) * 0.85
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: scene.glass }
                GradientStop { position: 1; color: "transparent" }
            }
        }

        // The prompt, and what's run at it.
        Column {
            x: scene.margin
            y: 54 * scene.sc

            readonly property string asked: "power"
            readonly property int askedChars: Math.floor(scene.lin(scene.intro, 0.12, 0.38) * asked.length)

            Text {
                textFormat: Text.StyledText
                font.family: scene.mono
                font.pixelSize: scene.fontPx
                color: scene.ph
                opacity: scene.seg(scene.intro, 0.05, 0.15)
                text: '<font color="' + scene.phHi + '"><b>' + scene.prompt + "</b></font>" + parent.asked.slice(0, parent.askedChars)
                    + (scene.chosen < 0 && parent.askedChars < parent.asked.length && scene.cursorOn ? "█" : "")
            }

            Text {
                visible: scene.chosen >= 0
                textFormat: Text.StyledText
                font.family: scene.mono
                font.pixelSize: scene.fontPx
                color: scene.ph
                readonly property int n: Math.floor(scene.lin(scene.rite, 0.06, scene.quickChosen ? 0.75 : 0.28) * scene.typed.length)
                text: '<font color="' + scene.phHi + '"><b>' + scene.prompt + "</b></font>" + scene.typed.slice(0, n)
                    + (n < scene.typed.length || scene.cursorOn ? "█" : "")
            }

            Repeater {
                model: scene.chosen >= 0 && !scene.quickChosen ? scene.log : []

                Text {
                    required property var modelData
                    required property int index
                    visible: index < Math.floor(scene.lin(scene.rite, 0.32, 0.76) * scene.log.length + 0.5)
                    textFormat: Text.StyledText
                    font.family: scene.mono
                    font.pixelSize: scene.fontPx
                    color: scene.ph
                    text: (modelData[0] ? '<font color="' + scene.phHi + '"><b>[' + modelData[0].replace(/ /g, "&nbsp;") + "]</b></font>&nbsp;" : "") + modelData[1]
                }
            }
        }

        // ── The dialog ───────────────────────────────────────────────────

        Item {
            id: dialog

            // It draws itself a row at a time, and clears at once.
            readonly property int rowsShown: Math.ceil(scene.lin(scene.intro, 0.38, 0.72) * scene.frameLines.length)
            visible: rowsShown > 0 && (scene.chosen < 0 || scene.quickChosen)

            // Its shadow, a cell down and to the right.
            Rectangle {
                x: scene.boxX + scene.cw
                y: scene.boxY + scene.lh
                width: scene.boxW
                height: Math.min(dialog.rowsShown, scene.frameLines.length) * scene.lh
                color: Qt.rgba(0, 0, 0, 0.6)
            }

            Rectangle {
                x: scene.boxX
                y: scene.boxY
                width: scene.boxW
                height: Math.min(dialog.rowsShown, scene.frameLines.length) * scene.lh
                color: Qt.rgba(scene.glass.r, scene.glass.g, scene.glass.b, 0.96)
            }

            Text {
                x: scene.boxX
                y: scene.boxY
                textFormat: Text.PlainText
                lineHeight: scene.lh
                lineHeightMode: Text.FixedHeight
                font.family: scene.mono
                font.pixelSize: scene.fontPx
                color: scene.ph
                text: scene.frameLines.slice(0, dialog.rowsShown).join("\n")
            }

            // Its border, a double line round it and a single one over the
            // buttons, drawn down as far as the rows are.
            Item {
                x: scene.boxX
                y: scene.boxY
                width: scene.boxW
                height: Math.min(dialog.rowsShown, scene.frameLines.length) * scene.lh
                clip: true

                Repeater {
                    model: 2

                    Rectangle {
                        required property int index
                        readonly property real inset: index === 0 ? 0 : 4 * scene.sc
                        x: scene.cw / 2 + inset
                        y: scene.lh / 2 + inset
                        width: scene.boxW - scene.cw - 2 * inset
                        height: scene.boxH - scene.lh - 2 * inset
                        color: "transparent"
                        border.width: 1.5 * scene.sc
                        border.color: index === 0 ? scene.ph : Qt.rgba(scene.ph.r, scene.ph.g, scene.ph.b, 0.45)
                    }
                }

                Rectangle {
                    x: scene.cw / 2
                    y: (scene.frameLines.length - 3.5) * scene.lh
                    width: scene.boxW - scene.cw
                    height: 1.5 * scene.sc
                    color: Qt.rgba(scene.ph.r, scene.ph.g, scene.ph.b, 0.6)
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: scene.lh / 2 - height / 2
                    width: titleText.implicitWidth + 2 * scene.cw
                    height: scene.lh
                    color: Qt.rgba(scene.glass.r, scene.glass.g, scene.glass.b, 1)

                    Text {
                        id: titleText
                        anchors.centerIn: parent
                        textFormat: Text.PlainText
                        font.family: scene.mono
                        font.pixelSize: scene.fontPx
                        font.bold: true
                        color: scene.phHi
                        text: "[ power ]"
                    }
                }
            }

            // The actions, the current one in inverse video.
            Repeater {
                model: scene.actions.length

                Item {
                    id: row

                    required property int index
                    readonly property bool lit: scene.current === index
                    // A lock or sleep blinks its row as it goes.
                    readonly property bool flash: scene.chosen === index && scene.quickChosen && Math.floor(scene.rite * 6) % 2 === 1

                    visible: dialog.rowsShown > scene.actionRow + index
                    x: scene.boxX + scene.cw
                    y: scene.boxY + (scene.actionRow + index) * scene.lh
                    width: scene.boxCols * scene.cw
                    height: scene.lh

                    Rectangle {
                        x: scene.cw
                        width: parent.width - 2 * scene.cw
                        height: parent.height
                        visible: row.lit && !row.flash
                        color: scene.ph
                    }

                    Text {
                        x: scene.cw
                        anchors.verticalCenter: parent.verticalCenter
                        textFormat: Text.StyledText
                        font.family: scene.mono
                        font.pixelSize: scene.fontPx
                        readonly property bool inverse: row.lit && !row.flash
                        color: inverse ? scene.glass : scene.ph
                        text: (inverse ? "" : '<font color="' + scene.phHi + '">') + " [" + scene.keyLetters[row.index] + "]" + (inverse ? "" : "</font>")
                            + "  " + scene.pad(scene.names[row.index], 10).replace(/ /g, "&nbsp;")
                            + (inverse ? "" : '<font color="' + scene.phDim + '">') + scene.commands[row.index] + (inverse ? "" : "</font>")
                    }

                    PowerHit {
                        anchors.fill: parent
                        menu: scene.menu
                        index: row.index
                    }
                }
            }

            // < OK >  < Cancel >
            Row {
                visible: dialog.rowsShown >= scene.frameLines.length - 1
                x: scene.boxX + scene.cw * (1 + Math.floor((scene.boxCols - 28) / 2))
                y: scene.boxY + (scene.frameLines.length - 2.5) * scene.lh
                spacing: scene.cw * 10

                Repeater {
                    model: ["<  OK  >", "< Cancel >"]

                    Rectangle {
                        id: button
                        required property string modelData
                        required property int index
                        readonly property bool lit: index === 0 ? scene.current >= 0 && !cancelHover : cancelHover
                        readonly property bool cancelHover: buttonHit.containsMouse && index === 1
                        width: label.implicitWidth
                        height: scene.lh
                        color: lit ? scene.ph : "transparent"

                        Text {
                            id: label
                            anchors.verticalCenter: parent.verticalCenter
                            textFormat: Text.PlainText
                            font.family: scene.mono
                            font.pixelSize: scene.fontPx
                            font.bold: true
                            color: button.lit ? scene.glass : scene.ph
                            text: button.modelData
                        }

                        MouseArea {
                            id: buttonHit
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: button.index === 0 ? scene.menu.choose(scene.menu.current) : scene.menu.close()
                        }
                    }
                }
            }
        }

        // ── tmux, along the foot ─────────────────────────────────────────

        Rectangle {
            x: 0
            y: scene.height - scene.lh - 10 * scene.sc
            width: scene.width
            height: scene.lh
            color: scene.ph
            opacity: scene.seg(scene.intro, 0.25, 0.5)

            Text {
                x: scene.margin
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                font.family: scene.mono
                font.pixelSize: scene.fontPx
                color: scene.glass
                text: "[0] 0:power*  1:zsh-"
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: scene.margin
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                font.family: scene.mono
                font.pixelSize: scene.fontPx
                color: scene.glass
                text: "\"" + scene.host + "\" " + Qt.formatDateTime(scene.menu.now, "hh:mm dd-MMM-yy")
            }
        }
    }
}
