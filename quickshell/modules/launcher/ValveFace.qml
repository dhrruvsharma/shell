pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.colors
import qs.components
import qs.modules.lock.themes.wasteland

// The Wasteland's wheel: a valve's handwheel off some dead plant, its rim
// rusted through the paint, five spokes and a riveted hub, the desert
// showing between them; it turns with the apps. The pointer is a strip of
// hazard tape from the rim to the chosen app's name, under a stencilled
// arrow.
Item {
    id: face

    required property LauncherDial dial

    readonly property real r: dial.radius
    readonly property real rim: Math.max(34, r * 0.1)

    Item {
        id: disc
        x: face.dial.cx - face.r
        y: face.dial.cy - face.r
        width: face.r * 2
        height: width
        rotation: face.dial.turn

        // The pipe's flange behind the wheel, grimy, bolted round.
        Rectangle {
            anchors.fill: parent
            anchors.margins: face.rim * 0.5
            radius: width / 2
            color: Colors.withAlpha(Waste.grime, 0.92)
            border.width: 2
            border.color: Colors.withAlpha("black", 0.6)

            Repeater {
                model: 12

                Rivet {
                    required property int index
                    readonly property real a: (index * 30 + 15) * Math.PI / 180
                    x: parent.width / 2 + Math.cos(a) * parent.width * 0.44 - width / 2
                    y: parent.height / 2 + Math.sin(a) * parent.width * 0.44 - height / 2
                    size: 11
                }
            }
        }

        // Spokes.
        Repeater {
            model: 5

            Rectangle {
                required property int index
                x: face.r
                y: face.r - height / 2
                width: face.r - face.rim / 2
                height: face.rim * 0.62
                transformOrigin: Item.Left
                rotation: index * 72 + 18
                radius: 3
                border.width: 1
                border.color: Waste.grime
                gradient: Gradient {
                    GradientStop { position: 0; color: Waste.steelHi }
                    GradientStop { position: 0.45; color: Waste.steel }
                    GradientStop { position: 1; color: Waste.rustDeep }
                }
            }
        }

        // The rim: steel, and the rust coming through.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillRule: ShapePath.OddEvenFill
                strokeColor: Waste.grime
                strokeWidth: 1.5
                fillGradient: ConicalGradient {
                    centerX: face.r
                    centerY: face.r
                    angle: 20
                    GradientStop { position: 0; color: Waste.steel }
                    GradientStop { position: 0.12; color: Waste.rust }
                    GradientStop { position: 0.2; color: Waste.steelHi }
                    GradientStop { position: 0.37; color: Waste.steel }
                    GradientStop { position: 0.45; color: Waste.rustDeep }
                    GradientStop { position: 0.58; color: Waste.steel }
                    GradientStop { position: 0.7; color: Waste.rust }
                    GradientStop { position: 0.82; color: Waste.steelHi }
                    GradientStop { position: 1; color: Waste.steel }
                }

                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r - 1
                    radiusY: face.r - 1
                    sweepAngle: 360
                }
                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r - face.rim
                    radiusY: face.r - face.rim
                    sweepAngle: 360
                }
            }

            // A highlight along the rim's crown.
            ShapePath {
                fillColor: "transparent"
                strokeColor: Colors.withAlpha("white", 0.12)
                strokeWidth: 2

                PathAngleArc {
                    centerX: face.r
                    centerY: face.r
                    radiusX: face.r - face.rim * 0.42
                    radiusY: face.r - face.rim * 0.42
                    sweepAngle: 360
                }
            }
        }

        // Stencilled on the rim.
        Repeater {
            model: 3

            Text {
                required property int index
                readonly property real deg: index * 120 + 40
                readonly property real a: deg * Math.PI / 180
                x: face.r + Math.cos(a) * (face.r - face.rim / 2) - width / 2
                y: face.r + Math.sin(a) * (face.r - face.rim / 2) - height / 2
                rotation: deg + 90
                text: ["TURN TO OPEN", "SALVAGE · DO NOT SELL", "VALVE 07"][index]
                font.family: Waste.stencil
                font.pixelSize: Math.round(face.rim * 0.44)
                font.letterSpacing: 2
                color: Colors.withAlpha(Waste.bone, 0.75)
            }
        }

        // The hub, riveted.
        Rectangle {
            anchors.centerIn: parent
            width: face.r * 0.4
            height: width
            radius: width / 2
            border.width: 2
            border.color: Waste.grime
            gradient: Gradient {
                GradientStop { position: 0; color: Waste.steelHi }
                GradientStop { position: 1; color: Waste.rustDeep }
            }

            Repeater {
                model: 6

                Rivet {
                    required property int index
                    readonly property real a: index * 60 * Math.PI / 180
                    x: parent.width / 2 + Math.cos(a) * parent.width * 0.36 - width / 2
                    y: parent.height / 2 + Math.sin(a) * parent.width * 0.36 - height / 2
                    size: 9
                }
            }
        }
    }

    // The hazard tape, and the arrow sprayed over it.
    HazardStripes {
        x: face.dial.cx + face.r - 6
        y: face.dial.cy - height / 2
        width: Math.max(0, face.dial.nameX - 26 - x)
        height: 12
        stripe: 9
        colorA: Waste.hazard
        opacity: face.dial.nameShown
    }

    Text {
        x: face.dial.nameX - 30 - width
        y: face.dial.cy - height - 8
        opacity: face.dial.nameShown
        text: "▶"
        font.pixelSize: 22
        color: Waste.hazard
    }
}
