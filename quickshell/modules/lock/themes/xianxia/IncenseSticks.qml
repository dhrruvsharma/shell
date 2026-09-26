pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.modules.lock

// Lives as incense sticks: one per wrong password pam_faillock still allows.
// Lit sticks carry an ember and a wisp of smoke that wavers with the ambient
// clock; a lost life burns its stick down with a puff.
Row {
    id: sticks

    required property LockContext ctx
    property real sc: 1

    spacing: 14 * sc

    Repeater {
        model: Math.min(sticks.ctx.maxLives, 5)

        Item {
            id: stick

            required property int index
            readonly property bool alight: index < sticks.ctx.lives
            readonly property real t: sticks.ctx.ambientTime + index * 1.7
            property real stickH: (alight ? 50 : 18) * sticks.sc
            readonly property real tipY: height - stickH

            width: 16 * sticks.sc
            height: 86 * sticks.sc

            onAlightChanged: if (!alight) puff.restart()

            Behavior on stickH {
                NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
            }

            // The stick.
            Rectangle {
                x: (stick.width - width) / 2
                y: stick.tipY
                width: 2.6 * sticks.sc
                height: stick.stickH
                radius: width / 2
                color: stick.alight ? "#8a4a33" : "#4a4440"
            }

            // Ember and its glow.
            Rectangle {
                x: (stick.width - width) / 2
                y: stick.tipY - height / 2
                width: 16 * sticks.sc
                height: width
                radius: width / 2
                visible: stick.alight
                color: Xian.alpha(Xian.ember, 0.18 + 0.08 * Math.sin(stick.t * 3))
            }

            Rectangle {
                x: (stick.width - width) / 2
                y: stick.tipY - height / 2
                width: 4.5 * sticks.sc
                height: width
                radius: width / 2
                visible: stick.alight
                color: Xian.ember
            }

            // A thin wavering wisp of smoke.
            Shape {
                anchors.fill: parent
                visible: stick.alight
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Xian.alpha(Xian.mist, 0.3)
                    strokeWidth: 1.1 * sticks.sc
                    capStyle: ShapePath.RoundCap
                    startX: stick.width / 2
                    startY: stick.tipY - 3 * sticks.sc

                    PathCubic {
                        readonly property real s: sticks.sc
                        x: stick.width / 2 + Math.sin(stick.t * 0.9) * 4 * s
                        y: 2 * s
                        control1X: stick.width / 2 + Math.sin(stick.t * 1.3) * 7 * s
                        control1Y: stick.tipY - 14 * s
                        control2X: stick.width / 2 - Math.sin(stick.t * 1.1 + 1) * 7 * s
                        control2Y: stick.tipY - 26 * s
                    }
                }
            }

            // Puff when a stick goes out.
            Rectangle {
                id: puffRing
                x: (stick.width - width) / 2
                y: stick.tipY - height / 2
                width: 10 * sticks.sc
                height: width
                radius: width / 2
                color: Xian.alpha(Xian.mist, 0.35)
                opacity: 0
            }

            ParallelAnimation {
                id: puff
                NumberAnimation { target: puffRing; property: "scale"; from: 0.5; to: 3.2; duration: 700; easing.type: Easing.OutCubic }
                NumberAnimation { target: puffRing; property: "opacity"; from: 0.9; to: 0; duration: 700 }
            }
        }
    }
}
