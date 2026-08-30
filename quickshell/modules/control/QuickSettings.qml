import Quickshell
import qs.components
import QtQuick.Layouts
import Quickshell.Io
import qs.services as Services

ColumnLayout {
    id: quickSettings
    Layout.fillWidth: true
    Layout.leftMargin: 20
    Layout.rightMargin: 20
    Layout.topMargin: 20
    spacing: 14

    property bool dndEnabled: false
    property bool nightLightEnabled: false
    property bool airplaneModeEnabled: false

    SectionHeader {
        title: "Quick Settings"
        icon: "󰒓"
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 3
        columnSpacing: 12
        rowSpacing: 12

        ToggleTile {
            label: "Wi-Fi"
            icon: Services.Network.icon
            active: Services.Network.wifiEnabled
            onClicked: Services.Network.toggleWifi()
        }

        ToggleTile {
            label: "Bluetooth"
            icon: "󰂯"
            active: Services.Bluetooth.defaultAdapter?.enabled ?? false
            onClicked: Services.Bluetooth.defaultAdapter.enabled = !Services.Bluetooth.defaultAdapter.enabled
        }

        ToggleTile {
            label: "DND"
            icon: "󰂛"
            active: dndEnabled
            onClicked: {
                quickSettings.dndEnabled = !dndEnabled
                run("swaync-client -d")
            }
        }

        ToggleTile {
            label: "Night Light"
            icon: "󰖔"
            active: nightLightEnabled
            onClicked: {
                quickSettings.nightLightEnabled = !nightLightEnabled
                run(["bash", "-c", "gammastep -O " + (nightLightEnabled ? "4000" : "6500")])
            }
        }

        ToggleTile {
            label: "Airplane"
            icon: "󰀝"
            active: airplaneModeEnabled
            onClicked: {
                quickSettings.airplaneModeEnabled = !airplaneModeEnabled
                run("rfkill " + (airplaneModeEnabled ? "block" : "unblock") + " all")
            }
        }

        ToggleTile {
            label: "Lock"
            icon: "󰌾"
            active: false
            onClicked: run("hyprlock")
        }
    }
}