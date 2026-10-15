pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.services as Services

// The volume OSD's sign: a speaker whose three waves light in turn as the
// level climbs (a third of the range each), drawn on a 24-unit grid like
// Material's volume glyphs. Muted, the waves go out and a cross springs up
// in their place.
Item {
    id: spk

    property real level: 0
    property bool muted: false
    property color color: Services.DesktopTheme.accent
    property bool squareCaps: false

    implicitWidth: 44
    implicitHeight: 44

    readonly property real u: width / 24
    // The cone's mouth, where the waves (and the meter's wavefronts) start.
    readonly property real mouthX: 11.6 * u
    readonly property real mouthY: 12 * u

    // The curve renderer stops drawing a ShapePath whose cap or join style
    // changes once it exists (as when the theme loads just after it), so
    // each style is a glyph of its own and a theme change builds afresh.
    Loader {
        anchors.fill: parent
        sourceComponent: spk.squareCaps ? sharpGlyph : roundGlyph
    }

    Component {
        id: roundGlyph

        Glyph {
            cap: ShapePath.RoundCap
            join: ShapePath.RoundJoin
        }
    }

    Component {
        id: sharpGlyph

        Glyph {
            cap: ShapePath.FlatCap
            join: ShapePath.MiterJoin
        }
    }

    component Glyph: Item {
        id: glyph

        required property int cap
        required property int join

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: spk.color
                strokeColor: spk.color
                strokeWidth: spk.u
                joinStyle: glyph.join
                startX: 3.4 * spk.u
                startY: 9.3 * spk.u

                PathLine { x: 6.9 * spk.u; y: 9.3 * spk.u }
                PathLine { x: 11.2 * spk.u; y: 5.2 * spk.u }
                PathLine { x: 11.2 * spk.u; y: 18.8 * spk.u }
                PathLine { x: 6.9 * spk.u; y: 14.7 * spk.u }
                PathLine { x: 3.4 * spk.u; y: 14.7 * spk.u }
                PathLine { x: 3.4 * spk.u; y: 9.3 * spk.u }
            }
        }

        Repeater {
            model: 3

            Shape {
                id: wave

                required property int index
                readonly property real r: (3.9 + index * 3.7) * spk.u

                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                opacity: spk.muted ? 0 : Math.max(0.18, Math.min(1, spk.level * 3 - index))
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation { duration: 160 }
                }

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: spk.color
                    strokeWidth: 1.9 * spk.u
                    capStyle: glyph.cap

                    PathAngleArc {
                        centerX: spk.mouthX
                        centerY: spk.mouthY
                        radiusX: wave.r
                        radiusY: wave.r
                        startAngle: -46
                        sweepAngle: 92
                    }
                }
            }
        }

        // The cross, sprung in round its own middle.
        Item {
            x: 18.1 * spk.u - width / 2
            y: spk.mouthY - height / 2
            width: 6.4 * spk.u
            height: width
            opacity: spk.muted ? 1 : 0
            scale: spk.muted ? 1 : 0.4
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: 160 }
            }

            Behavior on scale {
                NumberAnimation { duration: 260; easing.type: Easing.OutBack }
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: spk.color
                    strokeWidth: 1.9 * spk.u
                    capStyle: glyph.cap
                    startX: 0.4 * spk.u
                    startY: 0.4 * spk.u

                    PathLine { x: 6 * spk.u; y: 6 * spk.u }
                    PathMove { x: 6 * spk.u; y: 0.4 * spk.u }
                    PathLine { x: 0.4 * spk.u; y: 6 * spk.u }
                }
            }
        }
    }
}
