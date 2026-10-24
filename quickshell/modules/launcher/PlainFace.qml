pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.colors

// The launcher's wheel with no desktop theme: a tonal disc, minute marks
// round its edge and a dot for each hour, an inner plate; the pointer a
// pill of the accent on the rim, and a soft halo round the app at it.
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

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Colors.withAlpha(Colors.surface_container, 0.97)
            border.width: 1
            border.color: Colors.withAlpha(Colors.outline_variant, 0.8)
        }

        Rectangle {
            anchors.centerIn: parent
            width: (face.r - 46) * 2
            height: width
            radius: width / 2
            color: Colors.withAlpha(Colors.surface_container_high, 0.9)
            border.width: 1
            border.color: Colors.withAlpha(Colors.outline_variant, 0.45)
        }

        // Minute marks round the edge, longer every five.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Colors.withAlpha(Colors.on_surface_variant, 0.45)
                strokeWidth: 1
                fillColor: "transparent"

                PathMultiline {
                    paths: {
                        const out = [];
                        for (let i = 0; i < 120; i++) {
                            const a = i * 3 * Math.PI / 180;
                            const l = i % 10 === 0 ? 16 : 7;
                            out.push([Qt.point(face.r + Math.cos(a) * (face.r - 8), face.r + Math.sin(a) * (face.r - 8)), Qt.point(face.r + Math.cos(a) * (face.r - 8 - l), face.r + Math.sin(a) * (face.r - 8 - l))]);
                        }
                        return out;
                    }
                }
            }
        }

        Repeater {
            model: 12

            Rectangle {
                required property int index
                readonly property real a: index * 30 * Math.PI / 180
                x: face.r + Math.cos(a) * (face.r - 64) - width / 2
                y: face.r + Math.sin(a) * (face.r - 64) - height / 2
                width: 7
                height: 7
                radius: 3.5
                color: Colors.withAlpha(face.dial.accent, 0.7)
            }
        }
    }

    // The pointer.
    Rectangle {
        x: face.dial.cx + face.dial.track - width / 2
        y: face.dial.cy - height / 2
        width: 96
        height: 96
        radius: 48
        color: Colors.withAlpha(face.dial.accent, 0.14)
        border.width: 1
        border.color: Colors.withAlpha(face.dial.accent, 0.45)
    }

    Rectangle {
        x: face.dial.cx + face.r - width - 4
        y: face.dial.cy - height / 2
        width: 34
        height: 8
        radius: 4
        color: face.dial.accent
    }

    // On from the halo to the name.
    Rectangle {
        x: face.dial.cx + face.dial.track + 52
        y: face.dial.cy - height / 2
        width: Math.max(0, face.dial.nameX - 24 - x)
        height: 2
        radius: 1
        opacity: face.dial.nameShown
        color: Colors.withAlpha(face.dial.accent, 0.6)

        Rectangle {
            x: parent.width - width / 2
            y: parent.height / 2 - height / 2
            width: 8
            height: 8
            radius: 4
            color: face.dial.accent
        }
    }
}
