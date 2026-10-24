pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.colors
import qs.modules.lock.themes.artdeco

// Art Deco's wheel: the dial over an elevator's doors, gone round. Black
// lacquer fanned with gilt rays under stepped gilt rings, the floors
// numbered round its rim, turning with the apps; the pointer is the dial's
// gilt needle, reaching from the rim to the chosen app's name.
Item {
    id: face

    required property LauncherDial dial

    readonly property real r: dial.radius

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
                strokeColor: Deco.gold
                strokeWidth: 2
                fillColor: Colors.withAlpha(Deco.lacquer, 0.97)

                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r - 1
                    radiusY: face.r - 1
                    sweepAngle: 360
                }
            }

            // Rays: every other wedge of a fan of 64, gilt.
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: face.r
                    centerY: face.r
                    centerRadius: face.r * 0.8
                    focalX: face.r
                    focalY: face.r
                    GradientStop { position: 0; color: Colors.withAlpha(Deco.gold, 0.32) }
                    GradientStop { position: 1; color: Colors.withAlpha(Deco.gold, 0.08) }
                }

                PathPolyline {
                    path: {
                        const out = [];
                        const n = 64;
                        for (let i = 0; i < n; i += 2) {
                            const a0 = i * 2 * Math.PI / n;
                            const a1 = (i + 1) * 2 * Math.PI / n;
                            out.push(Qt.point(face.r, face.r));
                            out.push(Qt.point(face.r + Math.cos(a0) * face.r * 0.8, face.r + Math.sin(a0) * face.r * 0.8));
                            out.push(Qt.point(face.r + Math.cos(a1) * face.r * 0.8, face.r + Math.sin(a1) * face.r * 0.8));
                        }
                        out.push(Qt.point(face.r, face.r));
                        return out;
                    }
                }
            }

            // The stepped rings.
            ShapePath {
                fillColor: "transparent"
                strokeColor: Deco.gold
                strokeWidth: 1.5

                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r - 9
                    radiusY: face.r - 9
                    sweepAngle: 360
                }
                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r * 0.8
                    radiusY: face.r * 0.8
                    sweepAngle: 360
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: Colors.withAlpha(Deco.gold, 0.45)
                strokeWidth: 1

                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r - 15
                    radiusY: face.r - 15
                    sweepAngle: 360
                }
                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r * 0.8 - 6
                    radiusY: face.r * 0.8 - 6
                    sweepAngle: 360
                }
                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r * 0.3
                    radiusY: face.r * 0.3
                    sweepAngle: 360
                }
            }
        }

        // The floors.
        Repeater {
            model: 24

            Item {
                id: floor
                required property int index
                readonly property real deg: index * 15
                readonly property real a: deg * Math.PI / 180
                x: face.r + Math.cos(a) * (face.r * 0.9 - 4) - width / 2
                y: face.r + Math.sin(a) * (face.r * 0.9 - 4) - height / 2
                width: 30
                height: 30
                rotation: deg + 90

                Text {
                    anchors.centerIn: parent
                    text: floor.index === 0 ? "L" : String(floor.index)
                    font.family: Deco.display
                    font.pixelSize: 20
                    font.weight: Font.Bold
                    color: Deco.gold
                }

                // A diamond between floors.
                Rectangle {
                    x: parent.width / 2 + 23
                    y: parent.height / 2 - 3
                    width: 6
                    height: 6
                    rotation: 45
                    color: Colors.withAlpha(Deco.gold, 0.6)
                }
            }
        }
    }

    // The needle: a long gilt lozenge from a boss on the rim to the name.
    Shape {
        id: needle

        readonly property real x0: face.dial.cx + face.r - 12
        readonly property real x1: face.dial.nameX - 24
        readonly property real cy: face.dial.cy

        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: face.dial.nameShown

        ShapePath {
            strokeColor: Deco.goldDeep
            strokeWidth: 1
            joinStyle: ShapePath.MiterJoin
            fillGradient: LinearGradient {
                x1: 0
                y1: needle.cy - 6
                x2: 0
                y2: needle.cy + 6
                GradientStop { position: 0; color: Deco.goldHi }
                GradientStop { position: 0.5; color: Deco.gold }
                GradientStop { position: 1; color: Deco.goldDeep }
            }
            startX: needle.x0
            startY: needle.cy
            PathLine { x: needle.x0 + 40; y: needle.cy - 6 }
            PathLine { x: needle.x1; y: needle.cy }
            PathLine { x: needle.x0 + 40; y: needle.cy + 6 }
            PathLine { x: needle.x0; y: needle.cy }
        }
    }

    Rectangle {
        x: face.dial.cx + face.r - 12 - width / 2
        y: face.dial.cy - height / 2
        width: 20
        height: 20
        radius: 10
        opacity: face.dial.nameShown
        border.width: 1
        border.color: Deco.goldDeep
        gradient: Gradient {
            GradientStop { position: 0; color: Deco.goldHi }
            GradientStop { position: 1; color: Deco.goldDeep }
        }
    }
}
