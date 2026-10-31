import QtQuick
import Quickshell.Services.UPower
pragma Singleton

Item {
    id: root

    // UPower's display device aggregates whatever batteries the machine has
    // (no hardcoded BAT0) and updates over D-Bus signals, so nothing polls.
    readonly property var device: UPower.displayDevice
    readonly property bool ready: device.ready && device.isLaptopBattery
    property real percentage: ready ? Math.round(device.percentage * 100) : 0
    property bool charging: ready && device.state === UPowerDeviceState.Charging
    property bool full: percentage >= 100 || (ready && device.state === UPowerDeviceState.FullyCharged)

    function getIcon(percent, charging, isReady) {
        if (!isReady)
            return Icons.batteryUnknown;

        if (charging)
            return Icons.batteryCharging;

        const p = Math.round(percent);
        if (p >= 90)
            return Icons.battery100;

        if (p >= 80)
            return Icons.battery90;

        if (p >= 70)
            return Icons.battery80;

        if (p >= 60)
            return Icons.battery70;

        if (p >= 50)
            return Icons.battery60;

        if (p >= 40)
            return Icons.battery50;

        if (p >= 30)
            return Icons.battery40;

        if (p >= 20)
            return Icons.battery30;

        if (p >= 10)
            return Icons.battery20;

        return Icons.battery10;
    }

    function getStateColor(percent, charging, full) {
        if (charging)
            return "#a6e3a1";

        if (full)
            return "#89b4fa";

        if (percent <= 20)
            return "#f38ba8";

        if (percent <= 40)
            return "#fab387";

        return "#cdd6f4";
    }

    function formatTime(seconds) {
        if (seconds <= 0)
            return "";

        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        if (hours > 0)
            return hours + "h " + minutes + "m";

        return minutes + "m";
    }

}
