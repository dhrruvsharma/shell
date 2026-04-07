# QuickShell Config

A feature-complete [Quickshell](https://quickshell.outfoxxed.me/) desktop shell for **Arch Linux + Hyprland**, written entirely in QML. Covers everything from a top bar and control center to an AI chat panel, anime/manga/novel readers, and a Wallhaven wallpaper browser — all within a single shell process.

---

## Table of Contents

1. [Architecture](#architecture)
2. [Top Bar](#top-bar)
3. [Control Center](#control-center)
4. [Panels & Overlays](#panels--overlays)
   - [Launcher](#launcher)
   - [Window Switcher](#window-switcher)
   - [Network Panel](#network-panel)
   - [Media Panel & CAVA](#media-panel--cava)
   - [Calendar](#calendar)
   - [OSD](#osd)
5. [Notes Drawer](#notes-drawer)
6. [Clipboard Manager](#clipboard-manager)
7. [Power Menu](#power-menu)
8. [GitHub Contributions](#github-contributions)
9. [Wallpaper](#wallpaper)
   - [Local Picker](#local-picker)
   - [Wallhaven Browser](#wallhaven-browser)
10. [Media Features](#media-features)
    - [Anime](#anime)
    - [Manga](#manga)
    - [Novel](#novel)
    - [Spotify Lyrics](#spotify-lyrics)
11. [AI Chat](#ai-chat)
    - [Aikira (Character Chat)](#aikira-character-chat)
    - [Ollama Chat](#ollama-chat)
12. [Theming & Colors](#theming--colors)
13. [Settings](#settings)
14. [IPC Reference](#ipc-reference)
15. [Hardcoded Paths](#hardcoded-paths)

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

## Top Bar

`modules/bar/TopBar.qml` — a 42 px strip anchored to the top of the screen.

**Left side:** Workspaces · CPU · Battery · Clock · Bluetooth  
**Center:** Media pill (track info + controls, shown when something is playing)  
**Right side:** Network · Volume · Temperature · Memory · System Tray

---

## Control Center

`modules/control/ControlCenter.qml` — slides in from the left edge (450 px wide).

Contains:
- **Header** — user info / overview
- **Quick Settings** — toggle tiles (Wi-Fi, Bluetooth, Night Light, …)
- **Sliders** — volume and brightness
- **Stats** — CPU / memory / temp graphs
- **Info Section** — uptime, kernel, etc.
- **Power Section** — shutdown, reboot, suspend shortcuts
- **Notifications** — persistent notification list
- **Sink Selector** — PipeWire audio output switcher

**IPC:** `qs ipc call controlCenter changeVisible`

---

## Panels & Overlays

### Launcher

`modules/launcher/LauncherWindow.qml`

Triggered by hovering the **left 2 px edge** of the screen (bottom 600 px) or via IPC. Shows pinned apps and an application grid; pin state is persisted through `SettingsConfig`.

**IPC:** `qs ipc call launcherWindow toggle`

### Window Switcher

`modules/switcher/WindowSwitcher.qml`

Hyprland-aware window switcher with live thumbnails (`WindowThumbnail.qml`) and a search box.

### Network Panel

`modules/network/NetworkPanel.qml`

Two-tab panel (Wi-Fi · Bluetooth). Wi-Fi tab (`WifiPanel.qml`) lists available networks; Bluetooth tab (`BluetoothPanel.qml`) lists paired devices.

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

`Osd/OsdWindow.qml` — On-screen display for volume and brightness changes.

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

`components/PowerMenu.qml` — centered overlay with shutdown, reboot, suspend, and lock actions.

**IPC:** `qs ipc call powerMenu toggle`

---

## GitHub Contributions

`components/GhPopout.qml` — slides in from the **right 2 px edge** of the screen.

Displays a 40-week (280-day) contribution heatmap fetched from the `github-contributions-api.jogruber.de` public API. The username is set in `services/Github.qml` (`author` property). Refreshes every 10 minutes.

---

## Wallpaper

### Local Picker

`modules/wallpaper/Wallpaper.qml`

A horizontal card carousel that reads `~/Pictures/wallpapers/`. Supports `.jpg`, `.jpeg`, `.png`, `.webp`, `.gif`, `.mp4`, `.mkv`, `.mov`, `.webm`. Cards are skewed with a `Matrix4x4` transform and scale up on focus. Selecting a card calls the `setwall` script:

```
~/.local/bin/setwall <path>
```

**IPC:** `qs ipc call wallpaper toggle`

### Wallhaven Browser

`modules/wallpaper/WallhavenPanel.qml` + `services/Wallhaven.qml`

Browses [Wallhaven](https://wallhaven.cc) with full API parameter support: categories, purity, sorting, order, top-range, minimum resolution, aspect ratios, search query, and API key. All options are persisted in `SettingsConfig` and changes trigger an automatic re-fetch. Results load incrementally (pagination). Selecting a wallpaper downloads it to `~/Pictures/wallpapers/` then calls `setwall`.

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

Supports two providers, switchable at runtime from within the UI or via:
```bash
curl -X POST http://127.0.0.1:5151/provider/switch \
  -H 'Content-Type: application/json' \
  -d '{"provider":"freewebnovel"}'
```

| Provider name | Source |
|---|---|
| `novelbin` | novelbin.me |
| `freewebnovel` | freewebnovel.com |

**Setup:**
```bash
python -m venv ~/novel-env
~/novel-env/bin/pip install requests beautifulsoup4
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

Settings include: color scheme, music visualizer toggle, pinned apps, dock visibility / auto-hide / music player display, Wallhaven API parameters, and the app grid layout.

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
| `networkPanel` | `qs ipc call networkPanel changeVisible [wifi\|bluetooth]` | Bottom-right panel |
| `clipboardManager` | `qs ipc call clipboardManager changeVisible` | Centered overlay |
| `powerMenu` | `qs ipc call powerMenu toggle` | Centered overlay |
| `ollamaChat` | `qs ipc call ollamaChat changeVisible` | Centered panel |
| `aikiraChat` | `qs ipc call aikiraChat changeVisible` | Centered panel |
| `launcherWindow` | `qs ipc call launcherWindow toggle` | Left-edge launcher |
| `wallpaper` | `qs ipc call wallpaper toggle` | Local wallpaper picker |
| `visBottom` | `qs ipc call visBottom toggle` | Full-screen CAVA visualizer |

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
| `services/Anime.qml` | 148–149 | `~/ani-env/bin/python3` | Anime Python venv |
| `services/Manga.qml` | 137–138 | `~/.venv/manga/bin/python3` | Manga Python venv |
| `services/Novel.qml` | 144–146 | `~/novel-env/bin/python3` | Novel Python venv |
| `services/LyricsService.qml` | 60 | `http://localhost:8080` | Lyrics API port |
| `services/Anime.qml` | 39–40 | `~/.local/share/quickshell/anime_library.json` | Anime library file |
| `services/Manga.qml` | 47–48 | `~/.local/share/quickshell/manga_library.json` | Manga library file |
| `services/Novel.qml` | 59–60 | `~/.local/share/quickshell/new_novel_library.json` | Novel library file |
| `scripts/manga_server.py` | 48–50 | `~/.local/share/quickshell-manga` | Manga data/downloads dir |
| `services/Wallhaven.qml` | 13–14 | `/home/igris/Pictures/wallpapers` | Wallpaper directory |
| `services/Wallhaven.qml` | 14 | `/home/igris/.local/bin/setwall` | Wallpaper setter script |
| `modules/wallpaper/Wallpaper.qml` | 20 | `/home/igris/.local/bin/setwall '%1'` | Wallpaper setter script |
| `aikira/Api.qml` | 8 | `http://127.0.0.1:7842/api/v1` | Aikira backend port |
| `aikira/Aikira.qml` | 97 | `~/.config/quickshell/scripts/aikira/aikira-stream.py` | Aikira stream script |
