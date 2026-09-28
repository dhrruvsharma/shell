import QtQuick
import QtQuick.Shapes

// A strip of hazard tape (Wasteland): diagonal bands of two colours, cut
// off square at the strip's edges.
Item {
    id: tape

    property real stripe: 6
    property color colorA: "#d9a21b"
    property color colorB: "#16130f"
    // Lean of the bands: +1 top-left to bottom-right, -1 the other way.
    property int lean: -1

    clip: true

    Rectangle {
        anchors.fill: parent
        color: tape.colorA
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: tape.colorB
            strokeColor: "transparent"

            PathMultiline {
                paths: {
                    const out = [];
                    const s = Math.max(1, tape.stripe);
                    const h = tape.height;
                    for (let x = -h - s; x < tape.width + h; x += 2 * s) {
                        const top = tape.lean < 0 ? x + h : x;
                        const bottom = tape.lean < 0 ? x : x + h;
                        out.push([Qt.point(top, 0), Qt.point(top + s, 0), Qt.point(bottom + s, h), Qt.point(bottom, h), Qt.point(top, 0)]);
                    }
                    return out;
                }
            }
        }
    }
}
