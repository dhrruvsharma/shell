pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services as Services

// The toasts: the newest notifications stacked in the top right corner, clear
// of the bar wherever it stands, each on the theme's frame (NotificationToast).
// Only the toasts take clicks. The surface takes the keyboard while a reply
// is being typed on one, and lets it go after.
PanelWindow {
    id: win

    readonly property var popups: Services.Notification.popups
    readonly property real gap: 12
    readonly property bool replying: popups.some(n => n.replying)

    color: "transparent"
    anchors.top: true
    anchors.right: true
    margins.top: Services.BarLayout.reserveTop + gap
    margins.right: Services.BarLayout.reserveRight + gap

    implicitWidth: 384
    implicitHeight: Math.max(1, column.implicitHeight)
    visible: popups.length > 0
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:notifications"
    // A mapped layer going to Exclusive takes the keyboard; it never maps
    // with it (that would take the pointer too).
    WlrLayershell.keyboardFocus: replying ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region {
        item: column
    }

    Column {
        id: column
        width: parent.width
        spacing: 10

        move: Transition {
            NumberAnimation {
                property: "y"
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        Repeater {
            id: stack
            // Newest on top. (A ScriptModel keeps each toast as it is when
            // another comes or goes: its slide, a reply half typed.)
            model: ScriptModel {
                values: win.popups.slice().reverse()
            }

            NotificationToast {
                required property var modelData
                width: column.width
                n: modelData
            }
        }
    }
}
