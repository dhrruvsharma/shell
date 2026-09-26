pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import qs.modules.lock
import qs.services as Services

// "Mainframe" theme: a phosphor CRT console.
//
// Lock-in: the desktop turns into a CRT picture (curvature, scanlines), then
// powers off like an old set: it collapses into a bright line, then a dot.
// The console powers on and types out its lockdown log; you log in at the
// Password: prompt. Unlocking prints the session summary (XP, level, trophies)
// as log lines, powers the console off and the desktop back on.
//
// Theme contract (see ThemeHost): ctx, shot, shown, still, minScale.
Item {
    id: term

    required property LockContext ctx
    property url shot
    property bool shown: true
    property bool still: false
    property real minScale: 0.7

    readonly property real sc: Math.max(minScale, Math.min(2, Math.min(width / 1920, height / 1080)))
    readonly property string mono: "Iosevka Nerd Font"
    readonly property real fontPx: 20 * sc
    readonly property real lineH: Math.round(fontPx * 1.4)
    readonly property real margin: 64 * sc
    readonly property int cols: Math.max(20, Math.floor((width - 2 * margin) / Math.max(1, glyph.advanceWidth)))

    readonly property color ph: LockTheme.accent
    readonly property color phHi: Qt.lighter(ph, 1.18)
    readonly property color phDim: Qt.rgba(ph.r * 0.55, ph.g * 0.55, ph.b * 0.55, 1)
    readonly property color err: LockTheme.danger
    readonly property string user: ctx.userName
    property string host: "mainframe"
    property real uptimeAtLock: -1

    // Choreography: the capture's and the console's CRT "tubes".
    property real shotOn: 1
    property real shotCrt: 0
    property real shotSqX: 1
    property real shotSqY: 1
    property real shotFlash: 0
    property real termOn: 0
    property real termSqX: 1
    property real termSqY: 0
    property real termFlash: 0
    property real glitch: 0

    property bool cursorOn: true
    property int spin: 0
    property var _queue: []
    property int _typedChars: 0

    // ── Log ──────────────────────────────────────────────────────────
    function esc(s) {
        return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/ /g, "&nbsp;");
    }

    function toneColor(tone) {
        return tone === "err" ? err : tone === "dim" ? phDim : tone === "hi" ? phHi : ph;
    }

    // One log line: an optional [ TAG ] in bright bold, then the text.
    function styled(tag, text, tone) {
        const body = '<font color="' + toneColor(tone) + '">' + esc(text) + "</font>";
        if (!tag)
            return body;
        return '<font color="' + phHi + '"><b>' + esc("[" + tag + "]") + "</b></font>" + esc(" ") + body;
    }

    function say(tag, text, tone, typed) {
        const q = _queue.slice();
        q.push({ tag: tag || "", text: text, tone: tone || "plain", typed: typed === true });
        _queue = q;
        if (still)
            flush();
        else if (!pump.running)
            pump.start();
    }

    function flush() {
        while (_queue.length > 0)
            pumpOnce(true);
    }

    function pushLine(html) {
        log.append({ html: html });
        const max = Math.max(4, Math.floor(logArea.height / lineH) - 2);
        while (log.count > max)
            log.remove(0);
    }

    // Moves the queue along: typed lines appear a character at a time,
    // the others whole.
    function pumpOnce(instant) {
        if (_queue.length === 0)
            return false;
        const item = _queue[0];
        if (item.typed && !instant) {
            if (_typedChars === 0)
                pushLine("");
            _typedChars += 1;
            log.setProperty(log.count - 1, "html", styled(item.tag, String(item.text).slice(0, _typedChars), item.tone) + '<font color="' + phHi + '">█</font>');
            if (_typedChars < item.text.length)
                return true;
            log.setProperty(log.count - 1, "html", styled(item.tag, item.text, item.tone));
            _typedChars = 0;
        } else {
            pushLine(styled(item.tag, item.text, item.tone));
        }
        _queue = _queue.slice(1);
        return true;
    }

    function boot() {
        const lives = ctx.maxLives > 0 ? "faillock: " + ctx.maxLives + " attempts" : "faillock off";
        say("", "> lockdown --user " + user + " --reason away", "hi", true);
        say("  OK  ", "Suspended input devices");
        say("  OK  ", "Sealed the session keyring");
        say("  OK  ", "Armed intrusion countermeasures (" + lives + ")");
        say(" LOCK ", "Session locked at " + Qt.formatTime(new Date(ctx.lockedAt), "hh:mm:ss"), "hi");
        say("", " ");
        say("", host + " login: " + user);
    }

    Timer {
        id: pump
        interval: term._typedChars > 0 || (term._queue.length > 0 && term._queue[0].typed) ? 14 : 75
        repeat: true
        onTriggered: {
            if (!term.pumpOnce(false))
                stop();
        }
    }

    ListModel {
        id: log
    }

    Connections {
        target: term.ctx

        function onPhaseChanged() {
            if (term.ctx.phase === "exiting") {
                intro.stop();
                outro.start();
            }
        }

        function onDenied(costLife) {
            glitchFx.restart();
            term.say("", "Login incorrect", "err");
            if (costLife && term.ctx.maxLives > 0) {
                const left = term.ctx.lives;
                if (left > 0)
                    term.say(" WARN ", "Intrusion attempt logged. " + left + (left === 1 ? " attempt" : " attempts") + " left before lockout", "err");
                else
                    term.say(" LOCK ", "Account locked by faillock for " + Math.round(term.ctx.unlockTime / 60) + " min", "err");
            }
            term.say("", " ");
            term.say("", term.host + " login: " + term.user);
        }

        function onGranted() {
            const r = term.ctx.reward;
            term.say("", "Authentication successful.", "hi");
            term.say("", "Last login: " + Qt.formatDateTime(new Date(term.ctx.lockedAt), "ddd MMM d hh:mm:ss") + " on tty1", "dim");
            if (r) {
                const parts = r.lines.map(l => "+" + l.xp + " " + l.label.toLowerCase()).join("  ");
                const streak = r.multiplier > 1 ? "  (streak x" + r.multiplier.toFixed(2) + ")" : "";
                term.say("  XP  ", parts + streak + "  = +" + r.total);
                if (r.levelAfter > r.levelBefore)
                    term.say(" LVL  ", "Level " + r.levelBefore + " -> " + r.levelAfter + "  " + Services.LockStats.rankFor(r.levelAfter), "hi");
                if (r.achievements.length > 0)
                    term.say(" ACH  ", r.achievements.map(a => a.name).join(" · "), "hi");
            }
            term.say("", "Welcome back, " + term.user + ".", "hi");
        }

        function onMessageChanged() {
            if (term.ctx.message.length > 0)
                term.say(" PAM  ", term.ctx.message, "err");
        }
    }

    Timer {
        interval: 530
        repeat: true
        running: !term.still && term.ctx.awake && term.ctx.phase !== "verifying"
        onRunningChanged: if (!running) term.cursorOn = true
        onTriggered: term.cursorOn = !term.cursorOn
    }

    Timer {
        interval: 90
        repeat: true
        running: term.ctx.phase === "verifying"
        onTriggered: term.spin += 1
    }

    FileView {
        path: "/etc/hostname"
        printErrors: false
        onLoaded: {
            const h = text().trim();
            if (h.length > 0)
                term.host = h;
        }
    }

    FileView {
        path: "/proc/uptime"
        printErrors: false
        onLoaded: term.uptimeAtLock = parseFloat(text()) - (Date.now() - term.ctx.lockedAt) / 1000
    }

    // ── Info boxes ───────────────────────────────────────────────────
    readonly property int boxW: 38

    function boxTop(title) {
        return "┌─ " + title + " " + "─".repeat(Math.max(0, boxW - title.length - 5)) + "┐";
    }

    function boxRow(label, value) {
        const inner = (label.padEnd(10) + value).slice(0, boxW - 4);
        return "│ " + inner.padEnd(boxW - 4) + " │";
    }

    function boxBottom() {
        return "└" + "─".repeat(boxW - 2) + "┘";
    }

    function bar(fraction, width) {
        const n = Math.max(0, Math.min(width, Math.round(fraction * width)));
        return "[" + "#".repeat(n) + "-".repeat(width - n) + "]";
    }

    // tty-clock style digits: a 3x5 bitmap per character.
    readonly property var digitRows: ({
        "0": ["111", "101", "101", "101", "111"],
        "1": ["010", "110", "010", "010", "111"],
        "2": ["111", "001", "111", "100", "111"],
        "3": ["111", "001", "111", "001", "111"],
        "4": ["101", "101", "111", "001", "001"],
        "5": ["111", "100", "111", "001", "111"],
        "6": ["111", "100", "111", "101", "111"],
        "7": ["111", "001", "001", "001", "001"],
        "8": ["111", "101", "111", "101", "111"],
        "9": ["111", "101", "111", "001", "111"],
        ":": ["0", "1", "0", "1", "0"]
    })

    function uptime() {
        if (uptimeAtLock < 0)
            return "?";
        const s = Math.floor(uptimeAtLock + (ctx.now.getTime() - ctx.lockedAt) / 1000);
        const h = Math.floor(s / 3600);
        const m = Math.floor(s / 60) % 60;
        return h > 0 ? h + "h " + m + "m" : m + "m";
    }

    // ── Scene ────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    LockInput {
        ctx: term.ctx
        active: !term.still
        onEscapePressed: term.ctx.clearInput()
    }

    TextMetrics {
        id: glyph
        font.family: term.mono
        font.pixelSize: term.fontPx
        text: "M"
    }

    // The console itself, drawn through the CRT shader as its layer effect.
    Item {
        id: tty
        anchors.fill: parent
        visible: term.termOn > 0
        layer.enabled: true
        layer.effect: ShaderEffect {
            property real itemWidth: width
            property real itemHeight: height
            property real crt: 1
            property real bloom: 1
            property real squashX: term.termSqX
            property real squashY: term.termSqY
            property real flash: term.termFlash
            property real glitch: term.glitch
            property real time: term.ctx.ambientTime

            fragmentShader: Qt.resolvedUrl("../../../../shaders/lock_crt.frag.qsb")
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(term.ph.r * 0.035, term.ph.g * 0.035, term.ph.b * 0.035, 1)
        }

        Text {
            x: term.margin
            y: 48 * term.sc
            textFormat: Text.PlainText
            font.family: term.mono
            font.pixelSize: term.fontPx
            color: term.phHi
            readonly property string leftPart: term.host.toUpperCase() + "-OS 6.6 LTS  ·  SECURE CONSOLE  ·  tty1"
            readonly property string rightPart: Qt.formatDateTime(term.ctx.now, "ddd yyyy-MM-dd  hh:mm:ss").toUpperCase()
            text: leftPart + " ".repeat(Math.max(1, term.cols - leftPart.length - rightPart.length)) + rightPart
        }

        Text {
            x: term.margin
            y: 48 * term.sc + term.lineH
            textFormat: Text.PlainText
            font.family: term.mono
            font.pixelSize: term.fontPx
            color: term.phDim
            text: "═".repeat(term.cols)
        }

        Item {
            id: logArea
            x: term.margin
            y: 48 * term.sc + term.lineH * 3
            width: term.width - 2 * term.margin - (term.boxW + 4) * glyph.advanceWidth
            height: bigClockText.y - y - term.lineH

            Column {
                id: logColumn
                width: parent.width

                Repeater {
                    model: log

                    Text {
                        required property string html
                        width: logColumn.width
                        height: term.lineH
                        elide: Text.ElideRight
                        textFormat: Text.StyledText
                        font.family: term.mono
                        font.pixelSize: term.fontPx
                        color: term.ph
                        text: html
                    }
                }

                // The live prompt.
                Text {
                    width: logColumn.width
                    height: term.lineH
                    visible: term.ctx.phase !== "granted" && term.ctx.phase !== "exiting" && term._queue.length === 0 && log.count > 0
                    textFormat: Text.StyledText
                    font.family: term.mono
                    font.pixelSize: term.fontPx
                    color: term.ph
                    readonly property string stars: "*".repeat(Math.min(term.ctx.cells, 64))
                    readonly property string tail: {
                        const c = term.ctx;
                        if (c.phase === "verifying")
                            return '&nbsp;&nbsp;<font color="' + term.phDim + '">authenticating&nbsp;' + "|/-\\".charAt(term.spin % 4) + "</font>";
                        if (c.lockedOut && c.cells === 0)
                            return '<font color="' + term.err + '">' + term.esc("[LOCKED - retry in " + (c.lockoutClock || "?") + "]") + "</font>";
                        const cursor = term.cursorOn ? '<font color="' + term.phHi + '">█</font>' : "";
                        const caps = c.capsLock ? '&nbsp;&nbsp;<font color="' + term.err + '">[CAPS]</font>' : "";
                        return cursor + caps;
                    }
                    text: "Password:&nbsp;" + '<font color="' + (term.ctx.denying ? term.err : term.phHi) + '">' + stars + "</font>" + tail
                }
            }
        }

        // Big tty-clock digits, one lit square per bitmap pixel.
        Row {
            id: bigClockText

            readonly property real px: 22 * term.sc
            readonly property bool colonOn: term.ctx.now.getSeconds() % 2 === 0

            x: logArea.x + (logArea.width - width) / 2
            y: term.height * 0.56
            spacing: px * 1.1

            Repeater {
                model: Qt.formatTime(term.ctx.now, "hh:mm").split("")

                Grid {
                    id: digit
                    required property string modelData
                    readonly property var bitmap: term.digitRows[modelData] ?? term.digitRows["0"]
                    columns: bitmap[0].length
                    spacing: bigClockText.px * 0.16

                    Repeater {
                        model: digit.bitmap.length * digit.columns

                        Rectangle {
                            required property int index
                            readonly property bool lit: digit.bitmap[Math.floor(index / digit.columns)].charAt(index % digit.columns) === "1"
                                && (digit.modelData !== ":" || bigClockText.colonOn)
                            width: bigClockText.px
                            height: bigClockText.px
                            color: lit ? term.phHi : Qt.rgba(term.ph.r, term.ph.g, term.ph.b, 0.05)
                        }
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: bigClockText.horizontalCenter
            anchors.top: bigClockText.bottom
            anchors.topMargin: term.lineH * 0.6
            textFormat: Text.PlainText
            font.family: term.mono
            font.pixelSize: term.fontPx
            font.letterSpacing: 4 * term.sc
            color: term.phDim
            text: Qt.formatDate(term.ctx.now, "dddd d MMMM yyyy").toUpperCase()
        }

        Column {
            anchors.right: parent.right
            anchors.rightMargin: term.margin
            y: 48 * term.sc + term.lineH * 3

            Text {
                textFormat: Text.PlainText
                font.family: term.mono
                font.pixelSize: term.fontPx
                lineHeight: term.lineH
                lineHeightMode: Text.FixedHeight
                color: term.ph
                readonly property real pct: Services.Battery.percentage
                text: [
                    term.boxTop("SYSTEM"),
                    term.boxRow("host", term.host),
                    term.boxRow("uptime", term.uptime()),
                    term.boxRow("power", term.bar(pct / 100, 10) + " " + Math.round(pct) + "%" + (Services.Battery.charging ? " AC" : "")),
                    term.boxRow("audio", Services.Media.activePlayer ? (Services.Media.isPlaying ? "> " : "|| ") + Services.Media.title : "idle"),
                    term.boxRow("keymap", (term.ctx.layout || "--") + (term.ctx.capsLock ? "  CAPS" : "")),
                    term.boxBottom()
                ].join("\n")
            }

            Item {
                width: 1
                height: term.lineH
            }

            Text {
                textFormat: Text.PlainText
                font.family: term.mono
                font.pixelSize: term.fontPx
                lineHeight: term.lineH
                lineHeightMode: Text.FixedHeight
                color: term.ph
                readonly property int lvl: Services.LockStats.level
                readonly property int floorXp: Services.LockStats.xpForLevel(lvl)
                readonly property int ceilXp: Services.LockStats.xpForLevel(lvl + 1)
                readonly property int xpIn: Services.LockStats.xp - floorXp
                text: [
                    term.boxTop("PLAYER"),
                    term.boxRow("user", term.user),
                    term.boxRow("level", lvl + " · " + Services.LockStats.rank),
                    term.boxRow("xp", term.bar(xpIn / Math.max(1, ceilXp - floorXp), 10) + " " + xpIn + "/" + (ceilXp - floorXp)),
                    term.boxRow("streak", Services.LockStats.liveStreak + " days"),
                    term.boxRow("trophies", Services.LockStats.achievements.length + "/" + Services.LockStats.achievementDefs.length),
                    term.boxRow("attempts", term.ctx.maxLives > 0 ? "[" + "■".repeat(term.ctx.lives) + "□".repeat(Math.max(0, term.ctx.maxLives - term.ctx.lives)) + "]" : "unlimited"),
                    term.boxBottom()
                ].join("\n")
            }
        }

        Text {
            x: term.margin
            anchors.bottom: powerRow.top
            anchors.bottomMargin: term.lineH * 0.5
            textFormat: Text.PlainText
            font.family: term.mono
            font.pixelSize: term.fontPx
            color: term.phDim
            text: "─".repeat(term.cols)
        }

        Row {
            id: powerRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 56 * term.sc
            spacing: 3 * glyph.advanceWidth

            Repeater {
                model: [
                    { label: "SLEEP", act: "suspend" },
                    { label: "REBOOT", act: "reboot" },
                    { label: "HALT", act: "poweroff" }
                ]

                Text {
                    id: key
                    required property var modelData
                    textFormat: Text.PlainText
                    font.family: term.mono
                    font.pixelSize: term.fontPx
                    color: hold.containsMouse || hold.progress > 0 ? term.phHi : term.phDim
                    readonly property int filled: Math.round(hold.progress * 8)
                    text: "[ " + modelData.label + (hold.progress > 0 ? " " + "█".repeat(filled) + "░".repeat(8 - filled) : "") + " ]"

                    HoldArea {
                        id: hold
                        anchors.fill: parent
                        anchors.margins: -10 * term.sc
                        enabled: !term.still
                        onConfirmed: term.ctx[key.modelData.act]()
                    }
                }
            }

            Text {
                textFormat: Text.PlainText
                font.family: term.mono
                font.pixelSize: term.fontPx
                color: term.phDim
                text: "(hold)"
            }
        }
    }

    // ── The captured desktop, on its own tube ────────────────────────
    CaptureImage {
        id: capture
        source: term.shot
        imageWidth: term.width
        imageHeight: term.height
    }

    ShaderEffect {
        anchors.fill: parent
        visible: capture.ready && term.shotOn > 0
        opacity: term.shotOn

        property variant source: capture.image
        property real itemWidth: width
        property real itemHeight: height
        property real crt: term.shotCrt
        property real bloom: 0
        property real squashX: term.shotSqX
        property real squashY: term.shotSqY
        property real flash: term.shotFlash
        property real glitch: 0
        property real time: term.ctx.ambientTime

        fragmentShader: Qt.resolvedUrl("../../../../shaders/lock_crt.frag.qsb")
    }

    // ── Choreography ─────────────────────────────────────────────────
    property bool _introStarted: false

    function startIntro() {
        if (_introStarted)
            return;
        _introStarted = true;
        introFallback.stop();
        if (capture.ready) {
            intro.start();
        } else {
            shotOn = 0;
            powerOn.start();
        }
    }

    onShownChanged: if (shown && !still) startIntro()
    Component.onCompleted: {
        if (still) {
            shotOn = 0;
            termOn = 1;
            termSqY = 1;
            boot();
        } else if (shown) {
            startIntro();
        } else {
            introFallback.start();
        }
    }

    Timer {
        id: introFallback
        interval: 500
        onTriggered: term.startIntro()
    }

    // Desktop -> CRT picture -> line -> dot -> off, then the console on.
    SequentialAnimation {
        id: intro
        PauseAnimation { duration: 80 }
        NumberAnimation { target: term; property: "shotCrt"; from: 0; to: 1; duration: 300; easing.type: Easing.OutQuad }
        NumberAnimation { target: term; property: "shotSqY"; to: 0; duration: 170; easing.type: Easing.InQuad }
        NumberAnimation { target: term; property: "shotSqX"; to: 0; duration: 140; easing.type: Easing.InQuad }
        NumberAnimation { target: term; property: "shotOn"; to: 0; duration: 120 }
        ScriptAction { script: powerOn.start() }
    }

    SequentialAnimation {
        id: powerOn
        PropertyAction { target: term; property: "termSqY"; value: 0 }
        PropertyAction { target: term; property: "termFlash"; value: 0.7 }
        PropertyAction { target: term; property: "termOn"; value: 1 }
        ParallelAnimation {
            NumberAnimation { target: term; property: "termSqY"; to: 1; duration: 260; easing.type: Easing.OutCubic }
            NumberAnimation { target: term; property: "termFlash"; to: 0; duration: 420; easing.type: Easing.OutQuad }
        }
        ScriptAction { script: term.boot() }
    }

    // Console off, then the desktop's tube back on and the CRT look away:
    // the last frame is the desktop exactly.
    SequentialAnimation {
        id: outro
        ScriptAction { script: { pump.stop(); powerOn.stop(); } }
        ParallelAnimation {
            NumberAnimation { target: term; property: "termSqY"; to: 0; duration: 180; easing.type: Easing.InQuad }
            NumberAnimation { target: term; property: "termFlash"; to: 0.6; duration: 180 }
        }
        NumberAnimation { target: term; property: "termSqX"; to: 0; duration: 130; easing.type: Easing.InQuad }
        NumberAnimation { target: term; property: "termOn"; to: 0; duration: 90 }
        ScriptAction {
            script: {
                if (!capture.ready)
                    return;
                term.shotCrt = 1;
                term.shotSqX = 1;
                term.shotSqY = 0;
                term.shotFlash = 1;
                term.shotOn = 1;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: term; property: "shotSqY"; to: 1; duration: 240; easing.type: Easing.OutCubic }
            NumberAnimation { target: term; property: "shotFlash"; to: 0; duration: 320; easing.type: Easing.OutQuad }
        }
        NumberAnimation { target: term; property: "shotCrt"; to: 0; duration: 250; easing.type: Easing.InOutQuad }
    }

    SequentialAnimation {
        id: glitchFx
        NumberAnimation { target: term; property: "glitch"; to: 1; duration: 60 }
        PauseAnimation { duration: 180 }
        NumberAnimation { target: term; property: "glitch"; to: 0; duration: 220 }
    }
}
