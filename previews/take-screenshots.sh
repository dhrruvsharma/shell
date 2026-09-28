#!/usr/bin/env bash
# Regenerates previews/rice-screenshots/ without touching the live session.
#
# Runs a nested Hyprland (on a hidden special workspace) with a headless
# 1920x1200 output and a fake HOME holding copies of the configs, starts a
# copy of the Quickshell config inside it, then cycles themes/wallpapers and
# grabs each state with grim. Nothing under the real ~/.config is written
# except the output images.
#
# Usage: previews/take-screenshots.sh [workdir]   (default: a mktemp dir)
set -euo pipefail

CFG="$HOME/.config"
OUT="$CFG/previews/rice-screenshots"
WALLS="$HOME/Pictures/wallpapers"
W="${1:-$(mktemp -d /tmp/rice-shots.XXXXXX)}"
H="$W/home"
nap() { python3 -c "import time; time.sleep($1)"; }

# theme id, wallpaper file (in $WALLS)
THEMES="
hud lmd95y.jpg
terminal 0qg185.jpg
cosmos romantic-night-sky-5120x2880-25549.jpg
zen r282vq.jpg
xianxia 5d2jw5.jpg
cyberpunk wallhaven-k83mkq_1920x1200.png
wabisabi japan-artistic-5120x2880-25406.jpg
artdeco 4826vj.jpg
gothic wallhaven-rq25zw_1920x1200.png
newspaper 2kjyrg.jpg
wasteland zpg9jv.jpg
"

# ---- fake HOME -------------------------------------------------------------
mkdir -p "$H/.config" "$H/.cache/quickshell" "$H/.local/share" "$W/shots"
for d in quickshell hypr matugen kitty cava fish qt6ct Kvantum; do
    [ -e "$CFG/$d" ] && cp -a "$CFG/$d" "$H/.config/"
done
mkdir -p "$H/.config/gtk-3.0" "$H/.config/gtk-4.0" "$H/.config/rofi"
for d in fonts icons themes applications; do
    [ -e "$HOME/.local/share/$d" ] && ln -sfn "$HOME/.local/share/$d" "$H/.local/share/$d"
done
[ -e "$HOME/.icons" ] && ln -sfn "$HOME/.icons" "$H/.icons"
ln -sfn "$HOME/Pictures" "$H/Pictures"
cp -a "$HOME/.cache/current_wallpaper" "$HOME/.cache/current_avatar" "$H/.cache/" 2>/dev/null || true
cp -a "$HOME/.cache/quickshell/"*.json "$H/.cache/quickshell/" 2>/dev/null || true
# No global gsettings from matugen's hook.
sed -i 's/^post_hook = "gsettings.*$//' "$H/.config/matugen/config.toml"

# Nested Hyprland: no autostart, headless SHOT output, tiled, no cursor.
python3 - "$H/.config/hypr/hyprland.lua" <<'EOF'
import re, sys
p = sys.argv[1]; s = open(p).read()
s = re.sub(r'hl\.on\("hyprland\.start", function\(\)\n.*?\nend\)',
           'hl.monitor({ output = "SHOT", mode = "1920x1200@60", position = "0x0", scale = 1 })',
           s, flags=re.S)
s = s.replace('layout           = "scrolling"', 'layout           = "dwindle"')
s += '\nhl.config({ cursor = { invisible = true } })\n'
open(p, 'w').write(s)
EOF

cat > "$W/nested.sh" <<EOF
#!/bin/sh
export HOME=$H XDG_CONFIG_HOME=$H/.config XDG_CACHE_HOME=$H/.cache XDG_DATA_HOME=$H/.local/share XDG_STATE_HOME=$H/.local/state
unset HYPRLAND_INSTANCE_SIGNATURE
exec Hyprland > $W/nested.log 2>&1
EOF
chmod +x "$W/nested.sh"

