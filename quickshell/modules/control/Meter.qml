import QtQuick
import qs.colors
import qs.modules.desktopwidgets

// A 0..1 meter: the theme's own (WidgetBar), or a rounded bar without one.
Item {
    id: root

    property real value

    implicitHeight: ControlStyle.themeId !== "" ? bar.implicitHeight : 5

    WidgetBar {
        id: bar
        visible: ControlStyle.themeId !== ""
        width: parent.width
        themeId: ControlStyle.themeId
        value: root.value
    }

    Rectangle {
        visible: ControlStyle.themeId === ""
        width: parent.width
        height: 5
        radius: 2.5
        color: Colors.withAlpha(ControlStyle.ink, 0.12)

        Rectangle {
            width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, root.value)))
            height: parent.height
            radius: 2.5
            color: ControlStyle.accent
        }
    }
}
