pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.colors

// The Abyss's wheel: a sonar scope. Range rings and a graduated bearing
// ring on dark glass, contacts glowing where they lie, all turning with
// the apps; the sweep stands at three o'clock on the chosen one, its
// afterglow trailing, and its line runs on past the rim to the name.
Item {
    id: face

    required property LauncherDial dial

    readonly property real r: dial.radius
    readonly property color lume: dial.accent2
    readonly property string mono: "B612 Mono"

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
                strokeColor: Colors.withAlpha(face.lume, 0.5)
                strokeWidth: 1.5
                fillGradient: RadialGradient {
                    centerX: face.r
                    centerY: face.r
                    centerRadius: face.r
                    focalX: face.r
                    focalY: face.r
                    GradientStop { position: 0; color: "#0b2a2c" }
                    GradientStop { position: 1; color: "#03100f" }
                }

                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r - 1
                    radiusY: face.r - 1
                    sweepAngle: 360
                }
            }

            // Range rings, and the cross.
            ShapePath {
                fillColor: "transparent"
                strokeColor: Colors.withAlpha(face.lume, 0.18)
                strokeWidth: 1

                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r * 0.25
                    radiusY: face.r * 0.25
                    sweepAngle: 360
                }
                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r * 0.5
                    radiusY: face.r * 0.5
                    sweepAngle: 360
                }
                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r * 0.75
                    radiusY: face.r * 0.75
                    sweepAngle: 360
                }
                PathMultiline {
                    paths: [[Qt.point(0, face.r), Qt.point(face.r * 2, face.r)], [Qt.point(face.r, 0), Qt.point(face.r, face.r * 2)]]
                }
            }

            // The bearing ring.
            ShapePath {
                fillColor: "transparent"
                strokeColor: Colors.withAlpha(face.lume, 0.55)
                strokeWidth: 1

                PathMultiline {
                    paths: {
                        const out = [];
                        for (let i = 0; i < 180; i++) {
                            const a = i * 2 * Math.PI / 180;
                            const l = i % 15 === 0 ? 14 : i % 5 === 0 ? 8 : 4;
                            out.push([Qt.point(face.r + Math.cos(a) * (face.r - 4), face.r + Math.sin(a) * (face.r - 4)), Qt.point(face.r + Math.cos(a) * (face.r - 4 - l), face.r + Math.sin(a) * (face.r - 4 - l))]);
                        }
                        return out;
                    }
                }
            }
        }

        // Bearings every thirty degrees.
        Repeater {
            model: 12

            Text {
                required property int index
                readonly property real a: index * 30 * Math.PI / 180
                x: face.r + Math.cos(a) * (face.r - 34) - width / 2
                y: face.r + Math.sin(a) * (face.r - 34) - height / 2
                rotation: index * 30 + 90
                text: String(index * 30).padStart(3, "0")
                font.family: face.mono
                font.pixelSize: 11
                color: Colors.withAlpha(face.lume, 0.75)
            }
        }

        // Contacts.
        Repeater {
            model: 14

            Rectangle {
                required property int index
                readonly property real a: index * 2.3999632 + 0.4
                readonly property real d: face.r * (0.3 + 0.62 * ((index * 0.6180339) % 1))
                x: face.r + Math.cos(a) * d - width / 2
                y: face.r + Math.sin(a) * d - height / 2
                width: 12
                height: 12
                radius: 6
                color: Colors.withAlpha(face.lume, 0.12)

                Rectangle {
                    anchors.centerIn: parent
                    width: 4
                    height: 4
                    radius: 2
                    color: face.lume
                    opacity: 0.5 + (parent.index % 3) * 0.2
                }
            }
        }
    }

    // The sweep: its afterglow trailing above the line at three o'clock.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            fillGradient: ConicalGradient {
                centerX: face.dial.cx
                centerY: face.dial.cy
                angle: 0
                GradientStop { position: 0; color: Colors.withAlpha(face.lume, 0.42) }
                GradientStop { position: 0.12; color: Colors.withAlpha(face.lume, 0.0) }
                GradientStop { position: 1; color: Colors.withAlpha(face.lume, 0.0) }
            }
            startX: face.dial.cx
            startY: face.dial.cy

            PathLine { x: face.dial.cx + face.r - 3; y: face.dial.cy }
            PathAngleArc {
                centerX: face.dial.cx
                centerY: face.dial.cy
                radiusX: face.r - 3
                radiusY: face.r - 3
                startAngle: 0
                sweepAngle: -44
                moveToStart: false
            }
            PathLine { x: face.dial.cx; y: face.dial.cy }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: face.lume
            strokeWidth: 2
            startX: face.dial.cx
            startY: face.dial.cy
            PathLine { x: face.dial.cx + face.r - 2; y: face.dial.cy }
        }
    }

    Rectangle {
        x: face.dial.cx + face.r
        y: face.dial.cy - 0.75
        width: Math.max(0, face.dial.nameX - 26 - x)
        height: 1.5
        opacity: face.dial.nameShown
        color: Colors.withAlpha(face.lume, 0.85)

        Text {
            x: 6
            y: -height - 4
            text: "CONTACT"
            font.family: face.mono
            font.pixelSize: 10
            font.letterSpacing: 2.5
            color: face.lume
        }

        Rectangle {
            x: parent.width - 3
            y: -3
            width: 7
            height: 7
            radius: 3.5
            color: face.lume
        }
    }
}
