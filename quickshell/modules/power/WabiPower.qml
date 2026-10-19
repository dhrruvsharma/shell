pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.colors
import qs.modules.lock.themes.wabisabi

// Wabi-sabi: the desktop fades to an old print on washi (a sumi-and-paper
// grade under the theme's paper, shaders/desktop_washi.frag) and a card of
// paper rests in the middle with five characters brushed on it: 閉 close
// (lock), 眠 sleep, 去 leave (log out), 巡 come round (restart), 終 end
// (shut down). Over it, this week's micro-season. Pointing at a character
// draws an ensō round it (the theme's brush, shaders/enso.frag). Choosing
// one closes the circle, cracks it, and mends the cracks with gold as the
// paper darkens round it, and a word of parting is left beneath.
PowerScene {
    id: scene

    introMs: 1000
    outroMs: 380
    riteMs: 3000
    quickMs: 300
    ambient: true

    readonly property string brush: "Yuji Syuku"
    readonly property string serif: Wabi.serif

    readonly property var marks: ["閉", "眠", "去", "巡", "終"]
    readonly property var words: ["close", "sleep", "leave", "come round", "end"]
    readonly property var glosses: ["lock", "sleep", "log out", "restart", "shut down"]
    readonly property var partings: ({
        logout: ["またね", "until we meet again"],
        reboot: ["また巡る", "and round again"],
        poweroff: ["おやすみなさい", "rest well"]
    })

    readonly property var kou: Wabi.season72(menu.now)

    readonly property real cardW: 1120 * sc
    readonly property real cardH: 330 * sc
    readonly property real cardX: (width - cardW) / 2
    readonly property real cardY: height * 0.5 - cardH / 2 + 20 * sc
    readonly property real pitch: 206 * sc

    function markX(i) {
        return width / 2 + (i - 2) * pitch;
    }

    readonly property real markY: cardY + 140 * sc

    readonly property real faded: ease(intro, 0, 0.75)
    // The paper darkening round the mended circle.
    readonly property real dusk: quickChosen ? 0 : ease(rite, 0.55, 0.95)

    // ── The old print ────────────────────────────────────────────────────

    PowerGrade {
        menu: scene.menu
        amount: scene.faded
        saturation: 0.2
        brightness: 0.82
        duo: 0.85
        shadowColor: "#2b241d"
        lightColor: "#b3a68c"
        vignette: 0.35
    }

    ShaderEffect {
        anchors.fill: parent
        opacity: scene.faded * 0.75

        property real itemWidth: width
        property real itemHeight: height
        property real paper: 0.55
        property real age: 1
        property real seam: scene.seg(scene.intro, 0.4, 1)
        property real lineScale: 1
        property color paperColor: Wabi.paper
        property color ageColor: "#5a3d22"
        property color goldColor: Wabi.gold
        property color goldHi: Wabi.goldHi

        fragmentShader: Qt.resolvedUrl("../../shaders/desktop_washi.frag.qsb")
    }

    Rectangle {
        anchors.fill: parent
        color: "#0c0a08"
        opacity: scene.dusk * 0.94
    }

    // ── The season ───────────────────────────────────────────────────────

    // A soft pool of paper behind it, so it reads on the print.
    Shape {
        x: scene.width / 2 - width / 2
        y: scene.cardY - 128 * scene.sc - height / 2
        width: 1000 * scene.sc
        height: 1000 * scene.sc
        opacity: scene.seg(scene.intro, 0.3, 0.9) * (1 - scene.aside) * 0.8
        transform: Scale {
            origin.x: 500 * scene.sc
            origin.y: 500 * scene.sc
            yScale: 0.3
        }
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: 500 * scene.sc
                centerY: 500 * scene.sc
                centerRadius: 500 * scene.sc
                focalX: centerX
                focalY: centerY
                GradientStop { position: 0; color: Colors.withAlpha(Wabi.paper, 0.8) }
                GradientStop { position: 0.5; color: Colors.withAlpha(Wabi.paper, 0.35) }
                GradientStop { position: 1; color: "transparent" }
            }
            PathAngleArc {
                centerX: 500 * scene.sc
                centerY: 500 * scene.sc
                radiusX: 500 * scene.sc
                radiusY: 500 * scene.sc
                sweepAngle: 360
            }
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.cardY - height - 54 * scene.sc
        spacing: 6 * scene.sc
        opacity: scene.seg(scene.intro, 0.35, 0.9) * (1 - scene.aside)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: scene.kou.ja
            font.family: scene.brush
            font.pixelSize: 40 * scene.sc
            color: Wabi.sumi
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: scene.kou.en.toLowerCase()
            font.family: scene.serif
            font.weight: Font.Light
            font.pixelSize: 16 * scene.sc
            font.letterSpacing: 1 * scene.sc
            color: Colors.withAlpha(Wabi.sumi, 0.8)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 2 * scene.sc
            text: Wabi.eraYear(scene.menu.now) + "  " + Wabi.date(scene.menu.now) + "  ·  " + scene.kou.sekki.ja
            font.family: scene.serif
            font.pixelSize: 12 * scene.sc
            font.letterSpacing: 2 * scene.sc
            color: Colors.withAlpha(Wabi.sumi, 0.6)
        }
    }

    // ── The card ─────────────────────────────────────────────────────────

    Item {
        id: card

        readonly property real shown: scene.seg(scene.intro, 0.2, 0.7)

        x: scene.cardX
        y: scene.cardY + (1 - shown) * 18 * scene.sc
        width: scene.cardW
        height: scene.cardH
        opacity: shown * (1 - scene.dusk)

        Rectangle {
            id: sheet
            anchors.fill: parent
            readonly property real r: 30 * scene.sc
            topLeftRadius: r * 1
            topRightRadius: r * 0.5
            bottomRightRadius: r * 1.15
            bottomLeftRadius: r * 0.65
            color: Wabi.paper
            border.width: 1
            border.color: Colors.withAlpha("#8a7a5c", 0.5)
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.45
                shadowBlur: 0.8
                blurMax: 40
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 6
            }
        }

        // Its fibres and its foxing, faintly.
        ShaderEffect {
            anchors.fill: sheet
            opacity: 0.5

            property real itemWidth: width
            property real itemHeight: height
            property real paper: 0
            property real age: 0.6
            property real seam: 0
            property real lineScale: 1
            property color paperColor: Wabi.paper
            property color ageColor: "#8b6a43"
            property color goldColor: Wabi.gold
            property color goldHi: Wabi.goldHi

            fragmentShader: Qt.resolvedUrl("../../shaders/desktop_washi.frag.qsb")
        }

        // The seal in the corner.
        Rectangle {
            x: parent.width - 66 * scene.sc
            y: parent.height - 66 * scene.sc
            width: 34 * scene.sc
            height: width
            radius: 3 * scene.sc
            rotation: -3
            color: Wabi.shu
            opacity: 0.88

            Text {
                anchors.centerIn: parent
                text: "寂"
                font.family: scene.brush
                font.pixelSize: 24 * scene.sc
                color: Wabi.paper
            }
        }
    }

    // ── The characters ───────────────────────────────────────────────────

    Repeater {
        model: scene.actions.length

        Item {
            id: mark

            required property int index
            readonly property bool lit: scene.current === index
            readonly property bool picked: scene.chosen === index
            readonly property real shown: scene.seg(scene.intro, 0.35 + index * 0.06, 0.8 + index * 0.04)

            // The brush going round it: drawn while pointed at, gone when not.
            property real draw: 0
            onLitChanged: {
                if (lit) {
                    brushIn.restart();
                } else if (!picked) {
                    brushIn.stop();
                    draw = 0;
                }
            }
            NumberAnimation {
                id: brushIn
                target: mark
                property: "draw"
                from: 0
                to: 1
                duration: 760
                easing.type: Easing.OutCubic
            }

            readonly property real close: picked ? scene.ease(scene.rite, 0, scene.quickChosen ? 0.8 : 0.22) : 0
            readonly property real cracked: picked && !scene.quickChosen ? scene.lin(scene.rite, 0.22, 0.4) : 0
            readonly property real mended: picked && !scene.quickChosen ? scene.ease(scene.rite, 0.42, 0.72) : 0
            // Others step back as one is chosen; the chosen one, mended,
            // comes to the middle.
            readonly property real away: picked || scene.quickChosen ? 0 : scene.ease(scene.rite, 0, 0.3)
            readonly property real centre: picked && !scene.quickChosen ? scene.ease(scene.rite, 0.5, 0.9) : 0

            x: scene.mix(scene.markX(index), scene.width / 2, centre) - width / 2
            y: scene.markY - height / 2
            width: 250 * scene.sc
            height: 250 * scene.sc
            scale: 1 + 0.25 * centre
            opacity: shown * (1 - away)

            Enso {
                anchors.fill: parent
                visible: mark.draw > 0 || mark.close > 0
                // Drawn most of the way round while pointed at; chosen, it
                // closes.
                sweep: scene.mix(mark.draw * 0.9, 1, mark.close)
                start: 0.62
                thickness: 0.13
                bleed: mark.close * 0.4
                cracks: mark.cracked > 0 ? 3 : 0
                gold: mark.mended
                seed: 3.7 + mark.index * 1.3
                crackAt: Qt.vector4d(0.18, 0.47, 0.76, 0.9)
                inkColor: Qt.tint(Wabi.sumi, Colors.withAlpha(Wabi.gold, 0.6 * scene.dusk))
                goldColor: Wabi.goldHi
            }

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -6 * scene.sc
                text: scene.marks[mark.index]
                font.family: scene.brush
                font.pixelSize: 96 * scene.sc
                color: Qt.tint(Wabi.sumi, Colors.withAlpha(Wabi.goldHi, scene.dusk * 0.9))
            }

            PowerHit {
                anchors.centerIn: parent
                width: 170 * scene.sc
                height: 230 * scene.sc
                menu: scene.menu
                index: mark.index
            }
        }
    }

    // Their words, under them on the card.
    Repeater {
        model: scene.actions.length

        Column {
            id: word

            required property int index
            readonly property bool lit: scene.current === index

            x: scene.markX(index) - width / 2
            y: scene.cardY + scene.cardH - 92 * scene.sc
            spacing: 3 * scene.sc
            opacity: scene.seg(scene.intro, 0.55, 1) * (1 - scene.aside) * (lit ? 1 : 0.62)

            Behavior on opacity {
                NumberAnimation {
                    duration: 220
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: scene.words[word.index]
                font.family: scene.serif
                font.weight: Font.Light
                font.pixelSize: 16 * scene.sc
                font.letterSpacing: 1 * scene.sc
                color: Wabi.sumi
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: scene.glosses[word.index]
                font.family: scene.serif
                font.pixelSize: 11 * scene.sc
                font.letterSpacing: 2 * scene.sc
                color: word.lit ? Wabi.shu : Colors.withAlpha(Wabi.sumi, 0.55)
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.height - 92 * scene.sc
        opacity: scene.seg(scene.intro, 0.7, 1) * 0.7 * (1 - scene.aside)
        text: "esc  ·  stay a while"
        font.family: scene.serif
        font.pixelSize: 14 * scene.sc
        font.letterSpacing: 2 * scene.sc
        color: Wabi.sumi
    }

    // ── A word of parting ────────────────────────────────────────────────

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.markY + 175 * scene.sc
        visible: scene.chosen >= 0 && !scene.quickChosen
        opacity: scene.seg(scene.rite, 0.72, 0.98)
        spacing: 8 * scene.sc

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (scene.partings[scene.chosenId] ?? ["", ""])[0]
            font.family: scene.brush
            font.pixelSize: 34 * scene.sc
            color: Wabi.goldHi
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (scene.partings[scene.chosenId] ?? ["", ""])[1]
            font.family: scene.serif
            font.weight: Font.Light
            font.pixelSize: 15 * scene.sc
            font.letterSpacing: 3 * scene.sc
            color: Colors.withAlpha(Wabi.paper, 0.75)
        }
    }
}
