import Quickshell
import Quickshell.Io
import QtCore
import QtQml
import qs.settings

pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root

    readonly property string wallpaperDir: WallpaperEngine.dir
    property string scheme: "material"
    property string theme: "dark"

    property string currentSearchText: ""
    property string _pendingDownloadPath: ""
    property string downloadingWallpaperId: ""
    // 0..1 while a download runs (from curl's progress bar).
    property real downloadProgress: 0
    property string downloadError: ""

    // Where a result is (or would be) saved.
    function savePathFor(wallpaper) {
        const ext = wallpaper.fullUrl.split('.').pop().split('?')[0] || "jpg"
        return root.wallpaperDir + "/" + wallpaper.id + "." + ext
    }

    // ── Online / Wallhaven ──────────────────────────────────────────────────
    property list<var> onlineWallpapers: []
    property bool isFetchingOnline: false
    property int  onlinePage: 1
    property bool hasMorePages: false
    property string _fetchBuffer: ""
    property bool _discardFetch: false
    // A new search arrived while one was in flight: it starts once that
    // one has stopped.
    property bool _restartFetch: false
    // Random order pages through one shuffle only with the seed page 1 gave.
    property string _seed: ""
    property string onlineError: ""

    // ── React to SettingsConfig changes and re-fetch ────────────────────────
    Connections {
        target: SettingsConfig
        function onWallhavenCategoriesChanged() { root.fetchWallhaven(true) }
        function onWallhavenPurityChanged()      { root.fetchWallhaven(true) }
        function onWallhavenSortingChanged()     { root.fetchWallhaven(true) }
        function onWallhavenOrderChanged()       { root.fetchWallhaven(true) }
        function onWallhavenTopRangeChanged()    { root.fetchWallhaven(true) }
        function onWallhavenAtleastChanged()     { root.fetchWallhaven(true) }
        function onWallhavenRatiosChanged()      { root.fetchWallhaven(true) }
        function onWallhavenApiKeyChanged()      { root.fetchWallhaven(true) }
    }

    // No fetch at startup: the wallpaper picker asks when its Wallhaven tab
    // is first opened.

    function buildWallhavenUrl(page) {
        const p = []
        p.push("categories=" + SettingsConfig.wallhavenCategories)
        p.push("purity="     + SettingsConfig.wallhavenPurity)
        p.push("sorting="    + SettingsConfig.wallhavenSorting)
        p.push("order="      + SettingsConfig.wallhavenOrder)
        if (SettingsConfig.wallhavenSorting === "toplist")
            p.push("topRange=" + SettingsConfig.wallhavenTopRange)
        if (SettingsConfig.wallhavenAtleast.length > 0)
            p.push("atleast=" + SettingsConfig.wallhavenAtleast)
        if (SettingsConfig.wallhavenRatios.length > 0)
            p.push("ratios=" + SettingsConfig.wallhavenRatios)
        if (currentSearchText.length > 0)
            p.push("q=" + encodeURIComponent(currentSearchText))
        if (SettingsConfig.wallhavenSorting === "random" && page > 1 && _seed.length > 0)
            p.push("seed=" + _seed)
        if (SettingsConfig.wallhavenApiKey.trim().length > 0)
            p.push("apikey=" + encodeURIComponent(SettingsConfig.wallhavenApiKey.trim()))
        p.push("page=" + page)
        return "https://wallhaven.cc/api/v1/search?" + p.join("&")
    }

    function fetchWallhaven(resetPage) {
        if (resetPage) {
            // Before the list: emptying it looks like reaching its end to
            // the picker, which would fetch the next page (of this search,
            // before its first).
            hasMorePages = false
            onlinePage = 1
            _seed = ""
            onlineWallpapers = []
            onlineError = ""
            // The fetch in flight is for the old search: dropped, and this
            // one started when it stops.
            if (isFetchingOnline) {
                _restartFetch = true
                _discardFetch = true
                wallhavenFetcher.running = false
                return
            }
        } else if (isFetchingOnline) {
            return
        }
        isFetchingOnline = true
        onlineError = ""
        _fetchBuffer = ""
        const url = buildWallhavenUrl(onlinePage)
        console.log("[ServiceWallpaper] Fetching Wallhaven page", onlinePage, "–", url)
        wallhavenFetcher.command = ["curl", "-s", url]
        wallhavenFetcher.running = true
    }

    function _parseWallhavenResults(json) {
        try {
            const data = JSON.parse(json)

            if (data.error) {
                onlineError = data.error
                console.error("[ServiceWallpaper] Wallhaven API error:", data.error)
                isFetchingOnline = false
                return
            }

            const items = data.data || []
            const meta  = data.meta || {}

            const parsed = items.map(item => ({
                id:         item.id,
                thumbUrl:   item.thumbs.large,
                fullUrl:    item.path,
                resolution: item.resolution,
                fileType:   item.file_type,
                fileSize:   item.file_size || 0,
                favorites:  item.favorites || 0,
                // The image's main colours (for the picker's swatch cards).
                colors:     item.colors || []
            }))

            onlineWallpapers = (onlinePage === 1)
                ? parsed
                : [...onlineWallpapers, ...parsed]

            if (onlinePage === 1)
                _seed = meta.seed || ""
            hasMorePages = (meta.current_page || 1) < (meta.last_page || 1)
            onlineError = ""
            console.log("[ServiceWallpaper] Wallhaven: got", parsed.length,
                "wallpapers, page", meta.current_page, "/", meta.last_page)
        } catch (e) {
            const msg = json.trim()
            onlineError = msg.length > 0 ? msg : "Failed to parse response"
            console.error("[ServiceWallpaper] Wallhaven parse error:", e, "| body:", msg)
        }
        isFetchingOnline = false
    }

    function fetchNextPage() {
        if (!hasMorePages || isFetchingOnline) return
        onlinePage++
        fetchWallhaven(false)
    }

    // Back to a blank search (the picker calls this when it's destroyed, so
    // it opens fresh). A fetch in flight is stopped and its result dropped.
    function resetSearch() {
        _restartFetch = false
        if (isFetchingOnline) {
            _discardFetch = true
            wallhavenFetcher.running = false
        }
        _seed = ""
        // Before the list: emptying it looks like reaching its end to the
        // picker, which would fetch the next page.
        hasMorePages = false
        currentSearchText = ""
        onlineWallpapers = []
        onlinePage = 1
        onlineError = ""
    }

    function updateSearch(searchText) {
        currentSearchText = searchText
        fetchWallhaven(true)
    }

    function downloadAndSetWallpaper(wallpaper) {
        if (_pendingDownloadPath.length > 0) {
            console.warn("[ServiceWallpaper] Download already in progress")
            return
        }
        const savePath = savePathFor(wallpaper)
        _pendingDownloadPath = savePath
        downloadingWallpaperId = wallpaper.id
        downloadProgress = 0
        downloadError = ""
        console.log("[ServiceWallpaper] Downloading wallpaper", wallpaper.id, "->", savePath)
        // Into a .part file (which the local list ignores) renamed when done,
        // so a half-written image never shows up as a wallpaper.
        wallhavenDownloader.command = [
            "bash", "-c",
            "mkdir -p \"$1\" && curl -L --fail --progress-bar \"$2\" -o \"$3.part\" && mv \"$3.part\" \"$3\" || { rm -f \"$3.part\"; exit 1; }",
            "bash", root.wallpaperDir, wallpaper.fullUrl, savePath
        ]
        wallhavenDownloader.running = true
    }
    // ── End Online ──────────────────────────────────────────────────────────

    // ── Wallhaven processes ─────────────────────────────────────────────────
    Process {
        id: wallhavenFetcher
        stdout: SplitParser {
            onRead: line => { root._fetchBuffer += line }
        }
        onExited: (exitCode) => {
            if (root._discardFetch) {
                root._discardFetch = false
                root.isFetchingOnline = false
                root._fetchBuffer = ""
                if (root._restartFetch) {
                    root._restartFetch = false
                    root.fetchWallhaven(false)
                }
                return
            } else if (exitCode === 0) {
                root._parseWallhavenResults(root._fetchBuffer)
            } else {
                root.onlineError = "Network error — check your connection (curl exit " + exitCode + ")"
                console.error("[ServiceWallpaper] Wallhaven curl failed, exit:", exitCode)
                root.isFetchingOnline = false
            }
            root._fetchBuffer = ""
        }
    }

    Process {
        id: wallhavenDownloader
        // curl's progress bar redraws "###   42.3%" with carriage returns.
        stderr: SplitParser {
            splitMarker: "\r"
            onRead: data => {
                const m = data.match(/([0-9]+(?:\.[0-9]+)?)%/)
                if (m)
                    root.downloadProgress = Math.min(1, parseFloat(m[1]) / 100)
            }
        }
        onExited: (exitCode) => {
            if (exitCode === 0) {
                console.log("[ServiceWallpaper] Download complete:", root._pendingDownloadPath)
                root.downloadProgress = 1
                WallpaperEngine.set(root._pendingDownloadPath)
            } else {
                root.downloadError = "Download failed (curl exit " + exitCode + ")"
                console.error("[ServiceWallpaper] Download failed for:", root._pendingDownloadPath)
            }
            root._pendingDownloadPath = ""
            root.downloadingWallpaperId = ""
        }
    }
    // ── End Wallhaven processes ─────────────────────────────────────────────
}
