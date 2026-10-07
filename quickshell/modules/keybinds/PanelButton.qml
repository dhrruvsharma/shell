import QtQuick
import qs.colors
import qs.components
import qs.modules.lock
import qs.services as Services

// The keybinds panel's buttons: an icon and a word, filled with the accent
// when primary, red when it's about to delete something.
ClickableRect {
    id: button

    property string icon: ""
    property string text: ""
    property bool primary: false
    property bool danger: false

    implicitWidth: row.implicitWidth + 32
    implicitHeight: 38
    radius: Services.DesktopTheme.rad(19)
    opacity: enabled ? 1 : 0.45
    cursorShape: Qt.PointingHandCursor
    color: danger ? (hovered ? Qt.lighter(Colors.error, 1.08) : Colors.error)
        : primary ? (hovered ? Qt.lighter(Services.DesktopTheme.accent, 1.08) : Services.DesktopTheme.accent)
        : (hovered ? Colors.surface_container_highest : Colors.surface_container_high)
    border.width: primary || danger ? 0 : 1
    border.color: Colors.withAlpha(Colors.outline_variant, 0.8)

    readonly property color ink: danger ? Colors.on_error : primary ? Colors.on_primary : Colors.on_surface

    Behavior on color {
        ColorAnimation { duration: 120 }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            visible: button.icon !== ""
            text: button.icon
            font.pixelSize: 17
            color: button.ink
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: button.text
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: button.ink
        }
    }
}
