#!/usr/bin/env python3
"""
Novel backend server for QuickShell ServiceNovel.
Scrapes NovelBin and serves clean JSON on http://127.0.0.1:5151

Endpoints:
  GET /search?q=<query>&genre=<genre>&status=<All|Ongoing|Completed>&page=<n>
  GET /info?id=<novel-slug>
  GET /chapter?id=<chapter-slug>
  GET /hot
  GET /latest?page=<n>
  GET /favorites              (list)
  POST /favorites/add         (body: {id, title, imageUrl})
  POST /favorites/remove      (body: {id})
  POST /favorites/mark-seen   (body: {id, chapterId})
  GET /favorites/check        (poll for new chapters)
  GET /dl/list
  GET /dl/progress?chapterId=<id>
  GET /dl/chapter?chapterId=<id>   (offline text pages)
  POST /dl/start              (body: {novelId, chapterId, chapterNum, chapterTitle, novelTitle, rawCoverUrl})
  POST /dl/delete             (body: {chapterId})
  GET /health
"""

import os
import re
import json
import time
import shutil
import threading
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer
from socketserver import ThreadingMixIn
from urllib.parse import urlparse, parse_qs, quote, unquote
from concurrent.futures import ThreadPoolExecutor

# ── Use curl_cffi for browser-grade TLS fingerprinting (bypasses Cloudflare)
# Install: pip install curl_cffi --user
try:
    from curl_cffi.requests import Session as CffiSession
    _session = CffiSession(impersonate="firefox")
    _USE_CFFI = True
    print("[novel-server] Using curl_cffi (Firefox impersonation)")
except ImportError:
    import requests as _requests_mod
    _session = _requests_mod.Session()
    _USE_CFFI = False
    print("[novel-server] curl_cffi not found, falling back to requests (may timeout on Cloudflare)")

PORT       = 5151
BASE       = "https://novelbin.com"
PAGE_LIMIT = 20

# ── Persistent storage ─────────────────────────────────────────────────────
DATA_DIR       = os.path.expanduser("~/.local/share/quickshell-novel")
FAVORITES_FILE = os.path.join(DATA_DIR, "favorites.json")
DOWNLOADS_DIR  = os.path.join(DATA_DIR, "downloads")
os.makedirs(DATA_DIR,      exist_ok=True)
os.makedirs(DOWNLOADS_DIR, exist_ok=True)

HEADERS = {
    "User-Agent":                "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0",
    "Accept":                    "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language":           "en-US,en;q=0.5",
    "Accept-Encoding":           "gzip, deflate, br",
    "Connection":                "keep-alive",
    "Upgrade-Insecure-Requests": "1",
    "Sec-Fetch-Dest":            "document",
    "Sec-Fetch-Mode":            "navigate",
    "Sec-Fetch-Site":            "none",
    "Sec-Fetch-User":            "?1",
    "DNT":                       "1",
}
AJAX_HEADERS = {
    **HEADERS,
    "X-Requested-With": "XMLHttpRequest",
    "Sec-Fetch-Dest":   "empty",
    "Sec-Fetch-Mode":   "cors",
    "Sec-Fetch-Site":   "same-origin",
}

if not _USE_CFFI:
    _session.headers.update(HEADERS)


# ── TTL Cache ──────────────────────────────────────────────────────────────

_cache      = {}
_cache_lock = threading.Lock()

TTL_HOT    = 300
TTL_LATEST = 120
TTL_SEARCH = 600
TTL_INFO   = 1800
TTL_CHAP   = 86400   # chapters rarely change once published


def _cached(key, ttl, fn):
    with _cache_lock:
        entry = _cache.get(key)
    if entry:
        val, expires = entry
        if time.monotonic() < expires:
            return val
    val = fn()
    with _cache_lock:
        _cache[key] = (val, time.monotonic() + ttl)
    return val


# ── Helpers ────────────────────────────────────────────────────────────────

def fetch(url, extra_headers=None, timeout=30):
    headers = {**HEADERS, **(extra_headers or {})}
    if _USE_CFFI:
        r = _session.get(url, headers=headers, timeout=timeout)
    else:
        r = _session.get(url, headers=headers, timeout=timeout)
    r.raise_for_status()
    return r.text


