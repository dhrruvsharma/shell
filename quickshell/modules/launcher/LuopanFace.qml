pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.colors

// Cave Abode's wheel: a luopan, the geomancer's compass. A gilded face in
// rings under a lacquered rim: the twenty-four mountains, the eight
// trigrams in vermilion, the twelve earthly branches, graduated between,
// all turning with the apps round the heaven pool and its needle (which
// keeps to the south); the red thread across the face is the pointer, and
// runs on to the chosen app's name.
Item {
    id: face

    required property LauncherDial dial

    readonly property real r: dial.radius
    readonly property string cjk: "Noto Serif CJK SC"
    readonly property color lacquer: "#2a140a"
    readonly property color black: "#1d130a"
    readonly property color vermilion: "#b3261e"
    readonly property var mountains: ["子", "癸", "丑", "艮", "寅", "甲", "卯", "乙", "辰", "巽", "巳", "丙", "午", "丁", "未", "坤", "申", "庚", "酉", "辛", "戌", "乾", "亥", "壬"]
    readonly property var trigrams: ["☰", "☱", "☲", "☳", "☴", "☵", "☶", "☷"]
    readonly property var branches: ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]

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

            // The lacquered rim and the gilded face.
            ShapePath {
                strokeColor: "#120904"
                strokeWidth: 1
                fillColor: face.lacquer

                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r - 1
                    radiusY: face.r - 1
                    sweepAngle: 360
                }
            }

            ShapePath {
                strokeColor: face.black
                strokeWidth: 1.5
                fillGradient: RadialGradient {
                    centerX: face.r
                    centerY: face.r
                    centerRadius: face.r * 0.955
                    focalX: face.r
                    focalY: face.r
                    GradientStop { position: 0.45; color: "#e6c574" }
                    GradientStop { position: 0.85; color: "#d3ac57" }
                    GradientStop { position: 1; color: "#b88f3c" }
                }

                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r * 0.955
                    radiusY: face.r * 0.955
                    sweepAngle: 360
                }
            }

            // The rings' edges, and the dividers within them.
            ShapePath {
                fillColor: "transparent"
                strokeColor: face.black
                strokeWidth: 1.2

                PathMultiline {
                    paths: {
                        const out = [];
                        for (const f of [0.84, 0.79, 0.64, 0.5]) {
                            const pts = [];
                            for (let i = 0; i <= 120; i++) {
                                const a = i * 3 * Math.PI / 180;
                                pts.push(Qt.point(face.r + Math.cos(a) * face.r * f, face.r + Math.sin(a) * face.r * f));
                            }
                            out.push(pts);
                        }
                        // Dividers: 24 in the mountains, 8 in the
                        // trigrams, 12 in the branches.
                        const div = (n, a0, f0, f1) => {
                            for (let i = 0; i < n; i++) {
                                const a = (a0 + i * 360 / n) * Math.PI / 180;
                                out.push([Qt.point(face.r + Math.cos(a) * face.r * f0, face.r + Math.sin(a) * face.r * f0), Qt.point(face.r + Math.cos(a) * face.r * f1, face.r + Math.sin(a) * face.r * f1)]);
                            }
                        };
                        div(24, 7.5, 0.955, 0.84);
                        div(8, 22.5, 0.79, 0.64);
                        div(12, 15, 0.64, 0.5);
                        return out;
                    }
                }
            }

            // The graduated band: a mark every degree, longer every five.
            ShapePath {
                fillColor: "transparent"
                strokeColor: Colors.withAlpha(face.black, 0.8)
                strokeWidth: 0.8

                PathMultiline {
                    paths: {
                        const out = [];
                        for (let i = 0; i < 360; i++) {
                            const a = i * Math.PI / 180;
                            const f1 = i % 5 === 0 ? 0.8 : 0.815;
                            out.push([Qt.point(face.r + Math.cos(a) * face.r * 0.838, face.r + Math.sin(a) * face.r * 0.838), Qt.point(face.r + Math.cos(a) * face.r * f1, face.r + Math.sin(a) * face.r * f1)]);
                        }
                        return out;
                    }
                }
            }

            // The heaven pool.
            ShapePath {
                strokeColor: face.black
                strokeWidth: 2
                fillGradient: RadialGradient {
                    centerX: face.r
                    centerY: face.r
                    centerRadius: face.r * 0.24
                    focalX: face.r
                    focalY: face.r
                    GradientStop { position: 0; color: "#f2ead8" }
                    GradientStop { position: 1; color: "#c9bfa6" }
                }

                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r * 0.24
                    radiusY: face.r * 0.24
                    sweepAngle: 360
                }
            }
        }

        // The twenty-four mountains.
        Repeater {
            model: 24

            Text {
                required property int index
                readonly property real deg: index * 15
                readonly property real a: deg * Math.PI / 180
                x: face.r + Math.cos(a) * face.r * 0.897 - width / 2
                y: face.r + Math.sin(a) * face.r * 0.897 - height / 2
                rotation: deg + 90
                text: face.mountains[index]
                font.family: face.cjk
                font.pixelSize: Math.round(face.r * 0.068)
                font.weight: Font.Bold
                color: index % 3 === 0 ? face.vermilion : face.black
            }
        }

        // The eight trigrams.
        Repeater {
            model: 8

            Text {
                required property int index
                readonly property real deg: index * 45
                readonly property real a: deg * Math.PI / 180
                x: face.r + Math.cos(a) * face.r * 0.715 - width / 2
                y: face.r + Math.sin(a) * face.r * 0.715 - height / 2
                rotation: deg + 90
                text: face.trigrams[index]
                font.pixelSize: Math.round(face.r * 0.1)
                color: face.vermilion
            }
        }

        // The twelve earthly branches.
        Repeater {
            model: 12

            Text {
                required property int index
                readonly property real deg: index * 30
                readonly property real a: deg * Math.PI / 180
                x: face.r + Math.cos(a) * face.r * 0.57 - width / 2
                y: face.r + Math.sin(a) * face.r * 0.57 - height / 2
                rotation: deg + 90
                text: face.branches[index]
                font.family: face.cjk
                font.pixelSize: Math.round(face.r * 0.055)
                color: face.black
            }
        }
    }

    // The needle, keeping to the south whatever the turn.
    Rectangle {
        x: face.dial.cx - width / 2
        y: face.dial.cy - height / 2
        width: 4
        height: face.r * 0.4
        radius: 2
        gradient: Gradient {
            GradientStop { position: 0; color: face.vermilion }
            GradientStop { position: 0.5; color: face.vermilion }
            GradientStop { position: 0.5; color: "#1b1b1f" }
            GradientStop { position: 1; color: "#1b1b1f" }
        }
    }

    // The red thread: across the face, on past the rim to the name.
    Rectangle {
        x: face.dial.cx
        y: face.dial.cy - height / 2
        width: Math.max(0, face.dial.nameX - 22 - x)
        height: 2
        color: face.vermilion
        opacity: 0.4 + 0.6 * face.dial.nameShown

        Rectangle {
            x: parent.width - width / 2
            y: parent.height / 2 - height / 2
            width: 9
            height: 9
            radius: 4.5
            color: face.vermilion
        }
    }
}
