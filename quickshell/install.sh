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
#   ./install.sh --update        pull the latest changes and redo the setup steps
#                                they need, keeping your settings (combines with
#                                --no-deps, --no-hypr, --extras, --yes)
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
UPDATE=0
FINISH_FROM=
ORIG_ARGS=("$@")

PACMAN_PKGS=(
    hyprland qt6-5compat qt6-imageformats qt6-multimedia qt6-multimedia-ffmpeg
    pipewire wireplumber libpulse networkmanager bluez bluez-utils
    brightnessctl playerctl cava cliphist wl-clipboard grim slurp wf-recorder hyprsunset power-profiles-daemon
    matugen libnotify pacman-contrib jq curl lm_sensors python python-gobject mpv kitty
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-nerd-fonts-symbols
    noto-fonts noto-fonts-emoji
)
AUR_PKGS=(ttf-material-symbols-variable-git)
EXTRA_PKGS=(ollama github-cli)

# Type for the Art Deco, Cathedral, Broadsheet, Wasteland, Observatory,
# Abyss, Devaloka and Siege desktop themes (Google Fonts, OFL/Apache),
# fetched into ~/.local/share/fonts when missing.
THEME_FONTS=(
    ofl/limelight/Limelight-Regular.ttf
    ofl/poiretone/PoiretOne-Regular.ttf
    "ofl/josefinsans/JosefinSans[wght].ttf"
    "ofl/josefinsans/JosefinSans-Italic[wght].ttf"
    ofl/unifrakturmaguntia/UnifrakturMaguntia-Book.ttf
    "ofl/grenzegotisch/GrenzeGotisch[wght].ttf"
    "ofl/cinzel/Cinzel[wght].ttf"
    "ofl/alegreya/Alegreya[wght].ttf"
    "ofl/alegreya/Alegreya-Italic[wght].ttf"
    "ofl/playfairdisplay/PlayfairDisplay[wght].ttf"
    "ofl/playfairdisplay/PlayfairDisplay-Italic[wght].ttf"
    ofl/oldstandardtt/OldStandard-{Regular,Bold,Italic}.ttf
    ofl/anton/Anton-Regular.ttf
    ofl/stardosstencil/StardosStencil-{Regular,Bold}.ttf
    "ofl/bigshouldersstencil/BigShouldersStencil[opsz,wght].ttf"
    ofl/barlowcondensed/BarlowCondensed-{Regular,Medium,SemiBold,Bold}.ttf
    ofl/barlowsemicondensed/BarlowSemiCondensed-{Regular,Medium,SemiBold,Bold,Italic}.ttf
    apache/specialelite/SpecialElite-Regular.ttf
    ofl/imfellenglish/IMFeEN{rm,it}28P.ttf
    ofl/imfellenglishsc/IMFeENsc28P.ttf
    "ofl/ebgaramond/EBGaramond[wght].ttf"
    "ofl/ebgaramond/EBGaramond-Italic[wght].ttf"
    ofl/marcellussc/MarcellusSC-Regular.ttf
    ofl/michroma/Michroma-Regular.ttf
    ofl/b612/B612-{Regular,Bold,Italic}.ttf
    ofl/b612mono/B612Mono-{Regular,Bold}.ttf
    "ofl/eczar/Eczar[wght].ttf"
    ofl/tirodevanagarisanskrit/TiroDevanagariSanskrit-{Regular,Italic}.ttf
    ofl/germaniaone/GermaniaOne-Regular.ttf
    "ofl/texturina/Texturina[opsz,wght].ttf"
    "ofl/texturina/Texturina-Italic[opsz,wght].ttf"
)

# venv path : pip packages (the paths are set in services/ReaderEnv.qml)
VENVS=(
    "$HOME/ani-env:flask requests"
    "$HOME/.venv/manga:curl_cffi requests"
    "$HOME/novel-env:curl_cffi requests"
)

info() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

confirm() {
    ((ASSUME_YES)) && return 0
    read -rp "$1 [y/N] " reply
    [[ $reply =~ ^[Yy]$ ]]
}

usage() { sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

while (($#)); do
    case $1 in
        --copy)    MODE=copy ;;
        --no-deps) DEPS=0 ;;
        --extras)  EXTRAS=1 ;;
        --no-hypr) HYPR=0 ;;
        --github)  GITHUB_USER=${2-}; shift ;;
        -y|--yes)  ASSUME_YES=1 ;;
        --update)  UPDATE=1 ;;
        # Internal: the updated script, run by the old one after pulling.
        --finish-update) FINISH_FROM=${2-}; shift ;;
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

