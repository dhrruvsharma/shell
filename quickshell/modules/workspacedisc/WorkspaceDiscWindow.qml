import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Corner-anchored layer surface that hosts the rotating workspace disc.
// The window is transparent and masked to the disc ellipse, so only the disc
// itself is interactive and everything else clicks through.
PanelWindow {
    id: win

    readonly property string corner: WorkspaceDiscService.corner

    WlrLayershell.layer: WlrLayer.Top
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: -1
    color: "transparent"

    anchors {
        top: corner === "topLeft" || corner === "topRight"
        bottom: corner === "bottomLeft" || corner === "bottomRight"
        left: corner === "topLeft" || corner === "bottomLeft"
        right: corner === "topRight" || corner === "bottomRight"
    }

    implicitWidth: disc.implicitWidth
    implicitHeight: disc.implicitHeight

    mask: Region {
        shape: disc.maskShape
        x: disc.maskX
        y: disc.maskY
        width: disc.maskWidth
        height: disc.maskHeight
    }

    WorkspaceDisc {
        id: disc
        anchors.fill: parent
        corner: win.corner
    }
}
