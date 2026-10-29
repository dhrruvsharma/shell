pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.UPower
import qs.services as Services

// The switches: Wi-Fi and Bluetooth as wide tiles (their chevrons open the
// network panel on their tab), then do not disturb, night light, airplane
// mode, the power profile (a click steps through them) and the desktop
// theme (a click opens the Themes panel).
Column {
    id: root

    required property var center

    spacing: 16

    readonly property var wifi: Services.Network.activeWifi
    readonly property var adapter: Services.Bluetooth.defaultAdapter
    readonly property var device: Services.Bluetooth.activeDevice

    function wifiGlyph() {
        if (!Services.Network.wifiEnabled)
            return "wifi_off";
        if (!wifi)
            return "wifi_find";
        const s = wifi.strength;
        return s >= 75 ? "signal_wifi_4_bar" : s >= 50 ? "network_wifi_3_bar" : s >= 25 ? "network_wifi_2_bar" : "network_wifi_1_bar";
    }

    readonly property var profiles: [PowerProfile.PowerSaver, PowerProfile.Balanced].concat(PowerProfiles.hasPerformanceProfile ? [PowerProfile.Performance] : [])

    function nextProfile() {
        const i = profiles.indexOf(PowerProfiles.profile);
        PowerProfiles.profile = profiles[(i + 1) % profiles.length];
    }

    Row {
        width: parent.width
        spacing: 12

        QuickTile {
            width: (parent.width - parent.spacing) / 2
            icon: root.wifiGlyph()
            title: "Wi-Fi"
            on: Services.Network.wifiEnabled
            status: root.wifi ? root.wifi.name : Services.Network.wifiEnabled ? "Not connected" : "Off"
            onToggled: Services.Network.toggleWifi()
            onOpened: root.center.openPanel("wifi")
        }

        QuickTile {
            width: (parent.width - parent.spacing) / 2
            icon: !root.adapter || !root.adapter.enabled ? "bluetooth_disabled" : root.device ? "bluetooth_connected" : "bluetooth"
            title: "Bluetooth"
            on: root.adapter?.enabled ?? false
            status: !root.adapter ? "Unavailable" : !root.adapter.enabled ? "Off" : root.device ? root.device.name : "On"
            badge: root.adapter?.enabled && root.device?.batteryAvailable ? Math.round(root.device.battery * 100) + "%" : ""
            onToggled: {
                if (!root.adapter)
                    return;
                if (root.adapter.enabled)
                    root.adapter.enabled = false;
                else
                    Services.Radios.enableBluetooth();
            }
            onOpened: root.center.openPanel("bluetooth")
        }
    }

    Row {
        id: smalls
        width: parent.width

        readonly property real cell: width / 5

        QuickToggle {
            width: smalls.cell
            icon: "do_not_disturb_on"
            label: "Do not disturb"
            on: Services.Notification.dnd
            onClicked: Services.Notification.toggleDnd()
        }

        QuickToggle {
            width: smalls.cell
            icon: "nightlight"
            label: !Services.NightLight.available ? "Needs hyprsunset" : on ? Services.NightLight.temperature + " K" : "Night light"
            on: Services.NightLight.available && Services.NightLight.enabled
            muted: !Services.NightLight.available
            onClicked: {
                if (Services.NightLight.available)
                    Services.NightLight.toggle();
                else
                    Services.NightLight.checkAvailable();
            }
        }

        QuickToggle {
            width: smalls.cell
            icon: "flight"
            label: "Airplane"
            on: Services.Radios.airplane
            onClicked: Services.Radios.toggleAirplane()
        }

        QuickToggle {
            width: smalls.cell
            readonly property int profile: PowerProfiles.profile
            icon: profile === PowerProfile.PowerSaver ? "eco" : profile === PowerProfile.Performance ? "bolt" : "balance"
            label: profile === PowerProfile.PowerSaver ? "Power saver" : profile === PowerProfile.Performance ? "Performance" : "Balanced"
            on: profile !== PowerProfile.Balanced
            onClicked: root.nextProfile()
        }

        QuickToggle {
            width: smalls.cell
            icon: Services.DesktopTheme.enabled ? Services.DesktopTheme.current.icon : "palette"
            label: Services.DesktopTheme.enabled ? Services.DesktopTheme.current.name : "Themes"
            on: Services.DesktopTheme.enabled
            onClicked: root.center.openPanel("themes")
        }
    }
}