def _raw_get(url, timeout=30):
    """Return raw bytes + content-type (used for cover image proxy)."""
    if _USE_CFFI:
        r = _session.get(url, headers=HEADERS, timeout=timeout)
    else:
        r = _session.get(url, headers=HEADERS, timeout=timeout)
    r.raise_for_status()
    return r.content, r.headers.get("Content-Type", "image/jpeg")


def clean_text(html):
    """Strip all HTML tags and normalise whitespace."""
    text = re.sub(r"<[^>]+>", " ", html)
    text = re.sub(r"&nbsp;", " ", text)
    text = re.sub(r"&amp;",  "&", text)
    text = re.sub(r"&lt;",   "<", text)
    text = re.sub(r"&gt;",   ">", text)
    text = re.sub(r"&quot;", '"', text)
    text = re.sub(r"&#\d+;", "",  text)
    return re.sub(r"\s+", " ", text).strip()


def _slugify(text):
    """
    Convert any string to a novelbin-compatible novelId slug.
    Rules (inferred from site URLs):
      - lowercase everything
      - replace any run of non-alphanumeric characters with a single hyphen
      - strip leading/trailing hyphens
    Examples:
      "Fantasy: God of War"          → "fantasy-god-of-war"
      "Re:Zero"                      → "re-zero"
      "Café au Lait"                 → "caf-au-lait"
      "supreme-warrior-in-the-city"  → "supreme-warrior-in-the-city"
    """
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    return text.strip("-")


def proxy_url(img_url):
    return f"http://127.0.0.1:{PORT}/image?url={quote(img_url, safe='')}"


# ── Search ─────────────────────────────────────────────────────────────────

def search(query, genre=None, status="All", page=1):
    key = f"search:{query}:{genre}:{status}:{page}"
    return _cached(key, TTL_SEARCH, lambda: _search(query, genre, status, page))


def _search(query, genre, status, page):
    # Real URL: /search?keyword=...&page=N
    params = f"keyword={quote(query)}&page={page}"
    if genre:
        params += f"&genre={quote(genre)}"
    if status and status != "All":
        params += f"&status={quote(status)}"

    html    = fetch(f"{BASE}/search?{params}")
    results = []

    # Search results use the same .row / col-xs-3/7/2 layout as /hot and /latest
    for block in re.finditer(
        r'<div class="row">([\s\S]*?)(?=<div class="row">|<div class="pagination|<div id="pagination)',
        html, re.S
    ):
        b = block.group(1)
        if 'novel-title' not in b:
            continue

        title  = re.search(r'class="novel-title"[^>]*>\s*<a[^>]*>([^<]+)</a>', b)
        # Novel slug from the title/cover link — grab the /b/slug part only (no chapter subpath)
        slug_m = re.search(r'href="https://novelbin\.com(/b/[^/"]+)"', b)
        img    = re.search(r'(?:data-src|src)="(https://images\.novelbin\.com/[^"]+)"', b)
        author = re.search(r'class="author"[^>]*>(?:<[^>]+>)*([^<]+)', b)
        chap   = re.search(r'class="[^"]*chapter-title[^"]*"[^>]*>\s*([^<]+)', b)

        if not (title and slug_m):
            continue

        results.append({
            "id":            slug_m.group(1).strip("/"),
            "title":         clean_text(title.group(1)),
            "image":         proxy_url(img.group(1)) if img else "",
            "author":        clean_text(author.group(1)).strip() if author else "",
            "latestChapter": clean_text(chap.group(1)).strip() if chap else "",
        })

    has_next = bool(re.search(r'class="[^"]*next[^"]*"', html))
    return {
        "results":  results,
        "hasMore":  has_next,
        "nextPage": page + 1,
    }


# ── Novel Info + Chapter List ──────────────────────────────────────────────

def info(novel_id):
    return _cached(f"info:{novel_id}", TTL_INFO, lambda: _info(novel_id))


