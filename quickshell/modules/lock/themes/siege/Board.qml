pragma ComponentBehavior: Bound
import QtQuick

// An iron-bound board of dark oak, the ground of the Siege theme's plaques:
// a steel hairline round it and a finer one inside, the seams between its
// planks, and an iron strap nailed over each corner.
Item {
    id: board

    property color fill: War.alpha(War.ground, 0.86)
    property color metal: War.steel
    property real line: 1
    property real strap: 26
    property int planks: 3

    Rectangle {
        anchors.fill: parent
        color: board.fill
        border.width: board.line
        border.color: War.alpha(board.metal, 0.55)

        Rectangle {
            anchors.fill: parent
            anchors.margins: 4 * board.line
            color: "transparent"
            border.width: board.line
            border.color: War.alpha(board.metal, 0.18)
        }

        Repeater {
            model: Math.max(0, board.planks - 1)

            Rectangle {
                required property int index
                x: 5 * board.line
                y: Math.round(board.height * (index + 1) / board.planks)
                width: board.width - 10 * board.line
                height: board.line
                color: War.alpha("black", 0.35)
            }
        }
    }

    // The straps: an L of iron over each corner, two nails in each arm.
    Repeater {
        model: 4

        Item {
            id: corner
            required property int index
            readonly property bool isRight: index === 1 || index === 2
            readonly property bool isBottom: index >= 2
            readonly property real t: 5 * board.line
            x: isRight ? board.width - width : 0
            y: isBottom ? board.height - height : 0
            width: board.strap
            height: board.strap

            component Iron: Rectangle {
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.lighter(War.iron, 1.9) }
                    GradientStop { position: 1; color: War.iron }
                }
                border.width: board.line * 0.5
                border.color: "#0b0a0a"
            }

            component Nail: Rectangle {
                width: 3.2 * board.line
                height: width
                radius: width / 2
                color: War.ironHi
                border.width: board.line * 0.5
                border.color: "#0b0a0a"
            }

            Iron {
                y: corner.isBottom ? corner.height - corner.t : 0
                width: corner.width
                height: corner.t
            }

            Iron {
                x: corner.isRight ? corner.width - corner.t : 0
                width: corner.t
                height: corner.height
            }

            // Two nails along each arm, from the corner out.
            Repeater {
                model: [[0.5, 0], [0.84, 0], [0, 0.5], [0, 0.84]]

                Nail {
                    required property var modelData
                    readonly property real along: modelData[0] > 0 ? modelData[0] * corner.width : corner.t / 2
                    readonly property real down: modelData[1] > 0 ? modelData[1] * corner.height : corner.t / 2
                    x: (corner.isRight ? corner.width - along : along) - width / 2
                    y: (corner.isBottom ? corner.height - down : down) - height / 2
                }
            }
        }
    }
}
