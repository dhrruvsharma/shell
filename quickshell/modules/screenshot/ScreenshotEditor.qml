pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.services as Services

// The screenshot editor's window (EditorView), there while
// Services.Screenshot.session is set: the whole of the focused screen,
// over everything, with the keyboard.
Scope {
    LazyLoader {
        active: Services.Screenshot.session !== null

        PanelWindow {
            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:screenshot"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            EditorView {
                anchors.fill: parent
            }
        }
    }
}
