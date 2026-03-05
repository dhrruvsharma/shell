#!/usr/bin/env bash

STEP=5

# Kill previous OSD so it refreshes
pkill -f "rofi.*Volume" 2>/dev/null

case "$1" in
  up)
    wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ ${STEP}%+
    ;;
  down)
    wpctl set-volume @DEFAULT_AUDIO_SINK@ ${STEP}%-
    ;;
  mute)
    wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    ;;
esac

VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}')
MUTE=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q MUTED && echo 1 || echo 0)

BAR_LEN=20
FILLED=$((VOL * BAR_LEN / 100))
EMPTY=$((BAR_LEN - FILLED))

ICON=$([ "$MUTE" = "1" ] && echo "󰝟" || echo "󰕾")
BAR=$(printf "%0.s█" $(seq 1 $FILLED))$(printf "%0.s░" $(seq 1 $EMPTY))

printf "%s  %s%%  %s\n" "$ICON" "$VOL" "$BAR" | \
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
