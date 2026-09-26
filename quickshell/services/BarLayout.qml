pragma Singleton
import QtQuick
import QtCore

// Ordered island layout for the two draggable regions of the top bar.
//
// `left`/`right` are arrays of "islands"; each island is an array of atom ids
// (widget ids). A solo island renders as a lone pill; a 2+ island renders
// inside a subtle grouping container ("nested pills"). The center media pill
// and the right-edge system tray are fixed and deliberately NOT part of this
// model, so they can never be dragged or displaced.
//
// Persisted to a dedicated barlayout.conf so it never touches shared settings.
QtObject {
    id: root

    // The widgets that may be rearranged. Anything else is dropped on load,
    // and any of these missing from the saved layout is re-appended so a newly
    // added widget still shows up instead of silently vanishing.
    readonly property var knownIds: [
        "cpu", "battery", "clock", "bluetooth",
        "network", "volume", "temp", "memory", "updates"
    ]

    readonly property var defaultLeft: [["cpu"], ["battery"], ["clock"], ["bluetooth"]]
    readonly property var defaultRight: [["updates"], ["network"], ["volume"], ["temp"], ["memory"]]

    property var left: root.defaultLeft
    property var right: root.defaultRight

    property Settings store: Settings {
        location: StandardPaths.standardLocations(StandardPaths.ConfigLocation)[0] + "/quickshell/barlayout.conf"
        category: "barlayout"
        property string data: ""
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
