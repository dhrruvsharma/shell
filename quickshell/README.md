# QuickShell Config

A feature-complete [Quickshell](https://quickshell.outfoxxed.me/) desktop shell for **Arch Linux + Hyprland**, written entirely in QML. Covers everything from a top bar and control center to an AI chat panel, anime/manga/novel readers, and a Wallhaven wallpaper browser — all within a single shell process.

---

## Table of Contents

1. [Installation](#installation)
2. [Architecture](#architecture)
3. [Bar](#bar)
4. [Control Center](#control-center)
5. [Panels & Overlays](#panels--overlays)
   - [Launcher](#launcher)
   - [Window Switcher](#window-switcher)
   - [Network Panel](#network-panel)
   - [Media Panel & CAVA](#media-panel--cava)
   - [Calendar](#calendar)
   - [OSD](#osd)
   - [Keybinds Manager](#keybinds-manager)
6. [Notes Drawer](#notes-drawer)
7. [Clipboard Manager](#clipboard-manager)
8. [Power Menu](#power-menu)
9. [GitHub Contributions](#github-contributions)
10. [Wallpaper](#wallpaper)
    - [Swatch Deck Picker](#swatch-deck-picker)
    - [Wallhaven Browser](#wallhaven-browser)
11. [Media Features](#media-features)
    - [Anime](#anime)
    - [Manga](#manga)
    - [Novel](#novel)
    - [Spotify Lyrics](#spotify-lyrics)
12. [AI Chat](#ai-chat)
    - [Aikira (Character Chat)](#aikira-character-chat)
    - [Ollama Chat](#ollama-chat)
13. [Theming & Colors](#theming--colors)
14. [Settings](#settings)
15. [IPC Reference](#ipc-reference)
16. [Hardcoded Paths](#hardcoded-paths)
17. [Standalone Packages](#standalone-packages)

---

## Installation

Targets **Arch Linux + Hyprland (0.56+, Lua config)**. The repo holds the whole dotfiles tree; the shell lives in `quickshell/`, and the installer also reads `hypr/quickshell.lua` next to it.

```bash
git clone https://github.com/dhrruvsharma/shell.git ~/dotfiles
cd ~/dotfiles/quickshell
./install.sh
```

The installer:

1. Installs the packages with `pacman` (Quickshell, Qt6 extras, PipeWire, NetworkManager, BlueZ + `python-gobject` for the pairing agent, `cava`, `cliphist`, `grim`/`slurp`, `matugen`, Nerd Fonts, …) plus `ttf-material-symbols-variable-git` from the AUR via `paru`/`yay`
2. Fetches the Google Fonts used by the Art Deco, Gothic, Newspaper, Wasteland, Observatory, Abyss, Devaloka, Siege and Sekiro themes (and the brush faces of the Cave Abode and Wabi-sabi power menus) into `~/.local/share/fonts/quickshell-themes`
3. Symlinks the config to `~/.config/quickshell` (an existing one is backed up to `quickshell.bak-<timestamp>`)
4. Creates the data directories (`~/Pictures/wallpapers`, `~/Pictures/Screenshots`, `~/Videos/recordings`, …), links `setwall` into `~/.local/bin`, and registers the matugen template; creates your settings files from `defaults/` (see [Your settings](#your-settings))
5. Copies `hypr/quickshell.lua` (keybinds, blur, animations, scale) into `~/.config/hypr` and adds `require("quickshell")` to your `hyprland.lua` — after asking
6. Generates the notes drawer's IPC command list and asks for a GitHub username for the contributions widget

Run it as your normal user, not root; it calls `sudo` itself.

| Flag | Effect |
|---|---|
| `--copy` | Copy the config instead of symlinking it |
| `--no-deps` | Skip package and font installation |
| `--extras` | Also install `ollama` and `github-cli`, and create the Python venvs for Anime/Manga/Novel |
| `--no-hypr` | Leave `~/.config/hypr` untouched |
| `--github USER` | GitHub user for the contributions widget (blank disables it) |
| `-y`, `--yes` | Don't prompt for confirmation |
| `--update` | Pull the latest changes and redo the setup they need (see [Updating](#updating)) |

### Updating

When the repo gets new commits, update from the folder you installed from:

```bash
cd ~/dotfiles/quickshell
./install.sh --update
```

This:

1. Fetches and fast-forwards your checkout to its upstream branch, listing the new commits
2. Runs the **new** `install.sh` to catch up on whatever the update needs: new packages and fonts, missing state files from `defaults/`, the `setwall` link and matugen template, the IPC command list, and `hypr/quickshell.lua` when it changed (after asking, with your old copy backed up as `quickshell.lua.bak-<timestamp>`)

`--no-deps`, `--no-hypr`, `--extras` and `--yes` work as they do for installing, e.g. `./install.sh --update --no-deps` to skip `pacman`. Quickshell reloads its config by itself when files change; if anything looks off afterwards, restart it with `qs kill; qs -d`.

#### Your settings

What you change in the shell is saved to files inside the config folder, which git ignores, so updates never touch them:

| File | Holds |
|---|---|
| `barlayout.conf` | Bar edge and widget order |
| `barsettings.json` | Bar widgets shown or hidden, container colours, transparency, outline and widths |
| `desktoptheme.json` | Desktop theme and screen effect |
| `desktopwidgets.json` | Desktop widgets and their positions |
| `lockscreen.json` | Lock screen themes |
| `cavawidget.json` | Cava visualizer widget |
| `config/workspacedisc.json` | Workspace disc corner and look |
| `colors/Colors.json` | Colour scheme (written by matugen via `setwall`) |
| `calendar_notes.conf`, `notepad.conf`, `notes.conf`, `pet.json` | Calendar notes, notepad, notes drawer, bar pet |
| `ipc-commands.json` | Generated by the installer |

A new install starts from the copies in `defaults/`: the installer creates any of these files that's missing from there, so deleting one resets that setting on the next `./install.sh --update`.

#### If you've changed code

Edits to files the update doesn't touch are left as they are. If you've edited a file the update also changes, the update stops before changing anything and lists the files. Commit or stash them, update, then bring your edits back:

```bash
git stash
./install.sh --update
git stash pop      # may need resolving if your edits clash with the update
```

If your branch has commits of its own, the update won't merge them for you: `git pull --rebase` (or merge) yourself, then run `./install.sh --update` to catch up on setup.

#### `--copy` installs

The checkout is updated as above, and then the copy in `~/.config/quickshell` is brought up to date file by file. Files you've changed in the copy are kept, and the new version is put next to them as `<file>.new` for you to compare.

#### Updating an install from before `--update` existed

Older checkouts don't have `--update` yet, and still track the settings files, so a plain `git pull` stops on them. Get the new installer first, then update:

```bash
cd ~/dotfiles/quickshell
git fetch
git checkout origin/main -- install.sh
./install.sh --update
```

Your settings carry over: the files you'd changed are kept as they are, and the ones you hadn't are recreated from `defaults/`.

### After installing

1. Autostart the shell and clipboard history from your Hyprland config:
   ```lua
   hl.on("hyprland.start", function()
       hl.exec_cmd("wl-paste --watch cliphist store")
       hl.exec_cmd("qs")
   end)
   ```
   Then log into Hyprland, or run `hyprctl reload`.
2. Put a wallpaper in `~/Pictures/wallpapers` and run `setwall <file>` — it sets the wallpaper and generates the colour scheme with matugen.
3. Panels are sized for monitor scale `1`; the installer warns if a monitor uses another scale.
4. Change the GitHub widget's user later with `qs ipc call github setUser <name>` (an empty string disables it).
5. Anime, Manga, Novel, Aikira and Spotify Lyrics need their backends set up — see [Media Features](#media-features) and [AI Chat](#ai-chat), or run the installer with `--extras` for the venvs.

---

## Architecture

Every feature is a QML `Loader` inside a single `ShellRoot` (`shell.qml`). Components start with `active: false` and are instantiated only on first use — a 600 ms deactivation timer fully unloads them after closing, keeping memory footprint low while the shell itself is always running.

Backend data (anime, manga, novel, AI chat) is split into two layers:

| Layer | Location | Role |
|---|---|---|
| Python backend | `scripts/` | Scrapes / proxies data, exposes a local HTTP API |
| QML service + module | `services/` + `modules/` | Consumes the API, stores state, renders UI |

Services that own a Python process launch it on startup; no separate daemon management is required unless you prefer a persistent server independent of Quickshell.

---

## Bar

`modules/bar/` — a 42 px strip on any edge of the screen: `Bar.qml` holds its surface and the room it reserves, `TopBar.qml` the widgets.

**Start:** CPU · Battery · Clock · Bluetooth  
**Middle:** Media pill (track info + controls, shown when something is playing)  
**End:** Updates · Network · Volume · Temperature · Memory · Settings · System Tray

- **Widgets:** drag one onto another to group them, or into a gap to move it. `qs ipc call barLayout reset` restores the default order.
- **Settings** (`modules/barsettings/`, `services/BarSettings.qml`): the gear on the bar or **SUPER + B** opens them. Show or hide any widget (the gear, media pill, tray and pet too; hidden ones keep their place), from switches or by clicking them in a live preview of the bar over your wallpaper. Colour the containers from the wallpaper (a tone of matugen's scheme, *Default* being the usual look) or with a picker (saturation/brightness square, hue strip, hex code, swatches), and the text the same way, with a readability check. Transparency fades the containers but never the text; an outline helps them read when they're faint. Also the bar's edge and its widgets back in order. The **Width** tab sets each container's width (Auto fits its text; − / + nudge it 4 px, the slider sets any width, *All widgets* sets them all at once); text that no longer fits is cut short with "…" and scrolls through like the media pill's title, on hover, all the time or never, slow, normal or fast. Widths apply while the bar lies along the top or bottom. Everything applies live and is saved to `barsettings.json`.
- **Edge:** drag an empty stretch of the bar towards another edge and let go to move it there. On the left or right edge it stands on end and each widget shows a compact upright face. Panels that hang from the bar follow it.
- **Workspace disc** (`modules/workspacedisc/`): peeks out of a screen corner beside the bar. Hover it to open it out, click a chamber to switch workspace, drag it to another corner.

**IPC:** `qs ipc call barLayout setEdge top|bottom|left|right`, `toggleEdge`, `edge`; `qs ipc call barSettings toggle|open|close`, `toggleWidget <cpu|memory|temp|battery|clock|network|bluetooth|volume|updates|settings|media|tray|pet>`, `setColor <#rrggbb>` (`""` for the wallpaper's), `setTransparency <0-100>`, `resetLook`, `setWidth <widget> <px>` (`0` for auto), `setOverflow hover|always|cut`, `resetWidths`

---

## Control Center

`modules/control/ControlCenter.qml` — a full-height panel on the left (468 px wide), hanging clear of the bar on whichever edge it stands. It's made like the desktop theme's widgets (`ControlStyle.qml` reads `WidgetStyle`): the theme's widget frame is its surface (a scrap plate in Wasteland, a war banner in Siege, a lancet window in Cathedral, a newspaper column in Broadsheet…), with the theme's type, wording, meters and art throughout. Without a theme it's a plain rounded card.

From the top:
- **Masthead** (`Masthead.qml`) — the time in the theme's display face and the day as the theme keeps it (the watch of the siege, the canonical hour, the tithi and nakshatra, the boat's depth, the edition on the street…), and your avatar in the theme's frame (click it to pick another).
- **Switches** (`Toggles.qml`) — Wi-Fi and Bluetooth as wide tiles (the chevron opens the network panel on that tab; Bluetooth shows the connected device and its battery), then do not disturb, night light, airplane mode, the power profile (a click steps through them) and the desktop theme (opens the Themes panel).
- **Levels** (`Levels.qml`) — volume (the glyph mutes, the chevron lists the outputs by their short names), brightness, and the night light's warmth while it's on. Tracks are drawn in the theme's meter style (hazard tape, prayer beads, a sword drawn from its scabbard…). The volume/brightness OSD stays quiet while the panel is open.
- **Now playing** (`NowPlaying.qml`) — art, track, progress (click to seek) and controls, while a player is around.
- **Notifications** (`NotificationList.qml`) — newest first under the theme's name for them ("Radio chatter", "Dispatches", "Stop press"…), with a count and *Clear all*; they take whatever height is left. A click runs the app's default action; the cross dismisses one (the app is told). With none, the theme's line for the quiet.
- **Machine** (`Vitals.qml`) — CPU, memory, temperature and disk on the theme's meters, and the uptime.
- **Power** (`PowerRow.qml`) — lock, sleep (locks first, then suspends once every screen is covered), log out, restart, shut down; the last three ask for a second click.

**Do not disturb** (`services/Notification.qml`) holds back every toast but critical ones; the notifications still land in the list, and the setting is kept in `notifications.json`. **Night light** (`services/NightLight.qml`) runs `hyprsunset` (install it with `sudo pacman -S hyprsunset`); the choice and warmth are kept in `nightlight.json` and restored when the shell starts. **Airplane mode** (`services/Radios.qml`) blocks every radio with `rfkill`.

**IPC:** `qs ipc call controlCenter changeVisible` · `qs ipc call notifications toggleDnd|setDnd <bool>|clear` · `qs ipc call nightLight toggle|setTemperature <kelvin>`

---

## Panels & Overlays

### Launcher

`modules/launcher/` (`LauncherWindow.qml`, `LauncherDial.qml`, `DialApp.qml`, `DialFace.qml` and one `*Face.qml` per theme)

Opens with **SUPER+R**, by hovering the **left 2 px edge** of the screen (bottom 600 px), or via IPC. A great wheel rolls out of the left edge with the apps riding its rim. Turning it brings an app to the pointer at three o'clock, where it swells and its name is set large beside it in the theme's display face, with what it is, whether it runs in a terminal, and its actions. The wheel's face is the desktop theme's own object, and its pointer reaches across to the name:

| Theme | Wheel | Pointer |
|---|---|---|
| none | tonal dial, minute marks | accent pill and halo |
| HUD | game selection wheel, bearings | target brackets, `▸ EQUIP` tracer |
| Mainframe | reel of nine-track tape | read head, tape threading on |
| Astral | orrery, the sun at the hub | a course plotted in dots |
| Still | dry garden raked round its stones | a dot and a hairline |
| Cave Abode | luopan: mountains, trigrams, branches | the red thread |
| Neon Noir | round neon sign, katakana | a third tube and a chevron |
| Wabi-sabi | ensō on washi, mended in gold | vermilion seal, seam of gold |
| Art Deco | elevator dial gone round, gilt rays | gilt needle |
| Cathedral | rose window in stone | gilded rod, quatrefoil |
| Broadsheet | rotary telephone dial | finger stop; the name a headline on a clipping |
| Wasteland | a valve's rusted handwheel | hazard tape |
| Observatory | astrolabe, the rete turning over the plate | its rule, and a sight |
| Abyss | sonar scope | the sweep, `CONTACT` |
| Devaloka | Konark sun wheel | a lotus and a thread of gold, temple border |
| Siege | war shield in your tincture, hands aimed at the app | a longsword laid out |
| Sekiro | iron tsuba, the season inlaid in gold | the blade from its habaki; the name over crimson |

- **Turning:** ↑ / ↓, Page Up / Page Down, the scroll wheel (touchpads glide), or drag the wheel round (it runs on with a flick). Click an app on the rim to turn to it, click the one at the pointer (or its name) to launch. With more apps than the rim shows it wraps round from the last to the first; the letter each run of names starts with sits on the band inside the rim.
- **Search:** just type. It ranks names, initials (`gc` → Google Chrome), what an app is (`browser`), its keywords and command (`nvim`), then its description; the apps you launch most come first (counts in `~/.cache/quickshell/appusage.json`). The best match comes to the pointer.
- **Tab** steps through the app's actions ("New Private Window"…), **Enter** launches, **Esc** clears the search, then closes.
- **Apps** come from `services/AppRegistry.qml`: Quickshell's desktop-entry index (it follows installs and removals live, and parses each `Exec` line), with icons from your GTK icon theme via `scripts/app-icons.py`. Apps start detached from the shell (a reload doesn't kill them), in their working directory, and in a terminal (`$TERMINAL`, else kitty) when their entry asks for one — btop, htop, nvim, nvtop, yazi…

**IPC:** `qs ipc call launcherWindow toggle`

### Window Switcher

`modules/switcher/WindowSwitcher.qml`

Hyprland-aware window switcher with live thumbnails (`WindowThumbnail.qml`) and a search box.

### Network Panel

`modules/network/NetworkPanel.qml`

The airwaves round this computer, in two tabs (Wi-Fi · Bluetooth). Each tab's head shows its radio's state and has its own switch.

**Wi-Fi** (`WifiPanel.qml`) opens the Wi-Fi sign out into a map of the networks round you (`WifiFan.qml`). The computer sits at the foot of the sign and its four bars arc over it, a quarter of the signal strengths each with the strongest innermost. Every network the radio hears sits on the bar of its strength, closer and brighter the stronger it is. 2.4 GHz has the left of the fan and 5 GHz (then 6 GHz) the right, in channel order, so a crowded channel shows as a cluster; a network on both bands appears on both sides. The network in use is a disc in the theme's accent tethered to the computer, and its bar is lit. Saved networks are ringed, hidden ones are specks. Under the fan are the connection (address, live down/up rates and the last minute of traffic) and the networks in range, each with its signal as a small Wi-Fi sign. Pointing at a row lights its network on the fan and pointing at a network lights its row.

Picking a band: clicking a row joins the network on whichever band NetworkManager prefers. A network on more than one band shows a chip per band with its signal there (`2.4 GHz 95%`, `5 GHz 64%`): a chip joins on that band, and so does clicking the network on its side of the fan. For a network that needs a password, the chip chooses the band the password form joins on. The connection's own chips show the band in use, and the other chip moves it over. A saved network is brought up on the chosen access point (`nmcli connection up … ap <BSSID>`) without changing its profile; a new one is created on that access point and then released, so its profile isn't tied to one band afterwards.

Opening the panel rescans if the last scan is more than 30 s old, and a scan lights the bars outwards in turn. Traffic is sampled from `/proc/net/dev` only while it's on screen.

**Bluetooth** (`BluetoothPanel.qml`) puts the devices in orbit round the computer (`OrbitMap.qml`): connected ones on the inner orbit, tethered to it and ringed by their battery; paired ones on the middle orbit; ones a scan found on the outer, dashed one. A device glides to its new orbit as it pairs or connects, and a scan sends rings out from the computer. Below, the devices are listed as Connected, Paired and Nearby. It does its own pairing, no blueman needed:

- Click a device to pair it (which also trusts and connects it), connect it or disconnect it. Hover a paired device for **trust** (the shield: whether it may connect by itself) and **remove**.
- PIN, passkey and "does it show this code?" questions appear as a card under the orbits (`BluetoothPrompt.qml`), as do untrusted devices asking to connect (Deny / Allow / Always allow). The panel opens itself when one comes in.
- The eye icon makes this computer discoverable, so a phone can pair from its side.

Quickshell registers no BlueZ pairing agent, and without one bluetoothd refuses PIN/passkey pairing and turns away untrusted devices. `scripts/bluetooth_agent.py` is that agent: `services/Bluetooth.qml` runs it and talks to it in JSON lines (the protocol is in the script's docstring). It needs `python-gobject`; without it pairing falls back to Quickshell's own, which only handles devices that need no code.

**IPC:**
```bash
qs ipc call networkPanel changeVisible wifi
qs ipc call networkPanel changeVisible bluetooth
```

### Media Panel & CAVA

`modules/media/MediaPanel.qml` + `modules/media/CavaPanel.qml`

Full media controls with album art, seek bar, and a CAVA audio visualizer panel. A separate `Visualizer` component (`components/Visualizer.qml`) renders bar-style audio at the top and bottom of the screen (togglable).

**IPC:**
```bash
qs ipc call mediaPanel toggle
qs ipc call visBottom toggle   # full-screen CAVA visualizer
```

### Calendar

`modules/calendar/CalendarWindow.qml` + `ClockWindow.qml`

Popup calendar with a full clock display.

### OSD

`Osd/OsdWindow.qml` + `Osd/OsdPill.qml` + `services/Osd.qml`

The volume and brightness OSD, at the bottom centre (above a bottom bar) on the overlay layer, so it shows over fullscreen video too. It drops in as a bead holding its sign, opens into a pill, and folds back into the bead when it goes.

- **Brightness** — a drawn sun whose rays grow and turn with the level and whose glow lights the pill; below a fifth it wanes to a crescent moon. The meter is a strip of night sky that the daylight floods, putting out the stars as it reaches them. Every step sends a glint along the light.
- **Volume** — a speaker whose three waves light in turn, over a waveform that stands taller the louder it is. Every step sends a wavefront out of the speaker that bounces the bars as it rolls past. It names the output (headphones, speaker, HDMI) and shows when a new one takes over. Muted, the waveform goes flat. Past 100% (wpctl lets the keys run on), the bars clip and run hot.
- Brightness changes arrive through inotify on the backlight (the kernel notifies every write), so the OSD shows at once without polling. A key pressed at either end of the range shows it too.
- The desktop theme gives it its corners, frame, type and colours.

### Keybinds Manager

`modules/keybinds/KeybindsPanel.qml` + `services/Keybinds.qml` + `scripts/keybinds.py`

Every Hyprland bind in `~/.config/hypr/*.lua` (`hyprland.lua`, `quickshell.lua`, …), on a drawn keyboard and in a list, to add, change and delete. **SUPER + /** opens it.

- **The keyboard** shows one modifier layer at a time: the keys bound with those modifiers held light up in their action's colour, with the app's own icon on a launcher's key and the number on a workspace's. Pick the layer with the chips above it, by clicking the modifier keys, or peek by holding the real ones. Media keys and the mouse (buttons and scroll) have a row underneath. Two binds on one key get a red dot.
- **The list** keeps the config's own grouping: each heading is the comment above a group of binds. A loop's binds (the workspaces 1–10) share a row and are read-only, since changing them means changing the loop.
- **Hover** a key or a row to see what it runs, where it's written (`file:line`) and its options; **click** a free key to bind it; **double-click** a bind to edit it.
- **The editor** takes the shortcut by recording it (Hyprland steps aside into an empty submap meanwhile, so the keys you press don't fire their binds; Escape or 15 s leave it), by clicking a key on the keyboard, or from the modifier toggles. Anything already on that combo is named, and can be replaced. The action is a command (with your installed apps and common media/screenshot commands to hand), one of the shell's panels (from `ipc-commands.json`), a window or workspace action, or any Lua dispatcher. Options are Hyprland's bind flags (lock screen, repeat, on release, …) and an optional label (`description`). The line it'll write shows as you go.
- **Saving** rewrites only what changed on the line and keeps the rest as written (`mainMod ..`, variables such as `terminal`, alignment, other options). New binds go under the heading that suits them; that's adjustable. Before anything is written, the change goes through `luac -p` and a dry run of the config, and the running Hyprland builds the new action once to check it. The old file is kept in `~/.cache/quickshell/keybinds/` (the last 30 per file). Hyprland's own file watch reloads it; if Hyprland then reports a config error it didn't have before, the file is put back. **Undo** (in the toast, or Ctrl+Z) restores the previous version, but not over edits made since.

Keys: `/` search, `N` new bind, `Enter` edit and `Delete` delete the selected bind, `Ctrl+Z` undo, `Esc` back out. Reading the config runs it in a sandbox (`scripts/keybinds-probe.lua`, with Lua 5.5 like Hyprland): a stand-in `hl` records the binds, and nothing the config does is carried out.

**IPC:** `qs ipc call keybinds toggle` (also `open`, `close`)

---

## Notes Drawer

`components/NotesDrawer.qml` — slides up from the **bottom center** of the screen (900 px wide hover zone).

Features:
- Multiple **categories**, each independently named and configurable
- Per-category **shell command** — executed with `$text` / `$note` substitution when a note is clicked
- Per-category **keep-open** flag — opens a `kitty --hold` terminal so output stays visible
- Default action (no command set): copies note text to clipboard via `wl-copy`
- Sort toggle (newest-first / oldest-first)
- Add / edit / delete notes with optional subtext
- State persisted to `~/.config/quickshell/notes.conf`

---

## Clipboard Manager

`components/ClipboardManager.qml` — centered overlay with three tabs.

| Tab | Content |
|---|---|
| Clipboard | Recent clipboard history (read via `wl-paste`) |
| Emoji | Full emoji picker backed by `files/emoji.json` with category filter + search |
| Kaomoji | Kaomoji list backed by `files/kaomoji.json` with search |

Selecting any item copies it to the clipboard.

**IPC:** `qs ipc call clipboardManager changeVisible`

---

## Power Menu

`modules/power/` — **SUPER + P**. Lock, sleep, log out, restart and shut down, staged in the desktop theme's own world: one scene per theme (`<Name>Power.qml`, built on `PowerScene`; `PlainPower` without a theme). The screen is grabbed as it opens, so each scene grows out of the desktop and shrinks back into it.

| Theme | The menu | Shutting down |
|---|---|---|
| *(none)* | Five tiles over the frosted desktop, each turning into a circle in its own colour | The tile grows to fill the screen |
| HUD | A game's pause menu with a blinking cursor, and your player card | GAME OVER (a restart: CONTINUE? 3, 2, 1) |
| Mainframe | An ncurses dialog on a phosphor CRT, each action beside its real command | The command is typed, systemd's stop log scrolls, the tube collapses to a dot |
| Astral | An orrery: five worlds on their orbits round a star | The system falls into a singularity (a restart jumps to hyperspace) |
| Still | One breathing circle and five words; a pebble rolls to the one you point at | A long exhale |
| Cave Abode | Paper talismans on a cinnabar cord | The talisman burns; its seal hangs in the dark as the world turns to ink |
| Neon Noir | Vertical katakana neon signs in the rain | The signs short out one by one |
| Wabi-sabi | Brushed kanji on washi; an ensō drawn round the one you point at | The ensō closes, cracks and is mended with gold |
| Art Deco | The Express Elevator's floor dial and buttons | The gilded lift doors slide shut |
| Cathedral | Lancets and candles under the rose window | Compline: the candles are snuffed one by one |
| Broadsheet | A front page, the desktop as its halftone photograph, five stories | The story is stamped, the page spins away: -30- (a restart spins in an EXTRA) |
| Wasteland | A breaker panel of levers and caged lamps | A lever thrown, the lamps die, the blast shutter slams down |
| Observatory | The astrolabe, turned to tonight's sky, ringed by five brass stations | The dome's shutters close: "clear skies" |
| Abyss | An engine order telegraph, the depth and the boat's readings beside it | ABANDON SHIP is rung and the boat floods (a log out surfaces) |
| Devaloka | Five diyas on an aarti thali under the Konark wheel and the panchang | The lamps go out; moksha's flame rises away |
| Siege | War banners on the battlements between torches, your arms above | The host strikes camp: the banners are lowered, the torches go out |
| Sekiro | A Sculptor's Idol's menu by moonlight: Rest, Meditate, Return, Resurrect, Immortal Severance | Immortal Severance: a cut of blood across the screen, 不死断ち, darkness (Return closes the night in round 竜の帰郷; Resurrect writes 回生) |

Lock and sleep hand over to the lock screen straight away (sleep suspends once it's locked). Log out, restart and shut down play their ceremony first, and Esc or a click still turns it back; the last frame then stays up while the session ends. If the command is refused (an inhibitor, a password prompt), a notification says why and the menu comes back. Keys: arrows or Tab, Enter, 1–5 or L S O R P, Esc.

**IPC:** `qs ipc call powerMenu toggle`

---

## GitHub Contributions

`components/GhPopout.qml` — slides in from the **right 2 px edge** of the screen.

Displays a 40-week (280-day) contribution heatmap fetched from the `github-contributions-api.jogruber.de` public API. The username is set in `services/Github.qml` (`author` property). Refreshes every 10 minutes.

---

## Wallpaper

### Swatch Deck Picker

`modules/wallpaper/Wallpaper.qml` + `SwatchCard.qml`, `CardPicture.qml`, `SpectrumRibbon.qml`, `WallpaperBackdrop.qml`; colours from `services/WallpaperSwatches.qml`

Every wallpaper in your wallpaper folder (`~/Pictures/wallpapers/` unless you change it; images, GIFs and videos) is a paint-chip card **dressed in the colour scheme it would give your desktop**: the card is the scheme's surface, its text the on-surface colour, and a strip of chips shows primary, secondary, tertiary, container and surface with their hex codes. The cards are held fanned out like a hand along the bottom of the screen. Behind them the whole screen previews the card in front at full size, and the picker's own accents take on that card's colours, so browsing is trying each wallpaper on before you set it.

- **Sources:** Local, Favourites (press <kbd>F</kbd>), and Wallhaven search results.
- **Sort:** by name, newest first, or **by colour**. Colour sort goes round the hue wheel of each scheme's source colour, so the deck becomes a spectrum (grey schemes come last).
- **Spectrum ribbon:** the whole deck as one strip of colour under the header. A bracket marks the cards in hand and ticks mark favourites. Hover for a glimpse of any wallpaper; click or drag to jump there.
- **Peek:** hold <kbd>Space</kbd>, or tap it to keep it, and the deck steps aside for an unobstructed look. Clicking the picture does the same.
- **Live preview:** the play button in the header (or <kbd>V</kbd>) makes videos and animated GIF/WebP wallpapers play in the preview, and in the card in front, instead of a still of them. It's remembered (`wallpaperLivePreview` in `settings.json`), and the button only shows when the folder has something that moves.
- **Choosing a card:** the card you set leaves the hand and comes slowly to the middle of the screen while the rest of the hand is put away. It lights up as it's set: the "current" tag pops, a ring goes out from it and light crosses its picture. Then the picture grows into the wallpaper and the picker fades away over the wallpaper itself. A Wallhaven result waits in the middle while it downloads (<kbd>Esc</kbd> sends it back to the deck). This can be turned off in the settings: the wallpaper then changes straight away and the deck stays open.
- **Themes:** it follows the active desktop theme: corner radii, fonts, and the theme's frame on the card in front.

The schemes come from `scripts/wallpaper-palettes.py`. It runs `matugen image … --dry-run` with the same options as setting a wallpaper (nothing is applied), so a card shows exactly the scheme you will get. It only runs while the picker asks, niced and three images at a time, with the cards in view first. Each file is read once and cached in `~/.cache/quickshell/wallpaper-palettes.json`, keyed by file name and mtime.

**Keys:** <kbd>←</kbd><kbd>→</kbd> or the wheel to browse, <kbd>Home</kbd>/<kbd>End</kbd>, <kbd>PgUp</kbd>/<kbd>PgDn</kbd>, <kbd>R</kbd> random card, <kbd>Enter</kbd> set, <kbd>F</kbd> favourite, <kbd>S</kbd> sort, <kbd>Space</kbd> peek, <kbd>V</kbd> live preview, <kbd>Tab</kbd> next source, <kbd>/</kbd> search (Wallhaven), <kbd>Esc</kbd> close. You can also drag anywhere to turn the deck. Click a card to bring it to the front, then click the front card (or double-click any card) to set it.

Setting a wallpaper goes through `services/WallpaperEngine.qml`, which plays the desktop theme's transition and regenerates the colour scheme with matugen.

**Settings:** the gear at the top right opens four settings. The three fields are each applied with <kbd>Enter</kbd>, the switch as it's clicked:
- **Wallpaper folder:** where the picker looks, and where Wallhaven downloads are saved. If the folder doesn't exist, it offers to create it.
- **Wallpaper command:** empty, Quickshell draws the wallpaper. Set it (e.g. `swww img {}`, where `{}` is the file) to have another tool do it: the wallpaper layer then makes no windows, so the desktop theme's layer and video wallpapers go with it.
- **Wallhaven API key:** optional; it unlocks NSFW results. The picker asks Wallhaven whether it accepts the key.
- **Setting a wallpaper:** on (the default), the chosen card grows into the wallpaper and the picker closes; off, the wallpaper changes straight away and the deck stays open for more browsing (`wallpaperAnimateChoice`).

They're saved in `settings.json` (see [Settings](#settings)), and `scripts/setwall` reads the folder from there too.

**IPC:** `qs ipc call wallpaper toggle`, `qs ipc call wallpaper wallhaven`, `qs ipc call wallpaper set <path>`

### Wallhaven Browser

`modules/wallpaper/WallhavenPanel.qml` + `services/Wallhaven.qml`

The picker's Wallhaven tab browses [Wallhaven](https://wallhaven.cc) with full API parameter support: categories, purity, sorting, order, top-range, minimum resolution, aspect ratios, search query, and API key. All options are persisted in `SettingsConfig`, and changes trigger an automatic re-fetch. Results load page by page as you near the end of the deck. Their cards wear the colours Wallhaven reports for each image. Setting one downloads it to the wallpaper folder first, with the progress shown on the card and the button.

---

## Media Features

All four media features share the same two-layer pattern: a Python backend server started automatically by a QML service, and a QML module that drives the UI.

### Anime

- **Script:** `scripts/anime_server.py`
- **Service:** `services/Anime.qml` — starts server, polls `http://127.0.0.1:5050/health`
- **Module:** `modules/anime/` — Browse · Library · Detail · Stream views

Wraps the [AllAnime](https://allanime.day) GraphQL API (same source as `ani-cli`). Resolves multi-provider stream links and returns direct video URLs for MPV.

**Setup:**
```bash
python -m venv ~/ani-env
~/ani-env/bin/pip install flask requests
```

> Venv path is hardcoded in `services/Anime.qml` line 148. Edit that line to change it.

**Port:** `http://127.0.0.1:5050`  
**Library:** `~/.local/share/quickshell/anime_library.json`  
**IPC:** `qs ipc call animePlayer toggle`

---

### Manga

- **Script:** `scripts/manga_server.py`
- **Service:** `services/Manga.qml` — starts server, polls `http://127.0.0.1:5150/health`
- **Module:** `modules/manga/` — Browse · Library · Detail · Reader views

Scrapes [WeebCentral](https://weebcentral.com) using `curl_cffi` (Firefox TLS fingerprinting to bypass Cloudflare, with a `requests` fallback). Additional features:
- Favorites with automatic new-chapter detection (checked every 15 minutes)
- Chapter downloads to `~/.local/share/quickshell-manga/downloads/`
- Image proxy at `/image?url=` to bypass CDN user-agent checks

**Setup:**
```bash
python -m venv ~/.venv/manga
~/.venv/manga/bin/pip install curl_cffi requests
```

> Venv path is hardcoded in `services/Manga.qml` line 137. Edit that line to change it.

**Port:** `http://127.0.0.1:5150`

| Path | Contents |
|---|---|
| `~/.local/share/quickshell-manga/favorites.json` | Favorites list |
| `~/.local/share/quickshell-manga/downloads/` | Downloaded chapters |
| `~/.local/share/quickshell/manga_library.json` | In-shell reading library |

**IPC:** `qs ipc call mangaReader toggle`

---

### Novel

- **Script:** `scripts/novel_server/` (entry: `main.py`)
- **Service:** `services/Novel.qml` — starts server, polls `http://127.0.0.1:5151/health`
- **Module:** `modules/novel/` — Browse · Library · Detail · Reader views

Uses the `freewebnovel` provider (the registry supports more; switchable at runtime from the UI or via):
```bash
curl -X POST http://127.0.0.1:5151/provider/switch \
  -H 'Content-Type: application/json' \
  -d '{"provider":"freewebnovel"}'
```

| Provider name | Source |
|---|---|
| `freewebnovel` | freewebnovel.com |

**Setup:**
```bash
python -m venv ~/novel-env
~/novel-env/bin/pip install curl_cffi requests
```

> Venv path is hardcoded in `services/Novel.qml` lines 144–146. Edit those lines to change it.

> The `scripts/novel_server/__pycache__/` bytecode targets Python 3.14. It is regenerated automatically on older versions — no action needed.

**Port:** `http://127.0.0.1:5151`  
**Library:** `~/.local/share/quickshell/new_novel_library.json`  
**IPC:** `qs ipc call novelReader toggle`

---

### Spotify Lyrics

- **Service:** `services/LyricsService.qml`

Polls `playerctl -p spotify status` every 2 seconds. On track change, fetches time-synced lyrics from a local **[spotify-lyrics-api](https://github.com/akashrchandran/spotify-lyrics-api)** server using the Spotify track ID.

**Setup:**

1. Clone and run the lyrics API server (requires a Spotify `sp_dc` cookie — see its README):
   ```bash
   git clone https://github.com/akashrchandran/spotify-lyrics-api
   cd spotify-lyrics-api
   # follow upstream setup instructions
   ```

2. Ensure `playerctl` is installed:
   ```bash
   sudo pacman -S playerctl
   ```

3. The service expects the API at `http://localhost:8080` (hardcoded in `services/LyricsService.qml` line 60). Change that line if your server runs on a different port.

---

## AI Chat

### Aikira (Character Chat)

**aikira/** — a full AI roleplay / character-chat system with a FastAPI + PostgreSQL backend.

**Architecture:**

| Component | Role |
|---|---|
| `aikira/Aikira.qml` | Root panel (1100×720), drives streaming and reroll logic |
| `aikira/AppState.qml` | Singleton state: characters, personas, proxies, conversations, messages |
| `aikira/Api.qml` | REST client for `http://127.0.0.1:7842/api/v1` |
| `scripts/aikira/run.py` | FastAPI server entry point |
| `scripts/aikira/aikira-stream.py` | SSE streaming helper called per message |
| `scripts/aikira/app/` | FastAPI app (routes, models, config) |
| `scripts/aikira/alembic/` | Database migrations |

**Features:**
- Multi-character library with per-character first messages and system prompts
- User personas (selectable per-conversation)
- Proxy management with live connectivity testing
- Conversation history with rename support
- SSE token streaming rendered in real-time
- Response reroll — generates alternatives in-memory; navigate with `←` / `→`
- Views: Chat · Character Editor · Character Browser · Proxy Manager · Persona Selector

**Backend setup:**

The backend is a standalone FastAPI service. A systemd unit file is provided at `scripts/aikira/aikira.service` for persistent operation:

```bash
# Install dependencies
cd scripts/aikira
python -m venv .venv
.venv/bin/pip install -r requirements.txt

# Configure (copy and edit the .env)
cp .env.example .env   # set DATABASE_URL, model API keys, etc.

# Run database migrations
.venv/bin/alembic upgrade head

# Start the server
.venv/bin/python run.py
```

To run as a systemd user service:
```bash
cp scripts/aikira/aikira.service ~/.config/systemd/user/
# Edit WorkingDirectory and ExecStart paths in the unit file
systemctl --user enable --now aikira
```

**IPC:** `qs ipc call aikiraChat changeVisible`

---

### Ollama Chat

`components/OllamaChat.qml` + `services/OllamaService.qml`

Local LLM chat using a running [Ollama](https://ollama.com) instance. The service fetches available models from `http://127.0.0.1:11434/api/tags` and streams responses via `curl` to `/api/chat`. Supports multi-turn history, model selection, and response cancellation.

**Requires:** Ollama running locally (`ollama serve`).

**IPC:** `qs ipc call ollamaChat changeVisible`

---

## Theming & Colors

Colors are defined in `colors/Colors.json` and exposed as a QML singleton via `colors/Colors.qml`. The `SettingsConfig` singleton (`settings/SettingsConfig.qml`) exposes two color-scheme properties:

| Property | Values |
|---|---|
| `matugenScheme` | `material`, `vibrant`, `expressive`, … |
| `matugenTheme` | `dark`, `light` |

These are consumed by `config/Appearance.qml` / `config/AppearanceConfig.qml` and the Wallhaven service (which passes them to the `setwall` script for palette generation).

Settings are persisted to `~/.cache/quickshell/settings.json` and reloaded automatically when the file changes externally, enabling live color updates from tools like `matugen`.

---

## Settings

All persistent UI settings are managed by `settings/SettingsConfig.qml` and stored at:
```
~/.cache/quickshell/settings.json
```

Settings include: color scheme, music visualizer toggle, pinned apps, dock visibility / auto-hide / music player display, the wallpaper folder, Wallhaven API parameters, and the app grid layout.

---

## IPC Reference

All panels are controlled through Quickshell's `IpcHandler` system. Use `qs ipc call` from a terminal or bind commands in `hyprland.conf`.

| Target | Command | Notes |
|---|---|---|
| `animePlayer` | `qs ipc call animePlayer toggle` | Left-anchored panel |
| `mangaReader` | `qs ipc call mangaReader toggle` | Left-anchored panel |
| `novelReader` | `qs ipc call novelReader toggle` | Right-anchored panel |
| `mediaPanel` | `qs ipc call mediaPanel toggle` | Centered panel |
| `controlCenter` | `qs ipc call controlCenter changeVisible` | Left slide-in |
| `notifications` | `qs ipc call notifications toggleDnd` | Do not disturb (`setDnd <bool>`, `clear`) |
| `nightLight` | `qs ipc call nightLight toggle` | Night light via hyprsunset (`setTemperature <kelvin>`) |
| `networkPanel` | `qs ipc call networkPanel changeVisible [wifi\|bluetooth]` | Bottom-right panel |
| `clipboardManager` | `qs ipc call clipboardManager changeVisible` | Centered overlay |
| `powerMenu` | `qs ipc call powerMenu toggle` | Power menu, staged by the desktop theme (SUPER + P) |
| `ollamaChat` | `qs ipc call ollamaChat changeVisible` | Centered panel |
| `aikiraChat` | `qs ipc call aikiraChat changeVisible` | Centered panel |
| `launcherWindow` | `qs ipc call launcherWindow toggle` | Left-edge launcher |
| `wallpaper` | `qs ipc call wallpaper toggle` | Wallpaper picker (swatch deck) |
| `visBottom` | `qs ipc call visBottom toggle` | Full-screen CAVA visualizer |
| `keybinds` | `qs ipc call keybinds toggle` | Keybinds manager (SUPER + /) |
| `barSettings` | `qs ipc call barSettings toggle` | Bar settings (SUPER + B) |

### Example Hyprland keybindings

```ini
bind = $mod, A, exec, qs ipc call animePlayer toggle
bind = $mod, M, exec, qs ipc call mangaReader toggle
bind = $mod, N, exec, qs ipc call novelReader toggle
bind = $mod, C, exec, qs ipc call controlCenter changeVisible
bind = $mod, V, exec, qs ipc call clipboardManager changeVisible
bind = $mod, P, exec, qs ipc call powerMenu toggle
bind = $mod, I, exec, qs ipc call aikiraChat changeVisible
```

### Edge hover triggers (no keybind needed)

| Edge | Zone | Action |
|---|---|---|
| Left | 2 px wide, bottom 600 px | Opens Launcher |
| Right | 2 px wide, bottom 500 px | Toggles GitHub contributions popout |
| Bottom center | 2 px tall, 900 px wide | Toggles Notes drawer |

### How lazy loading works (`shell.qml`)

Each panel uses a `Loader` with `active: false` by default so it costs nothing until first opened:

1. IPC fires → if `active` is `false`, sets `active = true` then makes the item visible
2. If already active → toggles visibility
3. When closed, a 600 ms timer sets `active = false`, fully unloading the component

```
Anime   → animeLoader   (anchors: left, top, bottom)
Manga   → mangaLoader   (anchors: left, top, bottom)
Novel   → novelLoader   (anchors: right, top, bottom)
Aikira  → aikiraLoader  (centered)
Ollama  → chatLoader    (centered)
```

---

## Hardcoded Paths

| File | Line(s) | Hardcoded path | What to change |
|---|---|---|---|
| `services/ReaderEnv.qml` | 10–12 | `~/ani-env`, `~/.venv/manga`, `~/novel-env` | Anime/manga/novel Python venvs |
| `services/LyricsService.qml` | 60 | `http://localhost:8080` | Lyrics API port |
| `services/Anime.qml` | 39–40 | `~/.local/share/quickshell/anime_library.json` | Anime library file |
| `services/Manga.qml` | 47–48 | `~/.local/share/quickshell/manga_library.json` | Manga library file |
| `services/Novel.qml` | 59–60 | `~/.local/share/quickshell/new_novel_library.json` | Novel library file |
| `scripts/manga_server.py` | 48–50 | `~/.local/share/quickshell-manga` | Manga data/downloads dir |
| `aikira/Api.qml` | 8 | `http://127.0.0.1:7842/api/v1` | Aikira backend port |
| `aikira/Aikira.qml` | 97 | `~/.config/quickshell/scripts/aikira/aikira-stream.py` | Aikira stream script |

---

## Standalone Packages

The anime/manga/novel readers and the wallpaper picker can also run on their own, without the rest of this config, for people who only want those. `packaging/export.sh` builds each one as a separate Quickshell config:

```sh
packaging/export.sh readers [OUT_DIR]      # default ~/quickshell-readers
packaging/export.sh wallpapers [OUT_DIR]   # default ~/quickshell-wallpapers
```

A package keeps this config's folder layout, so its QML files are copied unchanged. On top go `packaging/common/overlay/` and `packaging/<package>/overlay/`: a standalone `shell.qml`, an `install.sh` and README, and small stand-ins for the rice-only parts (desktop themes, backend paths, settings). The script stops if an exported file uses a component that wasn't copied, so a new dependency can't slip out unnoticed. `OUT_DIR` can be the package's own git checkout: everything but `.git` is replaced on each export.

The packages are called **qs-novelmangareader** and **qs-wallpaperpicker**. Their `install.sh` installs the system packages and fonts they need (pacman, apt or dnf), puts the package in `~/.config/<name>`, and puts a `<name>` command on `PATH` (`~/.local/bin`, or `/usr/local/bin` after asking when `~/.local/bin` isn't on `PATH`, which is the default on Arch and in fish) (`qs-wallpaperpicker toggle`, `qs-novelmangareader manga`, …). They run with `qs -p` rather than `qs -c`, because Quickshell ignores every folder under `~/.config/quickshell/` once a `shell.qml` sits there, so they work next to any existing Quickshell config without touching it.

