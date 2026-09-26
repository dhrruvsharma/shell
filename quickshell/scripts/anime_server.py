"""
ani-cli Python API
Browse/search/episode lists come from allanime; streams are resolved the way
ani-cli 5.1 does it (hianime.at / ZokoAnime embed).
Run: pip install flask requests && python ani_api.py
"""

import base64
import html
import json
import re
import threading

import requests
from flask import Flask, jsonify, request

app = Flask(__name__)

AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/121.0"
ALLANIME_REFR = "https://allmanga.to"
ALLANIME_BASE = "allanime.day"
ALLANIME_API = f"https://api.{ALLANIME_BASE}"

HEADERS = {
    "User-Agent": AGENT,
    "Referer": ALLANIME_REFR,
}

# Headers specifically for GraphQL POST requests (need Content-Type)
GQL_HEADERS = {
    "User-Agent": AGENT,
    "Referer": ALLANIME_REFR,
    "Content-Type": "application/json",
}

def gql_post(variables: dict, query: str) -> str:
    """Fire a GraphQL POST request against the allanime API and return raw text.

    The upstream site now requires POST with a JSON body (matching the bash
    script's ``curl -X POST --data '...'`` calls).  The old GET-with-params
    approach no longer works after the Cloudflare / rules change.
    """
    payload = json.dumps({
        "variables": variables,
        "query": query,
    })
    resp = requests.post(
        f"{ALLANIME_API}/api",
        data=payload,
        headers=GQL_HEADERS,
        timeout=15,
    )
    resp.raise_for_status()
    return resp.text


SEARCH_GQL = (
    "query( $search: SearchInput $limit: Int $page: Int "
    "$translationType: VaildTranslationTypeEnumType "
    "$countryOrigin: VaildCountryOriginEnumType ) { "
    "shows( search: $search limit: $limit page: $page "
    "translationType: $translationType countryOrigin: $countryOrigin ) "
    "{ edges { _id name englishName nativeName thumbnail score "
    "availableEpisodes episodeCount __typename } }}"
)


def search_anime(query: str, mode: str = "sub") -> list[dict]:
    """Return list of show dicts including thumbnail, score, and episode counts."""
    variables = {
        "search": {
            "allowAdult": False,
            "allowUnknown": False,
            "query": query,
        },
        "limit": 40,
        "page": 1,
        "translationType": mode,
        "countryOrigin": "ALL",
    }

    payload = json.dumps({
        "variables": variables,
        "query": SEARCH_GQL,
    })
    resp = requests.post(
        f"{ALLANIME_API}/api",
        data=payload,
        headers=GQL_HEADERS,
        timeout=15,
    )
    resp.raise_for_status()

    data = resp.json()
    edges = data.get("data", {}).get("shows", {}).get("edges", [])

    results = []
    seen = set()
    for edge in edges:
        show_id = edge.get("_id")
        if not show_id or show_id in seen:
            continue
        seen.add(show_id)
        available = edge.get("availableEpisodes") or {}
        results.append({
            "id": show_id,
            "name": edge.get("name"),
            "english_name": edge.get("englishName"),
            "native_name": edge.get("nativeName"),
            "thumbnail": edge.get("thumbnail"),
            "score": edge.get("score"),
            "episode_count": edge.get("episodeCount"),
            "available_episodes": {
                "sub": available.get("sub", 0),
                "dub": available.get("dub", 0),
                "raw": available.get("raw", 0),
            },
        })
    return results

EPISODES_LIST_GQL = (
    "query ($showId: String!) { show( _id: $showId ) { _id availableEpisodesDetail }}"
)


def episodes_list(show_id: str, mode: str = "sub") -> list[str]:
    """Return sorted list of available episode strings for a show."""
    payload = json.dumps({
        "variables": {"showId": show_id},
        "query": EPISODES_LIST_GQL,
    })
    resp = requests.post(
        f"{ALLANIME_API}/api",
        data=payload,
        headers=GQL_HEADERS,
        timeout=15,
    )
    resp.raise_for_status()
    raw = resp.text
    m = re.search(r'"' + mode + r'\":\[([0-9.\",]*)\]', raw)
    if not m:
        return []
    eps_raw = m.group(1)
    eps = [e.strip('"') for e in eps_raw.split(",") if e.strip('"')]
    try:
        eps.sort(key=lambda x: float(x))
    except ValueError:
        eps.sort()
    return eps


