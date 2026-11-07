pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services as Services

// The screen-share picker's window (ShareView), there while an app is asking
// (Services.ScreenShare.asking): the whole of the focused screen, over
// everything, with the keyboard. It stays unmapped while the view grabs the
// desktop.
Scope {
    LazyLoader {
        active: Services.ScreenShare.asking

        PanelWindow {
            id: window

            screen: Quickshell.screens.find(s => s.name === view.session.focused) ?? Quickshell.screens[0]
            visible: view.shown
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:sharepicker"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "transparent"

            ShareView {
                id: view

                anchors.fill: parent
                session: Services.ScreenShare.session
            }
        }
    }
}
