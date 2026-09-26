pragma Singleton
import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import qs.services

QtObject {
    id: root

    // Local spotify-lyrics-api server (https://github.com/akashrchandran/spotify-lyrics-api).
    // It is optional: until it answers, `available` stays false and the media
    // panel hides the lyrics instead of showing "Loading lyrics..." forever.
    readonly property string apiUrl: "http://localhost:8080/"
    property bool available: false

    property var lines: []
    property bool loaded: false
    property string status
    property string trackid

    // Look for the server once a minute until it shows up
    property Timer probeTimer: Timer {
        interval: 60000
        running: !root.available
        repeat: true
        triggeredOnStart: true
        onTriggered: root.probe()
    }

    onAvailableChanged: {
        if (available) {
            // Refetch the current track even if it didn't change while offline
            trackid = ""
            root.poll()
        }
    }

    // Poll Spotify status every 2 seconds
    property Timer statusPoller: Timer {
        interval: 2000
        running: root.available
        repeat: true
        onTriggered: root.poll()
    }

    // Without a trackid the API answers 400 with {"error": true, "usage": ...},
    // which is enough to tell it apart from anything else on the port
    function probe() {
        let xhr = new XMLHttpRequest();
        xhr.open("GET", apiUrl);
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            try {
                root.available = typeof JSON.parse(xhr.responseText).error === "boolean"
            } catch (e) {
                root.available = false
            }
        }
        xhr.send();
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
            root.fetchLyrics(id)
            console.log("Track ID:", id)
        }
    }

    function fetchLyrics(trackId) {
        if (!trackId || trackId === "")
            return;

        let xhr = new XMLHttpRequest();
        xhr.open("GET", apiUrl + "?trackid=" + trackId);

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            // Ignore answers for a track that is no longer playing
            if (trackId !== root.trackid)
                return

            if (xhr.status === 0) {
                // Server went away; hide lyrics and go back to probing
                root.available = false
                root.loaded = false
                return
            }

            try {
                let data = JSON.parse(xhr.responseText);
                // Error answers (e.g. 404 "lyrics not available") mean no lyrics
                root.lines = xhr.status === 200 ? (data.lines || []) : [];
                console.log("Lyrics loaded:", root.lines.length, "lines");
            } catch(e) {
                console.log("Lyrics parse error:", e);
                root.lines = [];
            }
            root.loaded = true;
        }

        xhr.send();
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