pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

// A depth tape: the five zones of the ocean stacked from the sunlit top to
// the black of the trenches (on the scale light fades by, Deep.shade), the
// boundaries marked, and a lit pointer at `metres`. The Abyss theme's gauge
// on the desktop, the clock and the Bathysphere lock (which scales it with
// `unit`).
Item {
    id: gauge

    property real metres: 0
    property color pointer: Deep.lume
    property real unit: 1

    implicitWidth: 26 * unit
    implicitHeight: 90 * unit

    readonly property real tapeW: 9 * unit
    readonly property real at: Deep.shade(metres) * height

    Rectangle {
        width: gauge.tapeW
        height: parent.height
        radius: gauge.tapeW / 2
        border.width: Math.max(1, gauge.unit)
        border.color: Deep.alpha(Deep.lume, 0.45)
        gradient: Gradient {
            GradientStop { position: 0; color: "#5fc9c4" }
            GradientStop { position: Deep.shade(200); color: "#1f7d8f" }
            GradientStop { position: Deep.shade(1000); color: "#0c3a52" }
            GradientStop { position: Deep.shade(4000); color: "#061a2a" }
            GradientStop { position: 1; color: "#010407" }
        }
    }

    // The zones' floors.
    Repeater {
        model: [200, 1000, 4000, 6000]

        Rectangle {
            required property real modelData
            x: -2 * gauge.unit
            y: Deep.shade(modelData) * gauge.height
            width: gauge.tapeW + 4 * gauge.unit
            height: Math.max(1, gauge.unit)
            color: Deep.alpha(Deep.foam, 0.55)
        }
    }

    // The pointer, beside the tape.
    Shape {
        x: gauge.tapeW + 2 * gauge.unit
        y: gauge.at - 5 * gauge.unit
        width: 12 * gauge.unit
        height: 10 * gauge.unit
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: gauge.pointer
            strokeColor: "transparent"
            startX: 0
            startY: 5 * gauge.unit
            PathLine { x: 10 * gauge.unit; y: 0 }
            PathLine { x: 10 * gauge.unit; y: 10 * gauge.unit }
            PathLine { x: 0; y: 5 * gauge.unit }
        }
    }

    Rectangle {
        x: -gauge.unit
        y: gauge.at - gauge.unit
        width: gauge.tapeW + 2 * gauge.unit
        height: 2 * gauge.unit
        color: gauge.pointer
    }
}