install_theme_fonts() {
    local dir="$HOME/.local/share/fonts/quickshell-themes"
    local base=https://raw.githubusercontent.com/google/fonts/main
    local f name url fetched=0
    mkdir -p "$dir"
    for f in "${THEME_FONTS[@]}"; do
        name=${f##*/}
        [[ -s $dir/$name ]] && continue
        url=${f//\[/%5B}
        url=${url//\]/%5D}
        info "Fetching font $name"
        if curl -fsSL -o "$dir/$name" "$base/$url"; then
            fetched=1
        else
            rm -f "$dir/$name"
            warn "couldn't fetch $name; the desktop themes that use it fall back to other type"
        fi
    done
    ((fetched)) && fc-cache -f "$dir" >/dev/null
    return 0
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
        # The revision copied, so --update can tell your edits from ours.
        git -C "$SRC_DIR" rev-parse HEAD >"$TARGET/.installed-rev" 2>/dev/null || true
    fi
}

install_helpers() {
    info "Creating data directories"
    mkdir -p "$HOME/Pictures/wallpapers" "$HOME/Pictures/avatars" \
        "$HOME/Pictures/Screenshots" "$HOME/Videos/recordings" \
        "$HOME/.cache/quickshell" "$HOME/.local/share/quickshell" "$BIN_DIR"

    seed_state

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

# The shell's runtime state (bar layout, desktop theme, widgets, colours, …)
# isn't tracked: each install keeps its own, starting from defaults/.
seed_state() {
    local src rel
    while IFS= read -r -d '' src; do
        rel=${src#"$TARGET/defaults/"}
        [[ -e $TARGET/$rel ]] && continue
        info "Creating $rel from defaults/"
        mkdir -p "$(dirname "$TARGET/$rel")"
        cp "$src" "$TARGET/$rel"
    done < <(find "$TARGET/defaults" -type f -print0)
}

register_matugen_template() {
    local name=$1 input=$2 output=$3
    local mg_conf="$CONFIG_HOME/matugen/config.toml"
    # matugen 4 refuses a config without a [config] table ("missing field
    # `config`"), even for --dry-run, which leaves the picker's cards grey
    # and every wallpaper change uncoloured.
    if ! grep -qs '^\[config\]' "$mg_conf"; then
        info "Adding the [config] table matugen needs to $mg_conf"
        printf '\n[config]\n' >>"$mg_conf"
    fi
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
        warn "the dotfiles repo is missing its hypr/quickshell.lua template ($src);"
        warn "skipping Hyprland setup"
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

# ── Updating ─────────────────────────────────────────────────────────────────
#
# An update fast-forwards the checkout, keeping your local changes where the
# update doesn't touch them, then runs the *new* install.sh with
# --finish-update to redo whatever setup the new version needs. The shell's
# state files are gitignored now, but older checkouts still track them.

# Settings the shell writes at runtime: on an update, yours win.
is_settings_file() { [[ $1 == *.json || $1 == *.conf ]]; }

# Where the installed config lives relative to the checkout: "link" (it is the
# checkout), "copy" (a separate copy), or "none".
install_mode() {
    if [[ $(realpath -m "$TARGET") == "$SRC_DIR" ]]; then
        echo link
    elif [[ -d $TARGET && ! -L $TARGET ]]; then
        echo copy
    else
        echo none
    fi
}

# Fast-forwards the checkout to its upstream, keeping local changes to
# settings files. Prints the revision it started from.
pull_updates() {
    local repo
    repo=$(git -C "$SRC_DIR" rev-parse --show-toplevel 2>/dev/null) ||
        die "$SRC_DIR is not a git checkout; re-clone the repo to get updates"
    git -C "$repo" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1 ||
        die "the current branch has no upstream to update from (git branch -u origin/<branch>)"

    info "Fetching updates" >&2
    git -C "$repo" fetch --quiet || die "git fetch failed"

    local old new
    old=$(git -C "$repo" rev-parse HEAD)
    new=$(git -C "$repo" rev-parse '@{u}')
    if git -C "$repo" merge-base --is-ancestor "$new" "$old"; then
        echo "$old"
        return
    fi
    git -C "$repo" merge-base --is-ancestor "$old" "$new" ||
        die "your branch has commits of its own; merge or rebase onto $(git -C "$repo" rev-parse --abbrev-ref '@{u}') yourself"

    # Local edits: settings are set aside and put back; other files only
    # survive if the update doesn't touch them.
    local -a changed incoming blocked=()
    local f
    mapfile -t changed < <(git -C "$repo" diff --name-only HEAD)
    mapfile -t incoming < <(git -C "$repo" diff --name-only "$old" "$new")
    for f in "${changed[@]}"; do
        is_settings_file "$f" && continue
        # Already the updated version (e.g. install.sh checked out by hand).
        git -C "$repo" diff --quiet "$new" -- "$f" 2>/dev/null && continue
        printf '%s\n' "${incoming[@]}" | grep -qxF -- "$f" && blocked+=("$f")
    done
    if ((${#blocked[@]})); then
        warn "you've edited files this update also changes:"
        printf '     %s\n' "${blocked[@]}" >&2
        die "commit or stash them (git -C $repo stash), then run --update again"
    fi

    local saved
    saved=$(mktemp -d)
    for f in "${changed[@]}"; do
        if [[ -e $repo/$f ]]; then
            mkdir -p "$saved/$(dirname "$f")"
            cp -a "$repo/$f" "$saved/$f"
        fi
    done
    ((${#changed[@]})) && git -C "$repo" checkout --quiet HEAD -- "${changed[@]}"

    local merged=1
    git -C "$repo" merge --ff-only --quiet "$new" || merged=0

    # Put your versions back (also when the merge failed).
    for f in "${changed[@]}"; do
        if [[ -e $saved/$f ]]; then
            mkdir -p "$repo/$(dirname "$f")"
            cp -a "$saved/$f" "$repo/$f"
            # Worth a word only if it still differs from the update's version.
            if ((merged)) && ! git -C "$repo" diff --quiet HEAD -- "$f"; then
                warn "kept your $f (the update changed it too; compare: git -C $repo diff -- $f)"
            fi
        else
            rm -f "$repo/$f"
        fi
    done
    rm -rf "$saved"
    ((merged)) || die "couldn't fast-forward (see git's message above); nothing was changed"

    info "Updated $(git -C "$repo" rev-parse --short "$old") -> $(git -C "$repo" rev-parse --short "$new"):" >&2
    git -C "$repo" log --oneline --no-decorate "$old..$new" | head -n 15 | sed 's/^/     /' >&2
    echo "$old"
}

# Copy installs: brings the checkout's changes since `base` into $TARGET,
# leaving alone files you've changed there.
sync_copy() {
    local base=$1 status path dst
    while IFS=$'\t' read -r status path; do
        dst=$TARGET/$path
        # Yours if it differs from the version that was installed.
        if [[ -e $dst ]] && ! git -C "$SRC_DIR" cat-file blob "$base:./$path" 2>/dev/null | cmp -s - "$dst"; then
            if [[ $status == D ]] || is_settings_file "$path"; then
                warn "kept your $dst"
            else
                warn "kept your $dst; the new version is at $dst.new"
                cp -a "$SRC_DIR/$path" "$dst.new"
            fi
            continue
        fi
        if [[ $status == D ]]; then
            rm -f "$dst"
        else
            mkdir -p "$(dirname "$dst")"
            cp -a "$SRC_DIR/$path" "$dst"
        fi
    done < <(git -C "$SRC_DIR" diff --name-status --no-renames --relative "$base" HEAD -- .)
    git -C "$SRC_DIR" rev-parse HEAD >"$TARGET/.installed-rev"
}

# The second half of --update, run from the freshly pulled script.
finish_update() {
    local from=$1 mode
    mode=$(install_mode)
    [[ $mode == none ]] && die "no install found at $TARGET; run ./install.sh first"

    if [[ $mode == copy ]]; then
        local base=$from
        [[ -s $TARGET/.installed-rev ]] && base=$(<"$TARGET/.installed-rev")
        info "Updating the copy at $TARGET"
        sync_copy "$base"
    fi

    ((DEPS)) && install_packages
    ((DEPS)) && install_theme_fonts
    install_helpers
    if ((HYPR)) && ! git -C "$SRC_DIR" diff --quiet "$from" HEAD -- ../hypr/quickshell.lua; then
        info "hypr/quickshell.lua changed"
        install_hypr
    fi
    install_ipc_commands
    ((EXTRAS)) && install_venvs

    printf '\nUpdated. Quickshell reloads its config by itself; if anything looks off,\n'
    printf 'restart it with: qs kill; qs -d\n'
}

# One compound command, parsed whole before it runs: pulling rewrites this
# file, and bash would otherwise read on from the new one mid-way.
if [[ -n $FINISH_FROM ]]; then
    finish_update "$FINISH_FROM"
    exit
elif ((UPDATE)); then
    confirm "Update the Quickshell config in $SRC_DIR?" || exit 1
    from=$(pull_updates)
    if [[ $from == "$(git -C "$SRC_DIR" rev-parse HEAD)" ]]; then
        info "Already up to date"
        exit 0
    fi
    args=()
    for a in "${ORIG_ARGS[@]}"; do [[ $a == --update ]] || args+=("$a"); done
    exec "$SRC_DIR/install.sh" "${args[@]}" --finish-update "$from"
fi

cat <<EOF
Quickshell config installer
  source:  $SRC_DIR
  target:  $TARGET ($MODE)
  packages: $( ((DEPS)) && echo yes || echo skipped )
  extras:   $( ((EXTRAS)) && echo yes || echo no )
EOF
confirm "Proceed?" || exit 1

((DEPS)) && install_packages
((DEPS)) && install_theme_fonts
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
