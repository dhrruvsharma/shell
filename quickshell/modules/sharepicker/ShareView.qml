pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import qs.colors
import qs.modules.control
import qs.modules.lock
import qs.services as Services

// The screen-share picker: the desktop itself. It opens on a grab of the
// screen, so the first frame is the desktop as it was, and pulls back: the
// grab shrinks to a picture of the screen, windows come alive in their
// places (a scrolling layout's off-screen columns show past its edges), and
// the workspaces off screen line up on a shelf underneath.
//
// Bright means shared. Whatever the pointer is on stays lit and the rest goes
// down: a window, the whole screen (anywhere that isn't a window), a workspace
// on the shelf (between its windows). A click shares what's lit. A drag on a
// screen draws a region instead, which can be pulled about until it's shared
// with its button or Enter.
//
// Keys: Tab or the arrows step through everything, Enter or Space shares,
// R remembers the choice, Esc lets go of a region, then cancels. So does a
// right click; a click on nothing cancels. The wheel slides the screens
// sideways when windows reach past the view.
//
// The answer goes out after the window has gone: a share of the screen would
// otherwise start on the picker, with every window on it.
Item {
    id: view

    // Services.ScreenShare.session.
    required property var session
    // A picture to use instead of grabbing the desktop (tests).
    property url shot: ""

    // capturing, opening, open, leaving, gone.
    property string phase: "capturing"
    readonly property bool shown: phase !== "capturing" && phase !== "gone"
    readonly property bool interactive: phase === "opening" || phase === "open"
    // 0 the desktop as it was .. 1 laid out.
    property real intro: 0
    readonly property real zoom: 1 - Math.pow(1 - intro, 3)
    // What goes to the portal.
    property string answer: ""

    function seg(a, b, t) {
        return Math.max(0, Math.min(1, (t - a) / (b - a)));
    }

    function mix(a, b, t) {
        return a + (b - a) * t;
    }

    function clamp(v, low, high) {
        return Math.max(low, Math.min(high, v));
    }

    // ── What's on show ───────────────────────────────────────────────────

    readonly property var outputs: session.outputs
    readonly property var here: outputs.find(o => o.name === session.focused) ?? outputs[0]
    readonly property var stage: session.windows.filter(w => w.showing)
    readonly property var shelf: session.shelf

    function outputNamed(name) {
        return outputs.find(o => o.name === name) ?? here;
    }

    function windowsOn(entry) {
        return session.windows.filter(w => w.workspace === entry.workspace);
    }

    // The windows showing on a screen.
    function windowsIn(o) {
        return stage.filter(w => w.output === o.name || (o === here && !outputs.some(other => other.name === w.output)));
    }

    // Where a screen's windows can be seen, in layout coordinates (ShareRoom).
    function roomOf(o) {
        // The outline and the shadow of a window at the edge need a margin.
        const margin = 120;
        let left = o.x, top = o.y, right = o.x + o.w, bottom = o.y + o.h;
        for (const w of windowsIn(o)) {
            left = Math.min(left, w.x);
            top = Math.min(top, w.y);
            right = Math.max(right, w.x + w.w);
            bottom = Math.max(bottom, w.y + w.h);
        }
        left -= margin;
        top -= margin;
        right += margin;
        bottom += margin;
        for (const other of outputs) {
            const beside = other.y < o.y + o.h && other.y + other.h > o.y;
            const above = other.x < o.x + o.w && other.x + other.w > o.x;
            if (beside && other.x + other.w <= o.x)
                left = Math.max(left, other.x + other.w);
            if (beside && other.x >= o.x + o.w)
                right = Math.min(right, other.x);
            if (above && other.y + other.h <= o.y)
                top = Math.max(top, other.y + other.h);
            if (above && other.y >= o.y + o.h)
                bottom = Math.min(bottom, other.y);
        }
        return {
            x: left,
            y: top,
            w: right - left,
            h: bottom - top
        };
    }

    // ── Layout ───────────────────────────────────────────────────────────

    // 1 on a 1920 × 1200 screen.
    readonly property real sc: Math.max(0.5, Math.min(width / 1920, height / 1200))
    readonly property real side: 64 * sc
    readonly property real cardGap: 22 * sc
    // Windows, and the caption under them.
    readonly property real cardW: {
        const n = shelf.length;
        return n ? Math.min(236 * sc, (width - 2 * side - (n - 1) * cardGap) / n) : 0;
    }
    readonly property real cardH: cardW * here.h / here.w + 26
    readonly property real head: barHome + bar.height + 28 * sc
    readonly property real barHome: 22 * sc
    readonly property real foot: shelf.length ? cardH + 52 * sc : 44 * sc

    // Everything's screens, in layout coordinates.
    readonly property var box: {
        let left = Infinity, top = Infinity, right = -Infinity, bottom = -Infinity;
        for (const o of outputs) {
            left = Math.min(left, o.x);
            top = Math.min(top, o.y);
            right = Math.max(right, o.x + o.w);
            bottom = Math.max(bottom, o.y + o.h);
        }
        return {
            x: left,
            y: top,
            w: right - left,
            h: bottom - top
        };
    }
    // The scale of the screens laid out, and where layout (0, 0) ends up.
    readonly property real fit: Math.min((width - 2 * side) / box.w, (height - head - foot) / box.h, 0.8)
    readonly property real homeX: (width - box.w * fit) / 2 - box.x * fit
    readonly property real homeY: head + (height - head - foot - box.h * fit) / 2 - box.y * fit

    // How far windows reach past the view, sideways: the wheel slides to them.
    readonly property var reach: {
        let left = box.x, right = box.x + box.w;
        for (const o of outputs) {
            const r = roomOf(o);
            for (const w of windowsIn(o)) {
                left = Math.min(left, Math.max(w.x, r.x));
                right = Math.max(right, Math.min(w.x + w.w, r.x + r.w));
            }
        }
        return {
            left: left,
            right: right
        };
    }
    readonly property real panLeast: Math.min(0, width - side - (homeX + reach.right * fit))
    readonly property real panMost: Math.max(0, side - (homeX + reach.left * fit))
    property real pan: 0

    Behavior on pan {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    // The camera: layout (x, y) is at (camX + x * camS, camY + y * camS).
    readonly property real camS: mix(1, fit, zoom)
    readonly property real camX: mix(-here.x, homeX + pan, zoom)
    readonly property real camY: mix(-here.y, homeY, zoom)

    // Where something in layout coordinates is in the view.
    function inView(r) {
        return {
            x: camX + r.x * camS,
            y: camY + r.y * camS,
            w: r.w * camS,
            h: r.h * camS
        };
    }

    // ── What the pointer is on ───────────────────────────────────────────

    // What's lit: { kind, key, info }, see ScreenShare.selection().
    property var hot: null
    readonly property string hotKey: keyOf(hot)
    // How far what isn't lit goes down.
    readonly property real dim: 0.6 * seg(0.4, 1, intro)
    property int cursor: Qt.ArrowCursor

    function keyOf(target) {
        return target && target.kind !== "none" ? target.kind + ":" + target.key : "";
    }

    function outputTarget(o) {
        return {
            kind: "output",
            key: o.name,
            info: o
        };
    }

    function windowTarget(w) {
        return {
            kind: "window",
            key: w.id,
            info: w
        };
    }

    function workspaceTarget(entry) {
        return {
            kind: "workspace",
            key: entry.capture,
            info: entry
        };
    }

    // Whether a window stays bright under what's lit.
    function lit(w) {
        const t = hot;
        if (!t || t.kind === "region")
            return true;
        if (t.kind === "window")
            return t.key === w.id;
        if (t.kind === "output")
            return w.showing && w.output === t.key;
        return w.workspace === t.info.workspace;
    }

    function outputAt(px, py) {
        const x = (px - camX) / camS, y = (py - camY) / camS;
        return outputs.find(o => x >= o.x && y >= o.y && x < o.x + o.w && y < o.y + o.h) ?? null;
    }

    // What's at a point in the view: null for nothing, kind "none" for
    // something that can't be shared but isn't nothing either.
    function targetAt(px, py) {
        for (let i = 0; i < shelfCards.count; i++) {
            const card = shelfCards.itemAt(i) as ShareCard;
            if (!card)
                continue;
            const w = card.windowAt(view, px, py);
            if (w)
                return windowTarget(w.info);
            if (card.holds(view, px, py))
                return card.shareable ? workspaceTarget(card.info) : {
                    kind: "none"
                };
        }
        // Between the cards is a near miss, not a way out.
        if (shelf.length && py >= shelfRow.y && py < shelfRow.y + shelfRow.height && px >= shelfRow.x && px < shelfRow.x + shelfRow.width)
            return {
                kind: "none"
            };
        for (let i = 0; i < rooms.count; i++) {
            const w = (rooms.itemAt(i) as ShareRoom)?.windowAt(view, px, py);
            if (w)
                return windowTarget(w.info);
        }
        const o = outputAt(px, py);
        return o ? outputTarget(o) : null;
    }

    function windowItem(id) {
        for (let i = 0; i < rooms.count; i++) {
            const w = (rooms.itemAt(i) as ShareRoom)?.windowFor(id);
            if (w)
                return w;
        }
        for (let i = 0; i < shelfCards.count; i++) {
            const w = (shelfCards.itemAt(i) as ShareCard)?.windowFor(id);
            if (w)
                return w;
        }
        return null;
    }

    // Where a target is in the view.
    function rectOf(t) {
        if (t?.kind === "output" || (t?.kind === "window" && t.info.showing))
            return inView(t.info);
        let item = null;
        if (t?.kind === "window")
            item = windowItem(t.key);
        else if (t?.kind === "workspace") {
            for (let i = 0; i < shelfCards.count; i++) {
                const card = shelfCards.itemAt(i) as ShareCard;
                if (card?.key === keyOf(t))
                    item = card.surface;
            }
        }
        if (!item)
            return null;
        const r = item.mapToItem(view, 0, 0, item.width, item.height);
        return {
            x: r.x,
            y: r.y,
            w: r.width,
            h: r.height
        };
    }

    function hover(px, py) {
        if (phase !== "open")
            return;
        const zone = zoneAt(px, py);
        if (region) {
            hot = null;
            cursor = cursorFor(zone);
            return;
        }
        const t = targetAt(px, py);
        cursor = keyOf(t) !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor;
        if (keyOf(t) !== hotKey)
            hot = keyOf(t) !== "" ? t : null;
    }

    // ── Regions ──────────────────────────────────────────────────────────

    // { output, x, y, w, h }, in that screen's coordinates.
    property var region: null
    // It's still being drawn.
    property bool drawing: false
    // Smaller than this (on the screen) is a slip of the hand.
    readonly property int smallest: 24

    readonly property var regionRect: {
        if (!region)
            return null;
        const o = outputNamed(region.output);
        return {
            x: camX + (o.x + region.x) * camS,
            y: camY + (o.y + region.y) * camS,
            w: region.w * camS,
            h: region.h * camS
        };
    }

    // The part of a region a point is on: an edge or corner, "move", or "".
    function zoneAt(px, py) {
        const r = regionRect;
        if (!r || drawing)
            return "";
        const grip = 10;
        if (px < r.x - grip || px > r.x + r.w + grip || py < r.y - grip || py > r.y + r.h + grip)
            return "";
        const v = py < r.y + grip ? "n" : py > r.y + r.h - grip ? "s" : "";
        const h = px < r.x + grip ? "w" : px > r.x + r.w - grip ? "e" : "";
        return v + h || "move";
    }

    function cursorFor(zone) {
        return ({
                "": Qt.ArrowCursor,
                move: Qt.SizeAllCursor,
                n: Qt.SizeVerCursor,
                s: Qt.SizeVerCursor,
                e: Qt.SizeHorCursor,
                w: Qt.SizeHorCursor,
                nw: Qt.SizeFDiagCursor,
                se: Qt.SizeFDiagCursor,
                ne: Qt.SizeBDiagCursor,
                sw: Qt.SizeBDiagCursor
            })[zone];
    }

    // A point in the view, on a screen, kept on that screen.
    function onOutput(o, px, py) {
        return {
            x: clamp(Math.round((px - camX) / camS - o.x), 0, o.w),
            y: clamp(Math.round((py - camY) / camS - o.y), 0, o.h)
        };
    }

    function regionBetween(o, a, b) {
        return {
            output: o.name,
            x: Math.min(a.x, b.x),
            y: Math.min(a.y, b.y),
            w: Math.abs(a.x - b.x),
            h: Math.abs(a.y - b.y)
        };
    }

    // `from` with a part of it pulled by (dx, dy), kept on its screen.
    function pulled(from, zone, dx, dy) {
        const o = outputNamed(from.output);
        if (zone === "move")
            return Object.assign({}, from, {
                x: clamp(from.x + dx, 0, o.w - from.w),
                y: clamp(from.y + dy, 0, o.h - from.h)
            });
        let left = from.x, top = from.y, right = from.x + from.w, bottom = from.y + from.h;
        if (zone.includes("w"))
            left = clamp(left + dx, 0, right - smallest);
        if (zone.includes("e"))
            right = clamp(right + dx, left + smallest, o.w);
        if (zone.includes("n"))
            top = clamp(top + dy, 0, bottom - smallest);
        if (zone.includes("s"))
            bottom = clamp(bottom + dy, top + smallest, o.h);
        return {
            output: from.output,
            x: left,
            y: top,
            w: right - left,
            h: bottom - top
        };
    }

    function regionTarget() {
        return Object.assign({
            kind: "region",
            key: ""
        }, region);
    }

    // ── Keys ─────────────────────────────────────────────────────────────

    // Everything there is, in order, for Tab.
    readonly property var targets: {
        const list = outputs.map(o => outputTarget(o));
        for (let i = stage.length - 1; i >= 0; i--)
            list.push(windowTarget(stage[i]));
        for (const entry of shelf) {
            if (entry.capture > 0)
                list.push(workspaceTarget(entry));
            if (!entry.showing)
                list.push(...windowsOn(entry).map(w => windowTarget(w)));
        }
        return list;
    }

    function step(by) {
        if (phase !== "open" || region || !targets.length)
            return;
        const at = targets.findIndex(t => keyOf(t) === hotKey);
        const next = at < 0 ? (by > 0 ? 0 : targets.length - 1) : (at + by + targets.length) % targets.length;
        hot = targets[next];
        // Bring a window past the view's edge into it.
        if (hot.kind === "window" && hot.info.showing) {
            const left = homeX + hot.info.x * fit, right = left + hot.info.w * fit;
            if (left + pan < side)
                pan = clamp(side - left, panLeast, panMost);
            else if (right + pan > width - side)
                pan = clamp(width - side - right, panLeast, panMost);
        }
    }

    function back() {
        if (region) {
            region = null;
            drawing = false;
        } else {
            leave(null);
        }
    }

    function choose() {
        if (region && !drawing)
            leave(regionTarget());
        else if (hot)
            leave(hot);
    }

    Keys.onPressed: event => {
        const k = event.key;
        if (k === Qt.Key_Escape)
            back();
        else if (k === Qt.Key_Tab || k === Qt.Key_Right || k === Qt.Key_Down)
            step(1);
        else if (k === Qt.Key_Backtab || k === Qt.Key_Left || k === Qt.Key_Up)
            step(-1);
        else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)
            choose();
        else if (k === Qt.Key_R)
            Services.ScreenShare.remember = !Services.ScreenShare.remember;
        else
            return;
        event.accepted = true;
    }

    // ── Opening and leaving ──────────────────────────────────────────────

    property bool _waiting: false

    function show() {
        if (phase !== "capturing")
            return;
        phase = "opening";
        forceActiveFocus();
        // The zoom starts on the first frame of the window, or it would jump.
        _waiting = true;
        startAnyway.restart();
        Services.ScreenShare.shown();
    }

    function start() {
        _waiting = false;
        startAnyway.stop();
        introAnim.restart();
    }

    // Goes back to the desktop, with what was chosen (null for nothing).
    function leave(target) {
        if (!interactive)
            return;
        answer = Services.ScreenShare.selection(target);
        introAnim.stop();
        _waiting = false;
        startAnyway.stop();
        phase = "leaving";
        outroAnim.duration = Math.max(1, 340 * intro);
        outroAnim.restart();
    }

    Connections {
        target: view.Window.window
        enabled: view._waiting

        function onFrameSwapped() {
            view.start();
        }
    }

    // in case that frame never comes
    Timer {
        id: startAnyway

        interval: 200
        onTriggered: view.start()
    }

    NumberAnimation {
        id: introAnim

        target: view
        property: "intro"
        to: 1
        duration: 560
        onFinished: {
            if (view.phase !== "opening")
                return;
            view.phase = "open";
            if (pointer.awake)
                view.hover(pointer.mouseX, pointer.mouseY);
        }
    }

    NumberAnimation {
        id: outroAnim

        target: view
        property: "intro"
        to: 0
        onFinished: {
            view.phase = "gone";
            handOver.restart();
        }
    }

    // Long enough for the surface to be off the screen.
    Timer {
        id: handOver

        interval: 90
        onTriggered: Services.ScreenShare.finish(view.answer)
    }

    // ── The desktop, grabbed ─────────────────────────────────────────────

    LazyLoader {
        id: capture

        active: view.shot.toString() === ""

        ScreenCapture {
            timeoutMs: 260
            onFinished: view.show()
        }
    }

    readonly property var shots: (capture.item as ScreenCapture)?.shots ?? ({})
    readonly property url wallpaper: "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"

    function shotOf(name) {
        if (shot.toString() !== "")
            return shot;
        return shots[name]?.url ?? wallpaper;
    }

    Component.onCompleted: {
        if (shot.toString() !== "")
            show();
    }

    // ── What's behind it all ─────────────────────────────────────────────

    // Opaque from the start: the screen covers it until it pulls back, and
    // fading it in would let the real desktop show through.
    Item {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: Colors.background
        }

        Image {
            id: behind

            anchors.fill: parent
            visible: false
            source: view.shown ? view.shotOf(view.here.name) : ""
            sourceSize: Qt.size(640, 400)
            fillMode: Image.PreserveAspectCrop
            cache: false
        }

        MultiEffect {
            anchors.fill: parent
            source: behind
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: 48
            saturation: -0.2
        }

        Rectangle {
            anchors.fill: parent
            color: Colors.withAlpha(Colors.background, 0.74)
        }
    }

    // ── The screens, and the windows on them ─────────────────────────────

    Item {
        id: world

        x: view.camX
        y: view.camY
        scale: view.camS
        transformOrigin: Item.TopLeft

        Repeater {
            model: view.outputs

            Item {
                id: screenItem

                required property var modelData
                readonly property bool lit: {
                    const t = view.hot;
                    return !t || t.key === modelData.name || (t.kind === "workspace" && t.info.showing && t.info.output === modelData.name);
                }

                x: modelData.x
                y: modelData.y
                width: modelData.w
                height: modelData.h

                RectangularShadow {
                    anchors.fill: parent
                    blur: 60
                    spread: 4
                    color: "#a0000000"
                    opacity: view.zoom
                    cached: true
                }

                Rectangle {
                    anchors.fill: parent
                    color: Colors.background
                }

                Image {
                    anchors.fill: parent
                    source: view.shown ? view.shotOf(screenItem.modelData.name) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: false
                    cache: false
                    smooth: true
                }

                Rectangle {
                    anchors.fill: parent
                    color: "black"
                    opacity: screenItem.lit ? 0 : view.dim

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 140
                        }
                    }
                }
            }
        }

        Repeater {
            id: rooms

            model: view.outputs

            ShareRoom {
                required property var modelData

                bounds: view.roomOf(modelData)
                windows: view.windowsIn(modelData)
                owner: view
            }
        }

        // The screens' edges, over anything that reaches past them.
        Repeater {
            model: view.outputs

            Rectangle {
                id: edge

                required property var modelData
                readonly property bool hot: view.hotKey === "output:" + modelData.name
                readonly property real line: (hot ? 3 : 1) / view.fit

                x: modelData.x - line
                y: modelData.y - line
                width: modelData.w + 2 * line
                height: modelData.h + 2 * line
                color: "transparent"
                border.width: line
                border.color: hot ? ControlStyle.accent : Colors.withAlpha(Colors.on_surface, 0.28)
                opacity: view.zoom
            }
        }
    }

    // ── The workspaces off screen ────────────────────────────────────────

    Item {
        id: shelfRow

        readonly property real rise: view.seg(0.3, 1, view.intro)

        x: (view.width - width) / 2
        y: view.height - view.foot + 28 * view.sc + (1 - rise) * 50 * view.sc
        width: view.shelf.length * (view.cardW + view.cardGap) - view.cardGap
        height: view.cardH
        opacity: rise

        Repeater {
            id: shelfCards

            model: view.shelf

            ShareCard {
                required property var modelData
                required property int index

                x: index * (view.cardW + view.cardGap)
                width: view.cardW
                height: view.cardH
                info: modelData
                windows: view.windowsOn(modelData)
                output: view.outputNamed(modelData.output)
                owner: view
                rounding: view.session.rounding
            }
        }
    }

    // ── The pointer ──────────────────────────────────────────────────────

    MouseArea {
        id: pointer

        // "press", "draw", or the part of a region being pulled.
        property string action: ""
        property bool moved: false
        // The pointer has moved since the picker opened. Nothing lights up
        // until then: a surface appearing under it counts as motion to Qt.
        property bool awake: false
        property point rest: Qt.point(-1, -1)
        property real fromX: 0
        property real fromY: 0
        property var fromTarget: null
        property var fromOutput: null
        property var fromRegion: null

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: view.cursor

        onPressed: mouse => {
            if (!view.interactive)
                return;
            if (mouse.button === Qt.RightButton) {
                view.back();
                return;
            }
            fromX = mouse.x;
            fromY = mouse.y;
            moved = false;
            fromTarget = view.targetAt(mouse.x, mouse.y);
            fromOutput = view.outputAt(mouse.x, mouse.y);
            fromRegion = view.region;
            action = view.zoneAt(mouse.x, mouse.y) || "press";
        }

        onPositionChanged: mouse => {
            if (!awake) {
                if (rest.x < 0)
                    rest = Qt.point(mouse.x, mouse.y);
                awake = Math.hypot(mouse.x - rest.x, mouse.y - rest.y) >= 4;
            }
            if (!pressed || !action) {
                if (awake)
                    view.hover(mouse.x, mouse.y);
                return;
            }
            if (!moved && Math.hypot(mouse.x - fromX, mouse.y - fromY) >= 6)
                moved = true;
            if (action === "press" && moved && fromOutput) {
                action = "draw";
                view.hot = null;
                view.drawing = true;
            }
            if (action === "draw") {
                view.region = view.regionBetween(fromOutput, view.onOutput(fromOutput, fromX, fromY), view.onOutput(fromOutput, mouse.x, mouse.y));
            } else if (action !== "press" && moved) {
                view.region = view.pulled(fromRegion, action, Math.round((mouse.x - fromX) / view.camS), Math.round((mouse.y - fromY) / view.camS));
            }
        }

        onReleased: mouse => {
            const did = action;
            action = "";
            if (!view.interactive)
                return;
            if (did === "draw") {
                view.drawing = false;
                if (view.region.w < view.smallest || view.region.h < view.smallest)
                    view.region = null;
            } else if (did === "press" && !moved) {
                // By where it was pressed: a click is on what was pressed.
                if (view.region)
                    view.region = null;
                else if (fromTarget?.kind !== "none")
                    view.leave(fromTarget);
            }
            view.hover(mouse.x, mouse.y);
        }

        onDoubleClicked: mouse => {
            if (view.zoneAt(mouse.x, mouse.y) === "move")
                view.choose();
        }

        onExited: {
            if (!pressed)
                view.hot = null;
        }

        onWheel: wheel => {
            const by = wheel.angleDelta.x !== 0 ? wheel.angleDelta.x : wheel.angleDelta.y;
            view.pan = view.clamp(view.pan + by, view.panLeast, view.panMost);
        }
    }

    // ── What's over it ───────────────────────────────────────────────────

    ShareRegion {
        anchors.fill: parent
        visible: view.region !== null
        opacity: view.zoom
        rect: view.regionRect ?? ({
                x: 0,
                y: 0,
                w: 0,
                h: 0
            })
        pixelWidth: view.region?.w ?? 0
        pixelHeight: view.region?.h ?? 0
        drawing: view.drawing
        onShareClicked: view.choose()
    }

    // The name on what's lit, above it, so it hides as little of it as it
    // can: only a window at the top of the screen has to take it on board.
    ShareTag {
        id: tag

        readonly property var spot: view.hot ? view.rectOf(view.hot) : null

        x: view.clamp(spot?.x ?? 0, 12, view.width - width - 12)
        y: view.clamp((spot?.y ?? 0) - height - 10, view.head, view.height - height - 12)
        opacity: view.hot && view.phase !== "leaving" ? 1 : 0
        icon: view.hot?.kind === "window" ? Services.AppRegistry.iconForClass(view.hot.info.class) : ""
        glyph: view.hot?.kind === "workspace" ? "workspaces" : "monitor"
        title: {
            const t = view.hot;
            if (t?.kind === "window")
                return t.info.title || t.info.class;
            if (t?.kind === "workspace")
                return "Workspace " + t.info.name;
            return "Whole screen";
        }
        detail: {
            const t = view.hot;
            if (t?.kind === "window")
                return t.info.class + (t.info.showing ? "" : " · off screen");
            if (t?.kind === "workspace")
                return t.info.windows + (t.info.windows === 1 ? " window" : " windows") + " · stays on it when you go elsewhere";
            if (t?.kind === "output")
                return t.info.name + " · " + t.info.w + " × " + t.info.h;
            return "";
        }

        Behavior on x {
            enabled: tag.opacity > 0.5
            NumberAnimation {
                duration: 130
                easing.type: Easing.OutCubic
            }
        }

        Behavior on y {
            enabled: tag.opacity > 0.5
            NumberAnimation {
                duration: 130
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 110
            }
        }
    }

    ShareBar {
        id: bar

        readonly property real rise: view.seg(0.25, 0.9, view.intro)

        width: Math.max(view.box.w * view.fit, Math.min(view.width - 2 * view.side, 1040))
        x: (view.width - width) / 2
        y: view.barHome - (1 - rise) * 40 * view.sc
        opacity: rise
        heading: ControlStyle.label(view.headings[ControlStyle.themeId] ?? view.headings[""])
        remember: Services.ScreenShare.remember
        onRememberToggled: Services.ScreenShare.remember = !Services.ScreenShare.remember
        onCancelled: view.leave(null)
    }

    // In the desktop theme's words.
    readonly property var headings: ({
            "": "Share your screen",
            hud: "Open uplink",
            terminal: "share --pick",
            cosmos: "Broadcast",
            zen: "what to show",
            xianxia: "Scrying mirror",
            cyberpunk: "Go live",
            wabisabi: "what to show",
            artdeco: "On the air",
            gothic: "The looking glass",
            newspaper: "Late edition",
            wasteland: "Signal out",
            observatory: "The eyepiece",
            abyss: "Periscope up",
            devaloka: "Darshan",
            siege: "Light the beacon",
            sekiro: "The mirror"
        })
}
