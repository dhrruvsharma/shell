pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import qs.modules.lock.themes.cyberpunk
import qs.services as Services

// Neon Noir desktop theme, over the wallpaper: a noir shade with neon
// spilling in from the sides, city haze and still rain (desktop_neon
// shader), a katakana neon sign at the left edge and your street cred bottom
// right. Static once drawn: the tubes stutter on as it switches on. See
// ThemeLayer.
Item {
    id: root

    property real boot: 1
    property date now: new Date()
    property real pxScale: 1

    readonly property int level: Services.LockStats.level
    readonly property int floorXp: Services.LockStats.xpForLevel(level)
    readonly property int ceilXp: Services.LockStats.xpForLevel(level + 1)
    readonly property real progress: Math.max(0, Math.min(1, (Services.LockStats.xp - floorXp) / Math.max(1, ceilXp - floorXp)))

    // A neon tube doesn't fade in, it stutters on: `boot` through from..to
    // as a flicker ending lit.
    function stutter(p, from, to) {
        const x = (p - from) / (to - from);
        if (x <= 0)
            return 0;
        if (x >= 1)
            return 1;
        return [0.9, 0, 0.35, 1, 0, 0.7, 0.15, 1][Math.floor(x * 8)];
    }

    ShaderEffect {
        anchors.fill: parent
        opacity: root.boot

        property real itemWidth: width
        property real itemHeight: height
        property real shade: 0.85
        property real spill: 1
        property real haze: 1
        property real rain: 1
        property real lineScale: Math.min(2.5, 1 / root.pxScale)
        property color nightColor: Neon.night
        property color neonA: Neon.a
        property color neonB: Neon.b

        fragmentShader: Qt.resolvedUrl("../../shaders/desktop_neon.frag.qsb")
    }

    // The sign: ネオン in a tube frame, 営業中 ("open") hanging under it.
    // Each tube glows its own colour.
    component Glow: MultiEffect {
        shadowEnabled: true
        shadowOpacity: 1
        shadowBlur: 0.85
        blurMax: 24
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
    }

    Item {
        id: sign

        x: 34
        y: Math.round(parent.height * 0.4)
        width: 60
        height: kana.implicitHeight + 24 + 12 + open.implicitHeight
        opacity: root.stutter(root.boot, 0.3, 0.85)

        Rectangle {
            width: parent.width
            height: kana.implicitHeight + 24
            radius: 5
            color: Neon.alpha(Neon.night, 0.35)
            border.width: 2
            border.color: Neon.b
            layer.enabled: true
            layer.effect: Glow {
                shadowColor: Neon.b
            }
        }

        Text {
            id: kana
            anchors.horizontalCenter: parent.horizontalCenter
            y: 12
            text: "ネ\nオ\nン"
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 1.05
            font.family: Neon.kana
            font.weight: Font.Black
            font.pixelSize: 34
            color: Qt.lighter(Neon.a, 1.3)
            layer.enabled: true
            layer.effect: Glow {
                shadowColor: Neon.a
            }
        }

        Text {
            id: open
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            text: "営業中"
            font.family: Neon.kana
            font.weight: Font.Bold
            font.pixelSize: 13
            font.letterSpacing: 1
            color: Qt.lighter(Neon.b, 1.2)
            layer.enabled: true
            layer.effect: Glow {
                shadowColor: Neon.b
            }
        }
    }

    // Street cred, bottom right (lock screen progression).
    Column {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 38
        anchors.bottomMargin: 34
        spacing: 5
        opacity: root.stutter(root.boot, 0.45, 1) * 0.92

        Row {
            anchors.right: parent.right
            spacing: 10

            Text {
                anchors.baseline: userText.baseline
                text: "NETRUNNER"
                font.family: Neon.ui
                font.pixelSize: 15
                font.letterSpacing: 3
                color: Neon.b
            }

            Text {
                id: userText
                text: (Quickshell.env("USER") || "runner").toUpperCase()
                font.family: Neon.logo
                font.pixelSize: 17
                color: Neon.ink
            }
        }

        Text {
            anchors.right: parent.right
            text: "STREET CRED " + root.level + "  //  " + Services.LockStats.rank
            font.family: Neon.ui
            font.pixelSize: 16
            font.letterSpacing: 2
            color: Neon.a
        }

        Row {
            anchors.right: parent.right
            spacing: 8

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Repeater {
                    model: 18

                    Rectangle {
                        required property int index
                        width: 7
                        height: 5
                        color: (index + 0.5) / 18 <= root.progress ? Neon.a : Neon.alpha(Neon.ink, 0.15)
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Services.LockStats.xp.toLocaleString(Qt.locale(), "f", 0) + " XP"
                font.family: Neon.mono
                font.pixelSize: 11
                font.letterSpacing: 1
                color: Neon.alpha(Neon.ink, 0.7)
            }
        }
    }
}
