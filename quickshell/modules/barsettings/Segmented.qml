pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.components
import qs.modules.lock
import qs.services as Services

// A row of mutually exclusive choices, like the Themes panel's tabs:
// `options` is [{ id, label, icon }], `current` the id chosen.
Rectangle {
    id: root

    property var options: []
    property string current: ""

    signal chosen(string choice)

    implicitWidth: row.implicitWidth + 8
    implicitHeight: 38
    radius: Services.DesktopTheme.rad(19)
    color: Colors.surface_container

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: root.options

            ClickableRect {
                id: chip

                required property var modelData
                readonly property bool active: root.current === modelData.id

                width: chipRow.implicitWidth + 28
                height: 30
                radius: Services.DesktopTheme.rad(15)
                color: chip.active ? Colors.primary : chip.hovered ? Colors.surface_container_high : "transparent"
                cursorShape: Qt.PointingHandCursor
                onClicked: root.chosen(chip.modelData.id)

                Behavior on color {
                    ColorAnimation { duration: 140 }
                }

                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: 6

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !!chip.modelData.icon
                        text: chip.modelData.icon ?? ""
                        filled: chip.active
                        font.pixelSize: 16
                        color: chip.active ? Colors.on_primary : Colors.on_surface_variant
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chip.modelData.label
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: chip.active ? Colors.on_primary : Colors.on_surface
                    }
                }
            }
        }
    }
}
