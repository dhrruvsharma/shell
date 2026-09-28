import QtQuick
import QtQuick.Shapes

// Art Deco silhouette (every corner stepped in, like a ziggurat) for shell
// pieces under the desktop theme, as a MultiEffect maskSource; the DecoFrame
// counterpart of HudMask:
//
//   layer.enabled: deco
//   layer.effect: MultiEffect { maskEnabled: true; maskSource: mask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
//   DecoMask { id: mask; active: deco }
//
// It never draws itself; `active` gates its texture.
Shape {
    id: mask

    property bool active: false
    // Size of one step, and how many steps each corner takes (1 or 2).
    property real cut: 4
    property int steps: 1

    anchors.fill: parent
    visible: false
    layer.enabled: active
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: "white"
        strokeColor: "transparent"

        PathPolyline {
            path: ThemeShapes.deco(0, 0, mask.width, mask.height, mask.cut, mask.steps)
        }
    }
}
