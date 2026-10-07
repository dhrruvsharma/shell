import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.modules.wallpaper
import qs.services as Services

// The wallpaper (drawn by Quickshell on every screen) and the swatch-deck
// picker over it:
//
//   qs-wallpaperpicker toggle|wallhaven|set <file>|current
// (bin/qs-wallpaperpicker; underneath, `qs -p <this folder> ipc call
// wallpaper …`)
ShellRoot {
    id: root

    // Tracked by hand: while the window is unmapped the picker reads as
    // invisible, so its own `visible` can't say whether it should show.
    property bool pickerOpen: false

    function openPicker() {
        if (!pickerLoader.active)
            pickerLoader.active = true;
        pickerOpen = true;
        pickerLoader.item.open();
    }

    WallpaperLayer {}

    PanelWindow {
        id: window

        visible: root.pickerOpen

        WlrLayershell.namespace: "qs-wallpaperpicker"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Loader {
            id: pickerLoader
            anchors.fill: parent
            active: false
            focus: true
            sourceComponent: Wallpaper {}
        }
    }

    Connections {
        target: pickerLoader.item
        // Closed (once its close animation is over): unmap, and unload soon
        // after so its pictures don't stay in memory.
        function onVisibleChanged() {
            if (!root.pickerOpen || pickerLoader.item.visible)
                return;
            root.pickerOpen = false;
            unloadTimer.start();
        }
    }

    Timer {
        id: unloadTimer
        interval: 600
        // unless it was opened again in the meantime
        onTriggered: if (!root.pickerOpen) pickerLoader.active = false
    }

    IpcHandler {
        target: "wallpaper"

        function toggle(): void {
            const picker = pickerLoader.item;
            if (!root.pickerOpen || picker.closing)
                root.openPicker();
            else
                picker.close();
        }

        function wallhaven(): void {
            root.openPicker();
            pickerLoader.item.setMode("wallhaven");
        }

        function set(path: string): void {
            Services.WallpaperEngine.set(path);
        }

        function current(): string {
            return Services.WallpaperEngine.current;
        }
    }
}
