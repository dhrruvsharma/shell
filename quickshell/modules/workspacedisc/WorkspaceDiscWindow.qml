// SPDX-License-Identifier: GPL-3.0-or-later
//
// Derived from zesis-shell's widgets/workspaceindicator/disc/WorkspaceDiscPanel.qml.
// Copyright (C) 2026 Squirrel Modeller (zesis-shell)
//   https://github.com/zesis-shell/zesis
// Modifications copyright (C) 2026 dhrruvsharma.
//
// Licensed under the GNU General Public License, version 3 or (at your
// option) any later version. See LICENSE in the repository root.

pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.colors
import qs.services

// Corner-anchored layer surface that hosts the rotating workspace disc.
// The window is transparent and masked to the disc ellipse, so only the disc
// itself is interactive and everything else clicks through. It keeps clear
// of the bar: in a corner on the bar's edge it peeks out beside the bar.
//
// Drag the disc to move it to another corner. While it's held the surface
// covers the screen, so the disc moves inside it with plain Qt dragging
// (as a desktop widget does); the corners it can go to show, the nearest
// lit, and on release it settles into that one and the surface shrinks
// back round it there. The corner is saved in workspacedisc.json.
PanelWindow {
    id: win

    readonly property string corner: WorkspaceDiscService.corner

    readonly property real sw: screen ? screen.width : 1920
    readonly property real sh: screen ? screen.height : 1200
    readonly property real boxW: disc.implicitWidth
    readonly property real boxH: disc.implicitHeight

    function onRight(c) {
        return c === "topRight" || c === "bottomRight";
    }
    function onBottom(c) {
        return c === "bottomLeft" || c === "bottomRight";
    }
    // Where the disc's box sits in a corner, clear of the bar.
    function boxX(c) {
        return win.onRight(c) ? win.sw - BarLayout.reserveRight - win.boxW : BarLayout.reserveLeft;
    }
    function boxY(c) {
        return win.onBottom(c) ? win.sh - BarLayout.reserveBottom - win.boxH : BarLayout.reserveTop;
    }

    // Pressed: the surface covers the screen.
    property bool held: false
    // Dragged far enough to be a move; settling into its new corner after.
    property bool dragging: false
    property bool settling: false
    property string target: win.corner
    // The box's place on the screen while held.
    property real dragX: 0
    property real dragY: 0
    property point pressPos: Qt.point(0, 0)
    property point grabOffset: Qt.point(0, 0)
    readonly property bool full: width >= sw - 1 && height >= sh - 1

    WlrLayershell.layer: WlrLayer.Top
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: -1
    color: "transparent"

    anchors {
        top: win.held || !win.onBottom(win.corner)
        bottom: win.held || win.onBottom(win.corner)
        left: win.held || !win.onRight(win.corner)
        right: win.held || win.onRight(win.corner)
    }
    margins.top: win.held ? 0 : BarLayout.reserveTop
    margins.bottom: win.held ? 0 : BarLayout.reserveBottom
    margins.left: win.held ? 0 : BarLayout.reserveLeft
    margins.right: win.held ? 0 : BarLayout.reserveRight

    implicitWidth: disc.implicitWidth
    implicitHeight: disc.implicitHeight

    // The disc ellipse; no mask at all (the whole surface) while it's held.
    // Hyprland moves the surface as it grows before Qt's next frame brings
    // a mask for the new place, and with no window holding the keyboard a
    // pointer outside the old mask goes elsewhere, losing the press.
    mask: win.held && !win.settling ? null : discMask

    Region {
        id: discMask
        shape: disc.maskShape
        x: disc.x + disc.maskX
        y: disc.y + disc.maskY
        width: disc.maskWidth
        height: disc.maskHeight
    }

    // A point in the window's coordinates, on the screen.
    function toScreen(p) {
        return win.full ? p : Qt.point(win.boxX(win.corner) + p.x, win.boxY(win.corner) + p.y);
    }

    function press(p) {
        if (win.settling)
            return;
        win.pressPos = win.toScreen(p);
        win.dragX = win.boxX(win.corner);
        win.dragY = win.boxY(win.corner);
        win.target = win.corner;
        win.dragging = false;
        win.held = true;
    }

    function drag(p) {
        if (!win.held || win.settling || !win.full)
            return;
        const s = win.toScreen(p);
        if (!win.dragging) {
            if (Math.hypot(s.x - win.pressPos.x, s.y - win.pressPos.y) < 6)
                return;
            win.grabOffset = Qt.point(win.pressPos.x - win.dragX, win.pressPos.y - win.dragY);
            win.dragging = true;
            WorkspaceDiscService.moving = true;
        }
        win.dragX = Math.max(0, Math.min(win.sw - win.boxW, s.x - win.grabOffset.x));
        win.dragY = Math.max(0, Math.min(win.sh - win.boxH, s.y - win.grabOffset.y));
        const cx = win.dragX + win.boxW / 2, cy = win.dragY + win.boxH / 2;
        win.target = (cy < win.sh / 2 ? "top" : "bottom") + (cx < win.sw / 2 ? "Left" : "Right");
    }

    function letGo() {
        WorkspaceDiscService.moving = false;
        if (!win.held || win.settling)
            return;
        if (!win.dragging) {
            win.held = false;
            return;
        }
        // Glide into the corner, then give the surface back.
        win.dragging = false;
        win.settling = true;
        win.dragX = win.boxX(win.target);
        win.dragY = win.boxY(win.target);
        WorkspaceDiscService.setCorner(win.target);
        settleTimer.restart();
    }

    Timer {
        id: settleTimer
        interval: Anim.slow + 40
        onTriggered: {
            win.settling = false;
            win.held = false;
        }
    }

    Item {
        anchors.fill: parent

        // A press that loses the pointer to another surface gets no
        // release; with the surface covering the screen, the pointer leaving
        // it can only mean that. Drop the disc where it is.
        HoverHandler {
            onHoveredChanged: if (!hovered && win.held && win.full && !win.settling) win.letGo()
        }

        // The corners it can go to, while it's dragged: where it would
        // peek out, the nearest one lit.
        Repeater {
            model: win.dragging ? WorkspaceDiscService.corners : []

            Rectangle {
                id: spot

                required property string modelData
                readonly property bool lit: modelData === win.target
                readonly property real r: disc.discRadius + 8

                x: win.boxX(modelData) + (win.onRight(modelData) ? win.boxW - disc.peekOffset : disc.peekOffset) - r
                y: win.boxY(modelData) + (win.onBottom(modelData) ? win.boxH - disc.peekOffset : disc.peekOffset) - r
                width: 2 * r
                height: 2 * r
                radius: r
                color: Colors.withAlpha(Colors.primary, spot.lit ? 0.22 : 0.06)
                border.width: 2
                border.color: Colors.withAlpha(Colors.primary, spot.lit ? 0.9 : 0.3)

                Behavior on color {
                    ColorAnimation {
                        duration: 140
                    }
                }
            }
        }

        WorkspaceDisc {
            id: disc

            // At the surface's corner normally; on the screen while the
            // surface covers it (following the drag, then the glide).
            x: win.full ? win.dragX : 0
            y: win.full ? win.dragY : 0
            width: implicitWidth
            height: implicitHeight
            corner: win.corner
            moving: win.dragging
            // Open while it's held, and while it glides into place.
            forceExpanded: win.held || win.settling

            onGrabbed: pos => win.press(pos)
            onDragged: pos => win.drag(pos)
            onLetGo: win.letGo()

            Behavior on x {
                enabled: win.settling
                NumberAnimation {
                    duration: Anim.slow
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on y {
                enabled: win.settling
                NumberAnimation {
                    duration: Anim.slow
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
