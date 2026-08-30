import qs.components
import qs.services as Services

BarPill {
    z: 100
    text: Services.Network.icon + "   " + Services.Network.wifiLabel
    horizontalPadding: 20
    maxWidth: 200
    command: ["qs", "ipc", "call", "networkPanel", "changeVisible", "wifi"]
}
