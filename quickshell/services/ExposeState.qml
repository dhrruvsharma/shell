pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The expose / workspace overview, toggled over IPC:
//   qs ipc call expose toggle
// It comes as the panorama (services/Panorama: the workspaces on a strip
// round you) or as the grid of live windows, as Panorama.view says; `open`
// is the grid's.
Singleton {
    id: root

    property bool open: false

    function toggle() {
        if (root.open) {
            root.open = false;
            return;
        }
        if (Panorama.overviewOpen) {
            Panorama.closeOverview();
            return;
        }
        if (!Panorama.toggleOverview())
            root.open = true;
    }

    function show() {
        if (root.open || Panorama.overviewOpen)
            return;
        if (!Panorama.openOverview())
            root.open = true;
    }

    function hide() {
        root.open = false;
        Panorama.closeOverview();
    }

    IpcHandler {
        target: "expose"
        function toggle(): void { root.toggle() }
        function show(): void { root.show() }
        function hide(): void { root.hide() }
    }
}
