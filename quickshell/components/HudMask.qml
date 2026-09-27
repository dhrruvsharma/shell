import QtQuick
import QtQuick.Shapes

// Chamfered silhouette (top-left and bottom-right corners cut) for HUD-styled
// shell pieces under the desktop theme. Use it as a MultiEffect maskSource:
//
//   layer.enabled: hud
//   layer.effect: MultiEffect { maskEnabled: true; maskSource: mask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
//   HudMask { id: mask; active: hud }
//
// It never draws itself; `active` gates its texture so it costs nothing when
// the theme is off.
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
        startX: mask.cut
        startY: 0
        PathLine { x: mask.width; y: 0 }
        PathLine { x: mask.width; y: mask.height - mask.cut }
        PathLine { x: mask.width - mask.cut; y: mask.height }
        PathLine { x: 0; y: mask.height }
        PathLine { x: 0; y: mask.cut }
        PathLine { x: mask.cut; y: 0 }
    }
}
