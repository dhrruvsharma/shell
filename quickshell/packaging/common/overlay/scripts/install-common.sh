#!/usr/bin/env bash
# Shared by the package's install.sh (sourced, not run): messages, system
# packages through the distro's package manager, fonts, and putting the
# config in ~/.config/<name> and its command on PATH (~/.local/bin, or
# /usr/local/bin when ~/.local/bin isn't on PATH).
#
# install.sh sets, before calling these:
#   ASSUME_YES     1 to skip the prompts
#   PACMAN_PKGS    Arch packages     APT_PKGS   Debian/Ubuntu packages
#   DNF_PKGS       Fedora packages   MANUAL     lines saying what to get by hand
#                                               where a distro has no package
# (INSTALL_PM and SYSTEM_BIN override the package manager and /usr/local/bin,
# for testing.)

info() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

confirm() {
    ((ASSUME_YES)) && return 0
    local reply
    read -rp "$1 [Y/n] " reply
    [[ -z $reply || $reply =~ ^[Yy] ]]
}

# pacman, apt-get or dnf, whichever is here first (INSTALL_PM overrides).
package_manager() {
    local pm
    if [[ -n ${INSTALL_PM-} ]]; then
        echo "$INSTALL_PM"
        return
    fi
    for pm in pacman apt-get dnf; do
        command -v "$pm" >/dev/null && { echo "$pm"; return; }
    done
}

