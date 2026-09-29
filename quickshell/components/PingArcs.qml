pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

// A sonar ping spreading out (Abyss theme): arcs round (cx, cy), fading as
// they go. Angles as Qt's: 0 at three o'clock, clockwise; the default
// quarter faces the top-right corner.
Item {
    id: ping

    property real cx: 0
    property real cy: height
    property real startAngle: 270
    property real sweep: 90
    property color color: "#7ff0d8"
    property int rings: 3
    property real gap: 7
    property real lineWidth: 1

    Repeater {
        model: ping.rings

        Shape {
            id: arc
            required property int index
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            opacity: 0.85 - arc.index * (0.6 / Math.max(1, ping.rings))

            ShapePath {
                fillColor: "transparent"
                strokeColor: ping.color
                strokeWidth: ping.lineWidth
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: ping.cx
                    centerY: ping.cy
                    radiusX: ping.gap * (arc.index + 1)
                    radiusY: radiusX
                    startAngle: ping.startAngle
                    sweepAngle: ping.sweep
                }
            }
        }
    }
}
