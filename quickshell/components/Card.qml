import QtQuick
import qs.colors
import qs.services as Services

// The standard bordered surface used for grouped content. A desktop theme
// reshapes it and tints (or, Still, drops) its border.
Rectangle {
    id: root

    radius: 16
    color: Colors.surface_container
    border.width: Services.DesktopTheme.borderless ? 0 : 1
    border.color: Services.DesktopTheme.enabled && Services.DesktopTheme.look.border
        ? Services.DesktopTheme.borderColor(Services.DesktopTheme.look)
        : Colors.outline_variant

    // A desktop theme squares these off (or, Astral, rounds them into
    // capsules) while it's on, restoring the caller's radius when it's off.
    Binding {
        target: root
        property: "radius"
        value: Services.DesktopTheme.roundControls ? Math.min(root.height / 2, 26) : Services.DesktopTheme.controlRadius
        when: Services.DesktopTheme.controlRadius >= 0 || Services.DesktopTheme.roundControls
    }
}