# Installs the system packages this package needs, with whichever of
# pacman, apt or dnf is there. Quickshell is left alone when some build of
# it is already installed (quickshell and quickshell-git conflict on Arch).
install_system_packages() {
    local pm pkgs=() p failed=()
    pm=$(package_manager)
    case $pm in
        pacman)  pkgs=("${PACMAN_PKGS[@]}") ;;
        apt-get) pkgs=("${APT_PKGS[@]}") ;;
        dnf)     pkgs=("${DNF_PKGS[@]}") ;;
    esac
    if command -v qs >/dev/null || command -v quickshell >/dev/null; then
        for p in "${!pkgs[@]}"; do
            [[ ${pkgs[p]} == quickshell ]] && unset 'pkgs[p]'
        done
        pkgs=("${pkgs[@]}")
    fi

    if [[ -z $pm ]]; then
        warn "no pacman, apt or dnf here; install these yourself:"
        printf '     %s\n' "${PACMAN_PKGS[@]}" >&2
        return
    fi

    if ((${#pkgs[@]})); then
        info "Installing packages with $pm: ${pkgs[*]}"
        case $pm in
            pacman)
                local flags=(-S --needed)
                ((ASSUME_YES)) && flags+=(--noconfirm)
                sudo pacman "${flags[@]}" "${pkgs[@]}" || failed=("${pkgs[@]}")
                ;;
            apt-get | dnf)
                # One at a time, so a package this release doesn't have
                # doesn't stop the rest.
                if confirm "Install them?"; then
                    [[ $pm == apt-get ]] && sudo apt-get update -qq
                    for p in "${pkgs[@]}"; do
                        sudo "$pm" install -y -q "$p" >/dev/null || failed+=("$p")
                    done
                else
                    failed=("${pkgs[@]}")
                fi
                ;;
        esac
        ((${#failed[@]})) && warn "not installed: ${failed[*]}"
    fi

    # What this distro doesn't package, unless it's installed already (each
    # line starts with the command's name).
    local line todo=()
    if [[ $pm != pacman ]]; then
        for line in "${MANUAL[@]}"; do
            command -v "${line%%[ :]*}" >/dev/null || todo+=("$line")
        done
    fi
    if ((${#todo[@]})); then
        warn "get these yourself (not in $pm's repos):"
        printf '     %s\n' "${todo[@]}" >&2
    fi
}

fonts_dir() { echo "${XDG_DATA_HOME:-$HOME/.local/share}/fonts"; }

has_font() { fc-list : family 2>/dev/null | grep -qi -- "$1"; }

# A font file from a URL into the user's fonts, unless a font of that
# family is installed already.
install_font() {  # family url file
    local family=$1 url=$2 file=$3 dir
    has_font "$family" && return
    dir=$(fonts_dir)
    info "Downloading the $family font"
    mkdir -p "$dir"
    if curl -fsSL "$url" -o "$dir/$file.part"; then
        mv "$dir/$file.part" "$dir/$file"
        fc-cache -f "$dir" >/dev/null 2>&1 || true
    else
        rm -f "$dir/$file.part"
        warn "couldn't download $family; icons will show as boxes until it's installed"
    fi
}

# Nerd Fonts' symbols-only font (icon glyphs), unless some Nerd Font is there.
install_nerd_symbols() {
    local dir tmp
    has_font "Nerd Font" && return
    dir=$(fonts_dir)
    tmp=$(mktemp -d)
    info "Downloading the Symbols Nerd Font"
    if curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.tar.xz -o "$tmp/f.tar.xz" \
        && tar -xJf "$tmp/f.tar.xz" -C "$tmp"; then
        mkdir -p "$dir"
        cp "$tmp"/*.ttf "$dir/"
        fc-cache -f "$dir" >/dev/null 2>&1 || true
    else
        warn "couldn't download the Symbols Nerd Font; icons will show as boxes until a Nerd Font is installed"
    fi
    rm -rf "$tmp"
}

# This folder as ~/.config/$1, which `qs -p` runs: a symlink to it, or a
# copy with MODE=copy (an earlier copy is updated, keeping its settings and
# colours).
# Anything else already there is left alone, and the install stops.
install_config() {  # name
    local target="${XDG_CONFIG_HOME:-$HOME/.config}/$1"
    # Cloned right there, or linked by an earlier install.
    [[ $SRC_DIR -ef $target ]] && return
    if [[ -L $target ]]; then
        [[ ! -e $target || -e $target/.package-export ]] \
            || die "$target is a link to something else; move it away, then run this again"
        rm "$target"
    elif [[ -e $target ]]; then
        [[ -e $target/.package-export ]] \
            || die "$target already exists and isn't $1; move it away, then run this again"
        [[ $MODE == copy ]] \
            || die "$target is an earlier copy of $1; remove it, or run this again with --copy to update it"
        # Not the copy's own state: its settings and matugen palette.
        tar -C "$SRC_DIR" --exclude=./.git --exclude=./settings.json --exclude=./colors/Colors.json -cf - . \
            | tar -C "$target" -xf -
        info "Updated the copy in $target"
        return
    fi
    mkdir -p "$(dirname "$target")"
    if [[ $MODE == copy ]]; then
        mkdir -p "$target"
        tar -C "$SRC_DIR" --exclude=./.git -cf - . | tar -C "$target" -xf -
        info "Copied to $target"
    else
        ln -s "$SRC_DIR" "$target"
        info "Linked $target -> $SRC_DIR"
    fi
}

on_path() { [[ ":$PATH:" == *":$1:"* ]]; }

# Links the command into a folder: as is, or with "sudo" as $3. A different
# file of that name is left alone (ours say "Installed by <name>'s install.sh").
link_command() {  # source dest [sudo]
    local src=$1 dest=$2 name=${1##*/}
    if [[ -e $dest || -L $dest ]] && ! grep -q "Installed by $name's install.sh" "$dest" 2>/dev/null; then
        warn "$dest exists and isn't this package's; leaving it alone (use $src instead)"
        return 1
    fi
    ${3-} mkdir -p "$(dirname "$dest")" && ${3-} ln -sfn "$src" "$dest" || return 1
    info "Installed the $name command in $(dirname "$dest")"
}

# The line that puts ~/.local/bin on PATH for the user's shell.
path_hint() {
    case ${SHELL##*/} in
        fish) echo "fish_add_path ~/.local/bin" ;;
        zsh)  echo "echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc" ;;
        *)    echo "echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc" ;;
    esac
}

# The package's command (bin/$1), linked into the config so it stays
# current: in ~/.local/bin when that's on PATH. Otherwise in /usr/local/bin
# (with sudo, after asking), which every shell and compositor has on PATH,
# so it works at once, in keybinds too. Declined, it goes in ~/.local/bin
# with the line that puts that on PATH.
install_command() {  # name
    local name=$1
    local src="${XDG_CONFIG_HOME:-$HOME/.config}/$name/bin/$name"
    local bin="$HOME/.local/bin"
    if on_path "$bin"; then
        link_command "$src" "$bin/$name" || true
        return
    fi
    local sys=${SYSTEM_BIN:-/usr/local/bin}
    if on_path "$sys" \
        && confirm "$bin isn't on your PATH. Put the $name command in $sys instead (needs sudo)?" \
        && link_command "$src" "$sys/$name" sudo; then
        return
    fi
    link_command "$src" "$bin/$name" || return 0
    warn "$bin isn't on your PATH, so '$name' won't be found. Add it with"
    printf '     %s\n' "$(path_hint)" >&2
    warn "then open a new terminal (and use $bin/$name in compositor keybinds, or log in again)."
}
