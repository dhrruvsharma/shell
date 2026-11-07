pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.control
import qs.modules.lock
import qs.modules.screenshot

// The name on what's lit, on the desktop theme's frame: an app's icon or a
// glyph, what it is, and a line more about it.
Item {
    id: tag

    property string icon
    property string glyph
    property string title
    property string detail

    readonly property real inner: 40
    readonly property real maxText: 420

    width: row.implicitWidth + 2 * surface.pad + 8
    height: surface.headRoom + 2 * surface.pad + inner + surface.footRoom

    EditorSurface {
        id: surface

        anchors.fill: parent
        title: "share"
    }

    Row {
        id: row

        x: surface.pad + 4
        y: surface.headRoom + surface.pad
        height: tag.inner
        spacing: 12

        Image {
            anchors.verticalCenter: parent.verticalCenter
            visible: tag.icon !== ""
            width: 30
            height: 30
            sourceSize: Qt.size(64, 64)
            source: tag.icon
            asynchronous: true
            fillMode: Image.PreserveAspectFit
        }

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            visible: tag.icon === ""
            text: tag.glyph
            filled: true
            font.pixelSize: 26
            color: ControlStyle.accent
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: Math.min(implicitWidth, tag.maxText)
                text: tag.title
                elide: Text.ElideRight
                font.family: ControlStyle.ui
                font.pixelSize: 15
                color: ControlStyle.ink
            }

            Text {
                width: Math.min(implicitWidth, tag.maxText)
                visible: text !== ""
                text: tag.detail
                elide: Text.ElideRight
                font.family: ControlStyle.body
                font.pixelSize: 12
                color: Colors.withAlpha(ControlStyle.ink, 0.65)
            }
        }
    }
}
