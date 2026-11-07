pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// The edge line (modules/edgeline): a thin line on one of the screen's
// borders, dragged to wherever along any of them it should live. A click
// opens it out into one popout: a strip along the border (the workspaces,
// the time, its tabs, the launcher and power) and the tab that's chosen,
// its panels laid out together like a collage, all of them open at once.
// Once it's left it folds back into the line.
//
// The panels are fixed (`panels`); how they're grouped into tabs is yours
// (`tabs`, set in the customizer's book, chapter IX): each panel in one tab
// at most (or left out), five to a tab at most. How a tab's panels sit
// together is worked out once from their usual sizes, or arranged by hand
// in the popout (`arranging`: carried onto another's edge) and kept with
// the tab (`layout`).
//
// Minimal mode puts the rest of the shell away (the bar, the workspace
// disc, the desktop widgets and the visualizer) and leaves the line to do
// all of it.
//
// Settings: ~/.config/quickshell/edgeline.json.
Singleton {
    id: root

    readonly property var edges: ["top", "bottom", "left", "right"]

    // Every panel there is, in its usual order.
    readonly property var panels: [
        { id: "workspaces", name: "Workspaces", icon: "grid_view", blurb: "a card for each workspace and its windows" },
        { id: "calendar", name: "Calendar", icon: "calendar_month", blurb: "the time, the day and the month" },
        { id: "media", name: "Media", icon: "music_note", blurb: "what's playing (while something is)" },
        { id: "wifi", name: "Wi-Fi", icon: "wifi", blurb: "networks around, wired and tethered links" },
        { id: "bluetooth", name: "Bluetooth", icon: "bluetooth", blurb: "paired devices and their battery" },
        { id: "dns", name: "DNS", icon: "dns", blurb: "who answers your lookups: the network, AdGuard, your own", near: "wifi" },
        { id: "vpn", name: "VPN", icon: "vpn_lock", blurb: "WireGuard tunnels: import one, connect, and whether it answers", near: "wifi" },
        { id: "sound", name: "Sound", icon: "volume_up", blurb: "volume and outputs, brightness, night light" },
        { id: "system", name: "System", icon: "monitor_heart", blurb: "the machine, and the ways into the shell" },
        { id: "notes", name: "Notes", icon: "sticky_note_2", blurb: "the notepad's notes, written in here" },
        { id: "notifications", name: "Notifications", icon: "notifications", blurb: "the list, and do not disturb" },
        { id: "tray", name: "Tray", icon: "widgets", blurb: "the tray's apps and their menus" },
        { id: "commands", name: "Commands", icon: "terminal", blurb: "the shell's IPC commands you pin, a click to run", near: "system" }
    ]
    readonly property var panelIds: root.panels.map(p => p.id)
    readonly property int maxPerTab: 5
    readonly property int maxTabs: 8
    // What a tab can wear.
    readonly property var tabIcons: ["dashboard", "home", "wifi", "music_note", "monitor_heart", "edit_note", "inbox", "today", "tune", "bolt", "star", "apps", "headphones", "terminal", "favorite", "explore"]

    readonly property var defaultTabs: [
        { name: "Overview", icon: "dashboard", panels: ["workspaces", "calendar", "notifications"] },
        { name: "Connect", icon: "wifi", panels: ["wifi", "bluetooth", "dns", "vpn"] },
        { name: "Listen", icon: "music_note", panels: ["media", "sound"] },
        { name: "System", icon: "monitor_heart", panels: ["system", "tray", "commands"] },
        { name: "Notes", icon: "edit_note", panels: ["notes"] }
    ]

    // A panel's content size before it's been built and measured (w × h).
    readonly property var panelGuess: ({
            workspaces: [316, 176],
            calendar: [296, 330],
            media: [316, 176],
            wifi: [304, 330],
            bluetooth: [296, 196],
            dns: [304, 400],
            vpn: [304, 200],
            sound: [316, 124],
            system: [316, 290],
            notes: [300, 200],
            notifications: [336, 300],
            tray: [244, 96],
            commands: [316, 250]
        })
    // As measured in the popout (not kept): the customizer draws with these.
    property var panelSizes: ({})

    function panelSize(id) {
        return root.panelSizes[id] ?? root.panelGuess[id] ?? [300, 200];
    }

    function reportSize(id, w, h) {
        const old = root.panelSizes[id];
        if (old && old[0] === w && old[1] === h)
            return;
        const next = Object.assign({}, root.panelSizes);
        next[id] = [w, h];
        root.panelSizes = next;
    }

    readonly property bool enabled: adapter.enabled
    readonly property bool minimal: adapter.enabled && adapter.minimal
    readonly property string edge: root.edges.includes(adapter.edge) ? adapter.edge : "bottom"
    // The line's middle along its border, 0 (left/top end) to 1.
    readonly property real pos: Math.max(0, Math.min(1, Number(adapter.pos)))
    readonly property bool horizontal: root.edge === "top" || root.edge === "bottom"
    // The line's length at rest, in px.
    readonly property int length: Math.round(Math.max(48, Math.min(480, adapter.length)))
    // Swell into a little pill (the time, what's on) while the pointer
    // rests on it.
    readonly property bool peek: adapter.peek
    // Fold back into the line once the pointer has been off it this long
    // (unless something in it is being typed into).
    readonly property bool closeOnLeave: adapter.closeOnLeave
    readonly property int closeDelay: Math.max(200, Math.min(5000, adapter.closeDelay))

    // The tabs as set: [{ name, icon, panels: [ids] }], tidied.
    readonly property var tabs: root.tidy(adapter.tabs)
    readonly property var leftOut: root.panelIds.filter(p => !root.tabs.some(t => t.panels.includes(p)))
    // The tab it opens on (the one it was left on).
    readonly property int activeTab: Math.max(0, Math.min(root.tabs.length - 1, adapter.activeTab))

    // Opened out.
    property bool open: false
    // (arranging ends as it folds up, however it does)
    onOpenChanged: {
        if (!root.open)
            root.arranging = false;
    }
    // Being dragged to another place on the borders.
    property bool dragging: false

    // Something that lives elsewhere in the shell (shell.qml opens it):
    // launcher, power, controlCenter, wallpaper, themes, customizer,
    // clipboard, keybinds, notepad, network, bluetooth, updates.
    signal requested(string what)

    function panel(id) {
        return root.panels.find(p => p.id === id) ?? null;
    }

    function tabOf(panelId) {
        return root.tabs.findIndex(t => t.panels.includes(panelId));
    }

    // A list as a JS array: lists read back from the settings file are
    // array-like, not arrays. null when it's no list at all.
    function _list(v) {
        if (Array.isArray(v))
            return v;
        if (v && typeof v === "object" && typeof v.length === "number")
            return Array.from(v);
        return null;
    }

    // Each panel once, known ones only, five to a tab, no empty tabs.
    function tidy(raw) {
        const seen = {};
        const out = [];
        for (const t of root._list(raw) ?? root.defaultTabs) {
            if (!t || out.length >= root.maxTabs)
                continue;
            const ps = (root._list(t.panels) ?? []).filter(p => root.panelIds.includes(p) && !seen[p]).slice(0, root.maxPerTab);
            ps.forEach(p => seen[p] = true);
            if (ps.length === 0)
                continue;
            const first = root.panel(ps[0]);
            const tab = {
                name: String(t.name ?? "").trim().slice(0, 24) || first.name,
                icon: String(t.icon ?? "") || first.icon,
                panels: ps
            };
            // (one panel has nothing to arrange)
            const shape = ps.length > 1 ? root._fit(t.layout, ps) : null;
            if (shape !== null)
                tab.layout = shape;
            out.push(tab);
        }
        return out;
    }

    function _copy() {
        return root.tabs.map(t => {
            const c = { name: t.name, icon: t.icon, panels: t.panels.slice() };
            if (t.layout !== undefined)
                c.layout = JSON.parse(JSON.stringify(t.layout));
            return c;
        });
    }

    function _commit(next, active) {
        adapter.tabs = root.tidy(next);
        if (active !== undefined)
            adapter.activeTab = Math.max(0, active);
    }

    // Puts a panel into tab `to` at `at` (its end if left out), from
    // wherever it was. False when that tab is full.
    function movePanel(id, to, at) {
        const next = root._copy();
        const target = next[to];
        if (!target || !root.panelIds.includes(id))
            return false;
        const from = next.findIndex(t => t.panels.includes(id));
        if (from !== to && target.panels.length >= root.maxPerTab)
            return false;
        if (from >= 0) {
            const i = next[from].panels.indexOf(id);
            next[from].panels.splice(i, 1);
            if (from === to && at !== undefined && at > i)
                at--;
        }
        const n = target.panels.length;
        target.panels.splice(Math.max(0, Math.min(n, at === undefined || at < 0 ? n : at)), 0, id);
        // (a tab emptied on the way goes; the target keeps its place among
        // those that stay)
        const kept = next.filter(t => t.panels.length > 0);
        root._commit(next, kept.indexOf(target));
        return true;
    }

    // A tab of its own for a panel, at `at` among the tabs.
    function newTab(id, at) {
        if (!root.panelIds.includes(id))
            return false;
        const next = root._copy();
        const from = next.findIndex(t => t.panels.includes(id));
        if (from < 0 && next.length >= root.maxTabs)
            return false;
        if (from >= 0 && next[from].panels.length === 1)
            return false;
        if (from >= 0)
            next[from].panels.splice(next[from].panels.indexOf(id), 1);
        if (next.length >= root.maxTabs)
            return false;
        const p = root.panel(id);
        const tab = { name: p.name, icon: p.icon, panels: [id] };
        next.splice(Math.max(0, Math.min(next.length, at === undefined ? next.length : at)), 0, tab);
        root._commit(next, next.indexOf(tab));
        return true;
    }

    // Leaves a panel out of every tab.
    function leaveOut(id) {
        const next = root._copy();
        const from = next.findIndex(t => t.panels.includes(id));
        if (from < 0)
            return;
        next[from].panels.splice(next[from].panels.indexOf(id), 1);
        root._commit(next, Math.min(adapter.activeTab, next.filter(t => t.panels.length > 0).length - 1));
    }

    function removeTab(i) {
        const next = root._copy();
        if (i < 0 || i >= next.length)
            return;
        next.splice(i, 1);
        root._commit(next, Math.min(adapter.activeTab, next.length - 1));
    }

    function moveTab(i, j) {
        const next = root._copy();
        if (i < 0 || i >= next.length || j < 0 || j >= next.length || i === j)
            return;
        const [t] = next.splice(i, 1);
        next.splice(j, 0, t);
        root._commit(next, j);
    }

    function renameTab(i, name) {
        const next = root._copy();
        if (!next[i])
            return;
        next[i].name = String(name ?? "").trim().slice(0, 24) || root.panel(next[i].panels[0]).name;
        root._commit(next);
    }

    function setTabIcon(i, icon) {
        const next = root._copy();
        if (!next[i])
            return;
        next[i].icon = String(icon);
        root._commit(next);
    }

    // The next of the icons a tab can wear.
    function cycleTabIcon(i) {
        const t = root.tabs[i];
        if (!t)
            return;
        const k = root.tabIcons.indexOf(t.icon);
        root.setTabIcon(i, root.tabIcons[(k + 1) % root.tabIcons.length]);
    }

    // The panels there were before the tabs knew which ones they'd seen.
    readonly property var _firstPanels: ["workspaces", "calendar", "media", "wifi", "bluetooth", "sound", "system", "notes", "notifications", "tray"]

    // Panels new since the tabs were saved join the tab of the panel they
    // go with (`near`) if it has room, else get a tab of their own, rather
    // than being left out unseen.
    function _welcome() {
        const saved = root._list(adapter.known) ?? [];
        const known = saved.length > 0 ? saved : root._firstPanels;
        const fresh = root.panelIds.filter(id => !known.includes(id) && root.tabOf(id) < 0);
        if (fresh.length > 0) {
            const next = root._copy();
            for (const id of fresh) {
                const p = root.panel(id);
                const near = p.near ?? "";
                const tab = next.find(t => t.panels.includes(near));
                if (tab && tab.panels.length < root.maxPerTab)
                    tab.panels.splice(tab.panels.indexOf(near) + 1, 0, id);
                else if (next.length < root.maxTabs)
                    next.push({ name: p.name, icon: p.icon, panels: [id] });
            }
            adapter.tabs = root.tidy(next);
        }
        if (String(saved) !== String(root.panelIds))
            adapter.known = root.panelIds;
    }

    function resetTabs() {
        adapter.tabs = root.defaultTabs;
        adapter.activeTab = 0;
    }

    function setActiveTab(i) {
        if (i >= 0 && i < root.tabs.length)
            adapter.activeTab = i;
    }

    // Opens it out on the tab with this panel in it.
    function showPanel(id) {
        const i = root.tabOf(id);
        if (i < 0)
            return;
        root.setActiveTab(i);
        root.setOpen(true);
    }

    // ── Arranged by hand ─────────────────────────────────────────────────────
    // A tab's own arrangement (`layout`) is a shape: a tree of its panels,
    // each fork side by side ("row") or one over the other ("col"), a leaf
    // a panel's id: { dir: "row", a: "wifi", b: { dir: "col", a: "dns", b: "bluetooth" } }.
    // It stays as arranged; only the panels' sizes in it follow what they
    // show.
    property bool arranging: false

    // A shape read back from the file, as plain values (null: not one).
    function _shape(v) {
        if (typeof v === "string")
            return v;
        if (v && typeof v === "object" && (v.dir === "row" || v.dir === "col")) {
            const a = root._shape(v.a), b = root._shape(v.b);
            return a !== null && b !== null ? { dir: String(v.dir), a: a, b: b } : null;
        }
        return null;
    }

    function leavesOf(shape) {
        if (shape === null || shape === undefined)
            return [];
        if (typeof shape === "string")
            return [shape];
        return root.leavesOf(shape.a).concat(root.leavesOf(shape.b));
    }

    // The shape without a panel (its fork closes up); null when it was all.
    function _without(shape, id) {
        if (typeof shape === "string")
            return shape === id ? null : shape;
        const a = root._without(shape.a, id), b = root._without(shape.b, id);
        if (a === null)
            return b;
        if (b === null)
            return a;
        return { dir: shape.dir, a: a, b: b };
    }

    // A shape for exactly these panels: ones gone from the tab leave it,
    // ones new to it join at its end, beside the rest.
    function _fit(raw, panels) {
        let shape = root._shape(raw);
        if (shape === null)
            return null;
        const leaves = root.leavesOf(shape);
        for (const id of leaves) {
            if (shape !== null && (!panels.includes(id) || leaves.indexOf(id) !== leaves.lastIndexOf(id)))
                shape = root._without(shape, id);
        }
        for (const id of panels) {
            if (!root.leavesOf(shape).includes(id))
                shape = shape === null ? id : { dir: "row", a: shape, b: id };
        }
        return shape;
    }

    // `shape` with panel `id` taken from where it was and put on `side`
    // ("left", "right", "top", "bottom") of panel `target`, or of all the
    // rest ("").
    function docked(shape, id, target, side) {
        const rest = root._without(shape, id);
        if (rest === null)
            return id;
        const dir = side === "left" || side === "right" ? "row" : "col";
        const first = side === "left" || side === "top";
        const beside = node => first ? { dir: dir, a: id, b: node } : { dir: dir, a: node, b: id };
        if (target === "")
            return beside(rest);
        const put = node => typeof node === "string" ? (node === target ? beside(node) : node) : { dir: node.dir, a: put(node.a), b: put(node.b) };
        return put(rest);
    }

    function layoutOf(i) {
        return root.tabs[i]?.layout ?? null;
    }

    function setLayout(i, shape) {
        const next = root._copy();
        if (!next[i])
            return;
        next[i].layout = root._shape(shape);
        root._commit(next);
    }

    // Back to the arrangement worked out for it.
    function clearLayout(i) {
        const next = root._copy();
        if (!next[i])
            return;
        delete next[i].layout;
        root._commit(next);
    }

    function setArranging(on) {
        root.arranging = !!on && root.open;
    }

    // A shape sized for the panels as they measure (`byId`: { id: { id, w,
    // h } }), as bento() gives its trees (for cells()).
    function sized(shape, byId, gap) {
        if (typeof shape === "string") {
            const it = byId[shape] ?? { id: shape, w: 300, h: 200 };
            return { leaf: it, w: it.w, h: it.h };
        }
        const a = root.sized(shape.a, byId, gap), b = root.sized(shape.b, byId, gap);
        return shape.dir === "row"
            ? { dir: "row", a: a, b: b, w: a.w + gap + b.w, h: Math.max(a.h, b.h) }
            : { dir: "col", a: a, b: b, w: Math.max(a.w, b.w), h: a.h + gap + b.h };
    }

    function shapeOf(tree) {
        if (!tree)
            return null;
        return tree.leaf ? tree.leaf.id : { dir: tree.dir, a: root.shapeOf(tree.a), b: root.shapeOf(tree.b) };
    }

    // Tab `i`'s collage: its own arrangement, or else the one bento() picks
    // for the panels' usual sizes (`usual`), which keeps its shape while
    // what they show comes and goes; sized either way for `items` ([{ id,
    // w, h }], as they measure now).
    function layoutFor(i, items, usual, gap, maxW, maxH, flat, minW, minH) {
        if (items.length === 0)
            return null;
        const byId = {};
        for (const it of items)
            byId[it.id] = it;
        const ids = items.map(it => it.id);
        let shape = root.layoutOf(i);
        const leaves = root.leavesOf(shape);
        if (shape === null || leaves.length !== ids.length || !ids.every(id => leaves.includes(id)))
            shape = root.shapeOf(root.bento(usual, gap, maxW, maxH, flat, minW, minH));
        return root.sized(shape, byId, gap);
    }

    // ── Laying out a tab ─────────────────────────────────────────────────────
    // A collage of a tab's panels: every way of cutting the row of them in
    // two, side by side or one over the other, and again inside each part,
    // kept in their order; the one that wastes least room and stays inside
    // the screen wins, kept low along a border lying flat and narrow up a
    // standing one. Room the popout has anyway (`minW`, `minH`: its strip's
    // length) costs nothing. `items` are [{ id, w, h }]; returns the tree,
    // or null.
    function bento(items, gap, maxW, maxH, flat, minW, minH) {
        const n = items.length;
        if (n === 0)
            return null;
        const memo = {};
        const trees = (i, j) => {
            const key = i + ":" + j;
            if (memo[key])
                return memo[key];
            const out = [];
            if (j - i === 1) {
                out.push({ leaf: items[i], w: items[i].w, h: items[i].h });
            } else {
                for (let k = i + 1; k < j; k++) {
                    for (const a of trees(i, k)) {
                        for (const b of trees(k, j)) {
                            out.push({ dir: "row", a: a, b: b, w: a.w + gap + b.w, h: Math.max(a.h, b.h) });
                            out.push({ dir: "col", a: a, b: b, w: Math.max(a.w, b.w), h: a.h + gap + b.h });
                        }
                    }
                }
            }
            memo[key] = out;
            return out;
        };
        const area = items.reduce((s, it) => s + it.w * it.h, 0);
        let best = null, bestScore = Infinity;
        for (const t of trees(0, n)) {
            const w = Math.max(t.w, minW ?? 0), h = Math.max(t.h, minH ?? 0);
            const over = Math.max(0, t.w - maxW) + Math.max(0, t.h - maxH);
            const score = over * 1e6 + (w * h - area) + (flat ? h : w) * 200;
            if (score < bestScore) {
                bestScore = score;
                best = t;
            }
        }
        return best;
    }

    // The cells of a collage stretched over w × h from x, y: { id: rect }.
    function cells(tree, x, y, w, h, gap, out) {
        if (!tree)
            return out;
        if (tree.leaf) {
            out[tree.leaf.id] = Qt.rect(Math.round(x), Math.round(y), Math.round(w), Math.round(h));
        } else if (tree.dir === "row") {
            const wa = (w - gap) * tree.a.w / (tree.a.w + tree.b.w);
            root.cells(tree.a, x, y, wa, h, gap, out);
            root.cells(tree.b, x + wa + gap, y, w - wa - gap, h, gap, out);
        } else {
            const ha = (h - gap) * tree.a.h / (tree.a.h + tree.b.h);
            root.cells(tree.a, x, y, w, ha, gap, out);
            root.cells(tree.b, x, y + ha + gap, w, h - ha - gap, gap, out);
        }
        return out;
    }

    // ── Settings ─────────────────────────────────────────────────────────────
    function request(what) {
        root.open = false;
        root.requested(what);
    }

    function toggle() {
        if (adapter.enabled)
            root.setOpen(!root.open);
    }

    function setOpen(on) {
        root.open = adapter.enabled && !!on;
    }

    function setEnabled(on) {
        adapter.enabled = !!on;
        if (!on)
            root.open = false;
    }

    function setMinimal(on) {
        if (on)
            adapter.enabled = true;
        adapter.minimal = !!on;
    }

    function toggleMinimal() {
        root.setMinimal(!root.minimal);
    }

    // Moves it: to a border, its middle `pos` (0..1) of the way along.
    function place(edge, pos) {
        if (!root.edges.includes(edge))
            return;
        adapter.edge = edge;
        adapter.pos = Math.max(0, Math.min(1, Number(pos)));
    }

    function setEdge(edge) {
        if (root.edges.includes(edge))
            adapter.edge = edge;
    }

    function setLength(px) {
        adapter.length = Math.round(Math.max(48, Math.min(480, px)));
    }

    function setPeek(on) {
        adapter.peek = !!on;
    }

    function setCloseOnLeave(on) {
        adapter.closeOnLeave = !!on;
    }

    function setCloseDelay(ms) {
        adapter.closeDelay = Math.round(Math.max(200, Math.min(5000, ms)));
    }

    function reset() {
        adapter.edge = "bottom";
        adapter.pos = 0.5;
        adapter.length = 120;
        adapter.peek = true;
        adapter.closeOnLeave = true;
        adapter.closeDelay = 900;
    }

    // Its own writes come back as file changes; a read straight after one
    // would undo what was set meanwhile.
    property double _quietUntil: 0

    Timer {
        id: writeTimer
        interval: 200
        onTriggered: {
            root._quietUntil = Date.now() + 600;
            settingsFile.writeAdapter();
        }
    }

    FileView {
        id: settingsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/edgeline.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: {
            if (Date.now() > root._quietUntil)
                reload();
        }
        onAdapterUpdated: writeTimer.restart()
        onLoaded: root._welcome()
        onLoadFailed: root._welcome()

        adapter: JsonAdapter {
            id: adapter
            property bool enabled: true
            property bool minimal: false
            property string edge: "bottom"
            property real pos: 0.5
            property int length: 120
            property bool peek: true
            property bool closeOnLeave: true
            property int closeDelay: 900
            property var tabs: root.defaultTabs
            property int activeTab: 0
            // the panels there were when the tabs were last saved
            property var known: []
        }
    }
}
