pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

// The floor indicator over a 1920s elevator: a half dial fanned with rays,
// its marks (and optional labels) round the rim, and a needle. Art Deco's
// mark: the floor you've risen to on the desktop, the hours on the clock,
// and the passcode climbing floor by floor on the lock screen.
Item {
    id: dial

    // 0..1 from the left end of the dial to the right.
    property real value: 0
    property int ticks: 13
    // Optional labels, spread evenly from left to right.
    property var labels: []
    property string labelFont: Deco.display
    property real labelSize: radius * 0.16
    property color color: Deco.gold
    property color needleColor: Deco.goldHi
    property color labelColor: Deco.ivory
    property real line: Math.max(1, radius / 60)
    readonly property real radius: width / 2

    height: radius + radius * 0.14

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // The fan inside the dial: alternate wedges faintly gilt.
        ShapePath {
            fillColor: Qt.rgba(dial.color.r, dial.color.g, dial.color.b, 0.12)
            strokeColor: "transparent"

            PathMultiline {
                paths: {
                    const out = [];
                    const cx = dial.radius, cy = dial.radius;
                    const n = 16;
                    for (let i = 0; i < n; i += 2) {
                        const a0 = Math.PI + i * Math.PI / n;
                        const a1 = Math.PI + (i + 1) * Math.PI / n;
                        const r = dial.radius * 0.7;
                        out.push([Qt.point(cx, cy), Qt.point(cx + Math.cos(a0) * r, cy + Math.sin(a0) * r), Qt.point(cx + Math.cos(a1) * r, cy + Math.sin(a1) * r), Qt.point(cx, cy)]);
                    }
                    return out;
                }
            }
        }

        // The rim, doubled.
        ShapePath {
            fillColor: "transparent"
            strokeColor: dial.color
            strokeWidth: dial.line * 1.4
            capStyle: ShapePath.FlatCap

            PathAngleArc {
                centerX: dial.radius
                centerY: dial.radius
                radiusX: dial.radius - dial.line
                radiusY: dial.radius - dial.line
                startAngle: 180
                sweepAngle: 180
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(dial.color.r, dial.color.g, dial.color.b, 0.55)
            strokeWidth: dial.line
            capStyle: ShapePath.FlatCap

            PathAngleArc {
                centerX: dial.radius
                centerY: dial.radius
                radiusX: dial.radius * 0.72
                radiusY: dial.radius * 0.72
                startAngle: 180
                sweepAngle: 180
            }
        }

        // The marks.
        ShapePath {
            fillColor: "transparent"
            strokeColor: dial.color
            strokeWidth: dial.line
            capStyle: ShapePath.FlatCap

            PathMultiline {
                paths: {
                    const out = [];
                    const cx = dial.radius, cy = dial.radius;
                    const n = Math.max(2, dial.ticks);
                    for (let i = 0; i < n; i++) {
                        const a = Math.PI + i * Math.PI / (n - 1);
                        const r0 = dial.radius * (i % 2 === 0 ? 0.76 : 0.8);
                        const r1 = dial.radius * 0.9;
                        out.push([Qt.point(cx + Math.cos(a) * r0, cy + Math.sin(a) * r0), Qt.point(cx + Math.cos(a) * r1, cy + Math.sin(a) * r1)]);
                    }
                    return out;
                }
            }
        }

        // The needle, with its tail.
        ShapePath {
            fillColor: dial.needleColor
            strokeColor: "transparent"

            PathPolyline {
                path: {
                    const cx = dial.radius, cy = dial.radius;
                    const a = Math.PI + Math.max(0, Math.min(1, dial.value)) * Math.PI;
                    const r = dial.radius * 0.84;
                    const w = Math.max(1.5, dial.radius * 0.035);
                    const nx = -Math.sin(a), ny = Math.cos(a);
                    return [
                        Qt.point(cx + Math.cos(a) * r, cy + Math.sin(a) * r),
                        Qt.point(cx + nx * w, cy + ny * w),
                        Qt.point(cx - Math.cos(a) * r * 0.16, cy - Math.sin(a) * r * 0.16),
                        Qt.point(cx - nx * w, cy - ny * w),
                        Qt.point(cx + Math.cos(a) * r, cy + Math.sin(a) * r)
                    ];
                }
            }
        }

        // The hub.
        ShapePath {
            fillColor: dial.color
            strokeColor: Deco.lacquer
            strokeWidth: dial.line

            PathAngleArc {
                centerX: dial.radius
                centerY: dial.radius
                radiusX: dial.radius * 0.08
                radiusY: dial.radius * 0.08
                startAngle: 0
                sweepAngle: 360
            }
        }
    }

    Repeater {
        model: dial.labels

        Text {
            required property string modelData
            required property int index
            readonly property real a: Math.PI + index * Math.PI / Math.max(1, dial.labels.length - 1)
            readonly property real r: dial.radius * 0.58
            x: dial.radius + Math.cos(a) * r - width / 2
            y: dial.radius + Math.sin(a) * r - height / 2
            text: modelData
            font.family: dial.labelFont
            font.pixelSize: dial.labelSize
            font.weight: Font.DemiBold
            color: dial.labelColor
        }
    }
}
