import QtQuick.Layouts
import qs.colors
import qs.components

ColumnLayout {
    Layout.fillWidth: true
    Layout.leftMargin: 20
    Layout.rightMargin: 20
    Layout.topMargin: 20
    Layout.bottomMargin: 30
    spacing: 14

    SectionHeader {
        title: "Power Options"
        icon: "󰐥"
        titleColor: Colors.error
        iconColor: Colors.on_primary_container
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 14
        rowSpacing: 14

        ActionButton {
            icon: "󰐥"
            label: "Power Off"
            buttonColor: Colors.error_container
            onClicked: run("systemctl poweroff")
        }

        ActionButton {
            icon: "󰜉"
            label: "Restart"
            buttonColor: Colors.primary_container
            onClicked: run("systemctl reboot")
        }

        ActionButton {
            icon: "󰒲"
            label: "Sleep"
            buttonColor: Colors.secondary_container
            onClicked: run("systemctl suspend")
        }

        ActionButton {
            icon: "󰍃"
            label: "Log Out"
            buttonColor: Colors.tertiary_container
            onClicked: run("loginctl terminate-user $USER")
        }
    }

}