def _info(novel_id):
    # novel_id is like "b/novel-slug" or "b/novel-slug-12345"
    url         = f"{BASE}/b/{novel_id}"
    html        = fetch(url)

    # ── Basic metadata ──
    title_m     = re.search(r'<meta property="og:title" content="([^"]+)"', html)
    cover_m     = re.search(r'<meta property="og:image" content="([^"]+)"', html)
    desc_m      = re.search(
        r'<div[^>]+class="[^"]*novel-detail-body[^"]*"[^>]*>([\s\S]*?)</div>', html
    )
    if not desc_m:
        desc_m  = re.search(
            r'<div[^>]+id="novel-detail[^"]*"[^>]*>[\s\S]*?<p[^>]*>([\s\S]{40,}?)</p>', html
        )

    status_m    = re.search(
        r'<span[^>]*>\s*Status\s*</span>[^<]*<a[^>]*>([^<]+)</a>', html
    )
    author_m    = re.search(
        r'<span[^>]*>\s*Author[^<]*</span>[^<]*<a[^>]*>([^<]+)</a>', html
    )
    genres_raw  = re.findall(
        r'<span[^>]*>\s*Genre[^<]*</span>[\s\S]*?(<ul[\s\S]*?</ul>)', html
    )
    genres      = []
    if genres_raw:
        genres  = [clean_text(g) for g in re.findall(r'<li[^>]*>([^<]+)</li>', genres_raw[0])]

    description = ""
    if desc_m:
        raw_desc = desc_m.group(1)
        # join <p> paragraphs
        paras    = re.findall(r"<p[^>]*>([\s\S]*?)</p>", raw_desc)
        if paras:
            description = "\n\n".join(clean_text(p) for p in paras if clean_text(p))
        else:
            description = clean_text(raw_desc)

    # ── Chapter list via /ajax/chapter-archive?novelId=<slug> ──
    # novelId must be lowercase ASCII with hyphens only — special characters, colons,
    # accented letters, etc. are stripped/replaced just like the site's own URL slugger.
    # e.g. "Fantasy: God of War" → "fantasy-god-of-war"
    novel_slug = _slugify(novel_id.split("/")[-1])

    ch_html = fetch(
        f"{BASE}/ajax/chapter-archive?novelId={novel_slug}",
        extra_headers=AJAX_HEADERS,
    )

    # Real structure (from live HTML):
    # <ul class="list-chapter">
    #   <li><a href="https://novelbin.com/b/novel-slug/chapter-N-title" title="Chapter N Title">
    #         <span class="nchr-text chapter-title">Chapter N Title</span>
    #       </a></li>
    # </ul>
    chapters = []
    for m in re.finditer(
        r'<a\s+href="https://novelbin\.com(/b/[^"]+)"\s+title="([^"]*)"',
        ch_html, re.S
    ):
        full_path = m.group(1).strip("/")   # e.g. b/novel-slug/chapter-1-temporary-bodyguard
        label     = clean_text(m.group(2))
        ch_num_m  = re.search(r'(?:Chapter|Ch\.?)\s*([\d.]+)', label, re.I)
        chapters.append({
            "id":      full_path,           # use as GET /chapter?id=<full_path>
            "title":   label,
            "chapter": ch_num_m.group(1) if ch_num_m else label,
        })

    # Remove duplicates, preserve order
    seen    = set()
    deduped = []
    for c in chapters:
        if c["id"] not in seen:
            seen.add(c["id"])
            deduped.append(c)

    raw_cover = cover_m.group(1) if cover_m else ""
    return {
        "id":          novel_id,
        "title":       clean_text(title_m.group(1)) if title_m else "",
        "description": description,
        "status":      status_m.group(1).strip() if status_m else "",
        "author":      clean_text(author_m.group(1)) if author_m else "",
        "image":       proxy_url(raw_cover) if raw_cover else "",
        "genres":      genres,
        "chapters":    deduped,      # oldest-first from NovelBin
    }


# ── Single Chapter Text ────────────────────────────────────────────────────

def chapter(chapter_id):
    return _cached(f"chapter:{chapter_id}", TTL_CHAP, lambda: _chapter(chapter_id))


