pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.colors

// Still: the desktop goes soft and pale behind frosted paper, and in the
// middle there is one thin circle, breathing slowly, with the time inside
// it. Under it, five words, nothing more. A small pebble rests on the
// circle and rolls round to whichever word you point at. Choosing one is a
// long exhale: the circle draws in to a point, the world fades out, and a
// few words are left.
PowerScene {
    id: scene

    introMs: 1100
    outroMs: 420
    riteMs: 2600
    quickMs: 300
    ambient: true

    readonly property color ink: Colors.on_surface
    readonly property color paper: Colors.background
    readonly property string face: "Adwaita Sans"

    readonly property var words: ["lock", "sleep", "sign out", "restart", "shut down"]
    readonly property var partings: ({
        logout: "until next time",
        reboot: "begin again",
        poweroff: "goodnight"
    })

    readonly property real k: ease(intro, 0, 0.8)
    readonly property real cx: width / 2
    readonly property real cy: height * 0.44
    readonly property real ringR: 210 * sc
    // Breathing: in for four seconds, out for four.
    readonly property real breath: 0.5 - 0.5 * Math.cos(menu.time * Math.PI / 4)
    // The exhale.
    readonly property real exhale: quickChosen ? 0 : ease(rite, 0.08, 0.72)
    readonly property real dark: quickChosen ? 0 : ease(rite, 0.3, 0.9)

    function greeting() {
        const h = menu.now.getHours();
        return (h < 5 ? "still night" : h < 12 ? "morning" : h < 17 ? "afternoon" : h < 21 ? "evening" : "night") + ", " + menu.userName;
    }

    // ── The world, behind paper ──────────────────────────────────────────

    Rectangle {
        anchors.fill: parent
        color: scene.paper
        opacity: scene.menu.hasWorld ? 1 : 0
    }

    MultiEffect {
        anchors.fill: parent
        visible: scene.menu.hasWorld
        source: scene.menu.world
        blurEnabled: true
        blur: scene.k
        blurMax: 64
        saturation: -0.45 * scene.k
    }

    Rectangle {
        anchors.fill: parent
        color: scene.paper
        opacity: 0.62 * scene.k
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: scene.dark
    }

    // ── The circle ───────────────────────────────────────────────────────

    Item {
        id: circle

        readonly property real shown: scene.ease(scene.intro, 0.15, 0.85)
        readonly property real r: scene.ringR * (0.92 + 0.08 * shown) * (1 + 0.025 * scene.breath) * (1 - scene.exhale)

        x: scene.cx
        y: scene.cy
        opacity: shown

        Shape {
            x: -circle.r - 2
            y: -circle.r - 2
            width: 2 * circle.r + 4
            height: width
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: Colors.withAlpha(scene.dark > 0.5 ? "white" : scene.ink, 0.42 + 0.3 * scene.exhale)
                strokeWidth: 1.2 * scene.sc

                PathAngleArc {
                    centerX: circle.r + 2
                    centerY: circle.r + 2
                    radiusX: circle.r
                    radiusY: circle.r
                    sweepAngle: 360
                }
            }
        }

        // The pebble, rolling round to what's pointed at (resting at the
        // foot when nothing is).
        Rectangle {
            id: pebble

            readonly property real angle: scene.current >= 0 ? 150 - 30 * scene.current : 90
            property real at: angle
            Behavior on at {
                NumberAnimation {
                    duration: 520
                    easing.type: Easing.InOutCubic
                }
            }

            readonly property real a: at * Math.PI / 180
            width: (9 + 3 * scene.exhale) * scene.sc
            height: width
            radius: width / 2
            x: Math.cos(a) * circle.r - width / 2
            y: Math.sin(a) * circle.r - height / 2
            color: scene.dark > 0.5 ? "white" : scene.ink
            scale: scene.chosen >= 0 && scene.quickChosen ? 1 + 0.6 * Math.sin(Math.PI * scene.rite) : 1
        }

        Column {
            anchors.centerIn: parent
            spacing: 10 * scene.sc
            opacity: scene.seg(scene.intro, 0.35, 0.95) * (1 - scene.ease(scene.rite, 0, 0.3) * (scene.quickChosen ? 0 : 1))

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(scene.menu.now, "h:mm")
                font.family: scene.face
                font.pixelSize: 76 * scene.sc
                font.weight: Font.ExtraLight
                color: scene.ink
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: scene.greeting()
                font.family: scene.face
                font.pixelSize: 15 * scene.sc
                font.weight: Font.Light
                font.letterSpacing: 1.5 * scene.sc
                color: Colors.withAlpha(scene.ink, 0.6)
            }
        }
    }

    // ── The words ────────────────────────────────────────────────────────

    Row {
        id: row
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.cy + scene.ringR + 104 * scene.sc
        spacing: 64 * scene.sc
        opacity: scene.seg(scene.intro, 0.45, 1) * (1 - scene.ease(scene.rite, 0, 0.3) * (scene.quickChosen ? 0 : 1))

        Repeater {
            model: scene.words.length

            Item {
                id: word

                required property int index
                readonly property bool lit: scene.current === index

                property real on: lit ? 1 : 0
                Behavior on on {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutCubic
                    }
                }

                width: label.implicitWidth
                height: label.implicitHeight + 18 * scene.sc

                Text {
                    id: label
                    text: scene.words[word.index]
                    font.family: scene.face
                    font.pixelSize: 21 * scene.sc
                    font.weight: Font.Light
                    font.letterSpacing: 2 * scene.sc
                    color: Colors.withAlpha(scene.ink, 0.38 + 0.62 * word.on)
                }

                Rectangle {
                    anchors.horizontalCenter: label.horizontalCenter
                    y: label.implicitHeight + 10 * scene.sc
                    width: 4 * scene.sc
                    height: width
                    radius: width / 2
                    color: scene.ink
                    opacity: word.on
                }

                PowerHit {
                    anchors.fill: parent
                    anchors.margins: -12 * scene.sc
                    menu: scene.menu
                    index: word.index
                }
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.height - 84 * scene.sc
        opacity: scene.seg(scene.intro, 0.7, 1) * 0.4 * (1 - scene.aside)
        text: "esc  ·  stay"
        font.family: scene.face
        font.pixelSize: 13 * scene.sc
        font.weight: Font.Light
        font.letterSpacing: 3 * scene.sc
        color: scene.ink
    }

    // ── What's left ──────────────────────────────────────────────────────

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.cy + 40 * scene.sc
        visible: scene.chosen >= 0 && !scene.quickChosen
        opacity: scene.seg(scene.rite, 0.62, 0.95)
        text: scene.partings[scene.chosenId] ?? ""
        font.family: scene.face
        font.pixelSize: 26 * scene.sc
        font.weight: Font.Light
        font.letterSpacing: 6 * scene.sc
        color: Colors.withAlpha("white", 0.82)
    }
}