# ---------------------------------------------------------------------------
# Stream links — mirrors ani-cli 5.1 (hianime.at / ZokoAnime embed)
#
# allanime's episode source API now answers AA_CRYPTO_MISSING, so streams come
# from the ZokoAnime embed that hianime.at uses. That embed is keyed by MAL id
# (zokoanime.video/stream/mal/<mal>/<ep>/<sub|dub>), and allanime still knows
# each show's malId, so browse/search/library IDs stay allanime ones. Shows
# without a malId fall back to ani-cli's route: hianime search → episode list
# → servers → ZokoAnime hash.
# ---------------------------------------------------------------------------
HIANIME_BASE = "https://hianime.at"
ZOKO_BASE = "https://zokoanime.video"
# The embed ships its config as base64(json XOR "otaku-embed-v1")
ZOKO_KEY = b"otaku-embed-v1"
HIANIME_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                  "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
}

SHOW_META_GQL = "query ($showId: String!) { show( _id: $showId ) { _id name englishName malId }}"

_show_meta_cache: dict[str, dict] = {}
_show_meta_lock = threading.Lock()


def _show_meta(show_id: str) -> dict:
    """{name, englishName, malId} for an allanime show, cached per process."""
    with _show_meta_lock:
        if show_id in _show_meta_cache:
            return _show_meta_cache[show_id]
    raw = gql_post({"showId": show_id}, SHOW_META_GQL)
    show = (json.loads(raw).get("data") or {}).get("show") or {}
    meta = {
        "name": show.get("name") or "",
        "englishName": show.get("englishName") or "",
        "malId": str(show.get("malId") or ""),
    }
    with _show_meta_lock:
        _show_meta_cache[show_id] = meta
    return meta


def _deobfuscate_blob(blob: str) -> dict:
    raw = base64.b64decode(blob)
    plain = bytes(b ^ ZOKO_KEY[i % len(ZOKO_KEY)] for i, b in enumerate(raw))
    return json.loads(plain.decode("utf-8"))


def _zoko_links(embed_url: str) -> list[dict]:
    """Resolve a ZokoAnime embed into per-quality HLS links. [] if unavailable."""
    referer = re.sub(r"^(https?://[^/]*).*", r"\1/", embed_url)
    resp = requests.get(embed_url, headers=HIANIME_HEADERS, timeout=15)
    resp.raise_for_status()
    blob_m = re.search(r'window\.__P="([^"]*)"', resp.text)
    if not blob_m:
        return []  # the embed answers 200 without a blob for missing episodes

    cfg = _deobfuscate_blob(blob_m.group(1))
    master = cfg.get("src") or ""
    if ".m3u8" not in master:
        return []

    # Several subtitle languages can be listed; the site marks English as default
    subtitle = next((s.get("src") for s in cfg.get("subtitles") or [] if s.get("default")), None)
    extra = {"referer": referer, **({"subtitle": subtitle} if subtitle else {})}

    links = []
    try:
        m3u8 = requests.get(master, headers={**HIANIME_HEADERS, "Referer": referer}, timeout=15)
        m3u8.raise_for_status()
        base = master.rsplit("/", 1)[0] + "/"
        for sm in re.finditer(r"#EXT-X-STREAM-INF[^\n]*RESOLUTION=\d+x(\d+)[^\n]*\n([^\n]+)", m3u8.text):
            path = sm.group(2).strip()
            links.append({
                "quality": f"{sm.group(1)}p",
                "url": path if path.startswith("http") else base + path,
                "type": "m3u8",
                **extra,
            })
    except requests.RequestException:
        pass
    if not links:
        links.append({"quality": "best", "url": master, "type": "m3u8", **extra})
    return links


