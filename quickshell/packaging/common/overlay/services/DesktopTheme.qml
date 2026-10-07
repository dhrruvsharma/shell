pragma Singleton
import QtQuick
import Quickshell
import qs.colors

// Stand-in for the desktop-theme registry of the rice these packages come
// from. They only ask it for corner radii, a font and an accent; with no
// theme to apply, every radius stays as written, text keeps the default
// font and the accent is the palette's.
Singleton {
    readonly property bool enabled: false
    readonly property string theme: ""
    readonly property real controlRadius: -1
    readonly property bool roundControls: false
    readonly property string font: ""
    readonly property color accent: Colors.primary
    readonly property color accent2: Colors.tertiary

    function rad(normal) {
        return normal;
    }
}
