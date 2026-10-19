pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.colors
import qs.modules.lock

// The power menu without a desktop theme: the desktop drawn back behind a
// frosted veil in the scheme's colours, you at the top, and the actions as
// five tiles, each lit in its own container colour. A chosen one grows from
// its tile to fill the screen and says what it's doing.
PowerScene {
    id: scene

    introMs: 620
    outroMs: 320
    riteMs: 1500
    quickMs: 300

    // How far the desktop has receded.
    readonly property real k: ease(intro, 0, 0.8)

    readonly property real tileSize: 144 * sc
    readonly property real gap: 22 * sc
    readonly property real rowX: (width - 5 * tileSize - 4 * gap) / 2
    readonly property real rowY: height / 2 - tileSize / 2 + 34 * sc

    readonly property var fills: [Colors.primary_container, Colors.secondary_container, Colors.tertiary_container, Colors.primary_container, Colors.error_container]
    readonly property var inks: [Colors.on_primary_container, Colors.on_secondary_container, Colors.on_tertiary_container, Colors.on_primary_container, Colors.on_error_container]
    // The colour each one keeps once it has filled the screen and settled.
    readonly property var tones: [Colors.primary, Colors.secondary, Colors.tertiary, Colors.primary, Colors.error]
    readonly property var doing: ({ lock: "Locking", sleep: "Going to sleep", logout: "Logging out", reboot: "Restarting", poweroff: "Shutting down" })

    // ── The desktop, receding ────────────────────────────────────────────

    Rectangle {
        anchors.fill: parent
        color: Colors.background
        opacity: scene.menu.hasWorld ? 1 : 0
    }

    MultiEffect {
        anchors.fill: parent
        visible: scene.menu.hasWorld
        source: scene.menu.world
        blurEnabled: true
        blur: scene.k
        blurMax: 48
        saturation: -0.3 * scene.k
        scale: 1 - 0.035 * scene.k
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.background
        opacity: 0.52 * scene.k
    }

    // ── You ──────────────────────────────────────────────────────────────

    Column {
        id: head

        readonly property real shown: scene.seg(scene.intro, 0.12, 0.8)

        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.rowY - height - 70 * scene.sc + (1 - shown) * 22 * scene.sc
        spacing: 12 * scene.sc
        opacity: shown * (1 - scene.aside * (scene.quickChosen ? 0 : 1))

        PowerAvatar {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 92 * scene.sc
            height: width
            placeholder: Colors.surface_container_highest

            Rectangle {
                anchors.fill: parent
                anchors.margins: -4 * scene.sc
                radius: width / 2
                color: "transparent"
                border.width: 2 * scene.sc
                border.color: Colors.withAlpha(Colors.primary, 0.8)
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 6 * scene.sc
            text: scene.cap(scene.menu.userName)
            font.pixelSize: 30 * scene.sc
            font.weight: Font.Medium
            color: Colors.on_surface
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Up " + scene.uptimeText(scene.menu.uptime) + "  ·  " + Qt.formatDate(scene.menu.now, "dddd d MMMM")
            font.pixelSize: 14 * scene.sc
            color: Colors.on_surface_variant
        }
    }

    // ── The actions ──────────────────────────────────────────────────────

    Repeater {
        model: scene.actions.length

        Item {
            id: tile

            required property int index
            readonly property var act: scene.actions[index]
            readonly property bool lit: scene.current === index
            readonly property real shown: scene.seg(scene.intro, 0.22 + index * 0.06, 0.78 + index * 0.05)
            // A chosen one presses in; the rest step back.
            readonly property bool picked: scene.chosen === index
            readonly property real press: picked ? Math.sin(Math.PI * Math.min(1, scene.rite * (scene.quickChosen ? 1 : 3))) : 0

            property real glow: lit || picked ? 1 : 0
            Behavior on glow {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }

            x: scene.rowX + index * (scene.tileSize + scene.gap)
            y: scene.rowY + (1 - shown) * 34 * scene.sc
            width: scene.tileSize
            height: scene.tileSize + 46 * scene.sc
            opacity: shown * (picked || scene.quickChosen ? 1 : 1 - scene.aside)

            // A rounded square at rest, a circle when lit (Material's shape
            // morph).
            Rectangle {
                id: body
                width: scene.tileSize
                height: width
                radius: scene.mix(40 * scene.sc, width / 2, tile.glow)
                scale: (0.9 + 0.1 * tile.shown) * (1 + 0.04 * tile.glow - 0.06 * tile.press)
                color: Qt.tint(Colors.withAlpha(Colors.surface_container_high, 0.9), Colors.withAlpha(scene.fills[tile.index], tile.glow))
                border.width: 1
                border.color: Colors.withAlpha(Colors.outline_variant, 0.5 * (1 - tile.glow))

                Glyph {
                    anchors.centerIn: parent
                    text: tile.act.icon
                    filled: tile.glow > 0.5
                    font.pixelSize: 42 * scene.sc
                    color: Qt.tint(Colors.on_surface_variant, Colors.withAlpha(scene.inks[tile.index], tile.glow))
                }
            }

            Text {
                anchors.horizontalCenter: body.horizontalCenter
                y: body.height + 16 * scene.sc
                text: tile.act.label
                font.pixelSize: 15 * scene.sc
                font.weight: tile.glow > 0.5 ? Font.Medium : Font.Normal
                color: Colors.withAlpha(Colors.on_surface, 0.62 + 0.38 * tile.glow)
            }

            PowerHit {
                anchors.fill: body
                menu: scene.menu
                index: tile.index
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: scene.rowY + scene.tileSize + 120 * scene.sc
        opacity: scene.seg(scene.intro, 0.5, 1) * 0.7 * (1 - scene.aside)
        text: "Esc to go back"
        font.pixelSize: 13 * scene.sc
        color: Colors.on_surface_variant
    }

    // ── The ceremony: the tile grows to fill the screen ──────────────────

    Item {
        id: grow

        readonly property int i: scene.chosen
        readonly property real t: scene.ease(scene.rite, 0, 0.5)
        readonly property real settle: scene.ease(scene.rite, 0.3, 0.85)
        readonly property color ink: Qt.tint(scene.inks[Math.max(0, i)], Colors.withAlpha(scene.tones[Math.max(0, i)], settle))
        readonly property real fromX: scene.rowX + Math.max(0, i) * (scene.tileSize + scene.gap)

        visible: i >= 0 && !scene.quickChosen && scene.rite > 0
        x: scene.mix(fromX, 0, t)
        y: scene.mix(scene.rowY, 0, t)
        width: scene.mix(scene.tileSize, scene.width, t)
        height: scene.mix(scene.tileSize, scene.height, t)

        // The tile's colour as it grows, settling to a quiet surface with
        // only the icon still in it.
        Rectangle {
            anchors.fill: parent
            radius: scene.tileSize / 2 * (1 - grow.t)
            color: Qt.tint(scene.fills[Math.max(0, grow.i)], Colors.withAlpha(Colors.surface_container_lowest, grow.settle))
        }

        Column {
            readonly property real u: scene.ease(scene.rite, 0.25, 0.65)
            anchors.centerIn: parent
            spacing: 26 * scene.sc

            Glyph {
                id: bigIcon
                anchors.horizontalCenter: parent.horizontalCenter
                text: scene.actions[Math.max(0, grow.i)].icon
                filled: true
                font.pixelSize: scene.mix(42, 104, parent.u) * scene.sc
                color: grow.ink
                // Restart turns once.
                rotation: scene.chosenId === "reboot" ? -360 * scene.ease(scene.rite, 0.35, 1) : 0
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: scene.seg(scene.rite, 0.45, 0.8)
                text: (scene.doing[scene.chosenId] ?? "") + "…"
                font.pixelSize: 26 * scene.sc
                font.weight: Font.Medium
                color: Qt.tint(scene.inks[Math.max(0, grow.i)], Colors.withAlpha(Colors.on_surface, grow.settle))
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: scene.seg(scene.rite, 0.6, 0.95) * 0.75
                text: scene.chosenId === "poweroff" ? "Good night, " + scene.cap(scene.menu.userName) : scene.chosenId === "reboot" ? "Back in a moment" : "See you soon, " + scene.cap(scene.menu.userName)
                font.pixelSize: 15 * scene.sc
                color: Qt.tint(scene.inks[Math.max(0, grow.i)], Colors.withAlpha(Colors.on_surface_variant, grow.settle))
            }
        }
    }
}
