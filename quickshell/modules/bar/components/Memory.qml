import qs.components
import qs.services as Services

BarPill {
    text: " " + Math.round(Services.System.ram) + "%"
    horizontalPadding: 20
    command: ["qs", "ipc", "call", "controlCenter", "changeVisible"]
}
