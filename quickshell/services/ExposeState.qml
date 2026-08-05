pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Visibility state for the expose / workspace overview, toggled over IPC:
//   qs ipc call expose toggle
Singleton {
    id: root

    property bool open: false

    function toggle() { root.open = !root.open }

    IpcHandler {
        target: "expose"
        function toggle(): void { root.toggle() }
        function show(): void { root.open = true }
        function hide(): void { root.open = false }
    }
}
