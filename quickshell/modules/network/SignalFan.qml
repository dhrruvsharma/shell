import QtQuick
import QtQuick.Shapes
import qs.colors

// A signal strength as the Wi-Fi sign: a dot and three arcs over it, lit
// as far as `level` (0..1) reaches.
Item {
    id: glyph

    property real level: 0.5
    property color tone: Colors.on_surface_variant
    // brighter: the network in use, or the one pointed at
    property bool lit: false

    // the dot, at the foot; the arcs round it
    readonly property real ox: width / 2
    readonly property real oy: height - 2
    readonly property real reach: Math.min(height - 3, width / 2 / Math.SQRT1_2)
    readonly property int bars: level > 0.7 ? 3 : level > 0.45 ? 2 : level > 0.2 ? 1 : 0
    readonly property color litColor: Colors.withAlpha(tone, lit ? 1 : 0.85)
    readonly property color dimColor: Colors.withAlpha(tone, 0.2)
    readonly property real barWidth: Math.max(1.4, reach * 0.13)

    // (a Shape of its own: one sized by a layout, with paths drawn to its
    // size, would loop)
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            fillColor: glyph.litColor
            PathAngleArc {
                centerX: glyph.ox; centerY: glyph.oy
                radiusX: glyph.reach * 0.12; radiusY: radiusX
                startAngle: 0; sweepAngle: 360
            }
        }

        Bar {
            cx: glyph.ox; cy: glyph.oy
            radius: glyph.reach * (0.12 + 0.88 / 3)
            strokeWidth: glyph.barWidth
            strokeColor: glyph.bars >= 1 ? glyph.litColor : glyph.dimColor
        }
        Bar {
            cx: glyph.ox; cy: glyph.oy
            radius: glyph.reach * (0.12 + 0.88 * 2 / 3)
            strokeWidth: glyph.barWidth
            strokeColor: glyph.bars >= 2 ? glyph.litColor : glyph.dimColor
        }
        Bar {
            cx: glyph.ox; cy: glyph.oy
            radius: glyph.reach
            strokeWidth: glyph.barWidth
            strokeColor: glyph.bars >= 3 ? glyph.litColor : glyph.dimColor
        }
    }

    // one of the sign's arcs, round (cx, cy)
    component Bar: ShapePath {
        id: bar
        property real cx
        property real cy
        property real radius
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
            centerX: bar.cx; centerY: bar.cy
            radiusX: bar.radius; radiusY: bar.radius
            startAngle: 225; sweepAngle: 90
        }
    }
}
