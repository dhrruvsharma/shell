pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.colors
import qs.modules.lock
import qs.modules.lock.themes.observatory
import qs.services as Services

// Observatory: night falls over the desktop and tonight's sky comes out
// over it as the theme's engraved chart (StarChart), and in the middle
// hangs the astrolabe, its rete turned to the stars as they stand (the
// Astrolabe lock's instrument). Round its limb, five brass stations: Cap
// the lens (lock), Rest (sleep), Sign the log (log out), Turn again
// (restart), Close the dome (shut down). The rule swings round to whichever
// you point at. Closing up slides the dome's shutters across the sky; Turn
// again sends the rete once round the heavens first.
PowerScene {
    id: scene

    introMs: 1000
    outroMs: 380
    riteMs: 3000
    quickMs: 300
    ambient: true

    readonly property var names: ["Cap the lens", "Rest", "Sign the log", "Turn again", "Close the dome"]
    readonly property var glosses: ["lock", "sleep", "log out", "restart", "shut down"]
    readonly property var icons: ["camera", "bedtime", "history_edu", "autorenew", "roofing"]
    readonly property var farewells: ({
        logout: ["Signed out of the log", "clear skies, " + menu.userName],
        reboot: ["The heavens turn again", "back by the next transit"],
        poweroff: ["The dome is closed", "clear skies, " + menu.userName]
    })

    readonly property real cx: width / 2
    readonly property real cy: height * 0.52
    readonly property real astroR: 225 * sc
    readonly property real ring: 340 * sc
    // Stations round the limb, degrees clockwise from the top.
    readonly property var angles: [-120, -60, 0, 60, 120]

    function stationAt(i) {
        const a = angles[i] * Math.PI / 180;
        return Qt.point(cx + Math.sin(a) * ring, cy - Math.cos(a) * ring);
    }

    readonly property real night: ease(intro, 0, 0.75)
    // The dome's shutters: 0 open .. 1 shut.
    readonly property real shut: quickChosen ? 0 : ease(rite, chosenId === "reboot" ? 0.55 : 0.3, chosenId === "reboot" ? 0.85 : 0.72)
    readonly property real turn: chosenId === "reboot" ? ease(rite, 0.05, 0.6) : 0

    // The rule: over the station pointed at, else on the hour.
    readonly property real ruleTarget: current >= 0 ? angles[current] : (menu.now.getHours() + menu.now.getMinutes() / 60 - 12) * 15
    property real ruleAt: ruleTarget
    Behavior on ruleAt {
        SpringAnimation {
            spring: 2.2
            damping: 0.25
            epsilon: 0.05
        }
    }

    // ── Night ────────────────────────────────────────────────────────────

    PowerGrade {
        menu: scene.menu
        amount: scene.night
        saturation: 0.3
        brightness: 0.42
        duo: 0.6
        shadowColor: Sky.night
        lightColor: Qt.tint("#55607a", Colors.withAlpha(Sky.enamel, 0.3))
        vignette: 0.55
    }

    StarChart {
        anchors.fill: parent
        opacity: scene.night * 0.85
        now: scene.menu.now
        boot: scene.seg(scene.intro, 0.1, 0.95)
        strength: 0.9
        veil: 0.85
        labels: false
    }

    // ── Where we are ─────────────────────────────────────────────────────

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 52 * scene.sc
        spacing: 4 * scene.sc
        opacity: scene.seg(scene.intro, 0.4, 0.9) * (1 - scene.aside)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Sky.site.name
            font.family: Sky.display
            font.pixelSize: 34 * scene.sc
            color: Sky.parchment
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property var moon: Sky.moon(scene.menu.now)
            text: "sidereal time " + Sky.hm(Sky.lst(scene.menu.now)) + "   ·   " + Sky.phaseName(moon).toLowerCase() + "   ·   " + Sky.rank(Services.LockStats.level).toLowerCase() + " " + scene.menu.userName
            font.family: Sky.caps
            font.pixelSize: 15 * scene.sc
            font.letterSpacing: 1.5 * scene.sc
            color: Colors.withAlpha(Sky.parchment, 0.65)
        }
    }

    // ── The astrolabe ────────────────────────────────────────────────────

    Astrolabe {
        id: astro

        readonly property real shown: scene.seg(scene.intro, 0.2, 0.8)

        x: scene.cx - width / 2
        y: scene.cy - height / 2
        width: scene.astroR * 2
        height: scene.astroR * 2
        opacity: shown * (1 - 0.85 * scene.shut)
        scale: 0.94 + 0.06 * shown
        rete: Sky.lst(scene.menu.now) + 360 * scene.turn
        rule: scene.ruleAt
        glow: 1
        bloom: scene.chosenId === "reboot" ? 0.18 * Math.sin(Math.PI * scene.turn) : 0

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.7
            shadowBlur: 0.8
            blurMax: 40
            shadowHorizontalOffset: 3
            shadowVerticalOffset: 6
        }
    }

    // ── The stations ─────────────────────────────────────────────────────

    Repeater {
        model: scene.actions.length

        Item {
            id: station

            required property int index
            readonly property bool lit: scene.current === index
            readonly property bool picked: scene.chosen === index
            readonly property point at: scene.stationAt(index)
            readonly property real shown: scene.seg(scene.intro, 0.4 + index * 0.06, 0.8 + index * 0.04)
            readonly property real a: scene.angles[index]

            property real glow: lit || picked ? 1 : 0
            Behavior on glow {
                NumberAnimation {
                    duration: 220
                }
            }
            readonly property real flare: picked && scene.quickChosen ? Math.sin(Math.PI * scene.rite) : 0

            x: at.x - width / 2
            y: at.y - height / 2
            width: 78 * scene.sc
            height: width
            opacity: shown * (picked || scene.quickChosen ? 1 : 1 - scene.aside * 0.7) * (1 - scene.shut)
            scale: 1 + 0.08 * glow + 0.12 * flare

            // A brass medallion, its face enamelled in the night's colour.
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 1.8
                height: width
                radius: width / 2
                color: Sky.lamp
                opacity: 0.18 * station.glow + 0.25 * station.flare
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
                    GradientStop { position: 0; color: Sky.brassHi }
                    GradientStop { position: 1; color: Sky.brassDeep }
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 6 * scene.sc
                radius: width / 2
                color: Qt.tint(Sky.enamelDeep, Colors.withAlpha(Sky.enamel, 0.35 * station.glow))
                border.width: 1
                border.color: Colors.withAlpha(Sky.brassHi, 0.6)

                Glyph {
                    anchors.centerIn: parent
                    text: scene.icons[station.index]
                    filled: station.glow > 0.5
                    font.pixelSize: 30 * scene.sc
                    color: Qt.tint(Sky.brass, Colors.withAlpha(Sky.lamp, station.glow))
                }
            }

            PowerHit {
                anchors.fill: parent
                anchors.margins: -10 * scene.sc
                menu: scene.menu
                index: station.index
            }
        }
    }

    // Their names, outside the ring.
    Repeater {
        model: scene.actions.length

        Column {
            id: label

            required property int index
            readonly property bool lit: scene.current === index
            readonly property point at: scene.stationAt(index)
            readonly property real a: scene.angles[index] * Math.PI / 180
            // Out beyond the medallion, on the side away from the instrument.
            readonly property real dx: Math.sin(a)
            readonly property real dy: -Math.cos(a)

            x: dx > 0.3 ? at.x + 56 * scene.sc : dx < -0.3 ? at.x - 56 * scene.sc - width : at.x - width / 2
            y: Math.abs(dx) > 0.3 ? at.y - height / 2 : at.y - 56 * scene.sc - height
            spacing: 2 * scene.sc
            opacity: scene.seg(scene.intro, 0.55, 1) * (1 - scene.aside) * (lit ? 1 : 0.7)

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }

            Text {
                anchors.right: label.dx < -0.3 ? parent.right : undefined
                anchors.horizontalCenter: Math.abs(label.dx) <= 0.3 ? parent.horizontalCenter : undefined
                text: scene.names[label.index]
                font.family: Sky.display
                font.italic: true
                font.pixelSize: 24 * scene.sc
                color: label.lit ? Sky.lamp : Sky.parchment
            }

            Text {
                anchors.right: label.dx < -0.3 ? parent.right : undefined
                anchors.horizontalCenter: Math.abs(label.dx) <= 0.3 ? parent.horizontalCenter : undefined
                text: scene.glosses[label.index]
                font.family: Sky.caps
                font.pixelSize: 14 * scene.sc
                font.letterSpacing: 2 * scene.sc
                color: Colors.withAlpha(Sky.parchment, 0.6)
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.height - 76 * scene.sc
        opacity: scene.seg(scene.intro, 0.7, 1) * 0.6 * (1 - scene.aside)
        text: "Esc · keep observing"
        font.family: Sky.display
        font.italic: true
        font.pixelSize: 18 * scene.sc
        color: Sky.parchment
    }

    // ── The dome's shutters ──────────────────────────────────────────────

    Repeater {
        model: scene.chosen >= 0 && !scene.quickChosen ? 2 : 0

        Rectangle {
            id: leaf

            required property int index
            readonly property bool rightLeaf: index === 1

            width: scene.width / 2 + 2
            height: scene.height
            x: rightLeaf ? scene.width / 2 + (scene.width / 2) * (1 - scene.shut) - 1 : -(scene.width / 2) * (1 - scene.shut) - 1
            // Curved like the dome it's part of: lit near the slit, falling
            // away into the dark towards the walls.
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: leaf.rightLeaf ? "#232b3f" : "#06080d" }
                GradientStop { position: 0.55; color: "#121725" }
                GradientStop { position: 1; color: leaf.rightLeaf ? "#06080d" : "#232b3f" }
            }

            // Its ribs, and the brass edge where the two meet.
            Repeater {
                model: 6

                Rectangle {
                    required property int index
                    x: 0
                    y: (index + 1) * scene.height / 7
                    width: leaf.width
                    height: 2 * scene.sc
                    color: Colors.withAlpha("black", 0.45)
                }
            }

            Rectangle {
                x: leaf.rightLeaf ? 0 : leaf.width - width
                width: 6 * scene.sc
                height: leaf.height
                color: Sky.brass
            }
        }
    }

    // A brass plate over the seam with the night's last entry.
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.cy - height / 2
        width: farewell.implicitWidth + 90 * scene.sc
        height: farewell.implicitHeight + 50 * scene.sc
        visible: scene.chosen >= 0 && !scene.quickChosen
        opacity: scene.seg(scene.rite, 0.76, 0.98)

        Rectangle {
            anchors.fill: parent
            radius: 10 * scene.sc
            color: Sky.alpha(Sky.night, 0.96)
            border.width: 1.5 * scene.sc
            border.color: Sky.brass

            Rectangle {
                anchors.fill: parent
                anchors.margins: 5 * scene.sc
                radius: 7 * scene.sc
                color: "transparent"
                border.width: 1
                border.color: Sky.alpha(Sky.brass, 0.4)
            }
        }

        Column {
            id: farewell
            anchors.centerIn: parent
            spacing: 8 * scene.sc

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (scene.farewells[scene.chosenId] ?? ["", ""])[0]
                font.family: Sky.display
                font.pixelSize: 42 * scene.sc
                color: Sky.parchment
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (scene.farewells[scene.chosenId] ?? ["", ""])[1]
                font.family: Sky.display
                font.italic: true
                font.pixelSize: 21 * scene.sc
                color: Sky.lamp
            }
        }
    }
}
