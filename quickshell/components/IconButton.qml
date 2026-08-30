import QtQuick
import qs.colors

// Round icon-only button that tints its background on hover.
ClickableRect {
    id: root

    property alias icon: glyph.text
    property int iconSize: 16
    property color iconColor: Colors.on_surface_variant
    property color hoverColor: Colors.surface_container_highest
    property color idleColor: "transparent"

    implicitWidth: 30
    implicitHeight: 30
    radius: root.width / 2
    color: root.hovered ? root.hoverColor : root.idleColor

    MaterialIcon {
        id: glyph
        anchors.centerIn: parent
        font.pixelSize: root.iconSize
        color: root.iconColor
    }
}
