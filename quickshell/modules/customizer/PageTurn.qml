import QtQuick

// A leaf turning over (shaders/page_turn.vert/.frag): `frontItem` is the
// page it is, `backItem` the page on its other side; both are drawn into
// it while it turns (and hidden where they lie meanwhile). `dir` +1 turns
// a right-hand page over to the left, -1 a left-hand page back to the
// right. It covers the whole spread; `progress` runs 0..1, eased here.
// It also lays the shadow it casts on the page beneath it.
Item {
    id: turn

    property Item frontItem: null
    property Item backItem: null
    property real progress: 0
    property real dir: 1
    property real pageW: 740
    property real pageH: 900
    property bool active: false

    readonly property real ease: turn.progress * turn.progress * (3 - 2 * turn.progress)
    readonly property real spineAngle: Math.PI * turn.ease
    readonly property real edgeAngle: turn.spineAngle + 1.1 * Math.sin(Math.PI * turn.progress) * Math.cos(Math.PI * turn.progress * 0.85)
    readonly property real eye: 5600

    // Where the free edge stands over the spread, and how high it's lifted.
    readonly property real _k: (turn.edgeAngle - turn.spineAngle) / turn.pageW
    readonly property real edgeLift: Math.abs(turn._k) < 1e-6 ? turn.pageW * Math.sin(turn.spineAngle)
        : (Math.cos(turn.spineAngle) - Math.cos(turn.edgeAngle)) / turn._k
    readonly property real edgeRun: Math.abs(turn._k) < 1e-6 ? turn.pageW * Math.cos(turn.spineAngle)
        : (Math.sin(turn.edgeAngle) - Math.sin(turn.spineAngle)) / turn._k
    readonly property real edgeX: turn.pageW + turn.dir * turn.edgeRun * turn.eye / Math.max(1, turn.eye - turn.edgeLift)

    width: turn.pageW * 2
    height: turn.pageH
    visible: turn.active

    // The shadow on the page beneath, just past the leaf's edge: wider and
    // softer the higher the leaf is lifted.
    Rectangle {
        readonly property bool onRight: turn.edgeX > turn.pageW
        readonly property real w: 18 + turn.edgeLift * 0.16
        visible: turn.active && turn.progress > 0.01 && turn.progress < 0.99
        x: onRight ? Math.min(turn.edgeX, turn.pageW * 2) : Math.max(0, turn.edgeX - w)
        width: onRight ? Math.max(0, Math.min(w, turn.pageW * 2 - x)) : Math.max(0, Math.min(w, turn.edgeX))
        height: turn.pageH
        opacity: Math.min(1, Math.sin(turn.spineAngle) * 1.6) * 0.55
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: parent.onRight ? "#a0000000" : "transparent" }
            GradientStop { position: 1; color: parent.onRight ? "transparent" : "#a0000000" }
        }
    }

    ShaderEffect {
        width: turn.pageW * 2
        height: turn.pageH
        mesh: GridMesh {
            resolution: Qt.size(44, 6)
        }
        vertexShader: Qt.resolvedUrl("../../shaders/page_turn.vert.qsb")
        fragmentShader: Qt.resolvedUrl("../../shaders/page_turn.frag.qsb")

        property var front: ShaderEffectSource {
            sourceItem: turn.frontItem
            hideSource: turn.active
            live: true
        }
        property var back: ShaderEffectSource {
            sourceItem: turn.backItem
            hideSource: turn.active
            live: true
        }
        readonly property real pageW: turn.pageW
        readonly property real pageH: turn.pageH
        readonly property real spineX: turn.pageW
        readonly property real dir: turn.dir
        readonly property real spineAngle: turn.spineAngle
        readonly property real edgeAngle: turn.edgeAngle
        readonly property real eye: turn.eye
    }
}
