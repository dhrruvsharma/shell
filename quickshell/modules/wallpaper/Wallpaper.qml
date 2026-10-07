pragma ComponentBehavior: Bound
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import qs.services
import qs.colors
import qs.components
import qs.modules.lock
import qs.settings

// Wallpaper picker (SUPER+W, `qs ipc call wallpaper toggle|wallhaven`): a
// deck of swatch cards.
//
// Every wallpaper is a paint-chip card (SwatchCard) dressed in the colour
// scheme it would give the desktop, read with matugen as a dry run
// (services/WallpaperSwatches): the card is the scheme's surface, its text
// the on-surface, its strip of chips the roles with their hex codes. The
// cards are held fanned out like a hand along the foot of the screen;
// behind them the whole screen previews the card in front at full size,
// and the picker's own accents take on its colours, so browsing is trying
// each wallpaper on.
//
// Sources: Local (the wallpaper folder), Favourites (the hearted ones) and
// Wallhaven (search results fetched page by page as you reach the end;
// setting one downloads it first; their cards wear the colours Wallhaven
// reports for the image). Local cards sort by name, by colour (round the
// hue wheel: the deck becomes a spectrum) or newest first. The ribbon under
// the header is the whole deck in colour: hover for a glimpse, click or
// drag to go there. The gear opens the settings: the wallpaper folder
// (~/Pictures/wallpapers by default) and a Wallhaven API key.
//
// Keys: ←→ browse, Home/End, PgUp/PgDn, R a random card, Enter set, F
// favourite, S sort, Space peek (hold, or tap to keep: the deck steps aside
// for a clear look), Tab next source, / search (Wallhaven), Esc close.
// Mouse: wheel or drag anywhere to browse, click a card to bring it to the
// front, click the front card (or double-click any) to set it, click the
// picture itself to peek.
//
// Loaded per opening (shell.qml's wallpaperLoader) and destroyed once
// closed, so its pictures don't stay in memory. Every opening starts on
// the wallpaper on screen, in Local, with a blank Wallhaven search; the
// sort order is kept for the session.
Item {
    id: window

    readonly property string srcDir: "file://" + WallpaperEngine.dir
    property bool settingsOpen: false

    // ── What's in the deck ───────────────────────────────────────────────
    // Source: "local", "favorites" or "wallhaven".
    property string mode: "local"
    readonly property var modes: ["local", "favorites", "wallhaven"]
    readonly property bool favoritesOnly: mode === "favorites"
    readonly property bool online: mode === "wallhaven"
    readonly property string sort: WallpaperSwatches.sort
    readonly property var sorts: ["name", "colour", "newest"]

    // Every local wallpaper as listed: [{ fileName, fileUrl, modified, size,
    // video }] (a video's picture is a frame of it: pictureOf()).
    property var allWallpapers: []
    // ...in the chosen order (set by resort(): the colour sort waits for
    // the colours rather than reshuffling as each one is read).
    property var sortedWallpapers: []
    readonly property var displayedWallpapers: {
        if (online)
            return Wallhaven.onlineWallpapers.map(w => ({ fileName: w.id, fileUrl: w.thumbUrl, fullUrl: w.fullUrl, resolution: w.resolution, colors: w.colors ?? [], favorites: w.favorites ?? 0, fileSize: w.fileSize ?? 0, item: w }));
        if (!favoritesOnly)
            return sortedWallpapers;
        const favs = WallpaperFavorites.favorites;
        return sortedWallpapers.filter(w => favs.indexOf(w.fileName) >= 0);
    }
    // Local file names, for "already saved" checks on Wallhaven results.
    readonly property var localNames: {
        const set = {};
        for (const w of allWallpapers)
            set[w.fileName] = true;
        return set;
    }
    // The last Wallhaven result a download was started for (for "retry").
    property string lastDownload: ""

    readonly property int count: displayedWallpapers.length
    property int currentIndex: -1
    readonly property var currentEntry: currentIndex >= 0 && currentIndex < count ? displayedWallpapers[currentIndex] : null
    readonly property string currentName: currentEntry ? currentEntry.fileName : ""
    readonly property string activeName: WallpaperEngine.current.split("/").pop()
    // The card in front, kept across re-sorts and filtering.
    property string frontName: ""
    property bool modeChanging: false

    // ── The hand ─────────────────────────────────────────────────────────
    // Design pixels scale with the screen (1920×1200 is 1).
    readonly property real u: Math.max(0.6, Math.min(width / 1920, height / 1200))
    // The deck's position: the index in front, fractional while it moves.
    property real pos: 0
    // Cards shown on each side of the one in front, and the slots that
    // show them (two spare: a slot changes card only out of sight).
    readonly property int side: 7
    readonly property int slots: 2 * side + 3
    readonly property real cardW: 212 * u
    readonly property real cardH: gauge.implicitHeight
    // The cards turn round a pivot far below the screen, like a hand.
    readonly property real pivotX: width / 2
    readonly property real pivotY: height + 1650 * u
    readonly property real handR: pivotY - (height - 196 * u)
    readonly property real lift: 66 * u
    readonly property real frontScale: 1.22
    // Angles between the front card and its neighbours, and the rest.
    readonly property real step1: 204 * u / handR
    readonly property real stepN: 132 * u / handR
    // Top of the card in front, at rest.
    readonly property real frontTop: pivotY - handR - lift - cardH * frontScale / 2

    // ── Choreography, 0..1 ───────────────────────────────────────────────
    property real shown: 0
    // The cards being dealt (they rise from below, the middle first).
    property real deal: 0
    readonly property bool closing: closeAnim.running
    // Peeking: the deck steps aside for a clear view of the wallpaper.
    property bool peekHeld: false
    property bool peekKept: false
    property real peekPressedAt: 0
    property real peek: peekHeld || peekKept ? 1 : 0

    Behavior on peek {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    // ── Helpers ──────────────────────────────────────────────────────────
    // File name a Wallhaven result is saved under ("" for local entries).
    function savedName(entry) {
        return entry && entry.item ? Wallhaven.savePathFor(entry.item).split("/").pop() : "";
    }

    function isSaved(entry) {
        return !!entry && (!entry.item || localNames[savedName(entry)] === true);
    }

    function isActive(entry) {
        return !!entry && activeName === (entry.item ? savedName(entry) : entry.fileName);
    }

    function baseName(name) {
        const dot = name.lastIndexOf(".");
        return dot > 0 ? name.substring(0, dot) : name;
    }

    function bytes(n) {
        return n >= 1048576 ? (n / 1048576).toFixed(1) + " MB" : Math.max(1, Math.round(n / 1024)) + " KB";
    }

    function compact(n) {
        return n >= 1000 ? (n / 1000).toFixed(n >= 10000 ? 0 : 1) + "k" : String(n);
    }

    // The line under a card's name.
    function metaOf(entry) {
        if (!entry)
            return "";
        if (entry.item)
            return entry.resolution + "  ·  ♥ " + compact(entry.favorites) + (entry.fileSize ? "  ·  " + bytes(entry.fileSize) : "");
        const parts = [];
        const dot = entry.fileName.lastIndexOf(".");
        if (dot > 0)
            parts.push(entry.fileName.substring(dot + 1).toUpperCase());
        const e = WallpaperSwatches.entry(entry.fileName);
        if (e && e.w > 0)
            parts.push(e.w + " × " + e.h);
        if (entry.size > 0)
            parts.push(bytes(entry.size));
        return parts.join("  ·  ");
    }

    // The colours a card stands for: its scheme, or Wallhaven's for it.
    function schemeOf(entry) {
        return entry && !entry.item ? WallpaperSwatches.scheme(entry.fileName) : null;
    }

    // The picture a card and the preview show: a video's grabbed frame (once
    // the swatch worker has it), the file itself for anything else.
    function pictureOf(entry) {
        if (!entry)
            return "";
        if (!entry.video)
            return entry.fileUrl;
        const e = WallpaperSwatches.entry(entry.fileName);
        return e && e.f ? "file://" + e.f : "";
    }

    function swatchOf(entry) {
        if (!entry)
            return "";
        if (entry.item)
            return entry.colors && entry.colors.length > 0 ? String(WallpaperSwatches.dressFrom(entry.colors).accent) : "";
        return WallpaperSwatches.swatch(entry.fileName);
    }

    // ── The list ─────────────────────────────────────────────────────────
    function rebuildList() {
        const arr = [];
        for (let i = 0; i < folderModel.count; i++) {
            arr.push({
                fileName: folderModel.get(i, "fileName"),
                fileUrl: String(folderModel.get(i, "fileUrl")),
                modified: folderModel.get(i, "fileModified"),
                size: folderModel.get(i, "fileSize"),
                video: WallpaperEngine.kind(folderModel.get(i, "fileName")) === "video"
            });
        }
        allWallpapers = arr;
        resort();
        // Colours for the cards near the wallpaper on screen first.
        const at = Math.max(0, arr.findIndex(w => w.fileName === activeName));
        WallpaperSwatches.ensure(arr.map((w, i) => ({ w, d: Math.abs(i - at) })).sort((a, b) => a.d - b.d).map(x => x.w));
    }

    function resort() {
        const list = allWallpapers.map((w, i) => ({ w, i }));
        if (sort === "newest") {
            list.sort((a, b) => (b.w.modified - a.w.modified) || (a.i - b.i));
        } else if (sort === "colour") {
            const key = {};
            for (const x of list)
                key[x.w.fileName] = WallpaperSwatches.hueKey(x.w.fileName);
            list.sort((a, b) => (key[a.w.fileName] - key[b.w.fileName]) || (a.i - b.i));
        }
        sortedWallpapers = list.map(x => x.w);
    }

    function setSort(s) {
        if (s === sort)
            return;
        WallpaperSwatches.sort = s;
        reshuffle(resort);
    }

    function setMode(m) {
        if (m === mode)
            return;
        reshuffle(() => {
            modeChanging = true;
            mode = m;
            if (m === "wallhaven" && Wallhaven.onlineWallpapers.length === 0 && !Wallhaven.isFetchingOnline)
                Wallhaven.fetchWallhaven(true);
            Qt.callLater(refocus);
        });
    }

    // After the list changes: a new source (or a first list) starts on the
    // wallpaper on screen, or its first card; otherwise the card in front
    // stays in front wherever it went (or, gone, its place does).
    function refocus() {
        const list = displayedWallpapers;
        let i = -1;
        if (modeChanging || frontName === "") {
            modeChanging = false;
            i = online ? -1 : list.findIndex(w => w.fileName === activeName);
        } else {
            i = list.findIndex(w => w.fileName === frontName);
            if (i < 0)
                i = Math.min(currentIndex, list.length - 1);
        }
        if (i < 0)
            i = list.length > 0 ? 0 : -1;
        if (i !== currentIndex || Math.abs(pos - Math.max(0, i)) > 0.001)
            place(i);
        frontName = i >= 0 ? list[i].fileName : "";
    }

    // ── Moving through the deck ──────────────────────────────────────────
    // Straight to a card, no travel.
    function place(i) {
        posAnim.stop();
        currentIndex = i;
        pos = Math.max(0, i);
    }

    // To a card, the deck turning; a long way is cut short.
    function go(i) {
        if (count === 0)
            return;
        i = Math.max(0, Math.min(count - 1, i));
        currentIndex = i;
        posAnim.stop();
        if (Math.abs(i - pos) > side + 2)
            pos = i - Math.sign(i - pos) * 3;
        posAnim.to = i;
        posAnim.start();
    }

    function step(d) {
        go(currentIndex < 0 ? 0 : currentIndex + d);
    }

    function random() {
        if (count > 1)
            go((currentIndex + 1 + Math.floor(Math.random() * (count - 1))) % count);
    }

    // A new source or order: the hand is put away, `change` made out of
    // sight, and the new hand dealt.
    function reshuffle(change) {
        if (shuffleAnim.running && shuffleAnim.change) {
            const pending = shuffleAnim.change;
            shuffleAnim.change = null;
            pending();
        }
        if (!visible || closing || openAnim.running) {
            change();
            return;
        }
        shuffleAnim.change = change;
        shuffleAnim.restart();
    }

    // ── Acting on the card in front ──────────────────────────────────────
    // Sets it and stays open, so browsing can go on. A Wallhaven result is
    // downloaded first (once; a saved one is set from disk).
    function pickCurrent() {
        const e = currentEntry;
        if (!e || isActive(e))
            return;
        if (!e.item) {
            WallpaperEngine.set(e.fileUrl);
        } else if (isSaved(e)) {
            WallpaperEngine.set(Wallhaven.savePathFor(e.item));
        } else if (Wallhaven.downloadingWallpaperId === "") {
            lastDownload = e.fileName;
            Wallhaven.downloadAndSetWallpaper(e.item);
        }
    }

    function toggleFavorite(name) {
        if (name && !online)
            WallpaperFavorites.toggle(name);
    }

    function togglePeek() {
        peekKept = !peekKept;
    }

    function setSettingsOpen(on) {
        settingsOpen = on;
        if (on)
            settingsCard.reset();
        else
            keys.forceActiveFocus();
    }

    // ── Opening and closing ──────────────────────────────────────────────
    function open() {
        if (visible) {
            // Reopened while the close animation plays.
            closeAnim.stop();
            openAnim.restart();
        } else {
            visible = true;
        }
    }

    function close() {
        openAnim.stop();
        closeAnim.restart();
    }

    anchors.fill: parent
    visible: false
    focus: true

    Component.onDestruction: Wallhaven.resetSearch()

    onVisibleChanged: {
        if (!visible)
            return;
        peekKept = false;
        peekHeld = false;
        settingsOpen = false;
        place(displayedWallpapers.findIndex(w => w.fileName === activeName));
        if (currentIndex < 0 && count > 0)
            place(0);
        backdrop.show(currentEntry ? (currentEntry.fullUrl || pictureOf(currentEntry)) : "", true);
        keys.forceActiveFocus();
        closeAnim.stop();
        openAnim.restart();
    }
    // The card in front is whatever the deck moves to, never what a new
    // list happens to put at its index (read from the list: currentEntry
    // may not have caught up yet).
    onCurrentIndexChanged: {
        const e = displayedWallpapers[currentIndex];
        frontName = e ? e.fileName : "";
    }
    onDisplayedWallpapersChanged: Qt.callLater(refocus)
    onCurrentEntryChanged: {
        // The picture behind waits for the deck to slow down.
        backdropTimer.restart();
        // The next page of results as the end comes into view.
        if (online && currentIndex >= count - 8)
            Wallhaven.fetchNextPage();
        // Colours for the cards in hand first.
        if (!online && WallpaperSwatches.scanning) {
            const names = [];
            for (let d = 0; d <= side; d++) {
                for (const i of d === 0 ? [currentIndex] : [currentIndex - d, currentIndex + d]) {
                    const e = displayedWallpapers[i];
                    if (e && !WallpaperSwatches.entry(e.fileName))
                        names.push(e.fileName);
                }
            }
            WallpaperSwatches.prioritize(names);
        }
    }

    Connections {
        target: WallpaperSwatches

        // A video's frame, once it's grabbed.
        function onRevisionChanged() {
            if (window.currentEntry && window.currentEntry.video && backdrop.wanted !== window.pictureOf(window.currentEntry))
                backdropTimer.restart();
        }

        // The colour sort, once every colour is in.
        function onScanFinished() {
            if (window.sort === "colour")
                window.reshuffle(window.resort);
        }
    }

    // The deck turning.
    NumberAnimation {
        id: posAnim
        target: window
        property: "pos"
        duration: 380
        easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: shuffleAnim

        property var change: null

        NumberAnimation { target: window; property: "deal"; to: 0.1; duration: 170; easing.type: Easing.InQuad }
        ScriptAction {
            script: {
                const c = shuffleAnim.change;
                shuffleAnim.change = null;
                if (c)
                    c();
            }
        }
        NumberAnimation { target: window; property: "deal"; to: 1; duration: 560; easing.type: Easing.OutCubic }
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: window; property: "shown"; to: 1; duration: 380; easing.type: Easing.OutCubic }
        NumberAnimation { target: window; property: "deal"; to: 1; duration: 760; easing.type: Easing.OutCubic }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation { target: window; property: "shown"; to: 0; duration: 240; easing.type: Easing.InCubic }
        NumberAnimation { target: window; property: "deal"; to: 0; duration: 220; easing.type: Easing.InCubic }
        onFinished: window.visible = false
    }

    // Full resolution once the selection settles; a local picture as soon
    // as browsing slows down.
    Timer {
        id: backdropTimer
        interval: 110
        onTriggered: {
            const e = window.currentEntry;
            if (!e) {
                backdrop.show("");
            } else if (e.fullUrl) {
                backdrop.show(e.fileUrl);
                hiresTimer.restart();
            } else {
                backdrop.show(window.pictureOf(e));
            }
        }
    }

    Timer {
        id: hiresTimer
        interval: 550
        onTriggered: {
            if (window.currentEntry && window.currentEntry.fullUrl)
                backdrop.show(window.currentEntry.fullUrl, true);
        }
    }

    FolderListModel {
        id: folderModel
        folder: window.srcDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.mp4", "*.webm", "*.mkv", "*.mov", "*.m4v"]
        caseSensitive: false
        showDirs: false
        sortField: FolderListModel.Name
        onCountChanged: window.rebuildList()
    }

    // Measures a card (the deck's geometry needs its height).
    SwatchCard {
        id: gauge
        visible: false
        u: window.u
        title: "Wallpaper"
        meta: "JPG"
    }

    // ── The try-on: the picker wears the front card's colours ───────────
    Item {
        id: tint

        readonly property var dress: {
            const e = window.currentEntry;
            const s = window.schemeOf(e);
            if (s)
                return WallpaperSwatches.dressOf(s);
            if (e && e.item && e.colors && e.colors.length > 0)
                return WallpaperSwatches.dressFrom(e.colors);
            return null;
        }

        property color accent: dress ? dress.accent : Colors.primary
        property color accentInk: dress ? dress.accentInk : Colors.on_primary
        property color surface: dress ? dress.low : Colors.surface_container_low
        property color raised: dress ? dress.raised : Colors.surface_container_high
        property color ink: dress ? dress.ink : Colors.on_surface
        property color muted: dress ? dress.muted : Colors.on_surface_variant
        property color line: dress ? dress.line : Colors.outline_variant

        visible: false

        Behavior on accent { ColorAnimation { duration: 420; easing.type: Easing.OutCubic } }
        Behavior on accentInk { ColorAnimation { duration: 420; easing.type: Easing.OutCubic } }
        Behavior on surface { ColorAnimation { duration: 420; easing.type: Easing.OutCubic } }
        Behavior on raised { ColorAnimation { duration: 420; easing.type: Easing.OutCubic } }
        Behavior on ink { ColorAnimation { duration: 420; easing.type: Easing.OutCubic } }
        Behavior on muted { ColorAnimation { duration: 420; easing.type: Easing.OutCubic } }
        Behavior on line { ColorAnimation { duration: 420; easing.type: Easing.OutCubic } }
    }

    // ── The picture ──────────────────────────────────────────────────────
    // The desktop dimmed, until the picture is in.
    Rectangle {
        anchors.fill: parent
        color: Colors.scrim
        opacity: 0.55 * window.shown
    }

    WallpaperBackdrop {
        id: backdrop
        anchors.fill: parent
        opacity: window.shown
    }

    // Shade at the head and the foot, so the header and the deck read on
    // any picture; it lifts while peeking.
    Rectangle {
        anchors.fill: parent
        opacity: window.shown * (1 - 0.85 * window.peek)
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.66) }
            GradientStop { position: 0.13; color: Qt.rgba(0, 0, 0, 0.32) }
            GradientStop { position: 0.24; color: Qt.rgba(0, 0, 0, 0.06) }
            GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0) }
            GradientStop { position: 0.78; color: Qt.rgba(0, 0, 0, 0.18) }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.6) }
        }
    }

    // The wheel browses wherever it turns; a click on the picture peeks.
    MouseArea {
        property real acc: 0

        anchors.fill: parent
        onClicked: window.togglePeek()
        onWheel: wheel => {
            const d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : -wheel.angleDelta.x;
            if (Math.sign(d) !== Math.sign(acc))
                acc = 0;
            acc += d;
            while (acc >= 120) {
                window.step(-1);
                acc -= 120;
            }
            while (acc <= -120) {
                window.step(1);
                acc += 120;
            }
            wheelReset.restart();
        }

        Timer {
            id: wheelReset
            interval: 400
            onTriggered: parent.acc = 0
        }
    }

    // ── Keys ─────────────────────────────────────────────────────────────
    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            const k = event.key;
            if (k === Qt.Key_Escape) {
                if (window.settingsOpen)
                    window.setSettingsOpen(false);
                else if (window.peekKept)
                    window.peekKept = false;
                else
                    window.close();
            } else if (k === Qt.Key_Left || k === Qt.Key_Up) {
                window.step(-1);
            } else if (k === Qt.Key_Right || k === Qt.Key_Down) {
                window.step(1);
            } else if (k === Qt.Key_Home) {
                window.go(0);
            } else if (k === Qt.Key_End) {
                window.go(window.count - 1);
            } else if (k === Qt.Key_PageUp) {
                window.step(-window.side);
            } else if (k === Qt.Key_PageDown) {
                window.step(window.side);
            } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                window.pickCurrent();
            } else if (k === Qt.Key_Space) {
                if (!event.isAutoRepeat) {
                    window.peekHeld = true;
                    window.peekPressedAt = Date.now();
                }
            } else if (k === Qt.Key_F && !window.online) {
                window.toggleFavorite(window.currentName);
            } else if (k === Qt.Key_S && !window.online) {
                window.setSort(window.sorts[(window.sorts.indexOf(window.sort) + 1) % window.sorts.length]);
            } else if (k === Qt.Key_R) {
                window.random();
            } else if (k === Qt.Key_Tab || k === Qt.Key_Backtab) {
                window.setMode(window.modes[(window.modes.indexOf(window.mode) + (k === Qt.Key_Tab ? 1 : 2)) % 3]);
            } else if (k === Qt.Key_Slash && window.online) {
                search.forceActiveFocus();
            } else {
                return;
            }
            event.accepted = true;
        }

        Keys.onReleased: event => {
            if (event.key !== Qt.Key_Space || event.isAutoRepeat)
                return;
            window.peekHeld = false;
            // A tap keeps the peek (or ends a kept one).
            if (Date.now() - window.peekPressedAt < 240)
                window.peekKept = !window.peekKept;
            event.accepted = true;
        }
    }

    // ── The deck ─────────────────────────────────────────────────────────
    Item {
        id: deck
        anchors.fill: parent

        // Drag anywhere to turn the deck.
        DragHandler {
            id: drag

            property real from: 0

            target: null
            yAxis.enabled: false
            onActiveChanged: {
                if (active) {
                    posAnim.stop();
                    from = window.pos;
                } else {
                    // A flick carries on a little.
                    const v = centroid.velocity.x / (window.stepN * window.handR);
                    window.go(Math.round(window.pos - v * 0.2));
                }
            }
            onActiveTranslationChanged: {
                if (!active || window.count === 0)
                    return;
                window.pos = Math.max(-0.45, Math.min(window.count - 0.55, from - activeTranslation.x / (window.stepN * window.handR)));
                window.currentIndex = Math.max(0, Math.min(window.count - 1, Math.round(window.pos)));
            }
        }

        Repeater {
            model: window.slots

            Item {
                id: slot

                required property int index
                // The card this slot holds: the one nearest the deck's
                // position of those it can hold (every `slots`-th), so as
                // the deck turns each slot takes a new card out of sight.
                readonly property int idx: index + window.slots * Math.round((window.pos - index) / window.slots)
                readonly property real d: idx - window.pos
                readonly property real ad: Math.abs(d)
                readonly property bool live: idx >= 0 && idx < window.count && ad < window.side + 1
                readonly property var entry: live ? window.displayedWallpapers[idx] : null
                // 1 for the card in front.
                readonly property real near: Math.max(0, 1 - ad)
                readonly property real dealt: {
                    const t = Math.max(0, Math.min(1, window.deal * (1 + 0.09 * window.side) - 0.09 * ad));
                    return 1 - Math.pow(1 - t, 3);
                }
                readonly property real theta: (d < 0 ? -1 : 1) * (Math.min(ad, 1) * window.step1 + Math.max(0, ad - 1) * window.stepN)
                property real hoverLift: card.hovered && near < 0.5 ? 20 * window.u : 0
                readonly property real r: window.handR + window.lift * near + hoverLift
                // Below its place while dealt or peeking.
                readonly property real lower: (1 - dealt) * (window.cardH * 1.35 + 140 * window.u) + window.peek * (window.cardH * 1.25 + 120 * window.u)

                Behavior on hoverLift {
                    NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
                }

                width: window.cardW
                height: window.cardH
                x: window.pivotX + r * Math.sin(theta) - width / 2
                y: window.pivotY - r * Math.cos(theta) - height / 2 + lower
                rotation: (theta + (1 - dealt) * (d < 0 ? -0.1 : 0.1)) * 180 / Math.PI
                scale: 1 + (window.frontScale - 1) * near
                z: 100 - ad
                opacity: Math.max(0, Math.min(1, window.side + 1 - ad))
                visible: live && opacity > 0.01 && y < window.height

                SwatchCard {
                    id: card
                    anchors.fill: parent
                    u: window.u
                    entry: slot.entry
                    picture: window.pictureOf(slot.entry)
                    front: slot.near
                    dim: Math.min(0.3, Math.max(0, slot.ad - 0.6) * 0.065)
                    scheme: window.schemeOf(slot.entry)
                    imageColors: slot.entry && slot.entry.item ? slot.entry.colors : []
                    current: window.isActive(slot.entry)
                    favourite: !!slot.entry && !slot.entry.item && WallpaperFavorites.favorites.indexOf(slot.entry.fileName) >= 0
                    saved: !!slot.entry && !!slot.entry.item && window.isSaved(slot.entry)
                    download: !!slot.entry && !!slot.entry.item && Wallhaven.downloadingWallpaperId === slot.entry.fileName ? Wallhaven.downloadProgress : -1
                    title: !slot.entry ? "" : slot.entry.item ? "wallhaven " + slot.entry.fileName : window.baseName(slot.entry.fileName)
                    meta: window.metaOf(slot.entry)
                    onClicked: {
                        if (slot.idx === window.currentIndex)
                            window.pickCurrent();
                        else
                            window.go(slot.idx);
                    }
                    onDoubleClicked: {
                        window.go(slot.idx);
                        window.pickCurrent();
                    }
                }
            }
        }
    }

    // ── Above the card in front: what Enter does ─────────────────────────
    Row {
        id: actions

        readonly property var entry: window.currentEntry
        readonly property bool active: window.isActive(entry)
        readonly property bool mine: !!entry && !!entry.item && Wallhaven.downloadingWallpaperId === entry.fileName
        readonly property bool busy: Wallhaven.downloadingWallpaperId !== "" && !mine
        readonly property bool saved: window.isSaved(entry)
        readonly property bool failed: !!entry && !!entry.item && window.lastDownload === entry.fileName
            && Wallhaven.downloadError !== "" && Wallhaven.downloadingWallpaperId === ""
        readonly property bool fav: !!entry && !entry.item && WallpaperFavorites.favorites.indexOf(entry.fileName) >= 0

        anchors.horizontalCenter: parent.horizontalCenter
        y: window.frontTop - height - 20 * window.u + (1 - window.deal) * 60 * window.u + window.peek * 40 * window.u
        spacing: 8 * window.u
        // Faded out is gone too: no clicking a button you can't see.
        visible: window.count > 0 && !!entry && opacity > 0.05
        opacity: Math.max(0, window.deal * 1.6 - 0.6) * (1 - window.peek)

        ClickableRect {
            id: favButton
            visible: !window.online
            width: 40 * window.u
            height: 40 * window.u
            radius: height / 2
            color: favButton.hovered ? Colors.withAlpha(tint.surface, 0.95) : Colors.withAlpha(tint.surface, 0.78)
            border.width: 1
            border.color: Colors.withAlpha(tint.ink, 0.14)
            cursorShape: Qt.PointingHandCursor
            onClicked: window.toggleFavorite(window.currentName)

            Glyph {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 1
                text: "favorite"
                filled: actions.fav
                font.pixelSize: 20 * window.u
                color: actions.fav ? "#ff5c7a" : tint.ink
            }
        }

        ClickableRect {
            id: setButton

            readonly property bool idle: !actions.active && !actions.mine && !actions.busy

            width: setRow.implicitWidth + 32 * window.u
            height: 40 * window.u
            radius: height / 2
            clip: true
            color: actions.active ? Colors.withAlpha(tint.surface, 0.82)
                : actions.mine || actions.busy ? Colors.withAlpha(tint.accent, 0.35)
                : setButton.hovered ? Qt.lighter(tint.accent, 1.08) : tint.accent
            border.width: actions.active ? 1 : 0
            border.color: Colors.withAlpha(tint.ink, 0.14)
            cursorShape: idle ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: window.pickCurrent()

            // Download progress fills the button.
            Rectangle {
                visible: actions.mine
                width: parent.width * Wallhaven.downloadProgress
                height: parent.height
                color: tint.accent

                Behavior on width {
                    NumberAnimation { duration: 200 }
                }
            }

            Row {
                id: setRow
                anchors.centerIn: parent
                spacing: 8 * window.u

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: actions.active ? "check_circle" : actions.mine || actions.busy ? "downloading"
                        : actions.failed ? "refresh" : actions.saved ? "wallpaper" : "download"
                    filled: actions.active
                    font.pixelSize: 19 * window.u
                    color: actions.active ? tint.accent : tint.accentInk
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: actions.active ? "On your desktop"
                        : actions.mine ? "Downloading " + Math.round(Wallhaven.downloadProgress * 100) + "%"
                        : actions.busy ? "Another download running…"
                        : actions.failed ? "Download failed · retry"
                        : actions.saved ? "Set wallpaper" : "Download & set"
                    font.pixelSize: 14 * window.u
                    font.weight: Font.DemiBold
                    color: actions.active ? tint.ink : tint.accentInk
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: setButton.idle
                    width: enterKey.implicitWidth + 10 * window.u
                    height: 20 * window.u
                    radius: DesktopTheme.rad(6) * window.u
                    color: Colors.withAlpha(tint.accentInk, 0.14)

                    StyledText {
                        id: enterKey
                        anchors.centerIn: parent
                        text: "⏎"
                        font.pixelSize: 12 * window.u
                        font.weight: Font.Bold
                        color: tint.accentInk
                    }
                }
            }
        }
    }

    // ── The head: title, sources, order, the ribbon ──────────────────────
    component Glass: Rectangle {
        color: Colors.withAlpha(tint.surface, 0.8)
        border.width: 1
        border.color: Colors.withAlpha(tint.ink, 0.12)
        radius: DesktopTheme.rad(20) * window.u
    }

    // A row of choices in a glass pill.
    component Segments: Glass {
        id: segs

        property var options: []
        property string value
        signal picked(string key)

        width: segRow.implicitWidth + 8 * window.u
        height: 40 * window.u
        radius: DesktopTheme.rad(20) * window.u

        Row {
            id: segRow
            anchors.centerIn: parent
            spacing: 2 * window.u

            Repeater {
                model: segs.options

                ClickableRect {
                    id: seg

                    required property var modelData
                    readonly property bool current: segs.value === modelData.key

                    width: segLabel.implicitWidth + 28 * window.u
                    height: 32 * window.u
                    radius: DesktopTheme.rad(16) * window.u
                    color: current ? tint.accent : seg.hovered ? Colors.withAlpha(tint.ink, 0.08) : "transparent"
                    cursorShape: Qt.PointingHandCursor
                    onClicked: segs.picked(modelData.key)

                    Row {
                        id: segLabel
                        anchors.centerIn: parent
                        spacing: 6 * window.u

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !!seg.modelData.icon
                            text: seg.modelData.icon ?? ""
                            filled: seg.current
                            font.pixelSize: 17 * window.u
                            color: seg.current ? tint.accentInk : tint.muted
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: seg.modelData.label + (seg.modelData.key === "favorites" ? "  " + WallpaperFavorites.favorites.length : "")
                            font.pixelSize: 13 * window.u
                            font.weight: Font.DemiBold
                            color: seg.current ? tint.accentInk : tint.ink
                        }
                    }
                }
            }
        }
    }

    component RoundButton: ClickableRect {
        id: rb

        property string icon

        width: 40 * window.u
        height: 40 * window.u
        radius: height / 2
        color: rb.hovered ? Colors.withAlpha(tint.surface, 0.95) : Colors.withAlpha(tint.surface, 0.8)
        border.width: 1
        border.color: Colors.withAlpha(tint.ink, 0.12)
        cursorShape: Qt.PointingHandCursor

        Glyph {
            anchors.centerIn: parent
            text: rb.icon
            font.pixelSize: 19 * window.u
            color: tint.ink
        }
    }

    Item {
        id: head

        x: 40 * window.u
        y: 28 * window.u - (1 - window.shown) * 18 * window.u - window.peek * 24 * window.u
        width: parent.width - 80 * window.u
        height: 44 * window.u
        opacity: window.shown * (1 - window.peek)
        visible: opacity > 0.01

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12 * window.u

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: "style"
                filled: true
                font.pixelSize: 28 * window.u
                color: tint.accent
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    text: "Wallpapers"
                    font.pixelSize: 21 * window.u
                    font.weight: Font.Bold
                    color: "white"
                }

                StyledText {
                    text: window.count === 0 ? "" : (window.currentIndex + 1) + " of " + window.count + (window.online && Wallhaven.hasMorePages ? "+" : "")
                        + (window.online ? "  ·  wallhaven.cc" : window.sort === "colour" ? "  ·  by colour" : window.sort === "newest" ? "  ·  newest first" : "  ·  by name")
                    font.pixelSize: 12 * window.u
                    color: Colors.withAlpha("white", 0.72)
                }
            }
        }

        Segments {
            anchors.centerIn: parent
            options: [
                { key: "local", label: "Local", icon: "photo_library" },
                { key: "favorites", label: "Favourites", icon: "favorite" },
                { key: "wallhaven", label: "Wallhaven", icon: "travel_explore" }
            ]
            value: window.mode
            onPicked: key => window.setMode(key)
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * window.u

            // Reading colours (the first time, or new wallpapers).
            Glass {
                anchors.verticalCenter: parent.verticalCenter
                visible: !window.online && WallpaperSwatches.scanning
                width: readingRow.implicitWidth + 24 * window.u
                height: 40 * window.u

                Row {
                    id: readingRow
                    anchors.centerIn: parent
                    spacing: 8 * window.u

                    Spinner {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14 * window.u
                        arcColor: tint.accent
                        running: parent.parent.visible
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Reading colours  " + WallpaperSwatches.read + " / " + WallpaperSwatches.total
                        font.pixelSize: 12 * window.u
                        color: tint.muted
                    }
                }
            }

            Segments {
                anchors.verticalCenter: parent.verticalCenter
                visible: !window.online
                options: [
                    { key: "name", label: "Name", icon: "sort_by_alpha" },
                    { key: "colour", label: "Colour", icon: "palette" },
                    { key: "newest", label: "Newest", icon: "schedule" }
                ]
                value: window.sort
                onPicked: key => window.setSort(key)
            }

            StyledTextField {
                id: search
                anchors.verticalCenter: parent.verticalCenter
                visible: window.online
                width: 280 * window.u
                height: 40 * window.u
                radius: DesktopTheme.rad(20) * window.u
                backgroundColor: Colors.withAlpha(tint.surface, 0.8)
                borderColor: Colors.withAlpha(tint.ink, 0.12)
                focusBorderColor: tint.accent
                color: tint.ink
                placeholderTextColor: tint.muted
                placeholderText: "Search Wallhaven  ( / )"
                font.pixelSize: 13 * window.u
                leftPadding: 16 * window.u
                text: Wallhaven.currentSearchText
                onAccepted: {
                    Wallhaven.updateSearch(text);
                    keys.forceActiveFocus();
                }
                Keys.onEscapePressed: keys.forceActiveFocus()
            }

            RoundButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "settings"
                onClicked: window.setSettingsOpen(!window.settingsOpen)
            }

            RoundButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "visibility"
                onClicked: window.togglePeek()
            }

            RoundButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "close"
                onClicked: window.close()
            }
        }
    }

    SpectrumRibbon {
        id: ribbon

        // Its glimpse hangs over the hints and filters.
        z: 5
        x: head.x
        y: head.y + head.height + 18 * window.u
        width: head.width
        opacity: head.opacity
        visible: window.count > 0 && opacity > 0.01
        u: window.u
        pos: window.pos
        span: window.side
        accent: tint.accent
        ink: "white"
        colors: {
            WallpaperSwatches.revision;
            return window.displayedWallpapers.map(e => window.swatchOf(e));
        }
        favourites: {
            if (window.online || window.favoritesOnly)
                return [];
            const favs = WallpaperFavorites.favorites;
            const out = [];
            window.displayedWallpapers.forEach((e, i) => {
                if (favs.indexOf(e.fileName) >= 0)
                    out.push(i);
            });
            return out;
        }
        activeIndex: window.displayedWallpapers.findIndex(e => window.isActive(e))
        thumbs: window.displayedWallpapers.map(e => window.pictureOf(e))
        names: window.displayedWallpapers.map(e => e.item ? "wallhaven " + e.fileName : e.fileName)
        onScrub: index => {
            posAnim.stop();
            window.pos = index;
            window.currentIndex = Math.round(index);
        }
        onSettle: index => window.go(index)
    }

    // Under the ribbon: Wallhaven's filters, or the keys.
    Flow {
        id: filters

        x: head.x
        y: ribbon.y + ribbon.height + 14 * window.u
        width: head.width
        spacing: 8 * window.u
        visible: window.online && opacity > 0.01
        opacity: head.opacity

        component Chip: ClickableRect {
            id: chip

            property string label
            property bool active
            property bool danger: false

            width: chipText.implicitWidth + 22 * window.u
            height: 30 * window.u
            radius: DesktopTheme.rad(15) * window.u
            color: active ? (danger ? Colors.error : tint.accent) : chip.hovered ? Colors.withAlpha(tint.surface, 0.95) : Colors.withAlpha(tint.surface, 0.72)
            border.width: active ? 0 : 1
            border.color: Colors.withAlpha(tint.ink, 0.1)
            cursorShape: Qt.PointingHandCursor

            StyledText {
                id: chipText
                anchors.centerIn: parent
                text: chip.label
                font.pixelSize: 12 * window.u
                font.weight: Font.Medium
                color: chip.active ? (chip.danger ? Colors.on_error : tint.accentInk) : tint.ink
            }
        }

        component Gap: Item {
            width: 8 * window.u
            height: 30 * window.u
        }

        Repeater {
            model: [["Recent", "date_added"], ["Hot", "toplist"], ["Views", "views"], ["Favs", "favorites"], ["Random", "random"], ["Relevant", "relevance"]]

            Chip {
                required property var modelData
                label: modelData[0]
                active: SettingsConfig.wallhavenSorting === modelData[1]
                onClicked: SettingsConfig.wallhavenSorting = modelData[1]
            }
        }

        Repeater {
            model: SettingsConfig.wallhavenSorting === "toplist" ? ["1d", "3d", "1w", "1M", "3M", "6M", "1y"] : []

            Chip {
                required property string modelData
                label: modelData
                active: SettingsConfig.wallhavenTopRange === modelData
                onClicked: SettingsConfig.wallhavenTopRange = modelData
            }
        }

        Chip {
            label: SettingsConfig.wallhavenOrder === "desc" ? "↓" : "↑"
            onClicked: SettingsConfig.wallhavenOrder = SettingsConfig.wallhavenOrder === "desc" ? "asc" : "desc"
        }

        Gap {}

        Repeater {
            model: [["General", 0], ["Anime", 1], ["People", 2]]

            Chip {
                required property var modelData
                label: modelData[0]
                active: SettingsConfig.wallhavenCategories[modelData[1]] === "1"
                onClicked: {
                    const c = SettingsConfig.wallhavenCategories.split("");
                    c[modelData[1]] = c[modelData[1]] === "1" ? "0" : "1";
                    if (c.includes("1"))
                        SettingsConfig.wallhavenCategories = c.join("");
                }
            }
        }

        Gap {}

        Repeater {
            model: SettingsConfig.wallhavenApiKey.length > 0 ? [["SFW", 0], ["Sketchy", 1], ["NSFW", 2]] : [["SFW", 0], ["Sketchy", 1]]

            Chip {
                required property var modelData
                label: modelData[0]
                danger: modelData[1] === 2
                active: SettingsConfig.wallhavenPurity[modelData[1]] === "1"
                onClicked: {
                    const p = SettingsConfig.wallhavenPurity.split("");
                    p[modelData[1]] = p[modelData[1]] === "1" ? "0" : "1";
                    if (p.includes("1"))
                        SettingsConfig.wallhavenPurity = p.join("");
                }
            }
        }
    }

    Glass {
        anchors.horizontalCenter: parent.horizontalCenter
        y: ribbon.y + ribbon.height + 14 * window.u
        visible: !window.online && window.count > 0 && opacity > 0.01
        opacity: head.opacity
        width: hints.implicitWidth + 28 * window.u
        height: 28 * window.u
        color: Colors.withAlpha(tint.surface, 0.6)

        StyledText {
            id: hints
            anchors.centerIn: parent
            text: "←→ or wheel browse  ·  Enter set  ·  F favourite  ·  S sort  ·  R random  ·  Space peek  ·  Tab source  ·  Esc close"
            font.pixelSize: 12 * window.u
            color: Colors.withAlpha(tint.ink, 0.78)
        }
    }

    // ── Loading, empty, peeking ──────────────────────────────────────────
    // Full resolution on its way (Wallhaven), in the corner so the picture
    // stays in view.
    Glass {
        anchors.right: parent.right
        anchors.rightMargin: 40 * window.u
        y: (window.online ? filters.y + filters.height : ribbon.y + ribbon.height) + 16 * window.u
        visible: backdrop.loading && backdrop.upgrading && window.shown > 0.5
        width: hiresRow.implicitWidth + 24 * window.u
        height: 34 * window.u

        Row {
            id: hiresRow
            anchors.centerIn: parent
            spacing: 8 * window.u

            Spinner {
                anchors.verticalCenter: parent.verticalCenter
                width: 14 * window.u
                arcColor: tint.accent
                running: parent.parent.visible
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "Full resolution" + (backdrop.progress > 0.01 ? "  " + Math.round(backdrop.progress * 100) + "%" : "…")
                font.pixelSize: 12 * window.u
                color: tint.ink
            }
        }
    }

    Glass {
        anchors.right: parent.right
        anchors.rightMargin: 40 * window.u
        y: (window.online ? filters.y + filters.height : ribbon.y + ribbon.height) + 16 * window.u
        visible: backdrop.failed && window.shown > 0.5
        width: failedRow.implicitWidth + 24 * window.u
        height: 34 * window.u

        Row {
            id: failedRow
            anchors.centerIn: parent
            spacing: 8 * window.u

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: "broken_image"
                font.pixelSize: 16 * window.u
                color: tint.ink
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "Couldn't load this picture"
                font.pixelSize: 12 * window.u
                color: tint.ink
            }
        }
    }

    // Nothing to deal.
    Column {
        anchors.centerIn: parent
        visible: window.count === 0 && window.shown > 0
        opacity: window.shown
        spacing: 12 * window.u

        Spinner {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: window.online && Wallhaven.isFetchingOnline
            width: 40 * window.u
            arcColor: tint.accent
            running: visible
        }

        Glyph {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !(window.online && Wallhaven.isFetchingOnline)
            text: window.online ? (Wallhaven.onlineError ? "cloud_off" : "travel_explore") : window.favoritesOnly ? "heart_plus" : "hide_image"
            font.pixelSize: 52 * window.u
            color: "white"
            opacity: 0.85
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: window.online ? (Wallhaven.onlineError || (Wallhaven.isFetchingOnline ? "Searching Wallhaven…" : "No results"))
                : window.favoritesOnly ? "No favourites yet: press F on a wallpaper you like" : "No wallpapers in " + WallpaperEngine.tildeHome(WallpaperEngine.dir)
            font.pixelSize: 16 * window.u
            color: "white"
        }

        ClickableRect {
            id: folderButton
            anchors.horizontalCenter: parent.horizontalCenter
            visible: window.mode === "local" && !window.settingsOpen
            width: folderRow.implicitWidth + 32 * window.u
            height: 40 * window.u
            radius: height / 2
            color: folderButton.hovered ? Qt.lighter(tint.accent, 1.08) : tint.accent
            cursorShape: Qt.PointingHandCursor
            onClicked: window.setSettingsOpen(true)

            Row {
                id: folderRow
                anchors.centerIn: parent
                spacing: 8 * window.u

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "folder_open"
                    font.pixelSize: 18 * window.u
                    color: tint.accentInk
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Choose another folder"
                    font.pixelSize: 14 * window.u
                    font.weight: Font.DemiBold
                    color: tint.accentInk
                }
            }
        }
    }

    // The gear's settings, under the head on the right.
    PickerSettings {
        id: settingsCard

        anchors.right: parent.right
        anchors.rightMargin: 40 * window.u
        y: head.y + head.height + 12 * window.u
        z: 10
        visible: window.settingsOpen && head.visible
        opacity: head.opacity
        u: window.u
        surface: tint.surface
        ink: tint.ink
        muted: tint.muted
        accent: tint.accent
        accentInk: tint.accentInk
        wallpaperCount: window.allWallpapers.length
        onCloseRequested: window.setSettingsOpen(false)
    }

    // While peeking: how to get back.
    Glass {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 30 * window.u
        visible: opacity > 0.01
        opacity: window.peekKept ? window.peek : 0
        width: peekRow.implicitWidth + 28 * window.u
        height: 36 * window.u

        Row {
            id: peekRow
            anchors.centerIn: parent
            spacing: 10 * window.u

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: window.currentEntry ? (window.currentEntry.item ? "wallhaven " + window.currentName : window.currentName) : ""
                font.pixelSize: 13 * window.u
                font.weight: Font.DemiBold
                color: tint.ink
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "←→ browse  ·  Space or Esc: back to the deck"
                font.pixelSize: 12 * window.u
                color: tint.muted
            }
        }
    }
}
