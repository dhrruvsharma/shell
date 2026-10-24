pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.colors

// The HUD's wheel: a game's selection wheel. A dark disc under a segmented
// ring, a graduated bezel numbered in degrees, scan rings and cross hairs,
// all turning with the apps; target brackets lock onto the chosen one and
// a tracer runs from them to its name.
Item {
    id: face

    required property LauncherDial dial

    readonly property real r: dial.radius
    readonly property color accent: dial.accent
    readonly property string mono: "JetBrainsMono Nerd Font"

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
                fillColor: Colors.withAlpha(Colors.background, 0.86)
                strokeColor: Colors.withAlpha(face.accent, 0.35)
                strokeWidth: 1

                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r - 1
                    radiusY: face.r - 1
                    sweepAngle: 360
                }
            }

            // The segmented ring.
            ShapePath {
                fillColor: "transparent"
                strokeColor: Colors.withAlpha(face.accent, 0.75)
                strokeWidth: 5
                strokeStyle: ShapePath.DashLine
                dashPattern: [5, 1.2]

                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r - 10
                    radiusY: face.r - 10
                    sweepAngle: 360
                }
            }

            // The bezel's graduation.
            ShapePath {
                fillColor: "transparent"
                strokeColor: Colors.withAlpha(face.accent, 0.5)
                strokeWidth: 1

                PathMultiline {
                    paths: {
                        const out = [];
                        for (let i = 0; i < 72; i++) {
                            const a = i * 5 * Math.PI / 180;
                            const l = i % 6 === 0 ? 14 : 6;
                            out.push([Qt.point(face.r + Math.cos(a) * (face.r - 24), face.r + Math.sin(a) * (face.r - 24)), Qt.point(face.r + Math.cos(a) * (face.r - 24 - l), face.r + Math.sin(a) * (face.r - 24 - l))]);
                        }
                        return out;
                    }
                }
            }

            // Scan rings and cross hairs.
            ShapePath {
                fillColor: "transparent"
                strokeColor: Colors.withAlpha(face.accent, 0.16)
                strokeWidth: 1

                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r * 0.72
                    radiusY: face.r * 0.72
                    sweepAngle: 360
                }
                PathMove { x: face.r * 0.5; y: face.r }
                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r * 0.5
                    radiusY: face.r * 0.5
                    sweepAngle: 360
                }
                PathMultiline {
                    paths: [[Qt.point(face.r * 0.2, face.r), Qt.point(face.r * 1.8, face.r)], [Qt.point(face.r, face.r * 0.2), Qt.point(face.r, face.r * 1.8)]]
                }
            }
        }

        // Bearings round the bezel.
        Repeater {
            model: 12

            Text {
                required property int index
                readonly property real a: index * 30 * Math.PI / 180
                x: face.r + Math.cos(a) * (face.r - 58) - width / 2
                y: face.r + Math.sin(a) * (face.r - 58) - height / 2
                rotation: index * 30 + 90
                text: String(index * 30).padStart(3, "0")
                font.family: face.mono
                font.pixelSize: 12
                font.weight: Font.Medium
                color: Colors.withAlpha(face.accent, 0.7)
            }
        }
    }

    // ── Target lock ──────────────────────────────────────────────────────────

    Item {
        id: lock
        x: face.dial.cx + face.dial.track - 50
        y: face.dial.cy - 50
        width: 100
        height: 100

        Repeater {
            model: 4

            Item {
                id: corner
                required property int index
                readonly property bool east: index === 1 || index === 2
                readonly property bool low: index >= 2
                x: east ? lock.width - 16 : 0
                y: low ? lock.height - 16 : 0
                width: 16
                height: 16

                Rectangle {
                    y: corner.low ? 14 : 0
                    width: 16
                    height: 2
                    color: face.accent
                }

                Rectangle {
                    x: corner.east ? 14 : 0
                    width: 2
                    height: 16
                    color: face.accent
                }
            }
        }
    }

    // The tracer from the lock to the name.
    Rectangle {
        x: lock.x + lock.width + 6
        y: face.dial.cy - 0.5
        width: Math.max(0, face.dial.nameX - 30 - x)
        height: 1
        opacity: face.dial.nameShown
        color: Colors.withAlpha(face.accent, 0.8)

        Text {
            x: 4
            y: -height - 3
            text: "▸ EQUIP"
            font.family: face.mono
            font.pixelSize: 10
            font.letterSpacing: 2
            color: face.accent
        }

        Text {
            x: parent.width - width + 2
            anchors.verticalCenter: parent.verticalCenter
            text: "▸▸"
            font.family: face.mono
            font.pixelSize: 13
            color: face.accent
        }
    }
}
