import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.services as Svc
import qs.colors

// Grid of live workspace previews. Drag a window preview onto another
// workspace to move it there; click a window to focus it; click empty
// workspace space to switch to it. Ported from Nebula's WorkspaceOverview.
Rectangle {
    id: overlay
    focus: true
    z: 1
    color: "transparent"

    readonly property int cols: 5
    readonly property int rows: 2
    readonly property int thumbW: 300
    readonly property int thumbH: 200

    // Shared state for the in-flight drag. Only one window is ever dragged
    // at a time, so a single object serves all thumbnail delegates.
    QtObject {
        id: dragState
        property bool active: false
        property var source: null
        property string address: ""
        property int sourceWs: -1
        property real w: 0
        property real h: 0
        property real x: 0
        property real y: 0
    }

    Grid {
        id: grid
        anchors.centerIn: parent
        width: overlay.cols * overlay.thumbW + (overlay.cols - 1) * 10
        height: overlay.rows * overlay.thumbH + (overlay.rows - 1) * 10
        rows: overlay.rows
        columns: overlay.cols
        spacing: 10

        Repeater {
            id: rep
            model: overlay.cols * overlay.rows

            delegate: Item {
                id: cell
                required property int index
                readonly property int wsId: index + 1
                readonly property bool isFocused: Hyprland.focusedWorkspace && wsId === Hyprland.focusedWorkspace.id

                // Monitor this workspace lives on (fallback to focused monitor).
                readonly property var wsMonitor: {
                    var ws = (Hyprland.workspaces.values || []).find(w => w && w.id === cell.wsId)
                    return (ws && ws.monitor) ? ws.monitor : Hyprland.focusedMonitor
                }

                // Reference frame the thumbnail maps from. Fixed scale: the monitor
                // width maps exactly to the thumbnail width, so a normal workspace
                // fills the thumbnail with no scrolling and the monitor height is
                // letterboxed/centred vertically. `contentW` extends horizontally to
                // include windows placed outside the monitor (scrolling layout lays
                // columns out in a virtual space wider than the screen); the thumbnail
                // becomes a horizontally scrollable viewport over that extent.
                readonly property var contentFrame: {
                    var mon = cell.wsMonitor
                    if (!mon || mon.width <= 0) return null
                    var s = overlay.thumbW / mon.width
                    var refX = mon.x, refR = mon.x + mon.width
                    var wins = (Hyprland.toplevels.values || []).filter(t =>
                        t.workspace && t.workspace.id === cell.wsId &&
                        t.lastIpcObject && t.lastIpcObject.at && t.lastIpcObject.size)
                    for (var i = 0; i < wins.length; i++) {
                        var o = wins[i].lastIpcObject
                        refX = Math.min(refX, o.at[0])
                        refR = Math.max(refR, o.at[0] + o.size[0])
                    }
                    return {
                        x: refX, y: mon.y, scale: s,
                        offY: (overlay.thumbH - mon.height * s) / 2,
                        contentW: (refR - refX) * s
                    }
                }

                width: overlay.thumbW
                height: overlay.thumbH

                Rectangle {
                    id: workspaceThumbnail
                    anchors.fill: parent
                    color: Colors.surface_container
                    radius: 10
                    border.width: cell.isFocused ? 3 : 1
                    border.color: cell.isFocused ? Colors.primary : Colors.outline
                    clip: true

                    Text {
                        anchors.centerIn: parent
                        text: "WS " + cell.wsId
                        color: Colors.on_surface
                        opacity: 0.5
                        font.pixelSize: 16
                        font.weight: Font.Bold
                    }

                    // Horizontally scrollable viewport over the workspace. Normal
                    // workspaces exactly fill it (not interactive); scrolling-layout
                    // workspaces extend past the right edge and can be panned by
                    // dragging empty space or using the scroll wheel. No scrollbar.
                    Flickable {
                        id: flick
                        anchors.fill: parent
                        clip: true
                        contentWidth: cell.contentFrame ? Math.max(width, cell.contentFrame.contentW) : width
                        contentHeight: height
                        interactive: contentWidth > width
                        flickableDirection: Flickable.HorizontalFlick
                        boundsBehavior: Flickable.StopAtBounds

                        // Vertical scroll wheel pans horizontally.
                        WheelHandler {
                            onWheel: ev => {
                                var d = ev.angleDelta.y !== 0 ? ev.angleDelta.y : ev.angleDelta.x
                                flick.contentX = Math.max(0, Math.min(flick.contentWidth - flick.width, flick.contentX - d))
                            }
                        }

                        // Tap empty area to switch to this workspace; drag = scroll.
                        MouseArea {
                            width: flick.contentWidth
                            height: flick.contentHeight
                            z: 0
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Svc.Hyprland.dispatch("workspace " + cell.wsId)
                                Svc.ExposeState.open = false
                            }
                        }

                        Repeater {
                            model: (Hyprland.toplevels.values || []).filter(t => t.workspace && t.workspace.id === cell.wsId)

                            delegate: Rectangle {
                                id: windowRect
                            required property var modelData

                            readonly property var frame: cell.contentFrame
                            readonly property var ipc: modelData ? modelData.lastIpcObject : null
                            visible: modelData && frame && ipc && ipc.at && ipc.size

                            readonly property real originalX: (frame && ipc && ipc.at) ? (ipc.at[0] - frame.x) * frame.scale : 0
                            readonly property real originalY: (frame && ipc && ipc.at) ? frame.offY + (ipc.at[1] - frame.y) * frame.scale : 0
                            readonly property real originalWidth: (frame && ipc && ipc.size) ? ipc.size[0] * frame.scale : 0
                            readonly property real originalHeight: (frame && ipc && ipc.size) ? ipc.size[1] * frame.scale : 0

                            x: originalX
                            y: originalY
                            width: originalWidth
                            height: originalHeight
                            z: 1

                            color: "transparent"
                            radius: 3
                            clip: true

                            // Hide the live thumbnail while it is being dragged;
                            // the floating ghost stands in for it.
                            opacity: (dragState.active && dragState.address === String(windowRect.modelData.address)) ? 0 : 1

                            ScreencopyView {
                                anchors.fill: parent
                                captureSource: windowRect.modelData.wayland
                                live: true
                                paintCursor: false
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                radius: 3
                                border.width: dragArea.containsMouse ? 2 : 0
                                border.color: Colors.primary
                            }

                            MouseArea {
                                id: dragArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                // Always hold the grab so a press on a window drags
                                // the window (and onReleased always fires) instead of
                                // the surrounding Flickable stealing it to scroll.
                                preventStealing: true

                                property real pressX: 0
                                property real pressY: 0

                                onPressed: mouse => {
                                    dragArea.pressX = mouse.x
                                    dragArea.pressY = mouse.y
                                }

                                onPositionChanged: mouse => {
                                    // hoverEnabled makes this fire on plain hover too;
                                    // only react while a button is actually held.
                                    if (!dragArea.pressed) return

                                    // Promote to a drag once past the threshold. We move a
                                    // floating ghost rather than reparenting the live item,
                                    // which would break the mouse grab.
                                    if (!dragState.active &&
                                        (Math.abs(mouse.x - dragArea.pressX) > 8 ||
                                         Math.abs(mouse.y - dragArea.pressY) > 8)) {
                                        dragState.source   = windowRect.modelData.wayland
                                        dragState.address  = String(windowRect.modelData.address)
                                        dragState.sourceWs = windowRect.modelData.workspace ? windowRect.modelData.workspace.id : -1
                                        dragState.w        = windowRect.width
                                        dragState.h        = windowRect.height
                                        dragState.active   = true
                                    }
                                    if (dragState.active) {
                                        var pt = dragArea.mapToItem(overlay,
                                            mouse.x - dragState.w / 2,
                                            mouse.y - dragState.h / 2)
                                        dragState.x = pt.x
                                        dragState.y = pt.y
                                    }
                                }

                                onReleased: mouse => {
                                    // Click (no meaningful drag): focus the window.
                                    if (!dragState.active) {
                                        Svc.Hyprland.dispatch("focuswindow address:0x" + windowRect.modelData.address)
                                        Svc.ExposeState.open = false
                                        return
                                    }

                                    // Drag: find the workspace under the drop point and move there.
                                    var center = dragArea.mapToItem(grid, mouse.x, mouse.y)
                                    var targetIndex = -1
                                    for (var i = 0; i < rep.count; i++) {
                                        var wsItem = rep.itemAt(i)
                                        if (wsItem &&
                                            center.x >= wsItem.x && center.x <= wsItem.x + wsItem.width &&
                                            center.y >= wsItem.y && center.y <= wsItem.y + wsItem.height) {
                                            targetIndex = i
                                            break
                                        }
                                    }

                                    if (targetIndex >= 0) {
                                        var targetWsId = targetIndex + 1
                                        if (targetWsId !== dragState.sourceWs)
                                            Svc.Hyprland.dispatch("movetoworkspacesilent " + targetWsId + ",address:0x" + dragState.address)
                                    }

                                    dragState.active = false
                                    Hyprland.refreshToplevels()
                                }
                            }
                        }
                    }
                    }
                }
            }
        }
    }

    // Floating preview that follows the cursor during a drag.
    Rectangle {
        id: dragGhost
        visible: dragState.active
        x: dragState.x
        y: dragState.y
        width: dragState.w
        height: dragState.h
        z: 100
        color: "transparent"
        radius: 3
        clip: true
        opacity: 0.85

        ScreencopyView {
            anchors.fill: parent
            captureSource: dragState.source
            live: true
            paintCursor: false
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: 3
            border.width: 2
            border.color: Colors.primary
        }
    }
}
