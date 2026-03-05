#!/usr/bin/env bash

KAOMOJI_FILE="$HOME/.config/rofi/kaomoji.txt"

choice=$(rofi -dmenu -i -p "Kaomoji" < "$KAOMOJI_FILE")

[ -z "$choice" ] && exit 0

kaomoji=$(echo "$choice" | sed 's/  .*//')

echo -n "$kaomoji" | wl-copy
