#!/usr/bin/env python3
"""Where each app's icon is, for the app registry (services/AppRegistry.qml).

    app-icons.py NAME...

Looks every Icon= name up as the icon theme spec does: in the icon theme
GTK is set to (gtk-3.0/settings.ini, Papirus when unset), then the themes
it inherits and hicolor, then /usr/share/pixmaps. Of a theme's sizes it
takes the nearest to 96 px, so the launcher's large icons stay sharp. (The
shell's own lookup, through Qt, goes to another theme; the app icons in
the switcher, the launcher, the pet's hub and the keybinds keep to this
one.) Prints `name<TAB>path` for each name found; an absolute path comes
back as it is when the file exists.
"""

import configparser
import os
import sys

SIZE = 96
EXTS = (".svg", ".png", ".xpm")


def bases():
    home = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    dirs = [home] + (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":")
    return [os.path.expanduser("~/.icons")] + [os.path.join(d, "icons") for d in dirs if d]


def gtk_theme():
    for name in ("gtk-3.0", "gtk-4.0"):
        ini = configparser.ConfigParser(interpolation=None)
        try:
            ini.read(os.path.expanduser(f"~/.config/{name}/settings.ini"))
            theme = ini.get("Settings", "gtk-icon-theme-name", fallback="").strip()
        except configparser.Error:
            theme = ""
        if theme:
            return theme
    return "Papirus"


class Theme:
    def __init__(self, name, roots):
        self.roots = [os.path.join(r, name) for r in roots if os.path.isdir(os.path.join(r, name))]
        self.inherits = []
        dirs = []
        for root in self.roots:
            index = os.path.join(root, "index.theme")
            if not os.path.isfile(index):
                continue
            ini = configparser.ConfigParser(interpolation=None, strict=False)
            try:
                ini.read(index, encoding="utf-8")
            except configparser.Error:
                continue
            self.inherits = [t.strip() for t in ini.get("Icon Theme", "Inherits", fallback="").split(",") if t.strip()]
            for sub in ini.get("Icon Theme", "Directories", fallback="").split(","):
                sub = sub.strip()
                if sub and ini.has_section(sub):
                    dirs.append((self.distance(ini[sub]), sub))
            break
        # Nearest size first, so the first file found is the one to take.
        self.dirs = [sub for _, sub in sorted(dirs, key=lambda d: d[0])]

    @staticmethod
    def distance(sec):
        try:
            size = int(sec.get("Size", "0"))
            kind = sec.get("Type", "Threshold")
            if kind == "Fixed":
                return abs(size - SIZE)
            if kind == "Scalable":
                lo, hi = int(sec.get("MinSize", size)), int(sec.get("MaxSize", size))
            else:
                t = int(sec.get("Threshold", "2"))
                lo, hi = size - t, size + t
        except ValueError:
            return 1 << 20
        return lo - SIZE if SIZE < lo else SIZE - hi if SIZE > hi else 0

    def find(self, name):
        for sub in self.dirs:
            for root in self.roots:
                for ext in EXTS:
                    path = os.path.join(root, sub, name + ext)
                    if os.path.isfile(path):
                        return path
        return None


def chain(first, roots):
    themes, seen, todo = [], set(), [first]
    while todo:
        name = todo.pop(0)
        if name in seen:
            continue
        seen.add(name)
        theme = Theme(name, roots)
        if theme.roots:
            themes.append(theme)
            todo[0:0] = theme.inherits
    if "hicolor" not in seen:
        themes.append(Theme("hicolor", roots))
    return themes


def main(names):
    roots = bases()
    themes = chain(gtk_theme(), roots)
    for name in dict.fromkeys(names):
        if not name:
            continue
        if os.path.isabs(name):
            if os.path.isfile(name):
                print(f"{name}\t{name}")
            continue
        bare = name[:-4] if name.lower().endswith(EXTS) else name
        path = next((p for p in (t.find(bare) for t in themes) if p), None)
        if not path:
            path = next((f"/usr/share/pixmaps/{bare}{e}" for e in EXTS if os.path.isfile(f"/usr/share/pixmaps/{bare}{e}")), None)
        if path:
            print(f"{name}\t{path}")


if __name__ == "__main__":
    main(sys.argv[1:])
