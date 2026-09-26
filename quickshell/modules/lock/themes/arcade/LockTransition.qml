import QtQuick
import qs.modules.lock

// The pre-lock screenshot, drawn through the tile-wave shader. At progress 0 it
// is pixel-identical to the desktop it was captured from; at 1 every tile has
// flown away. See shaders/lock_transition.frag.
Item {
    id: transition

    property url source
    property real progress: 0
    property real desat: 0
    property bool inward: false
    property real tileSize: 64
    property color edgeColor: LockTheme.accent
    readonly property bool ready: shot.status === Image.Ready

    // The Image has to stay visible to keep providing its texture, so it sits
    // in a zero-size clipped host: live, but never drawn itself.
    Item {
        width: 0
        height: 0
        clip: true

        Image {
            id: shot
            width: transition.width
            height: transition.height
            source: transition.source
            asynchronous: false
            cache: false
            smooth: true
        }
    }

    ShaderEffect {
        anchors.fill: parent
        visible: transition.ready && transition.progress < 1

        property variant source: shot
        property real progress: transition.progress
        property real desat: transition.desat
        property real tileSize: transition.tileSize
        property real inward: transition.inward ? 1 : 0
        property real edgeStrength: 0.85
        property real itemWidth: width
        property real itemHeight: height
        property point origin: Qt.point(0.5, 0.46)
        property color edgeColor: transition.edgeColor

        fragmentShader: Qt.resolvedUrl("../../../../shaders/lock_transition.frag.qsb")
    }
}
