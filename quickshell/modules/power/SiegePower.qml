pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.colors
import qs.components
import qs.modules.lock
import qs.modules.lock.themes.siege
import qs.services as Services

// Siege: night falls on the desktop (the Portcullis lock's moonlight and
// torchlight, shaders/lock_nightfall.frag) and you stand on the
// battlements: the parapet runs along the foot of the screen, torches burn
// on it (shaders/torch.frag), and five war banners fly from poles planted
// between the merlons, each dyed its own tincture and charged with its
// sign: a key for Raise the drawbridge (lock), a crescent for Stand down
// (sleep), a knight for Ride out (log out), crossed swords for Regroup
// (restart), a tent for Strike camp (shut down). Your arms and motto fly
// over them. Pointed at, a banner lifts in the wind and the torchlight
// catches it. Striking camp lowers the banners one by one and puts the
// torches out; regrouping dips them all and raises them again.
PowerScene {
    id: scene

    introMs: 1000
    outroMs: 380
    riteMs: 3200
    quickMs: 300
    ambient: true

    readonly property var names: ["Raise the drawbridge", "Stand down", "Ride out", "Regroup", "Strike camp"]
    readonly property var glosses: ["lock", "sleep", "log out", "restart", "shut down"]
    readonly property var fields: [War.paints.azure, War.paints.purpure, War.paints.vert, War.paints["tenné"], War.paints.gules]
    readonly property var charges: ["key", "bedtime", "♞", "swords", "camping"]
    readonly property var proclamations: ({
        logout: ["Ride out", "Godspeed, " + War.hold],
        reboot: ["Regroup at first light", "the host will muster again"],
        poweroff: ["The host strikes camp", "the watch passes to the night"]
    })

    readonly property real wallTop: height * 0.7
    readonly property real pitch: 300 * sc
    readonly property real bannerW: 156 * sc
    readonly property real bannerH: 300 * sc
    readonly property real poleTop: height * 0.25

    function poleX(i) {
        return width / 2 + (i - 2) * pitch;
    }

    // Torches between the banners, and one at each end.
    readonly property var torches: [width / 2 - 2.5 * pitch, width / 2 - 1.5 * pitch, width / 2 - 0.5 * pitch, width / 2 + 0.5 * pitch, width / 2 + 1.5 * pitch, width / 2 + 2.5 * pitch]

    readonly property real nightfall: ease(intro, 0, 0.75)
    readonly property real torchlight: quickChosen ? 1 : chosenId === "poweroff" || chosenId === "logout" ? 1 - ease(rite, 0.45, 0.85) : 1
    readonly property real dark: quickChosen || chosenId === "reboot" ? (chosenId === "reboot" ? ease(rite, 0.7, 0.95) : 0) : ease(rite, 0.5, 0.92)

    // How far a banner has been struck (lowered down its pole), 0..1.
    function struck(i) {
        if (chosen < 0)
            return 0;
        if (quickChosen)
            return i === chosen ? 0.25 * Math.sin(Math.PI * rite) : 0;
        if (chosenId === "reboot") {
            // All dip together and are raised again.
            return 0.6 * Math.sin(Math.PI * ease(rite, 0.08, 0.62));
        }
        const order = [0, 4, 1, 3, 2].filter(j => j !== chosen).concat([chosen]);
        const k = order.indexOf(i);
        return ease(rite, 0.08 + k * 0.08, 0.22 + k * 0.08);
    }

    // ── Night on the walls ───────────────────────────────────────────────

    ShaderEffect {
        anchors.fill: parent
        opacity: scene.menu.hasWorld ? 1 : scene.nightfall

        property variant source: scene.menu.world
        property real itemWidth: width
        property real itemHeight: height
        property real night: scene.nightfall
        property real light: 0.9 * scene.torchlight
        property real reach: 360 * scene.sc
        property point torchA: Qt.point(scene.torches[0], scene.wallTop - 60 * scene.sc)
        property point torchB: Qt.point(scene.torches[5], scene.wallTop - 60 * scene.sc)
        property color moonColor: War.moon
        property color fireColor: War.fire

        fragmentShader: Qt.resolvedUrl("../../shaders/lock_nightfall.frag.qsb")
    }

    Rectangle {
        anchors.fill: parent
        color: "#050405"
        opacity: scene.dark * 0.96
    }

    // ── Your arms ────────────────────────────────────────────────────────

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 40 * scene.sc
        spacing: 8 * scene.sc
        opacity: scene.seg(scene.intro, 0.35, 0.9) * (1 - scene.aside)

        Arms {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 84 * scene.sc
            height: 100 * scene.sc
            glow: 0.3
        }

        Scroll {
            anchors.horizontalCenter: parent.horizontalCenter
            text: War.arms.motto
            band: 24 * scene.sc
            line: scene.sc
            font.family: War.book
            font.italic: true
            font.pixelSize: 15 * scene.sc
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "The Siege of " + War.hold + "  ·  day " + War.siegeDay(scene.menu.now) + "  ·  " + War.watch(scene.menu.now).name.toLowerCase()
            font.family: War.book
            font.pixelSize: 17 * scene.sc
            color: War.alpha(War.ivory, 0.8)
        }
    }

    // ── The banners ──────────────────────────────────────────────────────

    Repeater {
        model: scene.actions.length

        Item {
            id: flag

            required property int index
            readonly property bool lit: scene.current === index
            readonly property bool picked: scene.chosen === index
            readonly property real shown: scene.seg(scene.intro, 0.3 + index * 0.06, 0.75 + index * 0.05)
            readonly property real down: scene.struck(index)
            readonly property color field: scene.fields[index]

            property real lift: lit || picked ? 1 : 0
            Behavior on lift {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }

            readonly property real poleH: scene.wallTop - scene.poleTop + 30 * scene.sc

            x: scene.poleX(index)
            y: scene.poleTop
            opacity: flag.shown * (1 - scene.dark)

            // The pole, planted on the wall.
            Rectangle {
                x: -4 * scene.sc
                y: -14 * scene.sc
                width: 8 * scene.sc
                height: flag.poleH + 14 * scene.sc
                radius: 3 * scene.sc
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#3a2616" }
                    GradientStop { position: 0.5; color: "#7a5a3a" }
                    GradientStop { position: 1; color: "#2a1a0e" }
                }
            }

            // Its head.
            Rectangle {
                x: -7 * scene.sc
                y: -26 * scene.sc
                width: 14 * scene.sc
                height: 14 * scene.sc
                radius: 7 * scene.sc
                color: War.or
                border.width: 1
                border.color: "#2a1a0e"
            }

            // The banner, on its crossbar: struck, it comes down the pole.
            Item {
                id: cloth

                y: (flag.poleH - scene.bannerH - 30 * scene.sc) * flag.down
                width: 0
                height: 0
                // Swinging in the wind, more when it's lifted to you.
                rotation: Math.sin(scene.menu.time * 1.1 + flag.index * 1.9) * (1.2 + 1.8 * flag.lift) * (1 - flag.down)
                    + (1 - flag.shown) * 8

                // Torchlight on it when it's pointed at.
                Rectangle {
                    x: -scene.bannerW * 0.85
                    y: -10 * scene.sc
                    width: scene.bannerW * 1.7
                    height: scene.bannerH * 1.15
                    radius: width / 2
                    color: War.fire
                    opacity: 0.16 * flag.lift
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: 1
                        blurMax: 48
                    }
                }

                Shape {
                    id: bannerShape
                    x: -scene.bannerW / 2
                    y: 6 * scene.sc
                    width: scene.bannerW
                    height: scene.bannerH
                    preferredRendererType: Shape.CurveRenderer

                    readonly property color cloth: Qt.tint(flag.field, Colors.withAlpha(War.fire, 0.18 * flag.lift))

                    ShapePath {
                        strokeColor: Colors.withAlpha("black", 0.6)
                        strokeWidth: 1
                        joinStyle: ShapePath.MiterJoin
                        fillGradient: LinearGradient {
                            x1: 0
                            y1: 0
                            x2: scene.bannerW
                            y2: 0
                            GradientStop { position: 0; color: Qt.lighter(bannerShape.cloth, 1.25) }
                            GradientStop { position: 0.5; color: bannerShape.cloth }
                            GradientStop { position: 1; color: Qt.darker(bannerShape.cloth, 1.35) }
                        }
                        PathPolyline {
                            path: ThemeShapes.banner(0, 0, scene.bannerW, scene.bannerH, 46 * scene.sc, 1)
                        }
                    }

                    // An embroidered border of argent.
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Colors.withAlpha(War.argent, 0.55)
                        strokeWidth: 1.4 * scene.sc
                        strokeStyle: ShapePath.DashLine
                        dashPattern: [3, 2]
                        joinStyle: ShapePath.MiterJoin
                        PathPolyline {
                            path: ThemeShapes.banner(9 * scene.sc, 10 * scene.sc, scene.bannerW - 18 * scene.sc, scene.bannerH - 16 * scene.sc, 40 * scene.sc, 1)
                        }
                    }
                }

                // The charge.
                Glyph {
                    x: -width / 2
                    y: scene.bannerH * 0.32
                    visible: scene.charges[flag.index].length > 1
                    text: scene.charges[flag.index]
                    filled: true
                    font.pixelSize: 64 * scene.sc
                    color: flag.index === 3 ? War.argent : War.or
                }

                Text {
                    x: -width / 2
                    y: scene.bannerH * 0.27
                    visible: scene.charges[flag.index].length === 1
                    text: scene.charges[flag.index]
                    font.family: "DejaVu Sans"
                    font.pixelSize: 72 * scene.sc
                    color: War.argent
                }

                // The crossbar, and its finials.
                Rectangle {
                    x: -scene.bannerW / 2 - 8 * scene.sc
                    y: 0
                    width: scene.bannerW + 16 * scene.sc
                    height: 8 * scene.sc
                    radius: 4 * scene.sc
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#7a5a3a" }
                        GradientStop { position: 1; color: "#3a2616" }
                    }
                    border.width: 0.5
                    border.color: "#0b0a0a"
                }
            }

            PowerHit {
                x: -scene.bannerW / 2 - 10 * scene.sc
                y: -20 * scene.sc
                width: scene.bannerW + 20 * scene.sc
                height: scene.bannerH + 60 * scene.sc
                menu: scene.menu
                index: flag.index
            }
        }
    }

    // ── The parapet ──────────────────────────────────────────────────────

    ShaderEffect {
        id: parapet

        readonly property real shown: scene.seg(scene.intro, 0.15, 0.6)

        x: 0
        y: scene.wallTop - 40 * scene.sc + (1 - shown) * 80 * scene.sc
        width: scene.width
        height: scene.height - scene.wallTop + 40 * scene.sc
        opacity: shown * (1 - scene.dark)

        property real itemWidth: width
        property real itemHeight: height
        property real merlon: 120 * scene.sc
        property real depth: 56 * scene.sc
        property real course: 46 * scene.sc
        property real light: scene.torchlight
        property real reach: 150 * scene.sc
        property vector4d torchA: Qt.vector4d(scene.torches[0], 20 * scene.sc, scene.torches[1], 20 * scene.sc)
        property vector4d torchB: Qt.vector4d(scene.torches[2], 20 * scene.sc, scene.torches[3], 20 * scene.sc)
        property vector4d torchC: Qt.vector4d(scene.torches[4], 20 * scene.sc, scene.torches[5], 20 * scene.sc)
        property color stoneColor: "#3d3b38"
        property color moonColor: War.moon
        property color fireColor: War.fire

        fragmentShader: Qt.resolvedUrl("../../shaders/stone_wall.frag.qsb")
    }

    // Torches along it.
    Repeater {
        model: scene.torches.length

        ShaderEffect {
            required property int index
            x: scene.torches[index] - width / 2
            y: scene.wallTop - 34 * scene.sc - height * 0.94
            width: 84 * scene.sc
            height: 140 * scene.sc
            opacity: scene.seg(scene.intro, 0.4, 0.8) * scene.torchlight * (1 - scene.dark)

            property real itemWidth: width
            property real itemHeight: height
            property real time: scene.menu.time
            property real flare: scene.chosenId === "reboot" ? Math.sin(Math.PI * scene.ease(scene.rite, 0.05, 0.5)) : 0
            property real seed: index * 1.7

            fragmentShader: Qt.resolvedUrl("../../shaders/torch.frag.qsb")
        }
    }

    // What each banner commands, cut in the wall under it.
    Repeater {
        model: scene.actions.length

        Column {
            id: legend

            required property int index
            readonly property bool lit: scene.current === index

            x: scene.poleX(index) - width / 2
            y: scene.wallTop + 92 * scene.sc
            spacing: 3 * scene.sc
            opacity: scene.seg(scene.intro, 0.55, 1) * (1 - scene.aside) * (lit ? 1 : 0.72)

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: scene.names[legend.index]
                font.family: War.display
                font.pixelSize: 25 * scene.sc
                color: legend.lit ? War.fire : War.ivory
                style: Text.Raised
                styleColor: Colors.withAlpha("black", 0.6)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: scene.glosses[legend.index]
                font.family: War.book
                font.italic: true
                font.pixelSize: 15 * scene.sc
                color: War.alpha(War.ivory, 0.6)
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.height - 54 * scene.sc
        opacity: scene.seg(scene.intro, 0.7, 1) * 0.6 * (1 - scene.aside)
        text: "Esc · hold the walls"
        font.family: War.book
        font.italic: true
        font.pixelSize: 15 * scene.sc
        color: War.ivory
    }

    // Embers going up into the dark.
    Repeater {
        model: scene.chosen >= 0 && !scene.quickChosen ? 30 : 0

        Rectangle {
            required property int index
            readonly property real r1: Math.abs((Math.sin(index * 12.9898) * 43758.5453) % 1)
            readonly property real r2: Math.abs((Math.sin(index * 78.233) * 43758.5453) % 1)
            readonly property real age: (scene.rite - 0.35 - r1 * 0.45) / (0.3 + r2 * 0.25)
            visible: age > 0 && age < 1
            x: r2 * scene.width + Math.sin(age * 6 + index) * 24 * scene.sc
            y: scene.wallTop - age * 520 * scene.sc
            width: (2 + r1 * 3) * scene.sc
            height: width
            radius: width / 2
            color: index % 3 === 0 ? War.fire : War.ember
            opacity: (1 - age) * 0.9
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.height * 0.42
        visible: scene.chosen >= 0 && !scene.quickChosen
        opacity: scene.seg(scene.rite, 0.8, 0.98)
        spacing: 10 * scene.sc

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (scene.proclamations[scene.chosenId] ?? ["", ""])[0]
            font.family: War.display
            font.pixelSize: 54 * scene.sc
            color: War.ivory
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (scene.proclamations[scene.chosenId] ?? ["", ""])[1]
            font.family: War.book
            font.italic: true
            font.pixelSize: 20 * scene.sc
            color: War.fire
        }
    }
}
