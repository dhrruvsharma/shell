pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

// One of Sekiro's resurrection nodes: a rose medallion in a dark rim with a
// white emblem (a sakura petal, or a flower of eight petals), glowing while
// it's charged. Spent, it goes dark; `struck`, a stroke of black ink is
// drawn through it, as the game does to a node that can't be used yet.
Item {
    id: node

    property bool lit: true
    property bool struck: false
    // 0: a petal, 1: a flower.
    property int emblem: 0
    property real glow: 0
    property real strike: struck ? 1 : 0
    property color rose: "#d8417a"
    property color roseGlow: "#ff86b2"
    property real seed: 1

    implicitWidth: 34
    implicitHeight: 34

    readonly property real r: Math.min(width, height) / 2
    readonly property color face: lit ? rose : "#3a3034"

    Behavior on strike {
        NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // A soft halo, then the rim, then the face.
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: node.r
                centerY: node.r
                centerRadius: node.r
                focalX: node.r
                focalY: node.r
                GradientStop { position: 0; color: node.lit ? Qt.rgba(1, 0.52, 0.7, 0.55 + 0.35 * node.glow) : "transparent" }
                GradientStop { position: 1; color: "transparent" }
            }
            PathAngleArc { centerX: node.r; centerY: node.r; radiusX: node.r; radiusY: node.r; startAngle: 0; sweepAngle: 360 }
        }

        ShapePath {
            strokeColor: "#0b0809"
            strokeWidth: Math.max(1, node.r * 0.1)
            fillColor: "#5d5358"
            PathAngleArc { centerX: node.r; centerY: node.r; radiusX: node.r * 0.82; radiusY: node.r * 0.82; startAngle: 0; sweepAngle: 360 }
        }

        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: node.r * 0.9
                centerY: node.r * 0.82
                centerRadius: node.r * 0.72
                focalX: node.r * 0.9
                focalY: node.r * 0.82
                GradientStop { position: 0; color: node.lit ? Qt.lighter(node.roseGlow, 1.1) : "#4a4044" }
                GradientStop { position: 0.6; color: node.face }
                GradientStop { position: 1; color: node.lit ? Qt.darker(node.rose, 1.8) : "#211b1d" }
            }
            PathAngleArc { centerX: node.r; centerY: node.r; radiusX: node.r * 0.7; radiusY: node.r * 0.7; startAngle: 0; sweepAngle: 360 }
        }
    }

    // The emblem: a sakura of five notched petals, or a flower of eight.
    Repeater {
        model: node.emblem === 0 ? 5 : 8

        Shape {
            id: petal
            required property int index
            readonly property real len: node.r * (node.emblem === 0 ? 0.5 : 0.48)
            readonly property real wide: node.r * (node.emblem === 0 ? 0.22 : 0.12)
            readonly property real notch: node.emblem === 0 ? node.r * 0.09 : 0
            anchors.fill: parent
            rotation: index * (node.emblem === 0 ? 72 : 45)
            preferredRendererType: Shape.CurveRenderer
            opacity: node.lit ? 0.95 : 0.3

            // One petal, pointing up from the middle: narrow at the heart,
            // round at its end (notched, for a sakura's).
            ShapePath {
                strokeColor: "transparent"
                fillColor: "white"
                startX: node.r
                startY: node.r - node.r * 0.06
                PathCubic { x: node.r - 0.01 * node.r; y: node.r - 0.06 * node.r - 0.98 * petal.len + 0.0; control1X: node.r - petal.wide * 1.25; control1Y: node.r - 0.45 * petal.len; control2X: node.r - petal.wide * 1.1; control2Y: node.r - 1.05 * petal.len }
                PathLine { x: node.r; y: node.r - 0.06 * node.r - petal.len + petal.notch }
                PathLine { x: node.r + 0.01 * node.r; y: node.r - 0.06 * node.r - 0.98 * petal.len }
                PathCubic { x: node.r; y: node.r - node.r * 0.06; control1X: node.r + petal.wide * 1.1; control1Y: node.r - 1.05 * petal.len; control2X: node.r + petal.wide * 1.25; control2Y: node.r - 0.45 * petal.len }
            }
        }
    }

    // Struck through with a stroke of ink.
    BrushStroke {
        x: -node.r * 0.6
        y: node.r - height / 2
        width: node.r * 4.2
        height: node.r * 0.95
        visible: node.strike > 0
        reveal: node.strike
        ink: "#050404"
        seed: node.seed
        dry: 0.6
        weight: 0.82
    }
}