def _chapter(chapter_id):
    # chapter_id is the full path: "b/novel-slug/cchapter-N"
    # or occasionally a full https:// URL
    if chapter_id.startswith("http"):
        url = chapter_id
    else:
        url = f"{BASE}/{chapter_id}"

    html = fetch(url)

    # ── Chapter title from the .chr-text span (most accurate) ──
    title_m = re.search(r'<span class="chr-text">\s*([\s\S]*?)\s*</span>', html)
    if not title_m:
        title_m = re.search(r'<title>([^<|]+)', html)

    # ── Content block ──
    # The real structure (confirmed from live HTML):
    #   <div id="chr-content" class="chr-c" style="...">
    #     ...ad divs...
    #     <p>paragraph text</p>
    #     ...more ad divs and <p> tags interleaved...
    #   </div>
    #   <hr class="chr-end">          ← reliable end marker
    #
    # Old approach stopped at the first inner </div> (an ad block).
    # New approach: find the opening of #chr-content, then grab everything
    # up to the first <hr class="chr-end"> that follows it.

    content = ""
    start_m = re.search(r'<div[^>]+id="chr-content"[^>]*>', html)
    if start_m:
        after_open = html[start_m.end():]
        # Everything before the closing hr is our content
        end_m = re.search(r'<hr[^>]+class="[^"]*chr-end[^"]*"', after_open)
        content = after_open[:end_m.start()] if end_m else after_open[:50000]

    paragraphs = []
    if content:
        for raw in re.findall(r"<p[^>]*>([\s\S]*?)</p>", content):
            # Skip ad script containers (they contain <script> or data-format)
            if "<script" in raw or "data-format" in raw:
                continue
            t = clean_text(raw)
            if t:
                paragraphs.append(t)
    else:
        # Fallback: pull every <p> from the full page that looks like prose
        for raw in re.findall(r"<p[^>]*>([\s\S]{20,}?)</p>", html):
            if "<script" in raw or "data-format" in raw:
                continue
            t = clean_text(raw)
            if t and "advertisement" not in t.lower():
                paragraphs.append(t)

    # ── Prev / next — grab the full path, not just the last slug ──
    # The page has two sets of prev/next links (top + bottom nav); id= makes
    # them unique so we only need one match per direction.
    def path_from_href(pattern):
        m = re.search(pattern, html)
        if not m:
            return ""
        href = m.group(1)
        # Return the full path after the domain, e.g. b/novel-slug/cchapter-3
        parsed = urlparse(href)
        return parsed.path.strip("/")

    return {
        "id":         chapter_id,
        "title":      clean_text(title_m.group(1)).strip() if title_m else "",
        "paragraphs": paragraphs,
        "wordCount":  sum(len(p.split()) for p in paragraphs),
        "prevId":     path_from_href(r'<a[^>]+id="prev_chap"[^>]+href="([^"]+)"'),
        "nextId":     path_from_href(r'<a[^>]+id="next_chap"[^>]+href="([^"]+)"'),
    }


# ── Latest Updates ─────────────────────────────────────────────────────────

def latest_updates(page=1):
    return _cached(f"latest:{page}", TTL_LATEST, lambda: _latest_updates(page))


def _latest_updates(page):
    # Real URL: /sort/latest?page=N
    html    = fetch(f"{BASE}/sort/latest?page={page}")
    results = []

    for block in re.finditer(
        r'<div class="row">([\s\S]*?)(?=<div class="row">|<div class="pagination|</div>\s*</div>\s*</div>)',
        html, re.S
    ):
        b = block.group(1)
        if 'novel-title' not in b:
            continue

        title  = re.search(r'class="novel-title"[^>]*>\s*<a[^>]*>([^<]+)</a>', b)
        img    = re.search(r'(?:data-src|src)="(https://images\.novelbin\.com/[^"]+)"', b)
        author = re.search(r'class="author"[^>]*>(?:<[^>]+>)*([^<]+)', b)
        chap   = re.search(r'class="[^"]*chapter-title[^"]*"[^>]*>\s*([^<]+)', b)
        upd    = re.search(r'<time[^>]+datetime="([^"]+)"', b)

        # Novel slug from the title link
        slug_m = re.search(r'href="https://novelbin\.com(/b/[^/"]+)"', b)
        if not (title and slug_m):
            continue

        slug = slug_m.group(1).strip("/")
        results.append({
            "id":            slug,
            "title":         clean_text(title.group(1)),
            "image":         proxy_url(img.group(1)) if img else "",
            "author":        clean_text(author.group(1)).strip() if author else "",
            "latestChapter": clean_text(chap.group(1)).strip() if chap else "",
            "updatedAt":     upd.group(1) if upd else "",
        })

    has_next = bool(re.search(r'class="[^"]*next[^"]*"', html))
    return {
        "results":  results,
        "hasMore":  has_next,
        "nextPage": page + 1,
    }

    has_next = bool(re.search(r'class="[^"]*next[^"]*"', html))
    return {
        "results":  results,
        "hasMore":  has_next,
        "nextPage": page + 1,
    }


