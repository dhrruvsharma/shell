import QtQuick
import QtQuick.Shapes

// Siege silhouette (the top edge cut into battlements) for shell pieces
// under the desktop theme, as a MultiEffect maskSource; the CrenelFrame
// counterpart of HudMask:
//
//   layer.enabled: crenel
//   layer.effect: MultiEffect { maskEnabled: true; maskSource: mask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
//   CrenelMask { id: mask; active: crenel }
//
// It never draws itself; `active` gates its texture.
Shape {
    id: mask

    property bool active: false
    // About how wide a merlon is, and how far the crenels are cut down.
    property real merlon: 8
    property real depth: 3

    anchors.fill: parent
    visible: false
    layer.enabled: active
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: "white"
        strokeColor: "transparent"

        PathPolyline {
            path: ThemeShapes.crenel(0, 0, mask.width, mask.height, mask.merlon, mask.depth)
        }
    }
}
