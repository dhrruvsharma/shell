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

                    // Click empty workspace area to switch to it.
                    MouseArea {
                        anchors.fill: parent
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

                            readonly property var mon: cell.wsMonitor
                            visible: modelData && mon && modelData.lastIpcObject

                            readonly property real localX: (modelData && mon && modelData.lastIpcObject && modelData.lastIpcObject.at) ? modelData.lastIpcObject.at[0] - mon.x : 0
                            readonly property real localY: (modelData && mon && modelData.lastIpcObject && modelData.lastIpcObject.at) ? modelData.lastIpcObject.at[1] - mon.y : 0

                            readonly property real originalX: mon ? Math.floor((localX / mon.width) * workspaceThumbnail.width) : 0
                            readonly property real originalY: mon ? Math.floor((localY / mon.height) * workspaceThumbnail.height) : 0
                            readonly property real originalWidth: (mon && modelData.lastIpcObject && modelData.lastIpcObject.size) ? Math.floor((modelData.lastIpcObject.size[0] / mon.width) * workspaceThumbnail.width) : 0
                            readonly property real originalHeight: (mon && modelData.lastIpcObject && modelData.lastIpcObject.size) ? Math.floor((modelData.lastIpcObject.size[1] / mon.height) * workspaceThumbnail.height) : 0

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
                                // Keep the grab once a drag begins so onReleased
                                // always fires (fixes click + drag both failing).
                                preventStealing: dragState.active

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
