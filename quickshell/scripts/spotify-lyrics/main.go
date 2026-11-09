// Command spotify-lyrics prints the time-synced lyrics of a Spotify track as
// JSON, for services/LyricsService.qml:
//
//	SP_DC=<cookie> go run . <track id>
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
//	{"error": false, "syncType": "LINE_SYNCED", "lines": [{"startTimeMs": "1230", "words": "…", …}, …]}
//
// ({"error": false} for -check) or, exiting 1,
//
//	{"error": true, "kind": "…", "message": "…"}
//
// where kind is "auth" (no sp_dc, or Spotify refused it), "notfound" (Spotify
// has no lyrics for the track) or "failed" (anything else, worth another try
// later).
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

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintln(os.Stderr, "usage: SP_DC=<cookie> spotify-lyrics <track id> | -check")
		os.Exit(2)
	}
	spDC := strings.TrimSpace(os.Getenv("SP_DC"))
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	answer := map[string]any{"error": false}
	var err error
	if os.Args[1] == "-check" {
		err = check(ctx, spDC)
	} else {
		var lyr *lyrics
		if lyr, err = fetch(ctx, spDC, os.Args[1]); err == nil {
			answer["syncType"], answer["lines"] = lyr.SyncType, lyr.Lines
		}
	}
	cancel()

	out := json.NewEncoder(os.Stdout)
	if err != nil {
		kind := kindFailed
		var fe *fetchError
		if errors.As(err, &fe) {
			kind = fe.kind
		}
		out.Encode(map[string]any{"error": true, "kind": kind, "message": err.Error()})
		os.Exit(1)
	}
	out.Encode(answer)
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
	for k, vs := range header {
		req.Header[k] = vs
	}
	req.Header.Set("User-Agent", userAgent)
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
