#!/usr/bin/env bash
# Installer for the Quickshell readers (anime player, manga reader, novel reader).
#
#   ./install.sh            install the system packages and fonts they need, put
#                           this folder at ~/.config/qs-novelmangareader and the
#                           qs-novelmangareader command in ~/.local/bin, and set
#                           up the Python venv for the backends
#   ./install.sh --no-deps  skip the system packages and fonts
#   ./install.sh --no-venv  skip the Python venv
#   ./install.sh --copy     copy the folder instead of symlinking it
#   ./install.sh --yes      don't ask before installing
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/install-common.sh
source "$SRC_DIR/scripts/install-common.sh"

VENV="${XDG_DATA_HOME:-$HOME/.local/share}/qs-novelmangareader/venv"
PIP_PKGS=(flask requests curl_cffi)

PACMAN_PKGS=(quickshell python mpv noto-fonts curl)
APT_PKGS=(python3 python3-venv mpv fonts-noto-core curl)
DNF_PKGS=(python3 mpv google-noto-sans-fonts curl)
MANUAL=("quickshell: see https://quickshell.org for packages and building it")

MODE=link
DEPS=1
VENV_SETUP=1
ASSUME_YES=0

while (($#)); do
    case $1 in
        --copy)    MODE=copy ;;
        --no-deps) DEPS=0 ;;
        --no-venv) VENV_SETUP=0 ;;
        -y|--yes)  ASSUME_YES=1 ;;
        -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) die "unknown option: $1" ;;
    esac
    shift
done

[[ $EUID -eq 0 ]] && die "run as your normal user, not root"

if ((DEPS)); then
    install_system_packages
    install_nerd_symbols
fi

for cmd in quickshell python3 mpv; do
    command -v "$cmd" >/dev/null || warn "$cmd is still missing"
done

install_config qs-novelmangareader
install_command qs-novelmangareader

if ((VENV_SETUP)); then
    info "Setting up the backend venv in $VENV"
    [[ -x $VENV/bin/python3 ]] || python3 -m venv "$VENV"
    "$VENV/bin/pip" install --quiet --upgrade "${PIP_PKGS[@]}"
fi

cat <<MSG

Done. Start it with

    qs-novelmangareader

(put that in your autostart) and bind keys to

    qs-novelmangareader anime
    qs-novelmangareader manga
    qs-novelmangareader novel

See README.md for compositor examples and matugen colours.
MSG
