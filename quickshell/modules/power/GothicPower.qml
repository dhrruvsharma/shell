pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.colors
import qs.modules.lock.themes.gothic

// Cathedral: the desktop sinks into the dim of a nave at vespers, shafts of
// stained light and dust in it (shaders/desktop_glass.frag), the rose
// window glowing high above, and under it an arcade of five lancets, each
// glazed in the wallpaper's jewel colours (shaders/lancet.frag) with a
// candle burning before it: Sanctuary (lock), Rest (sleep), Ite, missa est
// (log out), Toll again (restart), Compline (shut down). Pointed at, a
// window fills with light and its candle burns up. Compline and the
// dismissal snuff the candles one by one, the chosen last, and the nave
// goes dark; Toll again rings the bell first.
PowerScene {
    id: scene

    introMs: 1000
    outroMs: 380
    riteMs: 3200
    quickMs: 300
    ambient: true

    readonly property var names: ["Sanctuary", "Rest", "Ite, missa est", "Toll again", "Compline"]
    readonly property var glosses: ["bar the doors · lock", "sleep", "go in peace · log out", "restart", "the close of day · shut down"]
    readonly property var endings: ({
        logout: ["Ite, missa est", "go forth, the office is ended"],
        reboot: ["The bell tolls again", "until the next hour"],
        poweroff: ["Compline", "the day is done · go in peace"]
    })

    readonly property var hour: Gothic.canonicalHour(menu.now)
    readonly property var season: Gothic.season(menu.now)

    readonly property real niW: 150 * sc
    readonly property real niH: 400 * sc
    readonly property real pitch: 232 * sc
    readonly property real niY: 438 * sc
    readonly property real roseD: 250 * sc
    readonly property real roseY: 60 * sc

    function niX(i) {
        return width / 2 + (i - 2) * pitch;
    }

    // An equilateral lancet as a closed outline: straight sides, and a
    // pointed head of two arcs each struck from the other side's springing
    // (the same shape the glass is cut to in shaders/lancet.frag).
    function lancet(x, y, w, h) {
        const s = w * 0.866;
        const pts = [Qt.point(x, y + h), Qt.point(x, y + s)];
        const seg = 16;
        for (let k = 1; k <= seg; k++) {
            const a = (180 + 60 * k / seg) * Math.PI / 180;
            pts.push(Qt.point(x + w + w * Math.cos(a), y + s + w * Math.sin(a)));
        }
        for (let k = 1; k <= seg; k++) {
            const a = (300 + 60 * k / seg) * Math.PI / 180;
            pts.push(Qt.point(x + w * Math.cos(a), y + s + w * Math.sin(a)));
        }
        pts.push(Qt.point(x + w, y + h));
        pts.push(pts[0]);
        return pts;
    }

    readonly property real nave: ease(intro, 0, 0.75)
    // The candles go out from the ends inwards, the chosen one last.
    function snuffAt(i) {
        if (chosen < 0 || quickChosen)
            return 2;
        const order = [0, 4, 1, 3, 2].filter(j => j !== chosen).concat([chosen]);
        return (chosenId === "reboot" ? 0.5 : 0.12) + order.indexOf(i) * 0.09;
    }
    readonly property real dark: quickChosen ? 0 : ease(rite, chosenId === "reboot" ? 0.6 : 0.3, 0.95)

    // ── The nave ─────────────────────────────────────────────────────────

    PowerGrade {
        menu: scene.menu
        amount: scene.nave
        saturation: 0.35
        brightness: 0.4
        contrast: 1.1
        duo: 0.5
        shadowColor: "#0b0c12"
        lightColor: Qt.tint("#8a7d68", Colors.withAlpha(Gothic.candle, 0.25))
        vignette: 0.7
    }

    ShaderEffect {
        anchors.fill: parent
        opacity: scene.nave * (1 - scene.dark)

        property real itemWidth: width
        property real itemHeight: height
        property real light: scene.seg(scene.intro, 0.1, 0.95)
        property real lineScale: 1
        property color glassA: Gothic.glassA
        property color glassB: Gothic.glassB
        property color glassC: Gothic.glassC
        property color glassD: Gothic.glassD
        property color stoneColor: "#0e0d0c"
        property color candleColor: Gothic.candle

        fragmentShader: Qt.resolvedUrl("../../shaders/desktop_glass.frag.qsb")
    }

    Rectangle {
        anchors.fill: parent
        color: "#050405"
        opacity: scene.dark * 0.96
    }

    // ── The rose ─────────────────────────────────────────────────────────

    RoseWindow {
        x: scene.width / 2 - width / 2
        y: scene.roseY
        width: scene.roseD
        height: scene.roseD
        opacity: scene.seg(scene.intro, 0.15, 0.7) * (1 - 0.85 * scene.dark)
        lit: 12
        litInner: 12
        glow: 0.85 + 0.15 * Math.sin(scene.menu.time * 0.5)
        bloom: scene.chosenId === "reboot" ? 0.6 * Math.sin(Math.PI * scene.lin(scene.rite, 0.02, 0.5)) : 0
    }

    // The bell, rung: rings of sound spreading from the rose.
    Repeater {
        model: scene.chosenId === "reboot" ? 3 : 0

        Rectangle {
            required property int index
            readonly property real t: scene.lin(scene.rite, 0.04 + index * 0.16, 0.5 + index * 0.16)
            x: scene.width / 2 - width / 2
            y: scene.roseY + scene.roseD / 2 - height / 2
            width: (scene.roseD + t * 1500 * scene.sc)
            height: width
            radius: width / 2
            visible: t > 0 && t < 1
            color: "transparent"
            border.width: 2 * scene.sc
            border.color: Colors.withAlpha(Gothic.candle, 0.5 * (1 - t))
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.roseY + scene.roseD + 14 * scene.sc
        spacing: 2 * scene.sc
        opacity: scene.seg(scene.intro, 0.4, 0.9) * (1 - scene.aside)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: scene.hour.en
            font.family: Gothic.blackletter
            font.pixelSize: 38 * scene.sc
            color: Gothic.parchment
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (scene.hour.gloss + "  ·  " + scene.season.en + "  ·  " + Gothic.year(scene.menu.now)).toUpperCase()
            font.family: Gothic.caps
            font.pixelSize: 11 * scene.sc
            font.letterSpacing: 2.5 * scene.sc
            color: Colors.withAlpha(Gothic.parchment, 0.6)
        }
    }

    // ── The arcade ───────────────────────────────────────────────────────

    Repeater {
        model: scene.actions.length

        Item {
            id: niche

            required property int index
            readonly property bool lit: scene.current === index
            readonly property bool picked: scene.chosen === index
            readonly property real shown: scene.seg(scene.intro, 0.3 + index * 0.06, 0.75 + index * 0.05)
            readonly property bool burning: scene.rite < scene.snuffAt(index)

            property real glow: lit || picked ? 1 : 0
            Behavior on glow {
                NumberAnimation {
                    duration: 320
                    easing.type: Easing.OutCubic
                }
            }
            readonly property real flare: picked && scene.quickChosen ? Math.sin(Math.PI * scene.rite) : 0

            x: scene.niX(index) - scene.niW / 2
            y: scene.niY + (1 - shown) * 24 * scene.sc
            width: scene.niW
            height: scene.niH
            opacity: shown * (1 - 0.9 * scene.dark)

            // The stone round it.
            Shape {
                x: -14 * scene.sc
                y: -14 * scene.sc
                width: scene.niW + 28 * scene.sc
                height: scene.niH + 22 * scene.sc
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: Colors.withAlpha("#15130f", 0.92)
                    strokeColor: Colors.withAlpha(Gothic.stone, 0.45)
                    strokeWidth: 1.2 * scene.sc
                    joinStyle: ShapePath.RoundJoin

                    PathPolyline {
                        path: scene.lancet(0.5, 0.5, scene.niW + 27 * scene.sc, scene.niH + 21 * scene.sc)
                    }
                }
            }

            ShaderEffect {
                anchors.fill: parent

                property real itemWidth: width
                property real itemHeight: height
                property real light: niche.burning ? 0.3 + 0.7 * niche.glow + 0.3 * niche.flare : 0.05
                property real candle: niche.burning ? 0.5 + 0.5 * niche.glow : 0
                property real seed: niche.index * 7.1 + 2
                property real quarry: 26 * scene.sc
                property color glassA: niche.index % 2 === 0 ? Gothic.glassA : Gothic.glassB
                property color glassB: niche.index % 2 === 0 ? Gothic.glassB : Gothic.glassD
                property color leadColor: Gothic.lead
                property color warmColor: Gothic.candle

                fragmentShader: Qt.resolvedUrl("../../shaders/lancet.frag.qsb")
            }

            // The candle on its sill, and the light it throws.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height - 70 * scene.sc
                width: 220 * scene.sc
                height: 140 * scene.sc
                radius: width / 2
                visible: niche.burning
                opacity: 0.18 + 0.22 * niche.glow
                color: Gothic.candle
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 1
                    blurMax: 48
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height - 8 * scene.sc
                width: parent.width + 20 * scene.sc
                height: 12 * scene.sc
                color: "#2a2620"
                border.width: 1
                border.color: Colors.withAlpha(Gothic.stone, 0.4)
            }

            Candle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height - 8 * scene.sc - height
                size: 1.15 * scene.sc * (1 + 0.06 * niche.glow + 0.1 * niche.flare)
                lit: niche.burning
                time: scene.menu.time
                seed: niche.index * 1.7
            }

            PowerHit {
                anchors.fill: parent
                menu: scene.menu
                index: niche.index
            }
        }
    }

    // Their names under them.
    Repeater {
        model: scene.actions.length

        Column {
            id: label

            required property int index
            readonly property bool lit: scene.current === index

            x: scene.niX(index) - width / 2
            y: scene.niY + scene.niH + 22 * scene.sc
            spacing: 4 * scene.sc
            opacity: scene.seg(scene.intro, 0.55, 1) * (1 - scene.aside) * (lit ? 1 : 0.7)

            Behavior on opacity {
                NumberAnimation {
                    duration: 220
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: scene.names[label.index]
                font.family: Gothic.gotisch
                font.pixelSize: 25 * scene.sc
                color: label.lit ? Gothic.candle : Gothic.parchment
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: scene.glosses[label.index]
                font.family: Gothic.book
                font.italic: true
                font.pixelSize: 14 * scene.sc
                color: Colors.withAlpha(Gothic.parchment, 0.62)
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.height - 82 * scene.sc
        opacity: scene.seg(scene.intro, 0.7, 1) * 0.6 * (1 - scene.aside)
        text: "Esc · remain at prayer"
        font.family: Gothic.book
        font.italic: true
        font.pixelSize: 15 * scene.sc
        color: Gothic.parchment
    }

    // ── The last words ───────────────────────────────────────────────────

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.height * 0.44
        visible: scene.chosen >= 0 && !scene.quickChosen
        opacity: scene.seg(scene.rite, 0.78, 0.98)
        spacing: 10 * scene.sc

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (scene.endings[scene.chosenId] ?? ["", ""])[0]
            font.family: Gothic.blackletter
            font.pixelSize: 64 * scene.sc
            color: Gothic.parchment
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (scene.endings[scene.chosenId] ?? ["", ""])[1]
            font.family: Gothic.book
            font.italic: true
            font.pixelSize: 19 * scene.sc
            font.letterSpacing: 1 * scene.sc
            color: Colors.withAlpha(Gothic.parchment, 0.7)
        }
    }
}
