import QtQuick
import QtQuick.Shapes

// A Sculptor's Idol, as Sekiro's checkpoints are: a little wooden Buddha
// carved rough, seated, with six arms (the Sculptor could only carve
// Buddhas of wrath, Shura), the upper pair raised, the middle pair spread,
// the lowest at rest in its lap. Drawn in silhouette, its rim lit by the
// glow it gives off when the shinobi communes with it (`glow`, 0..1, a
// mandorla of warm light behind it).
Item {
    id: idol

    property real glow: 0.5
    property color wood: "#20160f"
    property color rim: "#e6a24a"
    property color light: "#ffb35c"

    implicitWidth: 260
    implicitHeight: 340

    readonly property real w: width
    readonly property real h: height
    readonly property real arm: Math.max(2, w * 0.05)

    // The mandorla: light behind it, an upright oval.
    Shape {
        id: mandorla
        readonly property real r: idol.w * 0.8
        x: idol.w * 0.5 - r
        y: idol.h * 0.44 - r
        width: 2 * r
        height: 2 * r
        opacity: idol.glow
        transform: Scale {
            origin.x: mandorla.r
            origin.y: mandorla.r
            yScale: 1.25
        }
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: mandorla.r
                centerY: mandorla.r
                centerRadius: mandorla.r
                focalX: mandorla.r
                focalY: mandorla.r
                GradientStop { position: 0; color: Qt.rgba(1, 0.72, 0.38, 0.42) }
                GradientStop { position: 0.45; color: Qt.rgba(1, 0.6, 0.28, 0.2) }
                GradientStop { position: 1; color: "transparent" }
            }
            PathAngleArc { centerX: mandorla.r; centerY: mandorla.r; radiusX: mandorla.r; radiusY: mandorla.r; startAngle: 0; sweepAngle: 360 }
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // A halo ring behind the head.
        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(1, 0.75, 0.42, 0.25 + 0.5 * idol.glow)
            strokeWidth: Math.max(1, idol.w * 0.012)
            PathAngleArc {
                centerX: idol.w * 0.5
                centerY: idol.h * 0.25
                radiusX: idol.w * 0.2
                radiusY: idol.w * 0.2
                startAngle: 0
                sweepAngle: 360
            }
        }

        // The arms, behind the body: the raised pair, the spread pair.
        ShapePath {
            fillColor: "transparent"
            strokeColor: idol.wood
            strokeWidth: idol.arm
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: idol.w * 0.36
            startY: idol.h * 0.39
            PathQuad { x: idol.w * 0.2; y: idol.h * 0.06; controlX: idol.w * 0.14; controlY: idol.h * 0.25 }
            PathMove { x: idol.w * 0.64; y: idol.h * 0.39 }
            PathQuad { x: idol.w * 0.8; y: idol.h * 0.06; controlX: idol.w * 0.86; controlY: idol.h * 0.25 }
            PathMove { x: idol.w * 0.34; y: idol.h * 0.43 }
            PathQuad { x: idol.w * 0.03; y: idol.h * 0.33; controlX: idol.w * 0.12; controlY: idol.h * 0.47 }
            PathMove { x: idol.w * 0.66; y: idol.h * 0.43 }
            PathQuad { x: idol.w * 0.97; y: idol.h * 0.33; controlX: idol.w * 0.88; controlY: idol.h * 0.47 }
        }

        // Hands: a fist at the end of each of those arms.
        ShapePath {
            fillColor: idol.wood
            strokeColor: "transparent"
            PathAngleArc { centerX: idol.w * 0.2; centerY: idol.h * 0.05; radiusX: idol.arm * 0.95; radiusY: idol.arm * 0.95; startAngle: 0; sweepAngle: 360 }
            PathMove { x: idol.w * 0.8 + idol.arm; y: idol.h * 0.05 }
            PathAngleArc { centerX: idol.w * 0.8; centerY: idol.h * 0.05; radiusX: idol.arm * 0.95; radiusY: idol.arm * 0.95; startAngle: 0; sweepAngle: 360 }
            PathMove { x: idol.w * 0.03 + idol.arm; y: idol.h * 0.32 }
            PathAngleArc { centerX: idol.w * 0.03; centerY: idol.h * 0.32; radiusX: idol.arm * 0.95; radiusY: idol.arm * 0.95; startAngle: 0; sweepAngle: 360 }
            PathMove { x: idol.w * 0.97 + idol.arm; y: idol.h * 0.32 }
            PathAngleArc { centerX: idol.w * 0.97; centerY: idol.h * 0.32; radiusX: idol.arm * 0.95; radiusY: idol.arm * 0.95; startAngle: 0; sweepAngle: 360 }
        }

        // The block it was carved from, its seat.
        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0
                y1: idol.h * 0.8
                x2: 0
                y2: idol.h
                GradientStop { position: 0; color: Qt.lighter(idol.wood, 1.35) }
                GradientStop { position: 1; color: Qt.darker(idol.wood, 1.4) }
            }
            startX: idol.w * 0.1
            startY: idol.h * 0.84
            PathQuad { x: idol.w * 0.9; y: idol.h * 0.84; controlX: idol.w * 0.5; controlY: idol.h * 0.79 }
            PathLine { x: idol.w * 0.94; y: idol.h }
            PathLine { x: idol.w * 0.06; y: idol.h }
            PathLine { x: idol.w * 0.1; y: idol.h * 0.84 }
        }

        // The crossed legs, the body, the shoulders.
        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: idol.w * 0.25
                y1: 0
                x2: idol.w * 0.75
                y2: 0
                GradientStop { position: 0; color: Qt.darker(idol.wood, 1.3) }
                GradientStop { position: 0.55; color: idol.wood }
                GradientStop { position: 1; color: Qt.lighter(idol.wood, 1.25) }
            }
            startX: idol.w * 0.14
            startY: idol.h * 0.83
            PathQuad { x: idol.w * 0.3; y: idol.h * 0.68; controlX: idol.w * 0.13; controlY: idol.h * 0.71 }
            PathQuad { x: idol.w * 0.32; y: idol.h * 0.41; controlX: idol.w * 0.33; controlY: idol.h * 0.55 }
            PathQuad { x: idol.w * 0.44; y: idol.h * 0.35; controlX: idol.w * 0.33; controlY: idol.h * 0.36 }
            PathLine { x: idol.w * 0.56; y: idol.h * 0.35 }
            PathQuad { x: idol.w * 0.68; y: idol.h * 0.41; controlX: idol.w * 0.67; controlY: idol.h * 0.36 }
            PathQuad { x: idol.w * 0.7; y: idol.h * 0.68; controlX: idol.w * 0.67; controlY: idol.h * 0.55 }
            PathQuad { x: idol.w * 0.86; y: idol.h * 0.83; controlX: idol.w * 0.87; controlY: idol.h * 0.71 }
            PathQuad { x: idol.w * 0.14; y: idol.h * 0.83; controlX: idol.w * 0.5; controlY: idol.h * 0.88 }
        }

        // The lowest arms, resting in the lap, hands together.
        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.lighter(idol.wood, 1.2)
            strokeWidth: idol.arm * 0.85
            capStyle: ShapePath.RoundCap
            startX: idol.w * 0.33
            startY: idol.h * 0.45
            PathQuad { x: idol.w * 0.5; y: idol.h * 0.71; controlX: idol.w * 0.31; controlY: idol.h * 0.7 }
            PathQuad { x: idol.w * 0.67; y: idol.h * 0.45; controlX: idol.w * 0.69; controlY: idol.h * 0.7 }
        }

        // The head, and the knot of hair on its crown.
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: idol.w * 0.53
                centerY: idol.h * 0.23
                centerRadius: idol.w * 0.12
                focalX: idol.w * 0.53
                focalY: idol.h * 0.23
                GradientStop { position: 0; color: Qt.lighter(idol.wood, 1.35) }
                GradientStop { position: 1; color: idol.wood }
            }
            PathAngleArc { centerX: idol.w * 0.5; centerY: idol.h * 0.26; radiusX: idol.w * 0.105; radiusY: idol.w * 0.115; startAngle: 0; sweepAngle: 360 }
            PathMove { x: idol.w * 0.5 + idol.w * 0.05; y: idol.h * 0.165 }
            PathAngleArc { centerX: idol.w * 0.5; centerY: idol.h * 0.165; radiusX: idol.w * 0.05; radiusY: idol.w * 0.045; startAngle: 0; sweepAngle: 360 }
        }

        // The rim of light the glow puts round it.
        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(1, 0.68, 0.32, 0.25 + 0.6 * idol.glow)
            strokeWidth: Math.max(1, idol.w * 0.008)
            capStyle: ShapePath.RoundCap
            startX: idol.w * 0.68
            startY: idol.h * 0.41
            PathQuad { x: idol.w * 0.7; y: idol.h * 0.68; controlX: idol.w * 0.67; controlY: idol.h * 0.55 }
            PathQuad { x: idol.w * 0.86; y: idol.h * 0.83; controlX: idol.w * 0.87; controlY: idol.h * 0.71 }
        }
    }
}
