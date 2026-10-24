pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.colors

// Astral's wheel: an orrery. The sun at the hub glows over the screen's
// edge, its worlds ride their orbits through a field of stars, and the whole
// system turns with the apps; a course plotted in dots runs from the rim to
// the chosen app's name.
Item {
    id: face

    required property LauncherDial dial

    readonly property real r: dial.radius
    readonly property color accent: dial.accent
    readonly property color accent2: dial.accent2

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
                strokeColor: Colors.withAlpha(face.accent, 0.3)
                strokeWidth: 1
                fillGradient: RadialGradient {
                    centerX: face.r
                    centerY: face.r
                    centerRadius: face.r
                    focalX: face.r
                    focalY: face.r
                    GradientStop { position: 0; color: "#fff1c9" }
                    GradientStop { position: 0.2; color: "#f6b25a" }
                    GradientStop { position: 0.3; color: "#c4562c" }
                    GradientStop { position: 0.42; color: Colors.withAlpha("#3a2a5a", 0.95) }
                    GradientStop { position: 0.62; color: Colors.withAlpha("#0d1330", 0.96) }
                    GradientStop { position: 1; color: Colors.withAlpha("#05070f", 0.97) }
                }

                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r - 1
                    radiusY: face.r - 1
                    sweepAngle: 360
                }
            }
        }

        // Stars.
        Repeater {
            model: 90

            Rectangle {
                required property int index
                readonly property real a: index * 2.3999632
                readonly property real d: face.r * (0.28 + 0.7 * ((index * 0.7548777) % 1))
                x: face.r + Math.cos(a) * d - width / 2
                y: face.r + Math.sin(a) * d - height / 2
                width: index % 9 === 0 ? 3 : index % 3 === 0 ? 2 : 1.4
                height: width
                radius: width / 2
                color: "white"
                opacity: 0.25 + ((index * 0.37) % 1) * 0.6
            }
        }

        // The orbits.
        Repeater {
            model: [0.36, 0.5, 0.64, 0.78, 0.93]

            Rectangle {
                required property var modelData
                anchors.centerIn: parent
                width: face.r * 2 * modelData
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Colors.withAlpha(face.accent, 0.22)
            }
        }

        // The worlds on them: { orbit, angle, size, colour, ringed, moon }.
        Repeater {
            model: [
                { o: 0.36, a: 20, s: 9, c: "#c9b8a6" },
                { o: 0.5, a: 140, s: 15, c: face.accent2, moon: true },
                { o: 0.64, a: 250, s: 12, c: "#d77a52" },
                { o: 0.78, a: 60, s: 26, c: "#e2c38f", ringed: true },
                { o: 0.93, a: 320, s: 17, c: face.accent },
                { o: 0.78, a: 200, s: 7, c: "#9fc4e8" }
            ]

            Item {
                id: world
                required property var modelData
                readonly property real a: modelData.a * Math.PI / 180
                x: face.r + Math.cos(a) * face.r * modelData.o - width / 2
                y: face.r + Math.sin(a) * face.r * modelData.o - height / 2
                width: modelData.s
                height: width

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 2.6
                    height: width
                    radius: width / 2
                    color: Colors.withAlpha(world.modelData.c, 0.12)
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.lighter(world.modelData.c, 1.35) }
                        GradientStop { position: 1; color: Qt.darker(world.modelData.c, 1.6) }
                    }
                }

                Rectangle {
                    visible: world.modelData.ringed === true
                    anchors.centerIn: parent
                    width: parent.width * 2.1
                    height: parent.height * 0.62
                    radius: height / 2
                    rotation: -24
                    color: "transparent"
                    border.width: 2
                    border.color: Colors.withAlpha("#efe0c0", 0.7)
                }

                Rectangle {
                    visible: world.modelData.moon === true
                    x: parent.width + 5
                    y: -4
                    width: 4
                    height: 4
                    radius: 2
                    color: "#e8e8f0"
                }
            }
        }
    }

    // The plotted course, from the rim to the name.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: face.dial.nameShown

        ShapePath {
            fillColor: "transparent"
            strokeColor: Colors.withAlpha(face.accent, 0.85)
            strokeWidth: 2
            capStyle: ShapePath.RoundCap
            strokeStyle: ShapePath.DashLine
            dashPattern: [0.1, 4]
            startX: face.dial.cx + face.r + 8
            startY: face.dial.cy
            PathLine { x: face.dial.nameX - 30; y: face.dial.cy }
        }
    }

    Rectangle {
        x: face.dial.nameX - 30 - width / 2
        y: face.dial.cy - height / 2
        width: 9
        height: 9
        rotation: 45
        opacity: face.dial.nameShown
        color: face.accent2
    }
}
