import QtQuick
import QtQuick.Shapes
import qs.colors

// Accent stroke along a HUD piece's top-left chamfer (desktop theme); pairs
// with HudMask using the same `cut`.
Shape {
    id: tick

    property real cut: 7
    property real length: 10
    property color color: Colors.primary

    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: "transparent"
        strokeColor: tick.color
        strokeWidth: 1.5
        capStyle: ShapePath.FlatCap
        joinStyle: ShapePath.MiterJoin
        startX: 0.75
        startY: tick.cut + tick.length * 0.6
        PathLine { x: 0.75; y: tick.cut }
        PathLine { x: tick.cut; y: 0.75 }
        PathLine { x: tick.cut + tick.length; y: 0.75 }
    }
}
