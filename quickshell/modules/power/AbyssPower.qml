pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.colors
import qs.modules.lock.themes.abyss
import qs.services as Services

// Abyss: the desktop goes under, sunk as deep as the hour (the theme's
// water, shaders/desktop_abyss.frag), and the boat's engine order
// telegraph stands in the middle: a brass drum with its orders round the
// face, Seal hatch (lock), Hold depth (sleep), Surface (log out), Dive
// again (restart), Abandon ship (shut down), and a handle that swings to
// whichever you point at. The depth tape and the boat's readings stand
// either side. Choosing an order rings it (the handle thrown back and forth
// twice, as a telegraph is rung, the engine room's pointer answering) and
// the boat does it: surfacing into the light, or flooding (the Bathysphere
// lock's water, shaders/lock_flood.frag) into the dark.
PowerScene {
    id: scene

    introMs: 1000
    outroMs: 380
    riteMs: 3200
    quickMs: 300
    ambient: true

    readonly property var orders: ["SEAL\nHATCH", "HOLD\nDEPTH", "SURFACE", "DIVE\nAGAIN", "ABANDON\nSHIP"]
    readonly property var glosses: ["lock", "sleep", "log out", "restart", "shut down"]
    readonly property var logbook: ({
        logout: ["SURFACED", "fair winds, " + menu.userName],
        reboot: ["DIVING AGAIN", "back on station shortly"],
        poweroff: ["ALL HANDS ABANDON SHIP", "the boat goes dark"]
    })

    readonly property real metres: Deep.depthAt(menu.now)
    readonly property var zone: Deep.zoneAt(metres)

    readonly property real cx: width / 2
    readonly property real cy: height * 0.53
    readonly property real drumR: 270 * sc
    readonly property real faceR: 222 * sc

    // An order's place on the face: degrees from straight up.
    function bearing(i) {
        return -72 + 36 * i;
    }

    readonly property real sunk: ease(intro, 0, 0.8)
    readonly property real flood: chosenId === "poweroff" || chosenId === "reboot" ? ease(rite, 0.42, 0.95) : 0
    readonly property real surfacing: chosenId === "logout" ? ease(rite, 0.36, 0.72) : 0
    readonly property real gone: chosenId === "logout" ? ease(rite, 0.72, 0.95) : 0

    // The handle: over the order pointed at (upright when none is), rung
    // back and forth twice when one is given.
    readonly property real target: current >= 0 ? bearing(current) : 0
    property real handleAt: target
    Behavior on handleAt {
        SpringAnimation {
            spring: 2.4
            damping: 0.24
            epsilon: 0.05
        }
    }
    readonly property real ring: chosen >= 0 ? Math.sin(lin(rite, 0, quickChosen ? 0.6 : 0.3) * Math.PI * 4) * 34 * (1 - lin(rite, 0, quickChosen ? 0.6 : 0.3)) : 0
    // The engine room's pointer answers once the order is rung.
    readonly property real answer: chosen >= 0 ? ease(rite, quickChosen ? 0.3 : 0.18, quickChosen ? 0.8 : 0.34) : 0

    // ── Under water ──────────────────────────────────────────────────────

    Rectangle {
        anchors.fill: parent
        visible: scene.chosen >= 0 && !scene.quickChosen
        color: "black"
    }

    Item {
        id: sea
        anchors.fill: parent

        layer.enabled: scene.flood > 0
        layer.effect: ShaderEffect {
            property real itemWidth: sea.width
            property real itemHeight: sea.height
            property real progress: scene.flood
            property color waterColor: Deep.water
            property color glowColor: Deep.glow

            fragmentShader: Qt.resolvedUrl("../../shaders/lock_flood.frag.qsb")
        }

        PowerGrade {
            menu: scene.menu
            amount: scene.sunk
            saturation: 0.4
            brightness: 0.5
            duo: 0.4
            shadowColor: Deep.abyss
            lightColor: Deep.water
        }

        ShaderEffect {
            anchors.fill: parent
            visible: scene.menu.hasWorld
            opacity: Math.min(1, scene.sunk * 1.5)

            property variant source: scene.menu.world
            property real itemWidth: width
            property real itemHeight: height
            property real depth: Math.max(0.55, Deep.shade(scene.metres))
            property real flood: scene.sunk
            property real lineScale: 1
            property color glowColor: Deep.glow
            property color lumeColor: Deep.lume
            property color waterColor: Deep.water
            property color sunColor: "#d9f4ee"

            fragmentShader: Qt.resolvedUrl("../../shaders/desktop_abyss.frag.qsb")
        }

        Rectangle {
            anchors.fill: parent
            color: Deep.abyss
            opacity: 0.35 * scene.sunk
        }

        // ── The boat's state ─────────────────────────────────────────────

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 58 * scene.sc
            spacing: 8 * scene.sc
            opacity: scene.seg(scene.intro, 0.4, 0.9) * (1 - scene.aside)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "ENGINE ORDER TELEGRAPH"
                font.family: Deep.display
                font.pixelSize: 26 * scene.sc
                font.letterSpacing: 6 * scene.sc
                color: Deep.foam
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (scene.zone.name + "  ·  " + Deep.metres(scene.metres) + "  ·  " + Deep.rank(Services.LockStats.level) + " " + scene.menu.userName).toUpperCase()
                font.family: Deep.ui
                font.pixelSize: 13 * scene.sc
                font.letterSpacing: 2.5 * scene.sc
                color: Deep.lume
            }
        }

        // The depth tape, left.
        ZoneGauge {
            x: scene.cx - scene.drumR - 260 * scene.sc
            y: scene.cy - height / 2
            width: 120 * scene.sc
            height: 470 * scene.sc
            metres: scene.metres
            unit: scene.sc
            opacity: scene.seg(scene.intro, 0.45, 0.95) * (1 - scene.aside)
        }

        // The readings, right.
        Column {
            x: scene.cx + scene.drumR + 120 * scene.sc
            y: scene.cy - height / 2
            spacing: 22 * scene.sc
            opacity: scene.seg(scene.intro, 0.45, 0.95) * (1 - scene.aside)

            Repeater {
                model: [
                    ["DEPTH", Deep.metres(scene.metres)],
                    ["PRESSURE", Math.round(Deep.pressure(scene.metres)) + " atm"],
                    ["WATER", Deep.temperature(scene.metres).toFixed(1) + " °C"],
                    ["ZONE", scene.zone.latin.toUpperCase()],
                    ["SUBMERGED", scene.uptimeText(scene.menu.uptime)]
                ]

                Column {
                    id: reading
                    required property var modelData
                    spacing: 3 * scene.sc

                    Text {
                        text: reading.modelData[0]
                        font.family: Deep.ui
                        font.pixelSize: 11 * scene.sc
                        font.letterSpacing: 3 * scene.sc
                        color: Deep.alpha(Deep.lume, 0.7)
                    }

                    Text {
                        text: reading.modelData[1]
                        font.family: Deep.mono
                        font.pixelSize: 20 * scene.sc
                        color: Deep.foam
                    }
                }
            }
        }

        // ── The telegraph ────────────────────────────────────────────────

        Item {
            id: drum

            readonly property real shown: scene.seg(scene.intro, 0.2, 0.75)

            x: scene.cx
            y: scene.cy
            opacity: shown
            scale: 0.92 + 0.08 * shown

            // Lume glow behind it.
            Rectangle {
                x: -width / 2
                y: -height / 2
                width: scene.drumR * 2.6
                height: width
                radius: width / 2
                color: Deep.lume
                opacity: 0.08
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 1
                    blurMax: 64
                }
            }

            // The brass drum.
            Rectangle {
                x: -scene.drumR
                y: -scene.drumR
                width: scene.drumR * 2
                height: width
                radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0; color: "#e8c77c" }
                    GradientStop { position: 0.5; color: "#a8803a" }
                    GradientStop { position: 1; color: "#5d4317" }
                }
                border.width: 2 * scene.sc
                border.color: "#2d1f08"

                // Bolts round the rim.
                Repeater {
                    model: 16

                    Rectangle {
                        required property int index
                        readonly property real a: index * Math.PI / 8
                        x: scene.drumR + Math.cos(a) * (scene.drumR - 22 * scene.sc) - width / 2
                        y: scene.drumR + Math.sin(a) * (scene.drumR - 22 * scene.sc) - height / 2
                        width: 11 * scene.sc
                        height: width
                        radius: width / 2
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#f3dc9c" }
                            GradientStop { position: 1; color: "#6b4c1a" }
                        }
                    }
                }
            }

            // The face, under its glass.
            Rectangle {
                x: -scene.faceR
                y: -scene.faceR
                width: scene.faceR * 2
                height: width
                radius: width / 2
                color: "#e9e3d0"
                border.width: 3 * scene.sc
                border.color: "#3a2a0e"
            }

            // The orders, each in its sector of the upper half.
            Shape {
                x: -scene.faceR
                y: -scene.faceR
                width: scene.faceR * 2
                height: width
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: "#3a2a0e"
                    strokeWidth: 1.5 * scene.sc
                    capStyle: ShapePath.FlatCap

                    PathMultiline {
                        paths: {
                            const out = [];
                            const c = scene.faceR;
                            for (let k = 0; k <= 5; k++) {
                                const a = (180 + 36 * k) * Math.PI / 180;
                                out.push([Qt.point(c + Math.cos(a) * c * 0.2, c + Math.sin(a) * c * 0.2), Qt.point(c + Math.cos(a) * c * 0.98, c + Math.sin(a) * c * 0.98)]);
                            }
                            return out;
                        }
                    }
                }

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: "#3a2a0e"
                    strokeWidth: 1.5 * scene.sc

                    PathAngleArc {
                        centerX: scene.faceR
                        centerY: scene.faceR
                        radiusX: scene.faceR * 0.2
                        radiusY: scene.faceR * 0.2
                        startAngle: 180
                        sweepAngle: 180
                    }
                }
            }

            // A lit sector behind the order pointed at.
            Repeater {
                model: scene.actions.length

                Shape {
                    id: sector

                    required property int index
                    readonly property bool lit: scene.current === index || scene.chosen === index

                    x: -scene.faceR
                    y: -scene.faceR
                    width: scene.faceR * 2
                    height: width
                    opacity: lit ? 1 : 0
                    preferredRendererType: Shape.CurveRenderer

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }

                    ShapePath {
                        fillColor: Deep.alpha(sector.index === 4 ? Deep.alarm : Deep.lume, 0.35)
                        strokeColor: "transparent"
                        startX: scene.faceR
                        startY: scene.faceR

                        PathAngleArc {
                            centerX: scene.faceR
                            centerY: scene.faceR
                            radiusX: scene.faceR * 0.97
                            radiusY: scene.faceR * 0.97
                            startAngle: 180 + 36 * sector.index
                            sweepAngle: 36
                            moveToStart: false
                        }
                    }
                }
            }

            Repeater {
                model: scene.actions.length

                Text {
                    id: order
                    required property int index
                    readonly property real a: (180 + 18 + 36 * index) * Math.PI / 180
                    x: Math.cos(a) * scene.faceR * 0.66 - width / 2
                    y: Math.sin(a) * scene.faceR * 0.66 - height / 2
                    text: scene.orders[index]
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 0.95
                    font.family: Deep.ui
                    font.pixelSize: 15 * scene.sc
                    font.bold: true
                    font.letterSpacing: 1 * scene.sc
                    color: index === 4 ? "#9a2018" : "#2a1d08"
                }
            }

            // The lower half: whose boat it is, and the bell.
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: scene.faceR * 0.32
                spacing: 4 * scene.sc

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "ENGINE ROOM"
                    font.family: Deep.display
                    font.pixelSize: 15 * scene.sc
                    font.letterSpacing: 4 * scene.sc
                    color: "#2a1d08"
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (scene.menu.hostName || "bathysphere").toUpperCase() + " & SONS  ·  GLASGOW"
                    font.family: Deep.ui
                    font.pixelSize: 10 * scene.sc
                    font.letterSpacing: 2 * scene.sc
                    color: "#5a4520"
                }
            }

            // The engine room's answering pointer.
            Rectangle {
                x: -width / 2
                y: -scene.faceR * 0.92
                width: 8 * scene.sc
                height: scene.faceR * 0.92
                radius: width / 2
                color: "#b3261c"
                transformOrigin: Item.Bottom
                rotation: scene.mix(180, scene.chosen >= 0 ? scene.bearing(scene.chosen) : 180, scene.answer)
                visible: scene.chosen >= 0
                opacity: 0.85
            }

            // The handle, rung: two rods forked round the order it stands
            // over, so the order still shows between them, joined at the grip.
            Item {
                rotation: scene.handleAt + scene.ring

                Repeater {
                    model: [-1, 1]

                    Rectangle {
                        required property var modelData
                        x: -width / 2
                        y: -scene.drumR - 42 * scene.sc
                        width: 9 * scene.sc
                        height: scene.drumR + 42 * scene.sc
                        radius: width / 2
                        transformOrigin: Item.Bottom
                        rotation: modelData * 11
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "#6b4c1a" }
                            GradientStop { position: 0.5; color: "#f0d48a" }
                            GradientStop { position: 1; color: "#6b4c1a" }
                        }
                        border.width: 1
                        border.color: "#2d1f08"
                    }
                }

                // Its grip, across the two.
                Rectangle {
                    x: -58 * scene.sc
                    y: -scene.drumR - 58 * scene.sc
                    width: 116 * scene.sc
                    height: 26 * scene.sc
                    radius: height / 2
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#f3dc9c" }
                        GradientStop { position: 1; color: "#7a5a22" }
                    }
                    border.width: 1.5 * scene.sc
                    border.color: "#2d1f08"
                }
            }

            // The boss.
            Rectangle {
                x: -width / 2
                y: -height / 2
                width: 54 * scene.sc
                height: width
                radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0; color: "#f3dc9c" }
                    GradientStop { position: 1; color: "#5d4317" }
                }
                border.width: 1.5 * scene.sc
                border.color: "#2d1f08"
            }

            // The bell, rung: rings spreading from the drum.
            Repeater {
                model: scene.chosen >= 0 ? 2 : 0

                Rectangle {
                    required property int index
                    readonly property real t: scene.lin(scene.rite, 0.05 + index * 0.14, (scene.quickChosen ? 0.6 : 0.4) + index * 0.14)
                    x: -width / 2
                    y: -height / 2
                    width: scene.drumR * 2 * (1 + t * 0.8)
                    height: width
                    radius: width / 2
                    visible: t > 0 && t < 1
                    color: "transparent"
                    border.width: 3 * scene.sc
                    border.color: Deep.alpha(Deep.foam, 0.55 * (1 - t))
                }
            }
        }

        // Each order's name under it for the pointer.
        Repeater {
            model: scene.actions.length

            Item {
                id: hit
                required property int index
                readonly property real a: (180 + 18 + 36 * index) * Math.PI / 180

                x: scene.cx + Math.cos(a) * scene.faceR * 0.62 - width / 2
                y: scene.cy + Math.sin(a) * scene.faceR * 0.62 - height / 2
                width: 120 * scene.sc
                height: 110 * scene.sc

                PowerHit {
                    anchors.fill: parent
                    menu: scene.menu
                    index: hit.index
                }
            }
        }

        // What each order does, round the outside of the drum.
        Repeater {
            model: scene.actions.length

            Text {
                id: gloss
                required property int index
                readonly property bool lit: scene.current === index
                readonly property real a: (180 + 18 + 36 * index) * Math.PI / 180
                readonly property real r: scene.drumR + 104 * scene.sc

                x: scene.cx + Math.cos(a) * r - width / 2
                y: scene.cy + Math.sin(a) * r - height / 2
                text: scene.glosses[index].toUpperCase()
                font.family: Deep.ui
                font.pixelSize: 13 * scene.sc
                font.letterSpacing: 3 * scene.sc
                color: lit ? Deep.lume : Deep.alpha(Deep.foam, 0.55)
                opacity: scene.seg(scene.intro, 0.55, 1) * (1 - scene.aside)
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: scene.height - 80 * scene.sc
            opacity: scene.seg(scene.intro, 0.7, 1) * 0.65 * (1 - scene.aside)
            text: "ESC  ·  MAINTAIN COURSE"
            font.family: Deep.ui
            font.pixelSize: 13 * scene.sc
            font.letterSpacing: 4 * scene.sc
            color: Deep.foam
        }

        // Surfacing: light coming down from above.
        Rectangle {
            anchors.fill: parent
            visible: scene.surfacing > 0
            opacity: scene.surfacing
            gradient: Gradient {
                GradientStop { position: 0; color: Deep.alpha("#e9fbff", 0.95) }
                GradientStop { position: 0.6; color: Deep.alpha("#9fd8e0", 0.6) }
                GradientStop { position: 1; color: Deep.alpha(Deep.water, 0.3) }
            }
        }
    }

    // Bubbles, going up.
    Repeater {
        model: scene.chosen >= 0 && !scene.quickChosen ? 40 : 0

        Rectangle {
            required property int index
            readonly property real r1: Math.abs((Math.sin(index * 12.9898) * 43758.5453) % 1)
            readonly property real r2: Math.abs((Math.sin(index * 78.233) * 43758.5453) % 1)
            readonly property real age: (scene.rite - 0.3 - r1 * 0.4) / (0.25 + r2 * 0.2)
            visible: age > 0 && age < 1
            x: r2 * scene.width + Math.sin(age * 9 + index) * 10 * scene.sc
            y: scene.height * (1 - age * 1.2)
            width: (5 + r1 * 12) * scene.sc
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1.5 * scene.sc
            border.color: Deep.alpha(Deep.foam, 0.6 * (1 - age))
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: scene.gone
        visible: opacity > 0
    }

    Column {
        anchors.centerIn: parent
        visible: scene.chosen >= 0 && !scene.quickChosen
        opacity: scene.seg(scene.rite, 0.8, 0.98)
        spacing: 12 * scene.sc

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (scene.logbook[scene.chosenId] ?? ["", ""])[0]
            font.family: Deep.display
            font.pixelSize: 34 * scene.sc
            font.letterSpacing: 8 * scene.sc
            color: Deep.foam
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (scene.logbook[scene.chosenId] ?? ["", ""])[1].toUpperCase()
            font.family: Deep.ui
            font.pixelSize: 14 * scene.sc
            font.letterSpacing: 4 * scene.sc
            color: Deep.lume
        }
    }
}
