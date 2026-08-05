import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.colors

// Rotating "revolver cylinder" workspace indicator, ported from zesis-shell.
// The disc rotates so the active workspace's chamber lands at a fixed corner
// angle; chambers counter-rotate so numbers stay upright. Peeks from the
// screen corner and expands on hover.
Item {
    id: root

    readonly property int discRadius:   Math.round(WorkspaceDiscService.discRadius * UIScale.value)
    readonly property int chamberSize:  Math.round(WorkspaceDiscService.chamberSize * UIScale.value)
    readonly property int pad:          Math.round(16 * UIScale.value)
    readonly property int workSpaceAmount: WorkspaceDiscService.workSpaceAmount
    readonly property int peekOffset:   Math.round(WorkspaceDiscService.peekOffset * UIScale.value)

    implicitWidth: (discRadius + pad) * 2
    implicitHeight: (discRadius + pad) * 2

    // Mask region so the host window only accepts clicks over the disc itself.
    readonly property real maskX: visualDiscCX - discRadius
    readonly property real maskY: visualDiscCY - discRadius
    readonly property real maskWidth: discRadius * 2
    readonly property real maskHeight: discRadius * 2
    readonly property int maskShape: RegionShape.Ellipse

    // Live, ascending list of real workspace ids.
    readonly property var sortedWsIds: {
        var ids = (Hyprland.workspaceIds || []).filter(n => !isNaN(n) && n > 0)
        ids.sort((a, b) => a - b)
        return ids
    }

    readonly property int effectiveN: WorkspaceDiscService.expressive
        ? Math.max(WorkspaceDiscService.minWorkSpaceAmount, root.sortedWsIds.length)
        : root.workSpaceAmount

    readonly property int activeId: Hyprland.focusedWorkspaceId

    readonly property int activeIndex: {
        if (WorkspaceDiscService.expressive) {
            var idx = root.sortedWsIds.indexOf(root.activeId)
            return idx >= 0 ? idx : 0
        }
        return Math.max(0, Math.min(root.effectiveN - 1, root.activeId - 1))
    }

    // "topLeft" | "bottomLeft" | "topRight" | "bottomRight"
    property string corner: WorkspaceDiscService.corner

    readonly property bool _flipX: corner === "topRight" || corner === "bottomRight"
    readonly property bool _flipY: corner === "bottomLeft" || corner === "bottomRight"

    readonly property real _cornerAngle: {
        if (corner === "bottomLeft")  return -45
        if (corner === "topRight")    return 135
        if (corner === "bottomRight") return 225
        return 45
    }

    property bool forceExpanded: false
    property bool _hoveredExpanded: false
    readonly property bool expanded: root.forceExpanded || root._hoveredExpanded

    readonly property real discRotation: disc.rotation

    readonly property real discCX: {
        if (expanded)
            return root._flipX ? root.width - discRadius - pad : discRadius + pad
        return root._flipX ? root.width - peekOffset : peekOffset
    }
    readonly property real discCY: {
        if (expanded)
            return root._flipY ? root.height - discRadius - pad : discRadius + pad
        return root._flipY ? root.height - peekOffset : peekOffset
    }

    // Animated center, tracks the disc's actual visual position during transitions.
    readonly property real visualDiscCX: disc.x + discRadius
    readonly property real visualDiscCY: disc.y + discRadius

    readonly property real _skinOrbitRadius: skinLoader.item ? skinLoader.item.orbitRadius : Math.round(WorkspaceDiscService.chamberRadius * UIScale.value)

    Timer {
        id: collapseTimer
        interval: Anim.slow
        onTriggered: root._hoveredExpanded = false
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                collapseTimer.stop()
                root._hoveredExpanded = true
            } else {
                collapseTimer.restart()
            }
        }
    }

    Item {
        id: disc
        width: root.discRadius * 2
        height: root.discRadius * 2

        x: root.discCX - root.discRadius
        y: root.discCY - root.discRadius

        Behavior on x { NumberAnimation { duration: Anim.slow; easing.type: Easing.InOutCubic } }
        Behavior on y { NumberAnimation { duration: Anim.slow; easing.type: Easing.InOutCubic } }

        rotation: root._cornerAngle + root.activeIndex * (360 / root.effectiveN)

        Behavior on rotation {
            RotationAnimation {
                duration: Anim.slow
                direction: RotationAnimation.Shortest
                easing.type: Easing.InOutCubic
            }
        }

        Loader {
            id: skinLoader
            anchors.fill: parent
            source: {
                var name = WorkspaceDiscService.skin
                return "skins/WorkspaceDiscSkin" + name.charAt(0).toUpperCase() + name.slice(1) + ".qml"
            }
            onLoaded: {
                item.discRadius = Qt.binding(() => root.discRadius)
                item.effectiveN = Qt.binding(() => root.effectiveN)
            }
        }

        Component {
            id: defaultChamber
            Rectangle {
                property bool isActive: false
                property bool hasWindows: false
                radius: width / 2
                color: isActive ? Colors.accent : Colors.surfaceHigh
                border.color: isActive ? Colors.withAlpha(Colors.onAccent, 0.6) : Colors.withAlpha(Colors.accent, 0.2)
                border.width: 1
            }
        }

        Repeater {
            model: root.effectiveN
            delegate: Item {
                id: wsItem
                required property int index

                property int wsIndex: WorkspaceDiscService.expressive
                    ? (root.sortedWsIds[wsItem.index] ?? wsItem.index + 1)
                    : wsItem.index + 1
                property bool isActive: wsItem.index === root.activeIndex
                property bool hasWindows: Hyprland.isWorkspaceOccupied(wsItem.wsIndex)

                readonly property real _orbit: root._skinOrbitRadius

                width: root.chamberSize
                height: root.chamberSize
                x: root.discRadius + Math.cos(wsItem.index * 2 * Math.PI / root.effectiveN) * wsItem._orbit - root.chamberSize / 2
                y: root.discRadius - Math.sin(wsItem.index * 2 * Math.PI / root.effectiveN) * wsItem._orbit - root.chamberSize / 2

                Loader {
                    anchors.fill: parent
                    rotation: (skinLoader.item ? (skinLoader.item.counterRotateChambers ?? true) : true) ? -root.discRotation : 0
                    sourceComponent: skinLoader.item ? (skinLoader.item.chamberDelegate ?? defaultChamber) : defaultChamber
                    onLoaded: {
                        item.isActive = Qt.binding(() => wsItem.isActive)
                        item.hasWindows = Qt.binding(() => wsItem.hasWindows)
                        if ("chamberAngle" in item)
                            item.chamberAngle = Qt.binding(() => wsItem.index * (360.0 / root.effectiveN))
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: wsItem.wsIndex
                    font.pixelSize: UIScale.fontTiny
                    font.bold: wsItem.isActive
                    color: wsItem.isActive ? (skinLoader.item ? (skinLoader.item.activeNumberColor ?? Colors.surface) : Colors.surface) : Colors.text
                    rotation: -root.discRotation
                }

                MouseArea {
                    id: chamberMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.expanded)
                            Hyprland.changeWorkspace(wsItem.wsIndex)
                    }
                }

                PopupWindow {
                    id: wsPopup
                    visible: chamberMouseArea.containsMouse && root.expanded && wsItem.hasWindows
                    color: "transparent"

                    anchor.item: wsItem
                    anchor.edges: Edges.Right | Edges.Top
                    anchor.gravity: Edges.Right | Edges.Bottom
                    anchor.adjustment: PopupAdjustment.All
                    anchor.margins.left: 8

                    property var wsMonitor: {
                        var ws = (Hyprland.workspaces.values || []).find(w => w && w.id === wsItem.wsIndex)
                        return (ws && ws.monitor) ? ws.monitor : Hyprland.focusedMonitor
                    }

                    readonly property int thumbW: 420
                    readonly property int thumbH: wsMonitor ? Math.round(thumbW * wsMonitor.height / wsMonitor.width) : 158
                    readonly property real thumbScale: wsMonitor ? thumbW / wsMonitor.width : 1
                    readonly property real monOffX: wsMonitor ? wsMonitor.x : 0
                    readonly property real monOffY: wsMonitor ? wsMonitor.y : 0

                    implicitWidth: thumbW + 2
                    implicitHeight: thumbH + 2

                    onVisibleChanged: if (visible) Hyprland.updateAll()

                    Loader {
                        active: wsPopup.visible
                        anchors.fill: parent
                        sourceComponent: Rectangle {
                            color: Colors.bg
                            border.color: Colors.withAlpha(Colors.accent, 0.35)
                            border.width: 1
                            radius: 6
                            clip: true

                            Item {
                                x: 1
                                y: 1
                                width: wsPopup.thumbW
                                height: wsPopup.thumbH
                                clip: true

                                Repeater {
                                    model: (Hyprland.toplevels.values || []).filter(t => t.workspace && t.workspace.id === wsItem.wsIndex)
                                    delegate: Item {
                                        id: winItem
                                        required property var modelData

                                        x: {
                                            var at = winItem.modelData.lastIpcObject["at"]
                                            return at ? (at[0] - wsPopup.monOffX) * wsPopup.thumbScale : 0
                                        }
                                        y: {
                                            var at = winItem.modelData.lastIpcObject["at"]
                                            return at ? (at[1] - wsPopup.monOffY) * wsPopup.thumbScale : 0
                                        }
                                        width: {
                                            var sz = winItem.modelData.lastIpcObject["size"]
                                            return sz ? sz[0] * wsPopup.thumbScale : 50
                                        }
                                        height: {
                                            var sz = winItem.modelData.lastIpcObject["size"]
                                            return sz ? sz[1] * wsPopup.thumbScale : 50
                                        }

                                        ScreencopyView {
                                            anchors.fill: parent
                                            captureSource: winItem.modelData.wayland
                                            live: true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
