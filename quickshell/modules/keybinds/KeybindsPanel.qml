pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.colors
import qs.components
import qs.modules.lock
import qs.services as Services

// The keybinds manager: every Hyprland bind in ~/.config/hypr/*.lua, on a
// keyboard and in a list, to add, change and delete (services/Keybinds.qml
// does the writing, and puts a file back if Hyprland won't take it).
//
// The keyboard shows one modifier layer at a time: pick it with the chips,
// by clicking the modifier keys, or peek by holding the real ones. Hover a
// key or a list row to see what it does; click a free key to bind it,
// double-click a bind to edit it. While editing, clicking a key on the
// keyboard picks it.
//
// Keys: / searches, N new bind, Enter edits and Delete deletes the selected
// bind, Ctrl+Z undoes the last change, Esc steps back out.
// `qs ipc call keybinds toggle` (SUPER + /).
Item {
    id: root

    anchors.fill: parent
    visible: false

    // the layer picked; what's on the keyboard can differ (see shownLayer)
    property var pickedLayer: ["SUPER"]
    // modifiers held down on the real keyboard
    property var heldMods: []
    // the layer of a list row under the pointer
    property var peekMods: null
    property var selected: null // { mods, key }
    property var hoverSpec: null
    property var hoverBinds: []
    property var hoverRow: null
    property bool editing: false
    property string search: ""
    // where a bind that was just saved will be, to select once it's read
    property var pendingFocus: null

    readonly property var shownLayer: editing ? editor.mods : heldMods.length ? heldMods : peekMods ?? pickedLayer

    function open() {
        visible = true;
        Services.Keybinds.active = true;
        heldMods = [];
        peekMods = null;
        hoverSpec = null;
        hoverRow = null;
        closeEditor();
        keys.forceActiveFocus();
        closeAnim.stop();
        openAnim.restart();
    }

    function close() {
        Services.Keybinds.stopRecording();
        openAnim.stop();
        closeAnim.restart();
    }

    function toggle() {
        if (visible)
            close();
        else
            open();
    }

    Component.onDestruction: {
        Services.Keybinds.stopRecording();
        Services.Keybinds.active = false;
    }

    // ── Apps, for the launchers' names and icons ─────────────────────────────

    readonly property var appIndex: {
        const index = {};
        for (const a of Services.AppRegistry.apps) {
            const words = String(a.exec ?? "").trim().split(/\s+/).map(t => t.replace(/^["']|["']$/g, ""));
            const first = words.filter(t => !/^\w+=/.test(t) && t !== "env")[0] ?? "";
            const prog = first.replace(/^.*\//, "").replace(/\.(sh|py|AppImage)$/i, "").toLowerCase();
            if (prog && !index[prog])
                index[prog] = a;
        }
        return index;
    }

    // The installed app a launcher's program is: by name, without a
    // -stable/-launcher suffix, or the one it's the start of (code → code-oss).
    function appEntry(prog) {
        const p = String(prog ?? "").replace(/\.(sh|py|AppImage)$/i, "").toLowerCase();
        if (!p)
            return null;
        const bare = p.replace(/-(stable|launcher|bin|app|desktop)$/, "");
        return appIndex[p] ?? appIndex[bare] ?? appIndex[Object.keys(appIndex).find(k => k.startsWith(bare + "-")) ?? ""] ?? null;
    }

    function appIcon(prog) {
        if (!prog)
            return "";
        const a = appEntry(prog);
        return a ? Services.AppRegistry.iconForDesktopIcon(a.icon) : Services.AppRegistry.iconForClass(prog);
    }

    function appName(prog) {
        return appEntry(prog)?.name ?? "";
    }

    // ── Searching ────────────────────────────────────────────────────────────

    readonly property var matches: {
        const q = search.trim().toLowerCase();
        if (!q)
            return null;
        const words = q.split(/\s+/);
        const found = new Set();
        for (const b of Services.Keybinds.binds) {
            const hay = [b.title, b.category === "app" ? appName(b.app) : "", b.description ?? "",
                KeyData.comboText(b.mods.map(m => KeyData.modLabel(m)), KeyData.keyLabel(b.key)), b.keys,
                typeof b.param === "string" ? b.param : "", b.section, b.file].join(" ").toLowerCase();
            if (words.every(w => hay.includes(w)))
                found.add(b.id);
        }
        return found;
    }

    // ── The key in hand ──────────────────────────────────────────────────────

    function specFor(name) {
        const n = Services.Keybinds.norm(name);
        return KeyData.keys.find(k => Services.Keybinds.norm(k.name) === n)
            ?? KeyData.extras.find(k => Services.Keybinds.norm(k.name) === n)
            ?? { name: name, legend: KeyData.keyLabel(name), x: 0, y: 0, w: 1, mod: "" };
    }

    // What the card beside the keyboard shows: the key under the pointer,
    // the list row under it, the selection, or (null) the layer.
    readonly property var focusKey: {
        if (hoverSpec)
            return { spec: hoverSpec, mods: shownLayer, binds: hoverBinds };
        if (hoverRow)
            return { spec: specFor(hoverRow.key), mods: hoverRow.mods, binds: Services.Keybinds.bindsAt(hoverRow.mods, hoverRow.key) };
        if (selected && !editing)
            return { spec: specFor(selected.key), mods: selected.mods, binds: Services.Keybinds.bindsAt(selected.mods, selected.key) };
        return null;
    }

    readonly property string selectedKey: selected && KeyData.layerKey(selected.mods) === KeyData.layerKey(shownLayer) ? Services.Keybinds.norm(selected.key) : ""
    readonly property string selectedId: {
        if (!selected)
            return "";
        const b = Services.Keybinds.bindsAt(selected.mods, selected.key);
        return b.length ? b[0].id : "";
    }

    function select(mods, key) {
        selected = { mods: KeyData.sortMods(mods), key: key };
        pickedLayer = KeyData.sortMods(mods);
    }

    function selectBind(b) {
        select(b.mods, b.key);
        bindList.reveal(b.id);
    }

    // ── Editing ──────────────────────────────────────────────────────────────

    function edit(b) {
        if (!b || !b.editable)
            return;
        hoverSpec = null;
        hoverRow = null;
        editor.start(b);
        editing = true;
    }

    function newBind(mods, key) {
        if (Services.Keybinds.files.length === 0)
            return;
        hoverSpec = null;
        hoverRow = null;
        editor.start(null, mods ?? shownLayer, key ?? "");
        editing = true;
    }

    function closeEditor() {
        Services.Keybinds.stopRecording();
        editing = false;
        keys.forceActiveFocus();
    }

    function remove(b) {
        if (!b || !b.editable)
            return;
        const words = KeyData.comboText(b.mods.map(m => KeyData.modLabel(m)), KeyData.keyLabel(b.key));
        if (save([{ op: "delete", file: b.file, line: b.line, raw: b.raw }], "Removed " + words)
                && selected && KeyData.layerKey(selected.mods) === KeyData.layerKey(b.mods)
                && Services.Keybinds.norm(selected.key) === Services.Keybinds.norm(b.key))
            selected = null;
    }

    Connections {
        target: Services.Keybinds

        function onSaved(lines, summary) {
            const ops = root.lastOps ?? [];
            let focus = null;
            for (const i in lines) {
                const op = ops[Number(i)];
                if (op && op.op !== "delete")
                    focus = { file: op.file, line: lines[i], mods: op.keysChanged || op.op === "add" ? op.mods : null };
            }
            root.pendingFocus = focus;
            if (root.editing)
                root.closeEditor();
            toast.show("ok", summary, true);
        }

        // The editor says what went wrong itself while it's open.
        function onFailed(message) {
            if (root.editing) {
                editor.error = message;
                toast.kind = "";
            } else {
                toast.show("error", message, false);
            }
        }

        function onUndone(summary) {
            toast.show("ok", "Undid: " + summary, false);
        }

        function onBindsChanged() {
            const f = root.pendingFocus;
            if (!f)
                return;
            const b = Services.Keybinds.binds.find(x => x.file === f.file && x.line === f.line);
            if (b) {
                root.pendingFocus = null;
                root.selectBind(b);
                // only now is it known whether Hyprland has it
                if (toast.kind === "ok")
                    toast.live = Services.Keybinds.isLive(b) ? "yes" : "no";
            }
        }
    }

    property var lastOps: null

    function save(ops, summary) {
        if (!Services.Keybinds.apply(ops, summary))
            return false;
        lastOps = ops;
        toast.show("busy", "", false);
        return true;
    }

    // ── Scrim ────────────────────────────────────────────────────────────────

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Colors.scrim
        opacity: 0
        enabled: opacity > 0.01

        MouseArea {
            anchors.fill: parent
            enabled: parent.enabled
            onClicked: root.editing ? root.closeEditor() : root.close()
        }
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: scrim; property: "opacity"; to: 0.55; duration: 240; easing.type: Easing.OutCubic }
        NumberAnimation { target: panel; property: "opacity"; to: 1; duration: 240; easing.type: Easing.OutCubic }
        NumberAnimation { target: panel; property: "scale"; to: 1; duration: 320; easing.type: Easing.OutBack }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation { target: scrim; property: "opacity"; to: 0; duration: 200; easing.type: Easing.InCubic }
        NumberAnimation { target: panel; property: "opacity"; to: 0; duration: 200; easing.type: Easing.InCubic }
        NumberAnimation { target: panel; property: "scale"; to: 0.94; duration: 200; easing.type: Easing.InCubic }
        onFinished: {
            root.visible = false;
            Services.Keybinds.active = false;
        }
    }

    // ── Panel ────────────────────────────────────────────────────────────────

    Rectangle {
        id: panel

        PanelDecor {
            radius: panel.radius
            title: "keybinds"
        }

        anchors.centerIn: parent
        width: Math.min(1260, parent.width * 0.9)
        height: Math.min(980, parent.height * 0.9)
        radius: Services.DesktopTheme.rad(30)
        color: Colors.surface_container_lowest
        border.width: 1
        border.color: Colors.withAlpha(Colors.outline_variant, 0.6)
        clip: true
        opacity: 0
        scale: 0.94

        // Holds the keyboard when no field does. The keys are handled on the
        // panel itself, so they also arrive from the editor's fields (Esc).
        Item {
            id: keys
            focus: true
        }

        Keys.onPressed: event => {
            if (KeyData.isModifier(event)) {
                // peeking, only while no field has the keyboard
                const m = KeyData.modOfKey(event);
                if (m && keys.activeFocus && !root.editing && !root.heldMods.includes(m))
                    root.heldMods = KeyData.sortMods(root.heldMods.concat([m]));
                return;
            }
            if (event.key === Qt.Key_Escape) {
                if (root.editing)
                    root.closeEditor();
                else if (root.search !== "")
                    searchField.text = "";
                else if (root.selected)
                    root.selected = null;
                else
                    root.close();
            } else if (root.editing || !keys.activeFocus) {
                return;
            } else if (event.key === Qt.Key_Slash || (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier))) {
                searchField.forceActiveFocus();
            } else if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier)) {
                Services.Keybinds.undo();
            } else if (event.key === Qt.Key_N && !event.modifiers) {
                root.newBind();
            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_E) && root.selected) {
                const b = Services.Keybinds.bindsAt(root.selected.mods, root.selected.key);
                if (b.length === 1)
                    root.edit(b[0]);
                else if (b.length === 0)
                    root.newBind(root.selected.mods, root.selected.key);
            } else if (event.key === Qt.Key_Delete && root.selected) {
                const b = Services.Keybinds.bindsAt(root.selected.mods, root.selected.key);
                if (b.length === 1 && b[0].editable)
                    detail.askRemove(b[0]);
            } else {
                return;
            }
            event.accepted = true;
        }

        Keys.onReleased: event => {
            const m = KeyData.modOfKey(event);
            if (m)
                root.heldMods = root.heldMods.filter(x => x !== m);
        }

        // A modifier let go while another window had the keyboard never
        // reaches us, nor does a shortcut being recorded.
        Connections {
            target: root.Window.window

            function onActiveChanged() {
                if (!root.Window.window.active) {
                    root.heldMods = [];
                    // its keys would go to another window now
                    Services.Keybinds.stopRecording();
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Colors.withAlpha(Services.DesktopTheme.accent, 0.07) }
                GradientStop { position: 0.4; color: "transparent" }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 26
            spacing: 14

            // ── Header ───────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: false
                Layout.preferredHeight: 48
                spacing: 14

                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    radius: Services.DesktopTheme.rad(14)
                    color: Colors.primary_container

                    Glyph {
                        anchors.centerIn: parent
                        text: "keyboard"
                        filled: true
                        font.pixelSize: 24
                        color: Colors.on_primary_container
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: "Keybinds"
                        font.pixelSize: 21
                        font.weight: Font.Bold
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            const k = Services.Keybinds;
                            if (k.error === "no-lua-config")
                                return "No Lua config in " + (k.dir || "~/.config/hypr");
                            if (k.error)
                                return k.error;
                            if (!k.loaded)
                                return "Reading your binds…";
                            const names = k.files.map(f => f.name);
                            return k.binds.length + " binds in " + (names.length > 1 ? names.slice(0, -1).join(", ") + " and " + names[names.length - 1] : names[0] ?? "your config");
                        }
                        font.pixelSize: 13
                        color: Services.Keybinds.error ? Colors.error : Colors.on_surface_variant
                        elide: Text.ElideRight
                    }
                }

                // search
                Rectangle {
                    Layout.preferredWidth: 280
                    Layout.preferredHeight: 40
                    radius: Services.DesktopTheme.rad(20)
                    color: Colors.surface_container
                    border.width: 1
                    border.color: searchField.activeFocus ? Services.DesktopTheme.accent : Colors.withAlpha(Colors.outline_variant, 0.8)

                    Glyph {
                        id: searchGlyph
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: "search"
                        font.pixelSize: 18
                        color: Colors.on_surface_variant
                    }

                    StyledTextField {
                        id: searchField
                        anchors.left: searchGlyph.right
                        anchors.leftMargin: 6
                        anchors.right: clearSearch.left
                        anchors.verticalCenter: parent.verticalCenter
                        placeholderText: "Search binds   /"
                        font.pixelSize: 13
                        borderWidth: 0
                        backgroundColor: "transparent"
                        padding: 0
                        onTextChanged: root.search = text
                        Keys.onEscapePressed: {
                            if (text !== "")
                                text = "";
                            else
                                keys.forceActiveFocus();
                        }
                        Keys.onReturnPressed: {
                            const first = Services.Keybinds.binds.find(b => root.matches?.has(b.id));
                            if (first)
                                root.selectBind(first);
                            keys.forceActiveFocus();
                        }
                    }

                    GlyphButton {
                        id: clearSearch
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 26
                        implicitHeight: 26
                        visible: searchField.text !== ""
                        icon: "close"
                        iconSize: 15
                        onClicked: searchField.text = ""
                    }
                }

                PanelButton {
                    icon: "add"
                    text: "New bind"
                    primary: true
                    enabled: Services.Keybinds.files.length > 0
                    onClicked: root.newBind()
                }

                GlyphButton {
                    icon: "close"
                    iconSize: 20
                    implicitWidth: 36
                    implicitHeight: 36
                    onClicked: root.close()
                }
            }

            // ── Layers ───────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: false
                Layout.preferredHeight: 32
                spacing: 6
                visible: !Services.Keybinds.error

                Repeater {
                    model: Services.Keybinds.layers

                    delegate: ClickableRect {
                        id: layerChip
                        required property var modelData
                        readonly property bool current: KeyData.layerKey(root.shownLayer) === modelData.key

                        implicitWidth: layerRow.implicitWidth + 24
                        implicitHeight: 32
                        radius: Services.DesktopTheme.rad(16)
                        cursorShape: Qt.PointingHandCursor
                        color: current ? Services.DesktopTheme.accent : hovered ? Colors.surface_container_high : Colors.surface_container
                        border.width: current ? 0 : 1
                        border.color: Colors.withAlpha(Colors.outline_variant, 0.7)
                        onClicked: {
                            if (root.editing)
                                editor.mods = layerChip.modelData.mods;
                            else
                                root.pickedLayer = layerChip.modelData.mods;
                        }

                        Behavior on color {
                            ColorAnimation { duration: 140 }
                        }

                        Row {
                            id: layerRow
                            anchors.centerIn: parent
                            spacing: 8

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: KeyData.layerName(layerChip.modelData.mods)
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: layerChip.current ? Colors.on_primary : Colors.on_surface
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(20, countText.implicitWidth + 10)
                                height: 18
                                radius: 9
                                color: layerChip.current ? Colors.withAlpha(Colors.on_primary, 0.18) : Colors.surface_container_highest

                                StyledText {
                                    id: countText
                                    anchors.centerIn: parent
                                    text: layerChip.modelData.count
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: layerChip.current ? Colors.on_primary : Colors.on_surface_variant
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: root.editing ? "Click a key to pick it" : root.heldMods.length ? "Peeking at " + KeyData.layerName(root.heldMods) : "Hold Super, Alt, Ctrl or Shift to peek"
                    font.pixelSize: 12
                    color: Colors.on_surface_variant
                    opacity: 0.8
                }
            }

            // ── The keyboard and the card beside it ──────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: false
                Layout.preferredHeight: board.implicitHeight
                spacing: 20
                visible: !Services.Keybinds.error

                KeyboardMap {
                    id: board
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    mods: root.shownLayer
                    selectedKey: root.selectedKey
                    targetKey: root.editing ? Services.Keybinds.norm(editor.key) : ""
                    picking: root.editing
                    matches: root.matches
                    appIcon: name => root.appIcon(name)

                    onKeyHovered: (spec, binds) => {
                        root.hoverSpec = spec;
                        root.hoverBinds = binds;
                    }

                    onKeyClicked: (spec, binds) => {
                        if (root.editing) {
                            if (spec.mod)
                                editor.toggleMod(spec.mod);
                            else
                                editor.setKey(spec.name);
                        } else if (spec.mod) {
                            const l = root.pickedLayer.includes(spec.mod) ? root.pickedLayer.filter(m => m !== spec.mod) : root.pickedLayer.concat([spec.mod]);
                            root.pickedLayer = KeyData.sortMods(l);
                        } else if (binds.length === 0) {
                            root.newBind(root.shownLayer, spec.name);
                        } else {
                            root.select(root.shownLayer, spec.name);
                            if (binds[0].id)
                                bindList.reveal(binds[0].id);
                        }
                        keys.forceActiveFocus();
                    }

                    onKeyDoubleClicked: (spec, binds) => {
                        if (!root.editing && binds.length === 1)
                            root.edit(binds[0]);
                    }
                }

                DetailCard {
                    id: detail
                    Layout.preferredWidth: 300
                    Layout.fillHeight: true
                    spec: root.focusKey?.spec ?? null
                    mods: root.focusKey?.mods ?? root.shownLayer
                    binds: root.focusKey?.binds ?? []
                    appIcon: name => root.appIcon(name)
                    appName: name => root.appName(name)
                    onEdit: b => root.edit(b)
                    onRemove: b => root.remove(b)
                    onBindHere: (mods, key) => root.newBind(mods, key)
                }
            }

            // ── The list, or the editor over it ──────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !Services.Keybinds.error

                BindList {
                    id: bindList
                    anchors.fill: parent
                    opacity: root.editing ? 0 : 1
                    visible: opacity > 0
                    binds: Services.Keybinds.binds
                    matches: root.matches
                    selectedId: root.selectedId
                    appIcon: name => root.appIcon(name)
                    appName: name => root.appName(name)

                    Behavior on opacity {
                        NumberAnimation { duration: 180 }
                    }

                    onRowHovered: b => {
                        root.hoverRow = b;
                        root.peekMods = b ? KeyData.sortMods(b.mods) : null;
                    }
                    onRowClicked: b => {
                        root.select(b.mods, b.key);
                        keys.forceActiveFocus();
                    }
                    onRowDoubleClicked: b => root.edit(b)
                    onEdit: b => root.edit(b)
                    onRemove: b => root.remove(b)
                }

                BindEditor {
                    id: editor
                    anchors.fill: parent
                    opacity: root.editing ? 1 : 0
                    visible: opacity > 0
                    appIcon: name => root.appIcon(name)
                    appName: name => root.appName(name)
                    transform: Translate {
                        y: root.editing ? 0 : 24
                        Behavior on y {
                            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: 180 }
                    }

                    onCancelled: root.closeEditor()
                    onSaveRequested: (ops, summary) => root.save(ops, summary)
                    onDeleteRequested: b => root.remove(b)
                }
            }

            // No Lua config, or the script failed.
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: Services.Keybinds.error !== ""

                EmptyState {
                    glyph: "⌨"
                    title: Services.Keybinds.error === "no-lua-config" ? "No hyprland.lua found" : "Couldn't read your binds"
                    subtitle: Services.Keybinds.error === "no-lua-config"
                        ? "This edits Hyprland's Lua config (0.56 and later) in " + (Services.Keybinds.dir || "~/.config/hypr")
                        : Services.Keybinds.error
                }
            }
        }

        // The config raised while being read: say so over the list.
        Rectangle {
            visible: Services.Keybinds.probeError !== "" && !root.editing
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 26
            width: Math.min(parent.width - 80, probeText.implicitWidth + 60)
            height: 40
            radius: Services.DesktopTheme.rad(14)
            color: Colors.error_container

            Row {
                anchors.centerIn: parent
                spacing: 8

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "warning"
                    font.pixelSize: 16
                    color: Colors.on_error_container
                }

                StyledText {
                    id: probeText
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, panel.width - 160)
                    text: "Your config stopped with an error partway, so this may not be every bind: " + Services.Keybinds.probeError.split("\n")[0]
                    font.pixelSize: 12
                    color: Colors.on_error_container
                    elide: Text.ElideRight
                }
            }
        }

        // ── Toast ────────────────────────────────────────────────────────────
        Rectangle {
            id: toast

            property string kind: ""
            property string message: ""
            property bool undoable: false
            // whether Hyprland has the bind just saved: "", "yes" or "no"
            property string live: ""
            readonly property bool busy: Services.Keybinds.busy
            readonly property bool shown: kind !== "" || busy

            function show(k, text, canUndo) {
                kind = k;
                message = text;
                undoable = canUndo;
                live = "";
                hideTimer.interval = k === "error" ? 10000 : 7000;
                if (k !== "busy")
                    hideTimer.restart();
            }

            anchors.horizontalCenter: parent.horizontalCenter
            y: shown ? parent.height - height - 22 : parent.height + 12
            z: 50
            width: Math.min(parent.width - 120, toastRow.implicitWidth + 36)
            height: Math.max(46, toastRow.implicitHeight + 20)
            radius: Services.DesktopTheme.rad(18)
            color: kind === "error" && !busy ? Colors.error_container : Colors.inverse_surface
            opacity: shown ? 1 : 0

            Behavior on y {
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }

            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }

            readonly property color ink: kind === "error" && !busy ? Colors.on_error_container : Colors.inverse_on_surface

            HoverHandler {
                id: toastHover
                onHoveredChanged: {
                    if (hovered)
                        hideTimer.stop();
                    else if (toast.kind !== "" && toast.kind !== "busy")
                        hideTimer.restart();
                }
            }

            Timer {
                id: hideTimer
                interval: 7000
                onTriggered: toast.kind = ""
            }

            RowLayout {
                id: toastRow
                anchors.centerIn: parent
                width: Math.min(implicitWidth, toast.width - 36)
                spacing: 12

                Spinner {
                    visible: toast.busy
                    running: toast.busy
                    arcColor: Colors.inverse_primary
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                }

                Glyph {
                    visible: !toast.busy
                    text: toast.kind === "error" ? "error" : "check_circle"
                    filled: true
                    font.pixelSize: 19
                    color: toast.kind === "error" ? Colors.on_error_container : Colors.inverse_primary
                }

                StyledText {
                    Layout.maximumWidth: 640
                    text: toast.busy ? ({
                            saving: "Checking and saving…",
                            reloading: "Reloading Hyprland…",
                            checking: "Making sure Hyprland took it…",
                            restoring: "Putting the file back…"
                        })[Services.Keybinds.phase] ?? "Working…"
                        : toast.message + (toast.live === "yes" ? ", live in Hyprland" : toast.live === "no" ? "; Hyprland hasn't loaded it yet" : "")
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: toast.ink
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }

                ClickableRect {
                    visible: !toast.busy && toast.kind === "ok" && toast.undoable && Services.Keybinds.lastChange !== null
                    implicitWidth: undoText.implicitWidth + 24
                    implicitHeight: 30
                    radius: Services.DesktopTheme.rad(15)
                    cursorShape: Qt.PointingHandCursor
                    color: hovered ? Colors.withAlpha(Colors.inverse_primary, 0.25) : "transparent"
                    onClicked: Services.Keybinds.undo()

                    StyledText {
                        id: undoText
                        anchors.centerIn: parent
                        text: "Undo"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: Colors.inverse_primary
                    }
                }

                GlyphButton {
                    visible: !toast.busy && toast.kind === "error"
                    implicitWidth: 26
                    implicitHeight: 26
                    icon: "close"
                    iconSize: 15
                    iconColor: toast.ink
                    hoverColor: Colors.withAlpha(toast.ink, 0.12)
                    onClicked: toast.kind = ""
                }
            }
        }
    }
}
