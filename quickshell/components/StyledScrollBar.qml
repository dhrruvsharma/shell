import QtQuick
import QtQuick.Controls
import qs.colors

// The thin translucent scrollbar used by every list and grid in the shell.
ScrollBar {
    id: root

    property real thickness: 3
    property real handleRadius: 2
    property color handleColor: Colors.primary
    property real handleOpacity: 0.45

    policy: ScrollBar.AsNeeded

    contentItem: Rectangle {
        implicitWidth: root.thickness
        radius: root.handleRadius
        color: root.handleColor
        opacity: root.handleOpacity
    }
}
