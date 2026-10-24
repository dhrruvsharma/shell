import QtQuick
import QtQuick.Shapes
import qs.colors
import qs.services as Services

// Sekiro frame for shell pieces under the desktop theme: a fill shaped like
// a posture gauge (the ends tapering to a point) with a hairline round it,
// and the gauge's white tick standing at the middle of its head and foot.
// Drawn directly (no layer), like HudFrame; for items whose colour is set
// by their users, mask them with PostureMask and draw this over them with a
// transparent fill.
Shape {
    id: frame

    property real taper: 9
    property color fill: Colors.surface_container
    property color stroke: Services.DesktopTheme.accentOf("sekiro")
    property real strokeWidth: 1
    property real inset: 0.5
    // The gauge's centre ticks, top and bottom (0 for none).
    property real tick: 0

    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: frame.fill
        strokeColor: frame.stroke
        strokeWidth: frame.strokeWidth
        joinStyle: ShapePath.MiterJoin

        PathPolyline {
            path: ThemeShapes.spindle(0, 0, frame.width, frame.height, frame.taper, frame.inset)
        }
    }

    ShapePath {
        fillColor: "transparent"
        strokeColor: frame.tick > 0 ? Colors.withAlpha("#f4efe4", 0.85) : "transparent"
        strokeWidth: 1

        startX: Math.round(frame.width / 2) + 0.5
        startY: 0
        PathLine { x: Math.round(frame.width / 2) + 0.5; y: frame.tick }
        PathMove { x: Math.round(frame.width / 2) + 0.5; y: frame.height - frame.tick }
        PathLine { x: Math.round(frame.width / 2) + 0.5; y: frame.height }
    }
}
