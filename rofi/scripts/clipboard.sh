#!/usr/bin/env bash

cliphist list \
  | rofi -dmenu -i -p "Clipboard" \
  | cliphist decode \
  | wl-copy
