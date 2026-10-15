import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services as Services

// The volume / brightness OSD (OsdPill) in a small click-through surface of
// its own, mapped only while the pill is up or on its way out. It sits on
// the overlay layer, so it shows over a fullscreen video too, and keeps one
// size throughout (the pill moves inside it): Hyprland would animate a
// layer's size changes, and hypr/quickshell.lua turns its layer animation
// off for this namespace.
PanelWindow {
    id: win

    readonly property bool wanted: Services.Osd.visible
    // Set once the freshly mapped surface has drawn its first frame, so the
    // pill's entrance starts on screen rather than partway through.
    property bool live: false
    readonly property var sink: Services.Volume.defaultSink

    visible: wanted || pill.pop > 0
    onVisibleChanged: if (!visible) live = false

    anchors.bottom: true
    margins.bottom: 36 + Services.BarLayout.reserveBottom
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    mask: Region {}

    // Room round the pill for its shadow and its bead's overshoot.
    implicitWidth: pill.pillWidth + 64
    implicitHeight: pill.pillHeight + 56

    OsdPill {
        id: pill

        anchors.fill: parent
        shown: win.wanted && win.live
        kind: Services.Osd.type || "volume"
        volume: Services.Osd.volume
        brightness: Services.Osd.brightness
        muted: Services.Volume.muted
        device: win.sink ? (win.sink.nickname || win.sink.description || "Output") : "Volume"
        deviceIcon: win.iconFor(win.sink)
        pulse: Services.Osd.pulse
    }

    Connections {
        target: pill.Window.window
        enabled: win.visible && !win.live

        function onFrameSwapped() {
            win.live = true;
        }
    }

    // In case no frame comes, start anyway.
    Timer {
        interval: 150
        running: win.visible && !win.live
        onTriggered: win.live = true
    }

    // Headphones for Bluetooth and headphone outputs, a screen for HDMI and
    // DisplayPort, a speaker otherwise.
    function iconFor(node) {
        if (!node)
            return "";
        const s = (node.name + " " + node.nickname + " " + node.description).toLowerCase();
        if (node.name.startsWith("bluez_") || s.includes("headphone") || s.includes("headset"))
            return "󰋋";
        if (s.includes("hdmi") || s.includes("displayport"))
            return "󰍹";
        return "󰓃";
    }
}
