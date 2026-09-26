import qs.components
import qs.colors
import qs.services as Services

// Bar atom: an update glyph plus the pending-update count. Clicking toggles the
// UpdatesPanel popout. When everything is current it shows a check glyph.
BarPill {
    readonly property int n: Services.Updates.count
    text: n > 0 ? "󰚰 " + n : "󰄬"
    textColor: n > 0 ? Colors.primary : Colors.on_surface
    horizontalPadding: 20
    command: ["qs", "ipc", "call", "updatesPanel", "toggle"]
}
