pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.colors
import qs.modules.control
import qs.modules.lock
import qs.services as Services

// The screenshot editor (Services.Screenshot.session), over the whole
// screen: the shot (Sheet) between two bars on the theme's frame. Above,
// where it's saved: the folder and the name, to change, and Delete, Copy
// and Save. Below, the tools, the colour, size and fill of what's drawn
// next (or of the mark picked), and undo; over them, what the tool does.
//
// Save writes the marks and the crop into the file, under the name typed
// (the old file goes); with nothing drawn a new name only renames it. A
// draft (a shot taken only to the clipboard) is saved into the folder.
// Copy puts the shot, as it is now, on the clipboard. Closing with
// changes unsaved asks first.
//
// Keys: V select, P pen, H highlighter, L line, A arrow, R box, O ellipse,
// T text, N numbers, B pixelate, C crop; F fill, 1 2 3 size; Ctrl+Z undo,
// Ctrl+Shift+Z or Ctrl+Y redo; Delete removes the mark picked; F2 goes to
// the name; Ctrl+C copies; Enter or Ctrl+S saves (with the crop tool,
// Enter applies the crop); Esc steps back out, and closes.
Item {
    id: root

    readonly property var session: Services.Screenshot.session
    readonly property string file: session ? session.file : ""
    readonly property string dir: session ? session.dir : ""
    readonly property bool draft: session ? session.draft : false
    readonly property string ext: Services.Screenshot.extOf(file) || ".png"
    readonly property string firstStem: Services.Screenshot.stemOf(file)
    readonly property string stem: Services.Screenshot.cleanStem(nameField.text, ext)
    // Something to save: marks, a crop or a new name.
    readonly property bool dirty: sheet.edited || (stem !== "" && stem !== firstStem)

    property bool busy: false
    // Asking whether to save before closing; Delete asked once.
    property bool askClose: false
    property bool askDelete: false
    property string note: ""
    property bool noteBad: false
    // The tool the crop goes back to.
    property string lastTool: "arrow"
    property real shown: 0

    readonly property var tools: [
        { id: "select", glyph: "arrow_selector_tool", tip: "Select and move", key: "V" },
        { id: "pen", glyph: "stylus", tip: "Pen", key: "P" },
        { id: "marker", glyph: "ink_highlighter", tip: "Highlighter", key: "H" },
        { id: "line", glyph: "pen_size_2", tip: "Line", key: "L" },
        { id: "arrow", glyph: "arrow_outward", tip: "Arrow", key: "A" },
        { id: "rect", glyph: "rectangle", tip: "Box", key: "R" },
        { id: "ellipse", glyph: "circle", tip: "Ellipse", key: "O" },
        { id: "text", glyph: "title", tip: "Text", key: "T" },
        { id: "counter", glyph: "counter_1", tip: "Numbered steps", key: "N" },
        { id: "pixelate", glyph: "blur_on", tip: "Pixelate", key: "B" },
        { id: "crop", glyph: "crop", tip: "Crop", key: "C" }
    ]
    readonly property var toolKeys: ({
            [Qt.Key_V]: "select",
            [Qt.Key_P]: "pen",
            [Qt.Key_H]: "marker",
            [Qt.Key_L]: "line",
            [Qt.Key_A]: "arrow",
            [Qt.Key_R]: "rect",
            [Qt.Key_O]: "ellipse",
            [Qt.Key_T]: "text",
            [Qt.Key_N]: "counter",
            [Qt.Key_B]: "pixelate",
            [Qt.Key_C]: "crop"
        })
    readonly property var hints: ({
            select: "Click a mark to pick it, drag to move it · Delete removes it · double-click text to change it",
            pen: "Drag to draw · Shift keeps it straight",
            marker: "Drag over what matters · Shift keeps it straight",
            line: "Drag a line · Shift turns it in steps of 15°",
            arrow: "Drag from the tail to the point · Shift turns it in steps of 15°",
            rect: "Drag a box · Shift makes it square · F fills it",
            ellipse: "Drag an ellipse · Shift makes it round · F fills it",
            text: "Click to write · Enter finishes, Shift+Enter starts a new line · F puts it on a label",
            counter: "Click for 1, 2, 3… in order",
            pixelate: "Drag over what should stay private",
            crop: "Drag to crop · pull its edges · Enter applies, Esc leaves it as it was"
        })
    readonly property var swatches: ["#ff3b30", "#ff9500", "#ffcc00", "#34c759", "#0a84ff", "#bf5af2", "#ffffff", "#111111"]

    focus: true

    onDirtyChanged: Services.Screenshot.unsaved = dirty
    Component.onCompleted: {
        load();
        shown = 1;
    }
    Component.onDestruction: Services.Screenshot.unsaved = false

    // Another shot opened while this one's clean. (Not onSessionChanged:
    // that runs while the editor's still being made, in the middle of its
    // bindings.)
    Connections {
        target: Services.Screenshot

        function onSessionChanged() {
            root.load();
        }
    }

    Behavior on shown {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutCubic
        }
    }

    // (from the service: `session` here may not have caught up yet)
    function load() {
        const s = Services.Screenshot.session;
        if (!s)
            return;
        sheet.reset("file://" + s.file.split("/").map(encodeURIComponent).join("/"));
        nameField.text = Services.Screenshot.stemOf(s.file);
        note = "";
        askClose = false;
        askDelete = false;
        busy = false;
        const t = Services.Screenshot.tool;
        sheet.setTool(t === "crop" ? "arrow" : t);
        sheet.ink = Services.Screenshot.ink;
        sheet.size = Services.Screenshot.size;
        sheet.fill = Services.Screenshot.fill;
        root.forceActiveFocus();
    }

    function say(text, bad) {
        note = text;
        noteBad = !!bad;
        noteTimer.restart();
    }

    // ── Tools and style ──────────────────────────────────────────────────────

    function pickTool(t) {
        if (t === "crop" && sheet.tool !== "crop")
            lastTool = sheet.tool;
        sheet.setTool(t);
        if (t !== "crop")
            Services.Screenshot.tool = t;
        root.forceActiveFocus();
    }

    // The crop as it was, and back to the tool before it.
    function cancelCrop() {
        sheet.cropDraft = sheet.doc.crop ?? sheet.full;
        pickTool(lastTool);
    }

    // For what's drawn next, and the mark picked.
    function setColor(c) {
        sheet.ink = c;
        Services.Screenshot.ink = c;
        restyle();
    }

    function setSize(i) {
        sheet.size = i;
        Services.Screenshot.size = i;
        restyle();
    }

    function setFill(on) {
        sheet.fill = on;
        Services.Screenshot.fill = on;
        restyle();
    }

    function restyle() {
        const m = sheet.selectedMark;
        if (!m || sheet.tool !== "select")
            return;
        const c = Object.assign({}, m, {
            size: sheet.sizeFor(m.kind)
        });
        if (m.kind !== "pixelate")
            c.color = String(sheet.ink);
        if (m.kind === "rect" || m.kind === "ellipse" || m.kind === "text")
            c.fill = sheet.fill;
        if (c.color !== m.color || c.size !== m.size || c.fill !== m.fill)
            sheet.replace(m.id, c);
    }

    // Esc: out of the crop, then the mark picked, then the editor.
    function back() {
        if (sheet.cropping)
            cancelCrop();
        else if (sheet.selectedId >= 0)
            sheet.selectedId = -1;
        else
            requestClose();
    }

    // ── Saving ───────────────────────────────────────────────────────────────

    function requestClose() {
        if (busy)
            return;
        if (dirty && sheet.ready)
            askClose = true;
        else
            close();
    }

    function close() {
        askClose = false;
        shown = 0;
        closeTimer.restart();
    }

    function save() {
        if (busy || !sheet.ready)
            return;
        askClose = false;
        sheet.finishTyping();
        if (sheet.cropping)
            pickTool(lastTool);
        const stem = root.stem, from = root.file, dir = root.dir, ext = root.ext;
        if (!stem) {
            say("It needs a name", true);
            nameField.forceActiveFocus();
            return;
        }
        const to = dir + "/" + stem + ext;
        const moving = to !== from;
        if (!moving && !sheet.edited) {
            close();
            return;
        }
        busy = true;
        const write = () => {
            if (sheet.edited) {
                sheet.render(to, ok => {
                    if (!ok) {
                        busy = false;
                        say("Couldn't save it", true);
                        return;
                    }
                    if (moving)
                        Services.Screenshot.remove(from);
                    saved(from);
                });
            } else {
                Services.Screenshot.move(from, dir, stem, ext, false, code => {
                    if (code !== 0) {
                        busy = false;
                        say(code === 3 ? `There's already a ${stem}${ext}` : "Couldn't rename it", true);
                        return;
                    }
                    saved(from);
                });
            }
        };
        if (!moving) {
            write();
            return;
        }
        Services.Screenshot.exists(to, taken => {
            if (!taken) {
                write();
                return;
            }
            busy = false;
            say(`There's already a ${stem}${ext}`, true);
            nameField.forceActiveFocus();
        });
    }

    // Its notifications are about a file that's changed or gone now.
    function saved(from) {
        Services.Screenshot.forget(from);
        say("Saved", false);
        doneTimer.restart();
    }

    function copy() {
        if (busy || !sheet.ready)
            return;
        sheet.finishTyping();
        if (sheet.cropping)
            pickTool(lastTool);
        if (!sheet.edited) {
            Services.Screenshot.copy(root.file);
            say("Copied", false);
            return;
        }
        busy = true;
        const out = Services.Screenshot.drafts + "/clipboard.png";
        Services.Screenshot.makeDir(Services.Screenshot.drafts, () => {
            sheet.render(out, ok => {
                busy = false;
                if (!ok) {
                    say("Couldn't copy it", true);
                    return;
                }
                Services.Screenshot.copy(out);
                say("Copied", false);
            });
        });
    }

    // To the bin, on the second click.
    function remove() {
        if (busy)
            return;
        if (!askDelete) {
            askDelete = true;
            deleteTimer.restart();
            return;
        }
        askDelete = false;
        busy = true;
        const file = root.file;
        Services.Screenshot.trash(file, code => {
            busy = false;
            if (code !== 0) {
                say("Couldn't delete it", true);
                return;
            }
            Services.Screenshot.forget(file);
            close();
        });
    }

    Timer {
        id: noteTimer
        interval: 2600
        onTriggered: root.note = ""
    }

    Timer {
        id: deleteTimer
        interval: 3000
        onTriggered: root.askDelete = false
    }

    // "Saved" shows for a moment before it closes.
    Timer {
        id: doneTimer
        interval: 450
        onTriggered: {
            root.busy = false;
            root.close();
        }
    }

    Timer {
        id: closeTimer
        interval: 260
        onTriggered: Services.Screenshot.close()
    }

    // ── Keys ─────────────────────────────────────────────────────────────────

    // Keys typed into the name or a text mark come here too, unless they
    // were theirs.
    Keys.onPressed: event => {
        const k = event.key;
        const ctrl = event.modifiers & Qt.ControlModifier;
        const shift = event.modifiers & Qt.ShiftModifier;
        if (askClose) {
            if (k === Qt.Key_Escape)
                askClose = false;
            else if (k === Qt.Key_Return || k === Qt.Key_Enter)
                save();
            event.accepted = true;
            return;
        }
        if (ctrl && k === Qt.Key_S) {
            save();
        } else if (nameField.activeFocus) {
            if (k !== Qt.Key_Escape)
                return;
            root.forceActiveFocus();
        } else if (sheet.typing) {
            return;
        } else if (ctrl && k === Qt.Key_Z) {
            if (shift)
                sheet.redo();
            else
                sheet.undo();
        } else if (ctrl && k === Qt.Key_Y) {
            sheet.redo();
        } else if (ctrl && k === Qt.Key_C) {
            copy();
        } else if (k === Qt.Key_Delete || k === Qt.Key_Backspace) {
            sheet.removeSelected();
        } else if (k === Qt.Key_Escape) {
            back();
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            if (sheet.cropping)
                pickTool(lastTool);
            else
                save();
        } else if (k === Qt.Key_F2) {
            nameField.forceActiveFocus();
            nameField.selectAll();
        } else if (!ctrl && toolKeys[k] !== undefined) {
            pickTool(toolKeys[k]);
        } else if (!ctrl && k === Qt.Key_F) {
            setFill(!sheet.fill);
        } else if (!ctrl && k >= Qt.Key_1 && k <= Qt.Key_3) {
            setSize(k - Qt.Key_1);
        } else {
            return;
        }
        event.accepted = true;
    }

    // ── What's shown ─────────────────────────────────────────────────────────

    Rectangle {
        anchors.fill: parent
        color: Colors.scrim
        opacity: 0.68 * root.shown

        // Clicks here go nowhere.
        MouseArea {
            anchors.fill: parent
            onPressed: root.forceActiveFocus()
        }
    }

    Sheet {
        id: sheet

        x: 24
        y: topBar.y + topBar.height + 14
        width: parent.width - 48
        height: toolBar.y - 34 - y
        opacity: root.shown
        scale: 0.97 + 0.03 * root.shown

        onTouched: root.forceActiveFocus()
        onTyped: root.forceActiveFocus()
    }

    Text {
        anchors.centerIn: sheet
        visible: !sheet.ready
        text: sheet.failed ? "Couldn't open " + Services.Screenshot.pretty(root.file) : "Opening…"
        font.family: ControlStyle.body
        font.pixelSize: 15
        color: "white"
        opacity: 0.8
    }

    // ── Above: the file ──────────────────────────────────────────────────────

    Item {
        id: topBar

        readonly property real inner: 40

        anchors.horizontalCenter: parent.horizontalCenter
        y: 16 - (1 - root.shown) * 24
        width: Math.min(parent.width - 32, topRow.implicitWidth + 2 * topSurface.pad + 8)
        height: topSurface.headRoom + 2 * topSurface.pad + inner + topSurface.footRoom
        opacity: root.shown

        EditorSurface {
            id: topSurface
            anchors.fill: parent
            title: "screenshot"
        }

        Row {
            id: topRow

            anchors.horizontalCenter: parent.horizontalCenter
            y: topSurface.headRoom + topSurface.pad
            height: topBar.inner
            spacing: 10

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: "screenshot_region"
                filled: true
                font.pixelSize: 22
                color: ControlStyle.accent
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 300)
                elide: Text.ElideLeft
                text: Services.Screenshot.pretty(root.dir) + "/"
                font.family: ControlStyle.body
                font.pixelSize: 13
                color: Colors.withAlpha(ControlStyle.ink, 0.6)
            }

            // The name, without its extension.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 340
                height: 34
                radius: ControlStyle.radius(10)
                color: nameField.activeFocus ? ControlStyle.wellHover : ControlStyle.well
                border.width: 1
                border.color: root.noteBad && root.note ? ControlStyle.danger : nameField.activeFocus ? Colors.withAlpha(ControlStyle.accent, 0.8) : ControlStyle.line

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onPressed: nameField.forceActiveFocus()
                }

                TextInput {
                    id: nameField

                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: extLabel.left
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    selectByMouse: true
                    font.family: ControlStyle.body
                    font.pixelSize: 14
                    color: ControlStyle.ink
                    selectionColor: Colors.withAlpha(ControlStyle.accent, 0.4)
                    selectedTextColor: ControlStyle.ink
                    onTextEdited: if (root.noteBad) root.note = ""
                    onAccepted: root.save()
                }

                Text {
                    id: extLabel
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.ext
                    font: nameField.font
                    color: Colors.withAlpha(ControlStyle.ink, 0.45)
                }
            }

            // How big it'll be saved.
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: sheet.ready
                text: {
                    const r = sheet.doc.crop ?? sheet.full;
                    return Math.round(r.width) + " × " + Math.round(r.height);
                }
                font.family: ControlStyle.mono
                font.pixelSize: 12
                color: Colors.withAlpha(ControlStyle.ink, 0.55)
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 22
                color: ControlStyle.line
            }

            NotificationButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.draft
                glyph: "delete"
                text: root.askDelete ? "Delete it?" : "Delete"
                primary: root.askDelete
                onClicked: root.remove()
            }

            NotificationButton {
                anchors.verticalCenter: parent.verticalCenter
                glyph: "content_copy"
                text: "Copy"
                onClicked: root.copy()
            }

            NotificationButton {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(implicitWidth, 92)
                glyph: root.note === "Saved" ? "check" : "save"
                text: root.busy ? "Saving…" : "Save"
                primary: true
                enabled: sheet.ready && !root.busy
                onClicked: root.save()
            }

            ToolButton {
                anchors.verticalCenter: parent.verticalCenter
                glyph: "close"
                tip: "Close"
                key: "Esc"
                tipBelow: true
                onClicked: root.requestClose()
            }
        }
    }

    // What's just happened: saved, copied, a name that's taken.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: topBar.y + topBar.height + 10
        width: noteText.implicitWidth + 28
        height: 30
        radius: ControlStyle.radius(15)
        color: root.noteBad ? ControlStyle.danger : ControlStyle.accent
        opacity: root.note ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: 160
            }
        }

        Text {
            id: noteText
            anchors.centerIn: parent
            text: root.note
            font.family: ControlStyle.ui
            font.pixelSize: 13
            font.weight: Font.Medium
            color: ControlStyle.inkOn(parent.color)
        }
    }

    // ── Below: the tools ─────────────────────────────────────────────────────

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: toolBar.y - height - 9
        width: Math.min(implicitWidth, parent.width - 48)
        elide: Text.ElideRight
        text: root.hints[sheet.tool] ?? ""
        font.family: ControlStyle.body
        font.pixelSize: 12
        color: "white"
        opacity: 0.72 * root.shown
    }

    Item {
        id: toolBar

        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - height - 16 + (1 - root.shown) * 24
        width: Math.min(parent.width - 32, toolRow.implicitWidth + 2 * toolSurface.pad + 8)
        height: toolSurface.headRoom + 2 * toolSurface.pad + 40 + toolSurface.footRoom
        opacity: root.shown

        EditorSurface {
            id: toolSurface
            anchors.fill: parent
            title: "tools"
        }

        Row {
            id: toolRow

            anchors.horizontalCenter: parent.horizontalCenter
            y: toolSurface.headRoom + toolSurface.pad + 2
            height: 36
            spacing: 3

            Repeater {
                model: root.tools

                ToolButton {
                    required property var modelData
                    glyph: modelData.glyph
                    tip: modelData.tip
                    key: modelData.key
                    active: sheet.tool === modelData.id
                    onClicked: root.pickTool(modelData.id)
                }
            }

            Item {
                width: 13
                height: 36

                Rectangle {
                    anchors.centerIn: parent
                    width: 1
                    height: 22
                    color: ControlStyle.line
                }
            }

            // The colour, size and fill; while cropping, the crop's buttons.
            Row {
                visible: !sheet.cropping
                spacing: 3

                ToolButton {
                    glyph: "format_color_fill"
                    tip: "Fill boxes and ellipses, put text on a label"
                    key: "F"
                    active: sheet.fill
                    onClicked: root.setFill(!sheet.fill)
                }

                Repeater {
                    model: root.swatches

                    MouseArea {
                        id: swatch

                        required property string modelData
                        readonly property bool chosen: Qt.colorEqual(sheet.ink, modelData)

                        width: 28
                        height: 36
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setColor(modelData)

                        Rectangle {
                            anchors.centerIn: parent
                            visible: swatch.chosen
                            width: 28
                            height: 28
                            radius: 14
                            color: "transparent"
                            border.width: 2
                            border.color: ControlStyle.accent
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: swatch.chosen ? 20 : swatch.containsMouse ? 20 : 18
                            height: width
                            radius: width / 2
                            color: swatch.modelData
                            border.width: 1
                            border.color: Colors.withAlpha(ControlStyle.ink, 0.3)

                            Behavior on width {
                                NumberAnimation {
                                    duration: 100
                                }
                            }
                        }
                    }
                }

                Item {
                    width: 9
                    height: 36
                }

                Repeater {
                    model: 3

                    MouseArea {
                        id: sizeButton

                        required property int index
                        readonly property bool chosen: sheet.size === index

                        width: 30
                        height: 36
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setSize(index)

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: ControlStyle.radius(9)
                            color: sizeButton.chosen ? Colors.withAlpha(ControlStyle.accent, 0.2) : sizeButton.containsMouse ? ControlStyle.wellHover : "transparent"
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: [5, 9, 14][sizeButton.index]
                            height: width
                            radius: width / 2
                            color: sizeButton.chosen ? ControlStyle.accent : ControlStyle.ink
                        }
                    }
                }
            }

            Row {
                visible: sheet.cropping
                spacing: 6

                NotificationButton {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "check"
                    text: "Apply"
                    primary: true
                    onClicked: root.pickTool(root.lastTool)
                }

                NotificationButton {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "fit_screen"
                    text: "Whole shot"
                    onClicked: sheet.cropDraft = sheet.full
                }

                NotificationButton {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "close"
                    text: "Cancel"
                    onClicked: root.cancelCrop()
                }
            }

            Item {
                width: 13
                height: 36

                Rectangle {
                    anchors.centerIn: parent
                    width: 1
                    height: 22
                    color: ControlStyle.line
                }
            }

            ToolButton {
                glyph: "undo"
                tip: "Undo"
                key: "Ctrl+Z"
                enabled: sheet.canUndo
                onClicked: sheet.undo()
            }

            ToolButton {
                glyph: "redo"
                tip: "Redo"
                key: "Ctrl+Shift+Z"
                enabled: sheet.canRedo
                onClicked: sheet.redo()
            }
        }
    }

    // ── Closing with changes ─────────────────────────────────────────────────

    Item {
        anchors.fill: parent
        visible: root.askClose

        Rectangle {
            anchors.fill: parent
            color: "#66000000"

            MouseArea {
                anchors.fill: parent
            }
        }

        Item {
            anchors.centerIn: parent
            width: 440
            height: askSurface.headRoom + 2 * askSurface.pad + askColumn.implicitHeight + askSurface.footRoom + 8

            EditorSurface {
                id: askSurface
                anchors.fill: parent
                title: "unsaved"
            }

            Column {
                id: askColumn

                x: askSurface.pad + 4
                y: askSurface.headRoom + askSurface.pad + 4
                width: parent.width - 2 * x
                spacing: 12

                Text {
                    width: parent.width
                    text: "Save it first?"
                    font.family: ControlStyle.display
                    font.pixelSize: 18
                    color: ControlStyle.ink
                }

                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: sheet.edited ? "What's drawn on it hasn't been saved yet." : "It hasn't been renamed to " + root.stem + root.ext + " yet."
                    font.family: ControlStyle.body
                    font.pixelSize: 13
                    color: Colors.withAlpha(ControlStyle.ink, 0.7)
                }

                Row {
                    anchors.right: parent.right
                    spacing: 8

                    NotificationButton {
                        text: "Discard"
                        glyph: "delete_sweep"
                        onClicked: root.close()
                    }

                    NotificationButton {
                        text: "Keep editing"
                        onClicked: root.askClose = false
                    }

                    NotificationButton {
                        text: "Save"
                        glyph: "save"
                        primary: true
                        onClicked: root.save()
                    }
                }
            }
        }
    }
}
