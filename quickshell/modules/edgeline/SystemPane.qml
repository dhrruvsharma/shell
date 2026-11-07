pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.services as Services
import qs.modules.lock
import qs.modules.control

// The machine: the control centre's vitals (CPU, memory, heat, disk on the
// theme's meters, and the uptime), the battery where there is one, and the
// way into the rest of the shell, which has no bar to be reached from in
// minimal mode.
PaneSection {
    id: pane

    titled: false
    preferredWidth: 316

    Vitals {
        width: parent.width
    }

    // The battery: how full, and how long it has.
    Item {
        id: batteryRow
        visible: Services.Battery.ready
        width: parent.width
        height: 30

        readonly property var device: Services.Battery.device
        readonly property real remaining: batteryRow.device ? (Services.Battery.charging ? batteryRow.device.timeToFull : batteryRow.device.timeToEmpty) : 0

        Glyph {
            id: batteryGlyph
            anchors.verticalCenter: parent.verticalCenter
            text: EdgeIcons.battery(Services.Battery.percentage, Services.Battery.charging)
            filled: true
            font.pixelSize: 20
            color: Services.Battery.percentage <= 15 && !Services.Battery.charging ? ControlStyle.danger : ControlStyle.accent
        }

        Text {
            anchors.left: batteryGlyph.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: Services.Battery.percentage + "%"
            font.family: ControlStyle.display
            font.pixelSize: 17
            font.weight: Font.DemiBold
            color: ControlStyle.ink
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Services.Battery.full ? "Full" : (Services.Battery.charging ? "Charging" : "On battery")
                + (batteryRow.remaining > 0 ? " · " + Services.Battery.formatTime(batteryRow.remaining) + (Services.Battery.charging ? " to full" : " left") : "")
            font.family: ControlStyle.body
            font.pixelSize: 12
            color: Colors.withAlpha(ControlStyle.ink, 0.65)
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: ControlStyle.line
    }

    // The rest of the shell.
    Grid {
        id: actions
        width: parent.width
        columns: 4
        rowSpacing: 6
        columnSpacing: 6

        Repeater {
            model: [
                { icon: "tune", name: "Control", what: "controlCenter" },
                { icon: "wallpaper", name: "Wallpaper", what: "wallpaper" },
                { icon: "palette", name: "Themes", what: "themes" },
                { icon: "menu_book", name: "Customize", what: "customizer" },
                { icon: "content_paste", name: "Clipboard", what: "clipboard" },
                { icon: "keyboard", name: "Keys", what: "keybinds" },
                { icon: "edit_note", name: "Notepad", what: "notepad" },
                { icon: "system_update_alt", name: "Updates", what: "updates" }
            ]

            MouseArea {
                id: action
                required property var modelData
                width: (actions.width - 3 * actions.columnSpacing) / 4
                height: 54
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.EdgeLine.request(action.modelData.what)

                Rectangle {
                    anchors.fill: parent
                    radius: ControlStyle.radius(12)
                    color: action.containsMouse ? ControlStyle.wellHover : ControlStyle.well
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 2

                    Glyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: action.modelData.icon
                        filled: action.containsMouse
                        font.pixelSize: 20
                        color: action.containsMouse ? ControlStyle.accent : Colors.withAlpha(ControlStyle.ink, 0.8)
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: ControlStyle.label(action.modelData.name)
                        font.family: ControlStyle.ui
                        font.pixelSize: 10
                        font.capitalization: ControlStyle.caps
                        color: Colors.withAlpha(ControlStyle.ink, 0.75)
                    }
                }
            }
        }
    }
}
