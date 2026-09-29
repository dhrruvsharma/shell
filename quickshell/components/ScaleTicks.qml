import QtQuick
import QtQuick.Shapes

// A graduated edge for the Observatory theme: ticks along its width like the
// limb of an instrument, every `major`th one longer. They hang from its top
// edge, or stand on its bottom edge with `up`.
Shape {
    id: ticks

    property real step: 4
    property int major: 5
    property real minorLength: 3
    property real majorLength: 6
    property color color: "#c29a48"
    property real lineWidth: 1
    property bool up: false

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: "transparent"
        strokeColor: ticks.color
        strokeWidth: ticks.lineWidth
        capStyle: ShapePath.FlatCap

        PathMultiline {
            paths: {
                const out = [];
                const n = Math.floor(ticks.width / Math.max(1, ticks.step));
                // Centre the graduation along the edge.
                const x0 = (ticks.width - n * ticks.step) / 2;
                for (let i = 0; i <= n; i++) {
                    const x = Math.round(x0 + i * ticks.step) + 0.5;
                    const len = i % ticks.major === 0 ? ticks.majorLength : ticks.minorLength;
                    out.push(ticks.up ? [Qt.point(x, ticks.height), Qt.point(x, ticks.height - len)] : [Qt.point(x, 0), Qt.point(x, len)]);
                }
                return out;
            }
        }
    }
}
