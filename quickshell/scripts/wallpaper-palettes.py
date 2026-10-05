#!/usr/bin/env python3
"""The colour scheme matugen would make from each wallpaper, for the
wallpaper picker's swatch cards (services/WallpaperSwatches.qml).

    wallpaper-palettes.py DIR NAME...

matugen runs as a dry run (nothing is written or applied) with the options
services/WallpaperEngine.qml sets wallpapers with, so a card shows the exact
scheme its wallpaper will give. Prints one JSON line per wallpaper as soon as
it's read:

    {"n": name, "m": mtime, "s": bytes, "w": width, "h": height,
     "c": {role: "#rrggbb", ...}}

with "e": 1 instead of "c" when matugen can't read the image. A video is
read from a frame of it (scripts/wallpaper-still), whose path comes as "f";
"w" and "h" are the frame's. A line on stdin
of tab-separated names moves those names to the front of the queue, in that
order (the picker sends the cards in view).
"""

import json
import os
import struct
import subprocess
import sys
import threading
from collections import deque

WORKERS = 3

STILL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "wallpaper-still")
VIDEO = (".mp4", ".webm", ".mkv", ".mov", ".m4v")

ROLES = (
    "background", "surface", "surface_container_lowest", "surface_container_low",
    "surface_container", "surface_container_high", "surface_container_highest",
    "on_surface", "on_surface_variant", "outline", "outline_variant",
    "primary", "on_primary", "primary_container", "on_primary_container",
    "secondary", "on_secondary", "secondary_container", "on_secondary_container",
    "tertiary", "on_tertiary", "tertiary_container", "on_tertiary_container",
    "error", "source_color",
)


def jpeg_size(f):
    f.seek(2)
    while True:
        byte = f.read(1)
        if not byte:
            return 0, 0
        if byte != b"\xff":
            continue
        marker = f.read(1)
        while marker == b"\xff":
            marker = f.read(1)
        if not marker:
            return 0, 0
        m = marker[0]
        if m in (0xD9, 0xDA):
            return 0, 0
        if m == 0x01 or 0xD0 <= m <= 0xD7:
            continue
        length = struct.unpack(">H", f.read(2))[0]
        if 0xC0 <= m <= 0xCF and m not in (0xC4, 0xC8, 0xCC):
            f.read(1)
            h, w = struct.unpack(">HH", f.read(4))
            return w, h
        f.seek(length - 2, 1)


def image_size(path):
    """(width, height) from the file's header, or (0, 0)."""
    try:
        with open(path, "rb") as f:
            head = f.read(30)
            if head[:8] == b"\x89PNG\r\n\x1a\n":
                return struct.unpack(">II", head[16:24])
            if head[:6] in (b"GIF87a", b"GIF89a"):
                return struct.unpack("<HH", head[6:10])
            if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
                kind = head[12:16]
                if kind == b"VP8 ":
                    w, h = struct.unpack("<HH", head[26:30])
                    return w & 0x3FFF, h & 0x3FFF
                if kind == b"VP8L":
                    bits = int.from_bytes(head[21:25], "little")
                    return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1
                if kind == b"VP8X":
                    return int.from_bytes(head[24:27], "little") + 1, int.from_bytes(head[27:30], "little") + 1
            if head[:2] == b"\xff\xd8":
                return jpeg_size(f)
    except (OSError, struct.error):
        pass
    return 0, 0


def still(path):
    """A video's grabbed frame (cached by wallpaper-still), or None."""
    try:
        out = subprocess.run([STILL, path], capture_output=True, text=True, timeout=120)
        frame = out.stdout.strip()
        return frame if out.returncode == 0 and frame else None
    except (OSError, subprocess.SubprocessError):
        return None


def scheme(path):
    try:
        out = subprocess.run(
            ["matugen", "image", path, "--source-color-index", "0", "--dry-run", "-j", "hex", "-q"],
            capture_output=True, text=True, timeout=90,
        )
        colors = json.loads(out.stdout)["colors"]
        return {r: (colors[r].get("default") or colors[r]["dark"])["color"] for r in ROLES if r in colors}
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
        return None


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: wallpaper-palettes.py DIR NAME...")
    folder = sys.argv[1]
    queue = deque(dict.fromkeys(sys.argv[2:]))
    lock = threading.Lock()
    out = threading.Lock()

    def listen():
        for line in sys.stdin:
            names = [n for n in line.rstrip("\n").split("\t") if n]
            with lock:
                for name in reversed(names):
                    try:
                        queue.remove(name)
                    except ValueError:
                        continue
                    queue.appendleft(name)

    def work():
        while True:
            with lock:
                if not queue:
                    return
                name = queue.popleft()
            path = os.path.join(folder, name)
            try:
                st = os.stat(path)
            except OSError:
                continue
            record = {"n": name, "m": int(st.st_mtime), "s": st.st_size}
            image = path
            if name.lower().endswith(VIDEO):
                image = still(path)
                if image:
                    record["f"] = image
            record["w"], record["h"] = image_size(image) if image else (0, 0)
            colors = scheme(image) if image else None
            if colors:
                record["c"] = colors
            else:
                record["e"] = 1
            with out:
                print(json.dumps(record, separators=(",", ":")), flush=True)

    threading.Thread(target=listen, daemon=True).start()
    workers = [threading.Thread(target=work) for _ in range(WORKERS)]
    for t in workers:
        t.start()
    for t in workers:
        t.join()


if __name__ == "__main__":
    main()
