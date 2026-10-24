pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.colors

// Neon Noir's wheel: a round neon sign on a black wall. Two tubes, one in
// each neon, with katakana lettered between them and ticks lit at the
// quarters, turning with the apps; a third tube runs from the rim to the
// chosen app's name and ends in a chevron.
Item {
    id: face

    required property LauncherDial dial

    readonly property real r: dial.radius
    readonly property color accent: dial.accent
    readonly property color accent2: dial.accent2
    readonly property string sign: "アプリケーション・ランチャー・プログラム・起動・"

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
            color: Colors.withAlpha("#08060c", 0.93)
        }

        // The tubes: a wide faint glow, a brighter one, the tube, and its
        // white-hot core; { radius, colour }.
        Repeater {
            model: [{ f: face.r - 14, c: face.accent }, { f: face.r - 56, c: face.accent2 }]

            Item {
                id: tube
                required property var modelData
                anchors.fill: parent

                Repeater {
                    model: [[12, 0.1], [6, 0.24], [2.6, 1], [0.9, 0.75]]

                    Rectangle {
                        required property var modelData
                        anchors.centerIn: parent
                        width: tube.modelData.f * 2
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: modelData[0]
                        border.color: modelData[1] < 0.8 || modelData[0] > 2 ? Colors.withAlpha(tube.modelData.c, modelData[1]) : Colors.withAlpha("white", modelData[1])
                    }
                }
            }
        }

        // The lettering between the tubes.
        Repeater {
            model: face.sign.length

            Text {
                required property int index
                readonly property real deg: index * 360 / face.sign.length
                readonly property real a: deg * Math.PI / 180
                x: face.r + Math.cos(a) * (face.r - 35) - width / 2
                y: face.r + Math.sin(a) * (face.r - 35) - height / 2
                rotation: deg + 90
                text: face.sign[index]
                font.family: "Noto Sans CJK JP"
                font.pixelSize: 15
                font.weight: Font.Bold
                color: Colors.withAlpha(face.accent2, 0.85)
            }
        }

        // Ticks lit at the quarters, dim between.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: Colors.withAlpha(face.accent, 0.35)
                strokeWidth: 2
                capStyle: ShapePath.RoundCap

                PathMultiline {
                    paths: {
                        const out = [];
                        for (let i = 0; i < 48; i++) {
                            const a = i * 7.5 * Math.PI / 180;
                            const l = i % 12 === 0 ? 34 : 12;
                            out.push([Qt.point(face.r + Math.cos(a) * (face.r - 72), face.r + Math.sin(a) * (face.r - 72)), Qt.point(face.r + Math.cos(a) * (face.r - 72 - l), face.r + Math.sin(a) * (face.r - 72 - l))]);
                        }
                        return out;
                    }
                }
            }
        }
    }

    // The tube to the name.
    Item {
        x: face.dial.cx + face.r - 2
        y: face.dial.cy - 8
        width: Math.max(0, face.dial.nameX - 26 - x)
        height: 16
        opacity: face.dial.nameShown

        Repeater {
            model: [[16, 0.1], [8, 0.25], [3, 1], [1, 0.8]]

            Rectangle {
                required property var modelData
                x: 0
                y: (16 - height) / 2
                width: parent.width
                height: modelData[0]
                radius: height / 2
                color: modelData[0] === 1 ? Colors.withAlpha("white", modelData[1]) : Colors.withAlpha(face.accent, modelData[1])
            }
        }

        Text {
            x: parent.width - 4
            anchors.verticalCenter: parent.verticalCenter
            text: "»"
            font.pixelSize: 26
            font.weight: Font.Bold
            color: face.accent2
        }
    }
}
