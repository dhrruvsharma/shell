pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services as Svc
import qs.colors
import qs.components
import "Projection.js" as Proj

// One screen's panorama (see services/Panorama for what it's for).
//
// At rest it is a pixel in the screen's corner on the overlay layer, there
// so the workspace keys can tell the shell is up, holding a picture of each
// workspace on this screen as a texture: the screen copied as you leave a
// workspace (and a little after you reach one, and after its windows open,
// close or move while you're at the machine), or put together from its
// windows over the wallpaper for a workspace not seen since the shell
// started. Each picture is the screen's size (about 9 MB of GPU memory for
// 1920x1158); a workspace that goes away takes its picture with it. To play, it grows over the
// screen (but the bar's band, which stays), draws the picture of where you
// are, flat — the very screen — and only then lets Hyprland switch,
// underneath; it swings round to the new workspace's card, flattens onto
// it, fades into the real screen and shrinks back to its pixel.
//
// The overview is the same picture held drawn back: arrows, the wheel, a
// drag or the digits turn it, Enter or a click flattens onto a card, Esc
// back where you were, G the grid instead.
PanelWindow {
    id: win

    required property ShellScreen modelData
    screen: modelData

    // ── Where it lies ──────────────────────────────────────────────────────
    readonly property string monName: modelData ? modelData.name : ""
    readonly property HyprlandMonitor mon: modelData ? Hyprland.monitorFor(modelData) : null
    readonly property var ipc: mon && mon.lastIpcObject ? mon.lastIpcObject : ({})
    readonly property int screenW: modelData ? modelData.width : 1920
    readonly property int screenH: modelData ? modelData.height : 1080
    // The band the bar keeps for itself ([left, top, right, bottom]).
    readonly property int insL: win._reserved(0)
    readonly property int insT: win._reserved(1)
    readonly property int insR: win._reserved(2)
    readonly property int insB: win._reserved(3)
    readonly property int regionW: Math.max(1, win.screenW - win.insL - win.insR)
    readonly property int regionH: Math.max(1, win.screenH - win.insT - win.insB)

    function _reserved(i) {
        const r = win.ipc.reserved;
        return r && r.length > i ? Math.max(0, Math.round(Number(r[i]) || 0)) : 0;
    }

    // The special workspace is over this screen (nothing plays then).
    property string specialName: ""
    readonly property bool specialShown: win.specialName !== ""

    function activeId() {
        return win.mon && win.mon.activeWorkspace ? win.mon.activeWorkspace.id : 0;
    }

    // ── The surface ────────────────────────────────────────────────────────
    property bool grown: false

    anchors {
        top: true
        left: true
        right: win.grown
        bottom: win.grown
    }
    margins {
        top: win.grown ? win.insT : 0
        left: win.grown ? win.insL : 0
        right: win.grown ? win.insR : 0
        bottom: win.grown ? win.insB : 0
    }
    implicitWidth: win.grown ? win.regionW : 1
    implicitHeight: win.grown ? win.regionH : 1
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // hypr/quickshell.lua turns Hyprland's layer animation off for it (it
    // grows and shrinks, which Hyprland would animate), and the workspace
    // keys look for this name to know the shell is up.
    WlrLayershell.namespace: "quickshell:panorama"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: win.phase === "overview" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: win.phase === "overview" ? null : noInput

    Region {
        id: noInput
    }

    // ── What it shows ──────────────────────────────────────────────────────
    //   idle → arming (picture + surface) → switch | gesture | overview
    //   gesture → settle;  overview → leaving;  then fading → idle
    property string phase: "idle"
    property bool presenting: false
    // Workspace ids along the strip, in order.
    property var ring: []
    // The camera, in cards along the strip (fractional while moving; may
    // run past the ends, the ring repeats), and how far drawn back (0 =
    // flat on the screen, 1 = fully).
    property real pos: 0
    property real e: 0
    property int eDur: 300
    property bool eDirect: false
    property real fade: 1
    // The overview's lit card (unwrapped strip index) and its glow.
    property real litIdx: -1
    property real glowAmt: 0
    property real hoverIdx: NaN

    Behavior on e {
        enabled: !win.eDirect
        NumberAnimation {
            duration: win.eDur
            easing.type: Easing.InOutSine
        }
    }
    Behavior on glowAmt {
        NumberAnimation {
            duration: 220
        }
    }

    // Sets `e` at once (a write past the Behavior also stops its animation).
    function _setE(v) {
        win.eDirect = true;
        win.e = v;
        win.eDirect = false;
    }

    // The camera's moves: a cubic that keeps its speed when sent elsewhere
    // halfway (another key while it turns).
    property real _mP0: 0
    property real _mP1: 0
    property real _mV0: 0
    property real _mU: 1
    property int _mDur: 400
    property bool _motionDrives: false

    NumberAnimation {
        id: motion
        target: win
        property: "_mU"
        from: 0
        to: 1
        duration: win._mDur
        onFinished: if (win._mU >= 1) win._motionDone()
    }

    on_MUChanged: {
        if (!win._motionDrives)
            return;
        win.pos = Proj.hermite(win._mP0, win._mV0, win._mP1, win._mU);
        if (win.phase === "switch" && !win._dropping && win._mU >= 0.55)
            win._drop();
        if (win.phase === "leaving" && !win._dropping && win._mU >= 0.45)
            win._drop();
    }

    function moveTo(target, ms) {
        let v = 0;
        if (motion.running && win._motionDrives)
            v = Proj.hermiteSlope(win._mP0, win._mV0, win._mP1, win._mU) / win._mDur * ms;
        motion.stop();
        win._mP0 = win.pos;
        win._mP1 = target;
        win._mV0 = v;
        win._mDur = Math.max(1, Math.round(ms));
        win._motionDrives = true;
        win._mU = 0;
        motion.restart();
    }

    function _stopMotion() {
        motion.stop();
        win._motionDrives = false;
        win._mU = 1;
    }

    // ── The pictures ───────────────────────────────────────────────────────
    // ws id -> { slot, time, real }
    property var shots: ({})
    property int shotsRev: 0
    // Slot i holds workspace slotWs[i]'s picture (0 = free).
    property var slotWs: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var slotUsed: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

    function _slotItem(i) {
        const l = slotRep.itemAt(i);
        return l ? l.item : null;
    }

    function _slotFor(ws, alloc) {
        let i = win.slotWs.indexOf(ws);
        if (i >= 0 || !alloc)
            return i;
        i = win.slotWs.indexOf(0);
        if (i < 0) {
            // the one used longest ago, not on the strip if it can be helped
            let best = -1, bestT = Infinity;
            for (let k = 0; k < 10; k++) {
                const t = win.slotUsed[k] + (win.ring.includes(win.slotWs[k]) ? 1e12 : 0);
                if (t < bestT) {
                    bestT = t;
                    best = k;
                }
            }
            i = best;
            win._forget(win.slotWs[i], false);
        }
        const next = win.slotWs.slice();
        next[i] = ws;
        win.slotWs = next;
        return i;
    }

    function _forget(ws, free) {
        if (!(ws in win.shots))
            return;
        const s = Object.assign({}, win.shots);
        const slot = s[ws].slot;
        delete s[ws];
        win.shots = s;
        if (free && slot >= 0) {
            const next = win.slotWs.slice();
            next[slot] = 0;
            win.slotWs = next;
        }
        win.shotsRev++;
    }

    // What the shader samples for each card on the strip, and which cards
    // have no picture yet (they show the wallpaper).
    readonly property var texs: {
        void win.shotsRev;
        const out = [];
        for (let i = 0; i < 10; i++) {
            const ws = win.ring[i];
            const shot = ws !== undefined ? win.shots[ws] : undefined;
            const item = shot ? win._slotItem(shot.slot) : null;
            out.push(item ?? wallImg);
        }
        return out;
    }
    readonly property real blankMask: {
        void win.shotsRev;
        let m = 0;
        for (let i = 0; i < Math.min(10, win.ring.length); i++) {
            const shot = win.shots[win.ring[i]];
            if (!shot || !win._slotItem(shot.slot))
                m += Math.pow(2, i);
        }
        return m;
    }

    // Takes and makes pictures one at a time: "capture" copies the screen
    // (the workspace on it now), "compose" lays a hidden workspace's
    // windows over the wallpaper.
    property var _jobs: []
    property var _job: null

    function _queue(kind, ws, cb, urgent) {
        if (win._job && win._job.kind === kind && win._job.ws === ws) {
            if (cb)
                win._job.cbs.push(cb);
            if (urgent)
                win._job.urgent = true;
            return;
        }
        const same = win._jobs.find(j => j.kind === kind && j.ws === ws);
        if (same) {
            if (cb)
                same.cbs.push(cb);
            if (urgent) {
                same.urgent = true;
                win._jobs = [same].concat(win._jobs.filter(j => j !== same));
            }
        } else {
            const j = { kind: kind, ws: ws, cbs: cb ? [cb] : [], urgent: !!urgent };
            win._jobs = urgent ? [j].concat(win._jobs) : win._jobs.concat([j]);
        }
        // a picture of the screen can't wait for a composition
        if (urgent && win._job && win._job.kind === "compose") {
            const j = win._job;
            win._endJob(false, true);
            win._jobs = win._jobs.concat([j]);
        }
        if (!win._job)
            win._next();
    }

    function _next() {
        if (win._job || win._jobs.length === 0)
            return;
        const j = win._jobs[0];
        win._jobs = win._jobs.slice(1);
        win._job = j;
        jobTimeout.restart();
        if (j.kind === "capture") {
            if (j.ws !== win.activeId() || !win._canCapture(j.urgent)) {
                win._endJob(false, false);
                return;
            }
            grabLoader.active = true;
        } else {
            const wins = win._windowsOf(j.ws);
            if (j.ws === win.activeId()) {
                win._endJob(false, false);
                return;
            }
            composer.wins = wins;
            composer.ws = j.ws;
            composer.active = true;
        }
    }

    // The screen's frame (or the composition) is in: into the slot with it.
    function _jobReady() {
        const j = win._job;
        Svc.Panorama.log("job in", j ? j.kind + " " + j.ws : "none");
        if (!j)
            return;
        if (j.kind === "capture" && j.ws !== win.activeId()) {
            win._endJob(false, false);
            return;
        }
        const slot = win._slotFor(j.ws, true);
        j.slot = slot;
        const item = win._slotItem(slot);
        if (!item) {
            win._endJob(false, false);
            return;
        }
        item.scheduleUpdate();
    }

    function _slotDone(slot) {
        const j = win._job;
        if (!j || j.slot !== slot)
            return;
        const s = Object.assign({}, win.shots);
        s[j.ws] = { slot: slot, time: Date.now(), real: j.kind === "capture" };
        win.shots = s;
        const used = win.slotUsed.slice();
        used[slot] = Date.now();
        win.slotUsed = used;
        win.shotsRev++;
        win._endJob(true, false);
    }

    function _endJob(ok, requeue) {
        const j = win._job;
        jobTimeout.stop();
        grabLoader.active = false;
        composer.active = false;
        win._job = null;
        if (j && !requeue)
            for (const cb of j.cbs)
                cb(ok);
        Qt.callLater(win._next);
    }

    Timer {
        id: jobTimeout
        interval: 700
        onTriggered: {
            if (win._job && win._job.kind === "compose" && win._job.slot === undefined)
                win._jobReady(); // what came in is enough
            else
                win._endJob(false, false);
        }
    }

    // Whether a picture taken now would be one of the workspace: nothing of
    // the shell over it, no special workspace, the screen awake.
    function _canCapture(urgent) {
        if (win.specialShown || win.activeId() <= 0 || win.presenting)
            return false;
        if (win.ipc.dpmsStatus === false)
            return false;
        if (urgent)
            return true;
        // Hyprland says nothing of the lock screen: pictures on their own are
        // only taken while someone's been at the machine in the last moment.
        return !idle.isIdle && !Svc.Panorama.panelsUp && !Svc.Panorama.overviewOpen && !Svc.ExposeState.open;
    }

    // A hidden workspace's windows, where they lie in this surface's area.
    function _windowsOf(ws) {
        const list = Hyprland.toplevels.values.filter(t => t && t.workspace && t.workspace.id === ws && t.wayland
            && t.lastIpcObject && t.lastIpcObject.at && t.lastIpcObject.size);
        const mx = win.ipc.x ?? 0, my = win.ipc.y ?? 0;
        list.sort((a, b) => {
            const fa = a.lastIpcObject.floating ? 1 : 0, fb = b.lastIpcObject.floating ? 1 : 0;
            if (fa !== fb)
                return fa - fb;
            return (b.lastIpcObject.focusHistoryID ?? 0) - (a.lastIpcObject.focusHistoryID ?? 0);
        });
        return list.map(t => ({
            src: t.wayland,
            x: t.lastIpcObject.at[0] - mx - win.insL,
            y: t.lastIpcObject.at[1] - my - win.insT,
            w: Math.max(1, t.lastIpcObject.size[0]),
            h: Math.max(1, t.lastIpcObject.size[1])
        }));
    }

    function _workspaces() {
        return Hyprland.workspaces.values.filter(w => w && w.id > 0 && w.monitor && w.monitor.name === win.monName).map(w => w.id).sort((a, b) => a - b);
    }

    function _wsOf(id) {
        return Hyprland.workspaces.values.find(w => w && w.id === id) ?? null;
    }

    // A workspace on another screen (switching there turns that screen).
    function _elsewhere(id) {
        const w = win._wsOf(id);
        return !!(w && w.monitor && w.monitor.name !== win.monName);
    }

    // The strip: this screen's workspaces with `must` among them, at most
    // ten around `centre`.
    function _ringFor(must, centre) {
        const set = {};
        for (const id of win._workspaces())
            set[id] = true;
        for (const id of must)
            if (id > 0)
                set[id] = true;
        let ids = Object.keys(set).map(Number).sort((a, b) => a - b);
        if (ids.length > 10) {
            const at = Math.max(0, ids.indexOf(centre));
            const lo = Math.max(0, Math.min(ids.length - 10, at - 4));
            ids = ids.slice(lo, lo + 10);
            for (const id of must)
                if (id > 0 && !ids.includes(id))
                    ids[ids.length - 1] = id;
            ids.sort((a, b) => a - b);
        }
        return ids;
    }

    // ── Playing ────────────────────────────────────────────────────────────
    property var _reqs: []      // switches to hand to Hyprland once covered
    property var _queued: null  // one that came while fading out
    property int _fromId: 0
    property int _toId: 0
    property int _dir: 0
    property string _armKind: ""
    property bool _dispatchOnSwap: false
    property bool _dropping: false
    property bool _ownOverview: false

    readonly property bool ready: win.visible

    function _canPlay() {
        return !win.specialShown && !Svc.Panorama.panelsUp && win.activeId() > 0 && win.ipc.dpmsStatus !== false;
    }

    // "focus:3" -> 3; a relative one -> the workspace it would be, or 0.
    function _target(hint) {
        const m = /^(focus|move):(.+)$/.exec(String(hint));
        if (!m)
            return 0;
        const w = m[2];
        if (/^\d+$/.test(w))
            return Number(w);
        const r = /^([emr]?)([+-])(\d+)$/.exec(w);
        if (!r)
            return 0;
        const cur = win.activeId();
        const step = (r[2] === "-" ? -1 : 1) * Number(r[3]);
        if (r[1] === "r" || r[1] === "")
            return Math.max(1, cur + step);
        const ids = win._workspaces();
        const at = ids.indexOf(cur);
        if (at < 0 || ids.length === 0)
            return 0;
        return ids[((at + step) % ids.length + ids.length) % ids.length];
    }

    // A workspace key's switch (from the Lua side): false hands it straight
    // back to Hyprland.
    function routedSwitch(seq, hint, fromId) {
        if (!win.ready || win.activeId() !== fromId)
            return false;
        return win._beginSwitch({ seq: seq, hint: hint, lua: "" });
    }

    // One from the shell itself (the disc, the overview).
    function localSwitch(id) {
        if (!win.ready)
            return false;
        return win._beginSwitch({ seq: 0, hint: "focus:" + id, lua: "hl.dsp.focus({ workspace = " + Math.round(id) + " })" });
    }

    // +1 / -1 for "the next" / "the previous" (e+1, m-1…): the camera
    // carries on that way round the ring rather than back along it.
    function _direction(hint) {
        const m = /^(focus|move):[emr]?([+-])\d+$/.exec(String(hint));
        return m ? (m[2] === "-" ? -1 : 1) : 0;
    }

    function _beginSwitch(req) {
        const target = win._target(req.hint);
        const dir = win._direction(req.hint);
        if (target > 0 && (target === win.activeId() || win._elsewhere(target)))
            return false;
        if (win.phase === "switch") {
            win._dir = dir;
            win._dispatch(req);
            return true;
        }
        if (win.phase === "arming" && win._armKind === "switch") {
            win._dir = dir;
            win._reqs = win._reqs.concat([req]);
            return true;
        }
        if (win.phase === "fading" && !win._queued) {
            win._queued = req;
            return true;
        }
        if (win.phase !== "idle" || !win._canPlay())
            return false;
        win._reqs = [req];
        win._toId = target;
        win._dir = dir;
        win._arm("switch");
        return true;
    }

    function _dispatch(req) {
        if (req.seq > 0)
            Svc.Panorama.take(req.seq);
        else if (req.lua)
            Hyprland.dispatch(req.lua);
    }

    function _dispatchAll() {
        const reqs = win._reqs;
        win._reqs = [];
        for (const r of reqs)
            win._dispatch(r);
    }

    // Picture first, then the surface over the screen.
    function _arm(kind) {
        Svc.Panorama.log("arm", kind, win.monName);
        win._armKind = kind;
        win._fromId = win.activeId();
        win.phase = "arming";
        win.grown = true;
        armTimeout.restart();
        win._queue("capture", win._fromId, ok => win._armed(ok), true);
    }

    function _armed(ok) {
        Svc.Panorama.log("pictured", ok, win.phase);
        if (win.phase !== "arming")
            return;
        if (!ok || win.activeId() !== win._fromId) {
            win._giveUp();
            return;
        }
        let must = [win._fromId];
        if (win._armKind === "switch" && win._toId > 0)
            must.push(win._toId);
        if (win._armKind === "overview" || win._armKind === "gesture")
            must = must.concat(win._extraCard());
        win.ring = win._ringFor(must, win._fromId);
        win._stopMotion();
        win.pos = win.ring.indexOf(win._fromId);
        win._setE(0);
        win.fade = 1;
        win.litIdx = win.pos;
        win.glowAmt = 0;
        win.presenting = true;
    }

    // The new workspace's card past the last (a swipe or the overview can
    // make one, as Hyprland's swipe does).
    function _extraCard() {
        const ids = win._workspaces();
        if (ids.length >= 10)
            return [];
        if (win._armKind === "gesture" && !Svc.Panorama.swipeCreateNew)
            return [];
        const max = ids.length ? ids[ids.length - 1] : win.activeId();
        let next = max + 1;
        while (win._elsewhere(next))
            next++;
        return [next];
    }

    // The surface is up, the screen's own picture on it: off it goes.
    function _started() {
        Svc.Panorama.log("started", win._armKind, "ring", JSON.stringify(win.ring), "pos", win.pos);
        armTimeout.stop();
        const kind = win._armKind;
        win.phase = kind;
        const D = Svc.Panorama.duration;
        if (kind === "switch") {
            win._dropping = false;
            win.eDur = Math.round(D * 0.4);
            win.e = 1;
            win._dispatchOnSwap = true;
            switchWatch.restart();
        } else if (kind === "overview") {
            win._ownOverview = true;
            Svc.Panorama.overviewOpen = true;
            win.eDur = 380;
            win.e = 1;
            win.glowAmt = 1;
            keyHolder.forceActiveFocus();
            win._composeMissing();
        } else if (kind === "gesture") {
            win.eDirect = true;
            win._gBase = win.pos;
            win._applyOffset();
        }
    }

    // Couldn't get the picture or the surface in time: switch plainly.
    function _giveUp() {
        Svc.Panorama.log("gave up", win._armKind);
        armTimeout.stop();
        const kind = win._armKind;
        win._reset();
        if (kind === "switch")
            win._dispatchAll();
        else if (kind === "gesture")
            Svc.Panorama.gesturePlain(win._gSerial);
        else if (kind === "overview" && win._ownOverview) {
            win._ownOverview = false;
            Svc.Panorama.overviewOpen = false;
        }
    }

    Timer {
        id: armTimeout
        interval: 350
        onTriggered: if (win.phase === "arming") win._giveUp()
    }

    // No switch came of it (another screen's workspace, a key that went
    // nowhere): flatten back where it started.
    Timer {
        id: switchWatch
        interval: 500
        onTriggered: {
            if (win.phase === "switch" && win.activeId() === win._fromId && !motion.running) {
                win._reqs = [];
                win._toId = win._fromId;
                win._drop();
            }
        }
    }

    // The workspace on this screen changed.
    function _switched() {
        const to = win.activeId();
        Svc.Panorama.log("switched to", to, "in", win.phase);
        if (win.phase === "idle") {
            // unrouted (an app asked, a script): no show, but a picture soon
            refreshTimer.restart();
            return;
        }
        if (win.phase === "arming") {
            if (to !== win._fromId && win._armKind !== "gesture")
                win._giveUp();
            return;
        }
        if (win.phase === "switch") {
            switchWatch.stop();
            win._toId = to;
            if (!win.ring.includes(to)) {
                const here = win.ring[Proj.slotOf(Math.round(win.pos), win.ring.length)];
                win.ring = win._ringFor(win.ring.concat([to]), to);
                win.pos = win.ring.indexOf(here);
                win._mP0 = win.pos;
            }
            // straight there along the strip, in workspace order; "the
            // next" and "the previous" carry on round the ring instead
            const n = win.ring.length;
            let idx = win.ring.indexOf(to);
            if (win._dir > 0 && idx < win.pos - 0.01)
                idx += n * Math.ceil((win.pos - idx) / n);
            else if (win._dir < 0 && idx > win.pos + 0.01)
                idx -= n * Math.ceil((idx - win.pos) / n);
            const dist = Math.abs(idx - win.pos);
            const D = Svc.Panorama.duration;
            win._dropping = false;
            win.eDur = Math.round(D * 0.4);
            win.e = 1;
            win.moveTo(idx, D * 0.8 * Math.min(1.6, 1 + 0.15 * Math.max(0, dist - 1)));
            return;
        }
        if (win.phase === "settle" || win.phase === "leaving" || win.phase === "fading" || win.phase === "gesture") {
            win._checkDone();
            return;
        }
        if (win.phase === "overview") {
            // switched from elsewhere meanwhile: close onto it
            win.closeOverview();
        }
    }

    // The camera's past the middle of its way: flatten onto the card.
    function _drop() {
        win._dropping = true;
        win.eDur = Math.round(Svc.Panorama.duration * 0.45);
        win.e = 0;
        win.glowAmt = 0;
    }

    function _motionDone() {
        if (win.phase === "switch" || win.phase === "leaving") {
            if (!win._dropping)
                win._drop();
            win._checkDone();
        }
    }

    onEChanged: if (win.e === 0) win._checkDone()

    // Flat, on the right card, and the screen under it switched: fade into it.
    function _checkDone() {
        if (win.e !== 0 || motion.running)
            return;
        if (win.phase === "switch" || win.phase === "leaving" || win.phase === "settle") {
            if (win._toId > 0 && win.activeId() !== win._toId && !doneWait.running) {
                doneWait.restart();
                return;
            }
            win._fadeOut();
        }
    }

    // A moment for Hyprland to catch up before fading anyway.
    Timer {
        id: doneWait
        interval: 300
        onTriggered: win._fadeOut()
    }

    function _fadeOut() {
        if (win.phase === "fading" || win.phase === "idle")
            return;
        Svc.Panorama.log("fade", win.phase);
        doneWait.stop();
        win.phase = "fading";
        fadeAnim.restart();
    }

    NumberAnimation {
        id: fadeAnim
        target: win
        property: "fade"
        to: 0
        duration: 140
        easing.type: Easing.InQuad
        onFinished: if (win.phase === "fading") win._reset()
    }

    function _reset() {
        Svc.Panorama.log("reset", win.phase);
        fadeAnim.stop();
        armTimeout.stop();
        switchWatch.stop();
        doneWait.stop();
        win._stopMotion();
        win.presenting = false;
        win.phase = "idle";
        win.grown = false;
        win.fade = 1;
        win.eDirect = false;
        win._setE(0);
        win.glowAmt = 0;
        win.hoverIdx = NaN;
        win._dispatchOnSwap = false;
        if (win._ownOverview) {
            win._ownOverview = false;
            Svc.Panorama.overviewOpen = false;
        }
        refreshTimer.restart();
        if (win._queued) {
            const q = win._queued;
            win._queued = null;
            Qt.callLater(() => {
                if (!win._beginSwitch(q))
                    win._dispatch(q);
            });
        }
    }

    // Our first full frame is on screen: start; the frame after, the
    // switch can go underneath.
    Connections {
        target: fx.Window.window
        enabled: win.presenting

        function onFrameSwapped() {
            const w = fx.Window.window;
            if (!w)
                return;
            if (win.phase === "arming" && w.width >= win.regionW - 1 && w.height >= win.regionH - 1) {
                win._started();
            } else if (win._dispatchOnSwap && win.phase === "switch") {
                win._dispatchOnSwap = false;
                Svc.Panorama.log("dispatch", win._reqs.length);
                win._dispatchAll();
            }
        }
    }

    // ── The swipe ──────────────────────────────────────────────────────────
    property int _gSerial: -1
    property real _gTotal: 0
    property real _gSpeed: 0
    property real _gBase: 0
    property real _gOffset: 0

    function gesture(stage, serial, total, extra) {
        if (stage === "start") {
            if (win.phase !== "idle" || !win._canPlay() || win.activeId() <= 0)
                return false;
            win._gSerial = serial;
            win._gTotal = 0;
            win._gSpeed = 0;
            win._arm("gesture");
            return true;
        }
        if (serial !== win._gSerial)
            return false;
        if (stage === "update") {
            win._gTotal = total;
            win._gSpeed = Number(extra) || 0;
            if (win.phase === "gesture")
                win._applyOffset();
            return true;
        }
        if (stage === "finish") {
            win._gTotal = total;
            win._gFinish(extra === "1");
            return true;
        }
        return false;
    }

    // Fingers' travel -> cards: Hyprland's distance per workspace, its
    // direction; held back past the ends.
    function _offsetFor(total) {
        const d = Math.max(50, Svc.Panorama.swipeDistance);
        let o = (Svc.Panorama.swipeInvert ? -total : total) / d;
        const base = Math.round(win._gBase);
        const n = win.ring.length;
        if ((o > 0 && base >= n - 1) || (o < 0 && base <= 0))
            o = o * 0.18;
        return Math.max(-0.999, Math.min(0.999, o));
    }

    function _applyOffset() {
        const o = win._offsetFor(win._gTotal);
        win._gOffset = o;
        win.pos = win._gBase + o;
        win.e = Math.sin(Math.PI * Math.min(1, Math.abs(o)));
    }

    function _gFinish(cancelled) {
        if (win.phase === "arming") {
            // over before the surface was up: as Hyprland would
            win._reset();
            Svc.Panorama.gesturePlain(win._gSerial);
            return;
        }
        if (win.phase !== "gesture")
            return;
        const o = win._offsetFor(win._gTotal);
        const base = Math.round(win._gBase);
        const n = win.ring.length;
        const speed = win._gSpeed * (Svc.Panorama.swipeInvert ? -1 : 1);
        let dir = 0;
        if (!cancelled) {
            if (Math.abs(o) >= Svc.Panorama.swipeCancel)
                dir = o > 0 ? 1 : -1;
            else if (Math.abs(speed) >= Svc.Panorama.swipeForce && Math.sign(speed) === Math.sign(o))
                dir = o > 0 ? 1 : -1;
        }
        if (base + dir < 0 || base + dir > n - 1)
            dir = 0;
        const ws = dir !== 0 ? win.ring[base + dir] : 0;
        win._toId = ws > 0 ? ws : win._fromId;
        Svc.Panorama.gestureDone(ws);
        win.phase = "settle";
        const rem = Math.abs(dir - o);
        const fast = 1 + Math.min(2.5, Math.abs(speed) / 12);
        settleAnim.duration = Math.max(60, Math.min(220, Math.round(rem * 260 / fast + 40)));
        settleAnim.from = o;
        settleAnim.to = dir;
        settleAnim.restart();
    }

    NumberAnimation {
        id: settleAnim
        target: win
        property: "_gOffset"
        easing.type: Easing.OutCubic
        onFinished: {
            if (win.phase !== "settle")
                return;
            win.eDirect = false;
            win._setE(0);
            win._checkDone();
        }
    }

    on_GOffsetChanged: {
        if (win.phase !== "settle")
            return;
        win.pos = win._gBase + win._gOffset;
        win.e = Math.sin(Math.PI * Math.min(1, Math.abs(win._gOffset)));
    }

    // ── The overview ───────────────────────────────────────────────────────
    function toggleOverview() {
        if (win.phase === "overview") {
            win.closeOverview();
            return true;
        }
        return win.openOverview();
    }

    function openOverview() {
        if (win.phase === "overview")
            return true;
        if (win.phase !== "idle" || win.specialShown || win.activeId() <= 0)
            return false;
        win._arm("overview");
        return true;
    }

    function closeOverview() {
        if (win.phase === "arming" && win._armKind === "overview") {
            win._giveUp();
            return;
        }
        if (win.phase !== "overview")
            return;
        const here = win.ring.indexOf(win.activeId());
        win.choose(here >= 0 ? Proj.nearest(here, win.pos, win.ring.length) : Math.round(win.pos));
    }

    // The card at unwrapped index `idx`: flatten onto it, switching there.
    function choose(idx) {
        if (win.phase !== "overview")
            return;
        const n = win.ring.length;
        const ws = win.ring[Proj.slotOf(idx, n)];
        win.phase = "leaving";
        win._dropping = false;
        win.litIdx = idx;
        win._toId = ws;
        win._ownOverview = false;
        Svc.Panorama.overviewOpen = false;
        if (ws !== win.activeId())
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + ws + " })");
        const dist = Math.abs(idx - win.pos);
        if (dist < 0.01) {
            win._drop();
        } else {
            win.moveTo(idx, Math.min(620, 300 + 70 * dist));
        }
    }

    function browse(step) {
        if (win.phase !== "overview" || win.ring.length === 0)
            return;
        const target = Math.round(win._motionDrives && motion.running ? win._mP1 : win.pos) + step;
        win.litIdx = target;
        win.moveTo(target, 280);
    }

    function _browseTo(ws) {
        const i = win.ring.indexOf(ws);
        if (i < 0)
            return false;
        win.choose(Proj.nearest(i, win.pos, win.ring.length));
        return true;
    }

    function _composeMissing() {
        for (const ws of win.ring)
            if (ws !== win.activeId() && !(ws in win.shots) && win._wsOf(ws))
                win._queue("compose", ws, null, false);
    }

    // ── Pictures at rest ───────────────────────────────────────────────────
    Timer {
        id: refreshTimer
        interval: 700
        onTriggered: {
            if (win.phase === "idle" && win._canCapture(false))
                win._queue("capture", win.activeId(), null, false);
        }
    }

    Timer {
        id: eventRefresh
        interval: 1500
        onTriggered: refreshTimer.restart()
    }

    IdleMonitor {
        id: idle
        timeout: 20
        respectInhibitors: false
    }

    // After the shell starts: the screen, then whatever's hidden.
    Timer {
        id: startup
        interval: 2500
        onTriggered: {
            Hyprland.refreshMonitors();
            Hyprland.refreshToplevels();
            refreshTimer.restart();
            composeIdle.restart();
        }
    }

    Timer {
        id: composeIdle
        interval: 600
        onTriggered: {
            if (win.phase !== "idle")
                return;
            for (const ws of win._workspaces())
                if (ws !== win.activeId() && !(ws in win.shots))
                    win._queue("compose", ws, null, false);
        }
    }

    Connections {
        target: win.mon

        function onActiveWorkspaceChanged() {
            win._switched();
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            switch (event.name) {
            case "openwindow":
            case "closewindow":
            case "movewindowv2":
            case "changefloatingmode":
            case "fullscreen":
                if (win.phase === "idle")
                    eventRefresh.restart();
                break;
            case "activespecial": {
                const d = String(event.data);
                const comma = d.lastIndexOf(",");
                if (d.slice(comma + 1) === win.monName)
                    win.specialName = d.slice(0, comma);
                break;
            }
            case "destroyworkspacev2": {
                const id = Number(String(event.data).split(",")[0]);
                if (id > 0)
                    win._forget(id, true);
                break;
            }
            case "openlayer":
            case "closelayer":
                if (String(event.data).indexOf("quickshell:panorama") < 0)
                    insetsTimer.restart();
                break;
            case "configreloaded":
            case "monitoraddedv2":
            case "monitorremoved":
                insetsTimer.restart();
                break;
            }
        }
    }

    Timer {
        id: insetsTimer
        interval: 400
        onTriggered: Hyprland.refreshMonitors()
    }

    // The bar's band changed size: the pictures no longer fit.
    onRegionWChanged: win._dropAll()
    onRegionHChanged: win._dropAll()

    function _dropAll() {
        if (win.presenting)
            win._reset();
        win.shots = ({});
        win.slotWs = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        win.shotsRev++;
        startup.restart();
    }

    // ── The wallpaper (cards without a picture; the backdrop) ────────────
    readonly property string wallUrl: "file://" + Svc.WallpaperEngine.link

    Image {
        id: wallImg
        visible: false
        source: win.wallUrl
        asynchronous: true
        cache: false
        // shown as it is behind the cards, it needs every pixel
        sourceSize.width: win.screenW
    }

    Timer {
        id: wallReload
        interval: 1500
        onTriggered: {
            wallImg.source = "";
            wallImg.source = win.wallUrl;
        }
    }

    Connections {
        target: Svc.WallpaperEngine

        function onSerialChanged() {
            wallReload.restart();
        }
    }

    // The wallpaper covers the whole screen; this surface's part of it.
    readonly property vector4d bgRect: {
        const iw = Math.max(1, wallImg.implicitWidth), ih = Math.max(1, wallImg.implicitHeight);
        const s = Math.max(win.screenW / iw, win.screenH / ih);
        const dw = iw * s, dh = ih * s;
        const ox = (win.screenW - dw) / 2, oy = (win.screenH - dh) / 2;
        return Qt.vector4d((win.insL - ox) / dw, (win.insT - oy) / dh, win.regionW / dw, win.regionH / dh);
    }

    // ── Drawing ────────────────────────────────────────────────────────────
    // Nothing of this shows: the screen's copy and the compositions are
    // drawn into the slots from here.
    Item {
        width: 0
        height: 0
        clip: true

        Item {
            id: grabHost
            width: win.regionW
            height: win.regionH

            Loader {
                id: grabLoader
                active: false
                sourceComponent: ScreencopyView {
                    x: -win.insL
                    y: -win.insT
                    width: win.screenW
                    height: win.screenH
                    captureSource: win.modelData
                    live: false
                    paintCursor: false
                    onHasContentChanged: if (hasContent) Qt.callLater(win._jobReady)
                }
            }

            Loader {
                id: composer
                active: false
                property int ws: 0
                property var wins: []
                sourceComponent: Item {
                    id: comp
                    width: win.regionW
                    height: win.regionH
                    property int waiting: composer.wins.length + 1
                    property bool wallIn: false

                    function arrived() {
                        comp.waiting--;
                        if (comp.waiting <= 0)
                            Qt.callLater(win._jobReady);
                    }

                    Image {
                        x: -win.insL
                        y: -win.insT
                        width: win.screenW
                        height: win.screenH
                        source: win.wallUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(win.screenW, win.screenH)
                        onStatusChanged: {
                            if (!comp.wallIn && (status === Image.Ready || status === Image.Error)) {
                                comp.wallIn = true;
                                comp.arrived();
                            }
                        }
                        Component.onCompleted: {
                            if (!comp.wallIn && (status === Image.Ready || status === Image.Error)) {
                                comp.wallIn = true;
                                comp.arrived();
                            }
                        }
                    }

                    Repeater {
                        model: composer.wins

                        ScreencopyView {
                            required property var modelData
                            x: modelData.x
                            y: modelData.y
                            width: modelData.w
                            height: modelData.h
                            captureSource: modelData.src
                            live: false
                            paintCursor: false
                            property bool counted: false
                            onHasContentChanged: {
                                if (hasContent && !counted) {
                                    counted = true;
                                    comp.arrived();
                                }
                            }
                        }
                    }
                }
            }
        }

        Repeater {
            id: slotRep
            model: 10

            Loader {
                id: slotLoader
                required property int index
                active: win.slotWs[slotLoader.index] !== 0
                sourceComponent: ShaderEffectSource {
                    width: 1
                    height: 1
                    sourceItem: grabHost
                    live: false
                    hideSource: false
                    textureSize: Qt.size(win.regionW, win.regionH)
                    onScheduledUpdateCompleted: win._slotDone(slotLoader.index)
                }
            }
        }
    }

    // The panorama itself.
    ShaderEffect {
        id: fx
        width: win.regionW
        height: win.regionH
        visible: win.presenting
        opacity: win.fade

        readonly property real n: Math.max(1, Math.min(10, win.ring.length))
        readonly property real pitchPx: Math.max(1, width) * 1.04
        readonly property real kFull: Math.min(2 * Math.PI / (n * pitchPx), 0.9 / pitchPx) * Svc.Panorama.curve

        property size resolution: Qt.size(Math.max(1, width), Math.max(1, height))
        property color accent: Svc.DesktopTheme.accent
        property vector4d bgRect: win.bgRect
        property real scroll: win.pos * fx.pitchPx
        property real kappa: fx.kFull * win.e
        property real dist: 1 / Math.max(fx.kFull, 0.0001)
        property real zoom: 1 - Svc.Panorama.depth * win.e
        property real cardW: Math.max(1, width * (1 - 0.1 * win.e))
        property real cardH: Math.max(1, height * (1 - 0.1 * win.e))
        property real pitch: fx.pitchPx
        property real count: fx.n
        property real radius: Svc.DesktopTheme.rad(22) * win.e
        property real depthFade: 0.6
        property real blankMask: win.blankMask
        property real lit: win.litIdx
        property real glow: win.glowAmt
        property real veil: 1
        property var src0: win.texs[0]
        property var src1: win.texs[1]
        property var src2: win.texs[2]
        property var src3: win.texs[3]
        property var src4: win.texs[4]
        property var src5: win.texs[5]
        property var src6: win.texs[6]
        property var src7: win.texs[7]
        property var src8: win.texs[8]
        property var src9: win.texs[9]
        property var wall: wallImg

        fragmentShader: Qt.resolvedUrl("../../shaders/panorama.frag.qsb")

        // The same sums for QML (labels, the pointer).
        readonly property var params: ({
            w: fx.width, h: fx.height, dist: fx.dist, zoom: fx.zoom, kappa: fx.kappa,
            scroll: fx.scroll, pitch: fx.pitch, cardW: fx.cardW, cardH: fx.cardH, count: fx.n
        })
    }

    // The overview's words under each card.
    Item {
        id: labels
        width: win.regionW
        height: win.regionH
        visible: win.presenting && (win.phase === "overview" || win.phase === "leaving")
        opacity: win.glowAmt

        Repeater {
            model: labels.visible ? win.ring.length : 0

            PanoramaLabel {
                required property int index
                surface: win
                slot: index
                params: fx.params
            }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 26
            text: "←  →  turn      ↵  go      esc  back      G  grid"
            color: Colors.withAlpha(Colors.on_surface, 0.6)
            font.pixelSize: 13
            font.letterSpacing: 1
        }
    }

    // The pointer and the keys, while the overview's up.
    Item {
        id: keyHolder
        width: win.regionW
        height: win.regionH
        focus: true

        Keys.onPressed: ev => {
            if (win.phase !== "overview")
                return;
            ev.accepted = true;
            const k = ev.key;
            if (k === Qt.Key_Left || k === Qt.Key_H || k === Qt.Key_A || k === Qt.Key_Up || k === Qt.Key_Backtab)
                win.browse(-1);
            else if (k === Qt.Key_Right || k === Qt.Key_L || k === Qt.Key_D || k === Qt.Key_Down || k === Qt.Key_Tab)
                win.browse(1);
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)
                win.choose(Math.round(win.litIdx));
            else if (k === Qt.Key_Escape)
                win.closeOverview();
            else if (k === Qt.Key_G) {
                win.closeOverview();
                Svc.Panorama.set("view", "grid");
                gridLater.restart();
            } else if (k >= Qt.Key_0 && k <= Qt.Key_9) {
                win._browseTo(k === Qt.Key_0 ? 10 : k - Qt.Key_0);
            } else
                ev.accepted = false;
        }

        MouseArea {
            anchors.fill: parent
            enabled: win.phase === "overview"
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: !isNaN(win.hoverIdx) ? Qt.PointingHandCursor : Qt.ArrowCursor

            property real pressX: 0
            property real pressPos: 0
            property bool dragging: false
            property real wheelAcc: 0

            onPositionChanged: m => {
                if (pressed && (m.buttons & Qt.LeftButton)) {
                    if (!dragging && Math.abs(m.x - pressX) > 8) {
                        dragging = true;
                        win._stopMotion();
                    }
                    if (dragging) {
                        const p = Proj.project(fx.params, Math.round(pressPos) * fx.pitchPx, 0);
                        const scale = p ? p.scale : 1;
                        win.pos = pressPos - (m.x - pressX) / Math.max(40, fx.pitchPx * scale * 0.9);
                        win.litIdx = Math.round(win.pos);
                        return;
                    }
                }
                const h = Proj.hit(fx.params, m.x, m.y);
                win.hoverIdx = h.inside ? h.idx : NaN;
                if (h.inside)
                    win.litIdx = h.idx;
            }
            onPressed: m => {
                pressX = m.x;
                pressPos = win.pos;
                dragging = false;
            }
            onReleased: m => {
                if (dragging) {
                    dragging = false;
                    const t = Math.round(win.pos);
                    win.litIdx = t;
                    win.moveTo(t, 220);
                }
            }
            onClicked: m => {
                if (m.button === Qt.RightButton) {
                    win.closeOverview();
                    return;
                }
                const h = Proj.hit(fx.params, m.x, m.y);
                if (h.inside)
                    win.choose(h.idx);
                else
                    win.closeOverview();
            }
            onExited: win.hoverIdx = NaN
            onWheel: w => {
                const d = Math.abs(w.angleDelta.x) > Math.abs(w.angleDelta.y) ? w.angleDelta.x : w.angleDelta.y;
                wheelAcc += d;
                if (Math.abs(wheelAcc) >= 100) {
                    win.browse(wheelAcc < 0 ? 1 : -1);
                    wheelAcc = 0;
                }
            }
        }
    }

    Timer {
        id: gridLater
        interval: 520
        onTriggered: Svc.ExposeState.open = true
    }

    // For `qs ipc call panorama state`.
    function describe() {
        return {
            phase: win.phase, ring: win.ring, pos: Math.round(win.pos * 100) / 100, e: Math.round(win.e * 100) / 100,
            grown: win.grown, shots: Object.keys(win.shots).map(k => k + (win.shots[k].real ? "" : "~")),
            region: [win.insL, win.insT, win.regionW, win.regionH], special: win.specialName,
            reserved: JSON.stringify(win.ipc.reserved ?? null)
        };
    }

    Component.onCompleted: {
        Svc.Panorama.register(win.monName, win);
        const sp = win.ipc.specialWorkspace;
        win.specialName = sp && sp.name ? String(sp.name) : "";
        Hyprland.refreshMonitors();
        startup.restart();
    }
    Component.onDestruction: {
        Svc.Panorama.unregister(win.monName, win);
        if (win.phase === "overview" || win.phase === "arming")
            Svc.Panorama.overviewOpen = false;
    }
}
