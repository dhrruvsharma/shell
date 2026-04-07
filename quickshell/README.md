# QuickShell — Anime, Manga, Novel & Lyrics Setup Guide

This guide covers setting up the four media features built into this QuickShell config:
**Anime**, **Manga**, **Novel**, and **Spotify Lyrics**. All run on Arch Linux with Hyprland.

---

## Table of Contents

1. [Overview](#overview)
2. [Anime](#anime)
3. [Manga](#manga)
4. [Novel](#novel)
5. [Spotify Lyrics](#spotify-lyrics)
6. [Toggling Panels via IPC](#toggling-panels-via-ipc)

---

## Overview

Each feature is split into two layers:

| Layer | Location | Role |
|---|---|---|
| Python backend server | `scripts/` | Scrapes / proxies data, exposes a local HTTP API |
| QML service + module | `services/` + `modules/` | Consumes the API, stores library state, renders UI |

The services launch their own Python process on startup — no separate daemon management is required unless you want persistent servers independent of QuickShell.

---

## Anime

### How it works

- **Script:** `scripts/anime_server.py`
- **Service:** `services/Anime.qml` — starts the server, polls `http://127.0.0.1:5050/health`
- **Module:** `modules/anime/` — browse, library, detail, stream views

The backend wraps the [AllAnime](https://allanime.day) GraphQL API (the same source used by ani-cli). It resolves stream links from multiple providers and returns direct video URLs for MPV.

### Dependencies

```bash
# Python venv — path is hardcoded in services/Anime.qml
python -m venv ~/ani-env
~/ani-env/bin/pip install flask requests
```

> **Hardcoded path:** `services/Anime.qml` line 148 launches:
> `~/ani-env/bin/python3 ~/.config/quickshell/scripts/anime_server.py`
> If you want a different venv location, edit that path in `services/Anime.qml`.

### Port

`http://127.0.0.1:5050`

### Library storage

Anime library is saved to:
```
~/.local/share/quickshell/anime_library.json
```

---

## Manga

### How it works

- **Script:** `scripts/manga_server.py`
- **Service:** `services/Manga.qml` — starts the server, polls `http://127.0.0.1:5150/health`
- **Module:** `modules/manga/` — browse, library, detail, reader views

The backend scrapes [WeebCentral](https://weebcentral.com). It uses `curl_cffi` for Firefox TLS fingerprinting to bypass Cloudflare, with a fallback to `requests`.

It also handles:
- Favorites with new-chapter detection (checked every 15 minutes)
- Chapter downloads to `~/.local/share/quickshell-manga/downloads/`
- An image proxy at `/image?url=` to bypass CDN user-agent checks

### Dependencies

```bash
# Python venv — path is hardcoded in services/Manga.qml
python -m venv ~/.venv/manga
~/.venv/manga/bin/pip install curl_cffi requests
```

> **Hardcoded path:** `services/Manga.qml` line 137 launches:
> `~/.venv/manga/bin/python3 ~/.config/quickshell/scripts/manga_server.py`
> Edit that line if your venv is elsewhere.

### Port

`http://127.0.0.1:5150`

### Data storage

| Path | Contents |
|---|---|
| `~/.local/share/quickshell-manga/favorites.json` | Favorites list |
| `~/.local/share/quickshell-manga/downloads/` | Downloaded chapters |
| `~/.local/share/quickshell/manga_library.json` | In-shell reading library |

---

## Novel

### How it works

- **Script:** `scripts/novel_server/` (entry point: `main.py`)
- **Service:** `services/Novel.qml` — starts the server, polls `http://127.0.0.1:5151/health`
- **Module:** `modules/novel/` — browse, library, detail, reader views

The backend supports two providers switchable at runtime:

| Provider name | Label | Source |
|---|---|---|
| `novelbin` | NovelBin | novelbin.me |
| `freewebnovel` | FreeWebNovel | freewebnovel.com |

Switch providers from within the UI or via:
```bash
curl -X POST http://127.0.0.1:5151/provider/switch -H 'Content-Type: application/json' -d '{"provider":"freewebnovel"}'
```

Features include favorites, offline chapter downloads, and a local image proxy.

### Dependencies

```bash
# Python venv — path is hardcoded in services/Novel.qml
python -m venv ~/novel-env
~/novel-env/bin/pip install requests beautifulsoup4
```

> **Hardcoded path:** `services/Novel.qml` line 144-146 launches:
> `~/novel-env/bin/python3 ~/.config/quickshell/scripts/novel_server/main.py`
> Edit those lines if your venv path differs.

> **Note:** The novel server cache files use Python 3.14 `__pycache__` bytecode. If you are on Python 3.12 or earlier, the cache will simply be regenerated — no action needed.

### Port

`http://127.0.0.1:5151`

### Library storage

```
~/.local/share/quickshell/new_novel_library.json
```

---

## Spotify Lyrics

### How it works

- **Service:** `services/LyricsService.qml`

The service polls `playerctl -p spotify status` every 2 seconds. When a track changes, it fetches synced lyrics from a local lyrics API server by Spotify track ID.

The lyrics API used is **[spotify-lyrics-api](https://github.com/akashrchandran/spotify-lyrics-api)** — a self-hosted server that fetches time-synced lyrics from Spotify's internal API.

### Setup

1. Clone and run the lyrics API server (see its README for full instructions):

```bash
git clone https://github.com/akashrchandran/spotify-lyrics-api
cd spotify-lyrics-api
# follow its setup instructions — requires a Spotify sp_dc cookie
```

2. The service expects the API at **`http://localhost:8080`** — this is hardcoded in `services/LyricsService.qml` line 60:
```
xhr.open("GET", "http://localhost:8080/?trackid=" + trackId);
```
If you run the lyrics server on a different port, update that line.

3. Ensure `playerctl` is installed:
```bash
sudo pacman -S playerctl
```

---

## Toggling Panels via IPC

All panels are controlled through QuickShell's `IpcHandler` system. Use `qs ipc call` from a terminal or bind the commands in your Hyprland config.

### Available IPC targets

| Panel | IPC Target | Toggle command |
|---|---|---|
| Anime | `animePlayer` | `qs ipc call animePlayer toggle` |
| Manga | `mangaReader` | `qs ipc call mangaReader toggle` |
| Novel | `novelReader` | `qs ipc call novelReader toggle` |
| Media panel | `mediaPanel` | `qs ipc call mediaPanel toggle` |
| Control Center | `controlCenter` | `qs ipc call controlCenter changeVisible` |

### Example Hyprland keybindings (`hyprland.conf`)

```ini
bind = $mod, A, exec, qs ipc call animePlayer toggle
bind = $mod, M, exec, qs ipc call mangaReader toggle
bind = $mod, N, exec, qs ipc call novelReader toggle
```

### How the panels are loaded (`shell.qml`)

Each panel uses a `Loader` with `active: false` by default so it costs nothing until first opened. When the IPC handler fires:

1. If `active` is `false` → sets `active = true` then `visible = true`
2. If already active → toggles `visible`

When closed, a 600 ms timer fires that sets `active = false` again, fully unloading the component.

```
Anime   → animeLoader   (anchored: left, top, bottom)
Manga   → mangaLoader   (anchored: left, top, bottom)
Novel   → novelLoader   (anchored: right, top, bottom)
```

---

## Quick Reference: Hardcoded Paths

| File | Line(s) | Hardcoded path | What to change |
|---|---|---|---|
| `services/Anime.qml` | 148–149 | `~/ani-env/bin/python3` | Anime Python venv location |
| `services/Manga.qml` | 137–138 | `~/.venv/manga/bin/python3` | Manga Python venv location |
| `services/Novel.qml` | 144–146 | `~/novel-env/bin/python3` | Novel Python venv location |
| `services/LyricsService.qml` | 60 | `http://localhost:8080` | Lyrics API port |
| `services/Anime.qml` | 39–40 | `~/.local/share/quickshell/anime_library.json` | Anime library file |
| `services/Manga.qml` | 47–48 | `~/.local/share/quickshell/manga_library.json` | Manga library file |
| `services/Novel.qml` | 59–60 | `~/.local/share/quickshell/new_novel_library.json` | Novel library file |
| `scripts/manga_server.py` | 48–50 | `~/.local/share/quickshell-manga` | Manga data/downloads dir |
