pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services as Services
import qs.modules.lock

// The power menu (SUPER+P, `qs ipc call powerMenu toggle`): lock, sleep,
// log out, restart and shut down, as a scene in the desktop theme's own
// idiom: talismans in the cave abode, an elevator's call panel, a ship's
// engine telegraph, candles in the nave… (one <Name>Power.qml per theme,
// PlainPower without one; each is a PowerScene).
//
// Opening grabs the screen first (ScreenCapture), so the scene's first
// frame is the desktop as it was (`world`); the intro then turns it into
// the scene (`intro` 0 → 1) and the outro runs it back.
//
// Lock and sleep close the menu and start the lock screen (Sleep locks,
// then suspends, as the control centre's does). Log out, restart and shut
// down play the scene's ceremony first (`rite` 0 → 1; Esc still turns it
// back), then go, the ceremony's last frame standing while the session
// ends. If the command fails, the menu opens back up and says why.
//
// Keys: arrows or Tab move, Enter or Space choose, 1–5 or L S O R P choose
// directly, Esc goes back (or turns a ceremony back).
Item {
    id: root

    anchors.fill: parent
    visible: false

    // ── The actions ──────────────────────────────────────────────────────
    // `quick` ones close the menu and hand over to the lock screen; the
    // others end the session.
    readonly property var actions: [
        { id: "lock", icon: "lock", label: "Lock", quick: true },
        { id: "sleep", icon: "bedtime", label: "Sleep", quick: true },
        { id: "logout", icon: "logout", label: "Log out", quick: false },
        { id: "reboot", icon: "restart_alt", label: "Restart", quick: false },
        { id: "poweroff", icon: "power_settings_new", label: "Shut down", quick: false }
    ]
    readonly property var keys: [Qt.Key_L, Qt.Key_S, Qt.Key_O, Qt.Key_R, Qt.Key_P]

    // ── What the scenes draw ─────────────────────────────────────────────
    // The action under the pointer or the keys (-1: none), and the one being
    // carried out.
    property int current: -1
    property int chosen: -1
    // 0 the desktop .. 1 the scene up; and 0 .. 1 through the chosen
    // action's ceremony. Both run linearly: scenes ease their own parts.
    property real intro: 0
    property real rite: 0
    // closed, capturing, opening, open, rite, gone (the command is running),
    // closing.
    property string phase: "closed"
    readonly property bool interactive: phase === "opening" || phase === "open"
    // Seconds since the scene came up, ticking only for scenes that ask
    // (`ambient`), at 30 fps.
    property real time: 0
    readonly property date now: clock.date
    // Layout scale: 1 on a 1920 × 1200 screen.
    readonly property real sc: Math.min(width / 1920, height / 1200)

    readonly property string themeId: Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""
    readonly property string userName: Quickshell.env("USER") || "you"
    property string hostName: ""
    // Seconds the machine has been up (read as the menu opens).
    readonly property real uptime: _bootUptime + time

    // The desktop as it was when the menu opened, a texture provider for
    // the scenes' shaders, and whether there is one (the grab can fail; the
    // scene then fades in over the live desktop).
    readonly property Item world: worldImage.image
    readonly property bool hasWorld: worldImage.ready && worldImage.source.toString() !== ""
    // The wallpaper itself, for scenes that paint or engrave it.
    readonly property url wallpaper: "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
    // A picture to use instead of a capture (tests).
    property url shot: ""

    readonly property PowerScene scene: sceneLoader.item as PowerScene

    property real _bootUptime: 0
    property real _t0: 0
    property bool _waiting: false
    property string _then: ""

    // ── Opening and closing ──────────────────────────────────────────────

    function toggle() {
        if (phase === "closed" || phase === "closing")
            open();
        else
            close();
    }

    function open() {
        if (phase === "closing") {
            // Changed our mind on the way out: back up from where it is
            // (and whatever was on its way, a lock, isn't).
            outroAnim.stop();
            _then = "";
            chosen = -1;
            rite = 0;
            phase = "opening";
            _startIntro();
            return;
        }
        if (phase !== "closed")
            return;
        current = -1;
        chosen = -1;
        rite = 0;
        intro = 0;
        time = 0;
        _t0 = Date.now();
        _then = "";
        uptimeFile.reload();
        phase = "capturing";
        if (shot.toString() !== "") {
            _show();
        } else {
            captureLoader.active = true;
        }
    }

    function close() {
        if (phase === "closed" || phase === "closing")
            return;
        if (phase === "capturing")
            return _shut();
        introAnim.stop();
        riteAnim.stop();
        unriteAnim.stop();
        _waiting = false;
        startAnyway.stop();
        phase = "closing";
        outroAnim.duration = Math.max(1, (scene?.outroMs ?? 320) * intro);
        outroAnim.restart();
    }

    function _show() {
        if (phase !== "capturing")
            return;
        phase = "opening";
        current = scene?.defaultCurrent ?? -1;
        visible = true;
        forceActiveFocus();
        // The panels' surface grows to the screen as this shows, and its
        // first full-size frame comes a little later: the intro starts on
        // that frame, or it would jump.
        _waiting = true;
        startAnyway.restart();
    }

    function _startIntro() {
        _waiting = false;
        startAnyway.stop();
        introAnim.duration = Math.max(1, (scene?.introMs ?? 600) * (1 - intro));
        introAnim.restart();
    }

    // All the way down: drop the scene and the grab, then run what was
    // chosen (the lock screen grabs the desktop first, so it waits for us).
    function _shut() {
        introAnim.stop();
        outroAnim.stop();
        riteAnim.stop();
        unriteAnim.stop();
        watchdog.stop();
        startAnyway.stop();
        _waiting = false;
        visible = false;
        phase = "closed";
        intro = 0;
        rite = 0;
        chosen = -1;
        current = -1;
        captureLoader.active = false;
        if (_then) {
            Quickshell.execDetached(["sh", "-c", "sleep 0.05; " + _then]);
            _then = "";
        }
    }

    Connections {
        target: root.Window.window
        enabled: root._waiting

        function onFrameSwapped() {
            if (root.Window.window.width >= root.width)
                root._startIntro();
        }
    }

    // in case that frame never comes
    Timer {
        id: startAnyway
        interval: 250
        onTriggered: root._startIntro()
    }

    NumberAnimation {
        id: introAnim
        target: root
        property: "intro"
        to: 1
        onFinished: {
            if (root.phase === "opening")
                root.phase = "open";
        }
    }

    NumberAnimation {
        id: outroAnim
        target: root
        property: "intro"
        to: 0
        onFinished: root._shut()
    }

    // ── Choosing ─────────────────────────────────────────────────────────

    function hover(i) {
        if (interactive && i >= 0 && i < actions.length)
            current = i;
    }

    function step(d) {
        if (!interactive)
            return;
        const n = actions.length;
        current = current < 0 ? (d > 0 ? 0 : n - 1) : (current + d + n) % n;
    }

    function choose(i) {
        if (!interactive || i < 0 || i >= actions.length)
            return;
        if (phase === "opening") {
            introAnim.stop();
            intro = 1;
        }
        current = i;
        chosen = i;
        phase = "rite";
        const quick = actions[i].quick;
        riteAnim.duration = Math.max(1, quick ? (scene?.quickMs ?? 220) : (scene?.riteMs ?? 1800));
        riteAnim.restart();
    }

    // Back out of a ceremony that hasn't gone yet.
    function cancel() {
        if (phase !== "rite")
            return;
        riteAnim.stop();
        phase = "open";
        unriteAnim.duration = Math.max(1, 360 * rite);
        unriteAnim.restart();
    }

    readonly property string lockCommand: "exec quickshell -p \"$HOME/.config/quickshell/Lock.qml\""

    function _ritesDone() {
        if (phase !== "rite")
            return;
        const a = actions[chosen];
        if (a.quick) {
            // Out of the way first: the lock screen starts from a grab.
            _then = (a.id === "sleep" ? "QS_LOCK_THEN=suspend " : "") + lockCommand;
            close();
            return;
        }
        phase = "gone";
        runner.command = a.id === "logout" ? ["loginctl", "terminate-user", userName]
            : a.id === "reboot" ? ["systemctl", "reboot"] : ["systemctl", "poweroff"];
        runner.running = true;
        watchdog.restart();
    }

    // It didn't go: open back up, and say why.
    function _failed(why) {
        if (phase !== "gone")
            return;
        watchdog.stop();
        const a = actions[chosen];
        const what = a.id === "logout" ? "log out" : a.id === "reboot" ? "restart" : "shut down";
        Quickshell.execDetached(["notify-send", "-a", "Power", "-i", "dialog-warning", "Couldn't " + what,
            (why || "").trim() || "It was refused, or something is holding it up."]);
        phase = "open";
        unriteAnim.duration = 420;
        unriteAnim.restart();
    }

    NumberAnimation {
        id: riteAnim
        target: root
        property: "rite"
        to: 1
        onFinished: root._ritesDone()
    }

    NumberAnimation {
        id: unriteAnim
        target: root
        property: "rite"
        to: 0
        easing.type: Easing.OutCubic
        onFinished: {
            if (root.phase === "open")
                root.chosen = -1;
        }
    }

    Process {
        id: runner
        stderr: StdioCollector {
            id: runnerErr
        }
        onExited: (code, status) => {
            watchdog.stop();
            if (code !== 0)
                root._failed(runnerErr.text);
        }
    }

    // A command that hasn't even returned long after (waiting on a
    // password prompt, say) isn't happening.
    Timer {
        id: watchdog
        interval: 30000
        onTriggered: {
            if (runner.running)
                root._failed("It's still waiting for something, perhaps a password.");
        }
    }

    // Puts the menu in a state and holds it there (tests).
    function pose(i, cur, ch, r) {
        introAnim.stop();
        outroAnim.stop();
        riteAnim.stop();
        unriteAnim.stop();
        intro = i;
        current = cur;
        chosen = ch;
        rite = r;
        phase = ch >= 0 ? "rite" : "open";
    }

    // ── Keys ─────────────────────────────────────────────────────────────

    Keys.onPressed: event => {
        const k = event.key;
        if (k === Qt.Key_Escape) {
            // Even once it has gone (the last frame of the ceremony stays
            // up while the session ends), Esc takes it down, in case the
            // session doesn't end.
            if (phase === "rite")
                cancel();
            else
                close();
        } else if (k === Qt.Key_Left || k === Qt.Key_Up || k === Qt.Key_Backtab) {
            step(-1);
        } else if (k === Qt.Key_Right || k === Qt.Key_Down || k === Qt.Key_Tab) {
            step(1);
        } else if (k === Qt.Key_Home) {
            hover(0);
        } else if (k === Qt.Key_End) {
            hover(actions.length - 1);
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
            choose(current);
        } else if (k >= Qt.Key_1 && k <= Qt.Key_5) {
            choose(k - Qt.Key_1);
        } else if (keys.includes(k) && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            choose(keys.indexOf(k));
        } else {
            return;
        }
        event.accepted = true;
    }

    // ── The desktop, grabbed ─────────────────────────────────────────────

    LazyLoader {
        id: captureLoader
        active: false

        ScreenCapture {
            timeoutMs: 260
            onFinished: root._show()
        }
    }

    readonly property url _shotUrl: {
        if (shot.toString() !== "")
            return shot;
        const cap = captureLoader.item as ScreenCapture;
        if (!cap)
            return "";
        const scr = root.Window.window ? root.Window.window.screen : null;
        const byName = scr ? cap.shots[scr.name] : undefined;
        const any = Object.values(cap.shots)[0];
        return (byName ?? any)?.url ?? "";
    }

    CaptureImage {
        id: worldImage
        source: root.visible ? root._shotUrl : ""
        imageWidth: root.width
        imageHeight: root.height
    }

    // ── The scene ────────────────────────────────────────────────────────

    // Clicks that miss the actions go back.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: {
            if (root.phase === "rite")
                root.cancel();
            else if (root.interactive)
                root.close();
        }
    }

    // Only the theme's own scene is built, and only while the menu is up.
    Loader {
        id: sceneLoader
        anchors.fill: parent
        active: root.phase !== "closed"
        sourceComponent: ({
            "": plainScene,
            hud: hudScene,
            terminal: terminalScene,
            cosmos: cosmosScene,
            zen: zenScene,
            cyberpunk: neonScene,
            wabisabi: wabiScene,
            artdeco: decoScene,
            gothic: gothicScene,
            newspaper: broadsheetScene,
            wasteland: wastelandScene,
            observatory: observatoryScene,
            abyss: abyssScene,
            devaloka: devalokaScene,
            siege: siegeScene,
            sekiro: sekiroScene,
            xianxia: xianxiaScene
        })[root.themeId] ?? plainScene
    }

    Component {
        id: sekiroScene
        SekiroPower {
            menu: root
        }
    }

    Component {
        id: siegeScene
        SiegePower {
            menu: root
        }
    }

    Component {
        id: devalokaScene
        DevalokaPower {
            menu: root
        }
    }

    Component {
        id: abyssScene
        AbyssPower {
            menu: root
        }
    }

    Component {
        id: observatoryScene
        ObservatoryPower {
            menu: root
        }
    }

    Component {
        id: wastelandScene
        WastelandPower {
            menu: root
        }
    }

    Component {
        id: broadsheetScene
        BroadsheetPower {
            menu: root
        }
    }

    Component {
        id: gothicScene
        GothicPower {
            menu: root
        }
    }

    Component {
        id: decoScene
        DecoPower {
            menu: root
        }
    }

    Component {
        id: wabiScene
        WabiPower {
            menu: root
        }
    }

    Component {
        id: neonScene
        NeonPower {
            menu: root
        }
    }

    Component {
        id: zenScene
        ZenPower {
            menu: root
        }
    }

    Component {
        id: cosmosScene
        CosmosPower {
            menu: root
        }
    }

    Component {
        id: terminalScene
        TerminalPower {
            menu: root
        }
    }

    Component {
        id: hudScene
        HudPower {
            menu: root
        }
    }

    Component {
        id: plainScene
        PlainPower {
            menu: root
        }
    }

    Component {
        id: xianxiaScene
        XianxiaPower {
            menu: root
        }
    }

    // ── Odds and ends ────────────────────────────────────────────────────

    SystemClock {
        id: clock
        enabled: root.visible
        precision: SystemClock.Minutes
    }

    Timer {
        interval: 33
        repeat: true
        running: root.visible && (root.scene?.ambient ?? false)
        onTriggered: root.time = (Date.now() - root._t0) / 1000
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        printErrors: false
        onLoaded: root._bootUptime = parseFloat(text().split(" ")[0]) || 0
    }

    FileView {
        path: "/etc/hostname"
        printErrors: false
        onLoaded: root.hostName = text().trim().split(".")[0]
    }
}
