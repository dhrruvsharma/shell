import QtQuick
import qs.colors
import qs.components
import qs.modules.lock
import qs.services as Services

// One of the panel's sections: a card with a glyph and a title at its head,
// room on the right of the head for the section's own controls (`trailing`,
// set by the caller as children of it), and the content below.
Card {
    id: root

    property string title
    property string icon
    property alias trailing: trailingRow.data
    // The area under the head, for the section's content.
    default property alias content: body.data
    readonly property real pad: 18

    radius: Services.DesktopTheme.rad(22)
    color: Colors.surface_container_low

    Item {
        id: head
        x: root.pad
        y: root.pad - 2
        width: root.width - 2 * root.pad
        height: 32

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: root.icon
                filled: true
                font.pixelSize: 19
                color: Colors.primary
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.title
                font.pixelSize: 15
                font.weight: Font.Bold
            }
        }

        Row {
            id: trailingRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
        }
    }

    Item {
        id: body
        x: root.pad
        anchors.top: head.bottom
        anchors.topMargin: 14
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pad
        width: root.width - 2 * root.pad
    }
}
