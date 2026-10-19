pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import qs.colors
import qs.components
import qs.modules.lock.themes.artdeco
import qs.services as Services

// Art Deco: the desktop goes to black lacquer and gold under the theme's
// sunburst and skyline (shaders/desktop_deco.frag), and in the middle stands
// the car panel of the Express Elevator: the half-dial floor indicator over
// a column of five gilt push buttons, each a floor of the grand hotel's
// night: I Do not disturb (lock), II Turn-down (sleep), III Check out (log
// out), IV Encore (restart), V Lights out (shut down). The needle swings to
// whichever button you point at. Pressing one lights it with a ding, and
// for the last three the lift's gilded doors slide shut across the screen
// (the Express Elevator lock's own leaves, shaders/lock_deco_door.frag)
// with a word from the house on them.
PowerScene {
    id: scene

    introMs: 950
    outroMs: 380
    riteMs: 3000
    quickMs: 300
    ambient: true

    readonly property var numerals: ["I", "II", "III", "IV", "V"]
    readonly property var names: ["DO NOT DISTURB", "TURN-DOWN", "CHECK OUT", "ENCORE", "LIGHTS OUT"]
    readonly property var glosses: ["lock", "sleep", "log out", "restart", "shut down"]
    readonly property var plaques: ({
        logout: ["CHECKED OUT", "thank you for staying with us"],
        reboot: ["GOING UP", "back in a moment"],
        poweroff: ["GOOD NIGHT", "the building is closed"]
    })

    readonly property real panelW: 560 * sc
    readonly property real panelH: 830 * sc
    readonly property real panelX: (width - panelW) / 2
    readonly property real panelY: (height - panelH) / 2 + 30 * sc
    readonly property real rowY: panelY + 300 * sc
    readonly property real rowStep: 92 * sc

    readonly property real lacquered: ease(intro, 0, 0.7)
    // The doors: 0 open (off the sides) .. 1 shut.
    readonly property real doors: quickChosen ? 0 : ease(rite, 0.3, 0.64)

    // The needle: over the button pointed at, or resting at the left.
    readonly property real target: current >= 0 ? current / 4 : 0
    property real needle: target
    Behavior on needle {
        SpringAnimation {
            spring: 2.6
            damping: 0.22
            epsilon: 0.002
        }
    }

    // ── Lacquer and gold ─────────────────────────────────────────────────

    PowerGrade {
        menu: scene.menu
        amount: scene.lacquered
        saturation: 0.1
        brightness: 0.6
        duo: 0.8
        shadowColor: Deco.lacquer
        lightColor: Qt.darker(Deco.gold, 1.6)
        vignette: 0.5
    }

    ShaderEffect {
        anchors.fill: parent
        opacity: scene.lacquered * 0.75

        property real itemWidth: width
        property real itemHeight: height
        property real rise: scene.seg(scene.intro, 0.1, 0.9)
        property real lineScale: 1
        property color goldColor: Deco.gold
        property color jewelColor: Deco.jewel
        property color nightColor: Deco.lacquer

        fragmentShader: Qt.resolvedUrl("../../shaders/desktop_deco.frag.qsb")
    }

    // ── The house ────────────────────────────────────────────────────────

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.panelY - height - 34 * scene.sc
        spacing: 6 * scene.sc
        opacity: scene.seg(scene.intro, 0.35, 0.85) * (1 - scene.aside)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "THE " + (scene.menu.hostName || scene.menu.userName).toUpperCase()
            font.family: Deco.marquee
            font.pixelSize: 40 * scene.sc
            font.letterSpacing: 8 * scene.sc
            color: Deco.goldHi
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Deco.hour(scene.menu.now) + "   ·   FLOOR " + Services.LockStats.level + ", " + Deco.floorName(Services.LockStats.level)
            font.family: Deco.ui
            font.pixelSize: 13 * scene.sc
            font.weight: Font.DemiBold
            font.letterSpacing: 4 * scene.sc
            color: Deco.alpha(Deco.ivory, 0.75)
        }
    }

    // ── The car panel ────────────────────────────────────────────────────

    Item {
        id: panel

        readonly property real shown: scene.seg(scene.intro, 0.2, 0.7)

        x: scene.panelX
        y: scene.panelY + (1 - shown) * 30 * scene.sc
        width: scene.panelW
        height: scene.panelH
        opacity: shown

        DecoFrame {
            cut: 14 * scene.sc
            steps: 2
            fill: Deco.alpha(Deco.lacquer, 0.92)
            stroke: Deco.gold
            strokeWidth: 1.6 * scene.sc
            gap: 8 * scene.sc
            innerStroke: Deco.alpha(Deco.gold, 0.4)
        }

        // The floor indicator.
        DecoDial {
            id: dial
            anchors.horizontalCenter: parent.horizontalCenter
            y: 46 * scene.sc
            width: 380 * scene.sc
            value: scene.needle
            ticks: 9
            labels: scene.numerals
            labelSize: 24 * scene.sc
            color: Deco.gold
            needleColor: Deco.goldHi
            labelColor: Deco.ivory
        }

        // The maker's plate at its foot.
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - 92 * scene.sc
            width: 300 * scene.sc
            height: 46 * scene.sc

            DecoFrame {
                cut: 6 * scene.sc
                steps: 1
                fill: Deco.alpha(Deco.goldDeep, 0.35)
                stroke: Deco.alpha(Deco.gold, 0.7)
                strokeWidth: 1 * scene.sc
            }

            Column {
                anchors.centerIn: parent
                spacing: 1 * scene.sc

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "EXPRESS  ·  NONSTOP TO ALL FLOORS"
                    font.family: Deco.ui
                    font.pixelSize: 10 * scene.sc
                    font.weight: Font.DemiBold
                    font.letterSpacing: 2.5 * scene.sc
                    color: Deco.gold
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "capacity one guest"
                    font.family: Deco.display
                    font.pixelSize: 11 * scene.sc
                    font.letterSpacing: 2 * scene.sc
                    color: Deco.alpha(Deco.ivory, 0.6)
                }
            }
        }

        // A rule of chevrons under it.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: dial.y + dial.height + 26 * scene.sc
            spacing: 6 * scene.sc

            Repeater {
                model: 13

                Text {
                    required property int index
                    text: index === 6 ? "◆" : "‹"
                    rotation: index === 6 ? 0 : index < 6 ? 0 : 180
                    font.pixelSize: 14 * scene.sc
                    color: index === 6 ? Deco.goldHi : Deco.alpha(Deco.gold, 0.55)
                }
            }
        }
    }

    // The buttons, each with its brass plate.
    Repeater {
        model: scene.actions.length

        Item {
            id: row

            required property int index
            readonly property bool lit: scene.current === index
            readonly property bool picked: scene.chosen === index
            readonly property real shown: scene.seg(scene.intro, 0.35 + index * 0.06, 0.75 + index * 0.05)

            property real glow: lit || picked ? 1 : 0
            Behavior on glow {
                NumberAnimation {
                    duration: 200
                }
            }
            // Pressed in, and the ding.
            readonly property real press: picked ? Math.sin(Math.PI * scene.lin(scene.rite, 0, scene.quickChosen ? 0.4 : 0.12)) : 0
            readonly property real ding: picked ? Math.sin(Math.PI * scene.lin(scene.rite, 0.04, scene.quickChosen ? 0.9 : 0.3)) : 0

            x: scene.panelX + 66 * scene.sc
            y: scene.rowY + index * scene.rowStep
            width: scene.panelW - 132 * scene.sc
            height: 70 * scene.sc
            opacity: row.shown * (row.picked || scene.quickChosen ? 1 : 1 - scene.aside * 0.6)

            // The button: a gilt ring, its lacquer face lit from behind
            // like the old ones were.
            Item {
                id: button
                width: 64 * scene.sc
                height: width
                anchors.verticalCenter: parent.verticalCenter
                scale: 1 - 0.07 * row.press

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 1.5
                    height: width
                    radius: width / 2
                    color: Deco.jewel
                    opacity: 0.3 * row.glow + 0.3 * row.ding
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: 1
                        blurMax: 32
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0; color: Deco.goldHi }
                        GradientStop { position: 1; color: Deco.goldDeep }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 6 * scene.sc
                    radius: width / 2
                    color: Qt.tint(Deco.lacquerHi, Deco.alpha(Deco.jewel, 0.85 * row.glow))
                    border.width: 1
                    border.color: Deco.goldDeep

                    Text {
                        anchors.centerIn: parent
                        text: scene.numerals[row.index]
                        font.family: Deco.display
                        font.pixelSize: 22 * scene.sc
                        font.weight: Font.DemiBold
                        color: Qt.tint(Deco.gold, Deco.alpha(Deco.ivory, row.glow))
                    }
                }
            }

            Column {
                anchors.left: button.right
                anchors.leftMargin: 26 * scene.sc
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4 * scene.sc

                Text {
                    text: scene.names[row.index]
                    font.family: Deco.ui
                    font.pixelSize: 19 * scene.sc
                    font.weight: Font.DemiBold
                    font.letterSpacing: 4 * scene.sc
                    color: Qt.tint(Deco.gold, Deco.alpha(Deco.goldHi, row.glow))
                }

                Text {
                    text: scene.glosses[row.index]
                    font.family: Deco.display
                    font.pixelSize: 15 * scene.sc
                    font.letterSpacing: 2 * scene.sc
                    color: Deco.alpha(Deco.ivory, 0.55 + 0.35 * row.glow)
                }
            }

            PowerHit {
                anchors.fill: parent
                menu: scene.menu
                index: row.index
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.panelY + scene.panelH + 30 * scene.sc
        opacity: scene.seg(scene.intro, 0.6, 1) * 0.7 * (1 - scene.aside)
        text: "ESC  ·  STAY ON THIS FLOOR"
        font.family: Deco.ui
        font.pixelSize: 12 * scene.sc
        font.weight: Font.DemiBold
        font.letterSpacing: 5 * scene.sc
        color: Deco.gold
    }

    // ── The doors ────────────────────────────────────────────────────────

    // The wallpaper the doors are engraved with.
    Item {
        width: 0
        height: 0
        clip: true

        Image {
            id: wallpaper
            width: scene.width
            height: scene.height
            source: scene.chosen >= 0 && !scene.quickChosen ? scene.menu.wallpaper : ""
            sourceSize: Qt.size(Math.max(1, scene.width), Math.max(1, scene.height))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }
    }

    Leaf {
        x: -width * (1 - scene.doors)
    }

    Leaf {
        rightLeaf: true
        x: scene.width / 2 + width * (1 - scene.doors)
    }

    // A word from the house, on a plaque where the doors meet.
    Item {
        anchors.centerIn: parent
        width: 460 * scene.sc
        height: 150 * scene.sc
        visible: scene.chosen >= 0 && !scene.quickChosen
        opacity: scene.seg(scene.rite, 0.7, 0.92)

        DecoFrame {
            cut: 10 * scene.sc
            steps: 2
            fill: Deco.alpha(Deco.lacquer, 0.94)
            stroke: Deco.gold
            strokeWidth: 1.5 * scene.sc
            gap: 6 * scene.sc
        }

        Column {
            anchors.centerIn: parent
            spacing: 10 * scene.sc

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (scene.plaques[scene.chosenId] ?? ["", ""])[0]
                font.family: Deco.marquee
                font.pixelSize: 36 * scene.sc
                font.letterSpacing: 6 * scene.sc
                color: Deco.goldHi
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (scene.plaques[scene.chosenId] ?? ["", ""])[1]
                font.family: Deco.display
                font.pixelSize: 17 * scene.sc
                font.letterSpacing: 2 * scene.sc
                color: Deco.alpha(Deco.ivory, 0.8)
            }
        }
    }

    component Leaf: ShaderEffect {
        property bool rightLeaf: false
        property variant wall: wallpaper
        property real itemWidth: width
        property real itemHeight: height
        property real screenWidth: scene.width
        property real closedX: rightLeaf ? scene.width / 2 : 0
        property real mirror: rightLeaf ? 1 : 0
        property real uiScale: scene.sc
        // The gilt flashes as they meet.
        property real flash: Math.sin(Math.PI * scene.lin(scene.rite, 0.6, 0.78))
        property real alarm: 0
        property color goldColor: Deco.gold
        property color jewelColor: Deco.jewel
        property color lacquerColor: Deco.lacquer

        y: 0
        width: Math.ceil(scene.width / 2)
        height: scene.height
        visible: scene.doors > 0
        fragmentShader: Qt.resolvedUrl("../../shaders/lock_deco_door.frag.qsb")
    }
}
