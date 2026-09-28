import QtQuick
import qs.modules.bar.components
import qs.modules.pet
import qs.services as Services
import qs.colors
import qs.components

// Top bar with drag-rearrangeable "islands". Every draggable widget is an atom
// living in an island (a group of 1+ atoms sharing a pill/tray). Islands live in
// two ordered regions, left and right, driven by the BarLayout service. The
// center media pill and the right-edge system tray are fixed and never move.
// The pet (modules/pet) lives in the free stretches between them.
Item {
    id: topBar

    implicitHeight: 42
    anchors.left: parent.left
    anchors.right: parent.right
    focus: true

    readonly property real islandHeight: 34

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

    // First island whose horizontal center is right of px (insert before it), or
    // "" to append at the region's end.
    function _islandToInsertBefore(containers, px) {
        for (var i = 0; i < containers.length; i++) {
            var c = containers[i];
            var tl = c.mapToItem(topBar, 0, 0);
            if (px < tl.x + c.width / 2)
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
            var tl = slot.mapToItem(topBar, 0, 0);
            if (px < tl.x + slot.width / 2)
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
        var region = p.x < topBar.width / 2 ? "left" : "right";
        topBar.dropRegion = region;
        var containers = topBar._containersFor(region);

        // Only atom drags may merge into another island; island drags reorder.
        if (topBar.dragAtomId !== "") {
            for (var i = 0; i < containers.length; i++) {
                var c = containers[i];
                var tl = c.mapToItem(topBar, 0, 0);
                if (p.x >= tl.x && p.x <= tl.x + c.width) {
                    var solo = c.atomIds.length === 1 && c.atomIds[0] === topBar.dragAtomId;
                    if (!solo) {
                        topBar.dropKind = 1;
                        topBar.dropIslandFirstId = c.firstId;
                        topBar.dropBeforeAtomId = topBar._beforeAtomInIsland(c, p.x);
                        return;
                    }
                }
            }
        }

        topBar.dropKind = 2;
        topBar.dropBeforeAtomId = "";
        topBar.dropIslandFirstId = topBar._islandToInsertBefore(containers, p.x);
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
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        opacity: topBar.dragAtomId === slot.atomId ? 0.3 : 1

        Loader {
            id: atomLoader
            anchors.centerIn: parent
            source: Qt.resolvedUrl(topBar.atomSources[slot.atomId] || "")
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

        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        implicitWidth: atomRow.implicitWidth + 2 * island.pad
        implicitHeight: topBar.islandHeight
        // Desktop themes restyle the group chrome; the HUD, Neon Noir, Art
        // Deco and Cathedral themes' is a cut-corner frame drawn below the
        // atoms instead, Broadsheet rules it and Wasteland rivets it.
        readonly property var look: Services.DesktopTheme.look
        readonly property bool hud: look.shape === "chamfer"
        readonly property bool neon: look.shape === "neon"
        readonly property bool deco: look.shape === "deco"
        readonly property bool cusp: look.shape === "cusp"
        readonly property bool framed: hud || neon || deco || cusp
        radius: Services.DesktopTheme.radius(island.look, 16, height)
        topLeftRadius: Services.DesktopTheme.corner(island.look, radius, 0)
        topRightRadius: Services.DesktopTheme.corner(island.look, radius, 1)
        bottomRightRadius: Services.DesktopTheme.corner(island.look, radius, 2)
        bottomLeftRadius: Services.DesktopTheme.corner(island.look, radius, 3)
        color: island.grouped && !island.framed ? Colors.surface_container_high : "transparent"
        border.width: island.framed ? 0 : island.isMergeTarget ? 2 : island.grouped && island.look.shape !== "print" ? island.look.border : 0
        border.color: island.isMergeTarget ? Services.DesktopTheme.accent : Services.DesktopTheme.borderColor(island.look)
        opacity: island.beingDragged ? 0.4 : 1

        HudFrame {
            visible: island.hud && (island.grouped || island.isMergeTarget)
            fill: island.grouped ? Colors.surface_container_high : "transparent"
            stroke: island.isMergeTarget ? Colors.primary : Colors.withAlpha(Colors.on_surface, 0.12)
            strokeWidth: island.isMergeTarget ? 2 : 1
            tick: island.grouped
        }

        NeonFrame {
            visible: island.neon && (island.grouped || island.isMergeTarget)
            cut: 10
            fill: island.grouped ? Colors.surface_container_high : "transparent"
            stroke: island.isMergeTarget ? Services.DesktopTheme.accent2Of("cyberpunk") : Services.DesktopTheme.accentOf("cyberpunk")
            strokeWidth: island.isMergeTarget ? 2 : 1
            glow: island.grouped ? 0.5 : 0
        }

        DecoFrame {
            visible: island.deco && (island.grouped || island.isMergeTarget)
            cut: 4
            steps: 2
            fill: island.grouped ? Colors.surface_container_high : "transparent"
            stroke: island.isMergeTarget ? Services.DesktopTheme.accent2Of("artdeco") : Services.DesktopTheme.borderColor(island.look)
            strokeWidth: island.isMergeTarget ? 2 : 1
        }

        CuspFrame {
            visible: island.cusp && (island.grouped || island.isMergeTarget)
            cut: 8
            fill: island.grouped ? Colors.surface_container_high : "transparent"
            stroke: island.isMergeTarget ? Services.DesktopTheme.accent2Of("gothic") : Services.DesktopTheme.borderColor(island.look)
            strokeWidth: island.isMergeTarget ? 2 : 1
        }

        // Broadsheet: the group boxed between a heavy and a thin rule.
        Repeater {
            model: island.look.shape === "print" && island.grouped ? [{ y: 0, h: 2 }, { y: island.height - 1, h: 1 }] : []

            Rectangle {
                required property var modelData
                y: modelData.y
                width: island.width
                height: modelData.h
                color: Services.DesktopTheme.borderColor(island.look)
            }
        }

        // Wasteland: a plate bolted at the corners.
        Repeater {
            model: island.look.shape === "plate" && island.grouped ? 4 : 0

            Rivet {
                required property int index
                size: 3
                x: index % 2 === 0 ? 2 : island.width - width - 2
                y: index < 2 ? 2 : island.height - height - 2
            }
        }

        // Insertion caret shown just left of this island.
        Rectangle {
            visible: island.isBeforeTarget
            width: 3
            radius: 1.5
            height: 22
            color: Services.DesktopTheme.accent
            anchors.right: parent.left
            anchors.rightMargin: 3
            anchors.verticalCenter: parent.verticalCenter
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
        }

        Row {
            id: atomRow
            anchors.centerIn: parent
            spacing: island.grouped ? 4 : 0
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
        anchors.fill: parent

        // Declared first, so it passes behind the islands as it crosses.
        BarPet {
            anchors.fill: parent
            gaps: {
                const pad = 8;
                const l = leftRow.x + leftRow.width + pad;
                const r = rightRow.x - pad;
                if (!mediaPill.visible)
                    return [[l, r]];
                return [[l, mediaPill.x - pad], [mediaPill.x + mediaPill.width + pad, r]];
            }
        }

        Row {
            id: leftRow
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

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
                visible: topBar.dragActive && topBar.dropKind === 2 && topBar.dropRegion === "left" && topBar.dropIslandFirstId === ""
                width: 3
                radius: 1.5
                height: 22
                color: Colors.primary
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MediaPill {
            id: mediaPill
            anchors.centerIn: parent
        }

        Row {
            id: rightRow
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

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
                visible: topBar.dragActive && topBar.dropKind === 2 && topBar.dropRegion === "right" && topBar.dropIslandFirstId === ""
                width: 3
                radius: 1.5
                height: 22
                color: Colors.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            SystemTray {
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ---- drag ghost overlay ----------------------------------------------
    Item {
        anchors.fill: parent
        z: 1000
        visible: topBar.dragActive

        Rectangle {
            // Placeholder until the grabbed image is ready.
            visible: topBar.dragActive && (!topBar.dragGrab || ghost.status !== Image.Ready)
            x: topBar.dragPos.x - width / 2
            // Kept inside the bar strip: the bar is its own 42px surface.
            y: Math.max(0, Math.min(topBar.height - height, topBar.dragPos.y - height / 2))
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
            x: topBar.dragPos.x - width / 2
            // Kept inside the bar strip: the bar is its own 42px surface.
            y: Math.max(0, Math.min(topBar.height - height, topBar.dragPos.y - height / 2))
            width: topBar.dragW
            height: topBar.dragH
            opacity: 0.9
        }
    }
}