# ── Hot / Popular Novels ────────────────────────────────────────────────────

def hot_updates():
    return _cached("hot", TTL_HOT, _hot_updates)


def _hot_updates():
    # Real URL confirmed from site: /sort/top-hot-novel
    html    = fetch(f"{BASE}/sort/top-hot-novel")
    results = []
    seen    = set()

    # Real structure (from live HTML):
    # <div class="row">
    #   <div class="col-xs-3"> <img data-src="...cover..."> </div>
    #   <div class="col-xs-7"> <h3 class="novel-title"><a href="BASE/b/slug">Title</a></h3>
    #                          <span class="author">...</span> </div>
    #   <div class="col-xs-2"> <a href="BASE/b/slug/chapter-N-...">Chapter N...</a> </div>
    # </div>
    for block in re.finditer(
        r'<div class="row">([\s\S]*?)(?=<div class="row">|<div class="pagination|</div>\s*</div>\s*</div>)',
        html, re.S
    ):
        b = block.group(1)

        # Must contain a novel-title to be a real entry
        if 'novel-title' not in b:
            continue

        href  = re.search(r'href="https://novelbin\.com(/b/[^"]+?)"[^>]*>\s*(?:<[^>]+>)*([^<]+)', b)
        img   = re.search(r'(?:data-src|src)="(https://images\.novelbin\.com/[^"]+)"', b)
        title = re.search(r'class="novel-title"[^>]*>\s*<a[^>]*>([^<]+)</a>', b)
        author= re.search(r'class="author"[^>]*>(?:<[^>]+>)*([^<]+)', b)
        chap  = re.search(r'class="[^"]*chapter-title[^"]*"[^>]*>\s*([^<]+)', b)

        if not title:
            continue

        slug = ""
        if href:
            slug = href.group(1).strip("/")
        else:
            # fallback: find any /b/... link
            m = re.search(r'href="https://novelbin\.com(/b/[^/"]+)"', b)
            if m:
                slug = m.group(1).strip("/")

        if not slug or slug in seen:
            continue
        seen.add(slug)

        results.append({
            "id":            slug,
            "title":         clean_text(title.group(1)),
            "image":         proxy_url(img.group(1)) if img else "",
            "author":        clean_text(author.group(1)).strip() if author else "",
            "latestChapter": clean_text(chap.group(1)).strip() if chap else "",
        })

    return results


# ── Favorites ──────────────────────────────────────────────────────────────

_fav_lock = threading.Lock()


def _load_favs():
    with _fav_lock:
        if not os.path.exists(FAVORITES_FILE):
            return []
        with open(FAVORITES_FILE) as f:
            return json.load(f)


def _save_favs(favs):
    with _fav_lock:
        with open(FAVORITES_FILE, "w") as f:
            json.dump(favs, f, indent=2)


def fav_list():
    favs = _load_favs()
    return [{**f, "image": proxy_url(f["image"])} for f in favs]


def fav_add(novel_id, title, raw_image_url):
    favs = _load_favs()
    if any(f["id"] == novel_id for f in favs):
        return {"ok": True}
    favs.append({
        "id":                    novel_id,
        "title":                 title,
        "image":                 raw_image_url,
        "addedAt":               datetime.now(timezone.utc).isoformat(),
        "lastKnownChapterCount": 0,
        "latestSeenChapterId":   "",
        "hasNewChapters":        False,
    })
    _save_favs(favs)
    return {"ok": True}


