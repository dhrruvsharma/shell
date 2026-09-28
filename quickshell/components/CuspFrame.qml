import QtQuick
import QtQuick.Shapes
import qs.colors
import qs.services as Services

// Cathedral frame for shell pieces under the desktop theme: a fill with its
// corners scooped out, a jewel-toned hairline round it and, with `gap`, a
// second line of lead inside it. Drawn directly (no layer), like HudFrame;
// for items whose colour is set by their users, mask them with CuspMask and
// draw this over them with a transparent fill.
Shape {
    id: frame

    property real cut: 5
    property color fill: Colors.surface_container
    property color stroke: Services.DesktopTheme.accentOf("gothic")
    property real strokeWidth: 1
    // Distance of the inner line from the outer one; 0 for none.
    property real gap: 0
    property color innerStroke: Qt.rgba(stroke.r, stroke.g, stroke.b, 0.4)
    property real inset: 0.5

    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: frame.fill
        strokeColor: frame.stroke
        strokeWidth: frame.strokeWidth
        joinStyle: ShapePath.RoundJoin

        PathPolyline {
            path: ThemeShapes.cusp(frame.inset, frame.inset, frame.width - 2 * frame.inset, frame.height - 2 * frame.inset, frame.cut)
        }
    }

    ShapePath {
        fillColor: "transparent"
        strokeColor: frame.gap > 0 ? frame.innerStroke : "transparent"
        strokeWidth: 1
        joinStyle: ShapePath.RoundJoin

        PathPolyline {
            readonly property real i: frame.inset + frame.gap
            path: frame.gap > 0 ? ThemeShapes.cusp(i, i, frame.width - 2 * i, frame.height - 2 * i, Math.max(1, frame.cut - frame.gap * 0.4)) : []
        }
    }
}
