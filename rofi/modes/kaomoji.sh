#!/usr/bin/env bash

FILE="$HOME/.config/rofi/kaomoji.txt"

if [ -z "$ROFI_INFO" ]; then
    # First call: print entries
    cat "$FILE"
else
    # Second call: user selected something
    echo "$ROFI_INFO" | sed 's/  .*//' | wl-copy
fi