def _norm_title(s: str) -> str:
    return re.sub(r"[^a-z0-9]", "", s.lower())


def _hianime_embed(meta: dict, ep_no: str, mode: str) -> str | None:
    """ani-cli's lookup path: search → episode list → ZokoAnime server hash."""
    names = [n for n in (meta["name"], meta["englishName"]) if n]
    if not names:
        return None
    wanted = {_norm_title(n) for n in names}

    cards = []
    for query in names:
        resp = requests.get(f"{HIANIME_BASE}/search", params={"keyword": query},
                            headers=HIANIME_HEADERS, timeout=15)
        resp.raise_for_status()
        # The top-10 sidebar repeats the result markup, cut it off first
        page = resp.text.split('id="main-sidebar"', 1)[0]
        cards = re.findall(
            r'<h3 class="film-name">\s*<a href="[^"]*/([^"/]*)"\s*title="([^"]*)"'
            r'[^>]*?data-jname="([^"]*)"',
            page,
        )
        if cards:
            break
    if not cards:
        return None

    slug = next(
        (c[0] for c in cards
         if _norm_title(html.unescape(c[1])) in wanted or _norm_title(html.unescape(c[2])) in wanted),
        cards[0][0],
    )

    resp = requests.get(f"{HIANIME_BASE}/api/theme/episode/list/{slug.rsplit('-', 1)[-1]}",
                        headers=HIANIME_HEADERS, timeout=15)
    resp.raise_for_status()
    ep_html = resp.json().get("html", "")
    ep_id = next(
        (m.group(2) for m in re.finditer(r'data-number="([^"]*)"\s*data-id="(\d+)"', ep_html)
         if m.group(1) == ep_no),
        None,
    )
    if not ep_id:
        return None

    resp = requests.get(f"{HIANIME_BASE}/api/theme/episode/servers",
                        params={"episodeId": ep_id}, headers=HIANIME_HEADERS, timeout=15)
    resp.raise_for_status()
    servers = resp.json().get("html", "")
    # Only the ZokoAnime embed is understood; the other servers use different players
    hash_m = re.search(
        r'data-type="' + re.escape(mode) + r'"\s*data-server-name="ZokoAnime"\s*data-hash="([^"]*)"',
        servers,
    )
    return base64.b64decode(hash_m.group(1)).decode() if hash_m else None


def get_episode_links(show_id: str, ep_no: str, mode: str = "sub") -> dict:
    """
    Resolve stream links for one episode.
    Returns {providers: {name: [links]}, all_links: [...]}
    """
    meta = _show_meta(show_id)

    links: list[dict] = []
    if meta["malId"]:
        links = _zoko_links(f"{ZOKO_BASE}/stream/mal/{meta['malId']}/{ep_no}/{mode}")
    if not links:
        embed = _hianime_embed(meta, ep_no, mode)
        if embed:
            links = _zoko_links(embed)

    if not links:
        return {"error": f"No {mode} stream found for episode {ep_no}"}

    def quality_key(x):
        m = re.match(r"(\d+)", x.get("quality", ""))
        return int(m.group(1)) if m else 0

    links.sort(key=quality_key, reverse=True)
    all_links = [{**link, "provider": "ZokoAnime"} for link in links]

    return {
        "show_id": show_id,
        "episode": ep_no,
        "mode": mode,
        "providers": {"ZokoAnime": links},
        "all_links": all_links,
    }


LATEST_QUERY_HASH = "a24c500a1b765c68ae1d8dd85174931f661c71369c89b92b88b75a725afc471c"


