import QtQuick
import QtQuick.Shapes

// Cathedral silhouette (every corner scooped out, like a cusped tracery
// panel) for shell pieces under the desktop theme, as a MultiEffect
// maskSource; the CuspFrame counterpart of HudMask:
//
//   layer.enabled: cusp
//   layer.effect: MultiEffect { maskEnabled: true; maskSource: mask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
//   CuspMask { id: mask; active: cusp }
//
// It never draws itself; `active` gates its texture.
Shape {
    id: mask

    property bool active: false
    // Radius of the scoops.
    property real cut: 5

    anchors.fill: parent
    visible: false
    layer.enabled: active
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: "white"
        strokeColor: "transparent"

        PathPolyline {
            path: ThemeShapes.cusp(0, 0, mask.width, mask.height, mask.cut)
        }
    }
}
