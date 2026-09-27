pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.lock

// Still desktop theme, over the wallpaper: only a faint vignette. See
// ThemeLayer.
Item {
    id: root

    property real boot: 1
    property date now: new Date()
    property real pxScale: 1

    ShaderEffect {
        anchors.fill: parent
        opacity: root.boot

        property real itemWidth: width * root.pxScale
        property real itemHeight: height * root.pxScale
        property real gridSize: 30
        property real dotAlpha: 0
        property real scanAlpha: 0
        property real tintAlpha: 0.05
        property real vignette: 0.3
        property color tintColor: Colors.background
        property color dotColor: Colors.primary

        fragmentShader: Qt.resolvedUrl("../../shaders/lock_backdrop.frag.qsb")
    }
}
