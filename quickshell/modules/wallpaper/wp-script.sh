#!/usr/bin/env bash

# CONFIG
QML_PATH="$HOME/.config/quickshell/modules/wallpaper/Wallpaper.qml"
SRC_DIR="$HOME/Pictures/wallpapers"

# 1. Kill if running
if pgrep -f "quickshell.*Wallpaper.qml" > /dev/null; then
    pkill -f "quickshell.*Wallpaper.qml"
    exit 0
fi

# 2. Detect Active Wallpaper & Calculate Index
TARGET_INDEX=0
CURRENT_SRC=""

# The wallpaper on screen (Quickshell keeps this link pointed at it)
CURRENT_SRC=$(basename "$(readlink -f "$HOME/.cache/current_wallpaper" 2>/dev/null)")

if [ -n "$CURRENT_SRC" ]; then
    # Find index in the source directory (sorted alphabetically)
    MATCH_LINE=$(ls -1 "$SRC_DIR" | grep -nF "$CURRENT_SRC" | cut -d: -f1)
    
    if [ -n "$MATCH_LINE" ]; then
        TARGET_INDEX=$((MATCH_LINE - 1))
    fi
fi

export WALLPAPER_INDEX="$TARGET_INDEX"

# 3. Launch Quickshell
quickshell -p "$QML_PATH" &

# 4. FORCE FOCUS
sleep 0.2
hyprctl dispatch focuswindow "quickshell"