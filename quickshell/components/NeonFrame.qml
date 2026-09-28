pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.colors
import qs.services as Services

// Neon Noir frame for shell pieces under the desktop theme: a fill with its
// top-right corner cut, a neon hairline round it with the second neon along
// the cut, and a faint glow bleeding in from the line. Drawn directly (no
// layer), like HudFrame; for items whose colour is set by their users, mask
// them with NeonMask and draw this over them with a transparent fill.
Shape {
    id: frame

    property real cut: 8
    property color fill: Colors.surface_container
    property color stroke: Services.DesktopTheme.accentOf("cyberpunk")
    property color edge: Services.DesktopTheme.accent2Of("cyberpunk")
    property real strokeWidth: 1
    // 0..1: the faint tube glow inside the line.
    property real glow: 0.5
    // How far inside the item the line runs; more than half the stroke
    // keeps it clear of a NeonMask's antialiased edge.
    property real inset: 0.5

    readonly property real _i: inset
    readonly property real _c: cut + inset * 0.6

    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    component Outline: ShapePath {
        joinStyle: ShapePath.MiterJoin
        startX: frame._i
        startY: frame._i
        PathLine { x: frame.width - frame._c; y: frame._i }
        PathLine { x: frame.width - frame._i; y: frame._c }
        PathLine { x: frame.width - frame._i; y: frame.height - frame._i }
        PathLine { x: frame._i; y: frame.height - frame._i }
        PathLine { x: frame._i; y: frame._i }
    }

    Outline {
        fillColor: frame.fill
        strokeColor: frame.glow > 0 ? Qt.rgba(frame.stroke.r, frame.stroke.g, frame.stroke.b, 0.2 * frame.glow) : "transparent"
        strokeWidth: frame.strokeWidth + 4
    }

    Outline {
        fillColor: "transparent"
        strokeColor: Qt.rgba(frame.stroke.r, frame.stroke.g, frame.stroke.b, 0.8)
        strokeWidth: frame.strokeWidth
    }

    ShapePath {
        fillColor: "transparent"
        strokeColor: frame.edge
        strokeWidth: frame.strokeWidth + 0.5
        capStyle: ShapePath.FlatCap
        joinStyle: ShapePath.MiterJoin
        startX: frame.width - frame._c - 4
        startY: frame._i
        PathLine { x: frame.width - frame._c; y: frame._i }
        PathLine { x: frame.width - frame._i; y: frame._c }
        PathLine { x: frame.width - frame._i; y: frame._c + 4 }
    }
}
