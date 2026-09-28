pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.modules.lock
import qs.modules.lock.themes.gothic
import qs.services as Services

// Cathedral desktop theme, over the wallpaper: shafts of stained-glass light
// falling from a high window, dust hanging in them, candlelight at the foot
// and stone shadow in the vault (desktop_glass shader), and bottom right the
// hour the bells last rang, the year of grace and your standing in the
// masons' lodge (the lock level). Static once drawn: the light reaches down
// as it switches on. See ThemeLayer.
Item {
    id: root

    property real boot: 1
    property date now: new Date()
    property real pxScale: 1

    readonly property var hour: Gothic.canonicalHour(now)

    ShaderEffect {
        anchors.fill: parent
        opacity: Math.min(1, root.boot * 1.6)

        property real itemWidth: width
        property real itemHeight: height
        property real light: LockTheme.seg(root.boot, 0, 0.95)
        property real lineScale: Math.min(2.5, 1 / root.pxScale)
        property color glassA: Gothic.glassA
        property color glassB: Gothic.glassB
        property color glassC: Gothic.glassC
        property color glassD: Gothic.glassD
        property color stoneColor: "#0e0d0c"
        property color candleColor: Gothic.candle

        fragmentShader: Qt.resolvedUrl("../../shaders/desktop_glass.frag.qsb")
    }

    // The bells, bottom right.
    Column {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 44
        anchors.bottomMargin: 36
        spacing: 2
        opacity: LockTheme.seg(root.boot, 0.45, 1) * 0.95

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.7
            shadowBlur: 0.7
            blurMax: 24
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 1
        }

        Text {
            anchors.right: parent.right
            text: root.hour.en
            font.family: Gothic.blackletter
            font.pixelSize: 38
            color: Gothic.parchment
        }

        Text {
            anchors.right: parent.right
            text: (root.hour.gloss + "  ·  " + Gothic.year(root.now)).toUpperCase()
            font.family: Gothic.caps
            font.pixelSize: 12
            font.weight: Font.Bold
            font.letterSpacing: 2
            color: Gothic.alpha(Gothic.parchment, 0.85)
        }

        Text {
            anchors.right: parent.right
            topPadding: 3
            text: Gothic.rank(Services.LockStats.level) + " of the lodge  ·  " + Services.LockStats.xp.toLocaleString(Qt.locale(), "f", 0) + " stones laid"
            font.family: Gothic.book
            font.pixelSize: 15
            font.italic: true
            color: Gothic.glassC
        }
    }
}