def _parse_latest_show(edge: dict) -> dict:
    """
    Normalise a single edge from the latest shows response into a clean dict.
    All fields are optional-safe so partial data never raises KeyError.
    """
    last_ep_info = edge.get("lastEpisodeInfo", {})
    last_ep_date = edge.get("lastEpisodeDate", {})
    available = edge.get("availableEpisodes", {})
    season = edge.get("season") or {}
    aired = edge.get("airedStart") or {}

    def ep_str(mode: str) -> str | None:
        info = last_ep_info.get(mode)
        return info.get("episodeString") if info else None

    def ep_date(mode: str) -> dict | None:
        d = last_ep_date.get(mode)
        return d if d else None

    return {
        "id": edge.get("_id"),
        "name": edge.get("name"),
        "english_name": edge.get("englishName"),
        "native_name": edge.get("nativeName"),
        "type": edge.get("type"),
        "thumbnail": edge.get("thumbnail"),
        "score": edge.get("score"),
        "episode_count": edge.get("episodeCount"),
        "episode_duration_ms": edge.get("episodeDuration"),
        "available_episodes": {
            "sub": available.get("sub", 0),
            "dub": available.get("dub", 0),
            "raw": available.get("raw", 0),
        },
        "last_episode": {
            "sub": ep_str("sub"),
            "dub": ep_str("dub"),
        },
        "last_episode_date": {
            "sub": ep_date("sub"),
            "dub": ep_date("dub"),
        },
        "season": {
            "quarter": season.get("quarter"),
            "year": season.get("year"),
        },
        "aired_start": aired if aired else None,
        "last_update": edge.get("lastUpdateEnd"),
    }


def latest_shows(
    limit: int = 26,
    page: int = 1,
    mode: str = "sub",
    country: str = "ALL",
    search: dict | None = None,
) -> dict:
    """
    Fetch recently-updated shows using the persisted query on the allanime API.

    Parameters
    ----------
    limit   : number of results per page (max ~50 before the API ignores extras)
    page    : page number (1-based)
    mode    : "sub" | "dub" | "raw"
    country : "ALL" | "JP" | "CN" | "KR" etc.
    search  : optional extra search fields (e.g. {"query": "one piece"})

    Returns
    -------
    {
        "page": int,
        "limit": int,
        "total": int,          # total shows in the DB matching the filter
        "count": int,          # number of shows in this response
        "shows": [ ... ]
    }
    """
    variables = {
        "search": search or {},
        "limit": limit,
        "page": page,
        "translationType": mode,
        "countryOrigin": country,
    }

    # Persisted queries still use GET with extensions param (hash-based, no query body)
    params = {
        "variables": json.dumps(variables),
        "extensions": json.dumps({
            "persistedQuery": {
                "version": 1,
                "sha256Hash": LATEST_QUERY_HASH,
            }
        }),
    }

    resp = requests.get(
        f"{ALLANIME_API}/api",
        params=params,
        headers=HEADERS,
        timeout=15,
    )
    resp.raise_for_status()

    data = resp.json()

    shows_data = (
        data.get("data", {}).get("shows", {})
        if isinstance(data, dict)
        else {}
    )

    total = shows_data.get("pageInfo", {}).get("total", 0)
    edges = shows_data.get("edges", [])

    return {
        "page": page,
        "limit": limit,
        "total": total,
        "count": len(edges),
        "shows": [_parse_latest_show(e) for e in edges],
    }

POPULAR_QUERY_HASH = "60f50b84bb545fa25ee7f7c8c0adbf8f5cea40f7b1ef8501cbbff70e38589489"


def _parse_popular_show(rec: dict) -> dict:
    """
    Normalise a single recommendation entry from the popular shows response.
    Each entry has an `anyCard` (show details) and a `pageStatus` (view stats).
    """
    card = rec.get("anyCard") or {}
    status = rec.get("pageStatus") or {}

    last_ep_date = card.get("lastEpisodeDate") or {}
    available = card.get("availableEpisodes") or {}
    aired = card.get("airedStart") or {}

    def ep_date(mode: str) -> dict | None:
        d = last_ep_date.get(mode)
        return d if d else None

    return {
        "id": card.get("_id"),
        "name": card.get("name"),
        "english_name": card.get("englishName"),
        "native_name": card.get("nativeName"),
        "thumbnail": card.get("thumbnail"),
        "score": card.get("score"),
        "available_episodes": {
            "sub": available.get("sub", 0),
            "dub": available.get("dub", 0),
            "raw": available.get("raw", 0),
        },
        "last_episode_date": {
            "sub": ep_date("sub"),
            "dub": ep_date("dub"),
        },
        "aired_start": aired if aired else None,
        "views": {
            "total": status.get("views"),
            "range": status.get("rangeViews"),
        },
        "is_manga": status.get("isManga"),
    }


