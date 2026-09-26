pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pam
import qs.services as Services

// Shared state behind every monitor's LockSurface: PAM authentication, the
// passcode buffer, lives (mirrored from pam_faillock), idle state and the
// grant -> reward -> exit sequence.
//
// Phases: intro -> ready <-> verifying -> granted -> exiting, then `released`.
// Only a PAM success ever leads to `released`. The gamification layered on top
// is fenced off (try/catch + watchdog) so a bug there can never keep the
// session locked after a correct password.
Scope {
    id: ctx

    // ── Lifecycle ────────────────────────────────────────────────────
    property string phase: "intro"
    readonly property bool inputLocked: phase === "verifying" || phase === "granted" || phase === "exiting"
    property double lockedAt: Date.now()

    // Choreography lengths, set from the active theme's registry entry
    // (services/LockScreen.qml). The context owns these timers so a theme
    // only animates and never decides when the lock is released.
    property int introMs: 1250
    property int outroMs: 900
    property int rewardBaseMs: 1150
    property int rewardLevelUpMs: 900
    property int rewardAchievementMs: 450

    // Demo mode for LockPreview.qml and the theme picker: PAM is never
    // touched, any passcode "unlocks" ("wrong" fails) and nothing is saved.
    property bool preview: false
    signal previewExit

    signal released
    signal denied(bool costLife)
    signal granted
    signal typed(int index)
    signal erased(int index)

    // Takes a theme's choreography lengths from its registry entry.
    function configure(theme) {
        introMs = theme.introMs;
        outroMs = theme.outroMs;
        rewardBaseMs = theme.rewardBaseMs;
        rewardLevelUpMs = theme.rewardLevelUpMs;
        rewardAchievementMs = theme.rewardAchievementMs;
        ambient = theme.ambient;
    }

    // Called once the session lock has been requested.
    function begin() {
        lockedAt = Date.now();
        phase = "intro";
        introTimer.restart();
        refreshFaillock();
        refreshCaps();
        poke();
    }

    // ── Passcode input ───────────────────────────────────────────────
    // `buffer` is the typed secret; every surface's hidden TextInput mirrors
    // it. `cells` is how many passcode cells are on screen, which outlives the
    // buffer while an attempt is being verified.
    property string buffer: ""
    property int cells: 0
    property int combo: 0
    property bool denying: false
    property int attemptBackspaces: 0
    property double firstKeyAt: 0
    property double lastKeyAt: 0
    property var _attempt: null
    property var _pending: null

    function setBuffer(text) {
        if (inputLocked || text === buffer)
            return;
        const old = buffer;
        buffer = text;
        lastKeyAt = Date.now();
        poke();
        if (denying) {
            denying = false;
            deniedTimer.stop();
            cells = 0;
        }
        if (old.length === 0 && text.length > 0) {
            firstKeyAt = lastKeyAt;
            message = "";
        }
        if (text.length > old.length && text.startsWith(old)) {
            for (let i = old.length; i < text.length; i++) {
                combo += 1;
                cells = i + 1;
                typed(i);
            }
        } else if (text.length < old.length && old.startsWith(text)) {
            attemptBackspaces += 1;
            combo = 0;
            for (let i = old.length - 1; i >= text.length; i--) {
                cells = i;
                erased(i);
            }
        } else {
            // Replaced wholesale (select-all + type, paste over).
            attemptBackspaces += 1;
            combo = text.length;
            cells = text.length;
        }
        if (text.length === 0)
            firstKeyAt = 0;
        refreshCaps();
    }

    function clearInput() {
        if (inputLocked || buffer.length === 0)
            return;
        setBuffer("");
    }

    function submit() {
        if (inputLocked || buffer.length === 0)
            return;
        _attempt = {
            length: buffer.length,
            typeMs: firstKeyAt > 0 ? Date.now() - firstKeyAt : 0,
            backspaces: attemptBackspaces
        };
        const response = buffer;
        phase = "verifying";
        buffer = "";
        message = "";
        verifyTimeout.restart();
        if (preview) {
            _demoAccepts = response.toLowerCase() !== "wrong";
            demoVerdict.restart();
            return;
        }
        if (pam.active && pam.responseRequired) {
            pam.respond(response);
        } else {
            // PAM is between conversations (restarting after a failure, or
            // not started yet): hand the response over when it asks for one.
            _pending = response;
            if (!pam.active && !pam.start()) {
                _pending = null;
                message = "Authentication unavailable: PAM failed to start";
                _fail(false, true);
            }
        }
    }

    // PAM asked for another answer after the password (e.g. a one-time
    // code): hand the prompt back to the player.
    function _reprompt(prompt) {
        verifyTimeout.stop();
        _resetAttempt();
        message = prompt.trim();
        cells = 0;
        phase = "ready";
    }

    function _resetAttempt() {
        combo = 0;
        attemptBackspaces = 0;
        firstKeyAt = 0;
        _attempt = null;
        _pending = null;
    }

    // `attempted`: the failure answers a submitted passcode. Otherwise PAM
    // gave up on its own (e.g. a faillock lockout rejected at preauth), so
    // there's nothing to animate and no restart: the next submit starts a
    // fresh conversation, which keeps a lockout from spinning.
    function _fail(costsLife, attempted) {
        verifyTimeout.stop();
        if (costsLife) {
            failures += 1;
            lives = Math.max(0, lives - 1);
        }
        if (!preview)
            refreshFaillock();
        if (!attempted)
            return;
        _resetAttempt();
        denying = true;
        deniedTimer.restart();
        phase = "ready";
        denied(costsLife);
        if (preview)
            return;
        // Back off after a system error so a broken PAM setup can't spin.
        pamRestart.interval = costsLife ? 50 : 1500;
        pamRestart.restart();
    }

    function _succeed() {
        verifyTimeout.stop();
        watchdog.start();
        let r = null;
        try {
            const a = _attempt ?? { length: 0, typeMs: 0, backspaces: 0 };
            r = Services.LockStats.evaluate({
                lockedAt: lockedAt,
                unlockedAt: Date.now(),
                failures: failures,
                backspaces: a.backspaces,
                typeMs: a.typeMs,
                length: a.length,
                livesLeft: lives,
                maxLives: maxLives
            });
            if (!preview && !Services.LockStats.commit(r))
                console.warn("lock: stats file not loaded, progress from this unlock was not saved");
        } catch (e) {
            console.warn("lock: reward failed:", e);
            r = null;
        }
        _resetAttempt();
        reward = r;
        phase = "granted";
        granted();
        // The cells burst on `granted`; clear them so ACCESS GRANTED takes their place.
        cells = 0;
        // How long the reward read-out stays up before the exit; the XP bar
        // finishes filling at ~1 s. Any key or click skips ahead.
        let hold = Math.min(350, rewardBaseMs);
        if (r) {
            hold = rewardBaseMs;
            if (r.levelAfter > r.levelBefore)
                hold += rewardLevelUpMs;
            hold += Math.min(r.achievements.length, 3) * rewardAchievementMs;
        }
        rewardTimer.interval = hold;
        rewardTimer.restart();
    }

    property bool _demoAccepts: true

    // Preview only: the verdict a real PAM round-trip would have given.
    Timer {
        id: demoVerdict
        interval: 700
        onTriggered: {
            if (ctx.phase !== "verifying")
                return;
            if (ctx._demoAccepts)
                ctx._succeed();
            else
                ctx._fail(true, true);
        }
    }

    // Any key or click during the reward screen jumps straight to the exit.
    function skip() {
        if (phase !== "granted")
            return;
        rewardTimer.stop();
        _exit();
    }

    function _exit() {
        phase = "exiting";
        exitTimer.restart();
    }

    property var reward: null
    // Touching the stats singleton here creates it (and starts its file read)
    // with the lock, rather than lazily at the first unlock, when commit()
    // would find it not loaded yet.
    readonly property bool statsReady: Services.LockStats.ready

    Timer {
        id: introTimer
        interval: ctx.introMs
        onTriggered: if (ctx.phase === "intro") ctx.phase = "ready"
    }

    Timer {
        id: deniedTimer
        interval: 650
        onTriggered: {
            ctx.denying = false;
            if (ctx.buffer.length === 0)
                ctx.cells = 0;
        }
    }

    Timer {
        id: rewardTimer
        onTriggered: ctx._exit()
    }

    Timer {
        id: exitTimer
        interval: ctx.outroMs
        onTriggered: ctx.released()
    }

    // Hard deadline between a PAM success and releasing the lock, whatever
    // the UI is doing.
    Timer {
        id: watchdog
        interval: 7000
        onTriggered: ctx.released()
    }

    // ── PAM ──────────────────────────────────────────────────────────
    // PAM service used to check the passcode (Quickshell's defaults). Point it
    // at a dedicated file to change the stack, e.g. to add fingerprint auth.
    property string pamConfig: "login"
    property string pamConfigDirectory: "/etc/pam.d"
    property string message: ""

    PamContext {
        id: pam

        config: ctx.pamConfig
        configDirectory: ctx.pamConfigDirectory

        Component.onCompleted: {
            if (!ctx.preview)
                pam.start();
        }

        // Prompts get the pending passcode (or go back to the player if PAM
        // wants a second answer); anything else is informational, e.g.
        // pam_faillock's "The account is locked due to 3 failed logins."
        onPamMessage: {
            if (pam.responseRequired) {
                if (ctx._pending !== null) {
                    const r = ctx._pending;
                    ctx._pending = null;
                    pam.respond(r);
                } else if (ctx.phase === "verifying") {
                    ctx._reprompt(pam.message);
                }
            } else if (pam.message.length > 0) {
                ctx.message = pam.message.trim();
            }
        }

        // Errors arrive here too (as PamResult.Error), after `error`. A
        // success always unlocks, whatever the phase (e.g. a passwordless
        // PAM module).
        onCompleted: result => {
            const attempted = ctx.phase === "verifying";
            if (result === PamResult.Success) {
                ctx._succeed();
            } else {
                if (result === PamResult.Error && ctx.message.length === 0)
                    ctx.message = "Authentication service error, try again";
                ctx._fail(attempted && result !== PamResult.Error, attempted);
            }
        }

        onError: error => console.warn("lock: PAM error:", PamError.toString(error))
    }

    Timer {
        id: pamRestart
        interval: 50
        onTriggered: {
            if (!pam.active && ctx.phase !== "granted" && ctx.phase !== "exiting")
                pam.start();
        }
    }

    // A PAM module that never answers mustn't leave the player stuck on
    // VERIFYING with input locked.
    Timer {
        id: verifyTimeout
        interval: 25000
        onTriggered: {
            if (ctx.phase !== "verifying")
                return;
            pam.abort();
            ctx.message = "Authentication timed out, try again";
            ctx._fail(false, true);
        }
    }

    // ── Lives (pam_faillock) ─────────────────────────────────────────
    // Hearts mirror how many more wrong passwords pam_faillock allows before
    // it locks the account; the countdown shows when that lockout ends. Read
    // from `faillock --user` (the tally file is user-readable) and the
    // deny/unlock_time/fail_interval settings in faillock.conf.
    property int maxLives: 3
    property int lives: 3
    property int failures: 0
    property double lockoutUntil: 0  // epoch ms; -1 = until an admin resets it
    property int lockoutLeft: 0      // seconds
    readonly property bool lockedOut: lockoutUntil < 0 || lockoutLeft > 0
    readonly property bool lastLife: maxLives > 1 && lives === 1 && !lockedOut
    // "9:41" while a lockout counts down; empty when there is none or it
    // only ends when an admin resets it.
    readonly property string lockoutClock: lockoutLeft > 0
        ? Math.floor(lockoutLeft / 60) + ":" + String(lockoutLeft % 60).padStart(2, "0") : ""
    property int unlockTime: 600    // s, from faillock.conf
    property int failInterval: 900  // s

    readonly property string userName: Quickshell.env("USER") || "player"

    function refreshFaillock() {
        faillockProc.running = true;
    }

    function _parseFaillockConf(text) {
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].replace(/#.*/, "").trim();
            const m = line.match(/^(deny|unlock_time|fail_interval)\s*=\s*(\w+)/);
            if (!m)
                continue;
            const v = m[2] === "never" ? 0 : parseInt(m[2]);
            if (isNaN(v))
                continue;
            if (m[1] === "deny")
                maxLives = v;
            else if (m[1] === "unlock_time")
                unlockTime = v;
            else
                failInterval = v;
        }
        lives = Math.min(lives, maxLives);
        refreshFaillock();
    }

    function _parseFaillock(text) {
        const now = Date.now();
        const times = [];
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].match(/^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})\s.*\s([VI])\s*$/);
            if (m && m[7] === "V")
                times.push(new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]).getTime());
        }
        const window = failInterval * 1000;
        const latest = times.length > 0 ? Math.max.apply(null, times) : 0;
        let sinceNow = 0;
        let sinceLatest = 0;
        for (let i = 0; i < times.length; i++) {
            if (now - times[i] < window)
                sinceNow += 1;
            if (latest - times[i] < window)
                sinceLatest += 1;
        }
        // No tally despite failures means pam_faillock isn't recording for
        // this stack; keep the locally counted lives then.
        if (maxLives > 0 && !(failures > 0 && times.length === 0)) {
            lives = Math.max(0, maxLives - sinceNow);
            if (sinceLatest >= maxLives)
                lockoutUntil = unlockTime > 0 ? latest + unlockTime * 1000 : -1;
            else
                lockoutUntil = 0;
        }
        _tickLockout();
    }

    function _tickLockout() {
        if (lockoutUntil <= 0) {
            lockoutLeft = 0;
            return;
        }
        lockoutLeft = Math.max(0, Math.ceil((lockoutUntil - Date.now()) / 1000));
        if (lockoutLeft === 0) {
            lockoutUntil = 0;
            refreshFaillock();
        }
    }

    FileView {
        path: "/etc/security/faillock.conf"
        printErrors: false
        onLoaded: ctx._parseFaillockConf(text())
    }

    Process {
        id: faillockProc
        command: ["faillock", "--user", ctx.userName]
        stdout: StdioCollector {
            onStreamFinished: ctx._parseFaillock(text)
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: ctx.lockoutUntil > 0
        onTriggered: ctx._tickLockout()
    }

    // ── Idle ─────────────────────────────────────────────────────────
    // `awake` drops after a stretch without input; themes then dim and stop
    // their ambient motion so an idle lock screen draws about once a second.
    // Previews never doze.
    property bool awake: true

    function poke() {
        if (!awake)
            awake = true;
        idleTimer.restart();
    }

    Timer {
        id: idleTimer
        interval: 25000
        onTriggered: {
            if (!ctx.preview && ctx.buffer.length === 0 && ctx.phase === "ready")
                ctx.awake = false;
            else
                restart();
        }
    }

    // ── Ambient clock ────────────────────────────────────────────────
    // Seconds of ambient animation (drifting mist, stars, rotating seals)
    // for themes that want it. Ticks at ~30 fps, not the display rate, and
    // only while awake, so an idle screen goes still.
    property bool ambient: false
    property real ambientTime: 0

    Timer {
        property double last: 0

        interval: 33
        repeat: true
        running: ctx.ambient && ctx.awake
        onRunningChanged: last = Date.now()
        onTriggered: {
            const t = Date.now();
            ctx.ambientTime += Math.min(0.1, (t - last) / 1000);
            last = t;
        }
    }

    // ── Keyboard state ───────────────────────────────────────────────
    property bool capsLock: false
    property string layout: ""
    property bool multiLayout: false

    function refreshCaps() {
        capsTimer.restart();
    }

    function _shortLayout(name) {
        return (name || "").slice(0, 2).toUpperCase();
    }

    // The caps lock LED path has a per-boot input number, so find it once.
    Process {
        running: true
        command: ["sh", "-c", "for f in /sys/class/leds/*::capslock/brightness; do [ -e \"$f\" ] && echo \"$f\" && break; done"]
        stdout: StdioCollector {
            onStreamFinished: capsFile.path = text.trim()
        }
    }

    FileView {
        id: capsFile
        printErrors: false
        onLoaded: ctx.capsLock = text().trim() !== "0"
    }

    Timer {
        id: capsTimer
        interval: 60
        onTriggered: if (capsFile.path.length > 0) capsFile.reload()
    }

    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kbs = JSON.parse(text).keyboards;
                    const main = kbs.find(k => k.main) ?? kbs[0];
                    if (main) {
                        ctx.layout = ctx._shortLayout(main.active_keymap);
                        ctx.multiLayout = String(main.layout).includes(",");
                    }
                } catch (e) {}
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "activelayout")
                return;
            const parts = event.data.split(",");
            ctx.layout = ctx._shortLayout(parts[parts.length - 1]);
        }
    }

    // ── Clock ────────────────────────────────────────────────────────
    readonly property date now: clock.date

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // ── System actions ───────────────────────────────────────────────
    function suspend() {
        Quickshell.execDetached(["systemctl", "suspend"]);
    }

    function reboot() {
        Quickshell.execDetached(["systemctl", "reboot"]);
    }

    function poweroff() {
        Quickshell.execDetached(["systemctl", "poweroff"]);
    }
}
