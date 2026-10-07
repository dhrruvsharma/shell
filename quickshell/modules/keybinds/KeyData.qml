pragma Singleton
import QtQuick
import Quickshell
import qs.colors
import qs.services as Services

// What the keybinds panel knows about keys: the keyboard it draws, the
// names Hyprland gives keys (and how to show them), how to read a pressed
// key back as one of those names, and the actions the editor offers.
Singleton {
    id: root

    // ── The keyboard ─────────────────────────────────────────────────────────

    // A tenkeyless ANSI board in key units (x, y, w; h 1): `name` is
    // Hyprland's key name, `mod` marks a modifier key, `legend` what's
    // printed on it. Media keys and the mouse get a slimmer row underneath.
    readonly property real boardWidth: 18.25
    readonly property real extrasY: 6.6
    readonly property real extrasHeight: 0.82
    readonly property real boardHeight: extrasY + extrasHeight

    readonly property var keys: {
        const k = [];
        const row = (y, x0, names, w) => {
            let x = x0;
            for (const n of names) {
                const spec = typeof n === "string" ? { name: n } : n;
                k.push({ name: spec.name, legend: spec.legend ?? root.legendOf(spec.name), x: spec.x ?? x, y: y, w: spec.w ?? w ?? 1, mod: spec.mod ?? "" });
                x = (spec.x ?? x) + (spec.w ?? w ?? 1);
            }
        };
        row(0, 0, ["Escape"]);
        row(0, 2, ["F1", "F2", "F3", "F4"]);
        row(0, 6.5, ["F5", "F6", "F7", "F8"]);
        row(0, 11, ["F9", "F10", "F11", "F12"]);
        row(0, 15.25, ["Print", "Scroll_Lock", "Pause"]);
        row(1.25, 0, ["grave", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "minus", "equal", { name: "BackSpace", w: 2 }]);
        row(1.25, 15.25, ["Insert", "Home", "Prior"]);
        row(2.25, 0, [{ name: "Tab", w: 1.5 }, "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "bracketleft", "bracketright", { name: "backslash", w: 1.5 }]);
        row(2.25, 15.25, ["Delete", "End", "Next"]);
        row(3.25, 0, [{ name: "Caps_Lock", w: 1.75 }, "A", "S", "D", "F", "G", "H", "J", "K", "L", "semicolon", "apostrophe", { name: "Return", w: 2.25 }]);
        row(4.25, 0, [{ name: "Shift_L", w: 2.25, mod: "SHIFT" }, "Z", "X", "C", "V", "B", "N", "M", "comma", "period", "slash", { name: "Shift_R", w: 2.75, mod: "SHIFT" }]);
        row(4.25, 16.25, ["up"]);
        row(5.25, 0, [{ name: "Control_L", w: 1.25, mod: "CTRL" }, { name: "Super_L", w: 1.25, mod: "SUPER" }, { name: "Alt_L", w: 1.25, mod: "ALT" },
            { name: "space", w: 6.25 }, { name: "Alt_R", w: 1.25, mod: "ALT" }, { name: "Super_R", w: 1.25, mod: "SUPER" },
            { name: "Menu", w: 1.25 }, { name: "Control_R", w: 1.25, mod: "CTRL" }]);
        row(5.25, 15.25, ["left", "down", "right"]);
        return k;
    }

    // Media keys, then the mouse, as glyphs.
    readonly property var extras: {
        const media = [
            ["XF86AudioMute", "volume_off"], ["XF86AudioLowerVolume", "volume_down"], ["XF86AudioRaiseVolume", "volume_up"],
            ["XF86AudioMicMute", "mic_off"], ["XF86MonBrightnessDown", "brightness_low"], ["XF86MonBrightnessUp", "brightness_high"],
            ["XF86AudioPrev", "skip_previous"], ["XF86AudioPlay", "play_arrow"], ["XF86AudioPause", "pause"], ["XF86AudioNext", "skip_next"]
        ];
        const mouse = [["mouse:272", "L"], ["mouse:274", "M"], ["mouse:273", "R"], ["mouse_up", "keyboard_arrow_up"], ["mouse_down", "keyboard_arrow_down"]];
        const w = 1.1;
        const out = [];
        media.forEach((m, i) => out.push({ name: m[0], icon: m[1], x: i * w, w: w, group: "media" }));
        const x0 = root.boardWidth - mouse.length * w;
        mouse.forEach((m, i) => out.push({ name: m[0], icon: m[1].length > 1 ? m[1] : "", legend: m[1].length === 1 ? m[1] : "", x: x0 + i * w, w: w, group: "mouse" }));
        return out;
    }

    // ── Names ────────────────────────────────────────────────────────────────

    readonly property var modOrder: ["SUPER", "CTRL", "ALT", "SHIFT", "CAPS", "MOD2", "MOD3", "MOD5"]
    readonly property var modNames: ({ SUPER: "Super", CTRL: "Ctrl", ALT: "Alt", SHIFT: "Shift", CAPS: "Caps", MOD2: "Mod2", MOD3: "Mod3", MOD5: "Mod5" })

    readonly property var labels: ({
        escape: "Esc", grave: "`", minus: "-", equal: "=", backspace: "Backspace", tab: "Tab",
        bracketleft: "[", bracketright: "]", backslash: "\\", caps_lock: "Caps", semicolon: ";",
        apostrophe: "'", return: "Enter", comma: ",", period: ".", slash: "/", space: "Space",
        menu: "Menu", print: "PrtSc", scroll_lock: "ScrLk", pause: "Pause", insert: "Ins", home: "Home",
        prior: "PgUp", page_up: "PgUp", delete: "Del", end: "End", next: "PgDn", page_down: "PgDn",
        left: "←", right: "→", up: "↑", down: "↓", shift_l: "Shift", shift_r: "Shift", control_l: "Ctrl",
        control_r: "Ctrl", super_l: "Super", super_r: "Super", alt_l: "Alt", alt_r: "Alt",
        "mouse:272": "Left click", "mouse:273": "Right click", "mouse:274": "Middle click",
        "mouse:275": "Back button", "mouse:276": "Forward button", mouse_up: "Scroll up",
        mouse_down: "Scroll down", mouse_left: "Scroll left", mouse_right: "Scroll right",
        xf86audioraisevolume: "Volume up", xf86audiolowervolume: "Volume down", xf86audiomute: "Mute",
        xf86audiomicmute: "Mic mute", xf86monbrightnessup: "Brightness up", xf86monbrightnessdown: "Brightness down",
        xf86audioplay: "Play", xf86audiopause: "Pause", xf86audionext: "Next track", xf86audioprev: "Previous track",
        xf86audiostop: "Stop", xf86calculator: "Calculator", xf86mail: "Mail", xf86poweroff: "Power", kp_enter: "Num Enter"
    })

    // Names that mean the same key; the keyboard is drawn with the first.
    readonly property var aliases: ({ page_up: "prior", page_down: "next", enter: "return", esc: "escape" })

    function norm(name) {
        const n = String(name).toLowerCase();
        return root.aliases[n] ?? n;
    }

    function legendOf(name) {
        return root.labels[String(name).toLowerCase()] ?? (String(name).length === 1 ? String(name).toUpperCase() : name);
    }

    // How a key reads in a combo: "Q", "/", "Enter", "Scroll up", "Key 94".
    function keyLabel(name) {
        const n = String(name);
        const low = n.toLowerCase();
        if (root.labels[low] !== undefined)
            return root.labels[low];
        if (n.length === 1)
            return n.toUpperCase();
        if (/^kp_/i.test(n))
            return "Num " + n.slice(3);
        if (/^code:/i.test(n))
            return "Key " + n.slice(5);
        if (/^mouse:/i.test(n))
            return "Mouse " + n.slice(6);
        if (/^xf86/i.test(n))
            return n.slice(4).replace(/([a-z])([A-Z])/g, "$1 $2");
        return n;
    }

    function modLabel(mod) {
        return root.modNames[mod] ?? mod;
    }

    function sortMods(mods) {
        const seen = [];
        for (const m of mods)
            if (!seen.includes(m))
                seen.push(m);
        return seen.sort((a, b) => (root.modOrder.indexOf(a) + 100) % 100 - (root.modOrder.indexOf(b) + 100) % 100);
    }

    function layerKey(mods) {
        return root.sortMods(mods).join("+");
    }

    function layerName(mods) {
        return mods.length ? root.sortMods(mods).map(m => root.modLabel(m)).join(" + ") : "No modifier";
    }

    function comboText(mods, key) {
        return root.sortMods(mods).concat(key ? [key] : []).join(" + ");
    }

    // What colour an action's keys take: launchers the accent, the shell's
    // own panels the second accent, window and workspace moves the quieter
    // secondary, and media and system keys stay neutral.
    function toneOf(category) {
        switch (category) {
        case "app": return Services.DesktopTheme.accent;
        case "shell": return Services.DesktopTheme.accent2;
        case "window":
        case "workspace": return Colors.secondary;
        }
        return Colors.on_surface_variant;
    }

    readonly property var categories: [
        { id: "app", label: "Apps" },
        { id: "shell", label: "Shell" },
        { id: "window", label: "Windows" },
        { id: "workspace", label: "Workspaces" },
        { id: "media", label: "Media" },
        { id: "system", label: "System" },
        { id: "custom", label: "Other" }
    ]

    // ── Reading a pressed key ────────────────────────────────────────────────

    // xkb keycodes (evdev + 8) on a US board → Hyprland's names. Positions
    // are kept for anything shifted (Shift+1 still binds "1"); letters come
    // from the keysym, so other layouts name them right.
    readonly property var scanNames: ({
        9: "Escape", 10: "1", 11: "2", 12: "3", 13: "4", 14: "5", 15: "6", 16: "7", 17: "8", 18: "9", 19: "0",
        20: "minus", 21: "equal", 22: "BackSpace", 23: "Tab", 34: "bracketleft", 35: "bracketright", 36: "Return",
        47: "semicolon", 48: "apostrophe", 49: "grave", 51: "backslash", 59: "comma", 60: "period", 61: "slash",
        63: "KP_Multiply", 65: "space", 67: "F1", 68: "F2", 69: "F3", 70: "F4", 71: "F5", 72: "F6", 73: "F7",
        74: "F8", 75: "F9", 76: "F10", 78: "Scroll_Lock", 79: "KP_7", 80: "KP_8", 81: "KP_9", 82: "KP_Subtract",
        83: "KP_4", 84: "KP_5", 85: "KP_6", 86: "KP_Add", 87: "KP_1", 88: "KP_2", 89: "KP_3", 90: "KP_0",
        91: "KP_Decimal", 94: "less", 95: "F11", 96: "F12", 104: "KP_Enter", 106: "KP_Divide", 107: "Print",
        110: "Home", 111: "up", 112: "Prior", 113: "left", 114: "right", 115: "End", 116: "down", 117: "Next",
        118: "Insert", 119: "Delete", 121: "XF86AudioMute", 122: "XF86AudioLowerVolume", 123: "XF86AudioRaiseVolume",
        127: "Pause", 135: "Menu", 148: "XF86Calculator", 163: "XF86Mail", 171: "XF86AudioNext",
        172: "XF86AudioPlay", 173: "XF86AudioPrev", 174: "XF86AudioStop", 209: "XF86AudioPause",
        232: "XF86MonBrightnessDown", 233: "XF86MonBrightnessUp", 256: "XF86AudioMicMute"
    })

    readonly property var qtNames: ({
        [Qt.Key_Escape]: "Escape", [Qt.Key_Tab]: "Tab", [Qt.Key_Backtab]: "Tab", [Qt.Key_Backspace]: "BackSpace",
        [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "KP_Enter", [Qt.Key_Insert]: "Insert", [Qt.Key_Delete]: "Delete",
        [Qt.Key_Pause]: "Pause", [Qt.Key_Print]: "Print", [Qt.Key_Home]: "Home", [Qt.Key_End]: "End",
        [Qt.Key_Left]: "left", [Qt.Key_Up]: "up", [Qt.Key_Right]: "right", [Qt.Key_Down]: "down",
        [Qt.Key_PageUp]: "Prior", [Qt.Key_PageDown]: "Next", [Qt.Key_Space]: "space", [Qt.Key_Menu]: "Menu",
        [Qt.Key_VolumeDown]: "XF86AudioLowerVolume", [Qt.Key_VolumeMute]: "XF86AudioMute",
        [Qt.Key_VolumeUp]: "XF86AudioRaiseVolume", [Qt.Key_MediaPlay]: "XF86AudioPlay",
        [Qt.Key_MediaStop]: "XF86AudioStop", [Qt.Key_MediaPrevious]: "XF86AudioPrev",
        [Qt.Key_MediaNext]: "XF86AudioNext", [Qt.Key_MediaPause]: "XF86AudioPause",
        [Qt.Key_MediaTogglePlayPause]: "XF86AudioPlay", [Qt.Key_MonBrightnessUp]: "XF86MonBrightnessUp",
        [Qt.Key_MonBrightnessDown]: "XF86MonBrightnessDown", [Qt.Key_MicMute]: "XF86AudioMicMute",
        [Qt.Key_Calculator]: "XF86Calculator"
    })

    readonly property var modifierKeys: [Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L,
        Qt.Key_Super_R, Qt.Key_AltGr, Qt.Key_CapsLock, Qt.Key_Hyper_L, Qt.Key_Hyper_R, Qt.Key_NumLock]
    readonly property var modifierScans: ({ 37: "CTRL", 105: "CTRL", 50: "SHIFT", 62: "SHIFT", 64: "ALT", 108: "ALT", 133: "SUPER", 134: "SUPER" })

    function isModifier(event) {
        return root.modifierKeys.includes(event.key) || root.modifierScans[event.nativeScanCode] !== undefined;
    }

    // The modifier a modifier key is ("" for Caps Lock and the like).
    function modOfKey(event) {
        if (root.modifierScans[event.nativeScanCode])
            return root.modifierScans[event.nativeScanCode];
        switch (event.key) {
        case Qt.Key_Shift: return "SHIFT";
        case Qt.Key_Control: return "CTRL";
        case Qt.Key_Alt: return "ALT";
        case Qt.Key_Meta:
        case Qt.Key_Super_L:
        case Qt.Key_Super_R: return "SUPER";
        }
        return "";
    }

    function modsOf(modifiers) {
        const m = [];
        if (modifiers & Qt.MetaModifier)
            m.push("SUPER");
        if (modifiers & Qt.ControlModifier)
            m.push("CTRL");
        if (modifiers & Qt.AltModifier)
            m.push("ALT");
        if (modifiers & Qt.ShiftModifier)
            m.push("SHIFT");
        return m;
    }

    function nameOf(event) {
        if (event.key >= Qt.Key_A && event.key <= Qt.Key_Z)
            return String.fromCharCode(event.key);
        if (event.key >= Qt.Key_F1 && event.key <= Qt.Key_F24)
            return "F" + (event.key - Qt.Key_F1 + 1);
        return root.scanNames[event.nativeScanCode] ?? root.qtNames[event.key] ?? (event.nativeScanCode > 8 ? "code:" + event.nativeScanCode : "");
    }

    // ── Lua ──────────────────────────────────────────────────────────────────

    // A Lua literal, long-bracketed like the config's grimblast commands
    // when it has quotes or backslashes in it.
    function luaString(s) {
        s = String(s);
        if (!/["\\\n\r]/.test(s))
            return "\"" + s + "\"";
        let eq = "";
        while ((s + "]" + eq + "]").indexOf("]" + eq + "]") !== s.length)
            eq += "=";
        return "[" + eq + "[" + s + "]" + eq + "]";
    }

    function workspaceLiteral(ws) {
        return /^\d+$/.test(String(ws)) ? String(ws) : root.luaString(ws);
    }

    // ── Actions ──────────────────────────────────────────────────────────────

    // The editor's tabs and what they hold. `param`: what the preset needs
    // ("" none, "text", "command", "ipc", "workspace", "direction", "mode",
    // "code").
    readonly property var tabs: [
        { id: "run", label: "Run", icon: "terminal" },
        { id: "shell", label: "Shell", icon: "widgets" },
        { id: "window", label: "Window", icon: "web_asset" },
        { id: "workspace", label: "Workspace", icon: "space_dashboard" },
        { id: "lua", label: "Lua", icon: "data_object" }
    ]

    readonly property var presets: [
        { id: "exec", tab: "run", label: "Run a command", param: "command", icon: "terminal" },
        { id: "ipc", tab: "shell", label: "Quickshell", param: "ipc", icon: "widgets" },
        { id: "close", tab: "window", label: "Close", icon: "close" },
        { id: "kill", tab: "window", label: "Kill", icon: "dangerous" },
        { id: "float", tab: "window", label: "Floating", icon: "picture_in_picture_alt" },
        { id: "fullscreen", tab: "window", label: "Fullscreen", icon: "fullscreen", param: "mode", fixed: "fullscreen" },
        { id: "maximize", tab: "window", label: "Maximize", icon: "open_in_full", param: "mode", fixed: "maximized", as: "fullscreen" },
        { id: "pin", tab: "window", label: "Pin", icon: "push_pin" },
        { id: "center", tab: "window", label: "Center", icon: "filter_center_focus" },
        { id: "pseudo", tab: "window", label: "Pseudotile", icon: "dashboard" },
        { id: "group", tab: "window", label: "Group", icon: "tab" },
        { id: "drag", tab: "window", label: "Drag (mouse)", icon: "open_with" },
        { id: "resize", tab: "window", label: "Resize (mouse)", icon: "aspect_ratio" },
        { id: "focusdir", tab: "window", label: "Focus", icon: "arrow_forward", param: "direction" },
        { id: "layout", tab: "window", label: "Layout message", icon: "view_column", param: "text" },
        { id: "exit", tab: "window", label: "Exit Hyprland", icon: "logout" },
        { id: "focusws", tab: "workspace", label: "Go to workspace", icon: "space_dashboard", param: "workspace" },
        { id: "movews", tab: "workspace", label: "Move window to", icon: "move_down", param: "workspace" },
        { id: "special", tab: "workspace", label: "Scratchpad", icon: "layers", param: "text" },
        { id: "lua", tab: "lua", label: "Lua", icon: "data_object", param: "code" }
    ]

    function preset(id) {
        return root.presets.find(p => p.id === id) ?? null;
    }

    // The editor's preset for a bind's (preset, param) as keybinds.py read it.
    function presetFor(id, param) {
        if (id === "fullscreen" && param === "maximized")
            return "maximize";
        return root.preset(id) ? id : "lua";
    }

    // The hl.dsp expression for a preset and its parameter; "" while the
    // parameter it needs is missing.
    function dispatcher(id, param) {
        const p = String(param ?? "").trim();
        switch (id) {
        case "exec":
        case "ipc": return p ? "hl.dsp.exec_cmd(" + root.luaString(p) + ")" : "";
        case "close": return "hl.dsp.window.close()";
        case "kill": return "hl.dsp.window.kill()";
        case "float": return "hl.dsp.window.float({ action = \"toggle\" })";
        case "fullscreen": return "hl.dsp.window.fullscreen({ mode = \"fullscreen\" })";
        case "maximize": return "hl.dsp.window.fullscreen({ mode = \"maximized\" })";
        case "pin": return "hl.dsp.window.pin()";
        case "center": return "hl.dsp.window.center()";
        case "pseudo": return "hl.dsp.window.pseudo()";
        case "group": return "hl.dsp.group.toggle()";
        case "drag": return "hl.dsp.window.drag()";
        case "resize": return "hl.dsp.window.resize()";
        case "exit": return "hl.dsp.exit()";
        case "focusdir": return p ? "hl.dsp.focus({ direction = \"" + p + "\" })" : "";
        case "layout": return p ? "hl.dsp.layout(" + root.luaString(p) + ")" : "";
        case "focusws": return p ? "hl.dsp.focus({ workspace = " + root.workspaceLiteral(p) + " })" : "";
        case "movews": return p ? "hl.dsp.window.move({ workspace = " + root.workspaceLiteral(p) + " })" : "";
        case "special": return "hl.dsp.workspace.toggle_special(" + root.luaString(p || "magic") + ")";
        case "lua": return p;
        }
        return "";
    }

    // Ready-made commands under the editor's command field.
    readonly property var commands: [
        { label: "Volume up", icon: "volume_up", cmd: "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+" },
        { label: "Volume down", icon: "volume_down", cmd: "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-" },
        { label: "Mute", icon: "volume_off", cmd: "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" },
        { label: "Mic mute", icon: "mic_off", cmd: "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle" },
        { label: "Brighter", icon: "brightness_high", cmd: "brightnessctl set +5%" },
        { label: "Dimmer", icon: "brightness_low", cmd: "brightnessctl set 5%-" },
        { label: "Play / pause", icon: "play_pause", cmd: "playerctl play-pause" },
        { label: "Next track", icon: "skip_next", cmd: "playerctl next" },
        { label: "Previous", icon: "skip_previous", cmd: "playerctl previous" },
        { label: "Screenshot area", icon: "screenshot_region", cmd: "grimblast copy area" },
        { label: "Lock", icon: "lock", cmd: "quickshell -p ~/.config/quickshell/Lock.qml" }
    ]

    // The options the editor offers, by Hyprland's name.
    readonly property var flags: [
        { id: "locked", label: "On lock screen", hint: "Works while the screen is locked" },
        { id: "repeating", label: "Repeat", hint: "Fires again and again while held" },
        { id: "release", label: "On release", hint: "Fires when the key is let go" },
        { id: "long_press", label: "Long press", hint: "Fires only after holding the key" },
        { id: "non_consuming", label: "Pass through", hint: "The focused app gets the key too" },
        { id: "ignore_mods", label: "Any modifiers", hint: "Fires whatever modifiers are held" },
        { id: "transparent", label: "Transparent", hint: "Doesn't stop other binds on the same key" },
        { id: "dont_inhibit", label: "Can't be inhibited", hint: "Works even when an app inhibits shortcuts" }
    ]
}
