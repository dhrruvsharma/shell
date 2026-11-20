pragma ComponentBehavior: Bound
import QtQuick
import qs.colors

// A made-up window on one of Fig. 16's workspaces (PanoramaFigure): a
// title strip and a few lines of text, in the palette's colours.
Rectangle {
    id: mock

    // Scale of the figure against a 600 px one.
    property real u: 1

    radius: 5 * mock.u
    color: Colors.withAlpha(Colors.surface_container, 0.94)
    border.width: 1
    border.color: Colors.withAlpha(Colors.outline, 0.5)
    clip: true

    Rectangle {
        width: mock.width
        height: 12 * mock.u
        color: Colors.withAlpha(Colors.primary, 0.22)
    }

    Column {
        x: 10 * mock.u
        y: 22 * mock.u
        spacing: 6 * mock.u

        Repeater {
            model: [0.7, 0.5, 0.82, 0.38, 0.6]

            Rectangle {
                required property real modelData
                width: modelData * (mock.width - 20 * mock.u)
                height: 3 * mock.u
                radius: height / 2
                color: Colors.withAlpha(Colors.on_surface, 0.28)
            }
        }
    }
}
