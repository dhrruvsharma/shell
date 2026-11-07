pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.services as Services
import qs.modules.lock
import qs.modules.control

// The shell's IPC commands kept at hand (services/IpcCommands): a tile for
// each, a click runs it (`qs ipc call …`, as a keybind would). *Add* turns
// the pane into the catalogue of every command the running shell takes,
// searchable and grouped by the part of the shell it belongs to: a click
// pins one, and one that takes arguments asks for them first. Carry a tile
// to reorder them, right-click one to rename it; its × unpins it. Under the
// tiles: the command under the pointer, or what the last one gave back, or
// why it couldn't run.
PaneSection {
    id: pane

    title: EdgeWords.word("commands")
    preferredWidth: 316

    readonly property var ipc: Services.IpcCommands
    // The catalogue's showing (adding commands) in place of the tiles.
    property bool adding: false
    // The catalogue entry open for its arguments ("target fn").
    property string opened: ""
    // The tile under the pointer (its key).
    property string pointed: ""

    function openCatalogue() {
        pane.opened = "";
        search.text = "";
        pane.adding = true;
        pane.ipc.refresh();
        Qt.callLater(() => search.forceActiveFocus());
    }

    function closeCatalogue() {
        pane.adding = false;
        pane.opened = "";
    }

    // A run that went through with nothing to say folds the edge line (the
    // command has likely opened something of its own); one about the edge
    // line itself leaves it be.
    Connections {
        target: pane.ipc

        function onRan(k, ok, output) {
            const cmd = pane.ipc.pinned.find(c => pane.ipc.key(c) === k);
            if (ok && output === "" && cmd && cmd.target !== "edgeLine")
                Services.EdgeLine.setOpen(false);
        }
    }

    trailing: [
        PaneChip {
            visible: !pane.adding
            icon: "add"
            text: "Add"
            onClicked: pane.openCatalogue()
        },
        PaneChip {
            visible: pane.adding
            icon: "check"
            text: "Done"
            onClicked: pane.closeCatalogue()
        }
    ]

    // ── The tiles ────────────────────────────────────────────────────────────
    Item {
        id: tiles

        readonly property int columns: 3
        readonly property real gap: 6
        readonly property real cellW: (tiles.width - (tiles.columns - 1) * tiles.gap) / tiles.columns
        readonly property real cellH: 64
        readonly property int count: pane.ipc.pinned.length
        readonly property int rows: Math.ceil((tiles.count + 1) / tiles.columns)

        // A tile being carried: where it came from, the place it would
        // land in, and where it is.
        property int dragFrom: -1
        property int dragTo: -1
        property real carryX: 0
        property real carryY: 0

        visible: !pane.adding
        width: parent.width
        height: tiles.rows * (tiles.cellH + tiles.gap) - tiles.gap

        // The place tile `i` sits in, the others making way for one carried.
        function slotOf(i) {
            const f = tiles.dragFrom, t = tiles.dragTo;
            if (f < 0 || t < 0)
                return i;
            if (i === f)
                return t;
            if (f < t && i > f && i <= t)
                return i - 1;
            if (f > t && i >= t && i < f)
                return i + 1;
            return i;
        }

        function slotPos(slot) {
            return Qt.point((slot % tiles.columns) * (tiles.cellW + tiles.gap), Math.floor(slot / tiles.columns) * (tiles.cellH + tiles.gap));
        }

        function slotAt(x, y) {
            const col = Math.max(0, Math.min(tiles.columns - 1, Math.floor((x + tiles.gap / 2) / (tiles.cellW + tiles.gap))));
            const row = Math.max(0, Math.floor((y + tiles.gap / 2) / (tiles.cellH + tiles.gap)));
            return Math.max(0, Math.min(tiles.count - 1, row * tiles.columns + col));
        }

        function pickUp(i) {
            const p = tiles.slotPos(i);
            tiles.carryX = p.x;
            tiles.carryY = p.y;
            tiles.dragFrom = i;
            tiles.dragTo = i;
        }

        function carryTo(x, y) {
            tiles.carryX = x;
            tiles.carryY = y;
            tiles.dragTo = tiles.slotAt(x + tiles.cellW / 2, y + tiles.cellH / 2);
        }

        // (the tiles are made again once the order changes, so not from
        // inside the carried one's own handler)
        function drop() {
            const f = tiles.dragFrom, t = tiles.dragTo;
            tiles.dragFrom = -1;
            tiles.dragTo = -1;
            if (f >= 0 && t >= 0 && f !== t)
                Qt.callLater(pane.ipc.move, f, t);
        }

        function cancel() {
            tiles.dragFrom = -1;
            tiles.dragTo = -1;
        }

        function point(k) {
            if (k !== "" || pane.pointed !== "")
                pane.pointed = k;
        }

        Repeater {
            model: pane.ipc.pinned

            CommandTile {
                board: tiles
            }
        }

        // The place after the last: the way into the catalogue.
        MouseArea {
            id: addCell
            readonly property point at: tiles.slotPos(tiles.count)
            x: addCell.at.x
            y: addCell.at.y
            width: tiles.cellW
            height: tiles.cellH
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pane.openCatalogue()

            Rectangle {
                anchors.fill: parent
                radius: ControlStyle.radius(12)
                color: addCell.containsMouse ? ControlStyle.wellHover : "transparent"
                border.width: 1
                border.color: addCell.containsMouse ? ControlStyle.accent : ControlStyle.line
            }

            Column {
                anchors.centerIn: parent
                spacing: 2

                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "add"
                    font.pixelSize: 20
                    color: addCell.containsMouse ? ControlStyle.accent : Colors.withAlpha(ControlStyle.ink, 0.5)
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ControlStyle.label("Add")
                    font.family: ControlStyle.ui
                    font.pixelSize: 10
                    font.capitalization: ControlStyle.caps
                    color: Colors.withAlpha(ControlStyle.ink, 0.6)
                }
            }
        }
    }

    // Under the tiles: how the last run went (what it gave back, or why it
    // couldn't run), unless the pointer is on another tile (then that one's
    // command); else what can be done with them. (Two lines at most, so the
    // pane keeps its size.)
    Item {
        id: status

        readonly property var last: pane.ipc.runs[pane.ipc.lastKey] ?? null
        readonly property var lastCmd: pane.ipc.pinned.find(c => pane.ipc.key(c) === pane.ipc.lastKey) ?? null
        readonly property bool told: status.lastCmd !== null && (status.last?.state === "failed" || (status.last?.state === "ok" && (status.last?.output ?? "") !== ""))
        readonly property var pointedCmd: status.told && pane.pointed === pane.ipc.lastKey ? null : (pane.ipc.pinned.find(c => pane.ipc.key(c) === pane.pointed) ?? null)
        readonly property bool failed: status.pointedCmd === null && status.told && status.last.state === "failed"
        readonly property bool said: status.pointedCmd === null && status.told && status.last.state === "ok"

        visible: !pane.adding
        width: parent.width
        height: 32

        Glyph {
            id: mark
            visible: status.failed || status.said
            y: 1
            text: status.failed ? "error" : "subdirectory_arrow_right"
            font.pixelSize: 15
            color: status.failed ? ControlStyle.danger : ControlStyle.accent
        }

        Text {
            anchors.left: mark.visible ? mark.right : parent.left
            anchors.leftMargin: mark.visible ? 6 : 0
            anchors.right: forget.visible ? forget.left : parent.right
            anchors.rightMargin: forget.visible ? 4 : 0
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            text: status.pointedCmd ? pane.ipc.commandLine(status.pointedCmd)
                : status.failed ? "Couldn't run " + pane.ipc.titleOf(status.lastCmd) + ": " + status.last.error
                : status.said ? pane.ipc.titleOf(status.lastCmd) + " → " + status.last.output
                : pane.ipc.pinned.length === 0 ? "Pin any of the shell's commands here, and a click runs it."
                : "Carry a tile to move it, right-click to rename it."
            font.family: status.pointedCmd || status.said ? ControlStyle.mono : ControlStyle.body
            font.pixelSize: 11
            color: status.failed ? ControlStyle.danger : status.said ? ControlStyle.ink : Colors.withAlpha(ControlStyle.ink, 0.55)
        }

        PaneChip {
            id: forget
            visible: status.failed || status.said
            anchors.right: parent.right
            icon: "close"
            onClicked: pane.ipc.dismiss(pane.ipc.lastKey)
        }
    }

    // ── The catalogue ────────────────────────────────────────────────────────
    Column {
        visible: pane.adding
        width: parent.width
        spacing: 8

        Item {
            width: parent.width
            height: 36

            Rectangle {
                anchors.fill: parent
                radius: ControlStyle.radius(12)
                color: ControlStyle.well
                border.width: 1
                border.color: search.activeFocus ? ControlStyle.accent : ControlStyle.line
            }

            Glyph {
                id: lens
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "search"
                font.pixelSize: 17
                color: search.activeFocus ? ControlStyle.accent : Colors.withAlpha(ControlStyle.ink, 0.6)
            }

            TextInput {
                id: search
                anchors.left: lens.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                inputMethodHints: Qt.ImhNoAutoUppercase
                font.family: ControlStyle.body
                font.pixelSize: 13
                color: ControlStyle.ink
                selectionColor: Colors.withAlpha(ControlStyle.accent, 0.4)
                onTextChanged: {
                    pane.opened = "";
                    catalogue.positionViewAtBeginning();
                }
                // Enter: the one command left, pinned (or opened)
                onAccepted: {
                    const fns = catalogue.rows.filter(r => !r.head);
                    if (fns.length === 1) {
                        const c = fns[0].item;
                        if (c.params.length > 0)
                            pane.opened = fns[0].key;
                        else if (!pane.ipc.isPinned(c.target, c.fn, []))
                            pane.ipc.pin(c.target, c.fn, [], "");
                    }
                }
                Keys.onEscapePressed: event => {
                    if (search.text !== "")
                        search.text = "";
                    else
                        pane.closeCatalogue();
                    event.accepted = true;
                }

                Text {
                    visible: search.text.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    elide: Text.ElideRight
                    text: pane.ipc.catalogue.length > 0 ? "Search the shell's " + pane.ipc.catalogue.length + " commands" : "Search the shell's commands"
                    font: search.font
                    color: Colors.withAlpha(ControlStyle.ink, 0.45)
                }
            }
        }

        ListView {
            id: catalogue

            // The commands that match, each part of the shell headed by its
            // name.
            readonly property var rows: {
                const terms = search.text.trim().toLowerCase().split(/\s+/).filter(t => t !== "");
                const out = [];
                let last = "";
                for (const c of pane.ipc.catalogue) {
                    const hay = [c.target, pane.ipc.words(c.target), c.fn, pane.ipc.words(c.fn)].concat(c.params.map(p => p.name)).join(" ").toLowerCase();
                    if (!terms.every(t => hay.includes(t)))
                        continue;
                    if (c.target !== last) {
                        out.push({ head: true, target: c.target, key: "@" + c.target });
                        last = c.target;
                    }
                    out.push({ head: false, item: c, key: c.target + " " + c.fn });
                }
                return out;
            }

            width: parent.width
            height: Math.min(340, Math.max(48, catalogue.contentHeight))
            clip: true
            spacing: 1
            boundsBehavior: Flickable.StopAtBounds
            model: catalogue.rows

            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                width: ListView.view.width
                height: cell.modelData.head ? 30 : (entryLoader.item ? entryLoader.item.implicitHeight : 32)

                // A part of the shell: its glyph, its name, the IPC target.
                Item {
                    visible: cell.modelData.head
                    anchors.fill: parent

                    Glyph {
                        id: headGlyph
                        x: 4
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 5
                        text: cell.modelData.head ? pane.ipc.glyphOf(cell.modelData.target) : ""
                        font.pixelSize: 17
                        color: ControlStyle.accent
                    }

                    Text {
                        anchors.left: headGlyph.right
                        anchors.leftMargin: 9
                        anchors.right: targetText.left
                        anchors.rightMargin: 6
                        anchors.baseline: headGlyph.baseline
                        elide: Text.ElideRight
                        text: cell.modelData.head ? ControlStyle.label(pane.ipc.words(cell.modelData.target)) : ""
                        font.family: ControlStyle.ui
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        font.capitalization: ControlStyle.caps
                        color: ControlStyle.ink
                    }

                    Text {
                        id: targetText
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.baseline: headGlyph.baseline
                        text: cell.modelData.head ? cell.modelData.target : ""
                        font.family: ControlStyle.mono
                        font.pixelSize: 10
                        color: Colors.withAlpha(ControlStyle.ink, 0.45)
                    }
                }

                Loader {
                    id: entryLoader
                    active: !cell.modelData.head
                    width: parent.width

                    sourceComponent: CommandEntry {
                        item: cell.modelData.item
                        open: pane.opened === cell.modelData.key
                        onToggled: {
                            pane.opened = pane.opened === cell.modelData.key ? "" : cell.modelData.key;
                            Qt.callLater(() => catalogue.positionViewAtIndex(cell.index, ListView.Contain));
                        }
                        onPinned: pane.opened = ""
                    }
                }
            }
        }

        Text {
            visible: catalogue.rows.length === 0
            width: parent.width
            topPadding: 4
            bottomPadding: 4
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: pane.ipc.catalogue.length === 0 ? (pane.ipc.loading ? "Asking the shell for its commands…" : pane.ipc.catalogueError || "The shell didn't list its commands.") : "Nothing matches “" + search.text.trim() + "”."
            font.family: ControlStyle.body
            font.pixelSize: 12
            color: Colors.withAlpha(ControlStyle.ink, 0.6)
        }
    }
}
