import QtQuick
import QtQuick.Shapes

// A motto scroll, as under a coat of arms: a band of parchment with the
// words across it, its ends folded back behind it and cut in a
// swallowtail.
Item {
    id: scroll

    property alias text: label.text
    property alias font: label.font
    property color paper: War.parchment
    property color ink: War.ink
    property real band: 22
    property real line: 1
    // How far each end reaches out beyond the band.
    readonly property real tail: band * 1.1
    readonly property real drop: band * 0.34

    implicitWidth: label.implicitWidth + band * 1.4 + 2 * tail
    implicitHeight: band + drop

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // The ends, behind the band: dropped a little, their outer edges
        // cut in a V.
        ShapePath {
            fillColor: Qt.darker(scroll.paper, 1.5)
            strokeColor: War.alpha(scroll.ink, 0.7)
            strokeWidth: scroll.line
            joinStyle: ShapePath.MiterJoin
            startX: scroll.tail + scroll.band * 0.3
            startY: scroll.drop
            PathLine { x: 0; y: scroll.drop }
            PathLine { x: scroll.tail * 0.4; y: scroll.drop + scroll.band / 2 }
            PathLine { x: 0; y: scroll.height }
            PathLine { x: scroll.tail + scroll.band * 0.3; y: scroll.height }
            PathMove { x: scroll.width - scroll.tail - scroll.band * 0.3; y: scroll.drop }
            PathLine { x: scroll.width; y: scroll.drop }
            PathLine { x: scroll.width - scroll.tail * 0.4; y: scroll.drop + scroll.band / 2 }
            PathLine { x: scroll.width; y: scroll.height }
            PathLine { x: scroll.width - scroll.tail - scroll.band * 0.3; y: scroll.height }
        }

        // Where each end turns under the band.
        ShapePath {
            fillColor: Qt.darker(scroll.paper, 2.2)
            strokeColor: War.alpha(scroll.ink, 0.7)
            strokeWidth: scroll.line
            startX: scroll.tail
            startY: scroll.band
            PathLine { x: scroll.tail + scroll.band * 0.3; y: scroll.height }
            PathLine { x: scroll.tail + scroll.band * 0.3; y: scroll.band }
            PathLine { x: scroll.tail; y: scroll.band }
            PathMove { x: scroll.width - scroll.tail; y: scroll.band }
            PathLine { x: scroll.width - scroll.tail - scroll.band * 0.3; y: scroll.height }
            PathLine { x: scroll.width - scroll.tail - scroll.band * 0.3; y: scroll.band }
            PathLine { x: scroll.width - scroll.tail; y: scroll.band }
        }

        // The band.
        ShapePath {
            strokeColor: War.alpha(scroll.ink, 0.7)
            strokeWidth: scroll.line
            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: 0
                y2: scroll.band
                GradientStop { position: 0; color: Qt.lighter(scroll.paper, 1.06) }
                GradientStop { position: 1; color: Qt.darker(scroll.paper, 1.18) }
            }
            PathRectangle {
                x: scroll.tail
                y: 0
                width: scroll.width - 2 * scroll.tail
                height: scroll.band
            }
        }
    }

    Text {
        id: label
        x: (scroll.width - width) / 2
        y: (scroll.band - height) / 2
        font.family: War.display
        font.pixelSize: scroll.band * 0.6
        font.letterSpacing: scroll.band * 0.06
        font.capitalization: Font.AllUppercase
        color: scroll.ink
    }
}
