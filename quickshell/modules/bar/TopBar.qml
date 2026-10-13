// SPDX-License-Identifier: GPL-3.0-or-later
//
// Derived from zesis-shell's widgets/bar/BarZoneRow.qml.
// Copyright (C) 2026 Squirrel Modeller (zesis-shell)
//   https://github.com/zesis-shell/zesis
// Modifications copyright (C) 2026 dhrruvsharma.
//
// Licensed under the GNU General Public License, version 3 or (at your
// option) any later version. See LICENSE in the repository root.

import QtQuick
import qs.modules.bar.components
import qs.modules.pet
import qs.services as Services
import qs.colors
import qs.components

// The bar, with drag-rearrangeable "islands". Every draggable widget is an atom
// living in an island (a group of 1+ atoms sharing a pill/tray). Islands live in
// two ordered regions, left and right, driven by the BarLayout service. The
// center media pill and the end system tray are fixed and never move.
// The pet (modules/pet) lives in the free stretches between them.
//
// On the left or right screen edge the bar stands on end: the regions run
// top and bottom, islands and their atoms stack, and dragging works along
// the bar's length. Positions and lengths along the bar (x lying, y
// standing) go through _along()/_pos()/_len().
Item {
    id: topBar

    // Fills the bar's strip (modules/bar/Bar.qml), whichever way it runs.
    anchors.fill: parent
    focus: true

    readonly property bool vertical: Services.BarLayout.vertical
    // An island's thickness across the bar.
    readonly property real islandHeight: 34

    // A point's or an item's position along the bar, and an item's length.
    function _along(p) {
        return topBar.vertical ? p.y : p.x;
    }
    function _pos(item) {
        return topBar._along(item.mapToItem(topBar, 0, 0));
    }
    function _len(item) {
        return topBar.vertical ? item.height : item.width;
    }

    // id -> widget source for the draggable atoms. Media and tray are fixed and
    // intentionally excluded from this map.
    readonly property var atomSources: ({
            "cpu": "components/Cpu.qml",
            "battery": "components/Battery.qml",
            "clock": "components/Clock.qml",
            "bluetooth": "components/Bluetooth.qml",
            "network": "components/Network.qml",
            "volume": "components/Volume.qml",
            "temp": "components/Temp.qml",
            "memory": "components/Memory.qml",
            "updates": "components/Updates.qml"
        })

    // ---- drag state -------------------------------------------------------
    property string dragAtomId: ""       // atom being dragged ("" = none)
    property var dragIslandIds: null      // whole island being dragged (null = none)
    readonly property bool dragActive: topBar.dragAtomId !== "" || topBar.dragIslandIds !== null
    property var dragGrab: null           // ItemGrabResult for the ghost image
    property real dragW: 0
    property real dragH: 0
    property point dragPos: Qt.point(0, 0)

    // Resolved drop target, recomputed as the pointer moves.
    property string dropRegion: ""
    property int dropKind: 0              // 0 none, 1 merge into island, 2 spawn at gap
    property string dropIslandFirstId: ""
    property string dropBeforeAtomId: ""

    function _containersFor(regionKey) {
        var rep = regionKey === "left" ? leftRepeater : rightRepeater;
        var arr = [];
        for (var i = 0; i < rep.count; i++) {
            var c = rep.itemAt(i);
            if (c)
                arr.push(c);
        }
        return arr;
    }

    // First island whose middle lies past px along the bar (insert before
    // it), or "" to append at the region's end.
    function _islandToInsertBefore(containers, px) {
        for (var i = 0; i < containers.length; i++) {
            var c = containers[i];
            if (px < topBar._pos(c) + topBar._len(c) / 2)
                return c.firstId;
        }
        return "";
    }

    // Within a target island, the atom to insert before, or "" to append.
    function _beforeAtomInIsland(container, px) {
        var rep = container.atomRep;
        for (var i = 0; i < rep.count; i++) {
            var slot = rep.itemAt(i);
            if (!slot)
                continue;
            if (px < topBar._pos(slot) + topBar._len(slot) / 2)
                return slot.atomId;
        }
        return "";
    }

    function beginAtomDrag(slot) {
        topBar.dragAtomId = slot.atomId;
        topBar.dragIslandIds = null;
        topBar.dragW = slot.width;
        topBar.dragH = slot.height;
        topBar.dragGrab = null;
        topBar._resetDropTarget();
        topBar.dragPos = slot.mapToItem(topBar, slot.width / 2, slot.height / 2);
        slot.grabToImage(function (result) {
            topBar.dragGrab = result;
        });
    }

    function beginIslandDrag(container) {
        topBar.dragIslandIds = container.atomIds.slice();
        topBar.dragAtomId = "";
        topBar.dragW = container.width;
        topBar.dragH = container.height;
        topBar.dragGrab = null;
        topBar._resetDropTarget();
        topBar.dragPos = container.mapToItem(topBar, container.width / 2, container.height / 2);
        container.grabToImage(function (result) {
            topBar.dragGrab = result;
        });
    }

    function _resetDropTarget() {
        topBar.dropKind = 0;
        topBar.dropRegion = "";
        topBar.dropIslandFirstId = "";
        topBar.dropBeforeAtomId = "";
    }

    function updateDrag(p) {
        topBar.dragPos = p;
        var a = topBar._along(p);
        var region = a < topBar._len(topBar) / 2 ? "left" : "right";
        topBar.dropRegion = region;
        var containers = topBar._containersFor(region);

        // Only atom drags may merge into another island; island drags reorder.
        if (topBar.dragAtomId !== "") {
            for (var i = 0; i < containers.length; i++) {
                var c = containers[i];
                var from = topBar._pos(c);
                if (a >= from && a <= from + topBar._len(c)) {
                    var solo = c.atomIds.length === 1 && c.atomIds[0] === topBar.dragAtomId;
                    if (!solo) {
                        topBar.dropKind = 1;
                        topBar.dropIslandFirstId = c.firstId;
                        topBar.dropBeforeAtomId = topBar._beforeAtomInIsland(c, a);
                        return;
                    }
                }
            }
        }

        topBar.dropKind = 2;
        topBar.dropBeforeAtomId = "";
        topBar.dropIslandFirstId = topBar._islandToInsertBefore(containers, a);
    }

    function endDrag() {
        if (topBar.dragAtomId !== "") {
            if (topBar.dropKind === 1)
                Services.BarLayout.moveAtomToIsland(topBar.dropRegion, topBar.dragAtomId, topBar.dropIslandFirstId, topBar.dropBeforeAtomId);
            else if (topBar.dropKind === 2)
                Services.BarLayout.spawnIsland(topBar.dropRegion, topBar.dragAtomId, topBar.dropIslandFirstId);
        } else if (topBar.dragIslandIds) {
            Services.BarLayout.moveIsland(topBar.dropRegion, topBar.dragIslandIds, topBar.dropIslandFirstId);
        }
        topBar.clearDrag();
    }

    // Ends a drag without dropping anything: after a drop, or when the press
    // went away without a release (the pointer left the surface).
    function clearDrag() {
        topBar.dragAtomId = "";
        topBar.dragIslandIds = null;
        topBar.dragGrab = null;
        topBar._resetDropTarget();
    }

    // ---- atom slot: one widget + its press-hold drag ---------------------
    component AtomSlot: Item {
        id: slot
        required property string regionKey
        required property string atomId
        required property string islandFirstId

        implicitWidth: atomLoader.implicitWidth
        implicitHeight: atomLoader.implicitHeight
        opacity: topBar.dragAtomId === slot.atomId ? 0.3 : 1

        Loader {
            id: atomLoader
            anchors.centerIn: parent
            source: Qt.resolvedUrl(topBar.atomSources[slot.atomId] || "")
            // Widgets show their upright face on a standing bar.
            onLoaded: if ("vertical" in item) item["vertical"] = Qt.binding(() => topBar.vertical)
        }

        // Drag capture modelled on the window switcher's working MouseArea: it
        // owns the press, starts a drag once the pointer moves past a small
        // threshold, and lets a plain click (no drag) fall through to the
        // widget's own MouseArea below via propagateComposedEvents.
        MouseArea {
            id: dragCapture
            anchors.fill: parent
            propagateComposedEvents: true

            property real pressX: 0
            property real pressY: 0
            property bool dragStarted: false

            onPressed: mouse => {
                dragCapture.pressX = mouse.x;
                dragCapture.pressY = mouse.y;
                dragCapture.dragStarted = false;
            }
            onPositionChanged: mouse => {
                if (!dragCapture.dragStarted && (Math.abs(mouse.x - dragCapture.pressX) > 8 || Math.abs(mouse.y - dragCapture.pressY) > 8)) {
                    dragCapture.dragStarted = true;
                    topBar.beginAtomDrag(slot);
                }
                if (dragCapture.dragStarted)
                    topBar.updateDrag(slot.mapToItem(topBar, mouse.x, mouse.y));
            }
            onReleased: mouse => {
                if (dragCapture.dragStarted)
                    topBar.endDrag();
                dragCapture.dragStarted = false;
            }
            onCanceled: {
                if (dragCapture.dragStarted)
                    topBar.clearDrag();
                dragCapture.dragStarted = false;
            }
            onClicked: mouse => {
                if (!dragCapture.dragStarted)
                    mouse.accepted = false;
            }
        }
    }

    // ---- island container: 1+ atoms, with grouping chrome for 2+ ---------
    component IslandContainer: Rectangle {
        id: island
        required property string regionKey
        required property var atomIds
        required property int islandIndex

        readonly property string firstId: island.atomIds.length > 0 ? island.atomIds[0] : ""
        readonly property bool grouped: island.atomIds.length > 1
        readonly property real pad: island.grouped ? 5 : 0
        property alias atomRep: atomRep

        readonly property bool isMergeTarget: topBar.dragActive && topBar.dropKind === 1 && topBar.dropRegion === island.regionKey && topBar.dropIslandFirstId === island.firstId
        readonly property bool isBeforeTarget: topBar.dragActive && topBar.dropKind === 2 && topBar.dropRegion === island.regionKey && topBar.dropIslandFirstId === island.firstId
        readonly property bool beingDragged: topBar.dragIslandIds !== null && topBar.dragIslandIds.indexOf(island.firstId) >= 0

        // Its atoms run along the bar; across it, it is islandHeight thick.
        implicitWidth: topBar.vertical ? topBar.islandHeight : atomRow.implicitWidth + 2 * island.pad
        implicitHeight: topBar.vertical ? atomRow.implicitHeight + 2 * island.pad : topBar.islandHeight
        // Desktop themes restyle the group chrome; the HUD, Neon Noir, Art
        // Deco and Cathedral themes' is a cut-corner frame drawn below the
        // atoms instead, Broadsheet rules it, Wasteland rivets it,
        // Observatory graduates its foot, Abyss lights it from below,
        // Devaloka stands it on a temple border and Siege cuts it into
        // battlements.
        readonly property var look: Services.DesktopTheme.look
        readonly property bool hud: look.shape === "chamfer"
        readonly property bool neon: look.shape === "neon"
        readonly property bool deco: look.shape === "deco"
        readonly property bool cusp: look.shape === "cusp"
        readonly property bool crenel: look.shape === "crenel"
        readonly property bool framed: hud || neon || deco || cusp || crenel
        radius: Services.DesktopTheme.radius(island.look, 16, Math.min(width, height))
        topLeftRadius: Services.DesktopTheme.corner(island.look, radius, 0)
        topRightRadius: Services.DesktopTheme.corner(island.look, radius, 1)
        bottomRightRadius: Services.DesktopTheme.corner(island.look, radius, 2)
        bottomLeftRadius: Services.DesktopTheme.corner(island.look, radius, 3)
        color: island.grouped && !island.framed ? Colors.surface_container_high : "transparent"
        border.width: island.framed ? 0 : island.isMergeTarget ? 2 : island.grouped && island.look.shape !== "print" ? island.look.border : 0
        border.color: island.isMergeTarget ? Services.DesktopTheme.accent : Services.DesktopTheme.borderColor(island.look)
        opacity: island.beingDragged ? 0.4 : 1

        // The chrome of a group (or of a drop target) in the theme's look,
        // built only for the theme in use and only while there's a group or
        // target to show: every theme's, hidden, came to half a dozen shapes
        // per island, re-traced whenever an island changed width.
        Loader {
            anchors.fill: parent
            active: island.grouped || island.isMergeTarget
            sourceComponent: ({
                chamfer: hudChrome,
                neon: neonChrome,
                deco: decoChrome,
                cusp: cuspChrome,
                crenel: crenelChrome,
                print: printChrome,
                plate: plateChrome,
                scale: scaleChrome,
                zari: zariChrome,
                lume: lumeChrome
            })[island.look.shape] ?? null
        }

        Component {
            id: hudChrome

            HudFrame {
                fill: island.grouped ? Colors.surface_container_high : "transparent"
                stroke: island.isMergeTarget ? Colors.primary : Colors.withAlpha(Colors.on_surface, 0.12)
                strokeWidth: island.isMergeTarget ? 2 : 1
                tick: island.grouped
            }
        }

        Component {
            id: neonChrome

            NeonFrame {
                cut: 10
                fill: island.grouped ? Colors.surface_container_high : "transparent"
                stroke: island.isMergeTarget ? Services.DesktopTheme.accent2Of("cyberpunk") : Services.DesktopTheme.accentOf("cyberpunk")
                strokeWidth: island.isMergeTarget ? 2 : 1
                glow: island.grouped ? 0.5 : 0
            }
        }

        Component {
            id: decoChrome

            DecoFrame {
                cut: 4
                steps: 2
                fill: island.grouped ? Colors.surface_container_high : "transparent"
                stroke: island.isMergeTarget ? Services.DesktopTheme.accent2Of("artdeco") : Services.DesktopTheme.borderColor(island.look)
                strokeWidth: island.isMergeTarget ? 2 : 1
            }
        }

        Component {
            id: cuspChrome

            CuspFrame {
                cut: 8
                fill: island.grouped ? Colors.surface_container_high : "transparent"
                stroke: island.isMergeTarget ? Services.DesktopTheme.accent2Of("gothic") : Services.DesktopTheme.borderColor(island.look)
                strokeWidth: island.isMergeTarget ? 2 : 1
            }
        }

        Component {
            id: crenelChrome

            CrenelFrame {
                merlon: 9
                depth: 4
                fill: island.grouped ? Colors.surface_container_high : "transparent"
                stroke: island.isMergeTarget ? Services.DesktopTheme.accent2Of("siege") : Services.DesktopTheme.borderColor(island.look)
                strokeWidth: island.isMergeTarget ? 2 : 1
            }
        }

        // Broadsheet: the group boxed between a heavy and a thin rule.
        Component {
            id: printChrome

            Item {
                visible: island.grouped

                Repeater {
                    model: [{ y: 0, h: 2 }, { y: island.height - 1, h: 1 }]

                    Rectangle {
                        required property var modelData
                        y: modelData.y
                        width: island.width
                        height: modelData.h
                        color: Services.DesktopTheme.borderColor(island.look)
                    }
                }
            }
        }

        // Wasteland: a plate bolted at the corners.
        Component {
            id: plateChrome

            Item {
                visible: island.grouped

                Repeater {
                    model: 4

                    Rivet {
                        required property int index
                        size: 3
                        x: index % 2 === 0 ? 2 : island.width - width - 2
                        y: index < 2 ? 2 : island.height - height - 2
                    }
                }
            }
        }

        // Observatory: the group graduated along its foot.
        Component {
            id: scaleChrome

            Item {
                visible: island.grouped

                ScaleTicks {
                    x: 8
                    y: island.height - height - 1
                    width: island.width - 16
                    height: 3
                    up: true
                    step: 5
                    major: 4
                    minorLength: 1.5
                    majorLength: 3
                    color: Services.DesktopTheme.borderColor(island.look)
                    opacity: 0.7
                }
            }
        }

        // Devaloka: a temple border along its foot.
        Component {
            id: zariChrome

            Item {
                visible: island.grouped

                TempleBorder {
                    x: island.radius
                    y: island.height - height - 1
                    width: island.width - 2 * island.radius
                    height: 3
                    step: 5
                    rule: 0
                    color: Services.DesktopTheme.borderColor(island.look)
                    opacity: 0.8
                }
            }
        }

        // Abyss: lit along its foot.
        Component {
            id: lumeChrome

            Item {
                visible: island.grouped

                Rectangle {
                    x: island.radius
                    y: island.height - 2
                    width: island.width - 2 * island.radius
                    height: 1
                    color: Colors.withAlpha(Services.DesktopTheme.accent2, 0.7)
                }
            }
        }

        // Insertion caret shown just before this island: left of it, or above
        // it on a standing bar.
        Rectangle {
            visible: island.isBeforeTarget
            width: topBar.vertical ? 22 : 3
            height: topBar.vertical ? 3 : 22
            radius: 1.5
            color: Services.DesktopTheme.accent
            x: topBar.vertical ? (island.width - width) / 2 : -width - 3
            y: topBar.vertical ? -height - 3 : (island.height - height) / 2
        }

        // Whole-island drag from the group's padding/gaps (grouped only). It
        // sits BELOW the atoms, so a press on an atom goes to that atom, while a
        // press on the surrounding frame or an inter-atom gap drags the group.
        // Same threshold mechanism as the atom capture above.
        MouseArea {
            id: groupCapture
            anchors.fill: parent
            enabled: island.grouped

            property real pressX: 0
            property real pressY: 0
            property bool dragStarted: false

            onPressed: mouse => {
                groupCapture.pressX = mouse.x;
                groupCapture.pressY = mouse.y;
                groupCapture.dragStarted = false;
            }
            onPositionChanged: mouse => {
                if (!groupCapture.dragStarted && (Math.abs(mouse.x - groupCapture.pressX) > 8 || Math.abs(mouse.y - groupCapture.pressY) > 8)) {
                    groupCapture.dragStarted = true;
                    topBar.beginIslandDrag(island);
                }
                if (groupCapture.dragStarted)
                    topBar.updateDrag(island.mapToItem(topBar, mouse.x, mouse.y));
            }
            onReleased: mouse => {
                if (groupCapture.dragStarted)
                    topBar.endDrag();
                groupCapture.dragStarted = false;
            }
            onCanceled: {
                if (groupCapture.dragStarted)
                    topBar.clearDrag();
                groupCapture.dragStarted = false;
            }
        }

        // The atoms, in a row, or a column on a standing bar. (Only columns
        // is set: switching rows and columns over would pass through a
        // 1x1 grid.)
        Grid {
            id: atomRow
            anchors.centerIn: parent
            columns: topBar.vertical ? 1 : Math.max(1, atomRep.count)
            spacing: island.grouped ? 4 : 0
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter
            Repeater {
                id: atomRep
                model: island.atomIds
                AtomSlot {
                    required property var modelData
                    regionKey: island.regionKey
                    atomId: modelData
                    islandFirstId: island.firstId
                }
            }
        }
    }

    // ---- bar content ------------------------------------------------------
    Item {
        id: content
        anchors.fill: parent

        // Declared first, so it passes behind the islands as it crosses. The
        // pet walks along the bar: on a standing bar its track is turned on
        // its side, head to the screen edge, so its x runs up a left bar and
        // down a right one.
        Item {
            id: petTrack

            readonly property bool upward: topBar.vertical && Services.BarLayout.atLeft

            width: topBar.vertical ? content.height : content.width
            height: topBar.vertical ? content.width : content.height
            transformOrigin: Item.TopLeft
            rotation: !topBar.vertical ? 0 : petTrack.upward ? -90 : 90
            x: topBar.vertical && !petTrack.upward ? content.width : 0
            y: petTrack.upward ? content.height : 0

            BarPet {
                anchors.fill: parent
                reversed: petTrack.upward
                gaps: {
                    const pad = 8;
                    const v = topBar.vertical;
                    const l = (v ? leftRow.y + leftRow.height : leftRow.x + leftRow.width) + pad;
                    const r = (v ? rightRow.y : rightRow.x) - pad;
                    const m0 = (v ? mediaPill.y : mediaPill.x) - pad;
                    const m1 = (v ? mediaPill.y + mediaPill.height : mediaPill.x + mediaPill.width) + pad;
                    const spans = mediaPill.visible ? [[l, m0], [m1, r]] : [[l, r]];
                    if (!petTrack.upward)
                        return spans;
                    // Up the bar, its x counts from the bottom.
                    const n = petTrack.width;
                    return spans.map(s => [n - s[1], n - s[0]]).reverse();
                }
            }
        }

        // The start region: from the left end, or from the top. (Placed by
        // x/y, not anchors: anchors swapped by bindings are briefly both
        // set, and a left anchor with a horizontalCenter one fixes the width
        // for good.)
        Grid {
            id: leftRow
            x: topBar.vertical ? (parent.width - width) / 2 : 20
            y: topBar.vertical ? 20 : (parent.height - height) / 2
            // One column standing, else one per item shown (see atomRow).
            columns: topBar.vertical ? 1 : Math.max(1, leftRepeater.count + (leftCaret.visible ? 1 : 0))
            spacing: 8
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            Repeater {
                id: leftRepeater
                model: Services.BarLayout.left
                IslandContainer {
                    required property var modelData
                    required property int index
                    regionKey: "left"
                    atomIds: modelData
                    islandIndex: index
                }
            }

            // Append caret for the left region.
            Rectangle {
                id: leftCaret
                visible: topBar.dragActive && topBar.dropKind === 2 && topBar.dropRegion === "left" && topBar.dropIslandFirstId === ""
                width: topBar.vertical ? 22 : 3
                height: topBar.vertical ? 3 : 22
                radius: 1.5
                color: Colors.primary
            }
        }

        MediaPill {
            id: mediaPill
            anchors.centerIn: parent
        }

        // The end region, up to the tray: to the right end, or the bottom.
        Grid {
            id: rightRow
            x: topBar.vertical ? (parent.width - width) / 2 : parent.width - width - 20
            y: topBar.vertical ? parent.height - height - 20 : (parent.height - height) / 2
            columns: topBar.vertical ? 1 : Math.max(1, rightRepeater.count + (rightCaret.visible ? 1 : 0) + (tray.visible ? 1 : 0))
            spacing: 8
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            Repeater {
                id: rightRepeater
                model: Services.BarLayout.right
                IslandContainer {
                    required property var modelData
                    required property int index
                    regionKey: "right"
                    atomIds: modelData
                    islandIndex: index
                }
            }

            // Append caret for the right region (before the tray).
            Rectangle {
                id: rightCaret
                visible: topBar.dragActive && topBar.dropKind === 2 && topBar.dropRegion === "right" && topBar.dropIslandFirstId === ""
                width: topBar.vertical ? 22 : 3
                height: topBar.vertical ? 3 : 22
                radius: 1.5
                color: Colors.primary
            }

            SystemTray {
                id: tray
                vertical: topBar.vertical
            }
        }
    }

    // ---- drag ghost overlay ----------------------------------------------
    // It follows the pointer along the bar and is kept inside the bar's
    // strip across it: the bar is its own 42px surface.
    Item {
        id: ghostLayer

        readonly property real ghostX: topBar.vertical
            ? Math.max(0, Math.min(topBar.width - topBar.dragW, topBar.dragPos.x - topBar.dragW / 2))
            : topBar.dragPos.x - topBar.dragW / 2
        readonly property real ghostY: topBar.vertical
            ? topBar.dragPos.y - topBar.dragH / 2
            : Math.max(0, Math.min(topBar.height - topBar.dragH, topBar.dragPos.y - topBar.dragH / 2))

        anchors.fill: parent
        z: 1000
        visible: topBar.dragActive

        Rectangle {
            // Placeholder until the grabbed image is ready.
            visible: topBar.dragActive && (!topBar.dragGrab || ghost.status !== Image.Ready)
            x: ghostLayer.ghostX
            y: ghostLayer.ghostY
            width: topBar.dragW
            height: topBar.dragH
            radius: 14
            color: Colors.surface_container
            opacity: 0.85
        }

        Image {
            id: ghost
            visible: topBar.dragActive && topBar.dragGrab && status === Image.Ready
            source: topBar.dragGrab ? topBar.dragGrab.url : ""
            x: ghostLayer.ghostX
            y: ghostLayer.ghostY
            width: topBar.dragW
            height: topBar.dragH
            opacity: 0.9
        }
    }
}
