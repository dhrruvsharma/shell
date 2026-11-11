pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import qs.services

// Time-synced lyrics for what Spotify is playing. scripts/spotify-lyrics, a
// small Go program, fetches them from Spotify with the sp_dc cookie of your
// Spotify web session, kept in lyrics.json next to shell.qml (git ignores it):
//
//     { "sp_dc": "AQ…" }
//
// and from LRCLIB (lrclib.net) by the track's title, artist, album and length
// when there's no cookie, Spotify refuses it or has no lyrics for the track.
// The media panel sets the cookie (the key by the track's name), or edit the
// file; either way it applies without a restart. The program runs with `go
// run`, which builds it the first time (a few seconds) and reuses that build
// after.
Singleton {
    id: root

    readonly property string spDc: config.sp_dc.trim()
    // What Spotify made of the cookie: "" (not asked yet), "checking", "ok",
    // "refused", "unreachable" (couldn't ask it) or "nogo" (Go isn't
    // installed). A refused cookie isn't tried again until it changes; the
    // lyrics come from LRCLIB meanwhile.
    property string cookieStatus: ""
    // Lyrics no longer need the cookie, LRCLIB standing in without one
    readonly property bool available: true
    // Where the current lyrics came from: "spotify", "lrclib" or ""
    property string source: ""

    property var lines: []
    property bool loaded: false
    property string status
    property string trackid

    onSpDcChanged: {
        cookieStatus = ""
        // Refetch the current track even if it didn't change meanwhile, for
        // Spotify's lyrics to replace LRCLIB's
        trackid = ""
        root.poll()
    }

    FileView {
        id: cookieFile
        path: Quickshell.shellPath("lyrics.json")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        // However the file was made, only you can read it once it's saved here
        onSaved: lockDown.exec(["chmod", "600", path])

        adapter: JsonAdapter {
            id: config
            property string sp_dc: ""
        }
    }

    Process {
        id: lockDown
    }

    // Poll Spotify status every 2 seconds
    Timer {
        interval: 2000
        running: root.available
        repeat: true
        onTriggered: root.poll()
    }

    // A fetch that failed (offline, rate limited, …) is tried again in a
    // minute, then twice as long after each failure, up to 15 minutes.
    Timer {
        id: retryTimer
        interval: 60000
        onTriggered: {
            interval = Math.min(interval * 2, 900000)
            root.trackid = ""
            root.poll()
        }
    }

    Process {
        id: fetcher
        // The track and cookie this run is for, and whether it ran to an exit
        property string forId
        property string forCookie
        // Whether this run asked Spotify (not with a refused cookie)
        property bool usedCookie
        property bool ended

        workingDirectory: Quickshell.shellPath("scripts/spotify-lyrics")
        stdout: StdioCollector { id: fetchOut }
        stderr: StdioCollector { id: fetchErr }

        onExited: {
            ended = true
            root.finishFetch(fetchOut.text, fetchErr.text)
        }
        // Stopped without exiting: `go` never started
        onRunningChanged: {
            if (!running && !ended)
                root.finishFetch("", "couldn't run `go`; is Go installed?")
        }
    }

    // Asks Spotify whether it takes a cookie set in the media panel
    Process {
        id: checker
        property string forCookie
        property bool ended

        workingDirectory: Quickshell.shellPath("scripts/spotify-lyrics")
        stdout: StdioCollector { id: checkOut }
        stderr: StdioCollector { id: checkErr }

        onExited: {
            ended = true
            root.finishCheck(checkOut.text, checkErr.text, true)
        }
        onRunningChanged: {
            if (!running && !ended)
                root.finishCheck("", "", false)
        }
    }

    // Reads Spotify's MPRIS state directly (formerly two playerctl processes
    // every poll).
    function poll() {
        const sp = Media.spotifyPlayer
        if (!sp) {
            root.status = ""
            return
        }
        root.status = sp.playbackState === MprisPlaybackState.Playing ? "Playing"
            : sp.playbackState === MprisPlaybackState.Paused ? "Paused" : "Stopped"

        if (root.status !== "Playing")
            return

        const id = Media.spotifyTrackId()
        // Only fetch if track changed
        if (id && root.trackid !== id) {
            root.trackid = id
            root.loaded = false // Reset while fetching
            root.fetchLyrics()
            console.log("Track ID:", id)
        }
    }

    // Saves a cookie to lyrics.json and asks Spotify whether it takes it. An
    // empty one removes it.
    function setCookie(value) {
        let cookie = String(value).trim()
        // Copied as part of a Cookie header ("sp_dc=AQ…; sp_key=…")
        const named = cookie.match(/(?:^|;)\s*sp_dc=([^;\s]+)/)
        if (named)
            cookie = named[1]
        config.sp_dc = cookie
        cookieFile.writeAdapter()
        root.checkCookie()
    }

    // Asks Spotify whether it takes the cookie, one run at a time: a run that
    // ends after the cookie changed starts the next. The token it buys is
    // cached for the lyrics.
    function checkCookie() {
        if (!root.spDc) {
            root.cookieStatus = ""
            return
        }
        root.cookieStatus = "checking"
        if (checker.running)
            return
        checker.forCookie = root.spDc
        checker.ended = false
        checker.exec({
            command: ["go", "run", ".", "-check"],
            environment: { SP_DC: root.spDc }
        })
    }

    function finishCheck(out, err, started) {
        if (checker.forCookie !== root.spDc) {
            Qt.callLater(root.checkCookie)
            return
        }
        if (!started) {
            console.warn("LyricsService: couldn't run `go`; is Go installed?")
            root.cookieStatus = "nogo"
            return
        }
        const res = root.answer(out, err)
        if (res && !res.error) {
            root.cookieStatus = "ok"
        } else if (res && res.kind === "auth") {
            console.warn("LyricsService:", res.message)
            root.cookieStatus = "refused"
        } else {
            if (res)
                console.warn("LyricsService:", res.message)
            root.cookieStatus = "unreachable"
        }
    }

    // Fetches the current track's lyrics, one run at a time: a run that ends
    // after the track or the cookie changed starts the next.
    function fetchLyrics() {
        if (!root.trackid || fetcher.running)
            return
        const sp = Media.spotifyPlayer
        fetcher.forId = root.trackid
        fetcher.forCookie = root.spDc
        fetcher.usedCookie = root.spDc !== "" && root.cookieStatus !== "refused"
        fetcher.ended = false
        // What LRCLIB finds the track by
        const meta = sp ? [
            "-title", sp.trackTitle || "",
            "-artist", sp.trackArtist || "",
            "-album", sp.trackAlbum || "",
            "-duration", String(sp.lengthSupported && sp.length > 0 ? sp.length : 0)
        ] : []
        // The cookie goes in the environment, which unlike the command line
        // isn't open to every process. It's passed here rather than bound on
        // the Process, which could still hold the old one when a new cookie
        // sets off this fetch. Left out, only LRCLIB is asked.
        fetcher.exec({
            command: ["go", "run", "."].concat(meta, ["--", root.trackid]),
            environment: { SP_DC: fetcher.usedCookie ? root.spDc : "" }
        })
    }

    // Takes in what a run printed: the lyrics, or why there are none.
    function finishFetch(out, err) {
        if (fetcher.forId !== root.trackid || fetcher.forCookie !== root.spDc) {
            // The track or the cookie changed while it ran
            Qt.callLater(root.fetchLyrics)
            return
        }

        const res = root.answer(out, err) || { error: true, kind: "failed" }

        // What Spotify made of the cookie, whoever had the lyrics
        if (fetcher.usedCookie) {
            if (res.source === "spotify") {
                root.cookieStatus = "ok"
            } else if (res.spotify && res.spotify.kind === "auth") {
                console.warn("LyricsService:", res.spotify.message, "- using LRCLIB until the cookie changes")
                root.cookieStatus = "refused"
            } else if (res.spotify && res.spotify.kind === "failed") {
                console.warn("LyricsService: Spotify:", res.spotify.message)
            }
        }

        retryTimer.stop()
        if (!res.error) {
            retryTimer.interval = 60000
            root.source = res.source || ""
            root.lines = res.lines || []
            root.loaded = true
            console.log("Lyrics loaded from", root.source + ":", root.lines.length, "lines")
        } else {
            if (res.kind !== "notfound") {
                if (res.message)
                    console.warn("LyricsService:", res.message)
                retryTimer.restart()
            }
            root.source = ""
            root.lines = []
            root.loaded = true
        }
    }

    // A run's JSON answer, or null (with a warning) when it printed none
    function answer(out, err) {
        try {
            const res = JSON.parse(out)
            if (typeof res.error === "boolean")
                return res
        } catch (e) {}
        console.warn("LyricsService: spotify-lyrics failed:", (err || out).trim())
        return null
    }

    function currentLine(positionSeconds) {
        if (!lines || lines.length === 0)
            return ""

        let posMs = positionSeconds * 1000

        for (let i = lines.length - 1; i >= 0; i--) {
            if (posMs >= parseInt(lines[i].startTimeMs))
                return lines[i].words
        }

        return ""
    }
}
