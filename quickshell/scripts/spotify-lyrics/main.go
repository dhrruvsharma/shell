// Command spotify-lyrics prints the time-synced lyrics of a Spotify track as
// JSON, for services/LyricsService.qml:
//
//	SP_DC=<cookie> go run . [-title T -artist A -album B -duration S] <track id>
//
// It asks Spotify first, when there's a cookie; when Spotify has no lyrics,
// refuses the cookie or can't be reached, it falls back to LRCLIB
// (lrclib.net, free and keyless), which finds the track by the title, artist,
// album and length (in seconds) given. Without a cookie it asks LRCLIB only.
// Lyrics Spotify has without times ("syncType": "UNSYNCED", every line at 0)
// only stand when LRCLIB has none that are synced.
//
// With -check in place of the track it only makes sure Spotify takes the
// cookie, for the media panel to say so when it's set there.
//
// It asks Spotify the way the web player does, as the spotify-lyrics-api
// server it replaces did: the sp_dc cookie of a logged-in open.spotify.com
// buys an access token, and the token buys the lyrics. A token lasts an
// hour, so it's kept in ~/.cache/quickshell/spotify-token.json and most runs
// make a single request.
//
// It prints one line, either
//
//	{"error": false, "source": "spotify", "syncType": "LINE_SYNCED", "lines": [{"startTimeMs": "1230", "words": "…", …}, …]}
//
// ({"error": false} for -check) or, exiting 1,
//
//	{"error": true, "kind": "…", "message": "…"}
//
// where kind is "auth" (no sp_dc, or Spotify refused it; -check only),
// "notfound" (neither Spotify nor LRCLIB has synced lyrics for the track) or
// "failed" (anything else, worth another try later). source is "spotify" or
// "lrclib". Whenever Spotify was asked and its lyrics aren't the ones given,
// either answer also has
//
//	"spotify": {"kind": "…", "message": "…"}
//
// so the shell learns of a refused cookie even when LRCLIB stood in. There
// kind can also be "unsynced": Spotify took the cookie, but LRCLIB had the
// lyrics synced and Spotify didn't.
package main

