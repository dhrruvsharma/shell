import QtQuick
import QtQuick.Layouts
import qs.colors

// Title row with a trailing accent glyph, used at the top of each control-centre
// section.
RowLayout {
    id: root

    property string title: ""
    property string icon: ""
    property color titleColor: Colors.on_surface
    property color iconColor: Colors.primary

    Layout.fillWidth: true

    StyledText {
        Layout.fillWidth: true
        text: root.title
        font.pixelSize: 15
        font.weight: Font.DemiBold
        font.letterSpacing: 0.3
        color: root.titleColor
    }

    MaterialIcon {
        text: root.icon
        font.pixelSize: 16
        color: root.iconColor
        opacity: 0.6
    }
}
