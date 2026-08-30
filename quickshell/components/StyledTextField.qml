import QtQuick
import QtQuick.Controls
import qs.colors

// TextField with the shell's standard background. The background knobs are
// properties because call sites genuinely differ on radius/border; the text and
// placeholder colours are the same everywhere.
TextField {
    id: root

    property real radius: 10
    property int borderWidth: 1
    property color backgroundColor: Colors.surface_container
    property color borderColor: Colors.outline_variant
    // Defaults to borderColor, i.e. no focus highlight unless a call site asks.
    property color focusBorderColor: root.borderColor

    color: Colors.on_surface
    placeholderTextColor: Colors.on_surface_variant

    background: Rectangle {
        radius: root.radius
        color: root.backgroundColor
        border.width: root.borderWidth
        border.color: root.activeFocus ? root.focusBorderColor : root.borderColor
    }
}
