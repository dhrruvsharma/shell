pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.colors
import qs.services

// The bar pet: a small cat (or fox, or bunny) that lives in the top bar
// (modules/pet/BarPet.qml) and opens a hub when clicked
// (modules/pet/PetHub.qml): one place to open apps, the shell's panels
// (ipc-commands.json), your saved commands (the notes drawer's), the pet's
// own "tricks" (pinned commands), run a shell command, do sums, search the
// web and set reminders. It speaks now and then in a bubble
// (modules/pet/PetBubble.qml): greetings, reminders, a low battery, or
// `qs ipc call pet say <text>` from a script.
//
// Pats, meals and play build friendship and set its mood; none of it nags.
// Everything it remembers lives in ~/.config/quickshell/pet.json.
Singleton {
    id: root

    // ── Settings and memory (pet.json) ───────────────────────────────────────
    readonly property alias name: adapter.name
    readonly property alias species: adapter.species
    readonly property alias fur: adapter.fur
    readonly property alias chatty: adapter.chatty
    readonly property alias roam: adapter.roam
    readonly property alias shown: adapter.shown
    readonly property alias sleepAtNight: adapter.sleepAtNight
    readonly property alias affection: adapter.affection
    readonly property alias tricks: adapter.tricks
    readonly property alias recent: adapter.recent
    readonly property alias reminders: adapter.reminders
    property bool ready: false

    // ── Runtime ──────────────────────────────────────────────────────────────
    property bool hubOpen: false
    // Where the pet is: the screen x of its middle (BarPet keeps it up to
    // date), so the hub and the bubble hang from it.
    property real barX: 0
    // Whether it's asleep (BarPet's say) and how rested it is (0..1).
    property bool asleep: false
    property real energy: 1
    property double lastInteraction: Date.now()
    property double happyUntil: 0
    // The speech bubble: text, how long it stays, and a serial to show the
    // same words twice.
    property string bubbleText: ""
    property int bubbleMs: 3500
    property int bubbleSerial: 0
    // Something for BarPet to act out: pat, feed, play, nap, wake, notice,
    // run, alert, levelup.
    signal act(string what)

    readonly property string user: Quickshell.env("USER") || "friend"
    readonly property date now: clock.date

    // ── Friendship ───────────────────────────────────────────────────────────
    readonly property int level: Math.floor(Math.sqrt(adapter.affection / 6)) + 1
    readonly property int levelFloor: 6 * (level - 1) * (level - 1)
    readonly property int levelCeil: 6 * level * level
    readonly property real levelProgress: Math.max(0, Math.min(1, (adapter.affection - levelFloor) / Math.max(1, levelCeil - levelFloor)))
    readonly property var bonds: ["stranger", "acquaintance", "buddy", "pal", "friend", "good friend", "close friend", "best friend", "kindred spirit", "soulmate"]
    readonly property string bond: bonds[Math.min(level - 1, bonds.length - 1)]

    // ── Mood ─────────────────────────────────────────────────────────────────
    readonly property real hoursSinceFed: adapter.lastFed > 0 ? (now.getTime() - adapter.lastFed) / 3600000 : 99
    readonly property bool night: now.getHours() < 6 || now.getHours() >= 23
    readonly property string mood: asleep ? "asleep"
        : happyUntil > now.getTime() ? "happy"
        : hoursSinceFed > 8 ? "hungry"
        : energy < 0.3 || (night && adapter.sleepAtNight) ? "sleepy"
        : now.getTime() - lastInteraction > 3 * 3600000 ? "bored"
        : "content"
    readonly property var moodWords: ({ asleep: "fast asleep", happy: "happy", hungry: "a bit peckish", sleepy: "sleepy", bored: "a little bored", content: "content" })

    // ── Looks ────────────────────────────────────────────────────────────────
    readonly property var furs: ({
        cream: { base: "#f4e4c6", belly: "#fff7e8", shade: "#dcc4a0", line: "#5a4633", inner: "#f5b3b3", eye: "#2b2230", nose: "#ea8a96" },
        ginger: { base: "#f2a55f", belly: "#ffe6c9", shade: "#d9853f", line: "#5c3218", inner: "#f7b0a8", eye: "#2b2230", nose: "#e9798a" },
        grey: { base: "#aeb7c2", belly: "#e6ebf0", shade: "#8e98a4", line: "#353b44", inner: "#f2b5c0", eye: "#262b33", nose: "#e58c9a" },
        black: { base: "#34323d", belly: "#4c4a58", shade: "#27262e", line: "#121117", inner: "#e79aa9", eye: "#e2e87a", nose: "#e58c9a" },
        white: { base: "#fbfbfb", belly: "#ffffff", shade: "#e4e4ec", line: "#4a4a5a", inner: "#f7b8c4", eye: "#2b2a38", nose: "#f08fa0" },
        fox: { base: "#ee8f4c", belly: "#fff3e4", shade: "#d06f33", line: "#56260f", inner: "#3b1d0e", eye: "#2b1c14", nose: "#3b2218" }
    })
    readonly property var furNames: ["natural", "cream", "ginger", "grey", "black", "white", "theme"]

    // The fur to draw: "natural" is each species' own, "theme" the desktop
    // theme's accent made pastel.
    readonly property var coat: {
        const f = adapter.fur;
        if (f === "theme") {
            const a = Qt.color(DesktopTheme.accent);
            const h = a.hslHue < 0 ? 0.08 : a.hslHue;
            return { base: Qt.hsla(h, 0.5, 0.8, 1), belly: Qt.hsla(h, 0.55, 0.92, 1), shade: Qt.hsla(h, 0.42, 0.7, 1), line: Qt.hsla(h, 0.35, 0.24, 1), inner: "#f5b3b3", eye: "#2b2230", nose: "#ea8a96" };
        }
        if (f === "natural" || !furs[f])
            return furs[adapter.species === "fox" ? "fox" : adapter.species === "bunny" ? "white" : "cream"];
        return furs[f];
    }

    // ── Care ─────────────────────────────────────────────────────────────────
    property double _lastPat: 0
    property double _lastPlay: 0

    function touch() {
        lastInteraction = Date.now();
    }

    function love(n) {
        const before = level;
        adapter.affection = adapter.affection + n;
        if (level > before) {
            act("levelup");
            say(pick("level"), 4500);
        }
    }

    function pat() {
        touch();
        if (asleep)
            act("wake");
        happyUntil = Date.now() + 120000;
        act("pat");
        if (Date.now() - _lastPat > 2500)
            love(1);
        _lastPat = Date.now();
        say(pick("pat"));
    }

    function feed() {
        touch();
        if (asleep)
            act("wake");
        if (hoursSinceFed < 1.5) {
            say(pick("full"));
            return;
        }
        adapter.lastFed = Date.now();
        happyUntil = Date.now() + 300000;
        energy = Math.min(1, energy + 0.2);
        love(3);
        act("feed");
        say(pick("feed"));
    }

    function play() {
        touch();
        if (asleep)
            act("wake");
        if (energy < 0.25) {
            say(pick("tired"));
            return;
        }
        energy = Math.max(0, energy - 0.12);
        happyUntil = Date.now() + 180000;
        if (Date.now() - _lastPlay > 30000)
            love(2);
        _lastPlay = Date.now();
        act("play");
        say(pick("play"));
    }

    function nap() {
        touch();
        act("nap");
        say(pick("nap"));
    }

    // ── Speech ───────────────────────────────────────────────────────────────
    readonly property var lines: ({
        pat: ["purr~", "♥", "hehe", "mrrp!", "more pats pls", "*happy wiggle*"],
        feed: ["nom nom nom", "yum! 🐟", "*crunch crunch*", "best meal ever"],
        full: ["I'm full!", "no more, I'll burst", "maybe later~"],
        play: ["zoom!", "again again!", "gotcha!", "*pounce*"],
        tired: ["too sleepy to play…", "five more minutes…"],
        nap: ["nap time… zzz", "wake me for snacks"],
        wake: ["*yawn*", "mm? I'm up!"],
        run: ["on it!", "okie!", "✓", "done ✓"],
        welcome: ["welcome back, {user}!", "you're back! ♥", "missed you!"],
        hungry: ["*stares at the food bowl*", "is it snack time?"],
        level: ["we're {bond}s now! ♥", "{bond}s! ♥"],
        late: ["it's late… bed soon?", "still up? 🌙"],
        musings: ["stretch break?", "drink some water 💧", "you're doing great ♥", "blink a few times ✨", "posture check!", "*watches the cursor*"],
        battery: ["battery at {n}%, find a charger?", "{n}% left! plug me in?"],
        batteryLow: ["{n}%!! charger, now!"],
        charged: ["all charged up ⚡"]
    })

    // A little of the desktop theme in how it says hello.
    readonly property var flavor: ({
        hud: "Player 1 ready!", terminal: "$ pet --wake", cosmos: "the stars look bright ✨", zen: "breathe in…",
        xianxia: "may your qi flow", cyberpunk: "jacked in and ready", wabisabi: "一期一会", artdeco: "care for a cocktail?",
        gothic: "the bells are ringing", newspaper: "extra! extra!", wasteland: "stay safe out there",
        observatory: "clear skies tonight ✨", abyss: "blub blub… dive, dive!", devaloka: "may the devas smile on you 🪔",
        siege: "for the realm! ⚔️"
    })

    function fill(text, vars) {
        let t = text.split("{user}").join(user).split("{bond}").join(bond).split("{name}").join(adapter.name);
        for (const k in (vars ?? {}))
            t = t.split("{" + k + "}").join(vars[k]);
        return t;
    }

    function pick(kind, vars) {
        const set = lines[kind] ?? [kind];
        return fill(set[Math.floor(Math.random() * set.length)], vars);
    }

    // Shows `text` in the bubble; the pet stops to say it.
    function say(text, ms) {
        if (!text)
            return;
        bubbleText = text;
        bubbleMs = ms ?? Math.max(2600, Math.min(8000, 1600 + text.length * 70));
        bubbleSerial += 1;
    }

    // Speech the pet volunteers, gated by how chatty it's set to be:
    // 0 quiet (only what you asked for), 1 normal, 2 chatty.
    function chat(minLevel, text, ms) {
        if (adapter.chatty >= minLevel && adapter.shown)
            say(text, ms);
    }

    function greeting() {
        const h = now.getHours();
        const base = h < 5 ? "still up, {user}? 🌙" : h < 12 ? "good morning, {user}! ☀" : h < 17 ? "good afternoon, {user}!" : h < 22 ? "good evening, {user}!" : "night owl mode, {user}? 🌙";
        const f = DesktopTheme.enabled ? flavor[DesktopTheme.theme] : "";
        return fill(base) + (f ? "  " + f : "");
    }

    // ── Actions: everything the hub can do ───────────────────────────────────
    // An action: { key, title, subtitle, icon (Material Symbols name) or
    // image (a file:// URL), type, value, terminal? }. Types:
    //   cmd   a shell command     app   a desktop entry's exec line
    //   note  a notes-drawer note (value: its id)
    //   calc  a result to copy    web   a web search    url  a link
    //   remind  { at, text }      pet   pat | feed | play | nap
    readonly property var petActions: [
        { key: "pet:pat", title: "Pat " + adapter.name, subtitle: "Pet care", icon: "pets", type: "pet", value: "pat" },
        { key: "pet:feed", title: "Feed " + adapter.name, subtitle: "Pet care", icon: "set_meal", type: "pet", value: "feed" },
        { key: "pet:play", title: "Play with " + adapter.name, subtitle: "Pet care", icon: "sports_baseball", type: "pet", value: "play" },
        { key: "pet:nap", title: "Let " + adapter.name + " nap", subtitle: "Pet care", icon: "bedtime", type: "pet", value: "nap" }
    ]

    // The shell's own actions, from ipc-commands.json.
    property var shellActions: []

    function iconForCommand(text) {
        const t = text.toLowerCase();
        const table = [["wallpaper", "wallpaper"], ["clipboard", "content_paste"], ["notepad", "sticky_note_2"], ["power", "power_settings_new"],
            ["lock", "lock"], ["theme", "palette"], ["network", "wifi"], ["media", "music_note"], ["calendar", "calendar_month"],
            ["launcher", "apps"], ["expose", "view_carousel"], ["cava", "graphic_eq"], ["github", "code"], ["update", "system_update"],
            ["widget", "widgets"], ["manga", "menu_book"], ["novel", "auto_stories"], ["anime", "movie"], ["chat", "chat"],
            ["avatar", "face"], ["control", "tune"], ["clock", "schedule"], ["system", "monitor_heart"], ["bar", "view_agenda"],
            ["pet", "pets"]];
        for (const [k, icon] of table)
            if (t.includes(k))
                return icon;
        return "bolt";
    }

    function _loadShellActions(text) {
        try {
            // (Its own commands are left out: the hub has them already.)
            const list = JSON.parse(text).filter(e => !e.text.startsWith("qs ipc call pet "));
            shellActions = list.map(e => {
                const parts = (e.subtext || e.text).split(" · ");
                return { key: "ipc:" + e.text, title: parts[0], subtitle: "Shell" + (parts[1] ? " · " + parts[1] : ""), icon: iconForCommand(e.text), type: "cmd", value: e.text };
            });
        } catch (e) {
            shellActions = [];
        }
    }

    FileView {
        path: Quickshell.shellPath("ipc-commands.json")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root._loadShellActions(text())
    }

    // Your saved commands and snippets, from the notes drawer (its IPC
    // category is the list above, so it's left out).
    readonly property var noteActions: {
        const out = [];
        const notes = Notes.notes || [];
        for (const n of notes) {
            if (n.category === Notes.ipcCategory)
                continue;
            const runs = !!(Notes.categoryCommands[n.category] && Notes.categoryCommands[n.category].trim() !== "");
            const title = (n.subtext && n.subtext.trim() !== "" ? n.subtext : n.text).split("\n")[0];
            out.push({ key: "note:" + n.id, title: title, subtitle: (n.category === "notes" ? "Note" : n.category) + (runs ? " · runs" : " · copies"), icon: runs ? "play_circle" : "content_copy", type: "note", value: n.id });
        }
        return out;
    }

    readonly property var appActions: (AppRegistry.apps || []).map(a => ({
        key: "app:" + (a.desktopId || a.name), title: a.name, subtitle: "App" + (a.comment ? " · " + a.comment : ""), image: AppRegistry.iconForDesktopIcon(a.icon), icon: "apps", type: "app", value: a.exec
    }))

    readonly property var trickActions: (adapter.tricks || []).map(t => ({
        key: "trick:" + t.id, title: t.name, subtitle: "Trick · " + t.cmd, icon: t.icon || "bolt", image: t.image || "", type: t.type || "cmd", value: t.cmd, terminal: !!t.terminal, trickId: t.id
    }))

    // ── Search ───────────────────────────────────────────────────────────────
    function _score(text, q) {
        const t = (text || "").toLowerCase();
        const i = t.indexOf(q);
        if (i === 0)
            return 100 - t.length * 0.05;
        if (i > 0)
            return (/[\s\-_.·/:]/.test(t[i - 1]) ? 70 : 40) - i * 0.1;
        // Letters in order, close together ("ctrl" in "control center",
        // but not "fire" in "file roller").
        let j = 0, from = -1, to = -1;
        for (let k = 0; k < t.length && j < q.length; k++) {
            if (t[k] === q[j]) {
                if (j === 0)
                    from = k;
                to = k;
                j++;
            }
        }
        const span = to - from + 1;
        return j === q.length && q.length >= 2 && span <= q.length * 2 ? 20 - span - t.length * 0.02 : -1;
    }

    function search(query, limit) {
        const raw = query.trim();
        const out = [];
        if (!raw)
            return out;
        const n = limit ?? 8;
        const first = raw.charAt(0);
        const rest = raw.slice(1).trim();
        // Prefixes: >run, =math, ?search.
        if (first === ">" || first === "$") {
            if (rest)
                out.push({ key: "run", title: rest, subtitle: "Run in the background · Shift+Enter: in a terminal", icon: "terminal", type: "cmd", value: rest });
            return out;
        }
        if (first === "=") {
            const v = calc(rest);
            out.push(v !== null
                ? { key: "calc", title: "= " + v, subtitle: rest + " · Enter copies the answer", icon: "calculate", type: "calc", value: String(v) }
                : { key: "calc", title: "…", subtitle: "Sums: + − × ÷ ^ %, sqrt, sin, log, pi…", icon: "calculate", type: "none", value: "" });
            return out;
        }
        if (first === "?") {
            if (rest)
                out.push({ key: "web", title: "Search the web for “" + rest + "”", subtitle: "DuckDuckGo", icon: "travel_explore", type: "web", value: rest });
            return out;
        }
        const reminder = parseReminder(raw);
        if (reminder)
            out.push({ key: "remind", title: "Remind you " + reminder.when + ": " + reminder.text, subtitle: adapter.name + " will say it, and send a notification", icon: "alarm", type: "remind", value: reminder });
        if (/^(https?:\/\/|www\.)\S+$/i.test(raw) || /^[\w-]+(\.[\w-]+)+\.[a-z]{2,}(\/\S*)?$/i.test(raw))
            out.push({ key: "url", title: "Open " + raw, subtitle: "Link", icon: "link", type: "url", value: /^https?:\/\//i.test(raw) ? raw : "https://" + raw });
        // A sum typed bare ("12*7").
        if (/^[\d\s.+\-*/%^()]+$/.test(raw) && /[+\-*/%^]/.test(raw)) {
            const v = calc(raw);
            if (v !== null)
                out.push({ key: "calc", title: "= " + v, subtitle: raw + " · Enter copies the answer", icon: "calculate", type: "calc", value: String(v) });
        }
        const q = raw.toLowerCase();
        const pools = [[trickActions, 30], [petActions, 12], [shellActions, 18], [noteActions, 14], [appActions, 20]];
        const scored = [];
        for (const [pool, bonus] of pools) {
            for (const a of pool) {
                const s = Math.max(_score(a.title, q), _score(a.subtitle, q) - 30);
                if (s > 0)
                    scored.push({ a: a, s: s + bonus });
            }
        }
        scored.sort((x, y) => y.s - x.s);
        const seen = {};
        for (const e of scored) {
            if (out.length >= n)
                break;
            if (seen[e.a.key])
                continue;
            seen[e.a.key] = true;
            out.push(e.a);
        }
        if (out.length < n)
            out.push({ key: "run", title: "Run “" + raw + "”", subtitle: "As a shell command · Shift+Enter: in a terminal", icon: "terminal", type: "cmd", value: raw });
        if (out.length < n)
            out.push({ key: "web", title: "Search the web for “" + raw + "”", subtitle: "DuckDuckGo", icon: "travel_explore", type: "web", value: raw });
        return out;
    }

    // ── Sums: a small, safe calculator ───────────────────────────────────────
    function calc(expr) {
        const src = expr.replace(/×/g, "*").replace(/÷/g, "/").replace(/−/g, "-").replace(/,/g, "");
        let i = 0;
        const peek = () => src[i];
        const skip = () => {
            while (i < src.length && /\s/.test(src[i]))
                i++;
        };
        const fns = { sqrt: Math.sqrt, sin: Math.sin, cos: Math.cos, tan: Math.tan, log: Math.log10, ln: Math.log, abs: Math.abs, round: Math.round, floor: Math.floor, ceil: Math.ceil, exp: Math.exp };
        let expression = null, power = null, term = null;
        const primary = () => {
            skip();
            const c = peek();
            if (c === "(") {
                i++;
                const v = expression();
                skip();
                if (peek() !== ")")
                    throw "paren";
                i++;
                return v;
            }
            if (c === "-") {
                i++;
                return -power();
            }
            if (c === "+") {
                i++;
                return power();
            }
            const num = /^\d*\.?\d+(e[+-]?\d+)?/i.exec(src.slice(i));
            if (num) {
                i += num[0].length;
                return parseFloat(num[0]);
            }
            const word = /^[a-z]+/i.exec(src.slice(i));
            if (word) {
                const w = word[0].toLowerCase();
                i += w.length;
                if (w === "pi")
                    return Math.PI;
                if (w === "e")
                    return Math.E;
                if (fns[w]) {
                    skip();
                    if (peek() !== "(")
                        throw "call";
                    return fns[w](primary());
                }
            }
            throw "token";
        };
        power = () => {
            const base = primary();
            skip();
            if (peek() === "^") {
                i++;
                return Math.pow(base, power());
            }
            return base;
        };
        term = () => {
            let v = power();
            for (;;) {
                skip();
                const c = peek();
                if (c === "*" || c === "/" || c === "%") {
                    i++;
                    const r = power();
                    v = c === "*" ? v * r : c === "/" ? v / r : v % r;
                } else {
                    return v;
                }
            }
        };
        expression = () => {
            let v = term();
            for (;;) {
                skip();
                const c = peek();
                if (c === "+" || c === "-") {
                    i++;
                    const r = term();
                    v = c === "+" ? v + r : v - r;
                } else {
                    return v;
                }
            }
        };
        try {
            if (!src.trim())
                return null;
            const v = expression();
            skip();
            if (i < src.length || !isFinite(v))
                return null;
            return Math.abs(v) >= 1e15 || (Math.abs(v) < 1e-6 && v !== 0) ? v.toExponential(6) : parseFloat(v.toFixed(10));
        } catch (e) {
            return null;
        }
    }

    // ── Reminders ────────────────────────────────────────────────────────────
    // "remind 10m stretch", "remind me in 2 hours to call mum", "in 45 min
    // tea", "remind at 17:30 standup". Returns { at, text, when } or null.
    function parseReminder(s) {
        const rel = /^(?:remind(?:\s+me)?\s+)?in\s+(\d+(?:\.\d+)?)\s*(s|sec|secs|seconds?|m|mins?|minutes?|h|hrs?|hours?)\b\s*(?:to\s+)?(.*)$/i.exec(s)
            ?? /^remind(?:\s+me)?\s+(?:in\s+)?(\d+(?:\.\d+)?)\s*(s|sec|secs|seconds?|m|mins?|minutes?|h|hrs?|hours?)\b\s*(?:to\s+)?(.*)$/i.exec(s);
        if (rel) {
            const unit = rel[2].toLowerCase();
            const mult = unit.startsWith("s") ? 1000 : unit.startsWith("h") ? 3600000 : 60000;
            const ms = parseFloat(rel[1]) * mult;
            const text = rel[3].trim() || "you asked me to remind you";
            const mins = Math.round(ms / 60000);
            const when = ms < 60000 ? "in " + Math.round(ms / 1000) + " s" : mins < 60 ? "in " + mins + " min" : "in " + (ms / 3600000).toFixed(ms % 3600000 ? 1 : 0) + " h";
            return { at: Date.now() + ms, text: text, when: when };
        }
        const abs = /^remind(?:\s+me)?\s+at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s+(?:to\s+)?(.+)$/i.exec(s);
        if (abs) {
            let h = parseInt(abs[1]);
            const m = abs[2] ? parseInt(abs[2]) : 0;
            const ap = (abs[3] || "").toLowerCase();
            if (ap === "pm" && h < 12)
                h += 12;
            if (ap === "am" && h === 12)
                h = 0;
            if (h > 23 || m > 59)
                return null;
            const d = new Date();
            d.setHours(h, m, 0, 0);
            if (d.getTime() <= Date.now())
                d.setDate(d.getDate() + 1);
            return { at: d.getTime(), text: abs[4].trim(), when: "at " + Qt.formatTime(d, "h:mm AP") };
        }
        return null;
    }

    function addReminder(r) {
        const list = (adapter.reminders || []).slice();
        list.push({ id: Date.now() + Math.random(), at: r.at, text: r.text });
        list.sort((a, b) => a.at - b.at);
        adapter.reminders = list;
        say("okay! I'll remind you " + r.when + " ⏰");
    }

    function cancelReminder(id) {
        adapter.reminders = (adapter.reminders || []).filter(r => r.id !== id);
    }

    Timer {
        interval: 10000
        repeat: true
        running: (adapter.reminders || []).length > 0
        onTriggered: {
            const t = Date.now();
            const due = adapter.reminders.filter(r => r.at <= t);
            if (due.length === 0)
                return;
            adapter.reminders = adapter.reminders.filter(r => r.at > t);
            for (const r of due) {
                root.act("alert");
                root.say("⏰ " + r.text, 12000);
                Quickshell.execDetached(["notify-send", "-a", adapter.name, "-i", "alarm-clock", "⏰ " + adapter.name, r.text]);
            }
        }
    }

    // ── Running things ───────────────────────────────────────────────────────
    function exec(cmd, terminal) {
        if (!cmd || !cmd.trim())
            return;
        if (terminal)
            Quickshell.execDetached(["kitty", "--hold", "-e", "sh", "-c", cmd]);
        else
            Quickshell.execDetached(["sh", "-c", cmd]);
    }

    // Runs an action from the hub (or a trick). `inTerminal` forces a
    // terminal for commands.
    function run(a, inTerminal) {
        if (!a)
            return;
        touch();
        switch (a.type) {
        case "cmd":
            exec(a.value, inTerminal || a.terminal);
            break;
        case "app":
            exec(a.value.replace(/%[uUfFdDnNickvm]/g, "").trim(), inTerminal);
            break;
        case "note": {
            const n = (Notes.notes || []).find(x => x.id === a.value);
            if (n)
                Notes.executeNote(n);
            break;
        }
        case "calc":
            Quickshell.execDetached(["wl-copy", a.value]);
            say("copied " + a.value + " ✓");
            return;
        case "web":
            Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(a.value)]);
            break;
        case "url":
            Quickshell.execDetached(["xdg-open", a.value]);
            break;
        case "remind":
            addReminder(a.value);
            return;
        case "pet":
            ({ pat: pat, feed: feed, play: play, nap: nap })[a.value]?.();
            return;
        default:
            return;
        }
        remember(a);
        act("run");
        if (Math.random() < 0.3)
            chat(1, pick("run"));
        // A small thank-you for letting it help, now and then.
        if (Math.random() < 0.25)
            love(1);
    }

    function remember(a) {
        if (!a.key || a.key === "run" || a.key === "web" || a.key === "url")
            return;
        const entry = { key: a.key, title: a.title, subtitle: a.subtitle, icon: a.icon, image: a.image || "", type: a.type, value: a.value, terminal: !!a.terminal };
        const list = (adapter.recent || []).filter(e => e.key !== a.key);
        list.unshift(entry);
        adapter.recent = list.slice(0, 6);
    }

    // ── Tricks: commands you teach it ────────────────────────────────────────
    readonly property var defaultTricks: [
        { id: "t-terminal", name: "Terminal", icon: "terminal", cmd: "kitty" },
        { id: "t-files", name: "Files", icon: "folder", cmd: "thunar" },
        { id: "t-browser", name: "Browser", icon: "language", cmd: "firefox" },
        { id: "t-shot", name: "Screenshot", icon: "screenshot_region", cmd: "grimblast copy area" },
        { id: "t-wall", name: "Wallpapers", icon: "wallpaper", cmd: "qs ipc call wallpaper toggle" },
        { id: "t-control", name: "Control", icon: "tune", cmd: "qs ipc call controlCenter changeVisible" },
        { id: "t-clip", name: "Clipboard", icon: "content_paste", cmd: "qs ipc call clipboardManager changeVisible" },
        { id: "t-notes", name: "Notepad", icon: "sticky_note_2", cmd: "qs ipc call notepad toggle" },
        { id: "t-themes", name: "Themes", icon: "palette", cmd: "qs ipc call themes desktop" },
        { id: "t-lock", name: "Lock", icon: "lock", cmd: "qs ipc call lockscreen lock" }
    ]

    function teach(name, cmd, icon, terminal) {
        if (!name.trim() || !cmd.trim())
            return;
        const list = (adapter.tricks || []).slice();
        list.push({ id: "t-" + Date.now(), name: name.trim(), icon: icon || "bolt", cmd: cmd.trim(), terminal: !!terminal });
        adapter.tricks = list;
        love(1);
        act("happy");
        say("learned “" + name.trim() + "”! ✨");
    }

    // Pins an action from the search (an app, a shell action) as a trick.
    function pin(a) {
        if (!a || (a.type !== "cmd" && a.type !== "app"))
            return;
        const list = (adapter.tricks || []).slice();
        if (list.some(t => t.cmd === a.value))
            return;
        list.push({ id: "t-" + Date.now(), name: a.title, icon: a.icon || "bolt", image: a.image || "", cmd: a.value, type: a.type });
        adapter.tricks = list;
        act("happy");
        say("pinned “" + a.title + "” ✨");
    }

    function forget(id) {
        adapter.tricks = (adapter.tricks || []).filter(t => t.id !== id);
    }

    function moveTrick(id, delta) {
        const list = (adapter.tricks || []).slice();
        const i = list.findIndex(t => t.id === id);
        const j = i + delta;
        if (i < 0 || j < 0 || j >= list.length)
            return;
        const t = list[i];
        list[i] = list[j];
        list[j] = t;
        adapter.tricks = list;
    }

    function resetTricks() {
        adapter.tricks = defaultTricks.slice();
    }

    // ── Settings ─────────────────────────────────────────────────────────────
    function setName(n) {
        if (n.trim())
            adapter.name = n.trim().slice(0, 24);
    }

    function setSpecies(s) {
        if (["cat", "fox", "bunny"].includes(s))
            adapter.species = s;
    }

    function setFur(f) {
        if (furNames.includes(f))
            adapter.fur = f;
    }

    function setChatty(n) {
        adapter.chatty = Math.max(0, Math.min(2, n));
    }

    function setRoam(r) {
        if (["bar", "left", "right", "still"].includes(r))
            adapter.roam = r;
    }

    function setShown(on) {
        adapter.shown = on;
    }

    function setSleepAtNight(on) {
        adapter.sleepAtNight = on;
    }

    function toggleHub() {
        hubOpen = !hubOpen;
        if (hubOpen) {
            touch();
            if (asleep)
                act("wake");
            act("notice");
        }
    }

    // ── Things it notices ────────────────────────────────────────────────────
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Energy drains while it's up and comes back while it sleeps.
    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: {
            root.energy = Math.max(0, Math.min(1, root.energy + (root.asleep ? 0.03 : -0.006)));
            // Now and then, when chatty, a thought of its own.
            if (!root.asleep && !root.hubOpen && Math.random() < 1 / 45)
                root.chat(2, root.mood === "hungry" ? root.pick("hungry") : root.pick("musings"));
        }
    }

    // Hello, once a day.
    function _greet() {
        const today = Qt.formatDate(new Date(), "yyyy-MM-dd");
        if (adapter.lastGreeting === today)
            return;
        adapter.lastGreeting = today;
        chat(1, greeting(), 5000);
    }

    Timer {
        id: greetTimer
        interval: 4000
        onTriggered: root._greet()
    }

    onReadyChanged: {
        if (!ready)
            return;
        if ((adapter.tricks || []).length === 0 && !adapter.seeded) {
            adapter.tricks = defaultTricks.slice();
            adapter.seeded = true;
        }
        greetTimer.start();
    }

    // Back from the lock screen: say hello.
    property int _unlocks: -1

    Connections {
        target: LockStats

        function onUnlocksChanged() {
            if (root._unlocks >= 0 && LockStats.unlocks > root._unlocks) {
                root.touch();
                root.act("wake");
                root.chat(1, root.pick("welcome"));
            }
            root._unlocks = LockStats.unlocks;
        }
    }

    Component.onCompleted: _unlocks = LockStats.ready ? LockStats.unlocks : -1

    // The battery, when it runs low.
    property int _batteryWarned: 100

    Connections {
        target: Battery

        function onPercentageChanged() {
            const p = Math.round(Battery.percentage);
            if (Battery.charging || p <= 0) {
                root._batteryWarned = 100;
                return;
            }
            if (p <= 10 && root._batteryWarned > 10) {
                root._batteryWarned = 10;
                root.act("alert");
                root.chat(0, root.pick("batteryLow", { n: p }), 7000);
            } else if (p <= 20 && root._batteryWarned > 20) {
                root._batteryWarned = 20;
                root.act("alert");
                root.chat(0, root.pick("battery", { n: p }), 6000);
            }
        }

        function onChargingChanged() {
            if (Battery.charging && root._batteryWarned <= 20)
                root.chat(1, root.pick("charged"));
        }
    }

    // New music (chatty only), and new notifications (it just perks up).
    property string _lastTrack: ""
    property double _lastTrackSaid: 0

    Connections {
        target: Media

        function onTitleChanged() {
            const t = Media.title;
            if (!Media.isPlaying || !t || t === root._lastTrack)
                return;
            root._lastTrack = t;
            if (Date.now() - root._lastTrackSaid > 600000 && Math.random() < 0.5) {
                root._lastTrackSaid = Date.now();
                root.chat(2, "♪ " + t);
            }
        }
    }

    property int _notifications: -1

    Connections {
        target: Notification

        function onDataChanged() {
            const n = Notification.data.length;
            if (root._notifications >= 0 && n > root._notifications)
                root.act("notice");
            root._notifications = n;
        }
    }

    // ── Settings file ────────────────────────────────────────────────────────
    Timer {
        id: writeTimer
        interval: 300
        onTriggered: petFile.writeAdapter()
    }

    FileView {
        id: petFile
        path: Quickshell.env("HOME") + "/.config/quickshell/pet.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeTimer.restart()
        onLoaded: root.ready = true
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound)
                root.ready = true;
        }

        adapter: JsonAdapter {
            id: adapter
            property string name: "Mochi"
            property string species: "cat"
            property string fur: "natural"
            property int chatty: 1
            property string roam: "bar"
            property bool shown: true
            property bool sleepAtNight: true
            property int affection: 0
            property double lastFed: 0
            property string lastGreeting: ""
            property bool seeded: false
            property var tricks: []
            property var recent: []
            property var reminders: []
        }
    }
}
