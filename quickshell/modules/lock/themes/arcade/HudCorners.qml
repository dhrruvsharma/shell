pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.modules.lock

// Viewfinder brackets in the four screen corners. `enter` (0..1) slides them
// in from beyond the screen edge.
Item {
    id: corners

    property real size: 44
    property real margin: 24
    property real thickness: 2
    property color color: LockTheme.alpha(LockTheme.accent, 0.7)
    property real enter: 1

    Repeater {
        model: 4

        Shape {
            id: bracket

            required property int index
            readonly property bool isRight: index === 1 || index === 2
            readonly property bool isBottom: index >= 2
            readonly property real off: (1 - corners.enter) * corners.size * 1.5
            readonly property real t: corners.thickness / 2
            readonly property real s: corners.size

            width: s
            height: s
            x: isRight ? corners.width - corners.margin - s + off : corners.margin - off
            y: isBottom ? corners.height - corners.margin - s + off : corners.margin - off
            opacity: corners.enter
            preferredRendererType: Shape.CurveRenderer

            // Each bracket is an L: arm end -> corner -> other arm end.
            ShapePath {
                strokeColor: corners.color
                strokeWidth: corners.thickness
                fillColor: "transparent"
                capStyle: ShapePath.FlatCap
                joinStyle: ShapePath.MiterJoin
                startX: bracket.isRight ? bracket.s - bracket.t : bracket.t
                startY: bracket.isBottom ? bracket.t : bracket.s - bracket.t
                PathLine {
                    x: bracket.isRight ? bracket.s - bracket.t : bracket.t
                    y: bracket.isBottom ? bracket.s - bracket.t : bracket.t
                }
                PathLine {
                    x: bracket.isRight ? bracket.t : bracket.s - bracket.t
                    y: bracket.isBottom ? bracket.s - bracket.t : bracket.t
                }
            }

            // Small square pip just inside the corner.
            Rectangle {
                width: 4
                height: 4
                color: corners.color
                x: bracket.isRight ? bracket.s - 12 : 8
                y: bracket.isBottom ? bracket.s - 12 : 8
            }
        }
    }
}
