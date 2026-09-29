import QtQuick
import QtQuick.Shapes

// A temple border for the Devaloka theme: the row of little spires woven
// along a Kanchipuram sari's edge (after the towers of the temples) across
// its width, standing on a fine rule at its bottom edge, or hanging from
// one at its top with `down`. The spires are stretched a little so a whole
// number of them fits.
Item {
    id: border

    property real step: 6
    property color color: "#d8a23a"
    property bool down: false
    // The rule the spires stand on; 0 for none.
    property real rule: 1

    readonly property int count: Math.max(1, Math.floor(width / Math.max(2, step)))

    Rectangle {
        visible: border.rule > 0
        y: border.down ? 0 : border.height - height
        width: border.width
        height: border.rule
        color: border.color
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: border.color
            strokeColor: "transparent"

            PathPolyline {
                path: {
                    const w = border.width;
                    const h = border.height;
                    const n = border.count;
                    const s = w / n;
                    const base = border.down ? 0 : h;
                    const tip = border.down ? h : 0;
                    const pts = [Qt.point(0, base)];
                    for (let i = 0; i < n; i++) {
                        pts.push(Qt.point((i + 0.5) * s, tip));
                        pts.push(Qt.point((i + 1) * s, base));
                    }
                    pts.push(Qt.point(0, base));
                    return pts;
                }
            }
        }
    }
}
