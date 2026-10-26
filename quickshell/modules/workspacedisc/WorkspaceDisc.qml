// SPDX-License-Identifier: GPL-3.0-or-later
//
// Derived from zesis-shell's widgets/workspaceindicator/disc/WorkspaceDisc.qml.
// Copyright (C) 2026 Squirrel Modeller (zesis-shell)
//   https://github.com/zesis-shell/zesis
// Modifications copyright (C) 2026 dhrruvsharma.
//
// Licensed under the GNU General Public License, version 3 or (at your
// option) any later version. See LICENSE in the repository root.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.colors
import qs.components

// Rotating "revolver cylinder" workspace indicator, ported from zesis-shell.
// The disc rotates so the active workspace's chamber lands at a fixed corner
// angle; chambers counter-rotate so numbers stay upright. Peeks from the
// screen corner and expands on hover. Press and drag it to move it to
// another corner (WorkspaceDiscWindow does the moving).
//
// Set to hide when idle (WorkspaceDiscService.visibility "auto"), it tucks
// itself right into the corner once you've stayed on one workspace a while,
// and comes back out as you switch, or when the pointer reaches the corner.
Item {
    id: root

    // Being dragged to another corner (set by the window).
    property bool moving: false
    // Drawn as a picture (the customizer's plates): no pointer, no tucking
    // away; `corner` and `forceExpanded` set what it shows.
    property bool still: false

    // The press and the drag, in the window's coordinates.
    signal grabbed(point pos)
    signal dragged(point pos)
    signal letGo()

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
    // Opened out for a moment as the workspace changes (openOnSwitch).
    property bool _switchOpen: false
    readonly property bool expanded: root.forceExpanded || root._hoveredExpanded || root._switchOpen

    // ── Tucked away when idle ────────────────────────────────────────────────
    readonly property bool autoHide: !root.still && WorkspaceDiscService.visibility === "auto"
    property bool awake: true
    property bool _hovered: false
    readonly property bool tucked: root.autoHide && !root.awake && !root.forceExpanded && !root.moving
    // The corner the pointer can wake it from while it's tucked away.
    readonly property int revealSize: Math.round(26 * UIScale.value)

    function wake() {
        root.awake = true
        idleTimer.restart()
    }

    onAutoHideChanged: root.wake()

    onActiveIdChanged: {
        if (root.autoHide && WorkspaceDiscService.revealOnSwitch)
            root.wake()
        if (WorkspaceDiscService.openOnSwitch && !root.still && (!root.autoHide || WorkspaceDiscService.revealOnSwitch)) {
            root._switchOpen = true
            switchTimer.restart()
        }
    }

    Timer {
        id: idleTimer
        interval: WorkspaceDiscService.hideAfter * 1000
        running: root.autoHide
        onTriggered: {
            if (root._hovered || root.forceExpanded || root.moving || root._switchOpen)
                idleTimer.restart()
            else
                root.awake = false
        }
    }

    Timer {
        id: switchTimer
        interval: 1400
        onTriggered: root._switchOpen = false
    }

    readonly property real discRotation: disc.rotation

    readonly property real discCX: {
        if (tucked)
            return root._flipX ? root.width + discRadius + 2 : -discRadius - 2
        if (expanded)
            return root._flipX ? root.width - discRadius - pad : discRadius + pad
        return root._flipX ? root.width - peekOffset : peekOffset
    }
    readonly property real discCY: {
        if (tucked)
            return root._flipY ? root.height + discRadius + 2 : -discRadius - 2
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
        enabled: !root.still
        onHoveredChanged: {
            root._hovered = hovered
            if (hovered) {
                collapseTimer.stop()
                if (root.autoHide)
                    root.wake()
                root._hoveredExpanded = true
            } else {
                collapseTimer.restart()
                if (root.autoHide)
                    idleTimer.restart()
            }
        }
    }

    Item {
        id: disc
        width: root.discRadius * 2
        height: root.discRadius * 2

        x: root.discCX - root.discRadius
        y: root.discCY - root.discRadius
        opacity: root.tucked ? 0 : 1

        Behavior on opacity { NumberAnimation { duration: Anim.slow; easing.type: Easing.InOutCubic } }

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
            id: chambers
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

                StyledText {
                    anchors.centerIn: parent
                    text: wsItem.wsIndex
                    font.pixelSize: UIScale.fontTiny
                    font.bold: wsItem.isActive
                    color: wsItem.isActive ? (skinLoader.item ? (skinLoader.item.activeNumberColor ?? Colors.surface) : Colors.surface) : Colors.text
                    rotation: -root.discRotation
                }

                // Hover and cursor only: the grip below takes the clicks.
                MouseArea {
                    id: chamberMouseArea
                    anchors.fill: parent
                    enabled: !root.still
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                }

                PopupWindow {
                    id: wsPopup
                    visible: chamberMouseArea.containsMouse && root.expanded && wsItem.hasWindows && !root.moving
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

    // A click: switch to the workspace of the chamber under `p` (in the
    // grip's coordinates), once the disc has opened out.
    function clickAt(p) {
        if (!root.expanded)
            return
        for (let i = 0; i < chambers.count; i++) {
            const c = chambers.itemAt(i)
            if (!c)
                continue
            const q = c.mapFromItem(grip, p.x, p.y)
            if (Math.hypot(q.x - c.width / 2, q.y - c.height / 2) <= c.width / 2) {
                Hyprland.changeWorkspace(c.wsIndex)
                return
            }
        }
    }

    // Takes every press, so the disc can be dragged; a plain click (no
    // drag) switches to the chamber that was pressed. It goes by where the
    // press was: the surface grows on a press (WorkspaceDiscWindow), and a
    // Wayland button carries no position, so the release's is stale.
    MouseArea {
        id: grip

        property point pressPoint: Qt.point(0, 0)
        property bool wasDragged: false

        anchors.fill: parent
        enabled: !root.still

        onPressed: mouse => {
            grip.pressPoint = Qt.point(mouse.x, mouse.y);
            grip.wasDragged = false;
            root.grabbed(grip.mapToItem(null, mouse.x, mouse.y));
        }
        onPositionChanged: mouse => {
            root.dragged(grip.mapToItem(null, mouse.x, mouse.y));
            if (root.moving)
                grip.wasDragged = true;
        }
        onReleased: {
            const click = !grip.wasDragged;
            root.letGo();
            if (click)
                root.clickAt(grip.pressPoint);
        }
        onCanceled: root.letGo()
    }

    HoverHandler {
        enabled: root.moving
        cursorShape: Qt.ClosedHandCursor
    }
}
