import QtQuick
import QtQuick.Shapes
import qs.modules.lock

// Translucent HUD panel with chamfered top-left and bottom-right corners and an
// accent stroke running along the top-left chamfer. Children are laid out on
// top of it like any Item.
Item {
    id: panel

    property real cut: 12
    property color fill: LockTheme.panel
    property color stroke: LockTheme.line
    property color accent: LockTheme.accent
    property real accentLength: 34
    property bool showAccent: true

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: panel.fill
            strokeColor: panel.stroke
            strokeWidth: 1
            joinStyle: ShapePath.MiterJoin
            startX: panel.cut
            startY: 0.5
            PathLine { x: panel.width - 0.5; y: 0.5 }
            PathLine { x: panel.width - 0.5; y: panel.height - panel.cut }
            PathLine { x: panel.width - panel.cut; y: panel.height - 0.5 }
            PathLine { x: 0.5; y: panel.height - 0.5 }
            PathLine { x: 0.5; y: panel.cut }
            PathLine { x: panel.cut; y: 0.5 }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: panel.showAccent ? panel.accent : "transparent"
            strokeWidth: 2
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.MiterJoin
            startX: 1
            startY: panel.cut + 12
            PathLine { x: 1; y: panel.cut }
            PathLine { x: panel.cut; y: 1 }
            PathLine { x: panel.cut + panel.accentLength; y: 1 }
        }
    }
}
