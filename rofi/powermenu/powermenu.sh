#!/usr/bin/env bash

chosen=$(printf "󰤆  Lock\n󰍃  Logout\n󰑐  Suspend\n󰜉  Reboot\n󰐥  Shutdown" | \
  rofi -dmenu \
    -p "" \
    -theme ~/.config/rofi/powermenu/powermenu.rasi)

case "$chosen" in
  *Lock)      hyprlock ;;
  *Logout)    hyprctl dispatch exit ;;
  *Suspend)   systemctl suspend ;;
  *Reboot)    systemctl reboot ;;
  *Shutdown)  systemctl poweroff ;;
esac
