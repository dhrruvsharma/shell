import QtQuick
import qs.colors
import qs.services as Services
import qs.modules.control

// The notifications: the control centre's list (newest first, the cards
// with their own buttons and replies, Clear all), and do not disturb. It
// asks for room for a few cards; a cell taller than that, the list fills.
PaneSection {
    id: pane

    titled: false
    preferredWidth: 336

    readonly property int count: Services.Notification.history.length
    readonly property real listNatural: pane.count === 0 ? 150 : Math.min(420, 70 + pane.count * 104)
    readonly property real dndHeight: 26

    // (its own size, not its content's: the list grows into what its cell
    // gives it)
    implicitHeight: pane.listNatural + 12 + pane.dndHeight

    // A card's own action ran: the line folds up to make way for the app.
    QtObject {
        id: closer
        function close() {
            Services.EdgeLine.setOpen(false);
        }
    }

    NotificationList {
        width: parent.width
        height: Math.max(pane.listNatural, pane.height - 12 - pane.dndHeight)
        center: closer
    }

    Item {
        width: parent.width
        height: pane.dndHeight

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ControlStyle.label("Do not disturb")
            font.family: ControlStyle.ui
            font.pixelSize: 12
            font.capitalization: ControlStyle.caps
            font.letterSpacing: ControlStyle.upper ? 1 : 0
            color: Colors.withAlpha(ControlStyle.ink, 0.75)
        }

        PaneSwitch {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: Services.Notification.dnd
            onToggled: Services.Notification.toggleDnd()
        }
    }
}
