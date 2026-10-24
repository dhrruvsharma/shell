pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.colors
import qs.modules.lock.themes.newspaper

// Broadsheet's wheel: the newsroom telephone's rotary dial, black bakelite
// with the exchange letters and numbers showing through its finger holes,
// turning with the apps; the chromed finger stop at three o'clock is the
// pointer. What's beside it is set on a clipping: the chosen app's name the
// headline, a kicker and a heavy rule over it, a hard shadow under.
Item {
    id: face

    required property LauncherDial dial

    readonly property real r: dial.radius
    readonly property var letters: ["", "ABC", "DEF", "GHI", "JKL", "MNO", "PRS", "TUV", "WXY", "OPER"]

    Item {
        id: disc
        x: face.dial.cx - face.r
        y: face.dial.cy - face.r
        width: face.r * 2
        height: width
        rotation: face.dial.turn

        // The number plate under the dial.
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Press.paper
        }

        // The dial: bakelite with its ten finger holes cut out.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillRule: ShapePath.OddEvenFill
                strokeColor: "#000000"
                strokeWidth: 1
                fillGradient: RadialGradient {
                    centerX: face.r
                    centerY: face.r
                    centerRadius: face.r
                    focalX: face.r
                    focalY: face.r
                    GradientStop { position: 0; color: "#2a2826" }
                    GradientStop { position: 0.9; color: "#141312" }
                    GradientStop { position: 1; color: "#0a0a09" }
                }

                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r - 1
                    radiusY: face.r - 1
                    sweepAngle: 360
                }

                PathAngleArc {
                    centerX: face.r + Math.cos(face.hole(0)) * face.r * 0.76
                    centerY: face.r + Math.sin(face.hole(0)) * face.r * 0.76
                    radiusX: face.r * 0.105
                    radiusY: face.r * 0.105
                    sweepAngle: 360
                }
                PathAngleArc {
                    centerX: face.r + Math.cos(face.hole(1)) * face.r * 0.76
                    centerY: face.r + Math.sin(face.hole(1)) * face.r * 0.76
                    radiusX: face.r * 0.105
                    radiusY: face.r * 0.105
                    sweepAngle: 360
                }
                PathAngleArc {
                    centerX: face.r + Math.cos(face.hole(2)) * face.r * 0.76
                    centerY: face.r + Math.sin(face.hole(2)) * face.r * 0.76
                    radiusX: face.r * 0.105
                    radiusY: face.r * 0.105
                    sweepAngle: 360
                }
                PathAngleArc {
                    centerX: face.r + Math.cos(face.hole(3)) * face.r * 0.76
                    centerY: face.r + Math.sin(face.hole(3)) * face.r * 0.76
                    radiusX: face.r * 0.105
                    radiusY: face.r * 0.105
                    sweepAngle: 360
                }
                PathAngleArc {
                    centerX: face.r + Math.cos(face.hole(4)) * face.r * 0.76
                    centerY: face.r + Math.sin(face.hole(4)) * face.r * 0.76
                    radiusX: face.r * 0.105
                    radiusY: face.r * 0.105
                    sweepAngle: 360
                }
                PathAngleArc {
                    centerX: face.r + Math.cos(face.hole(5)) * face.r * 0.76
                    centerY: face.r + Math.sin(face.hole(5)) * face.r * 0.76
                    radiusX: face.r * 0.105
                    radiusY: face.r * 0.105
                    sweepAngle: 360
                }
                PathAngleArc {
                    centerX: face.r + Math.cos(face.hole(6)) * face.r * 0.76
                    centerY: face.r + Math.sin(face.hole(6)) * face.r * 0.76
                    radiusX: face.r * 0.105
                    radiusY: face.r * 0.105
                    sweepAngle: 360
                }
                PathAngleArc {
                    centerX: face.r + Math.cos(face.hole(7)) * face.r * 0.76
                    centerY: face.r + Math.sin(face.hole(7)) * face.r * 0.76
                    radiusX: face.r * 0.105
                    radiusY: face.r * 0.105
                    sweepAngle: 360
                }
                PathAngleArc {
                    centerX: face.r + Math.cos(face.hole(8)) * face.r * 0.76
                    centerY: face.r + Math.sin(face.hole(8)) * face.r * 0.76
                    radiusX: face.r * 0.105
                    radiusY: face.r * 0.105
                    sweepAngle: 360
                }
                PathAngleArc {
                    centerX: face.r + Math.cos(face.hole(9)) * face.r * 0.76
                    centerY: face.r + Math.sin(face.hole(9)) * face.r * 0.76
                    radiusX: face.r * 0.105
                    radiusY: face.r * 0.105
                    sweepAngle: 360
                }
                // The centre card's window.
                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r * 0.42
                    radiusY: face.r * 0.42
                    sweepAngle: 360
                }
            }
        }

        // The numbers and exchange letters, through the holes.
        Repeater {
            model: 10

            Column {
                id: digit
                required property int index
                readonly property real a: face.hole(index)
                x: face.r + Math.cos(a) * face.r * 0.76 - width / 2
                y: face.r + Math.sin(a) * face.r * 0.76 - height / 2
                rotation: -face.dial.turn
                spacing: -2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: String((digit.index + 1) % 10)
                    font.family: Press.masthead
                    font.pixelSize: Math.round(face.r * 0.075)
                    font.weight: Font.Bold
                    color: Press.ink
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: face.letters[(digit.index + 1) % 10]
                    font.family: Press.body
                    font.pixelSize: Math.round(face.r * 0.03)
                    font.letterSpacing: 1
                    color: Press.inkSoft
                }
            }
        }

        // The centre card: the exchange and the number.
        Column {
            anchors.centerIn: parent
            rotation: -face.dial.turn
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "CITY DESK"
                font.family: Press.headline
                font.pixelSize: Math.round(face.r * 0.06)
                font.letterSpacing: 2
                color: Press.ink
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: face.r * 0.5
                height: 2
                color: Press.ink
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "KLONDIKE 5-" + String(1000 + (face.dial.count * 37) % 9000)
                font.family: Press.body
                font.pixelSize: Math.round(face.r * 0.04)
                color: Press.inkSoft
            }
        }
    }

    // Holes from one o'clock round to nine, the way a dial is cut.
    function hole(i) {
        return (-62 - i * 30) * Math.PI / 180;
    }

    // The finger stop, at three o'clock.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: "#d9dcdf"
            strokeWidth: 7
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: face.dial.cx
                centerY: face.dial.cy
                radiusX: face.r * 0.76
                radiusY: face.r * 0.76
                startAngle: 6
                sweepAngle: 14
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: "#7d8186"
            strokeWidth: 2
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: face.dial.cx
                centerY: face.dial.cy
                radiusX: face.r * 0.76 + 2
                radiusY: face.r * 0.76 + 2
                startAngle: 6
                sweepAngle: 14
            }
        }
    }

    // ── The clipping ─────────────────────────────────────────────────────────

    Item {
        x: face.dial.infoX - 28
        y: face.dial.infoY - 26
        width: face.dial.infoWidth + 56
        height: face.dial.infoHeight + 52
        opacity: face.dial.nameShown
        rotation: -0.6

        Rectangle {
            x: 7
            y: 7
            width: parent.width
            height: parent.height
            color: Colors.withAlpha("black", 0.5)
        }

        Rectangle {
            anchors.fill: parent
            color: Press.paper
        }

        // The rule over the kicker.
        Rectangle {
            x: 28
            y: face.dial.nameY - face.dial.infoY + 26 - 34
            width: parent.width - 56
            height: 3
            color: Press.ink
        }
    }

    // The line from the stop to the headline.
    Rectangle {
        x: face.dial.cx + face.r + 6
        y: face.dial.cy - 1
        width: Math.max(0, face.dial.infoX - 40 - x)
        height: 2
        color: Press.paper
        opacity: face.dial.nameShown
    }
}
