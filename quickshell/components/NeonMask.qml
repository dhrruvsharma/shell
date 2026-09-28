import QtQuick
import QtQuick.Shapes

// Neon Noir silhouette (top-right corner cut) for shell pieces under the
// desktop theme, as a MultiEffect maskSource; the NeonFrame counterpart of
// HudMask:
//
//   layer.enabled: neon
//   layer.effect: MultiEffect { maskEnabled: true; maskSource: mask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
//   NeonMask { id: mask; active: neon }
//
// It never draws itself; `active` gates its texture.
Shape {
    id: mask

    property bool active: false
    property real cut: 7

    anchors.fill: parent
    visible: false
    layer.enabled: active
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: "white"
        strokeColor: "transparent"
        startX: 0
        startY: 0
        PathLine { x: mask.width - mask.cut; y: 0 }
        PathLine { x: mask.width; y: mask.cut }
        PathLine { x: mask.width; y: mask.height }
        PathLine { x: 0; y: mask.height }
        PathLine { x: 0; y: 0 }
    }
}