def popular_shows(
    size: int = 20,
    page: int = 1,
    date_range: int = 1,
    allow_adult: bool = False,
    allow_unknown: bool = False,
) -> dict:
    """
    Fetch currently popular anime using the queryPopular persisted query.

    Parameters
    ----------
    size          : results per page (default 20)
    page          : page number, 1-based (default 1)
    date_range    : view-count window in days (default 1 = last 24 h)
    allow_adult   : include adult titles (default False)
    allow_unknown : include unknown-status titles (default False)

    Returns
    -------
    {
        "page": int,
        "size": int,
        "date_range": int,
        "total": int,
        "count": int,
        "shows": [ ... ]
    }
    """
    variables = {
        "type": "anime",
        "size": size,
        "dateRange": date_range,
        "page": page,
        "allowAdult": allow_adult,
        "allowUnknown": allow_unknown,
    }

    # Persisted queries still use GET with extensions param (hash-based, no query body)
    params = {
        "variables": json.dumps(variables),
        "extensions": json.dumps({
            "persistedQuery": {
                "version": 1,
                "sha256Hash": POPULAR_QUERY_HASH,
            }
        }),
    }

    resp = requests.get(
        f"{ALLANIME_API}/api",
        params=params,
        headers=HEADERS,
        timeout=15,
    )
    resp.raise_for_status()

    data = resp.json() if isinstance(resp.json(), dict) else {}
    popular_data = data.get("data", {}).get("queryPopular", {})

    total = popular_data.get("total", 0)
    recommendations = popular_data.get("recommendations", [])

    return {
        "page": page,
        "size": size,
        "date_range": date_range,
        "total": total,
        "count": len(recommendations),
        "shows": [_parse_popular_show(r) for r in recommendations],
    }

def next_ep_countdown(query: str) -> list[dict]:
    """Fetch next episode countdown data from animeschedule.net."""
    base = "https://animeschedule.net"
    q = query.replace(" ", "+")
    try:
        r = requests.get(f"{base}/api/v3/anime", params={"q": q}, headers=HEADERS, timeout=15)
        r.raise_for_status()
        raw = r.text
    except Exception as e:
        return [{"error": str(e)}]

    routes = re.findall(r'"route":"([^"]+)"', raw)
    results = []
    for route in routes:
        try:
            page = requests.get(f"{base}/anime/{route}", headers=HEADERS, timeout=15)
            text = page.text
            next_raw = re.search(r'countdown-time-raw"[^>]*datetime="([^"]*)"', text)
            next_sub = re.search(r'countdown-time"[^>]*datetime="([^"]*)"', text)
            eng_title = re.search(r'english-title">([^<]*)<', text)
            jp_title = re.search(r'main-title"[^>]*>([^<]*)<', text)
            results.append({
                "route": route,
                "english_title": eng_title.group(1) if eng_title else None,
                "japanese_title": jp_title.group(1) if jp_title else None,
                "next_raw_release": next_raw.group(1) if next_raw else None,
                "next_sub_release": next_sub.group(1) if next_sub else None,
                "status": "Ongoing" if next_raw else "Finished",
            })
        except Exception as e:
            results.append({"route": route, "error": str(e)})
    return results


