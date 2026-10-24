pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.colors

// The Mainframe's wheel: a reel of nine-track tape. The wound tape shows
// through the three windows of its flange, stencilled with the reel's label,
// and the whole reel spins as the apps go by; the pointer is the drive's
// read head at the rim, the tape threading on from it to the chosen app's
// name.
Item {
    id: face

    required property LauncherDial dial

    readonly property real r: dial.radius
    readonly property color accent: dial.accent
    readonly property string mono: dial.monoFont

    // One of the flange's three windows: a sector between the hub and the
    // rim, rounded along the rim.
    function pane(w) {
        const a0 = (w * 120 + 18) * Math.PI / 180;
        const a1 = (w * 120 + 102) * Math.PI / 180;
        const ri = r * 0.3;
        const ro = r * 0.8;
        const pts = [];
        for (let i = 0; i <= 24; i++) {
            const a = a0 + (a1 - a0) * i / 24;
            pts.push(Qt.point(r + Math.cos(a) * ro, r + Math.sin(a) * ro));
        }
        for (let i = 8; i >= 0; i--) {
            const a = a0 + 0.12 + (a1 - a0 - 0.24) * i / 8;
            pts.push(Qt.point(r + Math.cos(a) * ri, r + Math.sin(a) * ri));
        }
        pts.push(pts[0]);
        return pts;
    }

    Item {
        id: disc
        x: face.dial.cx - face.r
        y: face.dial.cy - face.r
        width: face.r * 2
        height: width
        rotation: face.dial.turn

        // The tape pack, wound in layers.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: face.r
                    centerY: face.r
                    centerRadius: face.r * 0.86
                    focalX: face.r
                    focalY: face.r
                    GradientStop { position: 0.3; color: "#3a2b1f" }
                    GradientStop { position: 1; color: "#21170f" }
                }

                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r * 0.86
                    radiusY: face.r * 0.86
                    sweepAngle: 360
                }
            }
        }

        Repeater {
            model: 22

            Rectangle {
                required property int index
                readonly property real rr: face.r * (0.34 + index * 0.024)
                x: face.r - rr
                y: face.r - rr
                width: rr * 2
                height: width
                radius: rr
                color: "transparent"
                border.width: 1
                border.color: index % 2 === 0 ? Colors.withAlpha("black", 0.22) : Colors.withAlpha("#c9a27a", 0.06)
            }
        }

        // The flange, with its three windows cut out.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillRule: ShapePath.OddEvenFill
                strokeColor: Colors.withAlpha(face.accent, 0.55)
                strokeWidth: 1
                fillGradient: LinearGradient {
                    x1: face.r * 2
                    y1: 0
                    x2: 0
                    y2: face.r * 2
                    GradientStop { position: 0; color: "#2b3330" }
                    GradientStop { position: 1; color: "#131816" }
                }

                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r - 1
                    radiusY: face.r - 1
                    sweepAngle: 360
                }

                PathPolyline {
                    path: face.pane(0)
                }
                PathPolyline {
                    path: face.pane(1)
                }
                PathPolyline {
                    path: face.pane(2)
                }
            }
        }

        // The reel's label, stencilled on each spoke.
        Repeater {
            model: 3

            Text {
                required property int index
                readonly property real a: (index * 120 + 120) * Math.PI / 180
                x: face.r + Math.cos(a) * face.r * 0.6 - width / 2
                y: face.r + Math.sin(a) * face.r * 0.6 - height / 2
                rotation: index * 120 + 120
                text: ["SCRATCH 0x2A", "9 TRK · 6250 BPI", "WRITE RING ⏺"][index]
                font.family: face.mono
                font.pixelSize: 13
                font.letterSpacing: 2
                color: Colors.withAlpha(face.accent, 0.7)
            }
        }
    }

    // ── The drive ────────────────────────────────────────────────────────────

    // The read head, at the rim.
    Rectangle {
        x: face.dial.cx + face.r - 4
        y: face.dial.cy - height / 2
        width: 26
        height: 30
        color: "#1b211f"
        border.width: 1
        border.color: face.accent
        opacity: face.dial.nameShown

        Text {
            anchors.centerIn: parent
            text: "▣"
            font.family: face.mono
            font.pixelSize: 14
            color: face.accent
        }
    }

    // The tape threading on to the name.
    Rectangle {
        x: face.dial.cx + face.r + 22
        y: face.dial.cy - height / 2
        width: Math.max(0, face.dial.nameX - 24 - x)
        height: 6
        opacity: face.dial.nameShown
        color: "#3a2b1f"
        border.width: 1
        border.color: Colors.withAlpha(face.accent, 0.35)

        Text {
            anchors.right: parent.right
            anchors.rightMargin: -2
            anchors.verticalCenter: parent.verticalCenter
            text: "▶"
            font.family: face.mono
            font.pixelSize: 14
            color: face.accent
        }
    }
}
