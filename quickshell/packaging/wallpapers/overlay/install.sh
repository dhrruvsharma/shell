#!/usr/bin/env bash
# Installer for the Quickshell wallpaper picker.
#
#   ./install.sh            install the system packages and font it needs, put this
#                           folder at ~/.config/qs-wallpaperpicker and the
#                           qs-wallpaperpicker command in ~/.local/bin
#   ./install.sh --no-deps  skip the system packages and font
#   ./install.sh --copy     copy the folder instead of symlinking it
#   ./install.sh --yes      don't ask before installing
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/install-common.sh
source "$SRC_DIR/scripts/install-common.sh"

PACMAN_PKGS=(quickshell matugen ffmpeg curl python qt6-multimedia qt6-multimedia-ffmpeg qt6-imageformats)
APT_PKGS=(ffmpeg curl python3)
DNF_PKGS=(ffmpeg-free curl python3)
MANUAL=(
    "quickshell (with Qt 6 Multimedia for videos): see https://quickshell.org"
    "matugen: cargo install matugen, or a release from https://github.com/InioX/matugen"
)

MODE=link
DEPS=1
ASSUME_YES=0

while (($#)); do
    case $1 in
        --copy)    MODE=copy ;;
        --no-deps) DEPS=0 ;;
        -y|--yes)  ASSUME_YES=1 ;;
        -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown option: $1" ;;
    esac
    shift
done

[[ $EUID -eq 0 ]] && die "run as your normal user, not root"

if ((DEPS)); then
    install_system_packages
    install_font "Material Symbols Rounded" \
        "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" \
        "MaterialSymbolsRounded.ttf"
fi

command -v quickshell >/dev/null || warn "quickshell is still missing"
command -v matugen >/dev/null || warn "matugen is still missing: cards won't show colour schemes, and setting a wallpaper won't recolour anything"
command -v ffmpeg >/dev/null || warn "ffmpeg is still missing: video wallpapers will have no still for their card"

install_config qs-wallpaperpicker
install_command qs-wallpaperpicker
mkdir -p "$HOME/Pictures/wallpapers"

cat <<MSG

Done. Start it with

    qs-wallpaperpicker

(put that in your autostart) and bind a key to

    qs-wallpaperpicker toggle

It draws the wallpaper itself unless you give it a wallpaper command (for
swww, swaybg, …) in the picker's settings, the gear at the top right. Put
wallpapers in ~/Pictures/wallpapers, or pick another folder there too.
See README.md for more.
MSG
