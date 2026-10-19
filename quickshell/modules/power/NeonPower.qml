pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.colors
import qs.modules.lock.themes.cyberpunk
import qs.services as Services

// Neon Noir: the desktop turns to a rain-slick city at night (the Black ICE
// lock's street, shaders/lock_neon_city.frag, painted from the desktop) and
// the actions hang over it as five vertical neon signs in katakana, the way
// signs climb the buildings in Kabukichō: ロック lock, スリープ sleep,
// ログアウト log out, 再起動 reboot, 電源オフ halt. Unlit, their tubes glow
// dull; pointed at, one stutters on and buzzes. A halt shorts the signs out
// one after another until the street goes dark; a reboot tears the city up
// like a bad signal (shaders/lock_glitch.frag); a log out collapses the
// feed to a line (shaders/lock_crt.frag).
PowerScene {
    id: scene

    introMs: 900
    outroMs: 340
    riteMs: 2600
    quickMs: 300
    ambient: true

    readonly property var kana: ["ロック", "スリープ", "ログアウト", "再起動", "電源オフ"]
    readonly property var labels: ["LOCK", "SLEEP", "LOG OUT", "REBOOT", "HALT"]
    readonly property var tubes: [Neon.b, Neon.a, Neon.b, Neon.a, Neon.danger]
    // Hung at different heights, as signs on a street are.
    readonly property var drops: [0, 46, -18, 30, 8]

    readonly property real signW: 112 * sc
    readonly property real pitch: 190 * sc
    readonly property real signTop: 270 * sc

    readonly property real city: ease(intro, 0, 0.7)

    // A neon tube doesn't fade, it stutters: p through from..to as a
    // flicker that ends lit.
    function stutter(p, from, to) {
        const x = (p - from) / (to - from);
        if (x <= 0)
            return 0;
        if (x >= 1)
            return 1;
        return [0.9, 0, 0.35, 1, 0, 0.7, 0.15, 1][Math.floor(x * 8)];
    }

    // A halt puts the signs out one by one, the chosen one last.
    function shortOut(i) {
        if (chosenId !== "poweroff")
            return 1;
        const order = [0, 1, 2, 3, 4].filter(j => j !== chosen).concat([chosen]);
        const k = order.indexOf(i);
        return 1 - stutter(rite, 0.08 + k * 0.1, 0.18 + k * 0.1);
    }

    // ── The street ───────────────────────────────────────────────────────

    Rectangle {
        anchors.fill: parent
        visible: scene.chosen >= 0 && !scene.quickChosen
        color: "black"
    }

    Item {
        id: street
        anchors.fill: parent

        readonly property bool tearing: scene.chosenId === "reboot"
        readonly property bool cutting: scene.chosenId === "logout"
        // The city's lights going down with the signs.
        readonly property real lights: scene.chosenId === "poweroff" ? 1 - scene.ease(scene.rite, 0.1, 0.7) : 1

        layer.enabled: (tearing || cutting) && scene.rite > 0.25
        layer.effect: tearing ? glitchFx : crtFx

        PowerGrade {
            menu: scene.menu
            amount: scene.city
            saturation: 0.3
            brightness: 0.35
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 1 - street.lights
        }

        ShaderEffect {
            anchors.fill: parent
            opacity: scene.city * street.lights

            property variant wall: scene.menu.world
            property real itemWidth: width
            property real itemHeight: height
            property real time: scene.menu.time
            property real rain: 1
            property color nightColor: Neon.night
            property color neonA: Neon.a
            property color neonB: Neon.b

            fragmentShader: Qt.resolvedUrl("../../shaders/lock_neon_city.frag.qsb")
        }

        // ── JACK OUT? ────────────────────────────────────────────────────

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 82 * scene.sc
            spacing: 10 * scene.sc
            opacity: scene.stutter(scene.intro, 0.25, 0.7) * (1 - scene.aside)

            NeonText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "JACK OUT?"
                family: Neon.logo
                size: 64 * scene.sc
                letterSpacing: 6 * scene.sc
                split: 3 * scene.sc
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "接続を切断しますか  //  " + Neon.shift(scene.menu.now)
                font.family: Neon.kana
                font.pixelSize: 15 * scene.sc
                font.letterSpacing: 2 * scene.sc
                color: Neon.alpha(Neon.ink, 0.75)
            }
        }

        // ── The signs ────────────────────────────────────────────────────

        Repeater {
            model: scene.actions.length

            Item {
                id: sign

                required property int index
                readonly property bool lit: scene.current === index
                readonly property bool picked: scene.chosen === index
                readonly property color tube: scene.tubes[index]

                // On (1) or just glowing dull (0); stutters on when pointed at.
                property real power: 0
                onLitChanged: {
                    if (lit) {
                        powerOn.restart();
                    } else {
                        powerOn.stop();
                        power = 0;
                    }
                }
                NumberAnimation {
                    id: powerOn
                    target: sign
                    property: "power"
                    from: 0
                    to: 1
                    duration: 300
                }
                readonly property real on: scene.stutter(power, 0, 1) * (picked && scene.quickChosen ? 1 - 0.8 * (Math.floor(scene.rite * 8) % 2) : 1)

                // Signs come on down the street as it opens; a halt shorts
                // them out.
                readonly property real alive: scene.stutter(scene.intro, 0.3 + index * 0.07, 0.6 + index * 0.07) * scene.shortOut(index)
                // A dull tube still flickers now and then.
                readonly property real dull: 0.2 + 0.05 * Math.sin(scene.menu.time * (2 + index) + index * 7) * (Math.sin(scene.menu.time * 0.7 + index * 3) > 0.92 ? 4 : 1)
                readonly property real glow: alive * (dull + (1 - dull) * on)

                x: scene.width / 2 + (index - 2) * scene.pitch - width / 2
                y: scene.signTop + scene.drops[index] * scene.sc
                width: scene.signW
                height: board.height + 64 * scene.sc
                // Hung up as the street opens; dead tubes are lost in the
                // dark once it's out.
                opacity: scene.stutter(scene.intro, 0.3 + index * 0.07, 0.6 + index * 0.07) * (1 - (scene.chosenId === "poweroff" ? 0.92 * scene.ease(scene.rite, 0.55, 0.8) : 0))

                // A lit sign lights up the street round it.
                Shape {
                    x: board.width / 2 - width / 2
                    y: board.height / 2 - height / 2
                    width: board.width * 4
                    height: board.height * 1.6
                    opacity: 0.3 * sign.on * sign.alive
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: RadialGradient {
                            centerX: board.width * 2
                            centerY: board.height * 0.8
                            centerRadius: board.height * 0.8
                            focalX: centerX
                            focalY: centerY
                            GradientStop { position: 0; color: sign.tube }
                            GradientStop { position: 1; color: "transparent" }
                        }
                        startX: 0
                        startY: 0
                        PathLine { x: board.width * 4; y: 0 }
                        PathLine { x: board.width * 4; y: board.height * 1.6 }
                        PathLine { x: 0; y: board.height * 1.6 }
                        PathLine { x: 0; y: 0 }
                    }
                }

                // The bracket it hangs from.
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -30 * scene.sc
                    width: 3 * scene.sc
                    height: 30 * scene.sc
                    color: "#2a2c33"
                }

                Rectangle {
                    id: board
                    width: parent.width
                    height: kanaText.implicitHeight + 44 * scene.sc
                    radius: 6 * scene.sc
                    color: Neon.alpha(Neon.night, 0.88)
                    border.width: 2.5 * scene.sc
                    border.color: Qt.tint(Neon.alpha(sign.tube, 0.25 + 0.75 * sign.glow), Neon.alpha("white", 0.25 * sign.on * sign.alive))
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: sign.tube
                        shadowOpacity: sign.glow
                        shadowBlur: 0.9
                        blurMax: 32
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                    }
                }

                Text {
                    id: kanaText
                    anchors.horizontalCenter: board.horizontalCenter
                    y: 22 * scene.sc
                    text: scene.kana[sign.index].split("").join("\n")
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 0.98
                    font.family: Neon.kana
                    font.weight: Font.Black
                    font.pixelSize: 54 * scene.sc
                    font.features: ({ "vert": 1 })
                    color: Qt.tint(Neon.alpha(sign.tube, 0.16 + 0.84 * sign.glow), Neon.alpha("white", 0.55 * sign.on * sign.alive))
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: sign.tube
                        shadowOpacity: sign.glow * sign.glow
                        shadowBlur: 0.85
                        blurMax: 28
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                    }
                }

                // Its plate.
                Text {
                    anchors.horizontalCenter: board.horizontalCenter
                    y: board.height + 18 * scene.sc
                    text: scene.labels[sign.index]
                    font.family: Neon.ui
                    font.pixelSize: 19 * scene.sc
                    font.letterSpacing: 2 * scene.sc
                    color: sign.lit ? Qt.lighter(sign.tube, 1.3) : Neon.alpha(Neon.ink, 0.6)
                    opacity: sign.alive * (1 - (sign.picked || scene.quickChosen ? 0 : scene.aside))
                }

                // Sparks when it shorts out.
                Repeater {
                    model: scene.chosenId === "poweroff" ? 10 : 0

                    Rectangle {
                        required property int index
                        readonly property real t0: {
                            const order = [0, 1, 2, 3, 4].filter(j => j !== scene.chosen).concat([scene.chosen]);
                            return 0.14 + order.indexOf(sign.index) * 0.1;
                        }
                        readonly property real age: (scene.rite - t0) / 0.12
                        readonly property real a: index * 2.4 + sign.index
                        visible: age > 0 && age < 1
                        x: board.width / 2 + Math.cos(a) * age * 70 * scene.sc
                        y: board.height * 0.3 + Math.sin(a) * age * 50 * scene.sc + age * age * 60 * scene.sc
                        width: 3 * scene.sc
                        height: width
                        radius: width / 2
                        color: index % 2 === 0 ? "white" : Neon.hazard
                        opacity: 1 - age
                    }
                }

                PowerHit {
                    anchors.fill: parent
                    menu: scene.menu
                    index: sign.index
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: scene.height - 96 * scene.sc
            opacity: scene.stutter(scene.intro, 0.6, 1) * 0.7 * (1 - scene.aside)
            text: "ESC  //  STAY JACKED IN"
            font.family: Neon.ui
            font.pixelSize: 15 * scene.sc
            font.letterSpacing: 3 * scene.sc
            color: Neon.b
        }

        // Street cred, as on the desktop.
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 64 * scene.sc
            y: scene.height - 96 * scene.sc
            opacity: scene.stutter(scene.intro, 0.5, 0.9) * 0.85 * (1 - scene.aside)
            text: "NETRUNNER " + scene.menu.userName.toUpperCase() + "  //  STREET CRED " + Services.LockStats.level
            font.family: Neon.ui
            font.pixelSize: 15 * scene.sc
            font.letterSpacing: 2 * scene.sc
            color: Neon.a
        }
    }

    // ── What's left on the screen ────────────────────────────────────────

    Column {
        anchors.centerIn: parent
        visible: scene.chosen >= 0 && !scene.quickChosen
        spacing: 16 * scene.sc
        opacity: scene.chosenId === "poweroff" ? scene.stutter(scene.rite, 0.68, 0.86) : scene.stutter(scene.rite, 0.75, 0.95)

        NeonText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: scene.chosenId === "poweroff" ? "おやすみ" : scene.chosenId === "reboot" ? "再起動中" : "切断"
            family: Neon.kana
            weight: Font.Black
            size: 72 * scene.sc
            split: 2 * scene.sc
            neonA: scene.chosenId === "poweroff" ? Neon.danger : Neon.a
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: scene.chosenId === "poweroff" ? "GOOD NIGHT, " + scene.menu.userName.toUpperCase() : scene.chosenId === "reboot" ? "REBOOTING  //  BACK ONLINE SOON" : "CONNECTION TERMINATED"
            font.family: Neon.ui
            font.pixelSize: 17 * scene.sc
            font.letterSpacing: 4 * scene.sc
            color: Neon.alpha(Neon.ink, 0.75)
        }
    }

    Component {
        id: glitchFx
        ShaderEffect {
            property real itemWidth: street.width
            property real itemHeight: street.height
            property real progress: scene.ease(scene.rite, 0.25, 0.8)
            property color neonA: Neon.a
            property color neonB: Neon.b

            fragmentShader: Qt.resolvedUrl("../../shaders/lock_glitch.frag.qsb")
        }
    }

    Component {
        id: crtFx
        ShaderEffect {
            property real itemWidth: street.width
            property real itemHeight: street.height
            property real crt: 0.6
            property real bloom: 0.4
            property real squashX: 1 - scene.ease(scene.rite, 0.5, 0.62)
            property real squashY: 1 - scene.ease(scene.rite, 0.3, 0.5)
            property real flash: Math.sin(Math.PI * scene.lin(scene.rite, 0.28, 0.4))
            property real glitch: 0.3
            property real time: scene.menu.time
            opacity: 1 - scene.lin(scene.rite, 0.62, 0.7)

            fragmentShader: Qt.resolvedUrl("../../shaders/lock_crt.frag.qsb")
        }
    }
}
