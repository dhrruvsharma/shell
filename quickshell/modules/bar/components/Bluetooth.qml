import qs.components
import qs.services as Services
import qs.Core

BarPill {
    z: 100
    text: Icons.bluetooth + " " + bluetoothLabel
    horizontalPadding: 20
    maxWidth: 200
    command: ["qs", "ipc", "call", "networkPanel", "changeVisible", "bluetooth"]

    property string bluetoothLabel: {
        const adapter = Services.Bluetooth.defaultAdapter
        const device = Services.Bluetooth.activeDevice

        if (!adapter?.enabled)
            return "Off"

        if (device)
            return device.name

        return "Bluetooth"
    }
}
