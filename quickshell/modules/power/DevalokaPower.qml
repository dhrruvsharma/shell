pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.colors
import qs.components
import qs.modules.lock.themes.devaloka
import qs.services as Services

// Devaloka: the desktop warms to lamplight in a temple at dusk, the
// Konark sun wheel stands over today's panchang, and below it a brass
// aarti thali holds five clay diyas, a word in Devanagari over each flame:
// रक्षा raksha (lock), निद्रा nidra (sleep), विदा vida (log out), पुनर्जन्म
// punarjanma (restart), मोक्ष moksha (shut down). Pointed at, a flame burns
// up tall and the word lights. Moksha puts the lamps out one by one, the
// chosen flame last, its light rising away into the dark; punarjanma puts
// them out and lights them again as the wheel turns; vida circles the thali
// once, as the aarti is waved, before the lamps go out.
PowerScene {
    id: scene

    introMs: 1000
    outroMs: 380
    riteMs: 3200
    quickMs: 300
    ambient: true

    readonly property var words: ["रक्षा", "निद्रा", "विदा", "पुनर्जन्म", "मोक्ष"]
    readonly property var sounds: ["raksha", "nidra", "vidā", "punarjanma", "moksha"]
    readonly property var glosses: ["protection · lock", "sleep", "farewell · log out", "rebirth · restart", "release · shut down"]
    readonly property var benedictions: ({
        logout: ["विदा", "go well, " + menu.userName],
        reboot: ["पुनर्जन्म", "the wheel turns, and all returns"],
        poweroff: ["मोक्ष", "the lamps are at rest"]
    })

    readonly property var pan: Deva.panchang(menu.now)
    readonly property var prahar: Deva.prahar(menu.now)

    readonly property real cx: width / 2
    readonly property real plateY: height * 0.66
    readonly property real pitch: 196 * sc

    function diyaX(i) {
        return cx + (i - 2) * pitch;
    }

    // Back ones a little higher on the plate.
    function diyaY(i) {
        return plateY - 18 * sc + Math.abs(i - 2) * 6 * sc;
    }

    readonly property real lamplight: ease(intro, 0, 0.75)
    // Each lamp's flame, 0 out .. 1 burning, through the ceremony.
    function flameOf(i) {
        if (chosen < 0 || quickChosen)
            return 1;
        // Moksha: the chosen flame never goes out; its light leaves.
        if (chosenId === "poweroff" && i === chosen)
            return 1;
        const order = [0, 4, 1, 3, 2].filter(j => j !== chosen).concat([chosen]);
        const k = order.indexOf(i);
        const out = 1 - ease(rite, 0.22 + k * 0.08, 0.3 + k * 0.08);
        if (chosenId === "reboot")
            return Math.max(out, ease(rite, 0.68 + k * 0.05, 0.76 + k * 0.05));
        return out;
    }
    readonly property real dark: quickChosen || chosenId === "reboot" ? 0 : ease(rite, 0.35, 0.9)
    // Vida: the thali carried round once in a circle, as the aarti is waved.
    readonly property real wave: chosenId === "logout" ? ease(rite, 0.02, 0.4) : 0
    readonly property real waveX: Math.sin(wave * Math.PI * 2) * 40 * sc
    readonly property real waveY: (1 - Math.cos(wave * Math.PI * 2)) * -18 * sc

    // ── Lamplight ────────────────────────────────────────────────────────

    PowerGrade {
        menu: scene.menu
        amount: scene.lamplight
        saturation: 0.45
        brightness: 0.42
        duo: 0.55
        shadowColor: Deva.ground
        lightColor: Qt.tint(Deva.lac, Colors.withAlpha(Deva.haldi, 0.45))
        vignette: 0.7
    }

    Rectangle {
        anchors.fill: parent
        color: "#080303"
        opacity: scene.dark * 0.95
    }

    // ── The sun wheel and the day ────────────────────────────────────────

    KonarkWheel {
        x: scene.cx - width / 2
        y: 56 * scene.sc
        width: 150 * scene.sc
        height: width
        hour: scene.menu.now.getHours() + scene.menu.now.getMinutes() / 60
        glow: 1
        rotation: scene.chosenId === "reboot" ? 360 * scene.ease(scene.rite, 0.3, 0.8) : 0
        opacity: scene.seg(scene.intro, 0.2, 0.7) * (1 - 0.9 * scene.dark)
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 222 * scene.sc
        spacing: 4 * scene.sc
        opacity: scene.seg(scene.intro, 0.4, 0.9) * (1 - scene.aside)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: scene.pan.tithiLineDev + "  ·  " + scene.pan.nakshatraDev + "  ·  " + scene.pan.varaDev
            font.family: Deva.book
            font.pixelSize: 24 * scene.sc
            color: Deva.goldHi
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: scene.pan.masaName + " " + scene.pan.tithiLine + ", " + scene.pan.nakshatraName + "  ·  " + scene.prahar.line + ", raga " + scene.prahar.raga
            font.family: Deva.display
            font.pixelSize: 15 * scene.sc
            font.letterSpacing: 0.5 * scene.sc
            color: Deva.alpha(Deva.ivory, 0.65)
        }
    }

    // ── The thali ────────────────────────────────────────────────────────

    Item {
        id: thali

        readonly property real shown: scene.seg(scene.intro, 0.2, 0.7)

        x: scene.cx + scene.waveX
        y: scene.plateY + 30 * scene.sc + scene.waveY + (1 - shown) * 30 * scene.sc
        opacity: shown * (1 - scene.dark)

        // The plate, in perspective: a raised rim round a sunk well.
        Shape {
            x: -width / 2
            y: -height / 2
            width: 1080 * scene.sc
            height: 260 * scene.sc
            preferredRendererType: Shape.CurveRenderer

            // Its edge, seen below the rim.
            ShapePath {
                strokeColor: "#3b2408"
                strokeWidth: 1.5 * scene.sc
                fillColor: "#6e4712"
                PathAngleArc {
                    centerX: 540 * scene.sc
                    centerY: 142 * scene.sc
                    radiusX: 540 * scene.sc
                    radiusY: 115 * scene.sc
                    sweepAngle: 360
                }
            }

            ShapePath {
                strokeColor: "#3b2408"
                strokeWidth: 1.5 * scene.sc
                fillGradient: LinearGradient {
                    x1: 0
                    y1: 0
                    x2: 0
                    y2: 260 * scene.sc
                    GradientStop { position: 0; color: "#f0c870" }
                    GradientStop { position: 0.6; color: "#b88a36" }
                    GradientStop { position: 1; color: "#6e4712" }
                }
                PathAngleArc {
                    centerX: 540 * scene.sc
                    centerY: 128 * scene.sc
                    radiusX: 540 * scene.sc
                    radiusY: 115 * scene.sc
                    sweepAngle: 360
                }
            }

            ShapePath {
                strokeColor: "#5e3d12"
                strokeWidth: 1.2 * scene.sc
                fillGradient: LinearGradient {
                    x1: 0
                    y1: 40 * scene.sc
                    x2: 0
                    y2: 220 * scene.sc
                    GradientStop { position: 0; color: "#8a5e20" }
                    GradientStop { position: 1; color: "#e2b25c" }
                }
                PathAngleArc {
                    centerX: 540 * scene.sc
                    centerY: 132 * scene.sc
                    radiusX: 470 * scene.sc
                    radiusY: 92 * scene.sc
                    sweepAngle: 360
                }
            }

            ShapePath {
                strokeColor: Colors.withAlpha("#5e3d12", 0.6)
                strokeWidth: 1 * scene.sc
                fillColor: "transparent"
                strokeStyle: ShapePath.DashLine
                dashPattern: [2, 3]
                PathAngleArc {
                    centerX: 540 * scene.sc
                    centerY: 132 * scene.sc
                    radiusX: 330 * scene.sc
                    radiusY: 64 * scene.sc
                    sweepAngle: 360
                }
            }
        }

        // Kumkum and petals scattered on it.
        Repeater {
            model: 26

            Rectangle {
                required property int index
                readonly property real a: index * 2.39996
                readonly property real r: 0.35 + 0.55 * ((index * 37) % 26) / 26
                x: Math.cos(a) * r * 480 * scene.sc - width / 2
                y: Math.sin(a) * r * 98 * scene.sc - height / 2
                width: (index % 3 === 0 ? 6 : 10) * scene.sc
                height: (index % 3 === 0 ? 6 : 5) * scene.sc
                radius: height / 2
                rotation: index * 47
                color: index % 3 === 0 ? Deva.kumkum : index % 3 === 1 ? Deva.haldi : "#f08a2c"
                opacity: 0.85
            }
        }

        Lotus {
            x: -width / 2
            y: -height / 2 + 10 * scene.sc
            width: 120 * scene.sc
            height: 80 * scene.sc
            stroke: Deva.lac
            fill: Deva.alpha(Deva.lotus, 0.75)
            lineWidth: 1.5 * scene.sc
        }
    }

    // ── The diyas ────────────────────────────────────────────────────────

    Repeater {
        model: scene.actions.length

        Item {
            id: diya

            required property int index
            readonly property bool lit: scene.current === index
            readonly property bool picked: scene.chosen === index
            readonly property real shown: scene.seg(scene.intro, 0.35 + index * 0.06, 0.75 + index * 0.05)
            readonly property real burning: scene.flameOf(index)
            readonly property real flare: picked && scene.quickChosen ? Math.sin(Math.PI * scene.rite) : 0
            // Moksha: the chosen flame's light leaving its lamp.
            readonly property real leaving: picked && scene.chosenId === "poweroff" ? scene.ease(scene.rite, 0.6, 0.95) : 0

            property real glow: lit || picked ? 1 : 0
            Behavior on glow {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }

            x: scene.diyaX(index) + scene.waveX
            y: scene.diyaY(index) + scene.waveY
            opacity: diya.shown

            // Its light on the plate.
            Rectangle {
                x: -width / 2
                y: -height / 2 - 30 * scene.sc
                width: (160 + 120 * diya.glow) * scene.sc
                height: width
                radius: width / 2
                color: Deva.amrita
                opacity: (0.12 + 0.2 * diya.glow + 0.2 * diya.flare) * diya.burning * (1 - diya.leaving)
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 1
                    blurMax: 48
                }
            }

            // The clay lamp: a shallow bowl pinched to a spout at the front,
            // oil in it, a gold line round its lip.
            Shape {
                opacity: 1 - scene.dark
                x: -44 * scene.sc
                y: -10 * scene.sc
                width: 88 * scene.sc
                height: 40 * scene.sc
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: "#2b0f06"
                    strokeWidth: 1.2 * scene.sc
                    fillGradient: LinearGradient {
                        x1: 0
                        y1: 0
                        x2: 0
                        y2: 40 * scene.sc
                        GradientStop { position: 0; color: "#b65a2c" }
                        GradientStop { position: 1; color: "#4a1c0b" }
                    }
                    startX: 0
                    startY: 8 * scene.sc
                    PathCubic {
                        x: 44 * scene.sc
                        y: 40 * scene.sc
                        control1X: 2 * scene.sc
                        control1Y: 30 * scene.sc
                        control2X: 20 * scene.sc
                        control2Y: 40 * scene.sc
                    }
                    PathCubic {
                        x: 88 * scene.sc
                        y: 8 * scene.sc
                        control1X: 68 * scene.sc
                        control1Y: 40 * scene.sc
                        control2X: 86 * scene.sc
                        control2Y: 30 * scene.sc
                    }
                    PathLine {
                        x: 0
                        y: 8 * scene.sc
                    }
                }

                ShapePath {
                    strokeColor: Deva.gold
                    strokeWidth: 1.5 * scene.sc
                    fillColor: "#3a1d07"
                    PathAngleArc {
                        centerX: 44 * scene.sc
                        centerY: 8 * scene.sc
                        radiusX: 44 * scene.sc
                        radiusY: 8 * scene.sc
                        sweepAngle: 360
                    }
                }
            }

            // The wick, at the spout.
            Rectangle {
                opacity: 1 - scene.dark
                x: -2 * scene.sc
                y: -14 * scene.sc
                width: 4 * scene.sc
                height: 10 * scene.sc
                radius: 2 * scene.sc
                color: "#2a1a10"
            }

            // The flame.
            Item {
                id: flame

                readonly property real tall: (0.85 + 0.45 * diya.glow + 0.35 * diya.flare) * diya.burning * (1 - 0.6 * rise)
                // Moksha: the chosen flame's light rises away as it goes.
                readonly property real rise: diya.leaving

                x: -width / 2
                y: -12 * scene.sc - height - rise * 260 * scene.sc
                width: 30 * scene.sc
                height: 62 * scene.sc * Math.max(0.0001, tall)
                visible: diya.burning > 0.02 || rise > 0
                transformOrigin: Item.Bottom
                rotation: Math.sin(scene.menu.time * 2.1 + diya.index * 1.7) * 4 + Math.sin(scene.menu.time * 5.3 + diya.index) * 1.5
                opacity: rise > 0 ? 1 - rise : 1

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#ffb347"
                    shadowOpacity: 1
                    shadowBlur: 1
                    blurMax: 32
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: LinearGradient {
                            x1: 0
                            y1: flame.height
                            x2: 0
                            y2: 0
                            GradientStop { position: 0; color: "#fff4d6" }
                            GradientStop { position: 0.4; color: "#ffc45c" }
                            GradientStop { position: 1; color: "#ff6a1a" }
                        }
                        startX: flame.width / 2
                        startY: 0
                        PathCubic {
                            x: flame.width / 2
                            y: flame.height
                            control1X: flame.width * 1.05
                            control1Y: flame.height * 0.5
                            control2X: flame.width * 1.1
                            control2Y: flame.height
                        }
                        PathCubic {
                            x: flame.width / 2
                            y: 0
                            control1X: -flame.width * 0.1
                            control1Y: flame.height
                            control2X: -flame.width * 0.05
                            control2Y: flame.height * 0.5
                        }
                    }
                }
            }

            // Its word, over the flame.
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: -190 * scene.sc
                text: scene.words[diya.index]
                font.family: Deva.book
                font.pixelSize: 40 * scene.sc
                color: Qt.tint(Deva.alpha(Deva.gold, 0.75), Deva.alpha(Deva.amrita, diya.glow))
                opacity: (1 - (diya.picked || scene.quickChosen ? 0 : scene.aside)) * (0.55 + 0.45 * Math.max(diya.glow, diya.burning * 0.6)) * (1 - scene.dark)
                layer.enabled: diya.glow > 0.01
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#f4b73c"
                    shadowOpacity: diya.glow * 0.8
                    shadowBlur: 0.8
                    blurMax: 24
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }
            }

            PowerHit {
                x: -80 * scene.sc
                y: -200 * scene.sc
                width: 160 * scene.sc
                height: 240 * scene.sc
                menu: scene.menu
                index: diya.index
            }
        }
    }

    // What each lamp is, along the foot of the thali.
    Repeater {
        model: scene.actions.length

        Column {
            id: gloss

            required property int index
            readonly property bool lit: scene.current === index

            x: scene.diyaX(index) - width / 2
            y: scene.plateY + 168 * scene.sc
            spacing: 2 * scene.sc
            opacity: scene.seg(scene.intro, 0.55, 1) * (1 - scene.aside) * (lit ? 1 : 0.65)

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: scene.sounds[gloss.index]
                font.family: Deva.display
                font.pixelSize: 21 * scene.sc
                font.weight: Font.DemiBold
                color: gloss.lit ? Deva.goldHi : Deva.ivory
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: scene.glosses[gloss.index]
                font.family: Deva.book
                font.italic: true
                font.pixelSize: 14 * scene.sc
                color: Deva.alpha(Deva.ivory, 0.62)
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.height - 70 * scene.sc
        opacity: scene.seg(scene.intro, 0.7, 1) * 0.6 * (1 - scene.aside)
        text: "Esc · remain in the temple"
        font.family: Deva.book
        font.italic: true
        font.pixelSize: 15 * scene.sc
        color: Deva.ivory
    }

    // ── The blessing ─────────────────────────────────────────────────────

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.height * 0.36
        visible: scene.chosen >= 0 && !scene.quickChosen
        opacity: scene.seg(scene.rite, 0.78, 0.98)
        spacing: 8 * scene.sc

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (scene.benedictions[scene.chosenId] ?? ["", ""])[0]
            font.family: Deva.book
            font.pixelSize: 72 * scene.sc
            color: Deva.goldHi
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (scene.benedictions[scene.chosenId] ?? ["", ""])[1]
            font.family: Deva.display
            font.pixelSize: 19 * scene.sc
            font.letterSpacing: 1 * scene.sc
            color: Deva.alpha(Deva.ivory, 0.75)
        }
    }
}