def fav_remove(novel_id):
    favs = _load_favs()
    _save_favs([f for f in favs if f["id"] != novel_id])
    return {"ok": True}


def fav_mark_seen(novel_id, chapter_id):
    favs = _load_favs()
    for f in favs:
        if f["id"] == novel_id:
            f["latestSeenChapterId"] = chapter_id
            f["hasNewChapters"]      = False
    _save_favs(favs)
    return {"ok": True}


def fav_check():
    favs    = _load_favs()
    updated = []

    def _check_one(fav):
        key = f"info:{fav['id']}"
        with _cache_lock:
            _cache.pop(key, None)
        try:
            data  = info(fav["id"])
            count = len(data.get("chapters", []))
            if count > fav.get("lastKnownChapterCount", 0):
                fav["hasNewChapters"]        = True
                fav["lastKnownChapterCount"] = count
                updated.append({"id": fav["id"], "title": fav["title"], "newCount": count})
            elif not fav.get("hasNewChapters"):
                fav["lastKnownChapterCount"] = count
        except Exception:
            pass

    with ThreadPoolExecutor(max_workers=4) as ex:
        list(ex.map(_check_one, favs))
    _save_favs(favs)
    return {"checked": len(favs), "updated": updated}


# ── Downloads ──────────────────────────────────────────────────────────────

_dl_jobs = {}
_dl_lock = threading.Lock()


def dl_list():
    result = []
    if not os.path.exists(DOWNLOADS_DIR):
        return result
    for nid in sorted(os.listdir(DOWNLOADS_DIR)):
        novel_dir  = os.path.join(DOWNLOADS_DIR, nid)
        novel_meta = os.path.join(novel_dir, "novel_meta.json")
        if not os.path.isdir(novel_dir) or not os.path.exists(novel_meta):
            continue
        with open(novel_meta) as f:
            nm = json.load(f)
        chapters = []
        for cid in sorted(os.listdir(novel_dir)):
            ch_dir  = os.path.join(novel_dir, cid)
            ch_meta = os.path.join(ch_dir, "meta.json")
            if not os.path.isdir(ch_dir) or not os.path.exists(ch_meta):
                continue
            with open(ch_meta) as f:
                chapters.append(json.load(f))
        chapters.sort(key=lambda c: float(c.get("chapterNum", "0") or "0"))
        cover_path = os.path.join(novel_dir, "cover.jpg")
        cover_local = f"file://{cover_path}" if os.path.exists(cover_path) else proxy_url(nm.get("rawCoverUrl", ""))
        result.append({**nm, "image": cover_local, "chapters": chapters})
    return result


def dl_progress(chapter_id):
    with _dl_lock:
        return _dl_jobs.get(chapter_id, {"status": "not_started"})


def dl_start(novel_id, chapter_id, chapter_num, chapter_title, novel_title, raw_cover_url):
    with _dl_lock:
        job = _dl_jobs.get(chapter_id, {})
        if job.get("status") in ("downloading", "done"):
            return {"ok": False, "message": job["status"]}
        _dl_jobs[chapter_id] = {"status": "pending", "done": False, "error": None}
    threading.Thread(
        target=_dl_worker,
        args=(novel_id, chapter_id, chapter_num, chapter_title, novel_title, raw_cover_url),
        daemon=True
    ).start()
    return {"ok": True}


