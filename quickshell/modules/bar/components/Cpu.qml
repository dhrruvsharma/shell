import qs.components
import qs.services as Services
import qs.Core

BarPill {
    text: Icons.system + " " + Math.round(Services.System.cpu) + "%"
    command: ["qs", "ipc", "call", "systemPanel", "toggle"]
}
