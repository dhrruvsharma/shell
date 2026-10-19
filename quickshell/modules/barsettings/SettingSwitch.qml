import QtQuick
import qs.colors
import qs.services as Services

// An on/off switch, drawn like the ones in the Themes panel. It only shows
// `on`; whoever holds it flips the setting (a tile does on its click).
Rectangle {
    id: root

    property bool on: false

    implicitWidth: 46
    implicitHeight: 26
    radius: Services.DesktopTheme.rad(13)
    color: root.on ? Colors.primary : Colors.surface_container_highest

    Behavior on color {
        ColorAnimation { duration: 160 }
    }

    Rectangle {
        width: 20
        height: 20
        radius: Services.DesktopTheme.rad(10)
        y: 3
        x: root.on ? root.width - width - 3 : 3
        color: root.on ? Colors.on_primary : Colors.outline

        Behavior on x {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
    }
}
