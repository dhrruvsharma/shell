#!/usr/bin/env bash
# Build a standalone package from this config:
#
#   packaging/export.sh readers [OUT_DIR]      anime player, manga and novel readers
#                                              (default: ~/quickshell-readers)
#   packaging/export.sh wallpapers [OUT_DIR]   the wallpaper picker and wallpaper layer
#                                              (default: ~/quickshell-wallpapers)
#
# OUT_DIR is replaced wholesale except for its .git, so it can be the
# package's own git checkout: export, review `git diff`, commit, push.
#
# A package keeps this config's layout (modules/, services/, components/,
# colors/, …), so `import qs.*` lines work unchanged. Then common/overlay/
# and <package>/overlay/ go on top: a standalone shell.qml, its installer
# and README, and stand-ins for the rice-only pieces (desktop themes, …).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QS="$(cd "$HERE/.." && pwd)"
REPO="$(cd "$QS/.." && pwd)"
PKG=${1-}
MARKER=.package-export

die() { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

# Paths relative to this config, copied as they are (folders whole).
case $PKG in
    readers)
        FILES=(
            modules/anime modules/manga modules/novel
            services/{Anime,Manga,Novel,Http,HealthPoller}.qml
            components/{ClickableRect,CoverCard,CoverPlaceholder,CoverProgressBar,Divider}.qml
            components/{EmptyState,IconButton,LoadingBar,LoadingState,MaterialIcon}.qml
            components/{SkeletonGrid,SkeletonList,SkeletonPulse,SkeletonText,Spinner}.qml
            components/{StyledScrollBar,StyledText}.qml
            scripts/anime_server.py scripts/manga_server.py scripts/novel_server
        ) ;;
    wallpapers)
        FILES=(
            modules/wallpaper/{Wallpaper,SwatchCard,SpectrumRibbon,WallpaperBackdrop,WallpaperLayer,PickerSettings}.qml
            modules/lock/{Glyph,LockTheme}.qml
            services/{WallpaperEngine,WallpaperSwatches,WallpaperFavorites,Wallhaven}.qml
            components/{ClickableRect,Spinner,StyledText,StyledTextField}.qml
            shaders/wallpaper_transition.frag shaders/wallpaper_transition.frag.qsb
            scripts/wallpaper-apply scripts/wallpaper-still scripts/wallpaper-palettes.py
        ) ;;
    *) die "usage: $0 readers|wallpapers [OUT_DIR]" ;;
esac

OUT="$(realpath -m "${2:-$HOME/quickshell-$PKG}")"
case $OUT in
    "$HOME"|"$REPO"|"$REPO"/*|/) die "refusing to export into $OUT" ;;
esac
if [[ -d $OUT && -n $(ls -A "$OUT") && ! -e $OUT/$MARKER ]]; then
    shopt -s dotglob nullglob
    others=("$OUT"/*)
    [[ ${#others[@]} -eq 1 && ${others[0]} == "$OUT/.git" ]] \
        || die "$OUT is not empty and wasn't made by this script"
    shopt -u dotglob nullglob
fi

mkdir -p "$OUT"
find "$OUT" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +

for f in "${FILES[@]}"; do
    [[ -e $QS/$f ]] || die "$f is gone: update export.sh"
    mkdir -p "$OUT/$(dirname "$f")"
    cp -r "$QS/$f" "$OUT/$f"
done
find "$OUT" -name __pycache__ -type d -prune -exec rm -rf {} +

# Colours: read the palette from the package's own folder, quietly falling
# back to the built-in defaults when there is none.
old='path: Quickshell.env("HOME") + "/.config/quickshell/colors/Colors.json"'
grep -qF "$old" "$QS/colors/Colors.qml" || die "colors/Colors.qml: palette path changed, update export.sh"
mkdir -p "$OUT/colors"
sed "s|$old|path: Quickshell.shellPath(\"colors/Colors.json\")\n        printErrors: false|" \
    "$QS/colors/Colors.qml" > "$OUT/colors/Colors.qml"

cp -r "$HERE/common/overlay/." "$HERE/$PKG/overlay/." "$OUT/"
cp "$REPO/LICENSE" "$OUT/"
mkdir -p "$OUT/extras/matugen"
cp "$REPO/matugen/templates/quickshell.json.hbs" "$OUT/extras/matugen/"

# Every rice type the exported QML names must have come along (or have a
# stand-in in an overlay).
python3 - "$QS" "$OUT" <<'PY'
import os, re, sys
qs, out = sys.argv[1:]
def types(root):
    found = {}
    for dirpath, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in ("packaging", "scripts", ".git")]
        for f in files:
            if f.endswith(".qml") and f[0].isupper():
                found.setdefault(f[:-4], os.path.relpath(os.path.join(dirpath, f), root))
    return found
rice, pkg = types(qs), types(out)
missing = set()
for dirpath, _, files in os.walk(out):
    for f in files:
        if not f.endswith(".qml"):
            continue
        src = open(os.path.join(dirpath, f)).read()
        src = re.sub(r"//[^\n]*", "", src)
        src = re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', src)
        for name in set(re.findall(r"\b([A-Z][A-Za-z0-9]+)\b", src)):
            if name in rice and name not in pkg:
                missing.add(f"{rice[name]} (used by {os.path.relpath(os.path.join(dirpath, f), out)})")
if missing:
    sys.exit("missing from the package; add to export.sh or stub in an overlay:\n  " + "\n  ".join(sorted(missing)))
PY

rev=$(git -C "$REPO" rev-parse --short HEAD)
git -C "$REPO" diff --quiet HEAD -- quickshell || rev+="-dirty"
printf 'Generated by quickshell/packaging/export.sh from dhrruvsharma/shell %s.\n' "$rev" > "$OUT/$MARKER"

printf '\033[1;34m::\033[0m Exported %s to %s (%s)\n' "$PKG" "$OUT" "$rev"
