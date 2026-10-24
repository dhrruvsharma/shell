pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.colors

// Still's wheel: a dry garden. A stone at the hub, just over the screen's
// edge, and the gravel raked in rings round it, turning slowly with the
// apps; the pointer is a single dot at the edge of the gravel, and a
// hairline from it to the chosen app's name.
Item {
    id: face

    required property LauncherDial dial

    readonly property real r: dial.radius
    readonly property color ink: dial.light

    Item {
        id: disc
        x: face.dial.cx - face.r
        y: face.dial.cy - face.r
        width: face.r * 2
        height: width
        rotation: face.dial.turn

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Colors.withAlpha(Colors.surface_container_low, 0.94)
        }

        // The raked rings, in pairs, a little uneven like a rake's.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: Colors.withAlpha(face.ink, 0.13)
                strokeWidth: 1.2

                PathMultiline {
                    paths: {
                        const out = [];
                        for (let k = 0; k < 16; k++) {
                            const base = face.r * (0.42 + k * 0.035);
                            const pts = [];
                            for (let i = 0; i <= 120; i++) {
                                const a = i * 3 * Math.PI / 180;
                                const d = base + Math.sin(a * 3 + k * 1.3) * 1.4 + Math.sin(a * 7 + k) * 0.7;
                                pts.push(Qt.point(face.r + Math.cos(a) * d, face.r + Math.sin(a) * d));
                            }
                            out.push(pts);
                        }
                        return out;
                    }
                }
            }
        }

        // Two lesser stones out in the gravel, each in its own raked rings:
        // { angle, distance, size }.
        Repeater {
            model: [{ a: 24, d: 0.66, s: 0.13 }, { a: 205, d: 0.7, s: 0.1 }, { a: 118, d: 0.62, s: 0.08 }]

            Item {
                id: rock
                required property var modelData
                readonly property real at: modelData.a * Math.PI / 180
                readonly property real size: face.r * modelData.s
                x: face.r + Math.cos(at) * face.r * modelData.d - width / 2
                y: face.r + Math.sin(at) * face.r * modelData.d - height / 2
                width: size * 3.4
                height: width

                Repeater {
                    model: 3

                    Rectangle {
                        required property int index
                        anchors.centerIn: parent
                        width: rock.size * (1.5 + index * 0.6)
                        height: width * 0.86
                        radius: height / 2
                        color: Colors.withAlpha(Colors.surface_container_low, 1)
                        border.width: 1.2
                        border.color: Colors.withAlpha(face.ink, 0.14)
                        z: -index
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: rock.size
                    height: rock.size * 0.78
                    radius: height * 0.45
                    rotation: rock.modelData.a
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#5f5b54" }
                        GradientStop { position: 1; color: "#24221e" }
                    }
                }
            }
        }

        // The stone.
        Rectangle {
            x: face.r - width / 2 + face.r * 0.04
            y: face.r - height / 2
            width: face.r * 0.62
            height: face.r * 0.5
            radius: height * 0.48
            rotation: 18
            gradient: Gradient {
                GradientStop { position: 0; color: "#5b5852" }
                GradientStop { position: 1; color: "#26241f" }
            }

            Rectangle {
                x: parent.width * 0.55
                y: parent.height * 0.18
                width: parent.width * 0.22
                height: parent.height * 0.14
                radius: height / 2
                color: Colors.withAlpha("#6f8f5a", 0.55)
            }
        }
    }

    // The dot, and the hairline.
    Rectangle {
        x: face.dial.cx + face.r - 4 - width / 2
        y: face.dial.cy - height / 2
        width: 7
        height: 7
        radius: 3.5
        color: face.dial.accent
    }

    Rectangle {
        x: face.dial.cx + face.r + 10
        y: face.dial.cy - 0.5
        width: Math.max(0, face.dial.nameX - 24 - x)
        height: 1
        opacity: face.dial.nameShown * 0.45
        color: face.ink
    }
}
