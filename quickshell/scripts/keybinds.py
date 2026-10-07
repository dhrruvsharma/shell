#!/usr/bin/env python3
"""Read and edit the Hyprland binds in ~/.config/hypr/*.lua, for the keybinds
manager (services/Keybinds.qml, modules/keybinds).

  keybinds.py list                every bind as JSON (see list_binds)
  keybinds.py apply '<json>'      add, edit and delete binds (see apply)
  keybinds.py restore '<json>'    put backups back: undo, or the rollback
                                  when Hyprland rejects a change

Reading runs the config through scripts/keybinds-probe.lua, a stand-in `hl`
that records each hl.bind() with the file and line it came from, so loops,
helpers and variables (`mainMod .. " + Q"`, `exec_cmd(terminal)`) come out
evaluated. The source is then scanned for the hl.bind( calls themselves, so
an edit rewrites just the arguments that changed and keeps the rest of the
line as written (variables, alignment, trailing comments).

Every change is tried before it is written: the new files go through
`luac -p` and the probe in a scratch copy, and a new dispatcher expression
is built once by the running Hyprland (`hyprctl repl` constructs it without
running it; bad arguments make it nil). The old file is copied to
~/.cache/quickshell/keybinds first, then overwritten in place.

Everything prints one JSON object; failures are {"ok": false, "error": …}.
"""
import bisect
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

