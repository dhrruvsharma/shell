import QtQuick

// A section break: the theme's ornament between two short rules.
Item {
    id: fleuron

    property real span: 120
    property color color: BookStyle.accent

    implicitWidth: fleuron.span * 2 + glyph.implicitWidth + 24
    implicitHeight: Math.max(16, glyph.implicitHeight)

    Rectangle {
        anchors.right: glyph.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: fleuron.span
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: BookStyle.line }
        }
    }

    BookText {
        id: glyph
        anchors.centerIn: parent
        text: BookStyle.b.fleuron
        font.family: BookStyle.body
        font.pixelSize: 15
        color: fleuron.color
    }

    Rectangle {
        anchors.left: glyph.right
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: fleuron.span
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: BookStyle.line }
            GradientStop { position: 1; color: "transparent" }
        }
    }
}
