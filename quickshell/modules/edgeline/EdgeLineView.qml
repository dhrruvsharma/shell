pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.colors
import qs.services as Services
import qs.components
import qs.modules.control
import qs.modules.desktopwidgets

// What the edge line is and does, laid out on the whole screen in screen
// coordinates (EdgeLineWindow puts it on its surface; the harness in a
// window of its own). A thin line on one of the screen's borders
// (services/EdgeLine says which, and where along it); its brighter stretch
// is the workspace you're on, among the ones there are.
//
//  - Rest the pointer on it and it swells into a pill: the time, the date
//    or what's playing, and the screen tools at its end (a screenshot,
//    record or stop, the recording's sound; services/ScreenRecord). While
//    the screen's being recorded the line breathes red.
//  - Click it and it opens out into one popout. On the screen's bare
//    border it comes out of the border, flared into it (components/
//    Popout's bubble); along the bar's inner side it's a box in the desktop
//    theme's frame. The line stretches along the border into its strip
//    (the workspaces, the time, the tabs, the launcher, power and minimal
//    mode) and the chosen tab's panes stand beside it, all of them open,
//    laid out together like a collage (services/EdgeLine.bento). Another
//    tab and the popout takes that tab's shape. Once the pointer has left
//    it (and nothing in it is being typed into) it folds back into the
//    line; Esc or a click on the strip's bare stretch does too.
//  - Drag it (the line, or the strip's bare stretch) and it slides along
//    the borders after the pointer, onto whichever is nearest; let go and
//    it stays there.
//
// It keeps clear of the bar: on the bar's edge it lives along the bar's
// inner side. In minimal mode the bar is gone and it lives on the border.
Item {
    id: view

    // A panel of the shell's is up over this part of the screen: the line
    // drops beneath it (as the bar does) unless it's open.
    property bool covered: false

    // The screen's size, and whether the surface covers it now (the window
    // says; the harness pretends).
    property real sw: 1920
    property real sh: 1200
    property bool full: false

    // ── Where it lives ──────────────────────────────────────────────────────
    // Held and dragged, it goes where the pointer is; otherwise where it was
    // put.
    property bool held: false
    property string dragEdge: Services.EdgeLine.edge
    property real dragAlong: 0
    readonly property bool dragging: Services.EdgeLine.dragging
    readonly property string edge: view.dragging ? view.dragEdge : Services.EdgeLine.edge
    readonly property bool horizontal: view.edge === "top" || view.edge === "bottom"
    readonly property real edgeLen: view.lengthOf(view.edge)
    readonly property real inset: view.insetOf(view.edge)
    readonly property real lineLen: Services.EdgeLine.length
    // The line's middle along its border, in screen px.
    readonly property real along: view.dragging ? view.dragAlong : view.alongOf(Services.EdgeLine.edge, Services.EdgeLine.pos)

    // (bolder while it's carried, so it's easy to follow)
    readonly property real lineThick: view.dragging ? 5 : 3
    readonly property real lineGap: 3
    readonly property real pillThick: view.horizontal ? 32 : 38
    readonly property real margin: 10

    function lengthOf(e) {
        return e === "top" || e === "bottom" ? view.sw : view.sh;
    }

    function opposite(e) {
        return ({ top: "bottom", bottom: "top", left: "right", right: "left" })[e];
    }

    // The bar's room on a border; the line keeps to its inner side.
    function insetOf(e) {
        return ({
                top: Services.BarLayout.reserveTop,
                bottom: Services.BarLayout.reserveBottom,
                left: Services.BarLayout.reserveLeft,
                right: Services.BarLayout.reserveRight
            })[e] ?? 0;
    }

    // Where a border's free stretch starts and ends: clear of the bar
    // when it stands on a border across this one's ends.
    function startOf(e) {
        return e === "top" || e === "bottom" ? Services.BarLayout.reserveLeft : Services.BarLayout.reserveTop;
    }

    function endOf(e) {
        return view.lengthOf(e) - (e === "top" || e === "bottom" ? Services.BarLayout.reserveRight : Services.BarLayout.reserveBottom);
    }

    function alongOf(e, p) {
        const half = view.lineLen / 2 + 6;
        return Math.max(view.startOf(e) + half, Math.min(view.endOf(e) - half, p * view.lengthOf(e)));
    }

    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, v));
    }

    function mix(a, b, t) {
        return a + (b - a) * t;
    }

    function mixRect(a, b, t) {
        return Qt.rect(view.mix(a.x, b.x, t), view.mix(a.y, b.y, t), view.mix(a.width, b.width, t), view.mix(a.height, b.height, t));
    }

    // A box on the screen, given along a border (from its left or top end)
    // and out from it (inwards).
    function rectOn(e, a0, la, o0, lo) {
        switch (e) {
        case "top":
            return Qt.rect(a0, o0, la, lo);
        case "bottom":
            return Qt.rect(a0, view.sh - o0 - lo, la, lo);
        case "left":
            return Qt.rect(o0, a0, lo, la);
        default:
            return Qt.rect(view.sw - o0 - lo, a0, lo, la);
        }
    }

    // What the window needs for its mask: where the line's grip is (on the
    // screen), and the popout.
    readonly property rect gripRect: Qt.rect(grip.x, grip.y, grip.width, grip.height)
    readonly property Item popoutItem: popout
    // (For tests: the line's grip and the strip's.)
    readonly property Item gripItem: grip
    readonly property Item stripGripItem: stripGrip
    readonly property Item stripItem: strip

    // ── Its states ──────────────────────────────────────────────────────────
    // The pill, while the pointer rests on the line.
    property bool peeking: false
    property real peekT: view.peeking && Services.EdgeLine.peek && !view.dragging ? 1 : 0
    // Opened out. It starts once the surface covers the screen: the line
    // stretches along the border into the strip (openA), the popout comes
    // up round it (openB), then what's in it (openC).
    property real openT: Services.EdgeLine.open && view.full && !view.dragging ? 1 : 0
    readonly property real raised: Math.max(view.peekT, view.openT)
    readonly property real openA: view.clamp(view.openT / 0.45, 0, 1)
    readonly property real openB: view.clamp((view.openT - 0.3) / 0.7, 0, 1)
    readonly property real openC: view.clamp((view.openT - 0.55) / 0.45, 0, 1)
    readonly property bool panelUp: Services.EdgeLine.open || view.openT > 0.001
    // Fully open: from here on the popout follows its tabs' shapes.
    readonly property bool settled: view.openT >= 1

    Behavior on peekT {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }
    Behavior on openT {
        NumberAnimation {
            duration: 380
            easing.type: Easing.OutCubic
        }
    }

    // The surface covers the screen while it's open, opening, folding or
    // held, and is the small box otherwise.
    readonly property bool big: view.held || view.panelUp

    // The small box: round the line, roomy enough for the pill.
    // (Fixed: the pill's content changes, the surface shouldn't.)
    readonly property real boxAlong: view.horizontal ? Math.max(view.lineLen + 40, 540) : Math.max(view.lineLen + 40, 320)
    // (and for the name of the pill's tool under the pointer, beside it:
    // out from a border lying flat, inwards from a standing one)
    readonly property real boxOut: Math.ceil(view.lineGap + view.pillThick + 14) + (view.horizontal ? 40 : 260)
    readonly property real boxStart: Math.round(view.clamp(view.along - view.boxAlong / 2, 0, view.edgeLen - view.boxAlong))
    readonly property rect box: view.rectOn(view.edge, view.boxStart, view.boxAlong, view.inset, view.boxOut)

    property bool keyboardReady: false

    Timer {
        id: keyboardDelay
        interval: 150
        onTriggered: view.keyboardReady = Services.EdgeLine.open
    }

    Connections {
        target: Services.EdgeLine
        function onOpenChanged() {
            if (Services.EdgeLine.open) {
                // (the line's grip stops hearing the pointer while it's
                // open: it's back to a line once it has folded up)
                view.peeking = false;
                view.shownTab = Services.EdgeLine.activeTab;
                view.contentT = 1;
                keyboardDelay.restart();
                // Opened from elsewhere (a key): it waits a while for the
                // pointer before folding up again.
                if (!stageHover.hovered && Services.EdgeLine.closeOnLeave) {
                    leaveTimer.interval = Math.max(8000, Services.EdgeLine.closeDelay);
                    leaveTimer.restart();
                }
            } else {
                keyboardDelay.stop();
                view.keyboardReady = false;
                leaveTimer.stop();
            }
        }
        // Another tab: what's showing fades, the popout takes the new
        // tab's shape, and its panes come in.
        function onActiveTabChanged() {
            if (view.settled)
                tabSwap.restart();
            else
                view.shownTab = Services.EdgeLine.activeTab;
        }
        function onTabsChanged() {
            if (!tabSwap.running)
                view.shownTab = Services.EdgeLine.activeTab;
        }
    }

    // A full-screen panel came up over it (the launcher, the wallpapers…):
    // it folds up and makes way.
    onCoveredChanged: {
        if (view.covered && Services.EdgeLine.open)
            Services.EdgeLine.setOpen(false);
    }

    // ── Colours: the bar's (services/BarSettings), so the line is the bar
    // folded up; the accent is the theme's where it reads on them.
    readonly property color fill: Services.BarSettings.fill
    readonly property color ink: Services.BarSettings.ink
    readonly property real fillAlpha: Math.max(0.88, Services.BarSettings.fillOpacity)
    readonly property color accent: Services.BarSettings.contrast(ControlStyle.accent, view.fill) >= 2.4 ? ControlStyle.accent : Services.BarSettings.highlight
    readonly property var look: Services.DesktopTheme.look
    readonly property bool lowBattery: Services.Battery.ready && !Services.Battery.charging && Services.Battery.percentage <= 15

    // ── Workspaces, for the line and the strip ──────────────────────────────
    // (0 on a special workspace: nothing is lit)
    readonly property int focusedWs: Math.max(0, Hyprland.focusedWorkspace?.id ?? 1)
    readonly property var normalWs: Hyprland.workspaces.values.filter(w => w.id > 0)
    readonly property int wsCount: Math.max(5, view.focusedWs, ...view.normalWs.map(w => w.id))

    function occupied(id) {
        const ws = view.normalWs.find(w => w.id === id);
        return !!ws && ws.toplevels.values.length > 0;
    }

    // ── The line and the pill ───────────────────────────────────────────────
    readonly property real alongStart: view.startOf(view.edge)
    readonly property real alongEnd: view.endOf(view.edge)
    readonly property real lineA0: view.along - view.lineLen / 2
    readonly property real pillLen: Math.min(view.boxAlong - 16, view.horizontal ? peekFace.implicitWidth + 30 : peekFace.implicitHeight + 26)
    readonly property real pillA0: view.clamp(view.along - view.pillLen / 2, view.alongStart + 4, view.alongEnd - view.pillLen - 4)
    readonly property rect lineRect: view.rectOn(view.edge, view.lineA0, view.lineLen, view.inset + view.lineGap, view.lineThick)
    readonly property rect pillRect: view.rectOn(view.edge, view.pillA0, view.pillLen, view.inset + view.lineGap, view.pillThick)

    // ── The popout ──────────────────────────────────────────────────────────
    // On the screen's bare border (no bar on this edge) it comes out of the
    // border: Popout's bubble, flush with the edge and flared into it, in
    // the colour the theme's panes are inked for. Along the bar's inner side
    // it's a box in the theme's widget frame, as the control centre wears it
    // (a quiet sheet under Still), which keeps its own room: Cathedral's
    // arch, Mainframe's tab, Siege's crossbar and swallowtail, Cave Abode's
    // seal.
    readonly property bool attached: view.inset === 0
    readonly property bool bare: ControlStyle.frame === "bare"
    readonly property real flare: Services.DesktopTheme.controlRadius >= 0 ? 24 : 40
    readonly property real farCorner: Math.max(1, Services.DesktopTheme.panelRadius(26))
    readonly property color sheetFill: ControlStyle.paper ? "#ece5d4" : ControlStyle.darkFrame && !ControlStyle.darkScheme ? Colors.inverse_surface : Colors.surface_container
    readonly property var boxFrame: view.attached ? null : frameLoader.item
    // Its padding on each side of the screen: a little on the border's side
    // when it comes out of it; the frame's own room as a box.
    readonly property real padEdge: 10
    readonly property real padLeft: view.attached && view.edge === "left" ? view.padEdge : 16
    readonly property real padRight: view.attached && view.edge === "right" ? view.padEdge : 16
    readonly property real padTop: view.attached ? (view.edge === "top" ? view.padEdge : 16) : 16 + (view.boxFrame ? view.boxFrame.headRoomAll : 0) + (ControlStyle.frame === "scroll" ? 22 : 0)
    readonly property real padFoot: view.attached ? (view.edge === "bottom" ? view.padEdge : 16) : 16 + (view.boxFrame ? view.boxFrame.footRoom : 0)
    readonly property real stripThick: view.horizontal ? 44 : 48
    readonly property real stripGap: 10
    readonly property real cellGap: 12
    readonly property real cellPad: 14
    readonly property real popGap: 6

    // The tab showing: the chosen one, a beat behind while they swap.
    property int shownTab: Services.EdgeLine.activeTab
    readonly property var shownPanes: (Services.EdgeLine.tabs[Math.min(view.shownTab, Services.EdgeLine.tabs.length - 1)] ?? { panels: [] }).panels
    // The panes' fade through a swap.
    property real contentT: 1

    SequentialAnimation {
        id: tabSwap
        NumberAnimation {
            target: view
            property: "contentT"
            to: 0
            duration: 90
            easing.type: Easing.InQuad
        }
        ScriptAction {
            script: view.shownTab = Services.EdgeLine.activeTab
        }
        NumberAnimation {
            target: view
            property: "contentT"
            to: 1
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    // The collage's room: the screen along the border (clear of the bar),
    // and most of the way across it.
    readonly property real roomAcross: (view.horizontal ? view.sh : view.sw) - view.inset - view.insetOf(view.opposite(view.edge)) - view.popGap - view.margin
    readonly property real flareAlong: view.attached ? 2 * view.flare : 0
    readonly property real maxCollageW: view.horizontal ? view.alongEnd - view.alongStart - 2 * view.margin - view.padLeft - view.padRight - view.flareAlong : view.roomAcross * 0.72 - view.stripThick - view.stripGap - view.padLeft - view.padRight
    readonly property real maxCollageH: view.horizontal ? view.roomAcross * 0.85 - view.stripThick - view.stripGap - view.padTop - view.padFoot : view.alongEnd - view.alongStart - 2 * view.margin - view.padTop - view.padFoot - view.flareAlong

    // The panes as they measure now, and as they usually do (which picks
    // the arrangement of a tab not arranged by hand, so it keeps its shape
    // while what they show comes and goes).
    readonly property int shownIndex: Math.min(view.shownTab, Services.EdgeLine.tabs.length - 1)
    readonly property var paneItems: view.shownPanes.map(id => {
            const s = Services.EdgeLine.panelSize(id);
            return { id: id, w: s[0] + 2 * view.cellPad, h: s[1] + 2 * view.cellPad };
        })
    readonly property var collage: Services.EdgeLine.layoutFor(view.shownIndex, view.paneItems, view.shownPanes.map(id => {
            const g = Services.EdgeLine.panelGuess[id] ?? [300, 200];
            return { id: id, w: g[0] + 2 * view.cellPad, h: g[1] + 2 * view.cellPad };
        }), view.cellGap, view.maxCollageW, view.maxCollageH, view.horizontal, view.horizontal ? strip.naturalLength : 0, view.horizontal ? 0 : strip.naturalLength)
    readonly property real collageW: view.collage ? view.collage.w : 0
    readonly property real collageH: view.collage ? view.collage.h : 0

    // Its size for the tab showing (the flares too, out of the border), and
    // where that puts it: on the border, or clear of the bar.
    readonly property real innerAlong: Math.max(view.horizontal ? view.collageW : view.collageH, strip.naturalLength)
    readonly property real bodyW: view.horizontal ? view.innerAlong + view.padLeft + view.padRight : view.padLeft + view.stripThick + view.stripGap + view.collageW + view.padRight
    readonly property real bodyH: view.horizontal ? view.padTop + view.stripThick + view.stripGap + view.collageH + view.padFoot : view.padTop + view.innerAlong + view.padFoot
    readonly property real targetW: view.bodyW + (view.horizontal ? view.flareAlong : 0)
    readonly property real targetH: view.bodyH + (view.horizontal ? 0 : view.flareAlong)

    function popRectFor(w, h) {
        const la = view.horizontal ? w : h, lo = view.horizontal ? h : w;
        const a0 = view.clamp(view.along - la / 2, view.alongStart + view.margin, view.alongEnd - view.margin - la);
        return view.rectOn(view.edge, Math.round(a0), la, view.attached ? 0 : view.inset + view.popGap, lo);
    }

    // The body: the popout less its flares.
    function bodyOf(r) {
        const f = view.attached ? view.flare : 0;
        return view.horizontal ? Qt.rect(r.x + f, r.y, r.width - 2 * f, r.height) : Qt.rect(r.x, r.y + f, r.width, r.height - 2 * f);
    }

    // Where it's going (the strip and the panes go straight there) …
    readonly property rect targetRect: view.popRectFor(view.targetW, view.targetH)
    // … and where its frame is on the way, growing or shrinking to a new
    // tab's shape.
    property real frameW: view.targetW
    property real frameH: view.targetH
    readonly property rect frameRect: view.popRectFor(view.frameW, view.frameH)

    Behavior on frameW {
        enabled: view.settled
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }
    Behavior on frameH {
        enabled: view.settled
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    // Inside its padding: the strip on the border's side, the collage
    // beyond it.
    readonly property rect bodyRect: view.bodyOf(view.targetRect)
    readonly property rect innerRect: Qt.rect(view.bodyRect.x + view.padLeft, view.bodyRect.y + view.padTop, view.bodyRect.width - view.padLeft - view.padRight, view.bodyRect.height - view.padTop - view.padFoot)
    readonly property rect stripRect: {
        const r = view.innerRect, t = view.stripThick;
        switch (view.edge) {
        case "top":
            return Qt.rect(r.x, r.y, r.width, t);
        case "bottom":
            return Qt.rect(r.x, r.y + r.height - t, r.width, t);
        case "left":
            return Qt.rect(r.x, r.y, t, r.height);
        default:
            return Qt.rect(r.x + r.width - t, r.y, t, r.height);
        }
    }
    readonly property rect collageRect: {
        const r = view.innerRect, d = view.stripThick + view.stripGap;
        switch (view.edge) {
        case "top":
            return Qt.rect(r.x, r.y + d, r.width, r.height - d);
        case "bottom":
            return Qt.rect(r.x, r.y, r.width, r.height - d);
        case "left":
            return Qt.rect(r.x + d, r.y, r.width - d, r.height);
        default:
            return Qt.rect(r.x, r.y, r.width - d, r.height);
        }
    }
    readonly property var cellRects: view.collage ? Services.EdgeLine.cells(view.collage, view.collageRect.x, view.collageRect.y, view.collageRect.width, view.collageRect.height, view.cellGap, {}) : ({})

    // The line, swollen into the pill, or stretched as it opens: out of the
    // border, along it to the popout's foot (the popout comes up out of
    // it); as a box, into the strip (the box comes up round it).
    readonly property rect restRect: view.mixRect(view.lineRect, view.pillRect, view.peekT)
    readonly property rect slotRect: view.horizontal
        ? Qt.rect(view.bodyRect.x, view.edge === "top" ? 0 : view.sh - view.lineThick - 2, view.bodyRect.width, view.lineThick + 2)
        : Qt.rect(view.edge === "left" ? 0 : view.sw - view.lineThick - 2, view.bodyRect.y, view.lineThick + 2, view.bodyRect.height)
    readonly property rect morphRect: view.mixRect(view.restRect, view.attached ? view.slotRect : view.stripRect, view.openA)
    readonly property real surfaceRadius: Services.DesktopTheme.radius(view.look, 14, 44)

    // ── Folding up once it's left ───────────────────────────────────────────
    // Typing in it (a note, a password) keeps it open.
    readonly property var focusItem: view.Window.activeFocusItem
    readonly property bool typing: view.focusItem !== null && view.focusItem !== undefined && ("cursorPosition" in view.focusItem)

    Timer {
        id: leaveTimer
        interval: Services.EdgeLine.closeDelay
        onTriggered: {
            if (Services.EdgeLine.open && !stageHover.hovered && !view.held && !view.typing && !Services.EdgeLine.arranging)
                Services.EdgeLine.setOpen(false);
        }
    }

    function hoverChanged(on) {
        if (!Services.EdgeLine.open || !Services.EdgeLine.closeOnLeave)
            return;
        if (on) {
            leaveTimer.stop();
        } else {
            leaveTimer.interval = Services.EdgeLine.closeDelay;
            leaveTimer.restart();
        }
    }

    // ── Pressing and dragging ───────────────────────────────────────────────
    property point pressPoint: Qt.point(0, 0)
    // Pressed on the strip (a click there folds it up), and whether to open
    // out again where it's dropped.
    property bool fromStrip: false
    property bool reopen: false

    // The nearest border to a point: the screen split along its diagonals.
    function edgeAt(p) {
        const d = { top: p.y / view.sh, bottom: 1 - p.y / view.sh, left: p.x / view.sw, right: 1 - p.x / view.sw };
        let best = "bottom";
        for (const k of ["top", "bottom", "left", "right"])
            if (d[k] < d[best])
                best = k;
        return best;
    }

    function press(p, onStrip) {
        view.pressPoint = p;
        view.pressTool = onStrip || Services.EdgeLine.open ? "" : view.toolAt(p);
        view.fromStrip = onStrip;
        view.reopen = false;
        view.dragEdge = Services.EdgeLine.edge;
        view.dragAlong = view.along;
        view.held = true;
    }

    function move(p) {
        if (!view.held || !view.full)
            return;
        if (!view.dragging) {
            if (Math.hypot(p.x - view.pressPoint.x, p.y - view.pressPoint.y) < 7)
                return;
            view.reopen = Services.EdgeLine.open;
            Services.EdgeLine.dragging = true;
            Services.EdgeLine.setOpen(false);
            view.peeking = false;
        }
        const e = view.edgeAt(p);
        view.dragEdge = e;
        view.dragAlong = view.alongOf(e, (e === "top" || e === "bottom" ? p.x : p.y) / view.lengthOf(e));
    }

    function release() {
        if (!view.held)
            return;
        if (view.dragging) {
            Services.EdgeLine.place(view.dragEdge, view.dragAlong / view.lengthOf(view.dragEdge));
            Services.EdgeLine.dragging = false;
            if (view.reopen)
                Services.EdgeLine.setOpen(true);
        } else if (view.fromStrip) {
            Services.EdgeLine.setOpen(false);
        } else if (view.pressTool !== "") {
            view.useTool(view.pressTool);
        } else {
            Services.EdgeLine.setOpen(!Services.EdgeLine.open);
        }
        view.held = false;
    }

    // ── The pill's screen tools ─────────────────────────────────────────────
    // The tool pressed on (it's used if the press doesn't become a drag).
    property string pressTool: ""

    // The tool at a point (view coordinates), while the pill shows them.
    function toolAt(p) {
        if (view.peekT < 0.6 || !peekFace.visible)
            return "";
        const q = peekFace.mapFromItem(view, p.x, p.y);
        return peekFace.toolAt(q.x, q.y);
    }

    function pointTool(p) {
        peekFace.hot = view.held ? "" : view.toolAt(p);
    }

    function useTool(t) {
        const rec = Services.ScreenRecord;
        if (t === "shot") {
            // (out of the way of the selection)
            view.peeking = false;
            rec.screenshot("area");
        } else if (t === "record") {
            rec.toggle();
        } else if (t === "sound") {
            rec.toggleSound();
        }
    }

    function cancel() {
        if (view.dragging)
            Services.EdgeLine.dragging = false;
        view.held = false;
    }

    // Hovering the line: the pill after a moment, gone a moment after.
    function lineHover(on) {
        if (!on)
            peekFace.hot = "";
        if (on) {
            Services.ScreenRecord.look();
            unpeek.stop();
            if (!view.peeking)
                dwell.restart();
        } else {
            dwell.stop();
            unpeek.restart();
        }
    }

    Timer {
        id: dwell
        interval: 140
        onTriggered: view.peeking = grip.containsMouse
    }

    Timer {
        id: unpeek
        interval: 280
        onTriggered: if (!grip.containsMouse) view.peeking = false
    }

    // ── Keys ────────────────────────────────────────────────────────────────
    // Esc folds it up, from wherever the keyboard is in it (a field that
    // uses Esc itself takes it first); Tab and the number keys go through
    // the tabs (a field being typed into keeps those).
    Keys.onPressed: event => {
        const n = Services.EdgeLine.tabs.length;
        if (event.key === Qt.Key_Escape) {
            if (Services.EdgeLine.arranging)
                Services.EdgeLine.setArranging(false);
            else
                Services.EdgeLine.setOpen(false);
        } else if (event.key === Qt.Key_Tab && n > 1) {
            Services.EdgeLine.setActiveTab((Services.EdgeLine.activeTab + 1) % n);
        } else if (event.key === Qt.Key_Backtab && n > 1) {
            Services.EdgeLine.setActiveTab((Services.EdgeLine.activeTab + n - 1) % n);
        } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9 && event.key - Qt.Key_1 < n) {
            Services.EdgeLine.setActiveTab(event.key - Qt.Key_1);
        } else {
            return;
        }
        event.accepted = true;
    }

    // ── What's drawn ────────────────────────────────────────────────────────
    SystemClock {
        id: minuteClock
        precision: SystemClock.Minutes
    }

    // Everything that takes the pointer is in here. Over the open popout
    // (the mask leaves the rest to the windows below), and over the whole
    // screen while held: there, losing it means the pointer went to another
    // surface, where Qt hears no release.
    HoverHandler {
        id: stageHover
        onHoveredChanged: {
            if (!hovered && view.held && view.full)
                lostTimer.restart();
            else if (hovered)
                lostTimer.stop();
            view.hoverChanged(hovered);
        }
    }

    // Growing to the screen on a press, the surface hears the pointer
    // leave and come straight back: only a pointer that stays away has
    // gone. Carried, it's dropped where it is; merely pressed, it's let
    // go of (not taken for a click).
    Timer {
        id: lostTimer
        interval: 180
        onTriggered: {
            if (stageHover.hovered || !view.held)
                return;
            if (view.dragging)
                view.release();
            else
                view.cancel();
        }
    }

    FocusScope {
        anchors.fill: parent
        focus: true

        // Where it can go, while it's dragged: a faint rail along each
        // border.
        Repeater {
            model: view.dragging ? ["top", "bottom", "left", "right"] : []

            Rectangle {
                id: rail
                required property string modelData
                readonly property bool lit: rail.modelData === view.dragEdge
                readonly property rect r: view.rectOn(rail.modelData, view.startOf(rail.modelData) + 8, view.endOf(rail.modelData) - view.startOf(rail.modelData) - 16, view.insetOf(rail.modelData) + view.lineGap, view.lineThick)
                x: rail.r.x
                y: rail.r.y
                width: rail.r.width
                height: rail.r.height
                radius: view.lineThick / 2
                color: Colors.withAlpha(view.accent, rail.lit ? 0.32 : 0.14)

                Behavior on color {
                    ColorAnimation {
                        duration: 140
                    }
                }
            }
        }

        // The popout, the strip and the panes, as one sheet: out of the
        // border it slides out from under it as it opens (it's flush with
        // the border, its flares into it); as a box it comes up from the
        // bar's side, fading in.
        Item {
            id: sheet

            anchors.fill: parent
            visible: view.openB > 0.01 || (view.held && view.fromStrip)
            opacity: view.attached ? Math.min(1, view.openB * 4) : view.openB

            transform: Translate {
                readonly property real d: (1 - view.openB) * (view.attached ? (view.horizontal ? view.frameH : view.frameW) + 4 : 18)
                x: view.edge === "left" ? -d : view.edge === "right" ? d : 0
                y: view.edge === "top" ? -d : view.edge === "bottom" ? d : 0
            }

            Item {
                id: popout

                x: view.frameRect.x
                y: view.frameRect.y
                width: view.frameRect.width
                height: view.frameRect.height

                Loader {
                    id: frameLoader
                    anchors.fill: parent
                    sourceComponent: view.attached ? bubbleC : boxC
                }
            }

            // The panes of the tab showing, each in its cell of the collage.
            Item {
                id: panes
                anchors.fill: parent
                opacity: view.openC * view.contentT
                visible: opacity > 0.01

                Repeater {
                    model: ScriptModel {
                        values: view.panelUp ? view.shownPanes : []
                    }

                    PaneCell {
                        host: view
                    }
                }
            }

            // Arranging the panes by hand (the strip's Arrange): a card
            // over each, to carry onto another's edge.
            Loader {
                anchors.fill: parent
                active: Services.EdgeLine.arranging && view.panelUp
                opacity: view.openC * view.contentT
                visible: opacity > 0.01

                sourceComponent: ArrangeLayer {
                    host: view
                }
            }

            // A hairline between the strip and the panes.
            Rectangle {
                readonly property rect s: view.stripRect
                readonly property real half: view.stripGap / 2
                visible: view.openC > 0.01
                opacity: view.openC
                x: view.horizontal ? s.x + 6 : view.edge === "left" ? s.x + s.width + half : s.x - half - 1
                y: view.horizontal ? (view.edge === "top" ? s.y + s.height + half : s.y - half - 1) : s.y + 6
                width: view.horizontal ? s.width - 12 : 1
                height: view.horizontal ? 1 : s.height - 12
                color: ControlStyle.line
            }

            // The strip's bare stretch: a click folds it up, a drag moves it.
            // (Kept while it's held: dragged from here, it folds up on the way,
            // and hiding the grip would cancel the drag.)
            MouseArea {
                id: stripGrip

                x: view.stripRect.x
                y: view.stripRect.y
                width: view.stripRect.width
                height: view.stripRect.height
                visible: view.openC > 0.01 || (view.held && view.fromStrip)
                enabled: view.panelUp || (view.held && view.fromStrip)
                cursorShape: view.dragging ? Qt.ClosedHandCursor : Qt.ArrowCursor

                onPressed: mouse => view.press(view.mapFromItem(stripGrip, mouse.x, mouse.y), true)
                onPositionChanged: mouse => {
                    if (stripGrip.pressed)
                        view.move(view.mapFromItem(stripGrip, mouse.x, mouse.y));
                }
                onReleased: view.release()
                onCanceled: view.cancel()
            }

            EdgeStrip {
                id: strip

                x: view.stripRect.x
                y: view.stripRect.y
                width: view.stripRect.width
                height: view.stripRect.height
                visible: view.openC > 0.01
                opacity: view.openC
                vertical: !view.horizontal
                ink: ControlStyle.ink
                accent: ControlStyle.accent
                focusedWs: view.focusedWs
                wsCount: view.wsCount
                occupied: n => view.occupied(n)
                now: minuteClock.date
                tabs: Services.EdgeLine.tabs
                activeTab: Services.EdgeLine.activeTab
                onChooseTab: i => Services.EdgeLine.setActiveTab(i)
                onTip: (item, text) => {
                    tipBox.target = item;
                    tipBox.text = text;
                }
                onUntip: item => {
                    if (tipBox.target === item)
                        tipBox.target = null;
                }
            }

        }

        // Out of the border: Popout's bubble, flared into the edge, its far
        // corners the theme's.
        Component {
            id: bubbleC

            Popout {
                alwaysBubble: true
                alignment: ({ top: 0, right: 2, bottom: 4, left: 6 })[view.edge]
                radius: view.flare
                cornerRadius: view.farCorner
                color: Colors.withAlpha(view.sheetFill, 0.97)
            }
        }

        // Along the bar: a box in the theme's frame.
        Component {
            id: boxC

            Item {
                // (what the frame keeps for itself, for the padding)
                readonly property real headRoomAll: wf.tabRoom + wf.headRoom
                readonly property real footRoom: wf.footRoom

                // Astral's glass is thin over windows: a tint behind it.
                Rectangle {
                    visible: ControlStyle.frame === "glass"
                    anchors.fill: parent
                    radius: 24
                    color: Colors.withAlpha(Colors.background, 0.55)
                }

                WidgetFrame {
                    id: wf
                    visible: !view.bare
                    anchors.fill: parent
                    themeId: ControlStyle.themeId
                    seal: "线"
                }

                // Still: a quiet sheet, no frame at all.
                Rectangle {
                    visible: view.bare
                    anchors.fill: parent
                    radius: 20
                    color: Colors.withAlpha(Colors.surface_container_low, 0.95)
                    border.width: 1
                    border.color: Colors.withAlpha(Colors.outline_variant, 0.35)
                }
            }
        }

        // The body: the line at rest (a cell for each workspace, the one
        // you're on lit), the pill, or the line stretching into the strip
        // as the popout opens round it.
        Item {
            id: body

            x: view.morphRect.x
            y: view.morphRect.y
            width: view.morphRect.width
            height: view.morphRect.height
            visible: view.openB < 0.99

            // A dark rim round the line, so it reads on any wallpaper
            // or window.
            Rectangle {
                anchors.fill: parent
                anchors.margins: -1
                radius: Math.min(width, height) / 2
                color: Colors.withAlpha(view.fill, 0.75)
                opacity: 1 - view.raised
                visible: opacity > 0.01
            }

            // The cells.
            Item {
                id: cells
                anchors.fill: parent
                opacity: 1 - view.raised
                visible: opacity > 0.01

                readonly property real cell: (view.horizontal ? width : height) / view.wsCount

                Repeater {
                    model: view.wsCount

                    Rectangle {
                        id: cellRect
                        required property int index
                        readonly property bool busy: view.occupied(cellRect.index + 1)
                        x: view.horizontal ? cellRect.index * cells.cell : 0
                        y: view.horizontal ? 0 : cellRect.index * cells.cell
                        width: view.horizontal ? cells.cell : cells.width
                        height: view.horizontal ? cells.height : cells.cell
                        topLeftRadius: cellRect.index === 0 ? view.lineThick / 2 : 0
                        bottomLeftRadius: (view.horizontal ? cellRect.index === 0 : cellRect.index === view.wsCount - 1) ? view.lineThick / 2 : 0
                        topRightRadius: (view.horizontal ? cellRect.index === view.wsCount - 1 : cellRect.index === 0) ? view.lineThick / 2 : 0
                        bottomRightRadius: cellRect.index === view.wsCount - 1 ? view.lineThick / 2 : 0
                        color: view.lowBattery ? Colors.withAlpha(Colors.error, cellRect.busy ? 0.85 : 0.5) : Colors.withAlpha(view.ink, cellRect.busy ? 0.62 : 0.3)
                    }
                }

                // The workspace you're on, sliding to it.
                Rectangle {
                    visible: view.focusedWs > 0
                    x: view.horizontal ? (view.focusedWs - 1) * cells.cell : 0
                    y: view.horizontal ? 0 : (view.focusedWs - 1) * cells.cell
                    width: view.horizontal ? cells.cell : cells.width
                    height: view.horizontal ? cells.height : cells.cell
                    radius: view.lineThick / 2
                    color: view.accent

                    Behavior on x {
                        NumberAnimation {
                            duration: 240
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on y {
                        NumberAnimation {
                            duration: 240
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                // The screen's being recorded: the line breathes red.
                Rectangle {
                    anchors.fill: parent
                    radius: view.lineThick / 2
                    color: Colors.error
                    visible: Services.ScreenRecord.recording
                    opacity: 0.9

                    SequentialAnimation on opacity {
                        running: Services.ScreenRecord.recording && cells.visible
                        loops: Animation.Infinite
                        NumberAnimation {
                            to: 0.35
                            duration: 900
                            easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            to: 0.9
                            duration: 900
                            easing.type: Easing.InOutQuad
                        }
                    }
                }

                // A notification came in: the line lights up once.
                Rectangle {
                    id: flash
                    anchors.fill: parent
                    radius: view.lineThick / 2
                    color: view.accent
                    opacity: 0
                }
            }

            // Swollen or stretching: a surface in the bar's colours, fading
            // into the popout's frame as that comes up round it.
            Rectangle {
                anchors.fill: parent
                opacity: view.raised * (1 - view.openB)
                visible: opacity > 0.01
                radius: view.mix(Math.min(width, height) / 2, view.surfaceRadius, view.openA)
                color: Colors.withAlpha(view.fill, view.fillAlpha)
                border.width: view.look.border ? 1 : Services.BarSettings.outline ? 1 : 0
                border.color: view.look.border ? Services.DesktopTheme.borderColor(view.look, Services.DesktopTheme.theme) : Services.BarSettings.outlineColor
            }
        }

        // The pill's face: the time and what's on.
        PeekFace {
            id: peekFace
            vertical: !view.horizontal
            ink: view.ink
            accent: view.accent
            now: minuteClock.date
            x: body.x + (body.width - width) / 2
            y: body.y + (body.height - height) / 2
            opacity: Math.max(0, (view.peekT - 0.35) / 0.65) * (1 - view.openA)
            visible: opacity > 0.01
        }

        // The line's own grip, at rest and as a pill: hover for the
        // pill, click to open, drag to move. It reaches the border, so
        // a pointer pushed against the screen's edge finds it.
        MouseArea {
            id: grip

            readonly property rect r: view.peekT > 0.5 && !view.panelUp
                ? view.rectOn(view.edge, view.pillA0 - 4, view.pillLen + 8, view.inset, view.lineGap + view.pillThick + 6)
                : view.rectOn(view.edge, view.lineA0 - 8, view.lineLen + 16, view.inset, view.lineGap + view.lineThick + 9)
            x: grip.r.x
            y: grip.r.y
            width: grip.r.width
            height: grip.r.height
            enabled: !view.panelUp || (view.held && !view.fromStrip)
            hoverEnabled: true
            cursorShape: view.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

            onContainsMouseChanged: if (!view.panelUp) view.lineHover(grip.containsMouse)
            onPressed: mouse => view.press(view.mapFromItem(grip, mouse.x, mouse.y), false)
            onPositionChanged: mouse => {
                if (grip.pressed)
                    view.move(view.mapFromItem(grip, mouse.x, mouse.y));
                else
                    view.pointTool(view.mapFromItem(grip, mouse.x, mouse.y));
            }
            onReleased: view.release()
            onCanceled: view.cancel()
        }

        // What the pill's tool under the pointer does, beside the pill (out
        // from the border), level with the tool, so the pill itself keeps
        // still.
        Rectangle {
            id: pillTip

            readonly property rect p: view.pillRect
            readonly property point at: peekFace.hot !== "" ? peekFace.mapToItem(view, peekFace.toolCentre(peekFace.hot).x, peekFace.toolCentre(peekFace.hot).y) : Qt.point(0, 0)
            // (kept inside the window's small box, which is all there is of it now)
            readonly property rect b: view.box

            visible: peekFace.hot !== "" && view.peekT > 0.9 && !view.held && !view.panelUp
            x: Math.round(view.edge === "left" ? pillTip.p.x + pillTip.p.width + 8 : view.edge === "right" ? pillTip.p.x - width - 8
                : view.clamp(pillTip.at.x - width / 2, pillTip.b.x + 2, pillTip.b.x + pillTip.b.width - width - 2))
            y: Math.round(view.edge === "top" ? pillTip.p.y + pillTip.p.height + 8 : view.edge === "bottom" ? pillTip.p.y - height - 8
                : view.clamp(pillTip.at.y - height / 2, pillTip.b.y + 2, pillTip.b.y + pillTip.b.height - height - 2))
            width: pillTipText.implicitWidth + 18
            height: pillTipText.implicitHeight + 10
            radius: Math.min(height / 2, view.surfaceRadius)
            color: Colors.withAlpha(view.fill, 0.96)
            border.width: 1
            border.color: Colors.withAlpha(view.ink, 0.16)

            Text {
                id: pillTipText
                anchors.centerIn: parent
                text: peekFace.hint(peekFace.hot)
                font.family: ControlStyle.body
                font.pixelSize: 12
                color: view.ink
            }
        }

        // A name on the strip (a button's, a tab's up a standing border),
        // beside it for the moment it shows.
        Rectangle {
            id: tipBox

            property Item target: null
            property string text: ""
            readonly property point at: tipBox.target ? tipBox.target.mapToItem(view, tipBox.target.width / 2, tipBox.target.height / 2) : Qt.point(0, 0)
            readonly property rect s: view.stripRect

            visible: tipBox.target !== null && view.settled && !view.held
            x: Math.round(view.edge === "left" ? tipBox.s.x + tipBox.s.width + 8 : view.edge === "right" ? tipBox.s.x - width - 8
                : view.clamp(tipBox.at.x - width / 2, 4, view.sw - width - 4))
            y: Math.round(view.edge === "top" ? tipBox.s.y + tipBox.s.height + 8 : view.edge === "bottom" ? tipBox.s.y - height - 8
                : view.clamp(tipBox.at.y - height / 2, 4, view.sh - height - 4))
            width: tipText.implicitWidth + 18
            height: tipText.implicitHeight + 10
            radius: Math.min(height / 2, view.surfaceRadius)
            color: Colors.withAlpha(view.fill, 0.96)
            border.width: 1
            border.color: Colors.withAlpha(view.ink, 0.16)

            Text {
                id: tipText
                anchors.centerIn: parent
                text: tipBox.text
                font.family: ControlStyle.body
                font.pixelSize: 12
                color: view.ink
            }
        }
    }

    // A notification came in: the line lights up once (at rest).
    readonly property int noteCount: Services.Notification.history.length
    property int seenNotes: 0
    Component.onCompleted: view.seenNotes = view.noteCount
    onNoteCountChanged: {
        if (view.noteCount > view.seenNotes && !view.panelUp)
            flashAnim.restart();
        view.seenNotes = view.noteCount;
    }

    SequentialAnimation {
        id: flashAnim
        NumberAnimation {
            target: flash
            property: "opacity"
            to: 0.9
            duration: 160
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: flash
            property: "opacity"
            to: 0
            duration: 900
            easing.type: Easing.InOutQuad
        }
    }
}
