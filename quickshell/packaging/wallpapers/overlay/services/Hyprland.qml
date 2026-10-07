pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// The windows Hyprland has open, for the wallpaper layer: a video wallpaper
// pauses while tiled or fullscreen windows cover it. On other compositors
// the list stays empty and videos always play.
Singleton {
    id: root

    readonly property bool available: (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ?? "") !== ""
    // `hyprctl clients -j`
    property var windowList: []

    Process {
        id: clients
        running: root.available
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.windowList = JSON.parse(text);
                } catch (e) {
                    console.warn("hyprctl clients:", e);
                }
            }
        }
    }

    Connections {
        target: root.available ? Hyprland : null
        function onRawEvent(event) {
            if (!event.name.endsWith("v2") && /window|floating|fullscreen|workspace/.test(event.name))
                clients.running = true;
        }
    }
}
