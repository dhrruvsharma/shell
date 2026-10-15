pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.colors
import qs.services as Services

// The brightness OSD's meter: a strip of night sky that the daylight floods
// as the level rises, putting out the stars as it reaches them (and paling
// the rest). The light runs from dawn at its tail to full day at its front,
// which blooms; every step sends a glint along it, out from the sun.
Item {
    id: meter

    property real level: 0
    property color light: Services.DesktopTheme.accent
    property color dawn: Services.DesktopTheme.accent2
    // A night sky in the wallpaper's colour.
    property color sky: Qt.tint(Colors.surface_container_lowest, Colors.withAlpha(Colors.primary, 0.1))
    property color star: Colors.on_surface
    property bool squareCaps: false

    readonly property real r: squareCaps ? 0 : height / 2
    readonly property real reach: level <= 0.004 ? 0 : Math.max(height, level * width)

    // 0..1 along the light while a glint runs, else -1.
    property real glint: -1

    function emit() {
        if (reach > 0)
            glintAnim.restart();
    }

    SequentialAnimation {
        id: glintAnim

        NumberAnimation { target: meter; property: "glint"; from: 0; to: 1; duration: 520; easing.type: Easing.OutQuad }
        PropertyAction { target: meter; property: "glint"; value: -1 }
    }

    Rectangle {
        anchors.fill: parent
        radius: meter.r
        color: meter.sky
        border.width: 1
        border.color: Colors.withAlpha(Colors.outline_variant, 0.5)
    }

    // x along the strip, y across it, size.
    Repeater {
        model: [[0.06, 0.34, 1.6], [0.13, 0.66, 1.2], [0.22, 0.4, 2.0], [0.31, 0.7, 1.3], [0.39, 0.3, 1.5],
            [0.48, 0.58, 1.9], [0.57, 0.35, 1.2], [0.65, 0.68, 1.6], [0.74, 0.4, 1.3], [0.82, 0.62, 2.0],
            [0.9, 0.33, 1.4], [0.96, 0.6, 1.2]]

        Rectangle {
            required property var modelData

            x: modelData[0] * meter.width - width / 2
            y: modelData[1] * meter.height - height / 2
            width: modelData[2]
            height: width
            radius: width / 2
            color: meter.star
            opacity: Math.max(0, Math.min(1, (x - meter.reach) / 16)) * (1 - 0.45 * meter.level)
        }
    }

    // The bloom at the light's front, spilling onto the night.
    Shape {
        id: bloom

        readonly property real rad: meter.height * (1.25 + 0.35 * meter.level)

        x: meter.reach - meter.height / 2 - rad
        y: meter.height / 2 - rad
        width: rad * 2
        height: rad * 2
        preferredRendererType: Shape.CurveRenderer
        visible: meter.reach > 0
        opacity: 0.35 + 0.5 * meter.level

        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: bloom.rad
                centerY: bloom.rad
                centerRadius: bloom.rad
                focalX: bloom.rad
                focalY: bloom.rad

                GradientStop { position: 0; color: Colors.withAlpha(Qt.lighter(meter.light, 1.25), 0.85) }
                GradientStop { position: 0.4; color: Colors.withAlpha(meter.light, 0.3) }
                GradientStop { position: 1; color: Colors.withAlpha(meter.light, 0) }
            }

            PathAngleArc {
                centerX: bloom.rad
                centerY: bloom.rad
                radiusX: bloom.rad
                radiusY: bloom.rad
                startAngle: 0
                sweepAngle: 360
            }
        }
    }

    Rectangle {
        id: day

        width: meter.reach
        height: meter.height
        radius: meter.r
        visible: meter.reach > 0
        clip: true
        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop { position: 0; color: meter.dawn }
            GradientStop { position: 1; color: Qt.lighter(meter.light, 1.12) }
        }

        Rectangle {
            visible: meter.glint >= 0
            x: meter.glint * (day.width + width) - width
            width: 34
            height: day.height
            opacity: 1 - meter.glint * 0.6
            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0) }
                GradientStop { position: 0.6; color: Qt.rgba(1, 1, 1, 0.55) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
            }
        }
    }
}
