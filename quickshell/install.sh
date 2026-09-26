#!/usr/bin/env bash
# Installer for this Quickshell config (Arch Linux + Hyprland).
#
#   ./install.sh                 install packages, link config, set up helpers
#   ./install.sh --copy          copy the config instead of symlinking it
#   ./install.sh --no-deps       skip package installation
#   ./install.sh --extras        also install optional tools (ollama, gh)
#                                and the Python venvs for anime/manga/novel
#   ./install.sh --yes           don't prompt for confirmation
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
TARGET="$CONFIG_HOME/quickshell"
BIN_DIR="$HOME/.local/bin"

MODE=link
DEPS=1
EXTRAS=0
ASSUME_YES=0

PACMAN_PKGS=(
    hyprland qt6-5compat qt6-imageformats
    pipewire wireplumber libpulse networkmanager bluez bluez-utils
    brightnessctl playerctl cava cliphist wl-clipboard grim slurp wf-recorder
    matugen awww libnotify pacman-contrib jq curl lm_sensors python mpv kitty
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-nerd-fonts-symbols
    noto-fonts noto-fonts-emoji
)
AUR_PKGS=(ttf-material-symbols-variable-git)
EXTRA_PKGS=(ollama github-cli)

# venv path : pip packages (paths are hardcoded in services/{Anime,Manga,Novel}.qml)
VENVS=(
    "$HOME/ani-env:flask requests"
    "$HOME/.venv/manga:curl_cffi requests"
    "$HOME/novel-env:requests beautifulsoup4"
)

info() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

confirm() {
    ((ASSUME_YES)) && return 0
    read -rp "$1 [y/N] " reply
    [[ $reply =~ ^[Yy]$ ]]
}

usage() { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

while (($#)); do
    case $1 in
        --copy)    MODE=copy ;;
        --no-deps) DEPS=0 ;;
        --extras)  EXTRAS=1 ;;
        -y|--yes)  ASSUME_YES=1 ;;
        -h|--help) usage ;;
        *) die "unknown option: $1" ;;
    esac
    shift
done

[[ $EUID -eq 0 ]] && die "run as your normal user, not root"

install_packages() {
    command -v pacman >/dev/null || die "pacman not found; this installer targets Arch Linux"

    local pkgs=("${PACMAN_PKGS[@]}")
    ((EXTRAS)) && pkgs+=("${EXTRA_PKGS[@]}")
    # quickshell and quickshell-git conflict; keep whichever is already installed
    command -v qs >/dev/null || pkgs+=(quickshell)

    info "Installing repo packages"
    sudo pacman -S --needed "${pkgs[@]}"

    local aur
    aur=$(command -v paru || command -v yay || true)
    if [[ -n $aur ]]; then
        info "Installing AUR packages with $(basename "$aur")"
        "$aur" -S --needed "${AUR_PKGS[@]}"
    else
        warn "no AUR helper (paru/yay) found; install manually: ${AUR_PKGS[*]}"
    fi
}

install_config() {
    if [[ $SRC_DIR == "$(realpath -m "$TARGET")" ]]; then
        info "Config already lives at $TARGET"
        return
    fi

    if [[ -e $TARGET || -L $TARGET ]]; then
        local backup
        backup="$TARGET.bak-$(date +%Y%m%d-%H%M%S)"
        info "Backing up existing $TARGET -> $backup"
        mv "$TARGET" "$backup"
    fi

    mkdir -p "$CONFIG_HOME"
    if [[ $MODE == link ]]; then
        info "Symlinking $SRC_DIR -> $TARGET"
        ln -s "$SRC_DIR" "$TARGET"
    else
        info "Copying $SRC_DIR -> $TARGET"
        cp -a "$SRC_DIR" "$TARGET"
    fi
}

install_helpers() {
    info "Creating data directories"
    mkdir -p "$HOME/Pictures/wallpapers" "$HOME/Pictures/avatars" \
        "$HOME/Pictures/Screenshots" "$HOME/Videos/recordings" \
        "$HOME/.cache/quickshell" "$HOME/.local/share/quickshell" "$BIN_DIR"

    info "Linking setwall -> $BIN_DIR/setwall"
    ln -sf "$TARGET/scripts/setwall" "$BIN_DIR/setwall"
    [[ :$PATH: == *":$BIN_DIR:"* ]] || warn "$BIN_DIR is not on your PATH"

    local mg_dir="$CONFIG_HOME/matugen"
    local mg_conf="$mg_dir/config.toml"
    mkdir -p "$mg_dir/templates"
    if [[ ! -e $mg_dir/templates/quickshell.json.hbs ]]; then
        info "Installing matugen template"
        cp "$TARGET/scripts/matugen/quickshell.json.hbs" "$mg_dir/templates/"
    fi
    if ! grep -qs '^\[templates\.quickshell\]' "$mg_conf"; then
        info "Registering quickshell template in $mg_conf"
        cat >>"$mg_conf" <<'EOF'

[templates.quickshell]
input_path  = "~/.config/matugen/templates/quickshell.json.hbs"
output_path = "~/.config/quickshell/colors/Colors.json"
EOF
    fi
}

install_ipc_commands() {
    info "Collecting IPC commands for the notes drawer"
    python3 "$TARGET/scripts/gen-ipc-commands.py"
}

install_venvs() {
    local entry dir pkgs
    for entry in "${VENVS[@]}"; do
        dir=${entry%%:*}
        pkgs=${entry#*:}
        info "Setting up venv $dir ($pkgs)"
        [[ -x $dir/bin/python3 ]] || python3 -m venv "$dir"
        # shellcheck disable=SC2086
        "$dir/bin/pip" install --quiet --upgrade $pkgs
    done
}

cat <<EOF
Quickshell config installer
  source:  $SRC_DIR
  target:  $TARGET ($MODE)
  packages: $( ((DEPS)) && echo yes || echo skipped )
  extras:   $( ((EXTRAS)) && echo yes || echo no )
EOF
confirm "Proceed?" || exit 1

((DEPS)) && install_packages
install_config
install_helpers
install_ipc_commands
((EXTRAS)) && install_venvs

cat <<EOF

Done. Next steps:
  1. Autostart the shell and clipboard history from Hyprland:
       exec-once = wl-paste --watch cliphist store
       exec-once = qs
  2. Bind the panels you want, e.g.:
       bind = SUPER, P, exec, qs ipc call powerMenu toggle
       bind = ALT, H, exec, quickshell -p ~/.config/quickshell/Lock.qml
  3. Put a wallpaper in ~/Pictures/wallpapers and run: setwall <file>
     This sets the wallpaper and generates colours with matugen.
  4. After adding IPC handlers or Hyprland binds, refresh the notes drawer's
     "IPC Toggle" list with: ~/.config/quickshell/scripts/gen-ipc-commands.py
EOF
