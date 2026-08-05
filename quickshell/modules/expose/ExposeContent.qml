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
                            Hyprland.dispatch("workspace " + cell.wsId)
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

                            property bool dragging: false

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
                                drag.target: parent
                                drag.axis: Drag.XAndYAxis

                                onPressed: {
                                    windowRect.dragging = false
                                    var globalPos = windowRect.mapToItem(overlay, 0, 0)
                                    windowRect.parent = overlay
                                    windowRect.x = globalPos.x
                                    windowRect.y = globalPos.y
                                    windowRect.z = 10
                                }

                                onPositionChanged: mouse => {
                                    if (drag.active)
                                        windowRect.dragging = true
                                }

                                onReleased: {
                                    // Click (no meaningful drag): focus the window.
                                    if (!windowRect.dragging) {
                                        windowRect.parent = workspaceThumbnail
                                        windowRect.x = Qt.binding(() => windowRect.originalX)
                                        windowRect.y = Qt.binding(() => windowRect.originalY)
                                        windowRect.z = 1
                                        Hyprland.dispatch("focuswindow address:0x" + windowRect.modelData.address)
                                        Svc.ExposeState.open = false
                                        return
                                    }

                                    // Drag: find the workspace under the drop point and move there.
                                    var globalPos = windowRect.mapToItem(grid, windowRect.width / 2, windowRect.height / 2)
                                    var targetIndex = -1
                                    for (var i = 0; i < rep.count; i++) {
                                        var wsItem = rep.itemAt(i)
                                        if (wsItem &&
                                            globalPos.x >= wsItem.x && globalPos.x <= wsItem.x + wsItem.width &&
                                            globalPos.y >= wsItem.y && globalPos.y <= wsItem.y + wsItem.height) {
                                            targetIndex = i
                                            break
                                        }
                                    }

                                    if (targetIndex >= 0) {
                                        var targetWsId = targetIndex + 1
                                        var currentWsId = windowRect.modelData.workspace ? windowRect.modelData.workspace.id : -1
                                        if (targetWsId !== currentWsId)
                                            Hyprland.dispatch("movetoworkspacesilent " + targetWsId + ",address:0x" + windowRect.modelData.address)
                                    }

                                    windowRect.parent = workspaceThumbnail
                                    windowRect.x = Qt.binding(() => windowRect.originalX)
                                    windowRect.y = Qt.binding(() => windowRect.originalY)
                                    windowRect.z = 1
                                    windowRect.dragging = false
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