import (
	"context"
	"crypto/hmac"
	"crypto/sha1"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

const (
	serverTimeURL = "https://open.spotify.com/api/server-time"
	tokenURL      = "https://open.spotify.com/api/token"
	lyricsURL     = "https://spclient.wg.spotify.com/color-lyrics/v2/track/"
	// The web player's TOTP secrets, which Spotify rotates now and then. This
	// list keeps up with them (spotify-lyrics-api reads it too).
	secretsURL = "https://raw.githubusercontent.com/xyloflake/spot-secrets-go/refs/heads/main/secrets/secretDict.json"

	lrclibURL = "https://lrclib.net/api/"
	// LRCLIB asks clients to name themselves
	lrclibAgent = "quickshell-lyrics"

	userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
)

// How a fetch failed, for the shell to decide what to do next.
const (
	kindAuth     = "auth"     // no sp_dc, or Spotify refused it: wait for a new one
	kindNotFound = "notfound" // Spotify has no lyrics for the track
	kindFailed   = "failed"   // anything else: try again later
)

type fetchError struct{ kind, msg string }

func (e *fetchError) Error() string { return e.msg }

func failure(kind, format string, a ...any) error {
	return &fetchError{kind, fmt.Sprintf(format, a...)}
}

var (
	// Spotify turning down the cookie: it answers 401, or with an anonymous
	// token. (A bad TOTP gets a 400.)
	errCookieRefused = failure(kindAuth, "Spotify refused the sp_dc cookie (expired, or not copied whole?)")
	// Spotify turning down an access token, which a cached one can be.
	errTokenRefused = failure(kindFailed, "Spotify refused the access token")
)

var trackIDPattern = regexp.MustCompile(`^[0-9A-Za-z]{22}$`)

type lyrics struct {
	SyncType string          `json:"syncType"`
	Lines    json.RawMessage `json:"lines"`
}

// The syncType of lyrics that aren't timed to the song, and what's said of
// Spotify when its lyrics were passed over for being so
const (
	syncNone     = "UNSYNCED"
	kindUnsynced = "unsynced"
)

// track is what LRCLIB finds a track by
type track struct {
	title, artist, album string
	duration             float64 // seconds, 0 if unknown
}

func main() {
	var tr track
	flag.StringVar(&tr.title, "title", "", "the track's title, for LRCLIB")
	flag.StringVar(&tr.artist, "artist", "", "the track's artist, for LRCLIB")
	flag.StringVar(&tr.album, "album", "", "the track's album, for LRCLIB")
	flag.Float64Var(&tr.duration, "duration", 0, "the track's length in seconds, for LRCLIB")
	flag.Usage = func() {
		fmt.Fprintln(os.Stderr, "usage: SP_DC=<cookie> spotify-lyrics [-title T -artist A -album B -duration S] <track id> | -check")
	}
	// -check isn't a flag (it predates them), so it's picked out first
	if len(os.Args) == 2 && os.Args[1] == "-check" {
		run(func(ctx context.Context, spDC string, answer map[string]any) error {
			return check(ctx, spDC)
		})
	}
	flag.Parse()
	if flag.NArg() != 1 {
		flag.Usage()
		os.Exit(2)
	}
	run(func(ctx context.Context, spDC string, answer map[string]any) error {
		return fetchAny(ctx, spDC, flag.Arg(0), tr, answer)
	})
}

// run does the job, prints its answer and exits.
func run(job func(ctx context.Context, spDC string, answer map[string]any) error) {
	spDC := strings.TrimSpace(os.Getenv("SP_DC"))
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	answer := map[string]any{"error": false}
	err := job(ctx, spDC, answer)
	cancel()

	out := json.NewEncoder(os.Stdout)
	if err != nil {
		kind := kindFailed
		var fe *fetchError
		if errors.As(err, &fe) {
			kind = fe.kind
		}
		answer["error"], answer["kind"], answer["message"] = true, kind, err.Error()
		out.Encode(answer)
		os.Exit(1)
	}
	out.Encode(answer)
	os.Exit(0)
}

// fetchAny gets trackID's lyrics from Spotify when there's a cookie, else (or
// when that fails, or its lyrics aren't synced) from LRCLIB, filling them
// into answer.
func fetchAny(ctx context.Context, spDC, trackID string, tr track, answer map[string]any) error {
	var spErr error
	var unsynced *lyrics
	if spDC != "" {
		lyr, err := fetch(ctx, spDC, trackID)
		switch {
		case err == nil && lyr.SyncType != syncNone:
			answer["source"], answer["syncType"], answer["lines"] = "spotify", lyr.SyncType, lyr.Lines
			return nil
		case err == nil:
			// The words without their times: LRCLIB may have them timed
			unsynced = lyr
		default:
			spErr = err
			answer["spotify"] = map[string]any{"kind": kindOf(err), "message": err.Error()}
		}
	}

	lyr, err := fetchLRCLIB(ctx, tr)
	if err == nil {
		answer["source"], answer["syncType"], answer["lines"] = "lrclib", lyr.SyncType, lyr.Lines
		if unsynced != nil {
			answer["spotify"] = map[string]any{"kind": kindUnsynced, "message": "Spotify's lyrics for this track aren't synced"}
		}
		return nil
	}
	if unsynced != nil {
		answer["source"], answer["syncType"], answer["lines"] = "spotify", unsynced.SyncType, unsynced.Lines
		return nil
	}
	// Worth another try later if either might do better then
	if spErr != nil && kindOf(spErr) == kindFailed && kindOf(err) == kindNotFound {
		return spErr
	}
	return err
}

func kindOf(err error) string {
	var fe *fetchError
	if errors.As(err, &fe) {
		return fe.kind
	}
	return kindFailed
}

// check makes sure Spotify takes spDC: a token it bought before will do, else
// it buys one, which is then cached for the lyrics.
func check(ctx context.Context, spDC string) error {
	_, _, err := accessToken(ctx, spDC, true)
	return err
}

// fetch gets the lyrics of trackID, buying an access token with spDC when the
// cached one won't do.
func fetch(ctx context.Context, spDC, trackID string) (*lyrics, error) {
	if !trackIDPattern.MatchString(trackID) {
		return nil, failure(kindNotFound, "%q is not a Spotify track id", trackID)
	}
	tok, cached, err := accessToken(ctx, spDC, true)
	if err != nil {
		return nil, err
	}
	lyr, err := getLyrics(ctx, trackID, tok)
	if errors.Is(err, errTokenRefused) && cached {
		// The cached token went stale early: buy another, once
		if tok, _, err = accessToken(ctx, spDC, false); err != nil {
			return nil, err
		}
		lyr, err = getLyrics(ctx, trackID, tok)
	}
	return lyr, err
}

// getLyrics asks for trackID's lyrics with an access token.
func getLyrics(ctx context.Context, trackID, tok string) (*lyrics, error) {
	var res struct {
		Lyrics *lyrics `json:"lyrics"`
	}
	err := getJSON(ctx, lyricsURL+trackID+"?format=json&market=from_token", http.Header{
		"App-Platform":  {"WebPlayer"},
		"Authorization": {"Bearer " + tok},
	}, &res)
	var status httpStatus
	if errors.As(err, &status) {
		switch status {
		case http.StatusNotFound:
			return nil, failure(kindNotFound, "Spotify has no lyrics for this track")
		case http.StatusUnauthorized:
			return nil, errTokenRefused
		case http.StatusTooManyRequests:
			return nil, failure(kindFailed, "Spotify is rate limiting lyrics requests")
		}
	}
	if err != nil {
		return nil, fmt.Errorf("lyrics: %w", err)
	}
	if res.Lyrics == nil {
		return nil, failure(kindFailed, "Spotify's answer has no lyrics in it")
	}
	return res.Lyrics, nil
}

// token is an answer from /api/token, as cached.
type token struct {
	AccessToken string `json:"accessToken"`
	ExpiresMs   int64  `json:"accessTokenExpirationTimestampMs"`
	IsAnonymous bool   `json:"isAnonymous,omitempty"`
	// A hash of the sp_dc that bought it, so a new cookie never gets an old token
	Owner string `json:"owner,omitempty"`
}

// accessToken returns a token for spDC: the cached one while it has a minute
// left (when useCache), else a new one, which replaces it in the cache.
func accessToken(ctx context.Context, spDC string, useCache bool) (tok string, cached bool, err error) {
	if spDC == "" {
		return "", false, failure(kindAuth, "no sp_dc cookie set")
	}
	sum := sha256.Sum256([]byte(spDC))
	owner := hex.EncodeToString(sum[:8])
	cacheDir, cacheErr := os.UserCacheDir()
	file := filepath.Join(cacheDir, "quickshell", "spotify-token.json")

	if useCache && cacheErr == nil {
		if t, err := readToken(file); err == nil && t.Owner == owner &&
			time.Until(time.UnixMilli(t.ExpiresMs)) > time.Minute {
			return t.AccessToken, true, nil
		}
	}
	t, err := newToken(ctx, spDC)
	if err != nil {
		return "", false, err
	}
	t.Owner = owner
	if cacheErr == nil {
		if err := writeToken(file, t); err != nil {
			// Only costs the next run a new token
			fmt.Fprintln(os.Stderr, "spotify-lyrics: caching the token:", err)
		}
	}
	return t.AccessToken, false, nil
}

// newToken buys an access token with spDC, showing it's the web player with a
// TOTP of Spotify's clock.
func newToken(ctx context.Context, spDC string) (*token, error) {
	var server struct {
		Time int64 `json:"serverTime"`
	}
	if err := getJSON(ctx, serverTimeURL, nil, &server); err != nil {
		return nil, fmt.Errorf("server time: %w", err)
	}
	if server.Time <= 0 {
		return nil, failure(kindFailed, "Spotify sent no server time")
	}
	secret, version, err := totpSecret(ctx)
	if err != nil {
		return nil, fmt.Errorf("TOTP secret: %w", err)
	}

	query := "?reason=transport&productType=web-player" +
		"&totp=" + totp(secret, server.Time) +
		"&totpVer=" + strconv.Itoa(version) +
		"&ts=" + strconv.FormatInt(time.Now().Unix(), 10)
	var t token
	err = getJSON(ctx, tokenURL+query, http.Header{"Cookie": {"sp_dc=" + spDC}}, &t)
	var status httpStatus
	switch {
	case errors.As(err, &status) && status == http.StatusUnauthorized, err == nil && t.IsAnonymous:
		return nil, errCookieRefused
	case err != nil:
		return nil, fmt.Errorf("access token: %w", err)
	case t.AccessToken == "":
		return nil, failure(kindFailed, "Spotify sent no access token")
	}
	return &t, nil
}

// totpSecret fetches the newest TOTP secret and its version. The list keeps
// them as the web player's code does, XOR-scrambled; unscrambled, the numbers'
// digits written one after another are the key.
func totpSecret(ctx context.Context) (key []byte, version int, err error) {
	var secrets map[string][]int
	if err := getJSON(ctx, secretsURL, nil, &secrets); err != nil {
		return nil, 0, err
	}
	version = -1
	var scrambled []int
	for v, s := range secrets {
		if n, err := strconv.Atoi(v); err == nil && n > version {
			version, scrambled = n, s
		}
	}
	if len(scrambled) == 0 {
		return nil, 0, failure(kindFailed, "the TOTP secret list is empty")
	}
	for i, n := range scrambled {
		key = strconv.AppendInt(key, int64(n^(i%33+9)), 10)
	}
	return key, version, nil
}

// totp is the RFC 6238 code at Unix time t: HMAC-SHA1, 30 s steps, 6 digits.
func totp(key []byte, t int64) string {
	var step [8]byte
	binary.BigEndian.PutUint64(step[:], uint64(t/30))
	mac := hmac.New(sha1.New, key)
	mac.Write(step[:])
	sum := mac.Sum(nil)
	at := sum[len(sum)-1] & 0x0f
	code := binary.BigEndian.Uint32(sum[at:at+4]) & 0x7fffffff
	return fmt.Sprintf("%06d", code%1_000_000)
}

func readToken(file string) (*token, error) {
	b, err := os.ReadFile(file)
	if err != nil {
		return nil, err
	}
	var t token
	err = json.Unmarshal(b, &t)
	return &t, err
}

// writeToken caches t where only you can read it. It goes through a temp file
// renamed into place, so no run ever reads half a token.
func writeToken(file string, t *token) error {
	b, err := json.Marshal(t)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(file), 0o700); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(file), ".spotify-token-*")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name()) // fails harmlessly once renamed
	_, err = tmp.Write(b)
	if cerr := tmp.Close(); err == nil {
		err = cerr
	}
	if err != nil {
		return err
	}
	return os.Rename(tmp.Name(), file)
}

// httpStatus is an answer other than 200 OK.
type httpStatus int

func (s httpStatus) Error() string {
	return fmt.Sprintf("HTTP %d %s", int(s), http.StatusText(int(s)))
}

// getJSON GETs url with header added and decodes the JSON answer into v.
func getJSON(ctx context.Context, url string, header http.Header, v any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", userAgent)
	for k, vs := range header {
		req.Header[k] = vs
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return httpStatus(resp.StatusCode)
	}
	return json.NewDecoder(resp.Body).Decode(v)
}
