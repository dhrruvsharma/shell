import QtQuick
import qs.colors
import qs.components
import qs.modules.lock
import qs.services as Services

// One thing the bar can show (an entry of BarSettings.widgets): its glyph,
// name and what it does, and a switch. A click anywhere on it flips it.
ClickableRect {
    id: root

    required property var entry
    property bool selected: false
    // A line to show in place of the description (e.g. why it isn't on the
    // bar just now), or "".
    property string note: ""

    readonly property bool on: Services.BarSettings.shown(root.entry.id)

    implicitHeight: 64
    radius: Services.DesktopTheme.rad(16)
    color: root.hovered ? Colors.surface_container_high : Colors.surface_container
    border.width: root.selected ? 2 : 0
    border.color: Colors.primary
    cursorShape: Qt.PointingHandCursor
    onClicked: Services.BarSettings.toggle(root.entry.id)

    Behavior on color {
        ColorAnimation { duration: 140 }
    }

    Rectangle {
        id: badge
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        height: 38
        radius: Services.DesktopTheme.rad(12)
        color: root.on ? Colors.primary_container : Colors.surface_container_highest

        Behavior on color {
            ColorAnimation { duration: 160 }
        }

        Glyph {
            anchors.centerIn: parent
            text: root.entry.icon
            filled: root.on
            font.pixelSize: 21
            color: root.on ? Colors.on_primary_container : Colors.outline
        }
    }

    Column {
        anchors.left: badge.right
        anchors.leftMargin: 12
        anchors.right: toggle.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        StyledText {
            width: parent.width
            text: root.entry.name
            elide: Text.ElideRight
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: root.on ? Colors.on_surface : Colors.on_surface_variant
        }

        StyledText {
            width: parent.width
            text: root.note || root.entry.description
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            lineHeight: 1.05
            font.pixelSize: 12
            color: root.note ? Colors.tertiary : Colors.on_surface_variant
            opacity: root.on || root.note ? 1 : 0.75
        }
    }

    SettingSwitch {
        id: toggle
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        on: root.on
    }
}
