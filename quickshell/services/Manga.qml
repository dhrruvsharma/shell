pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    readonly property string apiUrl: "http://127.0.0.1:5150"

    // ── Manga list ───────────────────────────────────────────────────────────
    property list<var> mangaList: []
    property bool isFetchingManga: false
    property string mangaError: ""
    property bool hasMoreManga: false
    property int currentOffset: 0
    property int latestPage: 1
    property string currentSearchText: ""
    property string currentOrigin: ""

    // ── Manga detail ─────────────────────────────────────────────────────────
    property var currentManga: null
    property bool isFetchingDetail: false
    property string detailError: ""

    // ── Chapter pages ────────────────────────────────────────────────────────
    property list<var> chapterPages: []
    property bool isFetchingPages: false
    property string pagesError: ""
    property string currentChapterId: ""
    property bool dataSaverMode: false

    // ── Favorites ────────────────────────────────────────────────────────────
    property list<var> favoritesList: []
    property bool isFetchingFavs: false
    property int favNewCount: 0

    // ── Downloads ────────────────────────────────────────────────────────────
    property list<var> downloadsList: []
    property var downloadProgress: ({})

    // ── Library ──────────────────────────────────────────────────────────────
    // Each entry: { id, title, coverUrl, lastReadChapterId, lastReadChapterNum, addedAt }
    property list<var> libraryList: []
    property bool libraryLoaded: false

    readonly property string _libraryPath:
        Quickshell.env("HOME") + "/.local/share/quickshell/manga_library.json"

    // FileView for reading
    FileView {
        id: libraryFile
        path: root._libraryPath
        onLoaded: {
            try {
                var data = JSON.parse(libraryFile.text())
                root.libraryList = Array.isArray(data) ? data : []
            } catch (e) {
                console.warn("[ServiceManga] library parse error:", e)
                root.libraryList = []
            }
            root.libraryLoaded = true
            console.log("[ServiceManga] Library loaded —", root.libraryList.length, "entries")
        }
        onLoadFailed: {
            // File doesn't exist yet — start empty
            root.libraryList = []
            root.libraryLoaded = true
            console.log("[ServiceManga] No library file found, starting fresh")
        }
    }

    // FileView for writing
    FileView {
        id: libraryWriter
        path: root._libraryPath
    }

    function _saveLibrary() {
        libraryWriter.setText(JSON.stringify(root.libraryList, null, 2))
        libraryWriter.save()
    }

    function addToLibrary(manga) {
        // manga must have: id, title, coverUrl
        if (isInLibrary(manga.id)) return
        var entry = {
            id:                  manga.id,
            title:               manga.title,
            coverUrl:            manga.coverUrl,
            lastReadChapterId:   "",
            lastReadChapterNum:  "",
            addedAt:             new Date().toISOString()
        }
        root.libraryList = [entry, ...root.libraryList]
        _saveLibrary()
        console.log("[ServiceManga] Added to library:", manga.title)
    }

    function removeFromLibrary(mangaId) {
        root.libraryList = root.libraryList.filter(function(e) { return e.id !== mangaId })
        _saveLibrary()
        console.log("[ServiceManga] Removed from library:", mangaId)
    }

    function isInLibrary(mangaId) {
        return root.libraryList.some(function(e) { return e.id === mangaId })
    }

    function updateLastRead(mangaId, chapterId, chapterNum) {
        root.libraryList = root.libraryList.map(function(e) {
            if (e.id !== mangaId) return e
            return Object.assign({}, e, {
                lastReadChapterId:  chapterId,
                lastReadChapterNum: chapterNum
            })
        })
        _saveLibrary()
        console.log("[ServiceManga] Last read updated —", mangaId, "ch.", chapterNum)
    }

    function getLibraryEntry(mangaId) {
        for (var i = 0; i < root.libraryList.length; i++) {
            if (root.libraryList[i].id === mangaId) return root.libraryList[i]
        }
        return null
    }

    // Load library as soon as the singleton initialises
    Component.onCompleted: libraryFile.reload()

    // ── Backend server ───────────────────────────────────────────────────────
    property bool serverReady: false

    Process {
        id: serverProcess
        command: [Quickshell.env("HOME") + "/.venv/manga/bin/python3",
            Quickshell.env("HOME") + "/.config/quickshell/scripts/manga_server.py"]
        running: true
        onExited: (code) => {
            console.warn("[ServiceManga] Server exited with code", code, "— restarting")
            serverReady = false
            serverProcess.running = true
        }
    }

    HealthPoller {
        id: healthPoller
        url: root.apiUrl
        onReady: {
            root.serverReady = true
            console.log("[ServiceManga] Backend ready at", root.apiUrl)
            fetchByOrigin("", true)
            fetchFavorites()
            fetchDownloads()
        }
    }

    Timer {
        id: favChecker
        interval: 900000
        repeat: true
        running: root.serverReady && root.favoritesList.length > 0
        onTriggered: checkFavoritesForUpdates()
    }

    Timer {
        id: dlPoller
        interval: 500
        repeat: true
        running: false
        onTriggered: {
            var hasActive = false
            var ids = Object.keys(root.downloadProgress)
            for (var i = 0; i < ids.length; i++) {
                var st = root.downloadProgress[ids[i]].status
                if (st === "downloading" || st === "pending") { hasActive = true; break }
            }
            if (!hasActive) { dlPoller.stop(); return }
            for (var j = 0; j < ids.length; j++) {
                var s = root.downloadProgress[ids[j]].status
                if (s === "downloading" || s === "pending")
                    _pollOne(ids[j])
            }
        }
    }

    // ── HTTP helpers ──────────────────────────────────────────────────────────


    // ── Origin → type mapping ─────────────────────────────────────────────────
    function _originType(origin) {
        if (origin === "ko") return "Manhwa"
        if (origin === "ja") return "Manga"
        if (origin === "zh") return "Manhua"
        return ""
    }

    // ── Browse / Search ───────────────────────────────────────────────────────
    function fetchByOrigin(origin, reset) {
        if (isFetchingManga) return
        if (reset) { mangaList = []; currentOffset = 0; latestPage = 1 }
        currentOrigin = origin
        currentSearchText = ""

        if (origin === "") {
            isFetchingManga = true
            mangaError = ""
            const url = root.apiUrl + "/hot"
            Http.get(url, function(err, body) {
                if (err) { mangaError = "Request failed: " + err; isFetchingManga = false; return }
                _parseMangaResults(body)
            })
        } else if (origin === "latest") {
            if (reset) latestPage = 1
            isFetchingManga = true
            mangaError = ""
            const url = root.apiUrl + "/latest?page=" + latestPage
            Http.get(url, function(err, body) {
                if (err) { mangaError = "Request failed: " + err; isFetchingManga = false; return }
                _parseMangaResults(body)
            })
        } else {
            _doSearch("a", _originType(origin), currentOffset, "Popularity")
        }
    }

    function searchManga(query, reset) {
        if (isFetchingManga) return
        if (reset) { mangaList = []; currentOffset = 0 }
        currentSearchText = query
        _doSearch(query, _originType(currentOrigin), currentOffset, "Best Match")
    }

    function fetchNextMangaPage() {
        if (!hasMoreManga || isFetchingManga) return
        if (currentSearchText.length > 0) {
            _doSearch(currentSearchText, _originType(currentOrigin), currentOffset, "Best Match")
        } else if (currentOrigin === "latest") {
            latestPage++
            fetchByOrigin("latest", false)
        } else {
            _doSearch("a", _originType(currentOrigin), currentOffset, "Popularity")
        }
    }

    function _doSearch(query, type, offset, sort) {
        isFetchingManga = true
        mangaError = ""
        let url = root.apiUrl + "/search?q=" + encodeURIComponent(query)
            + "&offset=" + offset + "&sort=" + encodeURIComponent(sort)
        if (type) url += "&type=" + encodeURIComponent(type)
        Http.get(url, function(err, body) {
            if (err) { mangaError = "Request failed: " + err; isFetchingManga = false; return }
            _parseMangaResults(body)
        })
    }

    function _parseMangaResults(json) {
        try {
            const data = JSON.parse(json)
            if (data.error) { mangaError = data.error; isFetchingManga = false; return }

            const isHot    = Array.isArray(data)
            const isLatest = !isHot && data.nextPage !== undefined
            const items    = isHot ? data : (data.results || [])

            mangaList = [...mangaList, ...items.map(item => ({
                id:       item.id     || "",
                title:    item.title  || "",
                thumbUrl: item.image  || "",
                status:   item.status || "",
                type:     item.type   || "",
                author:   ""
            }))]

            hasMoreManga = isHot ? false : (data.hasMore || false)
            if (!isHot && !isLatest)
                currentOffset = data.nextOffset || (currentOffset + items.length)

            mangaError = ""
        } catch (e) {
            mangaError = "Parse error: " + e
            console.error("[ServiceManga]", e)
        }
        isFetchingManga = false
    }

    // ── Manga detail ──────────────────────────────────────────────────────────
    function fetchMangaDetail(mangaId) {
        if (isFetchingDetail) return
        isFetchingDetail = true
        currentManga = null
        detailError = ""
        const url = root.apiUrl + "/info?id=" + encodeURIComponent(mangaId)
        Http.get(url, function(err, body) {
            if (err) { detailError = "Request failed: " + err; isFetchingDetail = false; return }
            _parseMangaDetail(body)
        })
    }

    function _parseMangaDetail(json) {
        try {
            const data = JSON.parse(json)
            if (data.error) { detailError = data.error; isFetchingDetail = false; return }
            currentManga = {
                id:          data.id          || "",
                title:       data.title       || "",
                description: data.description || "",
                status:      data.status      || "",
                year:        0,
                coverUrl:    data.image       || "",
                authors:     data.authors     || [],
                tags:        data.tags        || [],
                chapters:    (data.chapters   || []).map(ch => ({
                    id:        ch.id        || "",
                    chapter:   ch.chapter   || "",
                    title:     ch.title     || "",
                    pages:     0,
                    group:     "",
                    publishAt: ch.publishAt || ""
                }))
            }
            detailError = ""
        } catch (e) {
            detailError = "Parse error: " + e
            console.error("[ServiceManga]", e)
        }
        isFetchingDetail = false
    }

    // ── Chapter pages ─────────────────────────────────────────────────────────
    function fetchChapterPages(chapterId) {
        if (isFetchingPages) return
        isFetchingPages = true
        currentChapterId = chapterId
        chapterPages = []
        pagesError = ""
        const url = root.apiUrl + "/pages?chapterId=" + encodeURIComponent(chapterId)
        Http.get(url, function(err, body) {
            if (err) { pagesError = "Request failed: " + err; isFetchingPages = false; return }
            _parseChapterPages(body)
        })
    }

    function fetchOfflineChapterPages(chapterId) {
        if (isFetchingPages) return
        isFetchingPages = true
        currentChapterId = chapterId
        chapterPages = []
        pagesError = ""
        const url = root.apiUrl + "/dl/pages?chapterId=" + encodeURIComponent(chapterId)
        Http.get(url, function(err, body) {
            if (err) { pagesError = "Request failed: " + err; isFetchingPages = false; return }
            _parseChapterPages(body)
        })
    }

    function _parseChapterPages(json) {
        try {
            const data = JSON.parse(json)
            if (data.error || !Array.isArray(data)) {
                pagesError = data.error || "Invalid response"
                isFetchingPages = false
                return
            }
            if (data.length === 0) {
                pagesError = "No pages found for this chapter"
                isFetchingPages = false
                return
            }
            chapterPages = data.map((p, idx) => ({
                index:     idx,
                url:       p.img || "",
                localPath: p.img || "",
                ready:     true
            }))
            pagesError = ""
            isFetchingPages = false
        } catch (e) {
            pagesError = "Parse error: " + e
            isFetchingPages = false
        }
    }

    // ── Favorites ─────────────────────────────────────────────────────────────
    function fetchFavorites() {
        if (isFetchingFavs) return
        isFetchingFavs = true
        Http.get(root.apiUrl + "/favorites", function(err, body) {
            isFetchingFavs = false
            if (err) { console.warn("[ServiceManga] favorites fetch failed:", err); return }
            try {
                const data = JSON.parse(body)
                favoritesList = data
                favNewCount = data.filter(f => f.hasNewChapters).length
            } catch (e) {
                console.error("[ServiceManga] favorites parse error:", e)
            }
        })
    }

    function addFavorite(manga) {
        const rawUrl = _extractRawUrl(manga.coverUrl)
        Http.post(root.apiUrl + "/favorites/add",
            { id: manga.id, title: manga.title, imageUrl: rawUrl },
                function(err, body) { if (!err) fetchFavorites() })
    }

    function removeFavorite(mangaId) {
        Http.post(root.apiUrl + "/favorites/remove", { id: mangaId },
                function(err, body) { if (!err) fetchFavorites() })
    }

    function isFavorite(mangaId) {
        return favoritesList.some(f => f.id === mangaId)
    }

    function markChapterSeen(mangaId, chapterId) {
        Http.post(root.apiUrl + "/favorites/mark-seen",
            { id: mangaId, chapterId: chapterId },
                function(err, body) { if (!err) fetchFavorites() })
    }

    function checkFavoritesForUpdates() {
        Http.get(root.apiUrl + "/favorites/check", function(err, body) {
            if (err) { console.warn("[ServiceManga] fav check failed:", err); return }
            try {
                const data = JSON.parse(body)
                if (data.updated && data.updated.length > 0) fetchFavorites()
            } catch (e) {}
        })
    }

    // ── Downloads ─────────────────────────────────────────────────────────────
    function fetchDownloads() {
        Http.get(root.apiUrl + "/dl/list", function(err, body) {
            if (err) { console.warn("[ServiceManga] dl/list failed:", err); return }
            try { downloadsList = JSON.parse(body) }
            catch (e) { console.error("[ServiceManga] dl/list parse error:", e) }
        })
    }

    function startDownload(chapter, manga) {
        const rawCover = _extractRawUrl(manga.coverUrl)
        var dp = Object.assign({}, downloadProgress)
        dp[chapter.id] = { status: "pending", total: 0, done: 0 }
        downloadProgress = dp
        dlPoller.start()
        Http.post(root.apiUrl + "/dl/start", {
            mangaId:      manga.id,
            chapterId:    chapter.id,
            chapterNum:   chapter.chapter,
            chapterTitle: chapter.title,
            mangaTitle:   manga.title,
            rawCoverUrl:  rawCover
        }, function(err, body) {
            if (err) {
                var dp2 = Object.assign({}, downloadProgress)
                dp2[chapter.id] = { status: "error", total: 0, done: 0 }
                downloadProgress = dp2
            }
        })
    }

    function _pollOne(chapterId) {
        Http.get(root.apiUrl + "/dl/progress?chapterId=" + encodeURIComponent(chapterId),
                function(err, body) {
                if (err) return
                try {
                    const prog = JSON.parse(body)
                    var dp = Object.assign({}, downloadProgress)
                    dp[chapterId] = prog
                    downloadProgress = dp
                    if (prog.status === "done") fetchDownloads()
                } catch(e) {}
            })
    }

    function getDownloadProgress(chapterId) {
        return downloadProgress[chapterId] || { status: "not_started", total: 0, done: 0 }
    }

    function deleteDownload(chapterId) {
        Http.post(root.apiUrl + "/dl/delete", { chapterId: chapterId },
                function(err, body) { if (!err) fetchDownloads() })
    }

    // ── Utility ───────────────────────────────────────────────────────────────
    function _extractRawUrl(proxyUrl) {
        const match = proxyUrl.match(/[?&]url=([^&]+)/)
        return match ? decodeURIComponent(match[1]) : proxyUrl
    }

    function downloadMorePages(upTo) {}

    function refreshChapterPages() {
        if (currentChapterId.length === 0) return
        chapterPages = []
        fetchChapterPages(currentChapterId)
    }

    function clearChapterList() {
        if (currentManga)
            currentManga = Object.assign({}, currentManga, { chapters: [] })
    }

    function clearChapterPages() {
        chapterPages = []
        currentChapterId = ""
        pagesError = ""
    }

    function clearMangaList() {
        mangaList = []
        hasMoreManga = false
        currentOffset = 0
        latestPage = 1
        mangaError = ""
    }
}
