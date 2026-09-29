import QtQuick
import QtQuick.Shapes

// A longsword standing point up, filling the item: the crossguard spans
// its width, the pommel sits at its foot. Steel lit from the left, a
// fuller down the blade, the hilt in `hilt` over a leather grip.
Shape {
    id: sword

    property color steel: War.steel
    property color hilt: War.or
    property color leather: "#3a2418"
    property color edge: "#0d0b0a"
    property real lineWidth: 1

    readonly property real guardY: height * 0.72
    readonly property real bw: Math.min(width * 0.11, height * 0.032)
    readonly property real pommelY: height - bw * 1.1
    readonly property real cx: width / 2

    preferredRendererType: Shape.CurveRenderer

    // The blade.
    ShapePath {
        strokeColor: sword.edge
        strokeWidth: sword.lineWidth
        joinStyle: ShapePath.MiterJoin
        fillGradient: LinearGradient {
            x1: sword.cx - sword.bw
            y1: 0
            x2: sword.cx + sword.bw
            y2: 0
            GradientStop { position: 0; color: Qt.lighter(sword.steel, 1.25) }
            GradientStop { position: 0.5; color: sword.steel }
            GradientStop { position: 0.51; color: Qt.darker(sword.steel, 1.45) }
            GradientStop { position: 1; color: Qt.darker(sword.steel, 1.2) }
        }
        startX: sword.cx
        startY: 0
        PathLine { x: sword.cx + sword.bw * 0.72; y: sword.height * 0.13 }
        PathLine { x: sword.cx + sword.bw; y: sword.guardY }
        PathLine { x: sword.cx - sword.bw; y: sword.guardY }
        PathLine { x: sword.cx - sword.bw * 0.72; y: sword.height * 0.13 }
        PathLine { x: sword.cx; y: 0 }
    }

    // The fuller.
    ShapePath {
        strokeColor: Qt.darker(sword.steel, 1.7)
        strokeWidth: Math.max(1, sword.bw * 0.35)
        capStyle: ShapePath.RoundCap
        fillColor: "transparent"
        startX: sword.cx
        startY: sword.guardY - sword.height * 0.01
        PathLine { x: sword.cx; y: sword.height * 0.24 }
    }

    // The grip.
    ShapePath {
        fillColor: sword.leather
        strokeColor: sword.edge
        strokeWidth: sword.lineWidth
        PathRectangle {
            x: sword.cx - sword.bw * 0.55
            y: sword.guardY
            width: sword.bw * 1.1
            height: sword.pommelY - sword.guardY
        }
    }

    // The crossguard, its quillons flared a little at the ends.
    ShapePath {
        fillColor: sword.hilt
        strokeColor: sword.edge
        strokeWidth: sword.lineWidth
        joinStyle: ShapePath.RoundJoin
        startX: 0
        startY: sword.guardY - sword.bw * 0.5
        PathLine { x: sword.width; y: sword.guardY - sword.bw * 0.5 }
        PathLine { x: sword.width - sword.bw * 0.5; y: sword.guardY + sword.bw * 0.45 }
        PathLine { x: sword.bw * 0.5; y: sword.guardY + sword.bw * 0.45 }
        PathLine { x: 0; y: sword.guardY - sword.bw * 0.5 }
    }

    // The pommel: a wheel.
    ShapePath {
        fillColor: sword.hilt
        strokeColor: sword.edge
        strokeWidth: sword.lineWidth
        PathAngleArc {
            centerX: sword.cx
            centerY: sword.pommelY
            radiusX: sword.bw * 1.05
            radiusY: sword.bw * 1.05
            startAngle: 0
            sweepAngle: 360
        }
    }
}
