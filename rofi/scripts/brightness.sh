#!/usr/bin/env bash

STEP=5

pkill -f "rofi.*Brightness" 2>/dev/null

case "$1" in
  up)
    brightnessctl -e4 -n2 set ${STEP}%+
    ;;
  down)
    brightnessctl -e4 -n2 set ${STEP}%-
    ;;
esac

CUR=$(brightnessctl g)
MAX=$(brightnessctl m)
PERCENT=$((CUR * 100 / MAX))

BAR_LEN=20
FILLED=$((PERCENT * BAR_LEN / 100))
EMPTY=$((BAR_LEN - FILLED))

BAR=$(printf "%0.s█" $(seq 1 $FILLED))$(printf "%0.s░" $(seq 1 $EMPTY))

printf "󰃠  %s%%  %s\n" "$PERCENT" "$BAR" | \
rofi -dmenu \
  -p "" \
  -no-fixed-num-lines \
  -disable-history \
  -theme-str '
    window { width: 26%; }
    listview { lines: 1; }
    inputbar { enabled: false; }
  ' \
  -timeout 0.6