@app.route("/")
def index():
    return jsonify({
        "name": "ani-cli API",
        "endpoints": {
            "GET /search":  "Search for anime. Params: q (required), mode (sub|dub, default sub)",
            "GET /episodes": "List episodes for a show. Params: id (required), mode (sub|dub, default sub)",
            "GET /links":   "Get stream links for an episode. Params: id, ep, mode. Optional: quality (e.g. 1080p, 720p, best, worst)",
            "GET /latest":  (
                "Recently-updated shows. Params: "
                "limit (int, default 26), page (int, default 1), "
                "mode (sub|dub|raw, default sub), "
                "country (ALL|JP|CN|KR…, default ALL), "
                "q (optional search query string)"
            ),
            "GET /popular": (
                "Currently popular anime ranked by views. Params: "
                "size (int, default 20), page (int, default 1), "
                "date_range (int days, default 1), "
                "allow_adult (bool, default false), allow_unknown (bool, default false)"
            ),
            "GET /nextep":  "Next episode countdown. Params: q (required)",
            "GET /health":  "Health check",
        },
        "examples": {
            "search":           "/search?q=blue+lock&mode=sub",
            "episodes":         "/episodes?id=<show_id>&mode=sub",
            "links":            "/links?id=<show_id>&ep=1&mode=sub",
            "links_quality":    "/links?id=<show_id>&ep=5&mode=sub&quality=720p",
            "latest":           "/latest?limit=26&page=1&mode=sub",
            "latest_dub":       "/latest?mode=dub&limit=10",
            "latest_search":    "/latest?q=one+piece",
            "latest_kr":        "/latest?country=KR&limit=20",
            "popular":          "/popular",
            "popular_weekly":   "/popular?date_range=7&size=50",
            "popular_page2":    "/popular?page=2",
            "nextep":           "/nextep?q=one+piece",
        },
    })


@app.route("/health")
def health():
    return jsonify({"status": "ok"})


@app.route("/search")
def search_route():
    """
    GET /search?q=<query>&mode=sub|dub
    Returns list of matching anime with id, title, episode count.
    """
    q = request.args.get("q", "").strip()
    mode = request.args.get("mode", "sub").strip()
    if not q:
        return jsonify({"error": "Missing required param: q"}), 400
    if mode not in ("sub", "dub"):
        return jsonify({"error": "mode must be 'sub' or 'dub'"}), 400
    try:
        results = search_anime(q, mode)
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    return jsonify({"query": q, "mode": mode, "count": len(results), "results": results})


@app.route("/episodes")
def episodes_route():
    """
    GET /episodes?id=<show_id>&mode=sub|dub
    Returns sorted list of available episodes.
    """
    show_id = request.args.get("id", "").strip()
    mode = request.args.get("mode", "sub").strip()
    if not show_id:
        return jsonify({"error": "Missing required param: id"}), 400
    try:
        eps = episodes_list(show_id, mode)
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    return jsonify({"id": show_id, "mode": mode, "count": len(eps), "episodes": eps})


@app.route("/links")
def links_route():
    """
    GET /links?id=<show_id>&ep=<episode>&mode=sub|dub&quality=best
    Returns stream links. quality can be: best, worst, 1080p, 720p, 480p, 360p,
    or any string to grep for.
    """
    show_id = request.args.get("id", "").strip()
    ep_no = request.args.get("ep", "").strip()
    mode = request.args.get("mode", "sub").strip()
    quality = request.args.get("quality", "best").strip()

    if not show_id:
        return jsonify({"error": "Missing required param: id"}), 400
    if not ep_no:
        return jsonify({"error": "Missing required param: ep"}), 400

    try:
        data = get_episode_links(show_id, ep_no, mode)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    if "error" in data:
        return jsonify(data), 404

    all_links = data.get("all_links", [])
    if quality == "best":
        selected = all_links[0] if all_links else None
    elif quality == "worst":
        numeric = [l for l in all_links if re.match(r"\d+", l.get("quality", ""))]
        selected = numeric[-1] if numeric else (all_links[-1] if all_links else None)
    else:
        matched = [l for l in all_links if quality in l.get("quality", "")]
        selected = matched[0] if matched else (all_links[0] if all_links else None)

    # FIX: If selected has an error (shouldn't happen after filtering, but guard anyway)
    if selected and "error" in selected:
        selected = None

    data["selected"] = selected
    data["requested_quality"] = quality
    return jsonify(data)


