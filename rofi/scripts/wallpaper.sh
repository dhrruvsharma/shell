#!/usr/bin/bash

WALLPAPER_DIR="$HOME/Pictures/wallpapers/"
IMAGE_PICKER_CONFIG="$HOME/.config/rofi/image-picker.rasi"
WALLPAPER_FILES=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \))
CURRENT_WALLPAPER_FILE=$(basename "$(swww query | awk '{print $NF}')")
ROFI_MENU=""

while IFS= read -r WALLPAPER_PATH; do
  WALLPAPER_NAME=$(basename "$WALLPAPER_PATH")
  if [[ "$WALLPAPER_NAME" == "$CURRENT_WALLPAPER_FILE" ]]; then
    ROFI_MENU+="${WALLPAPER_NAME} (current)\0icon\x1f${WALLPAPER_PATH}\n"
  else
    ROFI_MENU+="${WALLPAPER_NAME}\0icon\x1f${WALLPAPER_PATH}\n"
  fi
done <<<"$WALLPAPER_FILES"

SELECTED_WALLPAPER=$(echo -e "$ROFI_MENU" | rofi -dmenu \
  -p "Select Wallpaper:" \
  -theme "$IMAGE_PICKER_CONFIG" \
  -markup-rows)

SELECTED_WALLPAPER_NAME=$(echo "$SELECTED_WALLPAPER" | sed 's/ (current)//')

if [[ -n "$SELECTED_WALLPAPER_NAME" ]]; then
  "$HOME/.local/bin/setwall" "$WALLPAPER_DIR/$SELECTED_WALLPAPER_NAME" --transition-type any --transition-duration 1
fi