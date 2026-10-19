// SPDX-License-Identifier: GPL-3.0-or-later
//
// Derived from zesis-shell's widgets/bar/BarItemsService.qml.
// Copyright (C) 2026 Squirrel Modeller (zesis-shell)
//   https://github.com/zesis-shell/zesis
// Modifications copyright (C) 2026 dhrruvsharma.
//
// Licensed under the GNU General Public License, version 3 or (at your
// option) any later version. See LICENSE in the repository root.

pragma Singleton
import QtQuick
import QtCore

// Ordered island layout for the two draggable regions of the bar.
//
// `left`/`right` are arrays of "islands"; each island is an array of atom ids
// (widget ids). A solo island renders as a lone pill; a 2+ island renders
// inside a subtle grouping container ("nested pills"). The center media pill
// and the end system tray are fixed and deliberately NOT part of this model,
// so they can never be dragged or displaced. On a standing bar (left or
// right edge) "left" is the top region and "right" the bottom one.
//
// Persisted to a dedicated barlayout.conf so it never touches shared settings,
// along with the screen edge the bar sits on.
QtObject {
    id: root

    // The widgets that may be rearranged. Anything else is dropped on load,
    // and any of these missing from the saved layout is re-appended so a newly
    // added widget still shows up instead of silently vanishing. Each also
    // has an entry in BarSettings.widgets (its file, and what the settings
    // panel calls it); hidden ones keep their place here.
    readonly property var knownIds: [
        "cpu", "battery", "clock", "bluetooth",
        "network", "volume", "temp", "memory", "updates", "settings"
    ]

    readonly property var defaultLeft: [["cpu"], ["battery"], ["clock"], ["bluetooth"]]
    readonly property var defaultRight: [["updates"], ["network"], ["volume"], ["temp"], ["memory"], ["settings"]]

    property var left: root.defaultLeft
    property var right: root.defaultRight

    // Which screen edge the bar sits on: "top", "bottom", "left" or "right"
    // (drag the bar by an empty stretch to another edge, or setEdge()).
    // Panels that hang from the bar hang from that edge, and what lives on
    // the other edges (the hover strips, the GitHub popout, the workspace
    // disc) keeps clear of the bar.
    readonly property var edges: ["top", "bottom", "left", "right"]
    readonly property string edge: root.edges.includes(store.edge) ? store.edge : "top"
    readonly property bool atTop: root.edge === "top"
    readonly property bool atBottom: root.edge === "bottom"
    readonly property bool atLeft: root.edge === "left"
    readonly property bool atRight: root.edge === "right"
    // On the left or right edge the bar stands on end: its islands stack
    // and the widgets show a compact, upright face.
    readonly property bool vertical: root.atLeft || root.atRight
    // The bar's thickness, and the room it takes on its edge (none on the
    // others).
    readonly property int size: 42
    readonly property int reserveTop: root.atTop ? root.size : 0
    readonly property int reserveBottom: root.atBottom ? root.size : 0
    readonly property int reserveLeft: root.atLeft ? root.size : 0
    readonly property int reserveRight: root.atRight ? root.size : 0
    // The room the desktop theme's frames leave it, a hair more.
    readonly property int clearTop: root.atTop ? root.size + 2 : 0
    readonly property int clearBottom: root.atBottom ? root.size + 2 : 0
    readonly property int clearLeft: root.atLeft ? root.size + 2 : 0
    readonly property int clearRight: root.atRight ? root.size + 2 : 0
    // Popout (components/Popout) alignments for panels hanging from the
    // bar: from its middle (media, system), and from its far end (updates):
    // the right end of a lying bar, the bottom end of a standing one.
    readonly property int middleAlignment: ({ top: 0, right: 2, bottom: 4, left: 6 })[root.edge]
    readonly property int endAlignment: ({ top: 1, right: 3, bottom: 3, left: 5 })[root.edge]

    function setEdge(e) {
        if (root.edges.includes(e))
            store.edge = e
    }

    function opposite(e) {
        return ({ top: "bottom", bottom: "top", left: "right", right: "left" })[e] ?? "top"
    }

    // Where a point of `item` (an item in the bar) lies along the bar, in
    // screen pixels: x on a lying bar, y on a standing one. The bar's
    // surface starts at the screen's left or top edge either way.
    function along(item, x, y) {
        const p = item.mapToItem(null, x, y)
        return root.vertical ? p.y : p.x
    }

    property Settings store: Settings {
        location: StandardPaths.standardLocations(StandardPaths.ConfigLocation)[0] + "/quickshell/barlayout.conf"
        category: "barlayout"
        property string data: ""
        property string edge: "top"
    }

    // ---- persistence ------------------------------------------------------

    function load() {
        var parsed = null
        try {
            if (store.data && store.data.length > 0)
                parsed = JSON.parse(store.data)
        } catch (e) {
            console.warn("BarLayout: failed to parse saved layout:", e)
            parsed = null
        }

        var seen = ({})
        var rawLeft = (parsed && Array.isArray(parsed.left)) ? parsed.left : root.defaultLeft
        var rawRight = (parsed && Array.isArray(parsed.right)) ? parsed.right : root.defaultRight

        var cleanLeft = root._sanitize(rawLeft, seen)
        var cleanRight = root._sanitize(rawRight, seen)

        // Re-append any known widget that wasn't present, as its own island.
        for (var i = 0; i < root.knownIds.length; i++) {
            var id = root.knownIds[i]
            if (!seen[id]) {
                cleanRight.push([id])
                seen[id] = true
            }
        }

        root.left = cleanLeft
        root.right = cleanRight
    }

    function save() {
        store.data = JSON.stringify({ left: root.left, right: root.right })
    }

    // Drop unknown/duplicate ids and prune emptied islands.
    function _sanitize(region, seen) {
        var out = []
        if (!Array.isArray(region))
            return out
        for (var i = 0; i < region.length; i++) {
            var island = region[i]
            if (!Array.isArray(island))
                continue
            var filtered = []
            for (var j = 0; j < island.length; j++) {
                var id = island[j]
                if (root.knownIds.indexOf(id) >= 0 && !seen[id]) {
                    filtered.push(id)
                    seen[id] = true
                }
            }
            if (filtered.length > 0)
                out.push(filtered)
        }
        return out
    }

    // ---- mutation helpers -------------------------------------------------

    function _clone(region) {
        var out = []
        for (var i = 0; i < region.length; i++)
            out.push(region[i].slice())
        return out
    }

    function _snapshot() {
        return { left: root._clone(root.left), right: root._clone(root.right) }
    }

    function _commit(s) {
        root.left = s.left
        root.right = s.right
        root.save()
    }

    function _regionByKey(s, key) {
        return key === "left" ? s.left : s.right
    }

    // Remove id from whichever region/island holds it, pruning an emptied island.
    function _removeAtom(s, id) {
        var regions = [s.left, s.right]
        for (var r = 0; r < regions.length; r++) {
            var region = regions[r]
            for (var i = 0; i < region.length; i++) {
                var idx = region[i].indexOf(id)
                if (idx >= 0) {
                    region[i].splice(idx, 1)
                    if (region[i].length === 0)
                        region.splice(i, 1)
                    return
                }
            }
        }
    }

    function _islandIndexByMember(region, memberId) {
        for (var i = 0; i < region.length; i++)
            if (region[i].indexOf(memberId) >= 0)
                return i
        return -1
    }

    // Merge id into the existing island anchored by targetIslandFirstId, before
    // beforeId (or appended when beforeId is ""). The "drop inside another
    // island" case. Anchors are member ids, not indices, so they stay valid
    // even after the source removal reshuffles the region.
    function moveAtomToIsland(regionKey, id, targetIslandFirstId, beforeId) {
        if (!id || id === targetIslandFirstId)
            return
        var s = root._snapshot()
        root._removeAtom(s, id)
        var region = root._regionByKey(s, regionKey)
        var ti = root._islandIndexByMember(region, targetIslandFirstId)
        if (ti < 0) {
            // Target vanished (e.g. it was id's own solo island). Fall back to
            // a solo island at the end so the atom is never lost.
            region.push([id])
            root._commit(s)
            return
        }
        var island = region[ti]
        var at = (beforeId && beforeId !== id) ? island.indexOf(beforeId) : -1
        island.splice(at < 0 ? island.length : at, 0, id)
        root._commit(s)
    }

    // Move id out to its own island in regionKey, before the island anchored by
    // beforeIslandFirstId (or appended when "").
    function spawnIsland(regionKey, id, beforeIslandFirstId) {
        if (!id)
            return
        var s = root._snapshot()
        root._removeAtom(s, id)
        var region = root._regionByKey(s, regionKey)
        var at = beforeIslandFirstId ? root._islandIndexByMember(region, beforeIslandFirstId) : -1
        region.splice(at < 0 ? region.length : at, 0, [id])
        root._commit(s)
    }

    // Move a whole island (identified by any current member) into regionKey,
    // before the island anchored by beforeIslandFirstId (or appended when "").
    function moveIsland(regionKey, islandIds, beforeIslandFirstId) {
        if (!islandIds || islandIds.length === 0)
            return
        // Dropping a group onto itself is a no-op.
        if (beforeIslandFirstId && islandIds.indexOf(beforeIslandFirstId) >= 0)
            return
        var s = root._snapshot()
        var anchor = islandIds[0]
        var moving = null
        var regions = [s.left, s.right]
        for (var r = 0; r < regions.length && !moving; r++) {
            var region = regions[r]
            var fi = root._islandIndexByMember(region, anchor)
            if (fi >= 0)
                moving = region.splice(fi, 1)[0]
        }
        if (!moving)
            return
        var target = root._regionByKey(s, regionKey)
        var at = beforeIslandFirstId ? root._islandIndexByMember(target, beforeIslandFirstId) : -1
        target.splice(at < 0 ? target.length : at, 0, moving)
        root._commit(s)
    }

    function reset() {
        root.left = root._clone(root.defaultLeft)
        root.right = root._clone(root.defaultRight)
        root.save()
    }

    Component.onCompleted: root.load()
}
