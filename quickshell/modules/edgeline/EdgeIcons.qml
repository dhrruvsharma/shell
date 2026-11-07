pragma Singleton
import QtQuick
import Quickshell
import qs.services as Services

// Material Symbols names for the states the edge line shows.
Singleton {
    function battery(percent, charging) {
        if (!Services.Battery.ready)
            return "battery_unknown";
        if (charging)
            return "battery_charging_full";
        if (percent <= 10)
            return "battery_alert";
        const bars = Math.round(percent / 100 * 6);
        return bars >= 6 ? "battery_full" : "battery_" + Math.max(0, bars) + "_bar";
    }

    function wifi() {
        const net = Services.Network;
        const p = net.primary;
        if (p && p.type !== "wifi")
            return p.kind === "usb" ? "usb" : p.kind === "bluetooth" ? "bluetooth_connected" : p.kind === "mobile" ? "signal_cellular_alt" : "lan";
        if (!net.wifiEnabled)
            return "wifi_off";
        const w = net.activeWifi;
        if (!w)
            return "wifi_find";
        return w.strength >= 75 ? "signal_wifi_4_bar" : w.strength >= 50 ? "network_wifi_3_bar" : w.strength >= 25 ? "network_wifi_2_bar" : "network_wifi_1_bar";
    }

    function bluetooth() {
        const bt = Services.Bluetooth;
        if (!bt.defaultAdapter || !bt.defaultAdapter.enabled)
            return "bluetooth_disabled";
        return bt.activeDevice ? "bluetooth_connected" : "bluetooth";
    }

    function volume() {
        const v = Services.Volume;
        if (v.muted)
            return "volume_off";
        return v.volume <= 0.001 ? "volume_mute" : v.volume < 0.5 ? "volume_down" : "volume_up";
    }
}
