pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.colors
import qs.modules.lock
import qs.modules.lock.themes.xianxia
import qs.services as Services

// Cave Abode desktop theme, over the wallpaper: ink bleeding in from the
// edges, mist in the valleys and still motes of qi (desktop_ink shader), and
// the cultivation realm from the lock screen's level bottom right. Static
// once drawn: the ink spreads as it switches on. See ThemeLayer.
Item {
    id: root

    property real boot: 1
    property date now: new Date()
    property real pxScale: 1

    readonly property color ink: Qt.darker(Colors.background, 1.8)
    readonly property color mist: Qt.tint(Colors.on_surface_variant, Colors.withAlpha(Colors.tertiary, 0.2))
    readonly property color seal: Colors.tertiary
    readonly property var hour: Xian.shichen(now)
    readonly property var realm: Xian.realm(Services.LockStats.level)

    ShaderEffect {
        anchors.fill: parent
        opacity: root.boot

        property real itemWidth: width
        property real itemHeight: height
        property real ink: 0.7
        property real mist: 0.55
        property real motes: 0.8
        property real moteScale: Math.min(1.6, 1 / root.pxScale)
        property color inkColor: root.ink
        property color mistColor: root.mist
        property color moteColor: Colors.tertiary

        fragmentShader: Qt.resolvedUrl("../../shaders/desktop_ink.frag.qsb")
    }

    // Cultivation realm, bottom right (lock screen progression).
    Column {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 44
        anchors.bottomMargin: 38
        spacing: 3
        opacity: LockTheme.seg(root.boot, 0.45, 1) * 0.9

        Text {
            anchors.right: parent.right
            text: root.realm.zh + (root.realm.stageZh ? " · " + root.realm.stageZh : "")
            font.family: Xian.cjk
            font.pixelSize: 20
            color: Colors.on_surface
        }

        Text {
            anchors.right: parent.right
            text: root.realm.en + (root.realm.stageEn ? ", " + root.realm.stageEn : "")
            font.family: Xian.serif
            font.pixelSize: 12
            font.italic: true
            font.letterSpacing: 1
            color: LockTheme.alpha(Colors.on_surface, 0.7)
        }
    }
}
