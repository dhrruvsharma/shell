pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

// A kalash, the Samudra Manthan lock's measure of lives: a round-bellied
// pot with a red thread tied round its shoulder, mango leaves at its mouth
// and a coconut set on them. Full, it is gold and glows with the amrita in
// it; spoiled (`full` 0), the poison has turned it dark. Drawn in a 40 × 56
// box stretched to the item.
Item {
    id: pot

    property real full: 1
    property color gold: Deva.gold

    readonly property real kx: width / 40
    readonly property real ky: height / 56
    readonly property color metal: Qt.tint(Deva.poison, Qt.rgba(gold.r, gold.g, gold.b, 0.15 + 0.85 * full))
    readonly property color metalHi: Qt.tint(Qt.darker(Deva.poisonGlow, 1.3), Qt.rgba(1, 0.9, 0.62, full))
    readonly property color metalLo: Qt.tint("#08081c", Qt.rgba(0.42, 0.26, 0.06, full))
    readonly property color leaf: Qt.tint("#1d2334", Qt.rgba(0.3, 0.6, 0.25, 0.3 + 0.7 * full))

    // The amrita's glow behind the mouth.
    Rectangle {
        x: 20 * pot.kx - width / 2
        y: 16 * pot.ky - height / 2
        width: 30 * pot.kx
        height: width
        radius: width / 2
        color: Qt.rgba(1, 0.85, 0.45, 0.3 * pot.full)
        visible: pot.full > 0.01
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // Mango leaves fanning from the mouth, behind the coconut.
        component Leaf: ShapePath {
            id: lf
            property real angle: 0
            readonly property real a: angle * Math.PI / 180
            readonly property real bx: 20 * pot.kx
            readonly property real by: 15 * pot.ky
            readonly property real tx: bx + Math.sin(a) * 15 * pot.kx
            readonly property real ty: by - Math.cos(a) * 11 * pot.ky
            fillColor: pot.leaf
            strokeColor: Qt.darker(pot.leaf, 1.6)
            strokeWidth: 0.8
            startX: bx
            startY: by

            PathQuad {
                x: lf.tx
                y: lf.ty
                controlX: (lf.bx + lf.tx) / 2 + Math.cos(lf.a) * 4 * pot.kx
                controlY: (lf.by + lf.ty) / 2 + Math.sin(lf.a) * 4 * pot.ky
            }

            PathQuad {
                x: lf.bx
                y: lf.by
                controlX: (lf.bx + lf.tx) / 2 - Math.cos(lf.a) * 4 * pot.kx
                controlY: (lf.by + lf.ty) / 2 - Math.sin(lf.a) * 4 * pot.ky
            }
        }

        Leaf { angle: -64 }
        Leaf { angle: 64 }
        Leaf { angle: -34 }
        Leaf { angle: 34 }

        // The coconut.
        ShapePath {
            fillColor: Qt.tint("#1a1622", Qt.rgba(0.55, 0.36, 0.2, 0.25 + 0.75 * pot.full))
            strokeColor: Qt.tint("#0c0a12", Qt.rgba(0.3, 0.18, 0.08, pot.full))
            strokeWidth: 0.9

            PathAngleArc {
                centerX: 20 * pot.kx
                centerY: 9.5 * pot.ky
                radiusX: 6 * pot.kx
                radiusY: 7 * pot.ky
                startAngle: 0
                sweepAngle: 360
            }
        }

        // The pot.
        ShapePath {
            strokeColor: pot.metalLo
            strokeWidth: 1
            joinStyle: ShapePath.RoundJoin
            fillGradient: LinearGradient {
                x1: 4 * pot.kx
                y1: 0
                x2: 36 * pot.kx
                y2: 0
                GradientStop { position: 0; color: pot.metalLo }
                GradientStop { position: 0.32; color: pot.metalHi }
                GradientStop { position: 0.55; color: pot.metal }
                GradientStop { position: 1; color: pot.metalLo }
            }
            startX: 13 * pot.kx
            startY: 54 * pot.ky

            PathCubic { x: 13 * pot.kx; y: 20 * pot.ky; control1X: 0; control1Y: 50 * pot.ky; control2X: -1 * pot.kx; control2Y: 26 * pot.ky }
            PathLine { x: 10.5 * pot.kx; y: 17 * pot.ky }
            PathLine { x: 10.5 * pot.kx; y: 15 * pot.ky }
            PathLine { x: 29.5 * pot.kx; y: 15 * pot.ky }
            PathLine { x: 29.5 * pot.kx; y: 17 * pot.ky }
            PathLine { x: 27 * pot.kx; y: 20 * pot.ky }
            PathCubic { x: 27 * pot.kx; y: 54 * pot.ky; control1X: 41 * pot.kx; control1Y: 26 * pot.ky; control2X: 40 * pot.kx; control2Y: 50 * pot.ky }
            PathLine { x: 13 * pot.kx; y: 54 * pot.ky }
        }

        // The red thread round its shoulder, and a ring at its foot.
        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.tint("#3a1030", Qt.rgba(0.85, 0.16, 0.12, pot.full))
            strokeWidth: 1.6
            capStyle: ShapePath.RoundCap
            startX: 8.5 * pot.kx
            startY: 25 * pot.ky

            PathQuad { x: 31.5 * pot.kx; y: 25 * pot.ky; controlX: 20 * pot.kx; controlY: 28 * pot.ky }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: pot.metalLo
            strokeWidth: 1
            startX: 14 * pot.kx
            startY: 50.5 * pot.ky

            PathQuad { x: 26 * pot.kx; y: 50.5 * pot.ky; controlX: 20 * pot.kx; controlY: 52 * pot.ky }
        }
    }
}
