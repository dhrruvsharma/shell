pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.colors
import qs.components
import qs.modules.lock
import qs.services as Services

// Making or changing a bind. The shortcut can be recorded (Hyprland stands
// aside meanwhile, see services/Keybinds.qml), picked on the keyboard above,
// or built from the modifier toggles; anything already on it is named, and
// can be replaced. The action is chosen by kind: a command, one of the
// shell's panels, a window or workspace move, or Lua for anything else.
// The line that will be written shows underneath.
Card {
    id: editor

    // the bind being changed, or null for a new one
    property var bind: null
    property var mods: []
    property string key: ""
    property string tab: "run"
    property string preset: "exec"
    property string param: ""
    property var flags: ({})
    property string description: ""
    property string file: ""
    property string section: ""
    property bool whereTouched: false
    property bool replace: false
    property string error: ""
    property var appIcon: null
    property var appName: null

    signal cancelled
    signal saveRequested(var ops, string summary)
    signal deleteRequested(var bind)

    // what the bind was when the editor opened
    property string _preset: ""
    property string _param: ""
    property var _flags: ({})

    radius: Services.DesktopTheme.rad(20)
    color: Colors.surface_container_low

    // ── State ────────────────────────────────────────────────────────────────

    function start(b, startMods, startKey) {
        Services.Keybinds.stopRecording();
        bind = b;
        error = "";
        replace = false;
        whereTouched = false;
        heldMods = [];
        armedDelete = false;
        if (b) {
            mods = KeyData.sortMods(b.mods);
            key = b.key;
            preset = KeyData.presetFor(b.preset, b.param);
            param = preset === "maximize" || preset === "fullscreen" ? "" : String(b.param ?? "");
            description = b.description ?? "";
            const f = {};
            for (const fl of KeyData.flags)
                f[fl.id] = !!b.opts?.[fl.id];
            flags = f;
            file = b.file;
            section = b.section;
        } else {
            mods = KeyData.sortMods(startMods ?? []);
            key = startKey ?? "";
            preset = "exec";
            param = "";
            description = "";
            flags = {};
        }
        tab = KeyData.preset(preset)?.tab ?? "lua";
        _preset = preset;
        _param = param;
        _flags = Object.assign({}, flags);
        suggestWhere();
        ipcSearch.text = "";
    }

    readonly property string dispatcherExpr: KeyData.dispatcher(preset, param)
    readonly property var conflicts: key ? Services.Keybinds.bindsAt(mods, key).filter(b => !bind || b.id !== bind.id) : []
    readonly property bool canReplace: conflicts.some(c => c.editable)
    readonly property bool comboEdited: !bind || KeyData.layerKey(mods) !== KeyData.layerKey(bind.mods)
        || Services.Keybinds.norm(key) !== Services.Keybinds.norm(bind.key)
    readonly property bool actionEdited: !bind || preset !== _preset || param !== _param
    readonly property bool flagsEdited: KeyData.flags.some(f => !!flags[f.id] !== !!_flags[f.id])
    readonly property bool descriptionEdited: bind ? description !== (bind.description ?? "") : description !== ""
    readonly property bool dirty: comboEdited || actionEdited || flagsEdited || descriptionEdited || (replace && canReplace)

    function toggleMod(m) {
        Services.Keybinds.stopRecording();
        mods = mods.includes(m) ? mods.filter(x => x !== m) : KeyData.sortMods(mods.concat([m]));
        suggestWhere();
    }

    function setKey(name) {
        Services.Keybinds.stopRecording();
        key = name;
        error = "";
    }

    function setFlag(id, on) {
        const f = Object.assign({}, flags);
        f[id] = on;
        flags = f;
    }

    // Switch the action's kind, carrying over what still makes sense: a
    // command stays a command, a workspace a workspace, and Lua starts from
    // the action as it was.
    function choose(id) {
        const next = KeyData.preset(id);
        if (!next)
            return;
        if (id !== preset) {
            const was = KeyData.preset(preset)?.param ?? "";
            const now = next.param ?? "";
            const commandish = k => k === "command" || k === "ipc";
            if (id === "lua")
                param = dispatcherExpr || (bind?.rawArgs?.dsp ?? "");
            else if (!(commandish(now) && commandish(was)) && !(now === "workspace" && was === "workspace"))
                param = now === "workspace" ? "1" : now === "direction" ? "left" : id === "special" ? "magic" : "";
        }
        preset = id;
        tab = next.tab;
        error = "";
        suggestWhere();
    }

    function chooseTab(id) {
        if (KeyData.preset(preset)?.tab === id) {
            tab = id;
            return;
        }
        const first = { run: "exec", shell: "ipc", workspace: "focusws", lua: "lua" }[id];
        if (first) {
            choose(first);
        } else {
            tab = id;
            preset = "";
        }
    }

    // Where a new bind goes: the shell's file for a shell panel, and the
    // heading whose binds share its modifiers (ALT + … under the ALT apps).
    function suggestWhere() {
        if (bind || whereTouched)
            return;
        const files = Services.Keybinds.files;
        const shellFile = files.find(f => f.name === "quickshell.lua");
        const target = preset === "ipc" && shellFile ? shellFile : files.find(f => f.name === "hyprland.lua") ?? files[0];
        if (!target) {
            file = "";
            section = "";
            return;
        }
        const layer = KeyData.layerKey(mods);
        let best = null;
        let most = 0;
        for (const s of target.sections) {
            const n = Services.Keybinds.binds.filter(b => b.file === target.name && b.section === s.title && KeyData.layerKey(b.mods) === layer).length;
            if (n > most) {
                best = s;
                most = n;
            }
        }
        file = target.name;
        section = (best ?? target.sections[0])?.title ?? "";
    }

    function sectionInfo() {
        const f = Services.Keybinds.fileInfo(file);
        return f ? f.sections.find(s => s.title === section) ?? f.sections[f.sections.length - 1] ?? null : null;
    }

    readonly property string comboWords: KeyData.comboText(mods.map(m => KeyData.modLabel(m)), key ? KeyData.keyLabel(key) : "")

    function commit() {
        error = "";
        if (!key) {
            error = "Pick a key: record one, or click it on the keyboard";
            return;
        }
        if (!dispatcherExpr) {
            error = tab === "window" && !preset ? "Choose what it does to the window" : "Fill in what it does";
            return;
        }
        if (!dirty) {
            cancelled();
            return;
        }
        const ops = [];
        if (replace)
            for (const c of conflicts)
                if (c.editable)
                    ops.push({ op: "delete", file: c.file, line: c.line, raw: c.raw });
        if (!bind) {
            const s = sectionInfo();
            if (!file) {
                error = "There's no config file to save it in";
                return;
            }
            ops.push({
                op: "add", file: file, anchorLine: s?.anchorLine ?? 0, anchorRaw: s?.anchorRaw ?? "",
                mods: mods, key: key, dispatcher: dispatcherExpr, flags: flags, description: description
            });
        } else {
            const op = { op: "edit", file: bind.file, line: bind.line, raw: bind.raw };
            if (comboEdited) {
                op.keysChanged = true;
                op.mods = mods;
                op.key = key;
            }
            if (actionEdited)
                op.dispatcher = dispatcherExpr;
            if (flagsEdited)
                op.flags = flags;
            if (descriptionEdited)
                op.description = description;
            ops.push(op);
        }
        saveRequested(ops, (bind ? "Changed " : "Bound ") + comboWords);
    }

    // The line that will be written (keybinds.py has the last word).
    readonly property string preview: {
        const info = Services.Keybinds.fileInfo(bind ? bind.file : file);
        const mainVar = info?.mainMod ?? null;
        const sorted = KeyData.sortMods(mods);
        let keysExpr;
        if (bind && !comboEdited) {
            keysExpr = bind.rawArgs?.keys ?? "";
        } else {
            const useVar = mainVar && sorted[0] === "SUPER" && (!bind || String(bind.rawArgs?.keys ?? "").includes(mainVar));
            keysExpr = useVar ? mainVar + " .. \" + " + KeyData.comboText(sorted.slice(1), key || "…") + "\""
                : "\"" + KeyData.comboText(sorted, key || "…") + "\"";
        }
        const dsp = bind && !actionEdited ? bind.rawArgs?.dsp ?? "" : dispatcherExpr || "…";
        let opts = "";
        if (bind && !flagsEdited && !descriptionEdited) {
            opts = bind.rawArgs?.opts ?? "";
        } else {
            const parts = [];
            for (const k in (bind?.opts ?? {}))
                if (!KeyData.flags.some(f => f.id === k))
                    parts.push(k + " = " + JSON.stringify(bind.opts[k]));
            for (const f of KeyData.flags)
                if (flags[f.id])
                    parts.push(f.id + " = true");
            if (description)
                parts.push("description = " + KeyData.luaString(description));
            opts = parts.length ? "{ " + parts.join(", ") + " }" : "";
        }
        return "hl.bind(" + keysExpr + ", " + dsp + (opts ? ", " + opts : "") + ")";
    }

    // ── Recording ────────────────────────────────────────────────────────────

    property var heldMods: []
    readonly property bool recording: Services.Keybinds.recording

    function record() {
        if (recording) {
            Services.Keybinds.stopRecording();
            return;
        }
        heldMods = [];
        Services.Keybinds.startRecording();
        capture.forceActiveFocus();
    }

    onRecordingChanged: {
        heldMods = [];
        if (!recording && capture.activeFocus)
            editor.forceActiveFocus();
    }

    function took(newMods, newKey) {
        mods = KeyData.sortMods(newMods);
        key = newKey;
        error = "";
        Services.Keybinds.stopRecording();
        suggestWhere();
    }

    Item {
        id: capture
        focus: false

        Keys.onPressed: event => {
            event.accepted = true;
            if (!editor.recording)
                return;
            if (KeyData.isModifier(event)) {
                const m = KeyData.modOfKey(event);
                if (m && !editor.heldMods.includes(m))
                    editor.heldMods = KeyData.sortMods(editor.heldMods.concat([m]));
                return;
            }
            const name = KeyData.nameOf(event);
            if (name)
                editor.took(KeyData.modsOf(event.modifiers), name);
        }

        Keys.onReleased: event => {
            event.accepted = true;
            const m = KeyData.modOfKey(event);
            if (m)
                editor.heldMods = editor.heldMods.filter(x => x !== m);
        }
    }

    // ── Layout ───────────────────────────────────────────────────────────────

    component Caption: StyledText {
        font.pixelSize: 11
        font.weight: Font.Bold
        font.letterSpacing: 0.8
        color: Colors.on_surface_variant
    }

    component Chip: ClickableRect {
        id: chip
        property string label: ""
        property string icon: ""
        property bool on: false
        property int pad: 14
        implicitWidth: chipRow.implicitWidth + pad * 2
        implicitHeight: 28
        radius: Services.DesktopTheme.rad(14)
        cursorShape: Qt.PointingHandCursor
        color: on ? Colors.withAlpha(Services.DesktopTheme.accent, 0.9) : hovered ? Colors.surface_container_highest : Colors.surface_container_high
        border.width: on ? 0 : 1
        border.color: Colors.withAlpha(Colors.outline_variant, 0.7)

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 5

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.icon !== ""
                text: chip.icon
                font.pixelSize: 15
                color: chip.on ? Colors.on_primary : Colors.on_surface_variant
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.label !== ""
                text: chip.label
                font.pixelSize: 12
                font.weight: chip.on ? Font.DemiBold : Font.Medium
                color: chip.on ? Colors.on_primary : Colors.on_surface
            }
        }
    }

    component Field: StyledTextField {
        font.pixelSize: 13
        leftPadding: 12
        rightPadding: 12
        topPadding: 8
        bottomPadding: 8
        selectByMouse: true
        backgroundColor: Colors.surface_container
        focusBorderColor: Services.DesktopTheme.accent
        borderColor: Colors.withAlpha(Colors.outline_variant, 0.8)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        // ── Head ─────────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Glyph {
                text: editor.bind ? "edit" : "add_circle"
                filled: true
                font.pixelSize: 20
                color: Services.DesktopTheme.accent
            }

            StyledText {
                text: editor.bind ? "Edit bind" : "New bind"
                font.pixelSize: 16
                font.weight: Font.Bold
            }

            StyledText {
                Layout.fillWidth: true
                text: editor.bind ? editor.bind.file + ":" + editor.bind.line + "  ·  " + editor.bind.section : ""
                font.pixelSize: 12
                color: Colors.on_surface_variant
                elide: Text.ElideRight
            }

            GlyphButton {
                icon: "close"
                onClicked: editor.cancelled()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 24

            // ── Shortcut and action ──────────────────────────────────────────
            ColumnLayout {
                Layout.preferredWidth: Math.round((editor.width - 36 - 24) * 0.55)
                Layout.maximumWidth: Math.round((editor.width - 36 - 24) * 0.55)
                Layout.fillWidth: false
                Layout.fillHeight: true
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Caption {
                        Layout.fillWidth: true
                        text: "SHORTCUT"
                    }

                    Repeater {
                        model: ["SUPER", "CTRL", "ALT", "SHIFT"]

                        delegate: Chip {
                            required property string modelData
                            implicitHeight: 24
                            pad: 10
                            label: KeyData.modLabel(modelData)
                            on: editor.mods.includes(modelData)
                            onClicked: editor.toggleMod(modelData)
                        }
                    }
                }

                Rectangle {
                    id: comboBox
                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    radius: Services.DesktopTheme.rad(14)
                    color: Colors.surface_container
                    border.width: editor.recording ? 2 : 1
                    border.color: editor.recording ? Services.DesktopTheme.accent : Colors.withAlpha(Colors.outline_variant, 0.8)

                    // Recording takes the mouse too: a click or a scroll
                    // here, with modifiers held, binds that.
                    MouseArea {
                        anchors.fill: parent
                        enabled: editor.recording
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onPressed: mouse => editor.took(KeyData.modsOf(mouse.modifiers),
                            mouse.button === Qt.RightButton ? "mouse:273" : mouse.button === Qt.MiddleButton ? "mouse:274" : "mouse:272")
                        onWheel: wheel => editor.took(KeyData.modsOf(wheel.modifiers), wheel.angleDelta.y > 0 ? "mouse_up" : "mouse_down")
                    }

                    KeyCombo {
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !editor.recording
                        mods: editor.mods
                        key: editor.key
                        size: 14
                        placeholder: true
                    }

                    Row {
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        visible: editor.recording
                        spacing: 10

                        KeyCombo {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: editor.heldMods.length > 0
                            mods: editor.heldMods
                            size: 14
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: editor.heldMods.length ? "and a key…" : "Press the shortcut, or click or scroll here"
                            font.pixelSize: 13
                            color: Colors.on_surface_variant
                        }
                    }

                    PanelButton {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        implicitHeight: 36
                        icon: editor.recording ? "stop_circle" : "radio_button_checked"
                        text: editor.recording ? "Esc to stop" : "Record"
                        primary: editor.recording
                        onClicked: editor.record()
                    }
                }

                // what's on that key already
                RowLayout {
                    Layout.fillWidth: true
                    visible: editor.conflicts.length > 0
                    spacing: 8

                    Glyph {
                        text: "warning"
                        filled: true
                        font.pixelSize: 15
                        color: Colors.error
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            const c = editor.conflicts[0];
                            if (!c)
                                return "";
                            const what = c.liveOnly ? "something outside your files" : "“" + (c.category === "app" && editor.appName ? editor.appName(c.app) || c.title : c.title) + "”" + (c.generated ? " (a loop)" : "");
                            return "Already " + what + (editor.conflicts.length > 1 ? " and " + (editor.conflicts.length - 1) + " more" : "") + "; both would go off";
                        }
                        font.pixelSize: 12
                        color: Colors.error
                        elide: Text.ElideRight
                    }

                    Chip {
                        visible: editor.canReplace
                        implicitHeight: 24
                        pad: 10
                        icon: editor.replace ? "check" : ""
                        label: "Replace it"
                        on: editor.replace
                        onClicked: editor.replace = !editor.replace
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 6

                    Caption {
                        Layout.fillWidth: true
                        text: "ACTION"
                    }

                    Repeater {
                        model: KeyData.tabs

                        delegate: Chip {
                            required property var modelData
                            implicitHeight: 26
                            pad: 10
                            icon: modelData.icon
                            label: modelData.label
                            on: editor.tab === modelData.id
                            onClicked: editor.chooseTab(modelData.id)
                        }
                    }
                }

                // ── The tab's content ────────────────────────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // Run: a command
                    ColumnLayout {
                        anchors.fill: parent
                        visible: editor.tab === "run"
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Field {
                                id: commandField
                                Layout.fillWidth: true
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                placeholderText: "Command, e.g. kitty -e btop"
                                text: editor.preset === "exec" || editor.preset === "ipc" ? editor.param : ""
                                onTextEdited: {
                                    editor.preset = "exec";
                                    editor.param = text;
                                }
                                Keys.onReturnPressed: editor.commit()
                            }

                            PanelButton {
                                implicitHeight: 36
                                icon: "apps"
                                text: "Apps"
                                onClicked: appPicker.visible = !appPicker.visible
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: KeyData.commands

                                delegate: Chip {
                                    required property var modelData
                                    implicitHeight: 26
                                    pad: 10
                                    icon: modelData.icon
                                    label: modelData.label
                                    on: editor.preset === "exec" && editor.param === modelData.cmd
                                    onClicked: {
                                        editor.choose("exec");
                                        editor.param = modelData.cmd;
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }

                    // Shell: the shell's IPC commands
                    ColumnLayout {
                        anchors.fill: parent
                        visible: editor.tab === "shell"
                        spacing: 6

                        Field {
                            id: ipcSearch
                            Layout.fillWidth: true
                            placeholderText: "Search the shell's panels and actions"
                        }

                        ListView {
                            id: ipcList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 2
                            boundsBehavior: Flickable.StopAtBounds
                            model: {
                                const q = ipcSearch.text.trim().toLowerCase();
                                return editor.ipcCommands.filter(c => !q || (c.text + " " + c.subtext).toLowerCase().includes(q));
                            }
                            ScrollBar.vertical: StyledScrollBar {
                                thickness: 4
                                handleColor: Colors.outline_variant
                            }

                            delegate: ClickableRect {
                                id: ipcRow
                                required property var modelData
                                readonly property bool on: editor.preset === "ipc" && editor.param === modelData.text
                                width: ipcList.width - 8
                                height: 40
                                radius: Services.DesktopTheme.rad(10)
                                cursorShape: Qt.PointingHandCursor
                                color: on ? Colors.withAlpha(Services.DesktopTheme.accent, 0.16) : hovered ? Colors.surface_container_high : "transparent"
                                onClicked: {
                                    editor.choose("ipc");
                                    editor.param = modelData.text;
                                }

                                Column {
                                    x: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 20

                                    StyledText {
                                        width: parent.width
                                        text: ipcRow.modelData.subtext
                                        font.pixelSize: 12
                                        font.weight: ipcRow.on ? Font.DemiBold : Font.Medium
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: ipcRow.modelData.text
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        color: Colors.on_surface_variant
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }

                    // Window: what to do to the focused window
                    ColumnLayout {
                        anchors.fill: parent
                        visible: editor.tab === "window"
                        spacing: 10

                        Flow {
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: KeyData.presets.filter(p => p.tab === "window")

                                delegate: Chip {
                                    required property var modelData
                                    implicitHeight: 28
                                    pad: 11
                                    icon: modelData.icon
                                    label: modelData.label
                                    on: editor.preset === modelData.id
                                    onClicked: editor.choose(modelData.id)
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: editor.preset === "focusdir"
                            spacing: 6

                            StyledText {
                                text: "Towards"
                                font.pixelSize: 12
                                color: Colors.on_surface_variant
                            }

                            Repeater {
                                model: [["left", "arrow_back"], ["up", "arrow_upward"], ["down", "arrow_downward"], ["right", "arrow_forward"]]

                                delegate: Chip {
                                    required property var modelData
                                    pad: 9
                                    icon: modelData[1]
                                    on: editor.param === modelData[0]
                                    onClicked: editor.param = modelData[0]
                                }
                            }
                        }

                        Field {
                            Layout.fillWidth: true
                            visible: editor.preset === "layout"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            placeholderText: "Layout message, e.g. togglesplit or colresize +0.1"
                            text: editor.preset === "layout" ? editor.param : ""
                            onTextEdited: editor.param = text
                            Keys.onReturnPressed: editor.commit()
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }

                    // Workspace: go, send, scratchpad
                    ColumnLayout {
                        anchors.fill: parent
                        visible: editor.tab === "workspace"
                        spacing: 10

                        Row {
                            spacing: 6

                            Repeater {
                                model: KeyData.presets.filter(p => p.tab === "workspace")

                                delegate: Chip {
                                    required property var modelData
                                    icon: modelData.icon
                                    label: modelData.label
                                    on: editor.preset === modelData.id
                                    onClicked: editor.choose(modelData.id)
                                }
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            visible: editor.preset === "focusws" || editor.preset === "movews"
                            spacing: 6

                            Repeater {
                                model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "e-1", "e+1", "special:magic"]

                                delegate: Chip {
                                    required property string modelData
                                    pad: 10
                                    label: modelData === "e-1" ? "Previous" : modelData === "e+1" ? "Next" : modelData === "special:magic" ? "Scratchpad" : modelData
                                    on: editor.param === modelData
                                    onClicked: editor.param = modelData
                                }
                            }
                        }

                        Field {
                            Layout.fillWidth: true
                            placeholderText: editor.preset === "special" ? "Scratchpad name" : "Or any workspace: 11, name:web, previous, empty…"
                            text: editor.param
                            onTextEdited: editor.param = text
                            Keys.onReturnPressed: editor.commit()
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }

                    // Lua: any dispatcher
                    ColumnLayout {
                        anchors.fill: parent
                        visible: editor.tab === "lua"
                        spacing: 6

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            TextArea {
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                color: Colors.on_surface
                                placeholderText: "hl.dsp.window.swap({ direction = \"l\" })"
                                placeholderTextColor: Colors.on_surface_variant
                                wrapMode: TextArea.WrapAnywhere
                                selectByMouse: true
                                text: editor.preset === "lua" ? editor.param : ""
                                onTextChanged: if (activeFocus && editor.preset === "lua") editor.param = text
                                padding: 10
                                background: Rectangle {
                                    radius: Services.DesktopTheme.rad(10)
                                    color: Colors.surface_container
                                    border.width: 1
                                    border.color: parent.activeFocus ? Services.DesktopTheme.accent : Colors.withAlpha(Colors.outline_variant, 0.8)
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: "Any hl.dsp dispatcher, or a function. Hyprland builds it once before it's saved."
                            font.pixelSize: 11
                            color: Colors.on_surface_variant
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            // ── Label, options, where, preview ───────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                Caption {
                    text: "LABEL"
                }

                Field {
                    Layout.fillWidth: true
                    placeholderText: "Optional: what it does, in your words"
                    text: editor.description
                    onTextEdited: editor.description = text
                    Keys.onReturnPressed: editor.commit()
                }

                Caption {
                    Layout.topMargin: 4
                    text: "OPTIONS"
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: KeyData.flags

                        delegate: Chip {
                            id: flagChip
                            required property var modelData
                            implicitHeight: 26
                            pad: 10
                            icon: on ? "check" : ""
                            label: modelData.label
                            on: !!editor.flags[modelData.id]
                            onClicked: editor.setFlag(modelData.id, !on)
                            onEntered: editor.hint = modelData.hint
                            onExited: if (editor.hint === modelData.hint) editor.hint = ""
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: editor.hint
                    font.pixelSize: 11
                    color: Colors.on_surface_variant
                    visible: text !== ""
                    elide: Text.ElideRight
                }

                Caption {
                    Layout.topMargin: 4
                    visible: !editor.bind
                    text: "SAVE TO"
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: !editor.bind
                    spacing: 6

                    Repeater {
                        model: Services.Keybinds.files.map(f => f.name)

                        delegate: Chip {
                            required property string modelData
                            implicitHeight: 28
                            pad: 10
                            label: modelData
                            on: editor.file === modelData
                            onClicked: {
                                editor.whereTouched = true;
                                editor.file = modelData;
                                const f = Services.Keybinds.fileInfo(modelData);
                                if (f && !f.sections.some(s => s.title === editor.section))
                                    editor.section = f.sections[0]?.title ?? "";
                            }
                        }
                    }

                    ClickableRect {
                        id: sectionButton
                        Layout.fillWidth: true
                        implicitHeight: 28
                        radius: Services.DesktopTheme.rad(14)
                        cursorShape: Qt.PointingHandCursor
                        color: hovered || sectionMenu.visible ? Colors.surface_container_highest : Colors.surface_container_high
                        border.width: 1
                        border.color: Colors.withAlpha(Colors.outline_variant, 0.7)
                        onClicked: sectionMenu.visible = !sectionMenu.visible

                        StyledText {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 40
                            text: "under “" + editor.section + "”"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        Glyph {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: "unfold_more"
                            font.pixelSize: 16
                            color: Colors.on_surface_variant
                        }
                    }
                }

                Caption {
                    Layout.topMargin: 4
                    text: "WRITES"
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: previewText.implicitHeight + 16
                    radius: Services.DesktopTheme.rad(10)
                    color: Colors.surface_container

                    Text {
                        id: previewText
                        anchors.fill: parent
                        anchors.margins: 8
                        text: editor.preview
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: Colors.on_surface
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: editor.error !== ""
                    text: editor.error
                    font.pixelSize: 12
                    color: Colors.error
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    PanelButton {
                        visible: !!editor.bind
                        icon: editor.armedDelete ? "delete_forever" : "delete"
                        text: editor.armedDelete ? "Sure?" : "Delete"
                        danger: editor.armedDelete
                        onClicked: {
                            if (editor.armedDelete) {
                                editor.armedDelete = false;
                                editor.deleteRequested(editor.bind);
                            } else {
                                editor.armedDelete = true;
                                disarmDelete.restart();
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    PanelButton {
                        text: "Cancel"
                        onClicked: editor.cancelled()
                    }

                    PanelButton {
                        icon: Services.Keybinds.busy ? "" : "check"
                        text: Services.Keybinds.busy ? "Saving…" : editor.bind ? "Save" : "Add bind"
                        primary: true
                        enabled: !Services.Keybinds.busy
                        onClicked: editor.commit()
                    }
                }
            }
        }
    }

    property string hint: ""
    property bool armedDelete: false

    Timer {
        id: disarmDelete
        interval: 3200
        onTriggered: editor.armedDelete = false
    }

    // ── Popups ───────────────────────────────────────────────────────────────

    // the section a new bind goes under
    Card {
        id: sectionMenu
        visible: false
        z: 20
        width: Math.max(260, sectionButton.width)
        height: Math.min(sectionColumn.implicitHeight + 12, editor.height - 40)
        x: Math.min(editor.width - width - 12, sectionButton.mapToItem(editor, 0, 0).x)
        y: Math.max(12, sectionButton.mapToItem(editor, 0, 0).y - height - 6)
        radius: Services.DesktopTheme.rad(14)
        color: Colors.surface_container_high
        clip: true

        Flickable {
            anchors.fill: parent
            anchors.margins: 6
            contentHeight: sectionColumn.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: sectionColumn
                width: parent.width

                Repeater {
                    model: Services.Keybinds.fileInfo(editor.file)?.sections ?? []

                    delegate: ClickableRect {
                        required property var modelData
                        width: sectionColumn.width
                        height: 30
                        radius: Services.DesktopTheme.rad(8)
                        cursorShape: Qt.PointingHandCursor
                        color: editor.section === modelData.title ? Colors.withAlpha(Services.DesktopTheme.accent, 0.16) : hovered ? Colors.surface_container_highest : "transparent"
                        onClicked: {
                            editor.whereTouched = true;
                            editor.section = modelData.title;
                            sectionMenu.visible = false;
                        }

                        StyledText {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 50
                            text: parent.modelData.title
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        StyledText {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData.count
                            font.pixelSize: 11
                            color: Colors.on_surface_variant
                        }
                    }
                }
            }
        }
    }

    // an installed app's command
    Card {
        id: appPicker
        visible: false
        z: 20
        x: 18
        y: 60
        width: editor.width * 0.55
        height: editor.height - 78
        radius: Services.DesktopTheme.rad(16)
        color: Colors.surface_container_high

        onVisibleChanged: if (visible) {
            appSearch.text = "";
            appSearch.forceActiveFocus();
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            RowLayout {
                Layout.fillWidth: true

                Field {
                    id: appSearch
                    Layout.fillWidth: true
                    placeholderText: "Find an app"
                    Keys.onEscapePressed: appPicker.visible = false
                    Keys.onReturnPressed: if (appList.count > 0) editor.pickApp(appList.model[0])
                }

                GlyphButton {
                    icon: "close"
                    onClicked: appPicker.visible = false
                }
            }

            ListView {
                id: appList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: {
                    const q = appSearch.text.trim().toLowerCase();
                    return Services.AppRegistry.apps.filter(a => a.exec && (!q || a.name.toLowerCase().includes(q) || a.exec.toLowerCase().includes(q))).slice(0, 80);
                }
                ScrollBar.vertical: StyledScrollBar {
                    thickness: 4
                    handleColor: Colors.outline_variant
                }

                delegate: ClickableRect {
                    id: appRow
                    required property var modelData
                    width: appList.width - 8
                    height: 38
                    radius: Services.DesktopTheme.rad(10)
                    cursorShape: Qt.PointingHandCursor
                    color: hovered ? Colors.surface_container_highest : "transparent"
                    onClicked: editor.pickApp(appRow.modelData)

                    Image {
                        id: appImage
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22
                        height: 22
                        source: Services.AppRegistry.iconForDesktopIcon(appRow.modelData.icon)
                        sourceSize: Qt.size(44, 44)
                        asynchronous: true
                    }

                    Column {
                        anchors.left: appImage.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            width: parent.width
                            text: appRow.modelData.name
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: appRow.modelData.exec
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            color: Colors.on_surface_variant
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    function pickApp(app) {
        choose("exec");
        param = String(app.exec).trim();
        appPicker.visible = false;
    }

    // The shell's IPC commands, as scripts/gen-ipc-commands.py lists them.
    property var ipcCommands: []

    FileView {
        path: Quickshell.shellPath("ipc-commands.json")
        printErrors: false
        onLoaded: {
            try {
                editor.ipcCommands = JSON.parse(text());
            } catch (e) {
                editor.ipcCommands = [];
            }
        }
    }
}
