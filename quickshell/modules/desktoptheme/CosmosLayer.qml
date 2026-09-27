pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.lock

// Astral desktop theme, over the wallpaper: a still starfield and nebula in
// the wallpaper's colours. Static once drawn: the sky fades in as it switches
// on. See ThemeLayer.
Item {
    id: root

    property real boot: 1
    property date now: new Date()
    property real pxScale: 1

    readonly property color accent: Colors.primary
    readonly property color accent2: Colors.tertiary

    ShaderEffect {
        anchors.fill: parent
        opacity: root.boot

        property real itemWidth: width
        property real itemHeight: height
        property real starScale: Math.min(1.6, 1 / root.pxScale)
        property real veil: 0.16
        property real nebula: 1
        property real vignette: 0.4
        property color veilColor: Colors.background
        property color tintA: root.accent
        property color tintB: root.accent2

        fragmentShader: Qt.resolvedUrl("../../shaders/desktop_stars.frag.qsb")
    }
}
