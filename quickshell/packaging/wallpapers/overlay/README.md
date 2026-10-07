# qs-wallpaperpicker

A swatch-deck wallpaper picker for [Quickshell](https://quickshell.org), taken out of
[dhrruvsharma/shell](https://github.com/dhrruvsharma/shell) so it can run without
the rest of that rice.

Every wallpaper is a paint-chip card in the colour scheme it would give your desktop
(read with matugen as a dry run). The cards are fanned out like a hand along the bottom
of the screen, and the screen behind them previews the card in front at full size.
The picker's own colours change to match it as you browse.

- **Local:** the wallpapers in your wallpaper folder, sorted by name, colour (round the
  hue wheel, so the deck becomes a spectrum) or newest first.
- **Favourites:** the ones you've hearted.
- **Wallhaven:** search [wallhaven.cc](https://wallhaven.cc) and download a wallpaper
  into your folder as you set it.
- Images, animated GIF/WebP and videos (mp4, webm, mkv, mov). A video wallpaper pauses
  while windows cover it (on Hyprland).

By default Quickshell draws the wallpaper itself, with a transition between wallpapers
and support for videos. If you'd rather keep your own wallpaper tool (swww, hyprpaper,
swaybg, mpvpaper, …), set a **wallpaper command** in the picker's settings: the picker
then runs it instead and draws nothing on your desktop. See [Settings](#settings).

> This folder is generated from the rice by `packaging/export.sh`.
> Report bugs and send changes to the rice repo, not here.

## Requirements

- A Wayland compositor with layer-shell (Hyprland, Sway, niri, river, …)
- `quickshell` (0.2 or newer) with Qt 6 Multimedia (for videos), `python3`, `curl`
- [`matugen`](https://github.com/InioX/matugen), for the cards' colours and to
  recolour your desktop when you set a wallpaper
- `ffmpeg`, for video wallpapers' stills
- The Material Symbols Rounded font

## Install

```sh
git clone <this repo> ~/.config/qs-wallpaperpicker
~/.config/qs-wallpaperpicker/install.sh
```

It lives in its own folder, `~/.config/qs-wallpaperpicker`, outside `~/.config/quickshell`,
so it runs next to your own Quickshell config (or none) without touching it.

`install.sh` does everything:

- installs what the picker needs with your package manager: Quickshell, matugen, ffmpeg,
  curl, Python and Qt 6 Multimedia (pacman on Arch; apt on Debian/Ubuntu and dnf on
  Fedora install what they package and tell you where to get Quickshell and matugen)
- downloads the Material Symbols Rounded font into `~/.local/share/fonts` if it's missing
- links the folder to `~/.config/qs-wallpaperpicker` if you cloned it elsewhere
- puts the `qs-wallpaperpicker` command on your `PATH`: in `~/.local/bin` if that's on it, otherwise
  (after asking) in `/usr/local/bin`, so it works in every shell and in keybinds right away, and makes `~/Pictures/wallpapers`

Options: `--no-deps` (skip packages and the font), `--copy` (copy the folder instead of
linking it), `--yes` (don't ask).

Start it at login with `qs-wallpaperpicker`, and bind a key to open the picker.

Hyprland:

```ini
exec-once = qs-wallpaperpicker
bind = SUPER, W, exec, qs-wallpaperpicker toggle
```

Sway:

```
exec qs-wallpaperpicker
bindsym $mod+w exec qs-wallpaperpicker toggle
```

All its commands:

```sh
qs-wallpaperpicker              # start it
qs-wallpaperpicker toggle       # open/close the picker
qs-wallpaperpicker wallhaven    # open the picker on Wallhaven
qs-wallpaperpicker set <file>   # a name in the wallpaper folder, or a path
qs-wallpaperpicker current      # the wallpaper's path
qs-wallpaperpicker stop         # quit it
qs-wallpaperpicker log          # its log
```

Underneath that's `qs -p ~/.config/qs-wallpaperpicker …`, with the IPC target `wallpaper`
(`toggle`, `wallhaven`, `set`, `current`).

## Using it

| | |
|---|---|
| `←` `→`, wheel, drag | browse |
| `Enter`, click the front card | set it |
| `F` | favourite |
| `S` | sort: name, colour, newest |
| `R` | a random card |
| `Space` | peek: hold, or tap to keep (the deck steps aside) |
| `Tab` | next source |
| `/` | search (Wallhaven) |
| `Esc` | close |

## Settings

The gear at the top right opens them. Each one is applied when you press Enter.

- **Wallpaper folder:** where your wallpapers are, and where Wallhaven downloads go.
  `~/Pictures/wallpapers` by default. If the folder you type doesn't exist yet,
  you can create it there.
- **Wallpaper command:** empty by default, which means Quickshell draws the wallpaper.
  Set it to have your own tool do it; `{}` stands for the wallpaper's path, and is
  quoted for you wherever it stands (with no `{}`, the path goes at the end). Pressing Enter tries it on the wallpaper on screen
  and tells you whether it worked. It also runs once when the picker starts, so tools
  that don't remember the last wallpaper show it again after login. A command that
  keeps running (like `swaybg`) is left running in the background.

  | Tool | Command |
  |---|---|
  | swww | `swww img {}` (add options like `--transition-type grow`) |
  | hyprpaper 0.8+ | `hyprctl hyprpaper wallpaper ",{}"` |
  | older hyprpaper | `hyprctl hyprpaper reload ",{}"` |
  | swaybg | `pkill -x swaybg; swaybg -m fill -i {}` |
  | mpvpaper (videos) | `pkill -x mpvpaper; mpvpaper -o "no-audio --loop" ALL {}` |
  | feh / other X11 tools | not supported: this is Wayland only |

  Start the tool's daemon yourself (e.g. `swww-daemon`) as you do now.
- **Wallhaven API key:** optional. It unlocks NSFW results and your account's
  filters. Find it at [wallhaven.cc/settings/account](https://wallhaven.cc/settings/account).
  Wallhaven is asked to confirm the key works.

They're kept in `settings.json` in this folder, along with the Wallhaven filters
you pick in the picker. It's git-ignored, so your key stays out of the repo.

## Colours

When you set a wallpaper, `matugen image` runs on it with your own matugen config,
so your matugen templates (GTK, terminal, bar, …) follow your wallpaper.

The picker itself uses `colors/Colors.json` in this folder, with a built-in dark
default when it's missing. To have the picker follow your wallpaper too, add the
bundled template to `~/.config/matugen/config.toml`:

```toml
[templates.qs-wallpaperpicker]
input_path  = "~/.config/qs-wallpaperpicker/extras/matugen/quickshell.json.hbs"
output_path = "~/.config/qs-wallpaperpicker/colors/Colors.json"
```

## Files it uses

- `~/.cache/current_wallpaper_source` → the wallpaper; `~/.cache/current_wallpaper` →
  a still of it (the file itself, or a video's frame), for lock screens and the like
- `~/.cache/quickshell/wallpaper-palettes.json`: the cards' colour schemes
- `~/.cache/quickshell/wallpaper-favorites.json`, `~/.cache/quickshell/wallpaper-frames/`

## License

GPL-3.0-or-later, the same as the rice it comes from. See `LICENSE`.
