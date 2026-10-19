pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.colors
import qs.modules.lock.themes.newspaper

// Broadsheet: a late front page lands on the desk. Under the masthead and
// the dateline, STOP THE PRESSES! runs across the top; the photograph is
// the desktop as it was, printed in four-colour halftone (shaders/
// desktop_press.frag); and down the side run the night's five stories, one
// for each thing the machine can do: Desk left unattended (lock), City
// sleeps (sleep), Resident signs off (log out), Second edition rolls
// (restart), Presses halted (shut down). Pointing at one rules a box round
// it with a hand in the margin. Choosing one stamps it in the spot colour,
// then the page spins away; a restart spins an EXTRA in after it, the others
// leave -30-, the end of the story.
PowerScene {
    id: scene

    introMs: 950
    outroMs: 360
    riteMs: 3000
    quickMs: 300
    ambient: true

    readonly property var heads: ["DESK LEFT UNATTENDED", "CITY SLEEPS", "RESIDENT SIGNS OFF", "SECOND EDITION ROLLS", "PRESSES HALTED"]
    readonly property var deks: [
        "Owner steps away; screen locked tight, sources confirm.",
        "Machine dozes off, expected to stir at a keystroke.",
        "“See you tomorrow,” " + cap(menu.userName) + " tells reporters on the way out.",
        "A fresh start for the machine; back in minutes, editors say.",
        "Lights out at the plant as the night shift is sent home."
    ]
    readonly property var stamps: ["HOLD", "AFTER HOURS", "FILED", "REPRINT", "-30-"]
    readonly property var actionWords: ["lock", "sleep", "log out", "restart", "shut down"]

    readonly property real pageW: 1500 * sc
    readonly property real pageH: 1050 * sc
    readonly property real margin: 56 * sc

    readonly property real desk: ease(intro, 0, 0.6)
    readonly property real landed: ease(intro, 0.1, 0.75)
    // The page spinning away, and an EXTRA spinning in after a restart.
    readonly property real away: quickChosen ? 0 : ease(rite, 0.32, 0.72)
    readonly property real extra: chosenId === "reboot" ? ease(rite, 0.66, 0.96) : 0

    // ── The desk ─────────────────────────────────────────────────────────

    PowerGrade {
        menu: scene.menu
        amount: scene.desk
        saturation: 0.25
        brightness: 0.32
        vignette: 0.6
    }

    Rectangle {
        anchors.fill: parent
        color: "#0d0c0b"
        opacity: scene.away * 0.9
    }

    // ── The page ─────────────────────────────────────────────────────────

    Item {
        id: page

        x: (scene.width - width) / 2
        y: (scene.height - height) / 2 + 8 * scene.sc
        width: scene.pageW
        height: scene.pageH
        opacity: scene.landed * (1 - scene.lin(scene.rite, 0.62, 0.72) * (scene.quickChosen ? 0 : 1))
        scale: (1.12 - 0.12 * scene.landed) * (1 - 0.94 * scene.away)
        rotation: -0.8 - 3 * (1 - scene.landed) + 900 * scene.away * scene.away

        // Its hard shadow on the desk, as the clippings have.
        Rectangle {
            x: 10 * scene.sc
            y: 10 * scene.sc
            width: parent.width
            height: parent.height
            color: Colors.withAlpha("black", 0.5)
        }

        Rectangle {
            anchors.fill: parent
            color: Press.paper
        }

        // ── Head of the page ─────────────────────────────────────────────

        Text {
            x: scene.margin
            y: 34 * scene.sc
            width: 230 * scene.sc
            text: Press.edition(scene.menu.now) + "\nWEATHER: " + (scene.menu.now.getHours() < 18 ? "FAIR" : "CLEAR NIGHT")
            font.family: Press.body
            font.pixelSize: 12 * scene.sc
            font.bold: true
            font.letterSpacing: 1 * scene.sc
            lineHeight: 1.2
            color: Press.ink
        }

        Text {
            x: page.width - scene.margin - width
            y: 34 * scene.sc
            width: 230 * scene.sc
            horizontalAlignment: Text.AlignRight
            text: "PRICE: ONE KEYSTROKE\nLATE CITY FINAL"
            font.family: Press.body
            font.pixelSize: 12 * scene.sc
            font.bold: true
            font.letterSpacing: 1 * scene.sc
            lineHeight: 1.2
            color: Press.ink
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 18 * scene.sc
            text: Press.paperName(scene.menu.userName)
            font.family: Press.masthead
            font.pixelSize: 82 * scene.sc
            font.weight: Font.Black
            font.italic: true
            color: Press.ink
        }

        Rule {
            y: 128 * scene.sc
            heavy: true
        }

        Text {
            x: scene.margin
            y: 136 * scene.sc
            width: page.width - 2 * scene.margin
            horizontalAlignment: Text.AlignHCenter
            text: Press.volume(scene.menu.now) + "  ·  " + Press.number(scene.menu.now) + "  ·  " + Press.dateline(scene.menu.now) + "  ·  " + Press.time(scene.menu.now).toUpperCase()
            font.family: Press.body
            font.pixelSize: 13 * scene.sc
            font.bold: true
            font.letterSpacing: 1.5 * scene.sc
            color: Press.ink
        }

        Rule {
            y: 160 * scene.sc
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 168 * scene.sc
            text: "STOP THE PRESSES!"
            font.family: Press.headline
            font.pixelSize: 118 * scene.sc
            font.letterSpacing: 2 * scene.sc
            color: Press.ink
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 330 * scene.sc
            text: "Machine awaits its orders as five stories break at once; the desk to decide"
            font.family: Press.body
            font.pixelSize: 22 * scene.sc
            font.italic: true
            color: Press.inkSoft
        }

        Rule {
            y: 372 * scene.sc
        }

        // ── The photograph ───────────────────────────────────────────────

        Item {
            id: photo
            x: scene.margin
            y: 392 * scene.sc
            width: 840 * scene.sc
            height: 525 * scene.sc

            ShaderEffect {
                anchors.fill: parent
                visible: scene.menu.hasWorld

                property variant source: scene.menu.world
                property real itemWidth: width
                property real itemHeight: height
                property real press: scene.seg(scene.intro, 0.35, 0.95)
                property real cell: Math.max(2.2, 4 * scene.sc)
                property real fold: 0
                property color paperColor: Press.paper

                fragmentShader: Qt.resolvedUrl("../../shaders/desktop_press.frag.qsb")
            }

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: Math.max(1, scene.sc)
                border.color: Press.ink
            }
        }

        Text {
            x: photo.x
            y: photo.y + photo.height + 10 * scene.sc
            width: photo.width
            text: "THE DESKTOP, MOMENTS AGO. — Everything as " + scene.cap(scene.menu.userName) + " left it, up " + scene.uptimeText(scene.menu.uptime) + ". (Staff photograph)"
            wrapMode: Text.WordWrap
            font.family: Press.body
            font.pixelSize: 14 * scene.sc
            font.italic: true
            color: Press.inkSoft
        }

        // A column rule between the photograph and the stories.
        Rectangle {
            x: photo.x + photo.width + 26 * scene.sc
            y: photo.y
            width: Math.max(1, scene.sc)
            height: 600 * scene.sc
            color: Press.ink
        }
    }

    // ── The stories ──────────────────────────────────────────────────────

    // Laid out in the page's coordinates, then carried round with it.
    Item {
        id: stories

        x: page.x
        y: page.y
        width: page.width
        height: page.height
        opacity: page.opacity
        scale: page.scale
        rotation: page.rotation

        Repeater {
            model: scene.actions.length

            Item {
                id: story

                required property int index
                readonly property bool lit: scene.current === index
                readonly property bool picked: scene.chosen === index
                readonly property real colX: scene.margin + 840 * scene.sc + 54 * scene.sc

                property real ruled: lit || picked ? 1 : 0
                Behavior on ruled {
                    NumberAnimation {
                        duration: 160
                    }
                }
                // The stamp slamming down.
                readonly property real slam: picked ? scene.lin(scene.rite, 0.04, scene.quickChosen ? 0.45 : 0.16) : 0

                x: colX
                y: 392 * scene.sc + index * 122 * scene.sc
                width: stories.width - colX - scene.margin
                height: 108 * scene.sc

                // A box ruled round it in the spot colour.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -8 * scene.sc
                    color: Colors.withAlpha(Press.spotInk, 0.06 * story.ruled)
                    border.width: 2 * scene.sc
                    border.color: Colors.withAlpha(Press.spotInk, story.ruled)
                }

                // And a hand in the margin.
                Text {
                    x: -46 * scene.sc
                    anchors.verticalCenter: parent.verticalCenter
                    visible: story.ruled > 0.5
                    text: "☛"
                    font.pixelSize: 36 * scene.sc
                    color: Press.spotInk
                }

                Column {
                    width: parent.width
                    spacing: 4 * scene.sc

                    Text {
                        width: parent.width
                        text: scene.heads[story.index]
                        elide: Text.ElideRight
                        font.family: Press.headline
                        font.pixelSize: 31 * scene.sc
                        font.letterSpacing: 0.5 * scene.sc
                        color: Press.ink
                    }

                    Text {
                        width: parent.width
                        text: scene.deks[story.index]
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        font.family: Press.body
                        font.pixelSize: 15 * scene.sc
                        color: Press.inkSoft
                    }

                    Text {
                        text: "— " + scene.actionWords[story.index].toUpperCase() + ", PAGE A" + (story.index + 1)
                        font.family: Press.body
                        font.pixelSize: 11 * scene.sc
                        font.bold: true
                        font.letterSpacing: 1.5 * scene.sc
                        color: story.ruled > 0.5 ? Press.spotInk : Press.inkFaint
                    }
                }

                // The rule under each but the last.
                Rectangle {
                    visible: story.index < 4
                    y: parent.height + 6 * scene.sc
                    width: parent.width
                    height: Math.max(1, scene.sc)
                    color: Colors.withAlpha(Press.ink, 0.5)
                }

                // The stamp.
                Item {
                    anchors.centerIn: parent
                    width: stampText.implicitWidth + 36 * scene.sc
                    height: stampText.implicitHeight + 10 * scene.sc
                    visible: story.slam > 0
                    rotation: -9
                    scale: 1 + 0.9 * Math.pow(1 - story.slam, 2)
                    opacity: Math.min(1, story.slam * 3) * 0.92

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        radius: 6 * scene.sc
                        border.width: 4 * scene.sc
                        border.color: Press.spotInk
                    }

                    Text {
                        id: stampText
                        anchors.centerIn: parent
                        text: scene.stamps[story.index]
                        font.family: Press.headline
                        font.pixelSize: 44 * scene.sc
                        font.letterSpacing: 3 * scene.sc
                        color: Press.spotInk
                    }
                }

                PowerHit {
                    anchors.fill: parent
                    anchors.margins: -8 * scene.sc
                    menu: scene.menu
                    index: story.index
                }
            }
        }

        Text {
            x: page.width - scene.margin - width
            y: page.height - 44 * scene.sc
            text: "Esc to hold the front page  ·  continued on page A2"
            font.family: Press.body
            font.pixelSize: 14 * scene.sc
            font.italic: true
            color: Press.inkSoft
        }
    }

    // ── -30- ─────────────────────────────────────────────────────────────

    Column {
        anchors.centerIn: parent
        visible: scene.chosen >= 0 && !scene.quickChosen && scene.chosenId !== "reboot"
        opacity: scene.seg(scene.rite, 0.74, 0.96)
        spacing: 14 * scene.sc

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "— 30 —"
            font.family: Press.body
            font.pixelSize: 54 * scene.sc
            font.bold: true
            color: Press.paper
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: scene.chosenId === "poweroff" ? "Good night from the newsroom." : scene.cap(scene.menu.userName) + " has signed off for the day."
            font.family: Press.body
            font.pixelSize: 19 * scene.sc
            font.italic: true
            color: Colors.withAlpha(Press.paper, 0.75)
        }
    }

    // ── EXTRA! ───────────────────────────────────────────────────────────

    Item {
        anchors.centerIn: parent
        width: 980 * scene.sc
        height: 640 * scene.sc
        visible: scene.extra > 0
        scale: 0.06 + 0.94 * scene.extra
        rotation: -720 * (1 - scene.extra) * (1 - scene.extra) + 2

        Rectangle {
            x: 10 * scene.sc
            y: 10 * scene.sc
            width: parent.width
            height: parent.height
            color: Colors.withAlpha("black", 0.5)
        }

        Rectangle {
            anchors.fill: parent
            color: Press.paper
        }

        Column {
            anchors.centerIn: parent
            spacing: 6 * scene.sc

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Press.paperName(scene.menu.userName)
                font.family: Press.masthead
                font.pixelSize: 44 * scene.sc
                font.weight: Font.Black
                font.italic: true
                color: Press.ink
            }

            Rectangle {
                width: 860 * scene.sc
                height: 3 * scene.sc
                color: Press.ink
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "EXTRA!"
                font.family: Press.headline
                font.pixelSize: 170 * scene.sc
                color: Press.spotInk
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "MACHINE RESTARTS"
                font.family: Press.headline
                font.pixelSize: 84 * scene.sc
                color: Press.ink
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Back on the street in minutes, editors promise"
                font.family: Press.body
                font.pixelSize: 22 * scene.sc
                font.italic: true
                color: Press.inkSoft
            }
        }
    }

    component Rule: Item {
        property bool heavy: false

        x: scene.margin
        width: scene.pageW - 2 * scene.margin
        height: heavy ? 7 * scene.sc : 2 * scene.sc

        Rectangle {
            width: parent.width
            height: parent.heavy ? 4 * scene.sc : Math.max(1, 1.5 * scene.sc)
            color: Press.ink
        }

        Rectangle {
            visible: parent.heavy
            y: 5.5 * scene.sc
            width: parent.width
            height: Math.max(1, scene.sc)
            color: Press.ink
        }
    }
}
