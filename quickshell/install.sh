#!/usr/bin/env bash
# Installer for this Quickshell config (Arch Linux + Hyprland).
#
#   ./install.sh                 install packages, link config, set up helpers
#   ./install.sh --copy          copy the config instead of symlinking it
#   ./install.sh --no-deps       skip package installation
#   ./install.sh --extras        also install optional tools (ollama, gh)
#                                and the Python venvs for anime/manga/novel
#   ./install.sh --no-hypr       don't add the Quickshell keybinds/blur/animations/scale
#                                to ~/.config/hypr
#   ./install.sh --github USER   GitHub username for the contributions widget
#                                (asked interactively otherwise; blank disables it)
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
HYPR=1
GITHUB_USER=

PACMAN_PKGS=(
    hyprland qt6-5compat qt6-imageformats
    pipewire wireplumber libpulse networkmanager bluez bluez-utils
    brightnessctl playerctl cava cliphist wl-clipboard grim slurp wf-recorder
    matugen libnotify pacman-contrib jq curl lm_sensors python mpv kitty
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

usage() { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

while (($#)); do
    case $1 in
        --copy)    MODE=copy ;;
        --no-deps) DEPS=0 ;;
        --extras)  EXTRAS=1 ;;
        --no-hypr) HYPR=0 ;;
        --github)  GITHUB_USER=${2-}; shift ;;
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
    mkdir -p "$mg_dir/templates"
    if [[ ! -e $mg_dir/templates/quickshell.json.hbs ]]; then
        info "Installing matugen template"
        cp "$TARGET/scripts/matugen/quickshell.json.hbs" "$mg_dir/templates/"
    fi
    register_matugen_template quickshell \
        "~/.config/matugen/templates/quickshell.json.hbs" "~/.config/quickshell/colors/Colors.json"
}

register_matugen_template() {
    local name=$1 input=$2 output=$3
    local mg_conf="$CONFIG_HOME/matugen/config.toml"
    grep -qs "^\[templates\.$name\]" "$mg_conf" && return
    info "Registering matugen template $name"
    printf '\n[templates.%s]\ninput_path  = "%s"\noutput_path = "%s"\n' \
        "$name" "$input" "$output" >>"$mg_conf"
}

# hypr/quickshell.lua (next to quickshell/ in the dotfiles repo) holds only what
# the shell needs: keybinds, blur, animations and scale. It is added to the
# user's own hyprland.lua with require("quickshell"); nothing else is touched.
install_hypr() {
    local src dst="$CONFIG_HOME/hypr"
    src=$(realpath -m "$SRC_DIR/../hypr/quickshell.lua")
    if [[ ! -f $src ]]; then
        warn "no hypr/quickshell.lua next to $SRC_DIR; skipping Hyprland setup"
        return
    fi
    if [[ $src == "$(realpath -m "$dst/quickshell.lua")" ]]; then
        info "Hyprland already uses $src"
        return
    fi
    if [[ ! -f $dst/hyprland.lua ]]; then
        # Creating hyprland.lua would make Hyprland ignore an existing hyprland.conf
        warn "no $dst/hyprland.lua found; add the keybinds, blur, animations and scale"
        warn "from $src to your Hyprland config yourself"
        return
    fi
    confirm "Add Quickshell keybinds, blur, animations and scale to $dst/hyprland.lua?" || return 0

    if [[ -f $dst/quickshell.lua ]] && ! cmp -s "$src" "$dst/quickshell.lua"; then
        local backup
        backup="$dst/quickshell.lua.bak-$(date +%Y%m%d-%H%M%S)"
        info "Backing up existing $dst/quickshell.lua -> $backup"
        mv "$dst/quickshell.lua" "$backup"
    fi
    info "Copying quickshell.lua -> $dst"
    cp "$src" "$dst/"
    if ! grep -qs 'require("quickshell")' "$dst/hyprland.lua"; then
        info "Adding require(\"quickshell\") to $dst/hyprland.lua"
        printf '\n-- Quickshell keybinds, blur, animations and scale\nrequire("quickshell")\n' >>"$dst/hyprland.lua"
    fi

    if command -v Hyprland >/dev/null; then
        Hyprland --verify-config -c "$dst/hyprland.lua" 2>&1 | grep -q '^config ok' ||
            warn "Hyprland reports errors; check with: Hyprland --verify-config -c $dst/hyprland.lua"
    fi
    grep -qsE '"qs"' "$dst/hyprland.lua" ||
        warn "$dst/hyprland.lua doesn't seem to autostart the shell; see the next steps below"
}

install_ipc_commands() {
    info "Collecting IPC commands for the notes drawer"
    python3 "$TARGET/scripts/gen-ipc-commands.py"
}

configure_github() {
    local file="$HOME/.local/share/quickshell/github.json"
    local user=$GITHUB_USER

    if [[ -z $user && -e $file ]]; then
        info "GitHub widget already configured in $file"
        return
    fi
    if [[ -z $user ]] && ! ((ASSUME_YES)); then
        read -rp "GitHub username for the contributions widget (blank to disable): " user
    fi
    [[ -z $user || $user =~ ^[A-Za-z0-9-]+$ ]] || die "invalid GitHub username: $user"

    info "GitHub widget: ${user:-disabled}"
    printf '{\n    "username": "%s"\n}\n' "$user" >"$file"
}

check_scale() {
    command -v hyprctl >/dev/null && command -v jq >/dev/null || return 0
    local scaled
    scaled=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.scale != 1) | "\(.name) (\(.scale)x)"') || return 0
    [[ -z $scaled ]] && return
    warn "monitor scale is not 1 on: $scaled"
    warn "panels are sized for scale 1 and will look larger; set it in your Hyprland monitor rule, e.g."
    warn "  monitor = , preferred, auto, 1"
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
((HYPR)) && install_hypr
install_ipc_commands
configure_github
((EXTRAS)) && install_venvs
check_scale

cat <<EOF

Done. Next steps:
  1. Make sure your Hyprland config autostarts the shell and clipboard history,
     e.g. inside hl.on("hyprland.start", function() ... end):
       hl.exec_cmd("wl-paste --watch cliphist store")
       hl.exec_cmd("qs")
     then log into Hyprland (or run: hyprctl reload).
  2. Quickshell keybinds, blur, animations and scale live in
     ~/.config/hypr/quickshell.lua.
  3. Put a wallpaper in ~/Pictures/wallpapers and run: setwall <file>
     This sets the wallpaper and generates colours with matugen.
  4. After adding IPC handlers or Hyprland binds, refresh the notes drawer's
     "IPC Toggle" list with: ~/.config/quickshell/scripts/gen-ipc-commands.py
  5. Change the GitHub widget's user later with:
       qs ipc call github setUser <name>     (empty string disables it)
EOF
