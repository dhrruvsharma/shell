pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.colors
import qs.modules.desktoptheme
import qs.services as Services

// Astral: the desktop falls away into deep space (the Astral lock's sky,
// shaders/lock_space.frag) and the actions become an orrery round a small
// star, each a world on its own orbit, lit on the side that faces the star
// (shaders/planet.frag) and drifting slowly round: Airlock (lock),
// Hibernate (sleep), Eject (log out), Relaunch (restart), Go dark (shut
// down). Pointing at a world lights its orbit. Going dark sends the world
// spiralling into the star and the whole system down a singularity (the
// lock's warp, shaders/power_warp.frag); relaunching counts down and jumps to
// hyperspace; ejecting flings the world out of the system.
PowerScene {
    id: scene

    introMs: 950
    outroMs: 360
    riteMs: 2800
    quickMs: 300
    ambient: true

    readonly property color accent: Colors.primary
    readonly property color accent2: Colors.tertiary
    readonly property color ink: "#e9ecf8"
    readonly property string display: "ESPACION"
    readonly property string ui: "Adwaita Sans"

    readonly property real cx: width / 2
    readonly property real cy: height * 0.55
    readonly property real tilt: 0.34

    readonly property var names: ["AIRLOCK", "HIBERNATE", "EJECT", "RELAUNCH", "GO DARK"]
    readonly property var glosses: ["seal the hatch  ·  lock", "cryosleep  ·  sleep", "leave orbit  ·  log out", "restart", "shut down"]

    // Each world: its orbit, size, where it starts and how fast it goes
    // round (inner ones faster), and how it looks.
    readonly property var worlds: [
        { rx: 205, r: 18, at: 205, speed: 1.6, base: "#9aa3b5", band: "#6f7686", air: "#cfd8ff", bands: 0.15, craters: 1, ring: 0 },
        { rx: 295, r: 24, at: 330, speed: 1.0, base: "#bfe6ef", band: "#e9f8fb", air: "#9fe8ff", bands: 0.4, craters: 0.2, ring: 0 },
        { rx: 385, r: 25, at: 118, speed: 0.7, base: Qt.tint("#d9c08f", Colors.withAlpha(Colors.tertiary, 0.25)), band: "#a07e55", air: "#ffe2b0", bands: 0.8, craters: 0, ring: 1 },
        { rx: 475, r: 37, at: 28, speed: 0.5, base: Qt.tint("#6b7fd6", Colors.withAlpha(Colors.primary, 0.45)), band: Qt.tint("#c9b6f0", Colors.withAlpha(Colors.primary, 0.3)), air: Colors.primary, bands: 1, craters: 0, ring: 0 },
        { rx: 565, r: 21, at: 252, speed: 0.36, base: "#c2462f", band: "#7a2214", air: "#ff8a5c", bands: 0.35, craters: 0.6, ring: 0 }
    ]

    function angleOf(i) {
        return (worlds[i].at + menu.time * worlds[i].speed) * Math.PI / 180;
    }

    function posOf(i) {
        const a = angleOf(i);
        const rx = worlds[i].rx * sc;
        return Qt.point(cx + rx * Math.cos(a), cy + rx * tilt * Math.sin(a));
    }

    // MET: mission elapsed time, the uptime.
    function met(s) {
        const t = Math.floor(s);
        const p = n => String(n).padStart(2, "0");
        return p(Math.floor(t / 3600)) + ":" + p(Math.floor(t / 60) % 60) + ":" + p(t % 60);
    }

    readonly property string stardate: (menu.now.getFullYear() + Clocks.yearFraction(menu.now)).toFixed(2)

    // How far it has gone into space.
    readonly property real space: ease(intro, 0, 0.7)
    readonly property real warp: chosenId === "poweroff" ? ease(rite, 0.36, 0.95) : 0
    readonly property real blackout: chosenId === "reboot" ? ease(rite, 0.86, 0.96) : chosenId === "logout" ? ease(rite, 0.5, 0.9) : 0

    Rectangle {
        anchors.fill: parent
        visible: scene.chosen >= 0 && !scene.quickChosen
        color: "black"
    }

    Item {
        id: system
        anchors.fill: parent

        readonly property real jump: scene.chosenId === "reboot" ? scene.ease(scene.rite, 0.5, 0.92) : 0
        scale: 1 + 0.5 * jump * jump

        layer.enabled: scene.warp > 0
        layer.effect: ShaderEffect {
            property real itemWidth: system.width
            property real itemHeight: system.height
            property real progress: scene.warp
            property point center: Qt.point(scene.cx / scene.width, scene.cy / scene.height)
            property color glowColor: Qt.lighter(scene.accent, 1.3)

            fragmentShader: Qt.resolvedUrl("../../shaders/power_warp.frag.qsb")
        }

        PowerGrade {
            menu: scene.menu
            amount: scene.space
            saturation: 0.5
            brightness: 0.5
        }

        // Deep space, the desktop faint behind it.
        ShaderEffect {
            anchors.fill: parent
            opacity: scene.space * 0.9

            property real itemWidth: width
            property real itemHeight: height
            property real time: scene.menu.time
            property real nebula: 1
            property color baseColor: Qt.tint("#03040a", Colors.withAlpha(scene.accent2, 0.04))
            property color tintA: scene.accent
            property color tintB: scene.accent2

            fragmentShader: Qt.resolvedUrl("../../shaders/lock_space.frag.qsb")
        }

        // ── The orbits ───────────────────────────────────────────────────

        Repeater {
            model: scene.worlds.length

            Shape {
                id: orbit

                required property int index
                readonly property bool lit: scene.current === index
                readonly property real rx: scene.worlds[index].rx * scene.sc
                readonly property real shown: scene.seg(scene.intro, 0.2 + index * 0.06, 0.6 + index * 0.06)

                property real glow: lit ? 1 : 0
                Behavior on glow {
                    NumberAnimation {
                        duration: 220
                    }
                }

                anchors.fill: parent
                opacity: shown * (1 - scene.aside * 0.8)
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Colors.withAlpha(orbit.lit ? scene.accent : scene.ink, 0.13 + 0.5 * orbit.glow)
                    strokeWidth: (1 + 0.8 * orbit.glow) * scene.sc
                    strokeStyle: orbit.index === 4 ? ShapePath.DashLine : ShapePath.SolidLine
                    dashPattern: [4, 6]

                    PathAngleArc {
                        centerX: scene.cx
                        centerY: scene.cy
                        radiusX: orbit.rx * (0.6 + 0.4 * orbit.shown)
                        radiusY: orbit.rx * scene.tilt * (0.6 + 0.4 * orbit.shown)
                        startAngle: 0
                        sweepAngle: 360
                    }
                }
            }
        }

        // ── The worlds behind the star ───────────────────────────────────

        Repeater {
            model: scene.worlds.length

            World {
                required property int index
                i: index
                front: false
            }
        }

        // ── The star ─────────────────────────────────────────────────────

        Item {
            id: star

            readonly property real flare: scene.chosenId === "poweroff" ? Math.sin(Math.PI * scene.lin(scene.rite, 0.26, 0.44)) : 0
            readonly property real core: 26 * scene.sc * (1 + 0.8 * flare)

            x: scene.cx
            y: scene.cy
            opacity: scene.seg(scene.intro, 0.1, 0.5)

            // A streak of light across it, as through a lens.
            Rectangle {
                width: star.core * 26
                height: 2 * scene.sc
                x: -width / 2
                y: -height / 2
                opacity: 0.55
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.lighter(scene.accent2, 1.5) }
                    GradientStop { position: 1; color: "transparent" }
                }
            }

            Shape {
                x: -star.core * 4
                y: -star.core * 4
                width: star.core * 8
                height: star.core * 8
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: RadialGradient {
                        centerX: star.core * 4
                        centerY: star.core * 4
                        centerRadius: star.core * 4
                        focalX: centerX
                        focalY: centerY
                        GradientStop { position: 0; color: "#ffffff" }
                        GradientStop { position: 0.1; color: "#fff6e4" }
                        GradientStop { position: 0.16; color: Colors.withAlpha(Qt.lighter(scene.accent2, 1.5), 0.6) }
                        GradientStop { position: 0.4; color: Colors.withAlpha(scene.accent2, 0.12) }
                        GradientStop { position: 1; color: "transparent" }
                    }
                    PathAngleArc {
                        centerX: star.core * 4
                        centerY: star.core * 4
                        radiusX: star.core * 4
                        radiusY: star.core * 4
                        sweepAngle: 360
                    }
                }
            }
        }

        // ── The worlds in front of it ────────────────────────────────────

        Repeater {
            model: scene.worlds.length

            World {
                required property int index
                i: index
                front: true
            }
        }

        // Their names.
        Repeater {
            model: scene.worlds.length

            Column {
                id: tag

                required property int index
                readonly property bool lit: scene.current === index
                readonly property point at: scene.posOf(index)
                readonly property bool onLeft: at.x < scene.cx
                readonly property real gap: (scene.worlds[index].r * 1.6 + 14) * scene.sc

                x: onLeft ? at.x - gap - width : at.x + gap
                y: at.y - 18 * scene.sc
                spacing: 4 * scene.sc
                opacity: scene.seg(scene.intro, 0.5 + index * 0.05, 0.9) * (1 - (scene.quickChosen ? 0 : scene.ease(scene.rite, 0, 0.15))) * (lit ? 1 : 0.55)

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                    }
                }

                Text {
                    anchors.right: tag.onLeft ? parent.right : undefined
                    text: scene.names[tag.index]
                    font.family: scene.display
                    font.pixelSize: (tag.lit ? 19 : 16) * scene.sc
                    font.letterSpacing: 3 * scene.sc
                    color: tag.lit ? Qt.lighter(scene.accent, 1.25) : scene.ink
                }

                Text {
                    anchors.right: tag.onLeft ? parent.right : undefined
                    text: scene.glosses[tag.index].toUpperCase()
                    font.family: scene.ui
                    font.pixelSize: 11 * scene.sc
                    font.letterSpacing: 2.5 * scene.sc
                    color: Colors.withAlpha(scene.ink, 0.6)
                }
            }
        }

        // ── Mission control ──────────────────────────────────────────────

        Column {
            x: 96 * scene.sc
            y: 92 * scene.sc
            spacing: 8 * scene.sc
            opacity: scene.seg(scene.intro, 0.35, 0.85) * (1 - scene.aside)

            Text {
                text: "MISSION CONTROL"
                font.family: scene.display
                font.pixelSize: 24 * scene.sc
                font.letterSpacing: 6 * scene.sc
                color: scene.ink
            }

            Text {
                text: "MET " + scene.met(scene.menu.uptime) + "     STARDATE " + scene.stardate
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14 * scene.sc
                font.letterSpacing: 2 * scene.sc
                color: scene.accent
            }

            Text {
                text: "CMDR " + scene.menu.userName.toUpperCase() + "  ·  LV " + Services.LockStats.level + "  ·  " + Services.LockStats.rank.toUpperCase()
                font.family: scene.ui
                font.pixelSize: 12 * scene.sc
                font.letterSpacing: 2.5 * scene.sc
                color: Colors.withAlpha(scene.ink, 0.55)
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: scene.height - 96 * scene.sc
            opacity: scene.seg(scene.intro, 0.6, 1) * (1 - scene.aside) * 0.6
            text: "ESC  ·  STAY IN ORBIT"
            font.family: scene.ui
            font.pixelSize: 12 * scene.sc
            font.letterSpacing: 4 * scene.sc
            color: scene.ink
        }

    }

    // ── Relaunch: the jump to hyperspace ─────────────────────────────────

    Repeater {
        model: scene.chosenId === "reboot" ? 150 : 0

        Rectangle {
            id: streak
            required property int index
            readonly property real a: index * 2.39996
            readonly property real d0: (30 + ((index * 97) % 520)) * scene.sc
            readonly property real jump: system.jump
            readonly property real len: (6 + jump * jump * 1100) * scene.sc * (0.3 + ((index * 37) % 70) / 70)

            x: scene.cx + Math.cos(a) * d0 * (1 + jump * 2.4)
            y: scene.cy + Math.sin(a) * d0 * (1 + jump * 2.4) - height / 2
            width: len
            height: (1 + (index % 3) * 0.6) * scene.sc
            visible: scene.rite > 0.48
            opacity: Math.min(1, jump * 2.5)
            transformOrigin: Item.Left
            rotation: a * 180 / Math.PI
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: streak.index % 4 === 0 ? Qt.lighter(scene.accent, 1.4) : "#f2f5ff" }
            }
        }
    }

    // The jump's flash.
    Rectangle {
        anchors.fill: parent
        visible: opacity > 0
        color: "white"
        opacity: scene.chosenId === "reboot" ? Math.sin(Math.PI * scene.lin(scene.rite, 0.82, 0.94)) * 0.85 : 0
    }

    // ── Captions ─────────────────────────────────────────────────────────

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: scene.blackout
        visible: opacity > 0
    }

    // T-3, T-2, T-1
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.cy - 330 * scene.sc
        visible: scene.chosenId === "reboot" && scene.rite > 0.08 && scene.rite < 0.5
        text: "T-" + Math.max(1, 3 - Math.floor((scene.rite - 0.08) / 0.14))
        font.family: scene.display
        font.pixelSize: 84 * scene.sc
        font.letterSpacing: 10 * scene.sc
        color: scene.ink
    }

    Column {
        anchors.centerIn: parent
        visible: scene.chosen >= 0 && !scene.quickChosen
        opacity: scene.chosenId === "poweroff" ? scene.seg(scene.rite, 0.86, 1) : scene.chosenId === "reboot" ? scene.seg(scene.rite, 0.9, 1) : scene.seg(scene.rite, 0.7, 0.95)
        spacing: 14 * scene.sc

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: scene.chosenId === "poweroff" ? "ALL SYSTEMS DARK" : scene.chosenId === "reboot" ? "JUMP COMPLETE" : "UNDOCKED"
            font.family: scene.display
            font.pixelSize: 30 * scene.sc
            font.letterSpacing: 10 * scene.sc
            color: scene.ink
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (scene.chosenId === "poweroff" ? "GOOD NIGHT, COMMANDER" : scene.chosenId === "reboot" ? "SEE YOU ON THE OTHER SIDE" : "SAFE TRAVELS, " + scene.menu.userName.toUpperCase())
            font.family: scene.ui
            font.pixelSize: 13 * scene.sc
            font.letterSpacing: 4 * scene.sc
            color: Colors.withAlpha(scene.ink, 0.6)
        }
    }

    // ── A world ──────────────────────────────────────────────────────────

    component World: Item {
        id: world

        property int i
        property bool front

        readonly property var w: scene.worlds[i]
        readonly property bool lit: scene.current === i
        readonly property bool picked: scene.chosen === i
        readonly property real shown: scene.seg(scene.intro, 0.3 + i * 0.07, 0.75 + i * 0.05)
        readonly property real angle: scene.angleOf(i)

        // Going dark: it spirals into the star. Ejected: off on a tangent.
        readonly property real fall: picked && scene.chosenId === "poweroff" ? scene.ease(scene.rite, 0, 0.36) : 0
        readonly property real fling: picked && scene.chosenId === "logout" ? scene.lin(scene.rite, 0.05, 0.5) : 0
        readonly property real pulse: picked && scene.quickChosen ? Math.sin(Math.PI * scene.rite) : 0

        readonly property real a: angle + fall * 5
        readonly property real orbitR: w.rx * scene.sc * (1 - fall) * (0.6 + 0.4 * shown)
        readonly property real px: scene.cx + orbitR * Math.cos(a) - Math.sin(angle) * fling * fling * 1400 * scene.sc
        readonly property real py: scene.cy + orbitR * scene.tilt * Math.sin(a) + Math.cos(angle) * scene.tilt * fling * fling * 1400 * scene.sc
        // Nearer (lower on the screen) is bigger.
        readonly property real depth: 0.86 + 0.14 * Math.sin(a)

        property real glow: lit || picked ? 1 : 0
        Behavior on glow {
            NumberAnimation {
                duration: 220
            }
        }

        readonly property real rpx: w.r * scene.sc * depth * (1 + 0.22 * glow + 0.2 * pulse) * (1 - 0.85 * fall)

        visible: front ? Math.sin(a) >= 0 : Math.sin(a) < 0
        x: px - width / 2
        y: py - height / 2
        width: rpx * 4.6
        height: rpx * 4.6
        opacity: shown * (picked || scene.quickChosen ? 1 : 1 - scene.aside * 0.7)

        ShaderEffect {
            anchors.fill: parent

            property real itemWidth: width
            property real itemHeight: height
            property real radius: world.rpx
            property real bands: world.w.bands
            property real craters: world.w.craters
            property real ring: world.w.ring
            property real glow: world.glow
            property real seed: world.i * 3.7 + 1.3
            property point lightDir: {
                const dx = scene.cx - world.px;
                const dy = scene.cy - world.py;
                const l = Math.max(1, Math.sqrt(dx * dx + dy * dy));
                return Qt.point(dx / l, dy / l);
            }
            property color baseColor: world.w.base
            property color bandColor: world.w.band
            property color airColor: world.w.air

            fragmentShader: Qt.resolvedUrl("../../shaders/planet.frag.qsb")
        }

        PowerHit {
            anchors.centerIn: parent
            width: Math.max(44 * scene.sc, world.rpx * 3)
            height: width
            menu: scene.menu
            index: world.i
        }
    }
}