@app.route("/latest")
def latest_route():
    """
    GET /latest
    Query params:
      limit   (int, default 26)   — results per page
      page    (int, default 1)    — page number
      mode    (str, default sub)  — sub | dub | raw
      country (str, default ALL)  — ALL | JP | CN | KR | …
      q       (str, optional)     — filter by title query
    """
    try:
        limit = int(request.args.get("limit", 26))
        page  = int(request.args.get("page",  1))
    except ValueError:
        return jsonify({"error": "limit and page must be integers"}), 400

    mode    = request.args.get("mode",    "sub").strip()
    country = request.args.get("country", "ALL").strip()
    q       = request.args.get("q",       "").strip()

    if mode not in ("sub", "dub", "raw"):
        return jsonify({"error": "mode must be 'sub', 'dub', or 'raw'"}), 400

    if limit < 1 or limit > 100:
        return jsonify({"error": "limit must be between 1 and 100"}), 400

    if page < 1:
        return jsonify({"error": "page must be >= 1"}), 400

    # Build optional search dict only if a query was supplied
    search_dict = {"query": q} if q else {}

    try:
        result = latest_shows(
            limit=limit,
            page=page,
            mode=mode,
            country=country,
            search=search_dict if search_dict else None,
        )
    except requests.HTTPError as e:
        return jsonify({"error": f"Upstream API error: {e}"}), 502
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    return jsonify(result)


@app.route("/popular")
def popular_route():
    """
    GET /popular
    Query params:
      size          (int,  default 20)    — results per page
      page          (int,  default 1)     — page number
      date_range    (int,  default 1)     — view-count window in days (1=24h, 7=week, 30=month)
      allow_adult   (bool, default false) — include adult titles
      allow_unknown (bool, default false) — include unknown-status titles
    """
    try:
        size       = int(request.args.get("size",       20))
        page       = int(request.args.get("page",        1))
        date_range = int(request.args.get("date_range",  1))
    except ValueError:
        return jsonify({"error": "size, page, and date_range must be integers"}), 400

    def _bool(param: str, default: bool = False) -> bool:
        v = request.args.get(param, "").lower()
        if v in ("1", "true", "yes"):
            return True
        if v in ("0", "false", "no"):
            return False
        return default

    allow_adult   = _bool("allow_adult",   False)
    allow_unknown = _bool("allow_unknown", False)

    if size < 1 or size > 100:
        return jsonify({"error": "size must be between 1 and 100"}), 400
    if page < 1:
        return jsonify({"error": "page must be >= 1"}), 400
    if date_range < 1:
        return jsonify({"error": "date_range must be >= 1"}), 400

    try:
        result = popular_shows(
            size=size,
            page=page,
            date_range=date_range,
            allow_adult=allow_adult,
            allow_unknown=allow_unknown,
        )
    except requests.HTTPError as e:
        return jsonify({"error": f"Upstream API error: {e}"}), 502
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    return jsonify(result)


@app.route("/nextep")
def nextep_route():
    """
    GET /nextep?q=<anime name>
    Returns countdown data for the next episode.
    """
    q = request.args.get("q", "").strip()
    if not q:
        return jsonify({"error": "Missing required param: q"}), 400
    try:
        results = next_ep_countdown(q)
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    return jsonify({"query": q, "results": results})


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="ani-cli Python API server")
    parser.add_argument("--host", default="0.0.0.0", help="Host to bind (default: 0.0.0.0)")
    parser.add_argument("--port", type=int, default=5050, help="Port to listen on (default: 5050)")
    parser.add_argument("--debug", action="store_true", help="Enable Flask debug mode")
    args = parser.parse_args()

    print(f"""
  ┌─────────────────────────────────────────┐
  │          ani-cli Python API             │
  │  http://{args.host}:{args.port}              │
  ├─────────────────────────────────────────┤
  │  GET /search?q=blue+lock               │
  │  GET /episodes?id=<id>                 │
  │  GET /links?id=<id>&ep=1              │
  │  GET /latest                           │
  │  GET /latest?mode=dub&country=JP       │
  │  GET /popular                          │
  │  GET /popular?date_range=7&size=50     │
  │  GET /nextep?q=one+piece              │
  │  GET /                (docs)           │
  └─────────────────────────────────────────┘
""")
    app.run(host=args.host, port=args.port, debug=args.debug)