# ---- start the nested session ---------------------------------------------
before=$(ls "$XDG_RUNTIME_DIR/hypr")
sockets=$(ls "$XDG_RUNTIME_DIR" | grep -E '^wayland-[0-9]+$' || true)
hyprctl eval "hl.exec_cmd('$W/nested.sh', { workspace = 'special:qsshot silent' })" >/dev/null
nap 4
SIG=$(comm -13 <(echo "$before") <(ls "$XDG_RUNTIME_DIR/hypr") | head -1)
WL=$(comm -13 <(echo "$sockets") <(ls "$XDG_RUNTIME_DIR" | grep -E '^wayland-[0-9]+$') | head -1)
[ -n "$SIG" ] && [ -n "$WL" ] || { echo "nested Hyprland did not start (see $W/nested.log)"; exit 1; }

export HOME=$H XDG_CONFIG_HOME=$H/.config XDG_CACHE_HOME=$H/.cache XDG_DATA_HOME=$H/.local/share XDG_STATE_HOME=$H/.local/state
export HYPRLAND_INSTANCE_SIGNATURE=$SIG WAYLAND_DISPLAY=$WL QT_QPA_PLATFORM=wayland
cleanup() { hyprctl eval 'hl.dispatch(hl.dsp.exit())' >/dev/null 2>&1 || true; }
trap cleanup EXIT

hyprctl output create headless SHOT >/dev/null; nap 1.5
hyprctl eval 'hl.monitor({ output = "WAYLAND-1", disabled = true })' >/dev/null; nap 1

Q="quickshell ipc -p $H/.config/quickshell"
# Closing windows can kill the nested shell with a Wayland "invalid object"
# error, so (re)start it whenever it is gone.
ensure_shell() {
    $Q show >/dev/null 2>&1 && return
    setsid quickshell -p "$H/.config/quickshell" >> "$W/qs.log" 2>&1 < /dev/null &
    nap 7
}
set_look() {  # theme wallpaper
    ensure_shell
    $Q call wallpaper set "$WALLS/$2"; nap 4
    $Q call desktopTheme set "$1"; nap 7
}
grab() { grim -o SHOT "$W/shots/$1.png"; }
close_all() {
    for a in $(hyprctl -j clients | python3 -c 'import json,sys; print(" ".join(c["address"] for c in json.load(sys.stdin)))'); do
        hyprctl eval "hl.dispatch(hl.dsp.window.close({ window = \"address:$a\" }))" >/dev/null; nap 0.7
    done
    nap 1
}
wall_of() { echo "$THEMES" | awk -v t="$1" '$1 == t { print $2 }'; }

# ---- shots -----------------------------------------------------------------
echo "$THEMES" | while read -r t w; do
    [ -n "$t" ] || continue
    set_look "$t" "$w"; grab "theme-$t"
done

FF="fastfetch --logo arch_small --structure Title:Separator:OS:Kernel:Uptime:Packages:WM:CPU:Memory:Break:Colors; exec sleep 1000"
for t in cyberpunk terminal wabisabi; do
    set_look "$t" "$(wall_of "$t")"
    (cd "$H" && setsid kitty sh -c "$FF" >/dev/null 2>&1 < /dev/null &); nap 2
    (cd "$H" && setsid kitty -e cava >/dev/null 2>&1 < /dev/null &); nap 2
    (cd "$H" && setsid kitty -e tty-clock -c -C 5 >/dev/null 2>&1 < /dev/null &); nap 4
    grab "work-$t"; close_all
done

panel() {  # out theme open-target open-fn [close-target close-fn]
    set_look "$2" "$(wall_of "$2")"
    $Q call "$3" "$4"; nap 3; grab "panel-$1"
    $Q call "${5:-$3}" "${6:-$4}"; nap 1.5
}
panel launcher hud launcherWindow toggle
panel control gothic controlCenter changeVisible
panel themes artdeco themes desktop themes toggle
panel lock xianxia themes lockscreen themes toggle
panel pet cosmos pet open pet close

# ---- publish ---------------------------------------------------------------
mkdir -p "$OUT"
for f in "$W"/shots/*.png; do
    magick "$f" -quality 90 "$OUT/$(basename "${f%.png}").jpg"
done
echo "Wrote $(ls "$W"/shots/*.png | wc -l) screenshots to $OUT (work dir: $W)"