SHELL_DIR = Path(__file__).resolve().parent.parent
PROBE = SHELL_DIR / "scripts" / "keybinds-probe.lua"
HOME = Path.home()
HYPR_DIR = Path(os.environ.get("QS_KEYBINDS_HYPR_DIR")
                or Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config")) / "hypr")
BACKUP_DIR = Path(os.environ.get("QS_KEYBINDS_BACKUP_DIR")
                  or Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "quickshell" / "keybinds")
# Set by tests: never ask the running Hyprland anything.
NO_HYPRCTL = bool(os.environ.get("QS_KEYBINDS_NO_HYPRCTL"))
KEEP_BACKUPS = 30

MOD_BITS = {"SHIFT": 1, "CAPS": 2, "CTRL": 4, "ALT": 8, "MOD2": 16, "MOD3": 32, "SUPER": 64, "MOD5": 128}
MOD_ALIASES = {"CONTROL": "CTRL", "CTL": "CTRL", "MOD1": "ALT", "WIN": "SUPER", "LOGO": "SUPER",
               "META": "SUPER", "MOD4": "SUPER", "LOCK": "CAPS"}
MOD_ORDER = ["SUPER", "CTRL", "ALT", "SHIFT", "CAPS", "MOD2", "MOD3", "MOD5"]

# The bind options the editor manages. Any other key in an options table is
# kept as written.
FLAGS = ["locked", "repeating", "release", "long_press", "non_consuming", "transparent",
         "ignore_mods", "dont_inhibit", "click", "drag", "submap_universal", "allow_input_capture"]

KEY_NAME = re.compile(r"^[\w:.\-]+$")
IDENT = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")


def out(obj):
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")


def sha1(text):
    return hashlib.sha1(text.encode("utf-8")).hexdigest()


# ── Lua source scanning ─────────────────────────────────────────────────────

def long_bracket(src, i):
    """The level of a long bracket ([[, [==[) opening at i, else None."""
    if i >= len(src) or src[i] != "[":
        return None
    j = i + 1
    while j < len(src) and src[j] == "=":
        j += 1
    return j - i - 1 if j < len(src) and src[j] == "[" else None


def code_mask(src):
    """1 for each character that is code, 0 inside strings and comments."""
    n = len(src)
    mask = bytearray(n)
    i = 0
    while i < n:
        c = src[i]
        if c == "-" and src.startswith("--", i):
            lvl = long_bracket(src, i + 2)
            if lvl is not None:
                end = src.find("]" + "=" * lvl + "]", i + 2)
                i = n if end < 0 else end + lvl + 2
            else:
                end = src.find("\n", i)
                i = n if end < 0 else end
            continue
        if c in "\"'":
            j = i + 1
            while j < n and src[j] != c and src[j] != "\n":
                j += 2 if src[j] == "\\" else 1
            i = j + 1
            continue
        if c == "[":
            lvl = long_bracket(src, i)
            if lvl is not None:
                end = src.find("]" + "=" * lvl + "]", i)
                i = n if end < 0 else end + lvl + 2
                continue
        mask[i] = 1
        i += 1
    return mask


def split_args(src, mask, open_i, close_i):
    """(start, end) of each top-level, comma-separated piece between the
    brackets at open_i and close_i."""
    spans, depth, start = [], 0, open_i + 1
    for i in range(open_i, close_i + 1):
        if not mask[i]:
            continue
        ch = src[i]
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
            if depth == 0:
                spans.append((start, i))
        elif ch == "," and depth == 1:
            spans.append((start, i))
            start = i + 1
    return spans


def strip_span(src, a, b):
    while a < b and src[a].isspace():
        a += 1
    while b > a and src[b - 1].isspace():
        b -= 1
    return a, b


CALL_RE = re.compile(r"hl\s*\.\s*bind\s*\(")


class Source:
    """A config file: its text, which of it is code, and its hl.bind calls."""

    def __init__(self, name, text):
        self.name = name
        self.text = text
        self.mask = code_mask(text)
        self.newlines = [i for i, c in enumerate(text) if c == "\n"]
        self.calls = self._calls()

    def line_of(self, pos):
        return bisect.bisect_left(self.newlines, pos) + 1

    def line_start(self, pos):
        return self.text.rfind("\n", 0, pos) + 1

    def line_end(self, pos):
        """Just past the newline ending pos's line."""
        end = self.text.find("\n", pos)
        return len(self.text) if end < 0 else end + 1

    def _calls(self):
        calls = []
        src, mask = self.text, self.mask
        for m in CALL_RE.finditer(src):
            s = m.start()
            if s > 0 and (src[s - 1] in IDENT or src[s - 1] in ".:"):
                continue
            if not all(mask[k] for k in range(s, m.end())):
                continue
            open_i, depth, close_i = m.end() - 1, 0, None
            for i in range(open_i, len(src)):
                if not mask[i]:
                    continue
                if src[i] in "([{":
                    depth += 1
                elif src[i] in ")]}":
                    depth -= 1
                    if depth == 0:
                        close_i = i
                        break
            if close_i is None:
                continue
            args = [strip_span(src, a, b) for a, b in split_args(src, mask, open_i, close_i)]
            if args and args[-1][0] == args[-1][1]:
                args.pop()  # hl.bind() or a trailing comma
            calls.append({
                "start": s, "close": close_i, "args": args,
                "line": self.line_of(s), "endLine": self.line_of(close_i),
                "raw": src[s:close_i + 1],
            })
        return calls

    def arg_text(self, call, i):
        if i >= len(call["args"]):
            return None
        a, b = call["args"][i]
        return self.text[a:b]

    def string_locals(self):
        """Top-level `local name = "literal"` assignments."""
        found = {}
        for m in re.finditer(r'^local\s+([A-Za-z_]\w*)\s*=\s*"([^"\\\n]*)"', self.text, re.M):
            if self.mask[m.start()]:
                found.setdefault(m.group(1), m.group(2))
        return found

    def main_mod_var(self):
        return next((k for k, v in self.string_locals().items() if v.upper() == "SUPER"), None)


# ── Sections ────────────────────────────────────────────────────────────────

BANNER = re.compile(r"^\s*(-{4,}|-{2,}\s*[A-Z0-9][A-Z0-9 &/+.'-]*?\s*-{2,})\s*$")
NOTE = re.compile(r"^\s*--+\s*(NOTE|TODO|FIXME|XXX|HACK)\b", re.I)


def is_banner(block):
    return all(BANNER.match(line) for line in block)


def comment_title(lines, local_strings):
    """A section title from the first line of the comment block heading it."""
    text = re.sub(r"^\s*-+\s*", "", lines[0]).strip()
    text = re.split(r"(?<=[a-z)\]])\.\s", text)[0].rstrip(".:").strip()
    if len(text) > 32 and " (" in text:
        text = text[:text.index(" (")]
    for name, value in local_strings.items():
        if value.upper() in MOD_BITS:  # mainMod → SUPER
            text = re.sub(rf"\b{re.escape(name)}\b", value, text)
    return text


def file_default_title(name):
    stem = Path(name).stem
    return "General" if stem == "hyprland" else stem[:1].upper() + stem[1:]


def assign_sections(source):
    """The section each call is in: titled by the comment block right above
    its group (or above the loop making it); a banner like
    `---- KEYBINDINGS ----` starts afresh."""
    lines = source.text.split("\n")
    starts = {}
    for idx, call in enumerate(source.calls):
        starts.setdefault(call["line"], []).append(idx)
    local_strings = source.string_locals()
    default = file_default_title(source.name)
    titles = [default] * len(source.calls)
    current = None
    i = 0
    while i < len(lines):
        if lines[i].strip().startswith("--"):
            j = i
            while j < len(lines) and lines[j].strip().startswith("--"):
                j += 1
            block = lines[i:j]
            # the code under it, up to the next blank line
            k = j
            while k < len(lines) and lines[k].strip() and not lines[k].strip().startswith("--"):
                k += 1
            if is_banner(block):
                current = None
            elif not NOTE.match(block[0]) and any(n + 1 in starts for n in range(j, k)):
                current = comment_title(block, local_strings)
            i = j
            continue
        for idx in starts.get(i + 1, []):
            titles[idx] = current or default
        i += 1
    return titles


# ── Keys ────────────────────────────────────────────────────────────────────

def mod_sort(mods):
    return sorted(dict.fromkeys(mods), key=lambda m: MOD_ORDER.index(m) if m in MOD_ORDER else 99)


def parse_keys(keys):
    tokens = [t for t in re.split(r"[\s+]+", keys.strip()) if t]
    if not tokens:
        return [], "", 0
    mods = mod_sort(MOD_ALIASES.get(t.upper(), t.upper()) for t in tokens[:-1])
    return mods, tokens[-1], sum(MOD_BITS.get(m, 0) for m in mods)


def combo_text(mods, key):
    return " + ".join(list(mods) + [key])


# ── What a bind does ────────────────────────────────────────────────────────

SHELL_NAMES = {
    "launcherWindow": ("Launcher", "apps"),
    "avatarPicker": ("Avatar picker", "face"),
    "powerMenu": ("Power menu", "power_settings_new"),
    "notepad": ("Notepad", "edit_note"),
    "wallpaper": ("Wallpaper picker", "wallpaper"),
    "cavaWidget": ("Cava widget", "graphic_eq"),
    "pet": ("Pet", "pets"),
    "expose": ("Overview", "view_quilt"),
    "networkPanel": ("Network panel", "wifi"),
    "controlCenter": ("Control center", "tune"),
    "lockscreen": ("Lock screen themes", "lock"),
    "themes": ("Themes", "palette"),
    "widgets": ("Desktop widgets", "widgets"),
    "keybinds": ("Keybinds", "keyboard"),
    "clipboardManager": ("Clipboard", "content_paste"),
    "mediaPanel": ("Media panel", "music_note"),
    "ollamaChat": ("Ollama chat", "chat"),
    "aikiraChat": ("Aikira chat", "forum"),
    "mangaReader": ("Manga reader", "menu_book"),
    "novelReader": ("Novel reader", "auto_stories"),
    "animePlayer": ("Anime player", "movie"),
    "updatesPanel": ("Updates", "system_update"),
    "visBottom": ("Visualizer", "equalizer"),
    "desktopTheme": ("Desktop theme", "palette"),
    "barLayout": ("Bar layout", "view_agenda"),
    "calendarWindow": ("Calendar", "calendar_month"),
}

WRAPPERS = {"prime-run", "env", "nohup", "setsid", "exec", "uwsm-app", "systemd-run", "gamemoderun", "mangohud"}
IPC_RE = re.compile(r"^(?:qs|quickshell)(?:\s+-c\s+\S+)?\s+ipc\s+call\s+(\S+)\s+(\S+)(.*)$")


def words(camel):
    return re.sub(r"(?<=[a-z0-9])(?=[A-Z])", " ", camel).lower()


def program_of(cmd):
    """The program a command starts, without wrappers, env assignments or
    its path (`prime-run vesktop` → vesktop)."""
    try:
        tokens = shlex.split(cmd)
    except ValueError:
        tokens = cmd.split()
    i = 0
    while i < len(tokens):
        t = tokens[i]
        if re.match(r"^\w+=", t) or t in WRAPPERS or t.startswith("-"):
            i += 1
        elif t == "uwsm" and tokens[i + 1:i + 2] == ["app"]:
            i += 2
        elif t == "flatpak" and "run" in tokens[i:]:
            rest = [x for x in tokens[tokens.index("run", i) + 1:] if not x.startswith("-")]
            return rest[0].split(".")[-1].lower() if rest else "flatpak"
        else:
            return os.path.basename(t)
    return ""


def describe_exec(cmd):
    """(title, category, glyph, app, preset) for an exec_cmd command."""
    c = " ".join(cmd.split())
    m = IPC_RE.match(c)
    if m:
        target, fn, rest = m.group(1), m.group(2), m.group(3).strip()
        name, glyph = SHELL_NAMES.get(target, (words(target).capitalize(), "widgets"))
        if fn in ("toggle", "changeVisible") and not rest:
            return name, "shell", glyph, "", "ipc"
        return f"{name} · {words(fn)}{' ' + rest if rest else ''}", "shell", glyph, "", "ipc"
    if re.search(r"\b(qs|quickshell)\s+-p\s+\S*Lock\.qml", c):
        return "Lock screen", "shell", "lock", "", "exec"
    if c.startswith("grimblast"):
        if re.search(r"\bcopy\b", c):
            return "Screenshot to clipboard", "system", "content_copy", "", "exec"
        what = ("screen" if re.search(r"\b(output|screen)\b", c) else "area" if re.search(r"\barea\b", c)
                else "window" if re.search(r"\bactive\b", c) else "")
        glyph = "screenshot_region" if what == "area" else "screenshot_monitor"
        return "Screenshot" + (f" · {what}" if what else ""), "system", glyph, "", "exec"
    if "wf-recorder" in c:
        if re.search(r"\b(pkill|kill|killall)\b", c):
            return "Stop recording", "system", "stop_circle", "", "exec"
        return "Record screen", "system", "screen_record", "", "exec"
    if c.startswith("wpctl"):
        mic = "@DEFAULT_AUDIO_SOURCE@" in c
        if "set-mute" in c:
            return ("Mute microphone", "media", "mic_off", "", "exec") if mic else ("Mute", "media", "volume_off", "", "exec")
        if "set-volume" in c:
            up = re.search(r"\d+%\+|\+\d", c) is not None
            return ("Volume up", "media", "volume_up", "", "exec") if up else ("Volume down", "media", "volume_down", "", "exec")
    if c.startswith("brightnessctl"):
        up = re.search(r"\+\d|\d+%\+", c) is not None
        return ("Brightness up", "media", "brightness_high", "", "exec") if up else ("Brightness down", "media", "brightness_low", "", "exec")
    if c.startswith("playerctl"):
        for word, title, glyph in (("play-pause", "Play / pause", "play_pause"), ("next", "Next track", "skip_next"),
                                   ("previous", "Previous track", "skip_previous"), ("stop", "Stop", "stop"),
                                   ("pause", "Pause", "pause"), ("play", "Play", "play_arrow")):
            if re.search(rf"\b{word}\b", c):
                return title, "media", glyph, "", "exec"
    if re.match(r"^(hyprlock|loginctl\s+lock-session)\b", c):
        return "Lock", "system", "lock", "", "exec"
    prog = program_of(c)
    return prog or c, "app", "rocket_launch", prog, "exec"


DIRECTIONS = {"left": "arrow_back", "right": "arrow_forward", "up": "arrow_upward", "down": "arrow_downward"}
SHORT_DIRS = {"l": "left", "r": "right", "u": "up", "d": "down", "t": "up", "b": "down"}


def workspace_phrase(ws):
    s = str(ws)
    if s in ("e+1", "r+1", "+1", "m+1"):
        return "next workspace"
    if s in ("e-1", "r-1", "-1", "m-1", "previous"):
        return "previous workspace"
    if s.startswith("special"):
        name = s.split(":", 1)[1] if ":" in s else ""
        return f"scratchpad {name}".strip()
    return f"workspace {s}"


def cap(s):
    return s[:1].upper() + s[1:]


def describe(dsp):
    """title, category, glyph, app, and the editor's preset and param."""
    path, args = dsp.get("path", ""), dsp.get("args") or []
    a0 = args[0] if args else None
    t0 = a0 if isinstance(a0, dict) else {}
    keys0 = set(t0)

    def res(title, cat, glyph, preset="lua", param=None, app=""):
        return {"title": title, "category": cat, "glyph": glyph, "app": app, "preset": preset, "param": param}

    if path == "exec_cmd" and isinstance(a0, str):
        title, cat, glyph, app, preset = describe_exec(a0)
        return res(title, cat, glyph, preset, a0, app)
    if path == "window.close" and not args:
        return res("Close window", "window", "close", "close")
    if path == "window.kill" and not args:
        return res("Kill window", "window", "dangerous", "kill")
    if path == "window.float":
        if keys0 == {"action"} and t0.get("action") == "toggle":
            return res("Toggle floating", "window", "picture_in_picture_alt", "float")
        return res("Floating", "window", "picture_in_picture_alt")
    if path == "window.fullscreen":
        mode = t0.get("mode", "fullscreen")
        if keys0 <= {"mode"} and mode in ("fullscreen", "maximized"):
            if mode == "maximized":
                return res("Maximize", "window", "open_in_full", "fullscreen", mode)
            return res("Fullscreen", "window", "fullscreen", "fullscreen", mode)
        return res("Fullscreen", "window", "fullscreen")
    simple = {
        "window.pin": ("Pin window", "window", "push_pin", "pin"),
        "window.center": ("Center window", "window", "filter_center_focus", "center"),
        "window.pseudo": ("Pseudotile", "window", "dashboard", "pseudo"),
        "window.drag": ("Drag window", "window", "open_with", "drag"),
        "window.resize": ("Resize window", "window", "aspect_ratio", "resize"),
        "group.toggle": ("Toggle group", "window", "tab", "group"),
        "exit": ("Exit Hyprland", "system", "logout", "exit"),
    }
    if path in simple and not args:
        return res(*simple[path])
    if path == "window.move" and "workspace" in keys0:
        ws = t0["workspace"]
        title = "Move to " + workspace_phrase(ws)
        if keys0 == {"workspace"}:
            return res(title, "workspace", "move_down", "movews", str(ws))
        return res(title + (" (silent)" if t0.get("silent") else ""), "workspace", "move_down")
    if path == "focus" and keys0 == {"direction"}:
        word = str(t0["direction"]).lower()
        word = SHORT_DIRS.get(word, word)
        if word in DIRECTIONS:
            return res(f"Focus {word}", "window", DIRECTIONS[word], "focusdir", word)
        return res(f"Focus {word}", "window", "arrow_forward")
    if path == "focus" and keys0 == {"workspace"}:
        ws = str(t0["workspace"])
        phrase = workspace_phrase(ws)
        glyph = (f"#{ws}" if re.fullmatch(r"\d{1,2}", ws) else "arrow_right_alt" if phrase.startswith("next")
                 else "keyboard_backspace" if phrase.startswith("previous") else "space_dashboard")
        return res(cap(phrase), "workspace", glyph, "focusws", ws)
    if path == "focus" and "window" in keys0:
        return res("Focus window", "window", "select_window")
    if path == "workspace.toggle_special":
        if isinstance(a0, str) or not args:
            name = a0 or ""
            return res("Scratchpad" + (f" · {name}" if name else ""), "workspace", "layers", "special", name)
        return res("Scratchpad", "workspace", "layers")
    if path == "layout" and isinstance(a0, str) and len(args) == 1:
        return res(f"Layout · {a0}", "window", "view_column", "layout", a0)
    if path.startswith("group."):
        return res("Group · " + path.split(".", 1)[1].replace("_", " "), "window", "tab")
    if path == "submap":
        name = a0 if isinstance(a0, str) else ""
        return res("Leave submap" if name == "reset" else f"Submap · {name}", "system", "keyboard_command_key")
    if path == "dpms":
        return res("Screen power", "system", "monitor")
    if path == "<function>":
        return res("Lua function", "custom", "code")
    if path == "<nil>":
        return res("Invalid action", "custom", "error")
    if path.startswith("window."):
        return res(cap(path.split(".", 1)[1].replace("_", " ")) + " window", "window", "web_asset")
    return res(path.replace(".", " · ").replace("_", " ") or "Unknown", "custom", "code")


# ── The probe and the running Hyprland ──────────────────────────────────────

def run_probe(config_dir):
    try:
        p = subprocess.run(["lua", str(PROBE), str(config_dir), str(Path(config_dir) / "hyprland.lua")],
                           capture_output=True, text=True, timeout=8, errors="replace")
    except FileNotFoundError:
        return {"ok": False, "error": "lua is not installed", "binds": []}
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": "reading the config timed out", "binds": []}
    try:
        data = json.loads(p.stdout)
    except ValueError:
        return {"ok": False, "error": (p.stderr or p.stdout or "the probe failed").strip()[-600:], "binds": []}
    if not isinstance(data.get("binds"), list):
        data["binds"] = []  # an empty Lua table encodes as {}
    return data


def hyprctl(*args, timeout=4):
    if NO_HYPRCTL or not os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        return None
    try:
        p = subprocess.run(["hyprctl", *args], capture_output=True, text=True, timeout=timeout, errors="replace")
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None
    return p.stdout if p.returncode == 0 else None


def live_binds():
    text = hyprctl("binds", "-j")
    if text is None:
        return None
    try:
        return [{"modmask": b.get("modmask", 0), "key": b.get("key", ""), "submap": b.get("submap", "")}
                for b in json.loads(text)]
    except (ValueError, AttributeError):
        return None


# ── Listing ─────────────────────────────────────────────────────────────────

def load_sources(config_dir):
    sources = {}
    for path in sorted(Path(config_dir).glob("*.lua")):
        try:
            sources[path.name] = Source(path.name, path.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError):
            pass
    return sources


def collect(config_dir):
    """The binds of the config in config_dir: the probe's records joined to
    the hl.bind( calls in the source."""
    probe = run_probe(config_dir)
    sources = load_sources(config_dir)
    titles = {name: assign_sections(src) for name, src in sources.items()}

    sites = {}
    for rec in probe.get("binds", []):
        sites.setdefault((rec.get("file"), rec.get("line")), []).append(rec)

    binds, seen = [], {}
    for rec in probe.get("binds", []):
        name, line = rec.get("file"), rec.get("line")
        site = sites[(name, line)]
        k = seen.get((name, line), 0)
        seen[(name, line)] = k + 1
        src = sources.get(name)
        calls = [i for i, c in enumerate(src.calls) if c["line"] == line] if src else []
        mods, key, modmask = parse_keys(rec.get("keys", ""))
        opts = rec.get("opts") if isinstance(rec.get("opts"), dict) else {}
        dsp = rec.get("dsp") or {"path": "<nil>", "args": []}
        if not isinstance(dsp.get("args"), list):
            dsp["args"] = []
        description = opts.get("description") or opts.get("desc") or ""
        b = {
            "file": name, "line": line, "endLine": line, "keys": rec.get("keys", ""),
            "mods": mods, "key": key, "modmask": modmask, "submap": rec.get("submap", ""),
            "dsp": dsp, "opts": {o: v for o, v in opts.items() if o not in ("description", "desc")},
            "description": description, "raw": "", "rawArgs": {"keys": None, "dsp": None, "opts": None},
            "editable": False, "generated": len(site) > max(1, len(calls)),
            "groupSize": len(site), "groupIndex": k, "section": file_default_title(name or "?"),
            **describe(dsp),
        }
        if src and calls:
            call = src.calls[calls[k] if len(site) == len(calls) else calls[0]]
            b["raw"] = call["raw"]
            b["endLine"] = call["endLine"]
            b["rawArgs"] = {"keys": src.arg_text(call, 0), "dsp": src.arg_text(call, 1), "opts": src.arg_text(call, 2)}
            b["section"] = titles[name][src.calls.index(call)]
            b["editable"] = len(site) == len(calls) and len(call["args"]) in (2, 3)
        if b["submap"]:
            b["section"] = f"Submap · {b['submap']}"
        if b["preset"] == "lua":
            b["param"] = b["rawArgs"]["dsp"] or ""
        b["id"] = f"{name}:{line}" + (f"#{k}" if len(site) > 1 else "")
        binds.append(b)
    return probe, sources, binds


def file_info(sources, binds):
    files = []
    for name, src in sources.items():
        mine = [b for b in binds if b["file"] == name]
        if not mine:
            continue
        sections, order = {}, []
        for b in mine:
            s = sections.get(b["section"])
            if s is None:
                s = sections[b["section"]] = {"title": b["section"], "count": 0, "anchorLine": 0, "anchorRaw": ""}
                order.append(b["section"])
            s["count"] += 1
            if b["editable"] and not b["submap"]:
                s["anchorLine"], s["anchorRaw"] = b["line"], b["raw"]
        files.append({"name": name, "path": str(HYPR_DIR / name), "mainMod": src.main_mod_var(),
                      "sections": [sections[t] for t in order if sections[t]["anchorLine"]]})
    files.sort(key=lambda f: (f["name"] != "hyprland.lua", f["name"]))
    return files


def list_binds():
    if not (HYPR_DIR / "hyprland.lua").exists():
        return {"ok": False, "error": "no-lua-config", "dir": str(HYPR_DIR), "binds": [], "files": []}
    probe, sources, binds = collect(HYPR_DIR)
    live = live_binds()
    errors = hyprctl("configerrors")
    return {
        "ok": True,
        "dir": str(HYPR_DIR),
        "probeError": "" if probe.get("ok") else str(probe.get("error", "")),
        "strict": bool(probe.get("strict")),
        "files": file_info(sources, binds),
        "binds": binds,
        "live": live or [],
        "liveOk": live is not None,
        "configErrors": (errors or "").strip(),
    }


# ── Writing Lua ─────────────────────────────────────────────────────────────

def lua_string(s):
    """A Lua literal for s: quoted, or a long bracket when it has quotes,
    backslashes or newlines (as the config writes its grimblast commands)."""
    if not re.search(r'["\\\n\r]', s):
        return '"' + s + '"'
    eq = ""
    while (s + "]" + eq + "]").find("]" + eq + "]") != len(s):
        eq += "="
    return "[" + eq + "[" + ("\n" if s.startswith("\n") else "") + s + "]" + eq + "]"


def keys_expr(mods, key, main_mod_var):
    order = mod_sort(mods)
    if main_mod_var and order and order[0] == "SUPER":
        return f'{main_mod_var} .. " + {combo_text(order[1:], key)}"'
    return '"' + combo_text(order, key) + '"'


def parse_table(text):
    """A table constructor's entries as (key, raw value); key is None for a
    positional entry. None when the text isn't a constructor."""
    t = text.strip()
    if not (t.startswith("{") and t.endswith("}")):
        return None
    mask = code_mask(t)
    entries = []
    for a, b in split_args(t, mask, 0, len(t) - 1):
        a, b = strip_span(t, a, b)
        if a == b:
            continue
        m = re.match(r'^(?:([A-Za-z_]\w*)|\[\s*"([A-Za-z_]\w*)"\s*\])\s*=\s*(.*)$', t[a:b], re.S)
        entries.append((m.group(1) or m.group(2), m.group(3).strip()) if m else (None, t[a:b]))
    return entries


def opts_expr(original, flags, description):
    """New options-table text. original: the old table's text or None;
    flags: {flag: bool}, or None to keep them; description: text, or None
    to keep it. None when nothing is left."""
    entries = parse_table(original) if original else []
    if entries is None:
        if flags is None and description is None:
            return original
        raise ValueError("this bind's options come from an expression; change them in the file")
    result, seen = [], set()
    for key, raw in entries:
        if key in ("description", "desc"):
            seen.add("description")
            if description is None:
                result.append((key, raw))
            elif description:
                result.append((key, lua_string(description)))
        elif key in FLAGS and flags is not None:
            seen.add(key)
            if flags.get(key):
                result.append((key, "true"))
        else:
            result.append((key, raw))
    for key in FLAGS:
        if flags and flags.get(key) and key not in seen:
            result.append((key, "true"))
    if description and "description" not in seen:
        result.append(("description", lua_string(description)))
    if not result:
        return None
    return "{ " + ", ".join(raw if key is None else f"{key} = {raw}" for key, raw in result) + " }"


def find_call(src, line, raw):
    """The call that read as `raw` at `line`; wherever it is now if the file
    moved under us, as long as it is the only one like it."""
    for c in src.calls:
        if c["line"] == line and c["raw"] == raw:
            return c
    same = [c for c in src.calls if c["raw"] == raw]
    if len(same) == 1:
        return same[0]
    raise ValueError(f"{src.name} changed since it was read; reopen the keybinds panel")


def check_combo(op):
    mods = [MOD_ALIASES.get(str(m).upper(), str(m).upper()) for m in op.get("mods") or []]
    key = str(op.get("key", "")).strip()
    if not key or not KEY_NAME.match(key):
        raise ValueError(f"“{key}” isn't a key name")
    bad = [m for m in mods if m not in MOD_BITS]
    if bad:
        raise ValueError(f"unknown modifier {bad[0]}")
    return mods, key


def aligned_gap(src, call):
    """The column (from the call's start) where its dispatcher argument
    sits, if the spaces before it line it up with its neighbours."""
    a = call["args"]
    if len(a) < 2:
        return None
    gap_start = src.text.index(",", a[0][1]) + 1
    gap = src.text[gap_start:a[1][0]]
    return a[1][0] - call["start"] if "\n" not in gap and len(gap) > 1 else None


def edit_pieces(src, call, op):
    """Edits for a changed call: only the arguments that changed are
    rewritten, in place."""
    text, s = src.text, call["start"]
    args = call["args"]
    keys_span, dsp_span = args[0], args[1]
    opts_span = args[2] if len(args) > 2 else None
    pieces = []

    if op.get("keysChanged"):
        mods, key = check_combo(op)
        var = src.main_mod_var()
        if not (var and re.search(rf"\b{re.escape(var)}\b", text[keys_span[0]:keys_span[1]])):
            var = None
        new = keys_expr(mods, key, var)
        col = aligned_gap(src, call)
        if col is not None:
            gap_start = text.index(",", keys_span[1]) + 1
            head = keys_span[0] - s + len(new) + 1
            pieces.append((gap_start, dsp_span[0], " " * max(1, col - head)))
        pieces.append((keys_span[0], keys_span[1], new))

    if op.get("dispatcher") is not None:
        pieces.append((dsp_span[0], dsp_span[1], op["dispatcher"].strip()))

    if op.get("flags") is not None or op.get("description") is not None:
        old = text[opts_span[0]:opts_span[1]] if opts_span else None
        new = opts_expr(old, op.get("flags"), op.get("description"))
        if opts_span and new:
            pieces.append((opts_span[0], opts_span[1], new))
        elif opts_span:
            pieces.append((dsp_span[1], opts_span[1], ""))  # the comma goes too
        elif new:
            pieces.append((dsp_span[1], dsp_span[1], ", " + new))
    return pieces


def new_call_text(src, anchor, op):
    mods, key = check_combo(op)
    head = f"hl.bind({keys_expr(mods, key, src.main_mod_var())},"
    col = aligned_gap(src, anchor) if anchor else None
    head = head.ljust(col) if col and col > len(head) else head + " "
    opts = opts_expr(None, op.get("flags") or {}, op.get("description") or None)
    return head + op["dispatcher"].strip() + (", " + opts if opts else "") + ")"


def delete_pieces(src, call):
    """What to remove for a deleted call: its whole lines when nothing else
    is on them (a trailing comment goes with it), a NOTE comment right above
    it, and the comment heading its group when it was the group's only
    bind."""
    text = src.text
    ls, le = src.line_start(call["start"]), src.line_end(call["close"])
    after = text[call["close"] + 1:le].split("--", 1)[0].strip().lstrip(";").strip()
    if text[ls:call["start"]].strip() or after:
        end = call["close"] + 1
        return [(call["start"], end + 1 if text[end:end + 1] == ";" else end, "")]
    lines = text.split("\n")
    first, last = call["line"] - 1, call["endLine"] - 1
    j = first - 1
    while j >= 0 and lines[j].strip().startswith("--"):
        j -= 1
    block = lines[j + 1:first]
    k = last + 1
    while k < len(lines) and lines[k].strip().startswith("--"):
        k += 1
    group_goes_on = k < len(lines) and CALL_RE.search(lines[k].split("--", 1)[0])
    a, b = ls, le
    # A NOTE right above is about this bind; a heading goes when nothing
    # is left under it.
    if block and (NOTE.match(block[0]) or not is_banner(block) and not group_goes_on):
        a = sum(len(x) + 1 for x in lines[:j + 1])
    # Don't leave two blank lines where it was.
    if (a == 0 or text[:a].endswith("\n\n")) and text[b:b + 1] == "\n":
        b += 1
    return [(a, b, "")]


def apply_pieces(text, pieces):
    ordered = sorted(pieces, key=lambda p: (p[0], p[1]))
    for (a1, b1, _), (a2, _, _) in zip(ordered, ordered[1:]):
        if b1 > a2:
            raise ValueError("two changes touch the same bind")
    for a, b, new in reversed(ordered):
        text = text[:a] + new + text[b:]
    return text


def validate_dispatcher(expr, locals_):
    """Build the expression in the running Hyprland. An error message, or
    None when it built (or Hyprland couldn't be asked)."""
    prelude = "".join(f"local {k} = {lua_string(v)} " for k, v in locals_.items())
    code = (prelude + "local ok, r = pcall(function() return (" + expr + "\n) end) "
            "if not ok then return 'ERR ' .. tostring(r) end "
            "if type(r) == 'function' then return 'OK function' end "
            "return 'OK ' .. tostring(r)")
    reply = hyprctl("repl", code)
    if reply is None:
        return None
    reply = reply.strip()
    if reply.startswith("OK HL.Dispatcher") or reply == "OK function":
        return None
    if reply.startswith("ERR "):
        msg = re.sub(r"^\[string .*?\]:\d+:\s*", "", reply[4:])
        missing = re.search(r"attempt to call a nil value \(field '(\w+)'\)", msg)
        return f"there's no dispatcher called “{missing.group(1)}”" if missing else msg or "it failed to build"
    if reply.startswith("OK"):
        return "it doesn't take those arguments"
    return None  # an unexpected reply: don't block on it


def backup(name, text):
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    now = time.time()
    path = BACKUP_DIR / f"{name}.{time.strftime('%Y%m%d-%H%M%S', time.localtime(now))}-{int(now * 1000) % 1000:03d}.bak"
    path.write_text(text, encoding="utf-8")
    for old in sorted(BACKUP_DIR.glob(f"{name}.*.bak"))[:-KEEP_BACKUPS]:
        try:
            old.unlink()
        except OSError:
            pass
    return str(path)


def write_in_place(path, text):
    """Overwrite the file in place, where Hyprland's watch on it (IN_MODIFY,
    which reloads straight away) sees it, and any symlink stays one. The
    new text goes in with a single write, padded with newlines when it's
    shorter, so whenever Hyprland reads it, it's the whole new config; the
    padding is cut off after."""
    data = text.encode("utf-8")
    fd = os.open(path, os.O_WRONLY)
    try:
        pad = b"\n" * max(0, os.fstat(fd).st_size - len(data))
        buf = data + pad
        done = 0
        while done < len(buf):
            done += os.pwrite(fd, buf[done:], done)
        if pad:
            os.ftruncate(fd, len(data))
        os.fsync(fd)
    finally:
        os.close(fd)


KIND_ORDER = {"add": 0, "edit": 1, "delete": 2}


def op_line(op):
    """Where an op works, for ordering: an add goes just under its anchor."""
    return op.get("anchorLine", 1e9) + 0.5 if op.get("op") == "add" else op.get("line") or 0


def apply_op(src, op):
    """(new text, line of the bind made or kept, or None) for one change."""
    if op.get("dispatcher") is not None:
        if not op["dispatcher"].strip():
            raise ValueError("the action is empty")
        err = validate_dispatcher(op["dispatcher"], src.string_locals())
        if err:
            raise ValueError(f"Hyprland can't build that action: {err}")
    kind = op.get("op")
    if kind == "delete":
        call = find_call(src, op.get("line"), op.get("raw", ""))
        return apply_pieces(src.text, delete_pieces(src, call)), None
    if kind == "edit":
        call = find_call(src, op.get("line"), op.get("raw", ""))
        if len(call["args"]) < 2:
            raise ValueError("that bind isn't written as hl.bind(keys, action[, options])")
        return apply_pieces(src.text, edit_pieces(src, call, op)), call["line"]
    if kind == "add":
        if op.get("dispatcher") is None:
            raise ValueError("the action is empty")
        anchor = (find_call(src, op.get("anchorLine"), op["anchorRaw"]) if op.get("anchorRaw")
                  else src.calls[-1] if src.calls else None)
        text = new_call_text(src, anchor, op)
        if anchor:
            pos = src.line_end(anchor["close"])
            indent = re.match(r"[ \t]*", src.text[src.line_start(anchor["start"]):]).group(0)
        else:
            pos, indent = len(src.text), ""
        lead = "" if pos == 0 or src.text[pos - 1] == "\n" else "\n"
        new = src.text[:pos] + lead + indent + text + "\n" + src.text[pos:]
        return new, new.count("\n", 0, pos + len(lead)) + 1
    raise ValueError(f"unknown change “{kind}”")


def apply(payload):
    """ops: a list of changes, all checked and then written together. They
    are made bottom-up, one at a time, so each sees the last one's result
    (two deleted binds take the heading they shared with them).

    add:    file, anchorLine + anchorRaw (the bind to put it after), mods,
            key, dispatcher, flags, description
    edit:   file, line, raw, and what changed: keysChanged with mods + key,
            dispatcher, flags, description
    delete: file, line, raw
    """
    ops = payload.get("ops") or []
    if not ops:
        return {"ok": False, "error": "nothing to change"}
    originals = {name: src.text for name, src in load_sources(HYPR_DIR).items()}
    texts = dict(originals)
    lines = {}  # op index → (file, line) of its bind
    for n in sorted(range(len(ops)), key=lambda i: (-op_line(ops[i]), KIND_ORDER.get(ops[i].get("op"), 9))):
        op = ops[n]
        name = op.get("file", "")
        if name not in texts:
            return {"ok": False, "error": f"{name} isn't in {HYPR_DIR}", "op": n}
        try:
            old = texts[name]
            new, line = apply_op(Source(name, old), op)
        except ValueError as e:
            return {"ok": False, "error": str(e), "op": n}
        # Everything placed so far is further down: it moves with this.
        delta = new.count("\n") - old.count("\n")
        for m, (f, l) in lines.items():
            if f == name:
                lines[m] = (f, l + delta)
        if line is not None:
            lines[n] = (name, line)
        texts[name] = new
    texts = {name: text for name, text in texts.items() if text != originals[name]}
    if not texts:
        return {"ok": False, "error": "that changes nothing"}

    # Try it in a scratch copy of the config first.
    with tempfile.TemporaryDirectory(prefix="qs-keybinds-") as tmp:
        for p in HYPR_DIR.glob("*.lua"):
            shutil.copy(p, Path(tmp) / p.name)
        for name, text in texts.items():
            (Path(tmp) / name).write_text(text, encoding="utf-8")
            check = subprocess.run(["luac", "-p", "-o", os.devnull, str(Path(tmp) / name)], capture_output=True, text=True)
            if check.returncode != 0:
                msg = check.stderr.strip().replace(str(Path(tmp)) + "/", "").replace("luac: ", "")
                return {"ok": False, "error": f"that would break {name}: {msg}"}
        probe, _, after = collect(tmp)
        if not probe.get("ok"):
            msg = str(probe.get("error", "")).replace(str(Path(tmp)) + "/", "").strip().split("\n")[0]
            return {"ok": False, "error": f"the config wouldn't load: {msg}"}
        for n, (name, line) in lines.items():
            op = ops[n]
            if op.get("op") == "add" or op.get("keysChanged"):
                want = (mod_sort(MOD_ALIASES.get(str(m).upper(), str(m).upper()) for m in op.get("mods") or []),
                        str(op.get("key")).lower())
                if not any(b["file"] == name and b["line"] == line and (b["mods"], b["key"].lower()) == want
                           for b in after):
                    return {"ok": False, "error": "the new bind didn't read back as written; nothing was saved"}

    for name in texts:
        if (HYPR_DIR / name).read_text(encoding="utf-8") != originals[name]:
            return {"ok": False, "error": f"{name} changed while saving; nothing was written"}
    changes = []
    for name, text in texts.items():
        saved = backup(name, originals[name])
        write_in_place(HYPR_DIR / name, text)
        changes.append({"file": name, "backup": saved, "hash": sha1(text)})
    return {"ok": True, "changes": changes, "lines": {str(n): l for n, (_, l) in lines.items()}}


def restore(payload):
    """restores: [{file, backup, hash}]. hash is what the file has to still
    be (what the change wrote), so an edit made since is never thrown away;
    leave it out to restore regardless."""
    todo = []
    for r in payload.get("restores") or []:
        name = r.get("file", "")
        path = HYPR_DIR / name
        bak = Path(r.get("backup", ""))
        if not path.is_file() or path.parent != HYPR_DIR or not bak.is_file() \
                or bak.resolve().parent != BACKUP_DIR.resolve():
            return {"ok": False, "error": f"no backup to restore {name} from"}
        current = path.read_text(encoding="utf-8")
        if r.get("hash") and sha1(current) != r["hash"]:
            return {"ok": False, "error": f"{name} has been changed since; not undoing over that"}
        todo.append((name, path, current, bak.read_text(encoding="utf-8")))
    changes = []
    for name, path, current, text in todo:
        saved = backup(name, current)
        write_in_place(path, text)
        changes.append({"file": name, "backup": saved, "hash": sha1(text)})
    return {"ok": True, "changes": changes}


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    try:
        if cmd == "list":
            out(list_binds())
        elif cmd in ("apply", "restore"):
            payload = json.loads(sys.argv[2] if len(sys.argv) > 2 else sys.stdin.read())
            out(apply(payload) if cmd == "apply" else restore(payload))
        else:
            out({"ok": False, "error": f"unknown command {cmd}"})
    except Exception as e:  # the panel always gets an answer
        out({"ok": False, "error": f"{type(e).__name__}: {e}"})


if __name__ == "__main__":
    main()
