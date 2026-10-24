pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.colors
import qs.components
import qs.modules.lock.themes.sekiro

// Sekiro's wheel: a great iron tsuba. Hammered plate under a raised rim, a
// ring of gold inlay and nanako dots, the two hitsu-ana cut beside the
// tang's hole, the season's character inlaid in gold, all turning with the
// apps; the light on it stays where it is. The pointer is the blade: a
// gold habaki at the rim, then steel with its temper line running out to
// the chosen app's name, which is brushed over a swash of crimson.
Item {
    id: face

    required property LauncherDial dial

    readonly property real r: dial.radius
    readonly property color gold: "#c9a55c"
    readonly property color iron: "#2a2426"
    readonly property var season: Shinobi.season(new Date())

    // ── The guard ────────────────────────────────────────────────────────────

    Item {
        id: disc
        x: face.dial.cx - face.r
        y: face.dial.cy - face.r
        width: face.r * 2
        height: width
        rotation: face.dial.turn

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: "#050405"
                strokeWidth: 1.5
                fillGradient: RadialGradient {
                    centerX: face.r
                    centerY: face.r
                    centerRadius: face.r
                    focalX: face.r
                    focalY: face.r
                    GradientStop { position: 0; color: "#3d3538" }
                    GradientStop { position: 0.7; color: face.iron }
                    GradientStop { position: 0.93; color: "#1d181a" }
                    GradientStop { position: 1; color: "#120e10" }
                }

                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r - 1
                    radiusY: face.r - 1
                    startAngle: 0
                    sweepAngle: 360
                }
            }

            // The raised rim (mimi), and the gold inlay inside it.
            ShapePath {
                fillColor: "transparent"
                strokeColor: "#0d0a0b"
                strokeWidth: 9

                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r - 6
                    radiusY: face.r - 6
                    startAngle: 0
                    sweepAngle: 360
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: Colors.withAlpha(face.gold, 0.6)
                strokeWidth: 1.5

                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r * 0.86
                    radiusY: face.r * 0.86
                    startAngle: 0
                    sweepAngle: 360
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: Colors.withAlpha(face.gold, 0.28)
                strokeWidth: 1

                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r * 0.84
                    radiusY: face.r * 0.84
                    startAngle: 0
                    sweepAngle: 360
                }
            }
        }

        // Hammer marks (tsuchime) over the plate.
        Repeater {
            model: 110

            Rectangle {
                required property int index
                readonly property real a: index * 2.3999632
                readonly property real d: face.r * (0.32 + 0.6 * ((index * 0.6180339) % 1))
                x: face.r + Math.cos(a) * d - width / 2
                y: face.r + Math.sin(a) * d - height / 2
                width: 14 + (index * 7) % 18
                height: width * 0.62
                radius: height / 2
                rotation: (index * 47) % 180
                color: index % 3 === 0 ? Colors.withAlpha("white", 0.025) : Colors.withAlpha("black", 0.085)
            }
        }

        // Nanako: a ring of gold dots inside the inlay.
        Repeater {
            model: 72

            Rectangle {
                required property int index
                readonly property real a: index * 5 * Math.PI / 180
                x: face.r + Math.cos(a) * face.r * 0.8 - width / 2
                y: face.r + Math.sin(a) * face.r * 0.8 - height / 2
                width: index % 6 === 0 ? 5 : 2.5
                height: width
                radius: width / 2
                color: Colors.withAlpha(face.gold, index % 6 === 0 ? 0.75 : 0.45)
            }
        }

        // The hitsu-ana, either side of the tang's hole.
        Repeater {
            model: [-1, 1]

            Rectangle {
                required property var modelData
                x: face.r - width / 2
                y: face.r + modelData * face.r * 0.42 - height / 2
                width: face.r * 0.1
                height: face.r * 0.22
                radius: width / 2
                color: "#050405"
                border.width: 1
                border.color: Colors.withAlpha(face.gold, 0.35)
            }
        }

        // The season, inlaid in gold, at the four quarters.
        Repeater {
            model: 4

            Text {
                required property int index
                readonly property real a: (index * 90 + 45) * Math.PI / 180
                x: face.r + Math.cos(a) * face.r * 0.6 - width / 2
                y: face.r + Math.sin(a) * face.r * 0.6 - height / 2
                rotation: index * 90 + 135
                text: face.season.kanji
                font.family: Shinobi.brush
                font.pixelSize: face.r * 0.13
                color: Colors.withAlpha(face.gold, 0.55)
            }
        }
    }

    // The light on the iron: from the top right, staying put as it turns.
    Shape {
        x: disc.x
        y: disc.y
        width: disc.width
        height: disc.height
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: face.r * 1.6
                y1: face.r * 0.25
                x2: face.r * 0.6
                y2: face.r * 1.75
                GradientStop { position: 0; color: Colors.withAlpha("white", 0.09) }
                GradientStop { position: 0.5; color: "transparent" }
                GradientStop { position: 1; color: Colors.withAlpha("black", 0.3) }
            }

            PathAngleArc {
                centerX: face.r
                centerY: face.r
                radiusX: face.r - 1
                radiusY: face.r - 1
                startAngle: 0
                sweepAngle: 360
            }
        }
    }

    // ── The blade ────────────────────────────────────────────────────────────

    // A swash of crimson under the name, brushed in as it comes.
    BrushStroke {
        x: face.dial.nameX - 26
        y: face.dial.nameY + face.dial.nameHeight * 0.14
        width: face.dial.nameWidth + 90
        height: face.dial.nameHeight * 0.78
        visible: face.dial.app !== null
        reveal: face.dial.nameShown
        ink: Colors.withAlpha(Shinobi.blood, 0.82)
        seed: face.dial.current * 0.37 + 1.3
        dry: 0.6
        weight: 0.88
    }

    Shape {
        id: blade

        readonly property real x0: face.dial.cx + face.r + 2
        readonly property real x1: face.dial.nameX - 30
        readonly property real cy: face.dial.cy

        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: face.dial.nameShown

        // Steel: the back straight, the edge sweeping up into the point.
        ShapePath {
            strokeColor: "#0b0a0a"
            strokeWidth: 1
            joinStyle: ShapePath.MiterJoin
            fillGradient: LinearGradient {
                x1: 0
                y1: blade.cy - 8
                x2: 0
                y2: blade.cy + 9
                GradientStop { position: 0; color: "#9a9ca3" }
                GradientStop { position: 0.38; color: "#d9dade" }
                GradientStop { position: 0.42; color: "#7c7e85" }
                GradientStop { position: 0.75; color: "#c6c8cd" }
                GradientStop { position: 1; color: "#f4f2ec" }
            }
            startX: blade.x0
            startY: blade.cy - 7

            PathLine { x: blade.x1 - 34; y: blade.cy - 8 }
            PathQuad { x: blade.x1; y: blade.cy - 1; controlX: blade.x1 - 10; controlY: blade.cy - 8 }
            PathQuad { x: blade.x1 - 44; y: blade.cy + 7; controlX: blade.x1 - 22; controlY: blade.cy + 8 }
            PathLine { x: blade.x0; y: blade.cy + 8 }
            PathLine { x: blade.x0; y: blade.cy - 7 }
        }

        // The temper line (hamon), waving along the edge.
        ShapePath {
            fillColor: "transparent"
            strokeColor: Colors.withAlpha("white", 0.85)
            strokeWidth: 1.2
            capStyle: ShapePath.RoundCap

            PathPolyline {
                path: {
                    const out = [];
                    const n = 40;
                    for (let i = 0; i <= n; i++) {
                        const x = blade.x0 + 10 + (blade.x1 - 58 - blade.x0) * i / n;
                        out.push(Qt.point(x, blade.cy + 3.2 + Math.sin(i * 1.7) * 1.3));
                    }
                    return out;
                }
            }
        }
    }

    // The habaki, the gold collar where the blade leaves the guard.
    Rectangle {
        x: face.dial.cx + face.r - 6
        y: face.dial.cy - height / 2
        width: 20
        height: 22
        radius: 2
        opacity: face.dial.nameShown
        border.width: 1
        border.color: "#3a2a10"
        gradient: Gradient {
            GradientStop { position: 0; color: "#f2d48a" }
            GradientStop { position: 0.5; color: face.gold }
            GradientStop { position: 1; color: "#7a5a22" }
        }
    }
}
