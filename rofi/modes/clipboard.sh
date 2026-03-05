#!/usr/bin/env bash

if [ -z "$ROFI_INFO" ]; then
    cliphist list
else
    echo "$ROFI_INFO" | cliphist decode | wl-copy
fi
