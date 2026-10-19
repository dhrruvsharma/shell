pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.colors
import qs.modules.lock.themes.xianxia
import qs.services as Services

// Cave Abode: the desktop sinks into an ink-wash night (shaders/
// power_ink.frag), and five paper talismans hang from a cinnabar cord
// strung across the cave, each brushed with its seal and a run of talisman
// script: 封 seal the abode (lock), 眠 rest (sleep), 离 leave the mountain
// (log out), 轮 rebirth (restart), 寂 nirvana (shut down). Pointed at, a
// talisman wakes with spirit light. Chosen, it slips its string, floats to
// the middle and burns up from the foot (shaders/talisman.frag), its seal
// left hanging in the dark as gold light while the world dissolves into
// ink behind it.
PowerScene {
    id: scene

    introMs: 950
    outroMs: 380
    riteMs: 2800
    quickMs: 300
    ambient: true

    readonly property string brush: "Ma Shan Zheng"
    readonly property string serif: Xian.serif
    readonly property string cjk: Xian.cjk

    // Talisman paper, and the cinnabar it's written in.
    readonly property color paper: "#e2b752"
    readonly property color cinnabar: "#b3261c"
    readonly property color gold: Xian.gold
    readonly property color ink: Qt.tint(Xian.ink, Colors.withAlpha(Colors.tertiary, 0.05))
    readonly property color mist: Qt.tint(Xian.mist, Colors.withAlpha(Colors.tertiary, 0.2))
    readonly property color moon: Xian.paper

    readonly property var hour: Xian.shichen(menu.now)
    readonly property var realm: Xian.realm(Services.LockStats.level)

    readonly property var seals: ["封", "眠", "离", "轮", "寂"]
    readonly property var names: ["Seal the abode", "Rest a while", "Leave the mountain", "Rebirth", "Nirvana"]
    readonly property var afterwords: ({
        logout: "The mountain gate opens before you",
        reboot: "The wheel turns · return renewed",
        poweroff: "Stillness · the abode sleeps"
    })

    // ── Geometry ─────────────────────────────────────────────────────────
    readonly property real tw: 124 * sc
    readonly property real th: 368 * sc
    readonly property real pad: 44 * sc
    readonly property real pitch: 186 * sc
    readonly property real loop: 20 * sc
    // The cord, tied off beyond both edges and sagging to the middle.
    readonly property real cordTop: 222 * sc
    readonly property real sag: 74 * sc

    function cordY(x) {
        const u = (x - width / 2) / (width / 2 + 60 * sc);
        return cordTop + sag * (1 - u * u);
    }

    function hangX(i) {
        return width / 2 + (i - 2) * pitch;
    }

    // Where the chosen talisman burns: the middle, a little high.
    readonly property real burnX: width / 2
    readonly property real burnY: height * 0.43

    // How far into the night, and how far the world is gone to ink.
    readonly property real night: ease(intro, 0, 0.75)
    readonly property real gone: ease(rite, 0.48, 1.0) * (quickChosen ? 0 : 1)

    // A looped stroke down the sheet, the way talisman script runs (a
    // prolate cycloid, different on each sheet).
    function scribble(i, w, h) {
        const n = 3.25 + (i % 3) * 0.5;
        const amp = w * (0.15 + 0.035 * ((i * 7) % 3));
        const b = h * 0.08;
        const k = (h - 2 * b) / (2 * Math.PI * n);
        const phase = i * 1.37;
        const pts = [];
        const steps = 160;
        for (let s = 0; s <= steps; s++) {
            const t = s / steps * 2 * Math.PI * n;
            const x = w / 2 + amp * Math.sin(t + phase) * (0.72 + 0.28 * Math.cos(t * 0.5 + i));
            const y = b + k * t - b * Math.cos(t + phase);
            pts.push(Qt.point(x, y));
        }
        return pts;
    }

    // ── The night ────────────────────────────────────────────────────────

    ShaderEffect {
        anchors.fill: parent
        opacity: scene.menu.hasWorld ? 1 : scene.night

        property variant source: scene.menu.world
        property real itemWidth: width
        property real itemHeight: height
        property real amount: scene.menu.hasWorld ? scene.night : 1
        property real dissolve: scene.gone
        property real time: scene.menu.time
        property point origin: Qt.point(scene.burnX / scene.width, scene.burnY / scene.height)
        property color inkColor: scene.ink
        property color mistColor: scene.mist
        property color goldColor: scene.gold
        property color moteColor: Qt.tint(Colors.tertiary, "#40f5dc95")

        fragmentShader: Qt.resolvedUrl("../../shaders/power_ink.frag.qsb")
    }

    // ── The hour and your realm ──────────────────────────────────────────

    Column {
        readonly property real shown: scene.seg(scene.intro, 0.3, 0.85) * (1 - scene.aside)

        anchors.horizontalCenter: parent.horizontalCenter
        y: 62 * scene.sc - (1 - shown) * 14 * scene.sc
        spacing: 4 * scene.sc
        opacity: shown

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: scene.hour.zh
            font.family: scene.brush
            font.pixelSize: 58 * scene.sc
            color: Colors.withAlpha(scene.moon, 0.92)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: scene.hour.en
            font.family: scene.serif
            font.italic: true
            font.pixelSize: 15 * scene.sc
            font.letterSpacing: 1 * scene.sc
            color: Colors.withAlpha(scene.moon, 0.66)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 4 * scene.sc
            text: scene.realm.zh + (scene.realm.stageZh ? " · " + scene.realm.stageZh : "") + "   " + scene.realm.en + (scene.realm.stageEn ? ", " + scene.realm.stageEn : "")
            font.family: scene.cjk
            font.pixelSize: 12 * scene.sc
            font.letterSpacing: 1 * scene.sc
            color: Colors.withAlpha(scene.moon, 0.42)
        }
    }

    // ── The cord ─────────────────────────────────────────────────────────

    Shape {
        anchors.fill: parent
        opacity: scene.seg(scene.intro, 0.18, 0.5) * (1 - scene.aside * 0.6) * (1 - scene.gone)
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: Colors.withAlpha(scene.cinnabar, 0.95)
            strokeWidth: 2.2 * scene.sc
            capStyle: ShapePath.RoundCap
            startX: -60 * scene.sc
            startY: scene.cordY(-60 * scene.sc)
            PathQuad {
                x: scene.width + 60 * scene.sc
                y: scene.cordY(scene.width + 60 * scene.sc)
                controlX: scene.width / 2
                controlY: 2 * scene.cordY(scene.width / 2) - scene.cordY(-60 * scene.sc)
            }
        }
    }

    // ── The talismans ────────────────────────────────────────────────────

    Repeater {
        model: scene.actions.length

        Item {
            id: slot

            required property int index
            readonly property bool lit: scene.current === index
            readonly property bool picked: scene.chosen === index
            readonly property real shown: scene.seg(scene.intro, 0.28 + index * 0.07, 0.72 + index * 0.055)

            // The chosen one slips its string and floats to the middle; the
            // rest sink into the mist.
            readonly property real lift: picked && !scene.quickChosen ? scene.ease(scene.rite, 0.02, 0.3) : 0
            readonly property real sink: picked || scene.quickChosen ? 0 : scene.ease(scene.rite, 0, 0.22)
            readonly property real burn: picked && !scene.quickChosen ? scene.lin(scene.rite, 0.3, 0.8) : 0

            property real wake: lit || picked ? 1 : 0
            Behavior on wake {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }

            // A lock or sleep: a flash of light, and the menu goes.
            readonly property real flash: picked && scene.quickChosen ? Math.sin(Math.PI * scene.rite) : 0

            readonly property real hx: scene.hangX(index)
            readonly property real hy: scene.cordY(hx)
            readonly property real restX: hx - scene.tw / 2 - scene.pad
            readonly property real restY: hy + scene.loop - scene.pad
            readonly property real liftScale: 1 + 0.28 * lift

            // Swaying on its string, more when woken; still once it's lifted.
            readonly property real sway: (Math.sin(scene.menu.time * 0.9 + index * 1.7) * (0.8 + 0.7 * wake)
                + (1 - shown) * 9 * Math.cos(index)) * (1 - lift)

            x: scene.mix(restX, scene.burnX - scene.tw / 2 - scene.pad, lift)
            y: scene.mix(restY - 6 * scene.sc * wake, scene.burnY - scene.th / 2 - scene.pad, lift) - (1 - shown) * 70 * scene.sc + sink * 46 * scene.sc
            width: scene.tw + 2 * scene.pad
            height: scene.th + 2 * scene.pad
            opacity: shown * (1 - sink)
            scale: liftScale * (1 + 0.035 * wake + 0.05 * flash)
            transform: Rotation {
                origin.x: scene.pad + scene.tw / 2
                origin.y: scene.pad - scene.loop
                angle: slot.sway
            }

            // Its string, and the knot on the cord.
            Shape {
                anchors.fill: parent
                opacity: 1 - slot.lift * 3
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: scene.cinnabar
                    strokeWidth: 1.4 * scene.sc
                    startX: scene.pad + scene.tw / 2 - 9 * scene.sc
                    startY: scene.pad + 1
                    PathLine {
                        x: scene.pad + scene.tw / 2
                        y: scene.pad - scene.loop
                    }
                    PathLine {
                        x: scene.pad + scene.tw / 2 + 9 * scene.sc
                        y: scene.pad + 1
                    }
                }

                ShapePath {
                    fillColor: scene.cinnabar
                    strokeColor: "transparent"
                    PathAngleArc {
                        centerX: scene.pad + scene.tw / 2
                        centerY: scene.pad - scene.loop
                        radiusX: 3.2 * scene.sc
                        radiusY: 3.2 * scene.sc
                        sweepAngle: 360
                    }
                }
            }

            // The sheet: drawn flat, then aged, lit and burned by the shader.
            Item {
                id: sheet
                anchors.fill: parent
                layer.enabled: true
                layer.smooth: true
                layer.effect: ShaderEffect {
                    property real itemWidth: sheet.width
                    property real itemHeight: sheet.height
                    property real pad: scene.pad
                    property real glow: Math.min(1, slot.wake * 0.85 + slot.flash * 0.6 + slot.lift * 0.4)
                    property real burn: slot.burn
                    property real seed: slot.index * 1.618 + 0.4
                    property real shadow: (1 - slot.lift) * (1 - slot.sink)
                    property color auraColor: scene.gold
                    property color emberColor: Xian.ember

                    fragmentShader: Qt.resolvedUrl("../../shaders/talisman.frag.qsb")
                }

                Rectangle {
                    x: scene.pad
                    y: scene.pad
                    width: scene.tw
                    height: scene.th
                    color: scene.paper

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 6 * scene.sc
                        color: "transparent"
                        border.width: 2 * scene.sc
                        border.color: scene.cinnabar
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 10 * scene.sc
                        color: "transparent"
                        border.width: 1 * scene.sc
                        border.color: Colors.withAlpha(scene.cinnabar, 0.8)
                    }

                    // 敕令: "by decree".
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 16 * scene.sc
                        text: "敕令"
                        font.family: scene.brush
                        font.pixelSize: 25 * scene.sc
                        color: scene.cinnabar
                    }

                    // The seal itself.
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 46 * scene.sc
                        text: scene.seals[slot.index]
                        font.family: scene.brush
                        font.pixelSize: 86 * scene.sc
                        color: scene.cinnabar
                    }

                    // Its script.
                    Shape {
                        x: 0
                        y: 150 * scene.sc
                        width: scene.tw
                        height: 118 * scene.sc
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: scene.cinnabar
                            strokeWidth: 2.6 * scene.sc
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            PathPolyline {
                                path: scene.scribble(slot.index, scene.tw, 118 * scene.sc)
                            }
                        }

                        // Two strokes across its head, as talismans start.
                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: scene.cinnabar
                            strokeWidth: 2.4 * scene.sc
                            capStyle: ShapePath.RoundCap
                            startX: scene.tw * 0.26
                            startY: 2 * scene.sc
                            PathQuad {
                                x: scene.tw * 0.74
                                y: 0
                                controlX: scene.tw * 0.5
                                controlY: -5 * scene.sc
                            }
                        }
                    }

                    // 急急如律令: "swiftly, as the law commands".
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 274 * scene.sc
                        text: "急\n急\n如\n律\n令"
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight: 0.84
                        font.family: scene.brush
                        font.pixelSize: 17 * scene.sc
                        color: Colors.withAlpha(scene.cinnabar, 0.9)
                    }
                }
            }

            PowerHit {
                x: scene.pad
                y: scene.pad
                width: scene.tw
                height: scene.th
                menu: scene.menu
                index: slot.index
            }
        }
    }

    // What each one does, under it.
    Repeater {
        model: scene.actions.length

        Column {
            id: label

            required property int index
            readonly property bool lit: scene.current === index
            readonly property real shown: scene.seg(scene.intro, 0.55 + index * 0.04, 0.95)

            x: scene.hangX(index) - width / 2
            y: scene.cordY(scene.hangX(index)) + scene.loop + scene.th + 26 * scene.sc
            spacing: 4 * scene.sc
            opacity: shown * (1 - scene.aside) * (lit ? 1 : 0.62)

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: scene.names[label.index]
                font.family: scene.serif
                font.italic: true
                font.pixelSize: 17 * scene.sc
                color: label.lit ? scene.gold : scene.moon
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: scene.actions[label.index].label.toUpperCase()
                font.family: scene.serif
                font.pixelSize: 10 * scene.sc
                font.letterSpacing: 3 * scene.sc
                color: Colors.withAlpha(scene.moon, 0.55)
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.height - 86 * scene.sc
        opacity: scene.seg(scene.intro, 0.7, 1) * 0.55 * (1 - scene.aside)
        text: "Esc · remain in seclusion"
        font.family: scene.serif
        font.italic: true
        font.pixelSize: 14 * scene.sc
        font.letterSpacing: 1 * scene.sc
        color: scene.moon
    }

    // ── The burning ──────────────────────────────────────────────────────

    // Sparks off the burning front.
    Repeater {
        model: scene.chosen >= 0 && !scene.quickChosen ? 22 : 0

        Rectangle {
            id: spark

            required property int index
            readonly property real h1: (Math.sin(index * 12.9898) * 43758.5453) % 1
            readonly property real r1: Math.abs(h1)
            readonly property real r2: Math.abs((Math.sin(index * 78.233) * 43758.5453) % 1)
            readonly property real born: 0.32 + 0.44 * r1
            readonly property real age: (scene.rite - born) / (0.16 + 0.1 * r2)
            readonly property real frontY: scene.burnY + scene.th * 1.28 / 2 - scene.th * 1.28 * Math.min(1, (born - 0.3) / 0.5)

            visible: age > 0 && age < 1
            width: (3 + 3.5 * r2) * scene.sc
            height: width
            radius: width / 2

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 3.2
                height: width
                radius: width / 2
                color: Colors.withAlpha(parent.color, 0.22)
            }
            x: scene.burnX + (r2 - 0.5) * scene.tw * 1.2 + Math.sin(age * 5 + index) * 12 * scene.sc
            y: frontY - age * (110 + 120 * r1) * scene.sc
            opacity: (1 - age) * (0.6 + 0.4 * r1)
            color: index % 3 === 0 ? scene.gold : Xian.ember
        }
    }

    // The seal, left hanging in the dark as light once the paper has burned
    // out from under it, then rising to the middle.
    Item {
        id: afterglow

        // Where the seal sits on the lifted sheet, and where it ends up.
        readonly property real fromY: scene.burnY - scene.th * 0.64 + 90 * scene.sc * 1.28
        readonly property real toY: scene.burnY - 20 * scene.sc
        readonly property real lit: scene.ease(scene.rite, 0.6, 0.72)
        readonly property real rise: scene.ease(scene.rite, 0.7, 0.96)

        visible: scene.chosen >= 0 && !scene.quickChosen && lit > 0
        x: scene.burnX - width / 2
        y: scene.mix(fromY, toY, rise) - height / 2
        width: 340 * scene.sc
        height: 340 * scene.sc
        opacity: lit
        scale: scene.mix(0.45, 1, rise)

        Text {
            id: bigSeal
            anchors.centerIn: parent
            text: scene.seals[Math.max(0, scene.chosen)]
            font.family: scene.brush
            font.pixelSize: 250 * scene.sc
            color: Xian.goldHi
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#d9b35d"
                shadowOpacity: 1
                shadowBlur: 1
                blurMax: 48
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.burnY + 170 * scene.sc
        visible: scene.chosen >= 0 && !scene.quickChosen
        opacity: scene.seg(scene.rite, 0.74, 0.98)
        text: scene.afterwords[scene.chosenId] ?? ""
        font.family: scene.serif
        font.italic: true
        font.pixelSize: 22 * scene.sc
        font.letterSpacing: 1.5 * scene.sc
        color: Colors.withAlpha(scene.moon, 0.86)
    }
}