def _dl_worker(novel_id, chapter_id, chapter_num, chapter_title, novel_title, raw_cover_url):
    safe_nid  = re.sub(r"[^a-zA-Z0-9_-]", "_", novel_id.split("/")[-1])
    # chapter_id is a full path like "b/novel-slug/chapter-N-title" — use only the last segment as dir name
    safe_cid  = re.sub(r"[^a-zA-Z0-9_-]", "_", chapter_id.split("/")[-1])
    ch_dir    = os.path.join(DOWNLOADS_DIR, safe_nid, safe_cid)
    os.makedirs(ch_dir, exist_ok=True)

    try:
        with _dl_lock:
            _dl_jobs[chapter_id]["status"] = "downloading"

        data = _chapter(chapter_id)

        with open(os.path.join(ch_dir, "content.json"), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

        with open(os.path.join(ch_dir, "meta.json"), "w") as f:
            json.dump({
                "chapterId":    chapter_id,
                "chapterNum":   chapter_num,
                "title":        chapter_title,
                "novelId":      novel_id,
                "novelTitle":   novel_title,
                "wordCount":    data.get("wordCount", 0),
                "downloadedAt": datetime.now(timezone.utc).isoformat(),
            }, f)

        novel_dir  = os.path.join(DOWNLOADS_DIR, safe_nid)
        novel_meta = os.path.join(novel_dir, "novel_meta.json")
        with open(novel_meta, "w") as f:
            json.dump({"id": novel_id, "title": novel_title,
                       "localId": safe_nid, "rawCoverUrl": raw_cover_url}, f)

        cover_path = os.path.join(novel_dir, "cover.jpg")
        if not os.path.exists(cover_path) and raw_cover_url:
            try:
                body, _ = _raw_get(raw_cover_url, timeout=15)
                with open(cover_path, "wb") as f:
                    f.write(body)
            except Exception:
                pass

        with _dl_lock:
            _dl_jobs[chapter_id]["status"] = "done"
            _dl_jobs[chapter_id]["done"]   = True

    except Exception as e:
        import traceback; traceback.print_exc()
        with _dl_lock:
            _dl_jobs[chapter_id] = {"status": "error", "done": False, "error": str(e)}


def dl_chapter(chapter_id):
    """Return offline chapter content (paragraphs) from disk."""
    safe_cid     = re.sub(r"[^a-zA-Z0-9_-]", "_", chapter_id.split("/")[-1])
    for nid in os.listdir(DOWNLOADS_DIR):
        ch_dir       = os.path.join(DOWNLOADS_DIR, nid, safe_cid)
        content_path = os.path.join(ch_dir, "content.json")
        if os.path.exists(content_path):
            with open(content_path, encoding="utf-8") as f:
                return json.load(f)
    return None


def dl_remove(chapter_id):
    safe_cid = re.sub(r"[^a-zA-Z0-9_-]", "_", chapter_id.split("/")[-1])
    for nid in os.listdir(DOWNLOADS_DIR):
        ch_dir = os.path.join(DOWNLOADS_DIR, nid, safe_cid)
        if os.path.isdir(ch_dir):
            shutil.rmtree(ch_dir)
            novel_dir = os.path.join(DOWNLOADS_DIR, nid)
            remaining = [d for d in os.listdir(novel_dir) if os.path.isdir(os.path.join(novel_dir, d))]
            if not remaining:
                shutil.rmtree(novel_dir)
            with _dl_lock:
                _dl_jobs.pop(chapter_id, None)
            return {"ok": True}
    return {"ok": False, "error": "not found"}


# ── Image byte cache ───────────────────────────────────────────────────────

_img_cache      = {}
_img_cache_lock = threading.Lock()
_img_cache_max  = 400
_img_sem        = threading.Semaphore(8)


def _img_get(url):
    with _img_cache_lock:
        return _img_cache.get(url)


def _img_put(url, body, ctype):
    with _img_cache_lock:
        if len(_img_cache) >= _img_cache_max:
            _img_cache.pop(next(iter(_img_cache)))
        _img_cache[url] = (body, ctype)


def _send_image(handler, body, ctype):
    handler.send_response(200)
    handler.send_header("Content-Type", ctype)
    handler.send_header("Content-Length", str(len(body)))
    handler.send_header("Cache-Control", "public, max-age=86400")
    handler.send_header("Access-Control-Allow-Origin", "*")
    handler.end_headers()
    try:
        handler.wfile.write(body)
    except (BrokenPipeError, ConnectionResetError):
        pass


def proxy_image(handler, img_url):
    cached = _img_get(img_url)
    if cached:
        _send_image(handler, *cached)
        return
    with _img_sem:
        body, ctype = _raw_get(img_url)
    _img_put(img_url, body, ctype)
    _send_image(handler, body, ctype)


# ── HTTP Server ────────────────────────────────────────────────────────────

class ThreadingHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads      = True
    allow_reuse_address = True


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print(f"[novel-server] {fmt % args}")

    def _json(self, data, status=200):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def _error(self, msg, status=500):
        self._json({"error": msg}, status)

    def do_HEAD(self):
        parsed = urlparse(self.path)
        if parsed.path == "/image":
            self.send_response(200)
            self.send_header("Content-Type", "image/jpeg")
            self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        qs     = parse_qs(parsed.query)

        def param(key, default=""):
            return (qs.get(key) or [default])[0]

        try:
            p = parsed.path

            if p == "/hot":
                self._json(hot_updates())

            elif p == "/latest":
                self._json(latest_updates(int(param("page", "1"))))

            elif p == "/search":
                q = param("q")
                if not q:
                    return self._error("missing q", 400)
                self._json(search(
                    q,
                    param("genre") or None,
                    param("status", "All"),
                    int(param("page", "1")),
                ))

            elif p == "/info":
                nid = param("id")
                if not nid:
                    return self._error("missing id", 400)
                self._json(info(nid))

            elif p == "/chapter":
                cid = param("id")
                if not cid:
                    return self._error("missing id", 400)
                # Try offline first
                offline = dl_chapter(cid)
                if offline:
                    self._json(offline)
                else:
                    self._json(chapter(cid))

            elif p == "/image":
                img_url = unquote(param("url"))
                if not img_url:
                    return self._error("missing url", 400)
                proxy_image(self, img_url)

            elif p == "/favorites":
                self._json(fav_list())

            elif p == "/favorites/check":
                self._json(fav_check())

            elif p == "/dl/list":
                self._json(dl_list())

            elif p == "/dl/progress":
                cid = param("chapterId")
                if not cid:
                    return self._error("missing chapterId", 400)
                self._json(dl_progress(cid))

            elif p == "/dl/chapter":
                cid = param("chapterId")
                if not cid:
                    return self._error("missing chapterId", 400)
                data = dl_chapter(cid)
                if data is None:
                    return self._error("not downloaded", 404)
                self._json(data)

            elif p == "/health":
                self._json({"ok": True})

            else:
                self._error("not found", 404)

        except (BrokenPipeError, ConnectionResetError):
            pass
        except Exception as e:
            import traceback; traceback.print_exc()
            self._error(str(e))

    def do_POST(self):
        parsed = urlparse(self.path)
        try:
            length = int(self.headers.get("Content-Length", 0))
            body   = json.loads(self.rfile.read(length)) if length else {}
        except Exception:
            return self._error("bad request body", 400)

        try:
            p = parsed.path

            if p == "/favorites/add":
                nid = body.get("id", "")
                if not nid:
                    return self._error("missing id", 400)
                self._json(fav_add(nid, body.get("title", ""), body.get("imageUrl", "")))

            elif p == "/favorites/remove":
                nid = body.get("id", "")
                if not nid:
                    return self._error("missing id", 400)
                self._json(fav_remove(nid))

            elif p == "/favorites/mark-seen":
                nid = body.get("id", "")
                if not nid:
                    return self._error("missing id", 400)
                self._json(fav_mark_seen(nid, body.get("chapterId", "")))

            elif p == "/dl/start":
                nid = body.get("novelId", "")
                cid = body.get("chapterId", "")
                if not (nid and cid):
                    return self._error("missing novelId or chapterId", 400)
                self._json(dl_start(
                    nid, cid,
                    body.get("chapterNum", ""),
                    body.get("chapterTitle", ""),
                    body.get("novelTitle", ""),
                    body.get("rawCoverUrl", ""),
                ))

            elif p == "/dl/delete":
                cid = body.get("chapterId", "")
                if not cid:
                    return self._error("missing chapterId", 400)
                self._json(dl_remove(cid))

            else:
                self._error("not found", 404)

        except (BrokenPipeError, ConnectionResetError):
            pass
        except Exception as e:
            import traceback; traceback.print_exc()
            self._error(str(e))


def run():
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"[novel-server] Listening on http://127.0.0.1:{PORT} (threaded)")
    server.serve_forever()


if __name__ == "__main__":
    run()
