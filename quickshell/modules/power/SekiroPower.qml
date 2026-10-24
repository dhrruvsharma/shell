pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.components
import qs.modules.lock
import qs.modules.lock.themes.sekiro
import qs.services as Services

// Sekiro: resting at a Sculptor's Idol. Night falls on the desktop (the
// Deathblow lock's moonlight, shaders/lock_ashina.frag), the silver grass
// rises along the foot and the season drifts down; the idol sits on the
// right, its mandorla of light brightening as you commune with it, and on
// the left, as the game lays out its idol menu, the idol's name over five
// things to do: Rest (lock), Meditate (sleep), Return (log out: the ending
// where the Divine Heir goes home to the West), Resurrect (restart) and
// Immortal Severance (shut down). The one pointed at is struck through
// with a swash of crimson ink. Under them, the shinobi: resurrection nodes,
// vitality (the battery), how long he has gone undying (the uptime), his
// rank and skill experience.
//
// Returning closes the night in from the edges round 竜の帰郷; resurrecting
// takes the colour out of the world and writes 回生 over it, white, as it
// comes back; severing cuts the screen through with a stroke of blood and
// writes 不死断ち as the world goes dark.
PowerScene {
    id: scene

    introMs: 950
    outroMs: 380
    riteMs: 3000
    quickMs: 320
    ambient: true

    readonly property var names: ["Rest", "Meditate", "Return", "Resurrect", "Immortal Severance"]
    readonly property var glosses: ["lock", "sleep", "log out", "restart", "shut down"]
    readonly property var ceremonies: ({
        logout: { kanji: "竜の帰郷", word: "RETURN", line: "the Divine Heir goes home to the West" },
        reboot: { kanji: Shinobi.resurrection, word: "RESURRECTION", line: "shadows die twice" },
        poweroff: { kanji: "不死断ち", word: "IMMORTAL SEVERANCE", line: "hesitation is defeat" }
    })

    readonly property var stretch: Shinobi.stretch(menu.now)
    readonly property var season: Shinobi.season(menu.now)
    readonly property var tints: [["#f7cbd6", "#e98aa8"], ["#e4ff9a", "#fff4bf"], ["#de5a2c", "#a3221a"], ["#f4f7fb", "#c9d3e2"]][season.fall]

    readonly property bool hasBattery: Services.Battery.percentage > 0 || Services.Battery.charging
    readonly property real vitality: hasBattery ? Math.max(0, Math.min(1, Services.Battery.percentage / 100)) : 1

    readonly property real nightfall: ease(intro, 0, 0.8)
    // The ceremonies' parts.
    readonly property real returning: chosenId === "logout" ? ease(rite, 0.15, 0.9) : 0
    readonly property real dying: chosenId === "reboot" ? ease(rite, 0.05, 0.4) * (1 - ease(rite, 0.55, 0.9)) : chosenId === "poweroff" ? ease(rite, 0.25, 0.75) : 0
    readonly property real cutting: chosenId === "poweroff" ? lin(rite, 0.06, 0.2) : 0
    readonly property real flash: chosenId === "poweroff" ? Math.max(0, 1 - Math.abs(rite - 0.12) / 0.08) * 0.75 : 0
    readonly property real writing: chosenId === "logout" ? seg(rite, 0.3, 0.7) : chosenId === "reboot" ? seg(rite, 0.3, 0.6) : chosenId === "poweroff" ? seg(rite, 0.35, 0.7) : 0
    readonly property real dark: chosenId === "poweroff" ? ease(rite, 0.78, 0.98) : chosenId === "reboot" ? ease(rite, 0.88, 0.99) : 0
    readonly property real glow: 0.45 + 0.25 * Math.sin(menu.time * 1.6) * 0.5 + (current >= 0 ? 0.2 : 0) + (quickChosen ? 0.6 * Math.sin(Math.PI * rite) : 0)

    // ── Night at the idol ────────────────────────────────────────────────
    ShaderEffect {
        anchors.fill: parent
        opacity: scene.menu.hasWorld ? 1 : scene.nightfall

        property variant source: scene.menu.world
        property real itemWidth: width
        property real itemHeight: height
        property real night: scene.nightfall
        property real death: scene.dying
        property real hurt: 0
        property real flash: scene.flash
        property point moonPos: Qt.point(scene.width * 0.8, scene.height * 0.24)
        property real moonR: 104 * scene.sc
        property color moonColor: Shinobi.moon
        property color bloodColor: Shinobi.kanji

        fragmentShader: Qt.resolvedUrl("../../shaders/lock_ashina.frag.qsb")
    }

    // The season falling.
    ShaderEffect {
        anchors.fill: parent
        visible: scene.nightfall > 0

        property real itemWidth: width
        property real itemHeight: height
        property real boot: scene.nightfall
        property real lineScale: 1
        property real fall: scene.season.fall
        property real drift: scene.menu.time * 30 * scene.sc
        property real chrome: 0
        property real unit: scene.sc
        property color mistColor: Shinobi.moon
        property color tintA: scene.tints[0]
        property color tintB: scene.tints[1]

        fragmentShader: Qt.resolvedUrl("../../shaders/desktop_sekiro.frag.qsb")
    }

    // The silver grass.
    ShaderEffect {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * 0.22
        visible: scene.nightfall > 0

        property real itemWidth: width
        property real itemHeight: height
        property real time: scene.menu.time
        property real rise: scene.seg(scene.intro, 0.25, 1)
        property real wind: 1
        property real gust: scene.chosenId === "poweroff" ? -Math.sin(Math.PI * scene.lin(scene.rite, 0.1, 0.5)) : 0
        property real unit: scene.sc
        property color stalkColor: "#0a0d14"
        property color plumeColor: "#9aa5b8"

        fragmentShader: Qt.resolvedUrl("../../shaders/susuki.frag.qsb")
    }

    // ── The idol ─────────────────────────────────────────────────────────
    Idol {
        x: scene.width * 0.66 - width / 2
        y: scene.height * 0.74 - height
        width: 300 * scene.sc
        height: 390 * scene.sc
        opacity: scene.seg(scene.intro, 0.3, 0.85) * (1 - scene.aside * 0.5)
        glow: Math.min(1, scene.glow)
        transform: Translate { y: (1 - scene.seg(scene.intro, 0.3, 0.85)) * 30 * scene.sc }
    }

    // ── The idol's menu, on the left ─────────────────────────────────────
    Rectangle {
        width: scene.width * 0.44
        height: scene.height
        opacity: scene.seg(scene.intro, 0.1, 0.7) * (1 - scene.aside)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Shinobi.alpha("#050407", 0.86) }
            GradientStop { position: 0.6; color: Shinobi.alpha("#050407", 0.6) }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    Column {
        id: menuColumn
        x: 120 * scene.sc
        y: scene.height * 0.16
        spacing: 0
        opacity: scene.seg(scene.intro, 0.3, 0.9) * (1 - scene.aside)
        transform: Translate { x: -(1 - scene.seg(scene.intro, 0.3, 0.9)) * 40 * scene.sc }

        Text {
            text: Shinobi.idolKanji + "  Sculptor's Idol"
            font.family: Shinobi.book
            font.pixelSize: 19 * scene.sc
            font.letterSpacing: 2 * scene.sc
            color: Shinobi.gold
        }

        Text {
            text: scene.stretch.idol
            font.family: Shinobi.display
            font.pixelSize: 50 * scene.sc
            color: Shinobi.ivory
        }

        Text {
            text: scene.stretch.area + "  ·  " + scene.stretch.deed
            font.family: Shinobi.book
            font.pixelSize: 18 * scene.sc
            color: Shinobi.landLight
        }

        Item {
            width: 1
            height: 18 * scene.sc
        }

        Rectangle {
            width: 520 * scene.sc
            height: 1
            color: Shinobi.alpha(Shinobi.gold, 0.45)
        }

        Item {
            width: 1
            height: 26 * scene.sc
        }

        Repeater {
            model: scene.actions.length

            Item {
                id: row
                required property int index
                readonly property bool lit: scene.current === row.index
                readonly property bool picked: scene.chosen === row.index
                width: 560 * scene.sc
                height: 74 * scene.sc

                property real stroke: lit || picked ? 1 : 0
                Behavior on stroke {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutCubic
                    }
                }

                BrushStroke {
                    x: -26 * scene.sc
                    y: (row.height - height) / 2 - 6 * scene.sc
                    width: 520 * scene.sc
                    height: 56 * scene.sc
                    visible: row.stroke > 0
                    reveal: row.stroke
                    ink: Shinobi.alpha(Shinobi.kanji, 0.7)
                    seed: row.index + 1
                    dry: 0.8
                    weight: 0.8
                }

                Text {
                    id: name
                    y: (row.height - height) / 2 - 8 * scene.sc
                    text: scene.names[row.index]
                    font.family: Shinobi.display
                    font.pixelSize: 38 * scene.sc
                    color: row.lit ? "#fff7ea" : Shinobi.alpha(Shinobi.ivory, 0.82)
                }

                Text {
                    anchors.left: name.right
                    anchors.leftMargin: 16 * scene.sc
                    anchors.baseline: name.baseline
                    text: scene.glosses[row.index]
                    font.family: Shinobi.book
                    font.pixelSize: 17 * scene.sc
                    color: Shinobi.alpha(Shinobi.ivory, row.lit ? 0.8 : 0.5)
                }

                PowerHit {
                    anchors.fill: parent
                    menu: scene.menu
                    index: row.index
                }
            }
        }
    }

    // The shinobi, under the menu.
    Column {
        x: 120 * scene.sc
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 70 * scene.sc
        spacing: 8 * scene.sc
        opacity: scene.seg(scene.intro, 0.45, 1) * (1 - scene.aside)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.85
            shadowBlur: 0.5
            blurMax: 16
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 2
        }

        Row {
            spacing: 8 * scene.sc

            Repeater {
                model: 2

                ResurrectionNode {
                    required property int index
                    width: 36 * scene.sc
                    height: width
                    emblem: index
                    glow: scene.glow * 0.5
                    seed: index + 1
                    rose: Shinobi.node
                    roseGlow: Shinobi.nodeGlow
                }
            }
        }

        Rectangle {
            width: 380 * scene.sc
            height: 11 * scene.sc
            color: Shinobi.alpha("black", 0.6)
            border.width: 1
            border.color: Shinobi.alpha(Shinobi.steel, 0.35)

            Rectangle {
                x: 2 * scene.sc
                y: 2 * scene.sc
                width: (parent.width - 4 * scene.sc) * scene.vitality
                height: parent.height - 4 * scene.sc
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.lighter(Shinobi.vitality, 1.25) }
                    GradientStop { position: 1; color: Qt.darker(Shinobi.vitality, 1.5) }
                }
            }
        }

        Text {
            text: scene.menu.userName + "  ·  " + Shinobi.rank(Services.LockStats.level) + "  ·  undying for " + scene.uptimeText(scene.menu.uptime)
            font.family: Shinobi.book
            font.pixelSize: 17 * scene.sc
            color: Shinobi.alpha(Shinobi.ivory, 0.8)
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.height - 44 * scene.sc
        opacity: scene.seg(scene.intro, 0.7, 1) * 0.6 * (1 - scene.aside)
        text: "Esc · leave the idol"
        font.family: Shinobi.book
        font.pixelSize: 15 * scene.sc
        color: Shinobi.ivory
    }

    // ── The ceremonies ───────────────────────────────────────────────────
    // Severance: a cut of blood across the screen.
    BrushStroke {
        x: scene.width * 0.5 - width / 2
        y: scene.height * 0.44 - height / 2
        width: scene.width * 1.2
        height: 80 * scene.sc
        rotation: -22
        visible: scene.cutting > 0
        reveal: scene.cutting
        opacity: 1 - scene.dark
        ink: Shinobi.alpha(Shinobi.kanji, 0.92)
        seed: 9
        dry: 0.85
        weight: 0.7
    }

    // Return: the night closes in from the edges.
    Shape {
        anchors.fill: parent
        visible: scene.returning > 0
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: scene.width / 2
                centerY: scene.height * 0.44
                centerRadius: Math.hypot(scene.width, scene.height) * 0.6
                focalX: scene.width / 2
                focalY: scene.height * 0.44
                GradientStop { position: Math.max(0, 0.85 - scene.returning * 0.75); color: "transparent" }
                GradientStop { position: Math.max(0.02, 1.02 - scene.returning * 0.7); color: "#030204" }
            }
            PathRectangle { x: 0; y: 0; width: scene.width; height: scene.height }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#030204"
        opacity: Math.max(scene.dark, scene.returning * scene.returning * 0.92)
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.height * 0.44 - kanji.height / 2
        visible: scene.writing > 0
        spacing: 2 * scene.sc

        BrushKanji {
            id: kanji
            anchors.horizontalCenter: parent.horizontalCenter
            text: (scene.ceremonies[scene.chosenId] ?? { kanji: "" }).kanji
            size: (scene.chosenId === "reboot" ? 230 : 150) * scene.sc
            ink: scene.chosenId === "reboot" ? "#f3ecdf" : Shinobi.kanji
            progress: scene.writing
            seed: scene.chosen + 3
            dry: 0.6
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: Math.max(0, scene.writing * 2 - 1)
            text: (scene.ceremonies[scene.chosenId] ?? { word: "" }).word
            font.family: Shinobi.display
            font.pixelSize: 32 * scene.sc
            font.letterSpacing: 12 * scene.sc
            color: Shinobi.ivory
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 6 * scene.sc
            opacity: Math.max(0, scene.writing * 2 - 1) * 0.75
            text: (scene.ceremonies[scene.chosenId] ?? { line: "" }).line
            font.family: Shinobi.book
            font.pixelSize: 19 * scene.sc
            color: Shinobi.ivory
        }
    }
}
