import QtQuick
import QtQuick.Shapes
import qs.colors
import qs.services as Services

// Art Deco frame for shell pieces under the desktop theme: a fill with every
// corner stepped in, a gold hairline round it and, with `gap`, a second,
// fainter line inside it (the double rule of a Deco border). Drawn directly
// (no layer), like HudFrame; for items whose colour is set by their users,
// mask them with DecoMask and draw this over them with a transparent fill.
Shape {
    id: frame

    property real cut: 5
    property int steps: 1
    property color fill: Colors.surface_container
    property color stroke: Services.DesktopTheme.accentOf("artdeco")
    property real strokeWidth: 1
    // Distance of the inner line from the outer one; 0 for none.
    property real gap: 0
    property color innerStroke: Qt.rgba(stroke.r, stroke.g, stroke.b, 0.45)
    // How far inside the item the line runs; more than half the stroke
    // keeps it clear of a DecoMask's antialiased edge.
    property real inset: 0.5

    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: frame.fill
        strokeColor: frame.stroke
        strokeWidth: frame.strokeWidth
        joinStyle: ShapePath.MiterJoin

        PathPolyline {
            path: ThemeShapes.deco(frame.inset, frame.inset, frame.width - 2 * frame.inset, frame.height - 2 * frame.inset, frame.cut, frame.steps)
        }
    }

    ShapePath {
        fillColor: "transparent"
        strokeColor: frame.gap > 0 ? frame.innerStroke : "transparent"
        strokeWidth: 1
        joinStyle: ShapePath.MiterJoin

        PathPolyline {
            readonly property real i: frame.inset + frame.gap
            path: frame.gap > 0 ? ThemeShapes.deco(i, i, frame.width - 2 * i, frame.height - 2 * i, frame.cut, frame.steps) : []
        }
    }
}
