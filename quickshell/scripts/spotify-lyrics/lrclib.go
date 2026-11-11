package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"net/http"
	"net/url"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

// lrclibTrack is a track as LRCLIB answers it
type lrclibTrack struct {
	Duration     float64 `json:"duration"`
	Instrumental bool    `json:"instrumental"`
	SyncedLyrics string  `json:"syncedLyrics"`
}

// lyricLine is a line as Spotify answers it, which is what the shell reads
type lyricLine struct {
	StartTimeMs string `json:"startTimeMs"`
	Words       string `json:"words"`
}

// fetchLRCLIB gets tr's synced lyrics from LRCLIB: the exact match by title,
// artist, album and length first, else the closest in length of a search by
// title and artist.
func fetchLRCLIB(ctx context.Context, tr track) (*lyrics, error) {
	if tr.title == "" {
		return nil, failure(kindNotFound, "LRCLIB: no title to look the track up by")
	}
	header := http.Header{"User-Agent": {lrclibAgent}}

	q := url.Values{"track_name": {tr.title}, "artist_name": {tr.artist}}
	if tr.album != "" {
		q.Set("album_name", tr.album)
	}
	if tr.duration > 0 {
		q.Set("duration", strconv.Itoa(int(math.Round(tr.duration))))
	}
	var got lrclibTrack
	err := getJSON(ctx, lrclibURL+"get?"+q.Encode(), header, &got)
	var status httpStatus
	switch {
	case err == nil && got.SyncedLyrics != "":
		return parseLRC(got.SyncedLyrics)
	case err == nil && got.Instrumental:
		return nil, failure(kindNotFound, "LRCLIB: the track is instrumental")
	case err != nil && !(errors.As(err, &status) && status == http.StatusNotFound):
		return nil, lrclibFailure(err)
	}

	// No exact match, or one without synced lyrics: search
	q = url.Values{"track_name": {tr.title}}
	if tr.artist != "" {
		q.Set("artist_name", tr.artist)
	}
	var found []lrclibTrack
	if err := getJSON(ctx, lrclibURL+"search?"+q.Encode(), header, &found); err != nil {
		return nil, lrclibFailure(err)
	}
	best, bestOff := -1, math.Inf(1)
	for i, t := range found {
		if t.SyncedLyrics == "" {
			continue
		}
		off := 0.0
		if tr.duration > 0 {
			off = math.Abs(t.Duration - tr.duration)
		}
		if off < bestOff {
			best, bestOff = i, off
		}
	}
	// Further off than this it's another cut of the song, and out of sync
	if best < 0 || bestOff > 3 {
		return nil, failure(kindNotFound, "LRCLIB has no synced lyrics for this track")
	}
	return parseLRC(found[best].SyncedLyrics)
}

func lrclibFailure(err error) error {
	var status httpStatus
	if errors.As(err, &status) && status == http.StatusTooManyRequests {
		return failure(kindFailed, "LRCLIB is rate limiting lyrics requests")
	}
	return failure(kindFailed, "LRCLIB: %v", err)
}

// An LRC time tag, [mm:ss.xx]
var lrcTag = regexp.MustCompile(`\[(\d+):(\d+(?:\.\d+)?)\]`)

// parseLRC turns LRC text into lines as Spotify gives them. A line may carry
// several time tags (a repeated chorus); tags that aren't times (artist,
// offset, …) are skipped.
func parseLRC(text string) (*lyrics, error) {
	var lines []lyricLine
	var at []int64
	for _, raw := range strings.Split(text, "\n") {
		raw = strings.TrimSpace(raw)
		at = at[:0]
		for {
			m := lrcTag.FindStringSubmatchIndex(raw)
			if m == nil || m[0] != 0 {
				break
			}
			min, _ := strconv.ParseInt(raw[m[2]:m[3]], 10, 64)
			sec, _ := strconv.ParseFloat(raw[m[4]:m[5]], 64)
			at = append(at, min*60_000+int64(math.Round(sec*1000)))
			raw = raw[m[1]:]
		}
		words := strings.TrimSpace(raw)
		for _, ms := range at {
			lines = append(lines, lyricLine{strconv.FormatInt(ms, 10), words})
		}
	}
	if len(lines) == 0 {
		return nil, failure(kindNotFound, "LRCLIB's lyrics have no timed lines")
	}
	sort.SliceStable(lines, func(i, j int) bool {
		a, _ := strconv.ParseInt(lines[i].StartTimeMs, 10, 64)
		b, _ := strconv.ParseInt(lines[j].StartTimeMs, 10, 64)
		return a < b
	})
	b, err := json.Marshal(lines)
	if err != nil {
		return nil, fmt.Errorf("LRCLIB: %w", err)
	}
	return &lyrics{SyncType: "LINE_SYNCED", Lines: b}, nil
}
