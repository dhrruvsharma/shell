pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.colors
import qs.services as Services

// The brightness OSD's sign, drawn rather than set in a font so it can
// follow the level: the rays grow from stubs to their full length and the
// sun turns one ray's width as the level runs from 0 to 100, while its glow
// spreads. In the last fifth before 0 the rays draw in and the sun wanes to
// a crescent moon. `kick` (1 at a step, falling to 0) flares the rays and
// the glow for a moment after each step.
Item {
    id: sun

    property real level: 0
    property real kick: 0
    property color color: Services.DesktopTheme.accent
    // What it's drawn on: the moon's shadow is a disc of it.
    property color ground: Colors.surface_container_high
    property bool squareCaps: false

    implicitWidth: 44
    implicitHeight: 44

    // 0 by day, 1 at the darkest: the moon.
    readonly property real night: Math.max(0, Math.min(1, (0.2 - level) / 0.16))
    readonly property real core: (6.4 + 2.4 * level) * (1 - night) + 8.6 * night
    readonly property int rays: 8

    Shape {
        id: glow

        readonly property real r: 13 + 12 * sun.level + 5 * sun.kick

        anchors.centerIn: parent
        width: r * 2
        height: r * 2
        preferredRendererType: Shape.CurveRenderer
        opacity: Math.min(1, 0.25 + 0.55 * sun.level + 0.35 * sun.kick) * (1 - sun.night)
        visible: opacity > 0

        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: glow.r
                centerY: glow.r
                centerRadius: glow.r
                focalX: glow.r
                focalY: glow.r

                GradientStop { position: 0; color: Colors.withAlpha(sun.color, 0.5) }
                GradientStop { position: 0.42; color: Colors.withAlpha(sun.color, 0.16) }
                GradientStop { position: 1; color: Colors.withAlpha(sun.color, 0) }
            }

            PathAngleArc {
                centerX: glow.r
                centerY: glow.r
                radiusX: glow.r
                radiusY: glow.r
                startAngle: 0
                sweepAngle: 360
            }
        }
    }

    Item {
        anchors.centerIn: parent
        // A ray's width over the whole range, so every step turns it.
        rotation: 45 * sun.level
        opacity: 1 - sun.night
        visible: opacity > 0

        Repeater {
            model: sun.rays

            Item {
                required property int index

                rotation: index * 360 / sun.rays

                Rectangle {
                    readonly property real len: 2.2 + 5.2 * sun.level + 2.4 * sun.kick

                    x: -width / 2
                    y: -(sun.core + 3 + len)
                    width: 2.6
                    height: len
                    radius: sun.squareCaps ? 0 : width / 2
                    color: sun.color
                    antialiasing: true
                }
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: sun.core * 2
        height: width
        radius: width / 2
        color: sun.color
        antialiasing: true
    }

    // The earth's shadow, sliding over the sun from the upper right as the
    // level falls into the night.
    Rectangle {
        readonly property real d: sun.core * 1.86

        x: sun.width / 2 - d / 2 + sun.core * (2.1 - 1.24 * sun.night)
        y: sun.height / 2 - d / 2 - sun.core * (1.6 - 0.96 * sun.night)
        width: d
        height: d
        radius: d / 2
        color: sun.ground
        visible: sun.night > 0
        antialiasing: true
    }
}
