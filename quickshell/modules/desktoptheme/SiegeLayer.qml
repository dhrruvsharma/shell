pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.modules.lock
import qs.modules.lock.themes.siege
import qs.services as Services

// Siege desktop theme, over the wallpaper: the pall of a burning town along
// the top, fires glowing below the bottom edge and embers on the heat
// (shaders/desktop_siege.frag), and bottom right, out of the wallpaper's
// way, your achievement of arms (the shield of your arms before two
// crossed swords, your motto on a scroll beneath) beside an iron-bound
// board with the day of the siege and its watch, your arms blazoned, the
// season and the truce, and your rank in the host (the lock level, XP as
// renown). It changes once a minute. See ThemeLayer.
Item {
    id: root

    property real boot: 1
    property date now: new Date()
    property real pxScale: 1

    readonly property real line: pxScale < 1 ? 1 / pxScale : 1
    readonly property var watch: War.watch(now)
    readonly property var season: War.season(now)

    ShaderEffect {
        anchors.fill: parent

        property real itemWidth: width
        property real itemHeight: height
        property real boot: root.boot
        property real lineScale: root.line
        property color smokeColor: "#15110f"
        property color fireColor: War.fire
        property color emberColor: War.ember

        fragmentShader: Qt.resolvedUrl("../../shaders/desktop_siege.frag.qsb")
    }

    // The achievement, beside the board.
    Item {
        id: achievement
        anchors.right: board.left
        anchors.rightMargin: 6
        anchors.verticalCenter: board.verticalCenter
        width: 224
        height: 262
        opacity: LockTheme.seg(root.boot, 0.2, 0.7)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.6
            shadowBlur: 0.6
            blurMax: 20
            shadowHorizontalOffset: 2
            shadowVerticalOffset: 4
        }

        Repeater {
            model: [-35, 35]

            Sword {
                required property real modelData
                x: (achievement.width - width) / 2
                y: 112 - height / 2
                width: 50
                height: 246
                rotation: modelData
                transformOrigin: Item.Center
                lineWidth: root.line
            }
        }

        Arms {
            x: (achievement.width - width) / 2
            y: 40
            width: 122
            height: 146
            seed: 3
        }

        Scroll {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 216
            band: 22
            line: root.line
            text: War.arms.motto
        }
    }

    Item {
        id: board
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 40
        anchors.bottomMargin: 56
        width: lines.implicitWidth + 64
        height: lines.implicitHeight + 46
        opacity: LockTheme.seg(root.boot, 0.45, 1)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.55
            shadowBlur: 0.6
            blurMax: 20
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 3
        }

        Board {
            anchors.fill: parent
            line: root.line
        }

        Column {
            id: lines
            anchors.centerIn: parent
            spacing: 3

            Text {
                text: "The Siege of " + War.hold
                font.family: War.display
                font.pixelSize: 30
                color: War.ivory
            }

            Text {
                text: "Day " + War.siegeDay(root.now) + "  ·  " + root.watch.name.toLowerCase() + ": " + root.watch.deed
                font.family: War.book
                font.italic: true
                font.pixelSize: 17
                color: War.tincture
            }

            Text {
                text: War.arms.blazon
                font.family: War.book
                font.italic: true
                font.pixelSize: 14
                color: War.alpha(War.ivory, 0.72)
            }

            Text {
                topPadding: 3
                text: (root.season.name + "  ·  " + War.truceLine(root.now) + "  ·  " + War.year(root.now)).toUpperCase()
                font.family: War.display
                font.pixelSize: 12
                font.letterSpacing: 1.6
                color: War.alpha(War.steel, 0.85)
            }

            Text {
                topPadding: 2
                text: War.rank(Services.LockStats.level) + "  ·  " + War.count(Services.LockStats.xp) + " renown"
                font.family: War.book
                font.pixelSize: 14
                color: War.alpha(War.ivory, 0.66)
            }
        }
    }
}
