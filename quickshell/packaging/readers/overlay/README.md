# qs-novelmangareader

An anime player, manga reader and novel reader for [Quickshell](https://quickshell.org),
taken out of [dhrruvsharma/shell](https://github.com/dhrruvsharma/shell) so they can run
without the rest of that rice. They open as side panels over your desktop:
manga and anime on the left, novels on the right.

- **Anime:** browse, search and keep a library; episodes play in `mpv`.
- **Manga:** browse, search, favourite, download and read chapters.
- **Novels:** browse, search, keep a library and read in the panel or full screen.

Each one runs a small local Python server (`scripts/`) that fetches from the
source sites. They start with the panel's service and only listen on
`127.0.0.1` (anime 5050, manga 5150, novels 5151).

> This folder is generated from the rice by `packaging/export.sh`.
> Report bugs and send changes to the rice repo, not here.

## Requirements

- A Wayland compositor with layer-shell (Hyprland, Sway, niri, river, …)
- `quickshell` (0.2 or newer), `python3`, `mpv`
- Fonts: Noto Sans and a Nerd Font (for the icons)

## Install

```sh
git clone <this repo> ~/.config/qs-novelmangareader
~/.config/qs-novelmangareader/install.sh
```

It lives in its own folder, `~/.config/qs-novelmangareader`, outside `~/.config/quickshell`,
so it runs next to your own Quickshell config (or none) without touching it.

`install.sh` does everything:

- installs what the readers need with your package manager: Quickshell, Python, mpv,
  Noto Sans and curl (pacman on Arch; apt on Debian/Ubuntu and dnf on Fedora, which
  don't package Quickshell, so it tells you where to get it)
- downloads the Symbols Nerd Font into `~/.local/share/fonts` if you have no Nerd Font
- links the folder to `~/.config/qs-novelmangareader` if you cloned it elsewhere
- puts the `qs-novelmangareader` command on your `PATH`: in `~/.local/bin` if that's on it, otherwise
  (after asking) in `/usr/local/bin`, so it works in every shell and in keybinds right away
- makes a venv with `flask`, `requests` and `curl_cffi` in
  `~/.local/share/qs-novelmangareader/venv` for the backends

Options: `--no-deps` (skip packages and fonts), `--no-venv`, `--copy` (copy the folder
instead of linking it), `--yes` (don't ask).

Start it at login with `qs-novelmangareader` (it sits quietly until you open a panel).

## Commands and keybinds

```sh
qs-novelmangareader           # start it
qs-novelmangareader anime     # open/close the anime player
qs-novelmangareader manga     # open/close the manga reader
qs-novelmangareader novel     # open/close the novel reader
qs-novelmangareader stop      # quit it
qs-novelmangareader log       # its log
```

Underneath that's `qs -p ~/.config/qs-novelmangareader …`, with IPC targets
`animePlayer`, `mangaReader` and `novelReader` (each has `toggle`).

Hyprland:

```ini
exec-once = qs-novelmangareader
bind = SUPER ALT, A, exec, qs-novelmangareader anime
bind = SUPER ALT, M, exec, qs-novelmangareader manga
bind = SUPER ALT, N, exec, qs-novelmangareader novel
```

Sway:

```
exec qs-novelmangareader
bindsym $mod+Alt+a exec qs-novelmangareader anime
bindsym $mod+Alt+m exec qs-novelmangareader manga
bindsym $mod+Alt+n exec qs-novelmangareader novel
```

The minimize button in a panel's header hides it but keeps your place; the
next toggle brings it back as you left it.

## Colours

The panels use a Material You palette from `colors/Colors.json` in this folder,
with a built-in dark purple default when the file is missing. To follow your
wallpaper with [matugen](https://github.com/InioX/matugen), add the bundled template
to `~/.config/matugen/config.toml`:

```toml
[templates.qs-novelmangareader]
input_path  = "~/.config/qs-novelmangareader/extras/matugen/quickshell.json.hbs"
output_path = "~/.config/qs-novelmangareader/colors/Colors.json"
```

The panels pick up a new palette as soon as the file changes.

## Your data

- Libraries and reading progress: `~/.local/share/quickshell/{anime,manga}_library.json`,
  `~/.local/share/quickshell/new_novel_library.json`
- Downloads and caches: `~/.local/share/quickshell-manga`, `~/.local/share/quickshell-novel`

These are the same paths the full rice uses, so moving between the two keeps your library.

## License

GPL-3.0-or-later, the same as the rice it comes from. See `LICENSE`.
