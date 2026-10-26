import QtQuick
import QtQuick.Shapes
import qs.colors

// A box to tick, as on a printed form: the tick is drawn in with a stroke
// of the pen when it's turned on. Round boxes on the round themes.
Item {
    id: tick

    property bool checked: false

    signal toggled

    implicitWidth: 26
    implicitHeight: 26
    opacity: tick.enabled ? 1 : 0.4

    readonly property real r: Math.min(BookStyle.b.radius ?? 4, 6)
    property real drawn: tick.checked ? 1 : 0

    Behavior on drawn {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        id: box
        anchors.centerIn: parent
        width: 18
        height: 18
        radius: BookStyle.themeId === "cosmos" ? 9 : tick.r
        color: tick.checked ? Colors.withAlpha(BookStyle.accent, 0.12) : area.containsMouse ? BookStyle.well : "transparent"
        border.width: 1.2
        border.color: tick.checked ? BookStyle.accent : area.containsMouse ? BookStyle.ink : BookStyle.inkSoft
    }

    // The tick, revealed left to right as it's drawn.
    Item {
        x: box.x - 2
        y: box.y - 5
        width: (box.width + 8) * tick.drawn
        height: box.height + 8
        clip: true

        Shape {
            width: box.width + 8
            height: box.height + 8
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: BookStyle.accent
                strokeWidth: 2.4
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: [Qt.point(5, 13), Qt.point(9.5, 18.5), Qt.point(21, 3.5)]
                }
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tick.toggled()
    }
}
