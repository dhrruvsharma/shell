pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

// The colour scheme each wallpaper would give the desktop, for the wallpaper
// picker (modules/wallpaper): its swatch cards wear these colours, the colour
// sort orders by them and the spectrum ribbon draws them.
//
// scripts/wallpaper-palettes.py runs matugen on each image as a dry run
// (nothing is applied), with WallpaperEngine's options, so a card shows the
// scheme its wallpaper will actually set. It only runs when the picker asks,
// niced, and each file is read once: results are cached in
// ~/.cache/quickshell/wallpaper-palettes.json by file name and mtime.
Singleton {
    id: root

    readonly property string dir: WallpaperEngine.dir

    // File name -> { m: mtime (s), s: bytes, w, h, c: { role: "#rrggbb" } };
    // `e` instead of `c` when matugen couldn't read the image.
    property var entries: ({})
    // Bumped whenever `entries` changes.
    property int revision: 0
    readonly property bool scanning: worker.running
    // Files in the running scan, and how many of them are read.
    property int total: 0
    property int read: 0

    // The picker's sort order ("name", "colour" or "newest"), kept for the
    // session so it reopens the way it was left.
    property string sort: "name"

    signal scanFinished

    property bool _loaded: false
    property var _files: null
    property bool _again: false
    property var _batch: ({})

    function entry(name) {
        return entries[name] ?? null;
    }

    // The scheme for a file name, or null until it's read.
    function scheme(name) {
        const e = entries[name];
        return e && e.c ? e.c : null;
    }

    // matugen's seed when an image has no colour to give (Google blue): a
    // grey wallpaper, not a blue one.
    readonly property string fallbackSeed: "#4285f4"

    // The colour a wallpaper stands for (its scheme's source colour; a grey
    // for a colourless one), or "" until it's read.
    function swatch(name) {
        const s = scheme(name);
        if (!s)
            return "";
        return s.source_color === fallbackSeed ? s.surface_container_highest : s.source_color;
    }

    // Where a wallpaper goes in the colour sort: round the hue wheel from
    // red, then the greys from dark to light, then the ones not read yet.
    function hueKey(name) {
        const s = scheme(name);
        if (!s)
            return 3;
        const c = Qt.color(s.source_color);
        if (s.source_color === fallbackSeed || c.hslSaturation < 0.12 || c.hslHue < 0)
            return 1 + Qt.color(s.surface_container_highest).hslLightness;
        return (c.hslHue + 0.035) % 1;
    }

    // A card's dress made up from an image's colours, when there's no scheme
    // (Wallhaven results): a dark surface in its main hue, and the most vivid
    // colour as the accent.
    function dressFrom(cols) {
        const vividness = q => q.hslSaturation * (1 - Math.abs(q.hslLightness - 0.5));
        const main = Qt.color(cols[0]);
        let vivid = main;
        for (const c of cols) {
            const q = Qt.color(c);
            if (vividness(q) > vividness(vivid))
                vivid = q;
        }
        const h = main.hslSaturation > 0.08 && main.hslHue >= 0 ? main.hslHue : Math.max(0, vivid.hslHue);
        const s = Math.min(0.32, main.hslSaturation);
        const va = vivid.hslHue >= 0 ? vivid.hslHue : h;
        return {
            surface: Qt.hsla(h, s, 0.13, 1),
            raised: Qt.hsla(h, s, 0.19, 1),
            low: Qt.hsla(h, s, 0.1, 1),
            ink: Qt.hsla(h, 0.16, 0.9, 1),
            muted: Qt.hsla(h, 0.12, 0.72, 1),
            line: Qt.hsla(h, Math.min(0.24, s + 0.06), 0.32, 1),
            accent: Qt.hsla(va, Math.min(0.72, vivid.hslSaturation + 0.18), 0.74, 1),
            accentInk: Qt.hsla(va, 0.5, 0.16, 1)
        };
    }

    // A scheme's dress, the same shape as dressFrom's.
    function dressOf(s) {
        return {
            surface: s.surface_container,
            raised: s.surface_container_high,
            low: s.surface_container_low,
            ink: s.on_surface,
            muted: s.on_surface_variant,
            line: s.outline_variant,
            accent: s.primary,
            accentInk: s.on_primary
        };
    }

    // Reads whatever isn't cached yet. `files`: every local wallpaper, as
    // [{ fileName, modified }] (`modified` a Date), the ones wanted first
    // first. Cache entries for files that are gone are dropped.
    function ensure(files) {
        _files = files;
        if (!_loaded)
            return;
        if (worker.running) {
            _again = true;
            return;
        }
        const keep = {};
        for (const f of files)
            keep[f.fileName] = true;
        const kept = {};
        let pruned = false;
        for (const k in entries) {
            if (keep[k])
                kept[k] = entries[k];
            else
                pruned = true;
        }
        if (pruned) {
            entries = kept;
            revision++;
            saveTimer.restart();
        }
        const missing = [];
        for (const f of files) {
            const e = entries[f.fileName];
            const m = f.modified ? Math.floor(f.modified.getTime() / 1000) : -1;
            if (!e || (m >= 0 && e.m !== m))
                missing.push(f.fileName);
        }
        if (missing.length === 0)
            return;
        total = missing.length;
        read = 0;
        worker.command = ["nice", "-n", "19", "python3", Quickshell.shellPath("scripts/wallpaper-palettes.py"), dir].concat(missing);
        worker.running = true;
    }

    // Moves these names (still waiting to be read) to the front of the queue.
    function prioritize(names) {
        if (worker.running && names.length > 0)
            worker.write(names.join("\t") + "\n");
    }

    function _flush() {
        const keys = Object.keys(_batch);
        if (keys.length === 0)
            return;
        const next = Object.assign({}, entries);
        for (const k of keys)
            next[k] = _batch[k];
        _batch = {};
        entries = next;
        revision++;
        saveTimer.restart();
    }

    Process {
        id: worker
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                try {
                    const r = JSON.parse(line);
                    const name = r.n;
                    delete r.n;
                    root._batch[name] = r;
                    root.read++;
                    flushTimer.start();
                } catch (e) {
                    console.warn("wallpaper swatches:", e);
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.warn("wallpaper swatches:", text.trim());
            }
        }
        onExited: {
            root._flush();
            root.scanFinished();
            if (root._again) {
                root._again = false;
                Qt.callLater(() => root.ensure(root._files));
            }
        }
    }

    // Results arrive a few a second; cards and the ribbon repaint per batch.
    Timer {
        id: flushTimer
        interval: 250
        onTriggered: root._flush()
    }

    Timer {
        id: saveTimer
        interval: 1500
        onTriggered: cache.setText(JSON.stringify({ version: 1, entries: root.entries }))
    }

    FileView {
        id: cache
        path: Quickshell.env("HOME") + "/.cache/quickshell/wallpaper-palettes.json"
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (d && d.version === 1 && d.entries)
                    root.entries = d.entries;
            } catch (e) {
                console.warn("wallpaper swatches: unreadable cache,", e);
            }
            root.revision++;
            root._loaded = true;
            if (root._files)
                root.ensure(root._files);
        }
        onLoadFailed: {
            root._loaded = true;
            if (root._files)
                root.ensure(root._files);
        }
    }
}
