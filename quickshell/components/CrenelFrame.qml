import QtQuick
import QtQuick.Shapes
import qs.colors
import qs.services as Services

// Siege frame for shell pieces under the desktop theme: a fill whose top
// edge is cut into battlements, with a hairline round it. Drawn directly
// (no layer), like HudFrame; for items whose colour is set by their users,
// mask them with CrenelMask and draw this over them with a transparent
// fill.
Shape {
    id: frame

    property real merlon: 8
    property real depth: 3
    property color fill: Colors.surface_container
    property color stroke: Services.DesktopTheme.accentOf("siege")
    property real strokeWidth: 1
    property real inset: 0.5

    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: frame.fill
        strokeColor: frame.stroke
        strokeWidth: frame.strokeWidth
        joinStyle: ShapePath.MiterJoin

        PathPolyline {
            path: ThemeShapes.crenel(0, 0, frame.width, frame.height, frame.merlon, frame.depth, frame.inset)
        }
    }
}
