import QtQuick
import qs.colors
import qs.modules.control
import qs.modules.desktopwidgets

// What the editor's bars sit on: the desktop theme's frame, as a toast's
// (NotificationToast), and the room its decoration takes above and below
// what's in it.
Item {
    id: surface

    // The console frame's tab.
    property string title

    readonly property bool bare: ControlStyle.frame === "bare"
    readonly property real pad: bare ? 12 : Math.min(ControlStyle.st.pad, 16)
    readonly property real headRoom: bare ? 0 : frame.tabRoom + frame.headRoom
    readonly property real footRoom: bare ? 0 : frame.footRoom

    Rectangle {
        visible: ControlStyle.frame === "glass"
        anchors.fill: parent
        radius: 28
        color: Colors.withAlpha(Colors.background, 0.55)
    }

    WidgetFrame {
        id: frame
        visible: !surface.bare
        anchors.fill: parent
        themeId: ControlStyle.themeId
        title: ControlStyle.frame === "console" ? surface.title : ""
        seal: "画"
    }

    // Still: a quiet sheet.
    Rectangle {
        visible: surface.bare
        anchors.fill: parent
        radius: 16
        color: Colors.withAlpha(Colors.surface_container_low, 0.96)
        border.width: 1
        border.color: ControlStyle.line
    }
}
