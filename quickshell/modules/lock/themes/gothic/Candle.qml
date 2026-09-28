import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// A church candle for the "Rose Window" lock: one per faillock life. A lit
// one's flame sways a little (with the lock's ambient clock); a snuffed one
// trails a wisp of smoke.
Item {
    id: candle

    property bool lit: true
    property real time: 0
    property real size: 1
    property real seed: 0

    width: 28 * size
    height: 110 * size

    // Wax, with a drip down one side.
    Rectangle {
        id: wax
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: 18 * candle.size
        height: 70 * candle.size
        radius: 2 * candle.size
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "#bfb29a" }
            GradientStop { position: 0.45; color: "#f1e8d4" }
            GradientStop { position: 1; color: "#a89c84" }
        }

        Rectangle {
            x: parent.width * 0.62
            width: 4 * candle.size
            height: 16 * candle.size
            radius: width / 2
            color: "#efe6d0"
        }

        // Candlelight on the wax.
        Rectangle {
            width: parent.width
            height: parent.height * 0.4
            visible: candle.lit
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 0.8, 0.45, 0.45) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }

    // The wick.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: wax.top
        width: 2 * candle.size
        height: 6 * candle.size
        color: "#2a211a"
    }

    // The flame, swaying.
    Item {
        id: flame
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: wax.top
        anchors.bottomMargin: 3 * candle.size
        width: 14 * candle.size
        height: 30 * candle.size
        visible: candle.lit
        transformOrigin: Item.Bottom
        rotation: Math.sin(candle.time * 2.3 + candle.seed * 5) * 4 + Math.sin(candle.time * 5.1 + candle.seed) * 1.5
        scale: 1 + Math.sin(candle.time * 3.7 + candle.seed * 2) * 0.05

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#ffb347"
            shadowOpacity: 1
            shadowBlur: 1
            blurMax: 32
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 0
                    y1: flame.height
                    x2: 0
                    y2: 0
                    GradientStop { position: 0; color: "#fff4d6" }
                    GradientStop { position: 0.45; color: "#ffc45c" }
                    GradientStop { position: 1; color: "#ff7a1a" }
                }
                startX: flame.width / 2
                startY: 0
                PathCubic {
                    x: flame.width / 2
                    y: flame.height
                    control1X: flame.width * 1.05
                    control1Y: flame.height * 0.45
                    control2X: flame.width * 1.1
                    control2Y: flame.height
                }
                PathCubic {
                    x: flame.width / 2
                    y: 0
                    control1X: -flame.width * 0.1
                    control1Y: flame.height
                    control2X: -flame.width * 0.05
                    control2Y: flame.height * 0.45
                }
            }
        }
    }

    // Smoke from a snuffed wick.
    Shape {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: wax.top
        width: 24 * candle.size
        height: 40 * candle.size
        visible: !candle.lit
        opacity: 0.35
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: "#b8b0a4"
            strokeWidth: 1.5 * candle.size
            capStyle: ShapePath.RoundCap
            startX: 12 * candle.size
            startY: 40 * candle.size
            PathCubic {
                x: 10 * candle.size + Math.sin(candle.time * 1.3 + candle.seed) * 3 * candle.size
                y: 0
                control1X: 22 * candle.size
                control1Y: 26 * candle.size
                control2X: 2 * candle.size
                control2Y: 14 * candle.size
            }
        }
    }
}
