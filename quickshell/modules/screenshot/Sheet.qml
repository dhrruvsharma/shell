pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.colors
import qs.modules.control

// The shot in the editor (EditorView): the image and the marks on it
// (Mark.qml), as large as the room allows, and what the mouse does to them
// with the tool in hand. Everything is kept in the image's own pixels, and
// `render` saves what's shown, the crop at its full size, to a file.
//
// The state is { marks, crop }: the marks in the order they were made, the
// crop a rect or null. Every change makes a new state, so undo and redo
// step through them, and the shot is `edited` unless it's the first one.
// The marks are drawn in three layers: pixelated patches on the image,
// then the highlighter (one see-through layer, so strokes crossing don't
// darken), then the rest.
Item {
    id: sheet

    property url source
    // select, pen, marker, line, arrow, rect, ellipse, text, counter,
    // pixelate or crop; and the colour, size (0-2) and fill of new marks.
    property string tool: "arrow"
    property color ink: "#ff3b30"
    property int size: 1
    property bool fill: false

    readonly property bool ready: base.status === Image.Ready
    readonly property bool failed: base.status === Image.Error
    readonly property real imageWidth: base.implicitWidth
    readonly property real imageHeight: base.implicitHeight

    property var doc: ({
            marks: [],
            crop: null
        })
    property var firstDoc: doc
    property var undoStack: []
    property var redoStack: []
    property int nextId: 1
    readonly property bool edited: doc !== firstDoc
    readonly property bool canUndo: undoStack.length > 0
    readonly property bool canRedo: redoStack.length > 0

    // The mark being drawn; the one picked with the select tool, and the
    // one under the pointer (ids); how far the picked one's been dragged.
    property var live: null
    property int selectedId: -1
    property int hoverId: -1
    property bool dragging: false
    property real dragX: 0
    property real dragY: 0
    property point dragFrom

    // Text being typed: { id (-1 for new), x, y, color, size, fill }.
    property var typing: null

    // The crop being chosen: shown on the whole image while the crop tool's
    // in hand, applied when it's put down (or with Enter).
    readonly property bool cropping: tool === "crop"
    property rect cropDraft
    property var cropDrag: null
    readonly property rect full: Qt.rect(0, 0, imageWidth, imageHeight)
    readonly property rect view: cropping || !doc.crop ? full : doc.crop
    readonly property real fit: ready ? Math.min(width / view.width, height / view.height, 1) : 1
    // The size marks are drawn at, picked for the shot as it first shows: on
    // a big image shrunk to fit they look as thick as on a small one.
    property real unit: 1
    readonly property var sizes: ({
            pen: [3, 5, 9],
            marker: [12, 20, 32],
            pixelate: [8, 14, 22],
            counter: [11, 15, 21],
            text: [18, 26, 40]
        })

    readonly property var patches: doc.marks.filter(m => m.kind === "pixelate")
    readonly property var highlights: doc.marks.filter(m => m.kind === "marker")
    readonly property var inks: doc.marks.filter(m => m.kind !== "pixelate" && m.kind !== "marker")
    readonly property var selectedMark: doc.marks.find(m => m.id === selectedId) ?? null

    // A press on the shot (the editor takes the keyboard back from its
    // name field), and the end of typing.
    signal touched
    signal typed

    onReadyChanged: {
        if (!ready)
            return;
        unit = Math.max(1, 1 / Math.min(width / imageWidth, height / imageHeight));
        if (cropping)
            cropDraft = full;
    }

    // ── The state ────────────────────────────────────────────────────────────

    function reset(url) {
        live = null;
        typing = null;
        selectedId = -1;
        hoverId = -1;
        dragging = false;
        cropDrag = null;
        doc = {
            marks: [],
            crop: null
        };
        firstDoc = doc;
        undoStack = [];
        redoStack = [];
        source = url;
    }

    function commit(next) {
        undoStack = undoStack.concat([doc]);
        redoStack = [];
        doc = next;
    }

    function setMarks(marks) {
        commit({
            marks: marks,
            crop: doc.crop
        });
    }

    function add(m) {
        m.id = nextId++;
        setMarks(doc.marks.concat([m]));
    }

    function replace(id, m) {
        setMarks(doc.marks.map(x => x.id === id ? m : x));
    }

    function removeMark(id) {
        if (selectedId === id)
            selectedId = -1;
        setMarks(doc.marks.filter(x => x.id !== id));
    }

    function removeSelected() {
        if (selectedId >= 0)
            removeMark(selectedId);
    }

    function undo() {
        finishTyping();
        if (!canUndo)
            return;
        redoStack = redoStack.concat([doc]);
        doc = undoStack[undoStack.length - 1];
        undoStack = undoStack.slice(0, -1);
        selectedId = -1;
        if (cropping)
            cropDraft = doc.crop ?? full;
    }

    function redo() {
        finishTyping();
        if (!canRedo)
            return;
        undoStack = undoStack.concat([doc]);
        doc = redoStack[redoStack.length - 1];
        redoStack = redoStack.slice(0, -1);
        selectedId = -1;
        if (cropping)
            cropDraft = doc.crop ?? full;
    }

    function markById(id) {
        return doc.marks.find(m => m.id === id) ?? null;
    }

    function sizeFor(kind) {
        const steps = sizes[kind] ?? sizes.pen;
        const s = steps[Math.max(0, Math.min(2, size))] * unit;
        return kind === "pixelate" ? Math.round(s) : Math.round(s * 2) / 2;
    }

    // Counters are numbered in the order they were made.
    function numberOf(m) {
        let n = 0;
        for (const x of doc.marks) {
            if (x.kind === "counter")
                n++;
            if (x === m)
                return n;
        }
        return n + 1;
    }

    // The same mark, `dx`, `dy` over.
    function shifted(m, dx, dy) {
        const c = Object.assign({}, m);
        if (m.pts)
            c.pts = m.pts.map((v, i) => v + (i % 2 ? dy : dx));
        if (m.x1 !== undefined) {
            c.x1 += dx;
            c.x2 += dx;
            c.y1 += dy;
            c.y2 += dy;
        }
        if (m.x !== undefined) {
            c.x += dx;
            c.y += dy;
        }
        return c;
    }

    // The tool, put down and picked up: a crop being chosen is applied,
    // text being typed is kept.
    function setTool(t) {
        if (t === tool)
            return;
        finishTyping();
        if (cropping)
            applyCrop();
        live = null;
        dragging = false;
        cropDrag = null;
        if (t !== "select")
            selectedId = -1;
        if (t === "crop")
            cropDraft = doc.crop ?? full;
        tool = t;
    }

    // The topmost mark at a point.
    function markAt(px, py) {
        const tol = 6 / fit;
        for (const rep of [inkMarks, highlightMarks, patchMarks]) {
            for (let i = rep.count - 1; i >= 0; i--) {
                const item = rep.itemAt(i) as Mark;
                if (item && item.hit(px, py, tol))
                    return item.mark;
            }
        }
        return null;
    }

    function itemOf(id): Mark {
        for (const rep of [inkMarks, highlightMarks, patchMarks]) {
            for (let i = 0; i < rep.count; i++) {
                const item = rep.itemAt(i) as Mark;
                if (item && item.mark && item.mark.id === id)
                    return item;
            }
        }
        return null;
    }

    // Image pixels to the sheet's, and a rect likewise.
    function toSheet(r) {
        return Qt.rect(frame.x + (r.x - view.x) * fit, frame.y + (r.y - view.y) * fit, r.width * fit, r.height * fit);
    }

    // ── Drawing ──────────────────────────────────────────────────────────────

    function clampX(x) {
        return Math.max(0, Math.min(imageWidth, x));
    }

    function clampY(y) {
        return Math.max(0, Math.min(imageHeight, y));
    }

    function startDrawing(p) {
        const m = {
            kind: tool,
            color: String(ink),
            size: sizeFor(tool)
        };
        if (tool === "pen" || tool === "marker") {
            m.pts = [p.x, p.y];
        } else {
            m.x1 = m.x2 = clampX(p.x);
            m.y1 = m.y2 = clampY(p.y);
            if (tool === "rect" || tool === "ellipse")
                m.fill = fill;
        }
        live = m;
    }

    // Shift keeps a stroke straight, a line to steps of 15°, a box square.
    function drawTo(p, shift) {
        const m = Object.assign({}, live);
        if (m.pts) {
            if (shift) {
                m.pts = [m.pts[0], m.pts[1], p.x, p.y];
            } else {
                const n = m.pts.length;
                if (Math.hypot(p.x - m.pts[n - 2], p.y - m.pts[n - 1]) < 1.5 / fit)
                    return;
                m.pts = m.pts.concat([p.x, p.y]);
            }
        } else if (m.kind === "line" || m.kind === "arrow") {
            let x = p.x, y = p.y;
            if (shift) {
                const step = Math.PI / 12;
                const a = Math.round(Math.atan2(y - m.y1, x - m.x1) / step) * step;
                const len = Math.hypot(x - m.x1, y - m.y1);
                x = m.x1 + Math.cos(a) * len;
                y = m.y1 + Math.sin(a) * len;
            }
            m.x2 = x;
            m.y2 = y;
        } else {
            let x = clampX(p.x), y = clampY(p.y);
            if (shift) {
                const side = Math.max(Math.abs(x - m.x1), Math.abs(y - m.y1));
                x = clampX(m.x1 + Math.sign(x - m.x1 || 1) * side);
                y = clampY(m.y1 + Math.sign(y - m.y1 || 1) * side);
            }
            m.x2 = x;
            m.y2 = y;
        }
        live = m;
    }

    // A click with a stroke tool leaves a dot; a click with the others,
    // nothing.
    function finishDrawing() {
        const m = live;
        live = null;
        if (!m)
            return;
        if (m.pts) {
            if (m.pts.length === 2)
                m.pts = m.pts.concat([m.pts[0] + 0.1, m.pts[1]]);
            add(m);
            return;
        }
        const w = Math.abs(m.x2 - m.x1), h = Math.abs(m.y2 - m.y1);
        const least = 4 / fit;
        if (m.kind === "line" || m.kind === "arrow" ? Math.hypot(w, h) < least : w < least || h < least)
            return;
        add(m);
    }

    // ── Picking and moving ───────────────────────────────────────────────────

    function pick(p) {
        const m = markAt(p.x, p.y);
        selectedId = m ? m.id : -1;
        if (m) {
            dragging = true;
            dragFrom = p;
            dragX = 0;
            dragY = 0;
        }
    }

    function dragTo(p) {
        dragX = p.x - dragFrom.x;
        dragY = p.y - dragFrom.y;
    }

    function drop() {
        const m = selectedMark;
        const dx = dragX, dy = dragY;
        dragging = false;
        dragX = 0;
        dragY = 0;
        if (m && (Math.abs(dx) > 0.5 || Math.abs(dy) > 0.5))
            replace(m.id, shifted(m, dx, dy));
    }

    // ── Text ─────────────────────────────────────────────────────────────────

    // New text where the click was (the middle of its first line), or the
    // mark's own to change.
    function startTyping(p, m) {
        if (m) {
            typing = {
                id: m.id,
                x: m.x,
                y: m.y,
                color: m.color,
                size: m.size,
                fill: !!m.fill
            };
            editor.text = m.text;
        } else {
            const s = sizeFor("text");
            typing = {
                id: -1,
                x: p.x - Math.round(s * 0.3),
                y: p.y - Math.round(s * 0.3) - s * 0.65,
                color: String(ink),
                size: s,
                fill: fill
            };
            editor.text = "";
        }
        selectedId = -1;
        editor.forceActiveFocus();
        editor.cursorPosition = editor.length;
    }

    function finishTyping() {
        const t = typing;
        if (!t)
            return;
        const text = editor.text.replace(/\s+$/, "");
        typing = null;
        editor.text = "";
        if (t.id >= 0) {
            const old = markById(t.id);
            if (!text)
                removeMark(t.id);
            else if (old && old.text !== text)
                replace(t.id, Object.assign({}, old, {
                    text: text
                }));
        } else if (text) {
            add({
                kind: "text",
                color: t.color,
                size: t.size,
                fill: t.fill,
                x: t.x,
                y: t.y,
                text: text
            });
        }
        typed();
    }

    // ── Cropping ─────────────────────────────────────────────────────────────

    // Grab an edge or corner of the crop to move it, the middle to move the
    // whole, or anywhere outside to draw a new one (anywhere at all while
    // it's still the whole image).
    function cropEdges(p) {
        const r = cropDraft, tol = 10 / fit;
        const inX = p.x >= r.x - tol && p.x <= r.x + r.width + tol;
        const inY = p.y >= r.y - tol && p.y <= r.y + r.height + tol;
        return {
            l: inY && Math.abs(p.x - r.x) <= tol,
            r: inY && Math.abs(p.x - r.x - r.width) <= tol,
            t: inX && Math.abs(p.y - r.y) <= tol,
            b: inX && Math.abs(p.y - r.y - r.height) <= tol
        };
    }

    function pressCrop(p) {
        const e = cropEdges(p);
        const r = cropDraft;
        const whole = r.x <= 0 && r.y <= 0 && r.width >= imageWidth && r.height >= imageHeight;
        if (e.l || e.r || e.t || e.b)
            cropDrag = {
                mode: "edges",
                edges: e,
                from: r,
                start: p
            };
        else if (!whole && p.x > r.x && p.x < r.x + r.width && p.y > r.y && p.y < r.y + r.height)
            cropDrag = {
                mode: "move",
                from: r,
                start: p
            };
        else
            cropDrag = {
                mode: "new",
                from: r,
                start: Qt.point(clampX(p.x), clampY(p.y))
            };
    }

    function dragCrop(p) {
        const d = cropDrag, f = d.from;
        const least = 8 / fit;
        if (d.mode === "new") {
            const x = clampX(p.x), y = clampY(p.y);
            cropDraft = Qt.rect(Math.min(x, d.start.x), Math.min(y, d.start.y), Math.abs(x - d.start.x), Math.abs(y - d.start.y));
        } else if (d.mode === "move") {
            const x = Math.max(0, Math.min(imageWidth - f.width, f.x + p.x - d.start.x));
            const y = Math.max(0, Math.min(imageHeight - f.height, f.y + p.y - d.start.y));
            cropDraft = Qt.rect(x, y, f.width, f.height);
        } else {
            let l = f.x, t = f.y, r = f.x + f.width, b = f.y + f.height;
            if (d.edges.l)
                l = Math.max(0, Math.min(r - least, p.x));
            if (d.edges.r)
                r = Math.min(imageWidth, Math.max(l + least, p.x));
            if (d.edges.t)
                t = Math.max(0, Math.min(b - least, p.y));
            if (d.edges.b)
                b = Math.min(imageHeight, Math.max(t + least, p.y));
            cropDraft = Qt.rect(l, t, r - l, b - t);
        }
    }

    // A crop drawn too small to mean anything is let go.
    function dropCrop() {
        const d = cropDrag;
        cropDrag = null;
        if (d && (cropDraft.width < 8 / fit || cropDraft.height < 8 / fit))
            cropDraft = d.from;
    }

    function applyCrop() {
        const c = cropDraft;
        if (c.width < 1 || c.height < 1)
            return;
        const x = Math.max(0, Math.floor(c.x)), y = Math.max(0, Math.floor(c.y));
        const w = Math.min(imageWidth - x, Math.round(c.width)), h = Math.min(imageHeight - y, Math.round(c.height));
        const next = x === 0 && y === 0 && w >= imageWidth && h >= imageHeight ? null : Qt.rect(x, y, w, h);
        const now = doc.crop;
        if (next === null ? now === null : now !== null && next.x === now.x && next.y === now.y && next.width === now.width && next.height === now.height)
            return;
        commit({
            marks: doc.marks,
            crop: next
        });
    }

    // ── Saving ───────────────────────────────────────────────────────────────

    // What's shown, the crop at its full size, to a PNG; `done` hears whether
    // it worked.
    function render(path, done) {
        finishTyping();
        if (cropping)
            setTool("select");
        const r = doc.crop ?? full;
        const ok = frame.grabToImage(result => done(result.saveToFile(path)), Qt.size(Math.round(r.width), Math.round(r.height)));
        if (!ok)
            done(false);
    }

    // ── What's shown ─────────────────────────────────────────────────────────

    // The shot, fitted and centred; image pixels inside, so its children
    // draw (and its mouse area reads) in them.
    Item {
        id: frame

        x: Math.round((sheet.width - sheet.view.width * sheet.fit) / 2)
        y: Math.round((sheet.height - sheet.view.height * sheet.fit) / 2)
        width: sheet.view.width
        height: sheet.view.height
        scale: sheet.fit
        transformOrigin: Item.TopLeft
        clip: true
        visible: sheet.ready

        Item {
            id: canvas

            x: -sheet.view.x
            y: -sheet.view.y
            width: sheet.imageWidth
            height: sheet.imageHeight

            Image {
                id: base
                source: sheet.source
                cache: false
                asynchronous: true
                smooth: true
                mipmap: true
            }

            Repeater {
                id: patchMarks
                model: ScriptModel {
                    values: sheet.patches
                }

                Mark {
                    required property var modelData
                    mark: modelData
                    source: sheet.source
                    imageWidth: sheet.imageWidth
                    imageHeight: sheet.imageHeight
                    shiftX: sheet.dragging && modelData.id === sheet.selectedId ? sheet.dragX : 0
                    shiftY: sheet.dragging && modelData.id === sheet.selectedId ? sheet.dragY : 0
                }
            }

            Mark {
                mark: sheet.live && sheet.live.kind === "pixelate" ? sheet.live : null
                source: sheet.source
                imageWidth: sheet.imageWidth
                imageHeight: sheet.imageHeight
            }

            // (only while there's something on it: the layer's the size of
            // the image)
            Item {
                width: sheet.imageWidth
                height: sheet.imageHeight
                opacity: 0.42
                layer.enabled: sheet.highlights.length > 0 || (sheet.live !== null && sheet.live.kind === "marker")
                layer.smooth: true

                Repeater {
                    id: highlightMarks
                    model: ScriptModel {
                        values: sheet.highlights
                    }

                    Mark {
                        required property var modelData
                        mark: modelData
                        imageWidth: sheet.imageWidth
                        imageHeight: sheet.imageHeight
                        shiftX: sheet.dragging && modelData.id === sheet.selectedId ? sheet.dragX : 0
                        shiftY: sheet.dragging && modelData.id === sheet.selectedId ? sheet.dragY : 0
                    }
                }

                Mark {
                    mark: sheet.live && sheet.live.kind === "marker" ? sheet.live : null
                    imageWidth: sheet.imageWidth
                    imageHeight: sheet.imageHeight
                }
            }

            Repeater {
                id: inkMarks
                model: ScriptModel {
                    values: sheet.inks
                }

                Mark {
                    required property var modelData
                    mark: modelData
                    number: modelData.kind === "counter" ? sheet.numberOf(modelData) : 1
                    imageWidth: sheet.imageWidth
                    imageHeight: sheet.imageHeight
                    visible: !(sheet.typing && sheet.typing.id === modelData.id)
                    shiftX: sheet.dragging && modelData.id === sheet.selectedId ? sheet.dragX : 0
                    shiftY: sheet.dragging && modelData.id === sheet.selectedId ? sheet.dragY : 0
                }
            }

            Mark {
                mark: sheet.live && sheet.live.kind !== "marker" && sheet.live.kind !== "pixelate" ? sheet.live : null
                imageWidth: sheet.imageWidth
                imageHeight: sheet.imageHeight
            }

            // The text being typed, as it will be drawn (its label, if
            // filled), in a thin box.
            Item {
                id: typingBox

                readonly property real pad: sheet.typing ? Math.round(sheet.typing.size * 0.3) : 0

                visible: sheet.typing !== null
                x: sheet.typing ? sheet.typing.x : 0
                y: sheet.typing ? sheet.typing.y : 0
                width: Math.max(editor.contentWidth, editor.font.pixelSize * 0.6) + 2 * pad
                height: editor.contentHeight + 2 * pad

                Rectangle {
                    anchors.fill: parent
                    radius: typingBox.pad
                    color: sheet.typing && sheet.typing.fill ? sheet.typing.color : "transparent"
                    border.width: 1.5 / sheet.fit
                    border.color: Colors.withAlpha(ControlStyle.accent, 0.9)
                    antialiasing: true
                }

                TextEdit {
                    id: editor

                    x: typingBox.pad
                    y: typingBox.pad
                    textFormat: TextEdit.PlainText
                    font.family: "Adwaita Sans"
                    font.pixelSize: sheet.typing ? Math.max(6, Math.round(sheet.typing.size)) : 12
                    font.weight: Font.DemiBold
                    color: sheet.typing ? (sheet.typing.fill ? inkFor(sheet.typing.color) : sheet.typing.color) : "white"
                    selectionColor: Colors.withAlpha(ControlStyle.accent, 0.45)
                    selectedTextColor: color
                    cursorVisible: activeFocus
                    enabled: sheet.typing !== null

                    function inkFor(c) {
                        const q = Qt.color(c);
                        return 0.2126 * q.r + 0.7152 * q.g + 0.0722 * q.b > 0.55 ? "#16130f" : "#fbf8f3";
                    }

                    // Enter finishes, Shift+Enter starts a new line, Esc
                    // finishes too.
                    Keys.onPressed: event => {
                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                            sheet.finishTyping();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            sheet.finishTyping();
                            event.accepted = true;
                        }
                    }
                }
            }
        }

        MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: {
                switch (sheet.tool) {
                case "select":
                    return sheet.dragging ? Qt.ClosedHandCursor : sheet.hoverId >= 0 ? Qt.OpenHandCursor : Qt.ArrowCursor;
                case "text":
                    return Qt.IBeamCursor;
                case "crop":
                    return sheet.cropCursor;
                default:
                    return Qt.CrossCursor;
                }
            }

            function at(mouse) {
                return Qt.point(mouse.x + sheet.view.x, mouse.y + sheet.view.y);
            }

            onPressed: mouse => {
                sheet.touched();
                const p = at(mouse);
                if (sheet.typing) {
                    sheet.finishTyping();
                    return;
                }
                switch (sheet.tool) {
                case "select":
                    sheet.pick(p);
                    break;
                case "text":
                    {
                        const m = sheet.markAt(p.x, p.y);
                        sheet.startTyping(p, m && m.kind === "text" ? m : null);
                        break;
                    }
                case "counter":
                    sheet.add({
                        kind: "counter",
                        color: String(sheet.ink),
                        size: sheet.sizeFor("counter"),
                        x: p.x,
                        y: p.y
                    });
                    break;
                case "crop":
                    sheet.pressCrop(p);
                    break;
                default:
                    sheet.startDrawing(p);
                }
            }

            onPositionChanged: mouse => {
                const p = at(mouse);
                if (!pressed) {
                    sheet.hoverAt(p);
                    return;
                }
                if (sheet.tool === "select") {
                    if (sheet.dragging)
                        sheet.dragTo(p);
                } else if (sheet.tool === "crop") {
                    if (sheet.cropDrag)
                        sheet.dragCrop(p);
                } else if (sheet.live) {
                    sheet.drawTo(p, mouse.modifiers & Qt.ShiftModifier);
                }
            }

            onReleased: {
                if (sheet.tool === "select") {
                    if (sheet.dragging)
                        sheet.drop();
                } else if (sheet.tool === "crop") {
                    if (sheet.cropDrag)
                        sheet.dropCrop();
                } else if (sheet.live) {
                    sheet.finishDrawing();
                }
            }

            // On text with the select tool: change it.
            onDoubleClicked: mouse => {
                if (sheet.tool !== "select")
                    return;
                const p = at(mouse);
                const m = sheet.markAt(p.x, p.y);
                if (m && m.kind === "text") {
                    sheet.dragging = false;
                    sheet.startTyping(p, m);
                }
            }

            onExited: sheet.hoverId = -1
        }
    }

    property int cropCursor: Qt.CrossCursor

    // What's under the pointer: a mark to pick, a crop edge to pull.
    function hoverAt(p) {
        if (tool === "select") {
            const m = markAt(p.x, p.y);
            hoverId = m ? m.id : -1;
        } else if (tool === "crop") {
            const e = cropEdges(p);
            const r = cropDraft;
            if ((e.l && e.t) || (e.r && e.b))
                cropCursor = Qt.SizeFDiagCursor;
            else if ((e.r && e.t) || (e.l && e.b))
                cropCursor = Qt.SizeBDiagCursor;
            else if (e.l || e.r)
                cropCursor = Qt.SizeHorCursor;
            else if (e.t || e.b)
                cropCursor = Qt.SizeVerCursor;
            else if (p.x > r.x && p.x < r.x + r.width && p.y > r.y && p.y < r.y + r.height && (r.width < imageWidth || r.height < imageHeight))
                cropCursor = Qt.SizeAllCursor;
            else
                cropCursor = Qt.CrossCursor;
        }
    }

    // ── Over the shot, in screen pixels ──────────────────────────────────────

    // A mark under the pointer, and the one picked, with a cross to delete it.
    Rectangle {
        readonly property Mark item: sheet.hoverId >= 0 && sheet.hoverId !== sheet.selectedId && sheet.tool === "select" ? sheet.itemOf(sheet.hoverId) : null
        readonly property rect r: item ? sheet.toSheet(item.bounds) : Qt.rect(0, 0, 0, 0)

        visible: item !== null
        x: r.x - 4
        y: r.y - 4
        width: r.width + 8
        height: r.height + 8
        radius: 4
        color: "transparent"
        border.width: 1
        border.color: Colors.withAlpha(ControlStyle.accent, 0.55)
    }

    Item {
        id: picked

        readonly property Mark item: sheet.selectedId >= 0 && sheet.tool === "select" ? sheet.itemOf(sheet.selectedId) : null
        readonly property rect r: item ? sheet.toSheet(item.bounds) : Qt.rect(0, 0, 0, 0)

        visible: item !== null
        x: r.x - 5 + sheet.dragX * sheet.fit
        y: r.y - 5 + sheet.dragY * sheet.fit
        width: r.width + 10
        height: r.height + 10

        // (the geometry renderer: the curve renderer draws no dashes)
        Shape {
            anchors.fill: parent

            ShapePath {
                strokeColor: ControlStyle.accent
                strokeWidth: 1.5
                strokeStyle: ShapePath.DashLine
                dashPattern: [4, 3]
                fillColor: "transparent"
                startX: 0
                startY: 0

                PathLine {
                    x: picked.width
                    y: 0
                }
                PathLine {
                    x: picked.width
                    y: picked.height
                }
                PathLine {
                    x: 0
                    y: picked.height
                }
                PathLine {
                    x: 0
                    y: 0
                }
            }
        }

        MouseArea {
            id: bin
            visible: !sheet.dragging
            x: parent.width - width / 2
            y: -height / 2
            width: 22
            height: 22
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sheet.removeSelected()

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: bin.containsMouse ? ControlStyle.danger : ControlStyle.accent
                border.width: 1.5
                border.color: "white"
            }

            Text {
                anchors.centerIn: parent
                text: "close"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 15
                color: "white"
            }
        }
    }

    // The crop being chosen: the rest dimmed, thirds, handles at the corners
    // and the size it will be.
    Item {
        id: cropView

        readonly property rect r: sheet.cropping ? sheet.toSheet(sheet.cropDraft) : Qt.rect(0, 0, 0, 0)
        readonly property rect all: sheet.toSheet(sheet.full)

        visible: sheet.cropping && sheet.ready
        anchors.fill: parent

        Rectangle {
            x: cropView.all.x
            y: cropView.all.y
            width: cropView.all.width
            height: cropView.r.y - cropView.all.y
            color: "#99000000"
        }
        Rectangle {
            x: cropView.all.x
            y: cropView.r.y + cropView.r.height
            width: cropView.all.width
            height: cropView.all.y + cropView.all.height - y
            color: "#99000000"
        }
        Rectangle {
            x: cropView.all.x
            y: cropView.r.y
            width: cropView.r.x - cropView.all.x
            height: cropView.r.height
            color: "#99000000"
        }
        Rectangle {
            x: cropView.r.x + cropView.r.width
            y: cropView.r.y
            width: cropView.all.x + cropView.all.width - x
            height: cropView.r.height
            color: "#99000000"
        }

        Rectangle {
            x: cropView.r.x
            y: cropView.r.y
            width: cropView.r.width
            height: cropView.r.height
            color: "transparent"
            border.width: 1.5
            border.color: ControlStyle.accent

            Repeater {
                model: 2

                Item {
                    id: third
                    required property int index
                    anchors.fill: parent

                    Rectangle {
                        x: parent.width * (third.index + 1) / 3
                        width: 1
                        height: parent.height
                        color: "#40ffffff"
                    }

                    Rectangle {
                        y: parent.height * (third.index + 1) / 3
                        width: parent.width
                        height: 1
                        color: "#40ffffff"
                    }
                }
            }

            Repeater {
                model: 4

                Rectangle {
                    required property int index
                    x: (index % 2 ? parent.width : 0) - width / 2
                    y: (index > 1 ? parent.height : 0) - height / 2
                    width: 12
                    height: 12
                    radius: 2
                    color: ControlStyle.accent
                    border.width: 1.5
                    border.color: "white"
                }
            }
        }

        Rectangle {
            readonly property bool below: cropView.r.y < 40

            x: Math.max(cropView.all.x, Math.min(cropView.r.x, cropView.all.x + cropView.all.width - width))
            y: below ? cropView.r.y + cropView.r.height + 8 : cropView.r.y - height - 8
            width: sizeText.implicitWidth + 16
            height: 22
            radius: ControlStyle.radius(11)
            color: "#cc000000"

            Text {
                id: sizeText
                anchors.centerIn: parent
                text: Math.round(sheet.cropDraft.width) + " × " + Math.round(sheet.cropDraft.height)
                font.family: ControlStyle.mono
                font.pixelSize: 12
                color: "white"
            }
        }
    }
}
