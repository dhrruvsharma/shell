pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.colors
import qs.components
import qs.modules.lock.themes.wasteland
import qs.services as Services

// Wasteland: the desktop bleaches under a dust storm (shaders/
// desktop_dust.frag over a harsh, warm grade), and the rig's breaker panel
// is bolted up in the middle, a plate of scrap (ScrapPlate) under hazard
// tape: five heavy levers, a caged lamp over each and its job on a strip of
// masking tape under it: Bar the door (lock), Lie low (sleep), Hit the road
// (log out), Jump-start (restart), Kill switch (shut down). Pointing at a
// lever lights its lamp amber. Throwing one sparks, the lamps die along the
// panel, and the blast shutter slams down (the Blast Door lock's,
// shaders/lock_shutter.frag) in a burst of dust, a word spray-painted on it.
PowerScene {
    id: scene

    introMs: 900
    outroMs: 360
    riteMs: 3000
    quickMs: 300
    ambient: true

    readonly property var jobs: ["BAR THE DOOR", "LIE LOW", "HIT THE ROAD", "JUMP-START", "KILL SWITCH"]
    readonly property var glosses: ["LOCK", "SLEEP", "LOG OUT", "RESTART", "SHUT DOWN"]
    readonly property var sprayed: ({
        logout: ["GONE SCAVENGING", "back when the dust settles"],
        reboot: ["BACK BY SUNDOWN", "rig restarting"],
        poweroff: ["NOBODY HOME", "lights out till sunrise"]
    })

    readonly property real plateW: 1180 * sc
    readonly property real plateH: 620 * sc
    readonly property real plateX: (width - plateW) / 2
    readonly property real plateY: (height - plateH) / 2 + 40 * sc
    readonly property real pitch: 206 * sc

    function leverX(i) {
        return width / 2 + (i - 2) * pitch;
    }

    readonly property real storm: ease(intro, 0, 0.7)
    readonly property real drop: quickChosen ? 0 : bounce(lin(rite, 0.4, 0.62))
    readonly property real dust: quickChosen ? 0 : lin(rite, 0.5, 0.96)
    // The panel shaking as the lever goes.
    readonly property real shake: chosen >= 0 ? Math.sin(rite * 160) * 6 * sc * (1 - lin(rite, 0.08, 0.32)) * (rite > 0.08 ? 1 : 0) : 0

    function bounce(t) {
        const n = 7.5625, d = 2.75;
        if (t < 1 / d)
            return n * t * t;
        if (t < 2 / d) {
            const u = t - 1.5 / d;
            return n * u * u + 0.75;
        }
        if (t < 2.5 / d) {
            const u = t - 2.25 / d;
            return n * u * u + 0.9375;
        }
        const u = t - 2.625 / d;
        return n * u * u + 0.984375;
    }

    // ── The storm ────────────────────────────────────────────────────────

    PowerGrade {
        menu: scene.menu
        amount: scene.storm
        saturation: 0.35
        brightness: 0.5
        contrast: 1.2
        duo: 0.45
        shadowColor: "#1a120b"
        lightColor: Waste.dust
        vignette: 0.6
        grain: 0.5
    }

    ShaderEffect {
        anchors.fill: parent
        opacity: scene.storm

        property real itemWidth: width
        property real itemHeight: height
        property real storm: scene.storm
        property real lineScale: 1
        property color dustColor: Waste.dust
        property color rustColor: Waste.rust
        property color hazardColor: Waste.hazard
        property color grimeColor: Waste.grime

        fragmentShader: Qt.resolvedUrl("../../shaders/desktop_dust.frag.qsb")
    }

    // ── What watch it is ─────────────────────────────────────────────────

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.plateY - height - 30 * scene.sc
        spacing: 6 * scene.sc
        opacity: scene.seg(scene.intro, 0.35, 0.85) * (1 - scene.aside)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Waste.watch(scene.menu.now)
            font.family: Waste.stencil
            font.pixelSize: 34 * scene.sc
            font.letterSpacing: 3 * scene.sc
            color: Waste.bone
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Services.LockStats.liveStreak + (Services.LockStats.liveStreak === 1 ? " DAY" : " DAYS") + " WITHOUT INCIDENT  ·  " + Waste.rank(Services.LockStats.level) + " " + scene.menu.userName.toUpperCase()
            font.family: Waste.ui
            font.pixelSize: 14 * scene.sc
            font.weight: Font.DemiBold
            font.letterSpacing: 3 * scene.sc
            color: Waste.alpha(Waste.bone, 0.7)
        }
    }

    // ── The panel ────────────────────────────────────────────────────────

    Item {
        id: panel

        readonly property real shown: scene.seg(scene.intro, 0.15, 0.6)

        x: scene.plateX + scene.shake
        y: scene.plateY - (1 - shown) * 40 * scene.sc
        width: scene.plateW
        height: scene.plateH
        opacity: shown

        ScrapPlate {
            anchors.fill: parent
            seed: 4.2
            rust: 0.55
            fill: 0.95
            rivetSize: 10 * scene.sc
            rivetInset: 16 * scene.sc
        }

        HazardStripes {
            x: 34 * scene.sc
            y: 30 * scene.sc
            width: parent.width - 68 * scene.sc
            height: 20 * scene.sc
            stripe: 14 * scene.sc
            colorA: Waste.hazard
            colorB: Waste.grime
        }

        Text {
            x: 40 * scene.sc
            y: 62 * scene.sc
            text: "MAIN POWER"
            font.family: Waste.stencil
            font.pixelSize: 44 * scene.sc
            font.letterSpacing: 4 * scene.sc
            color: Waste.alpha(Waste.bone, 0.85)
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 40 * scene.sc
            y: 76 * scene.sc
            text: "⚠ DANGER · HIGH VOLTAGE · KEEP OFF"
            font.family: Waste.stencilCond
            font.pixelSize: 20 * scene.sc
            font.weight: Font.Bold
            font.letterSpacing: 2 * scene.sc
            color: Waste.alpha(Waste.danger, 0.85)
        }
    }

    // ── The levers ───────────────────────────────────────────────────────

    Repeater {
        model: scene.actions.length

        Item {
            id: lever

            required property int index
            readonly property bool lit: scene.current === index
            readonly property bool picked: scene.chosen === index
            readonly property real shown: scene.seg(scene.intro, 0.3 + index * 0.06, 0.7 + index * 0.05)

            property real pull: lit || picked ? 1 : 0
            Behavior on pull {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutBack
                }
            }
            readonly property real thrown: picked ? scene.ease(scene.rite, 0.02, scene.quickChosen ? 0.6 : 0.14) : 0
            // Its lamp: green and steady, amber and blinking when pointed
            // at, red once thrown, out when the power goes.
            readonly property bool dead: scene.chosen >= 0 && !scene.quickChosen && !picked && scene.rite > 0.18 + index * 0.04
            readonly property color lamp: thrown > 0.5 ? Waste.danger : lit ? Waste.hazard : Waste.safe
            readonly property real lampOn: dead ? 0 : lit && !picked ? (Math.floor(scene.menu.time * 3) % 2 === 0 ? 1 : 0.35) : thrown > 0.5 ? 1 : 0.55

            x: scene.leverX(index) - width / 2 + scene.shake
            y: scene.plateY + 130 * scene.sc
            width: 170 * scene.sc
            height: 460 * scene.sc
            opacity: shown

            // The lamp in its cage.
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 34 * scene.sc
                height: width

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 2.6
                    height: width
                    radius: width / 2
                    color: lever.lamp
                    opacity: 0.22 * lever.lampOn
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.tint(Waste.grime, Waste.alpha(lever.lamp, 0.2 + 0.8 * lever.lampOn))
                    border.width: 2 * scene.sc
                    border.color: "#2b2620"
                }

                // The wire guard.
                Repeater {
                    model: 3

                    Rectangle {
                        required property int index
                        anchors.centerIn: parent
                        width: 2 * scene.sc
                        height: parent.height + 4 * scene.sc
                        rotation: index * 60
                        color: Waste.alpha("#1c1813", 0.85)
                    }
                }
            }

            // The housing.
            Rectangle {
                id: box
                anchors.horizontalCenter: parent.horizontalCenter
                y: 64 * scene.sc
                width: 78 * scene.sc
                height: 210 * scene.sc
                radius: 4 * scene.sc
                gradient: Gradient {
                    GradientStop { position: 0; color: "#3d3933" }
                    GradientStop { position: 1; color: "#1f1c18" }
                }
                border.width: 1.5 * scene.sc
                border.color: "#0e0c0a"

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 18 * scene.sc
                    width: 16 * scene.sc
                    height: parent.height - 36 * scene.sc
                    radius: width / 2
                    color: "#0b0a08"
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 2 * scene.sc
                    text: "ON"
                    font.family: Waste.stencilCond
                    font.pixelSize: 13 * scene.sc
                    font.weight: Font.Bold
                    color: Waste.alpha(Waste.bone, 0.6)
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1 * scene.sc
                    text: "OFF"
                    font.family: Waste.stencilCond
                    font.pixelSize: 13 * scene.sc
                    font.weight: Font.Bold
                    color: Waste.alpha(Waste.bone, 0.6)
                }

                Repeater {
                    model: 4

                    Rivet {
                        required property int index
                        size: 6 * scene.sc
                        x: (index % 2 === 0 ? 10 * scene.sc : box.width - 10 * scene.sc) - width / 2
                        y: (index < 2 ? 22 * scene.sc : box.height - 22 * scene.sc) - height / 2
                    }
                }
            }

            // The handle, on its pivot: up is on.
            Item {
                id: handle
                x: lever.width / 2
                y: box.y + box.height / 2
                rotation: scene.mix(-26 + 7 * lever.pull + Math.sin(scene.menu.time * 9) * 1.5 * lever.pull * (lever.picked ? 0 : 1), 152, lever.thrown)

                Rectangle {
                    x: -8 * scene.sc
                    y: -118 * scene.sc
                    width: 16 * scene.sc
                    height: 124 * scene.sc
                    radius: 3 * scene.sc
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "#8b877d" }
                        GradientStop { position: 0.5; color: "#c9c4b7" }
                        GradientStop { position: 1; color: "#5b574f" }
                    }
                    border.width: 1
                    border.color: "#151310"
                }

                Rectangle {
                    x: -19 * scene.sc
                    y: -150 * scene.sc
                    width: 38 * scene.sc
                    height: 44 * scene.sc
                    radius: 10 * scene.sc
                    color: lever.index === 4 ? Waste.danger : Waste.hazard
                    border.width: 2 * scene.sc
                    border.color: "#151310"

                    Rectangle {
                        x: 6 * scene.sc
                        y: 5 * scene.sc
                        width: 8 * scene.sc
                        height: parent.height - 14 * scene.sc
                        radius: 4 * scene.sc
                        color: Waste.alpha("white", 0.3)
                    }
                }

                Rectangle {
                    x: -11 * scene.sc
                    y: -11 * scene.sc
                    width: 22 * scene.sc
                    height: width
                    radius: width / 2
                    color: "#2e2a24"
                    border.width: 2 * scene.sc
                    border.color: "#0e0c0a"
                }
            }

            // Sparks off the pivot as it's thrown.
            Repeater {
                model: lever.picked && !scene.quickChosen ? 16 : 0

                Rectangle {
                    required property int index
                    readonly property real age: (scene.rite - 0.08 - (index % 4) * 0.02) / 0.2
                    readonly property real a: index * 2.4
                    visible: age > 0 && age < 1
                    x: lever.width / 2 + Math.cos(a) * age * (60 + index * 6) * scene.sc
                    y: box.y + box.height / 2 + Math.sin(a) * age * 50 * scene.sc + age * age * 90 * scene.sc
                    width: 3.5 * scene.sc
                    height: width
                    radius: width / 2
                    color: index % 3 === 0 ? "white" : Waste.hazard
                    opacity: 1 - age
                }
            }

            // Its job, on masking tape.
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                y: box.y + box.height + 34 * scene.sc
                width: tapeText.implicitWidth + 24 * scene.sc
                height: tapeText.implicitHeight + 10 * scene.sc
                rotation: [-2, 1.5, -1, 2, -1.5][lever.index]

                Rectangle {
                    anchors.fill: parent
                    color: Waste.tape
                    opacity: 0.95
                }

                Text {
                    id: tapeText
                    anchors.centerIn: parent
                    text: scene.jobs[lever.index]
                    font.family: Waste.type
                    font.pixelSize: 19 * scene.sc
                    color: lever.lit ? Waste.danger : Waste.tapeInk
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: box.y + box.height + 82 * scene.sc
                text: scene.glosses[lever.index]
                font.family: Waste.stencilCond
                font.pixelSize: 15 * scene.sc
                font.weight: Font.Bold
                font.letterSpacing: 2 * scene.sc
                color: Waste.alpha(Waste.bone, lever.lit ? 0.9 : 0.5)
            }

            PowerHit {
                anchors.fill: parent
                menu: scene.menu
                index: lever.index
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.plateY + scene.plateH + 30 * scene.sc
        opacity: scene.seg(scene.intro, 0.6, 1) * 0.75 * (1 - scene.aside)
        text: "ESC · STAY PUT"
        font.family: Waste.stencilCond
        font.pixelSize: 16 * scene.sc
        font.weight: Font.Bold
        font.letterSpacing: 4 * scene.sc
        color: Waste.bone
    }

    // ── The shutter ──────────────────────────────────────────────────────

    // The wallpaper painted on it.
    Item {
        width: 0
        height: 0
        clip: true

        Image {
            id: wallpaper
            width: scene.width
            height: scene.height
            source: scene.chosen >= 0 && !scene.quickChosen ? scene.menu.wallpaper : ""
            sourceSize: Qt.size(Math.max(1, scene.width / 2), Math.max(1, scene.height / 2))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }
    }

    Item {
        id: shutter
        width: scene.width
        height: scene.height
        y: -height * (1 - scene.drop)
        visible: scene.drop > 0

        ShaderEffect {
            anchors.fill: parent

            property variant wall: wallpaper
            property real itemWidth: width
            property real itemHeight: height
            property real uiScale: scene.sc
            property real mural: 0.85
            property real rail: 64 * scene.sc
            property color steelColor: Waste.steel
            property color rustColor: Waste.rust
            property color hazardColor: Waste.hazard
            property color grimeColor: Waste.grime
            property color paintColor: Waste.paint

            fragmentShader: Qt.resolvedUrl("../../shaders/lock_shutter.frag.qsb")
        }

        // Sprayed on it.
        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -40 * scene.sc
            spacing: 10 * scene.sc
            opacity: scene.seg(scene.rite, 0.68, 0.9) * 0.92
            rotation: -3

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (scene.sprayed[scene.chosenId] ?? ["", ""])[0]
                font.family: Waste.stencil
                font.pixelSize: 110 * scene.sc
                font.letterSpacing: 4 * scene.sc
                color: Waste.bone
                style: Text.Outline
                styleColor: Waste.alpha(Waste.grime, 0.6)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (scene.sprayed[scene.chosenId] ?? ["", ""])[1]
                font.family: Waste.type
                font.pixelSize: 26 * scene.sc
                color: Waste.hazard
            }
        }
    }

    // The dust it throws up.
    ShaderEffect {
        x: 0
        width: scene.width
        height: 380 * scene.sc
        y: scene.height - height
        visible: scene.dust > 0 && scene.dust < 1

        property real itemWidth: width
        property real itemHeight: height
        property real progress: scene.dust
        property color dustColor: Waste.dust

        fragmentShader: Qt.resolvedUrl("../../shaders/lock_dustburst.frag.qsb")
    }
}
