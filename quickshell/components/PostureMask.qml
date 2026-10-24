import QtQuick
import QtQuick.Shapes

// Sekiro silhouette (a posture gauge: the ends tapering to a point) for
// shell pieces under the desktop theme, as a MultiEffect maskSource; the
// PostureFrame counterpart of HudMask:
//
//   layer.enabled: posture
//   layer.effect: MultiEffect { maskEnabled: true; maskSource: mask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
//   PostureMask { id: mask; active: posture }
//
// It never draws itself; `active` gates its texture.
Shape {
    id: mask

    property bool active: false
    // How far in from each end the taper runs.
    property real taper: 9

    anchors.fill: parent
    visible: false
    layer.enabled: active
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: "white"
        strokeColor: "transparent"

        PathPolyline {
            path: ThemeShapes.spindle(0, 0, mask.width, mask.height, mask.taper)
        }
    }
}
