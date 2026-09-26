#!/usr/bin/env python3
"""Collect every Quickshell IPC command used by this rice into ipc-commands.json.

Sources:
  * every IpcHandler in the shell's QML (typed, zero-argument functions only;
    Quickshell does not expose untyped ones over IPC)
  * `qs ipc` / `quickshell -p` commands bound in the Hyprland config: every
    *.lua in ~/.config/hypr (hyprland.lua, quickshell.lua, ...), or
    hyprland.conf when there is no Lua config (Hyprland then ignores it)

Services/Notes.qml merges the result into the notes drawer's "IPC Toggle"
category. Run again after adding handlers or binds.
"""
import json
import os
import re
import sys
from pathlib import Path

SHELL_DIR = Path(__file__).resolve().parent.parent
HYPR_DIR = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "hypr"
OUT = SHELL_DIR / "ipc-commands.json"

IS_SHELL_CMD = re.compile(r"^(qs|quickshell)\s+(ipc\s+call|-p)\s")


def norm(cmd):
    return " ".join(cmd.split())


def words(camel):
    return re.sub(r"(?<=[a-z0-9])(?=[A-Z])", " ", camel).title()


def describe(target, func):
    verb = "Toggle" if func in ("toggle", "changeVisible") else words(func)
    return f"{verb} {words(target)}"


def block_body(src, start):
    """Text between the brace at/after `start` and its matching close."""
    open_at = src.index("{", start)
    depth = 0
    for i in range(open_at, len(src)):
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
            if depth == 0:
                return src[open_at + 1:i]
    return src[open_at + 1:]


def qml_commands():
    cmds = {}
    for path in sorted(SHELL_DIR.rglob("*.qml")):
        src = path.read_text(errors="ignore")
        for m in re.finditer(r"\bIpcHandler\s*\{", src):
            body = block_body(src, m.start())
            target = re.search(r'^\s*target:\s*"([^"]+)"', body, re.M)
            if not target:
                continue
            for fn in re.finditer(r"\bfunction\s+(\w+)\s*\(\s*\)\s*:\s*\w+", body):
                cmd = f"qs ipc call {target.group(1)} {fn.group(1)}"
                cmds[cmd] = describe(target.group(1), fn.group(1))
    return cmds


def lua_binds(path):
    src = path.read_text(errors="ignore")
    env = dict(re.findall(r'^\s*local\s+(\w+)\s*=\s*"([^"]*)"', src, re.M))

    def ev(expr):
        out = []
        for part in expr.split(".."):
            part = part.strip()
            lit = re.fullmatch(r'"([^"]*)"', part)
            if lit:
                out.append(lit.group(1))
            elif part in env:
                out.append(env[part])
            else:
                return None
        return "".join(out)

    for m in re.finditer(r"hl\.bind\((.+?),\s*hl\.dsp\.exec_cmd\((.+?)\)\s*\)", src):
        key, cmd = ev(m.group(1)), ev(m.group(2))
        if key and cmd:
            yield " ".join(key.split()).replace(" + ", "+"), cmd


def conf_binds(path):
    src = path.read_text(errors="ignore")
    env = dict(re.findall(r"^\s*\$(\w+)\s*=\s*(.*?)\s*(?:#.*)?$", src, re.M))
    sub = lambda s: re.sub(r"\$(\w+)", lambda v: env.get(v.group(1), v.group(0)), s)
    for m in re.finditer(r"^\s*bind\w*\s*=\s*([^,]*),\s*([^,]*),\s*exec\s*,\s*(.+)$", src, re.M):
        mods, key, cmd = (sub(g).strip() for g in m.groups())
        yield "+".join(mods.split() + [key]), cmd


def hypr_binds():
    if (HYPR_DIR / "hyprland.lua").exists():
        for path in sorted(HYPR_DIR.glob("*.lua")):
            yield from lua_binds(path)
    elif (HYPR_DIR / "hyprland.conf").exists():
        yield from conf_binds(HYPR_DIR / "hyprland.conf")


def main():
    cmds = qml_commands()
    keys = {}

    for key, cmd in hypr_binds():
        cmd = norm(cmd)
        if not IS_SHELL_CMD.match(cmd):
            continue
        keys.setdefault(cmd, [])
        if key not in keys[cmd]:
            keys[cmd].append(key)
        if cmd not in cmds:
            ipc = re.match(r"qs ipc call (\S+) (\S+)$", cmd)
            cmds[cmd] = describe(*ipc.groups()) if ipc else "Lock Screen" if "Lock.qml" in cmd else cmd

    entries = []
    for cmd in sorted(cmds):
        sub = cmds[cmd]
        if keys.get(cmd):
            sub += " · " + ", ".join(keys[cmd])
        entries.append({"text": cmd, "subtext": sub})

    OUT.write_text(json.dumps(entries, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"wrote {len(entries)} commands to {OUT}", file=sys.stderr)


if __name__ == "__main__":
    main()
