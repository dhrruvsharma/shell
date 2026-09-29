import QtQuick
import QtQuick.Shapes

// One of the lives on the "Portcullis" lock screen: a swallowtailed pennon
// of the tincture flying from the head of a lance. Struck (a life lost),
// it slides down the lance and hangs there limp and grey.
Item {
    id: pennon

    property bool struck: false
    property color color: War.tincture
    property real line: 1

    // 0 flying at the lance's head .. 1 struck, hanging at its foot.
    property real down: struck ? 1 : 0
    Behavior on down {
        NumberAnimation {
            duration: 750
            easing.type: Easing.InOutCubic
        }
    }

    readonly property real lance: 3 * line

    implicitWidth: 56
    implicitHeight: 92

    // The lance, and its head.
    Rectangle {
        x: 0
        y: 6 * pennon.line
        width: pennon.lance
        height: pennon.height - 6 * pennon.line
        color: "#6b4a2c"
        border.width: 0.5
        border.color: "#1a120b"
    }

    Shape {
        x: pennon.lance / 2 - 3 * pennon.line
        y: 0
        width: 6 * pennon.line
        height: 9 * pennon.line
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: War.steel
            strokeColor: "#1a120b"
            strokeWidth: 0.5
            startX: 3 * pennon.line
            startY: 0
            PathLine { x: 6 * pennon.line; y: 7 * pennon.line }
            PathLine { x: 0; y: 7 * pennon.line }
            PathLine { x: 3 * pennon.line; y: 0 }
        }
    }

    // The pennon: it flies out from the lance, and hangs down it once
    // struck.
    Shape {
        id: flag
        x: pennon.lance
        y: 9 * pennon.line + (pennon.height * 0.55) * pennon.down
        width: pennon.width - pennon.lance
        height: pennon.height * 0.34
        rotation: 72 * pennon.down
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        readonly property color cloth: Qt.tint(pennon.color, Qt.rgba(0.35, 0.33, 0.31, 0.8 * pennon.down))

        ShapePath {
            fillColor: flag.cloth
            strokeColor: Qt.darker(flag.cloth, 2.2)
            strokeWidth: 0.8 * pennon.line
            joinStyle: ShapePath.MiterJoin
            startX: 0
            startY: 0
            PathQuad { x: flag.width; y: flag.height * 0.22; controlX: flag.width * 0.5; controlY: flag.height * 0.02 }
            PathLine { x: flag.width * 0.7; y: flag.height * 0.5 }
            PathLine { x: flag.width; y: flag.height * 0.78 }
            PathQuad { x: 0; y: flag.height; controlX: flag.width * 0.5; controlY: flag.height * 0.9 }
            PathLine { x: 0; y: 0 }
        }
    }
}
