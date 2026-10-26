pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// The colour scheme matugen makes from the wallpaper, set in the
// customizer's book: light or dark, the kind of scheme (tonal spot, content,
// vibrant…) and its contrast. scripts/wallpaper-apply reads the same file
// for every new wallpaper; a change here makes the scheme again from the
// wallpaper there is.
//
// `previews` holds what each kind of scheme would make of the wallpaper (a
// dry run of matugen for each, read when the book asks), for its plate.
//
// Settings: ~/.config/quickshell/palette.json.
Singleton {
    id: root

    readonly property var schemes: [
        { id: "scheme-tonal-spot", name: "Tonal spot", note: "Calm: one colour, gently toned (matugen's own)" },
        { id: "scheme-content", name: "Content", note: "True to the wallpaper's own colours" },
        { id: "scheme-fidelity", name: "Fidelity", note: "As close to the wallpaper as a scheme can be" },
        { id: "scheme-vibrant", name: "Vibrant", note: "Its colour turned up" },
        { id: "scheme-expressive", name: "Expressive", note: "Playful, the hues shifted" },
        { id: "scheme-fruit-salad", name: "Fruit salad", note: "A bold mix of hues" },
        { id: "scheme-rainbow", name: "Rainbow", note: "Colourful accents on calm surfaces" },
        { id: "scheme-neutral", name: "Neutral", note: "Barely tinted, nearly grey" },
        { id: "scheme-monochrome", name: "Monochrome", note: "Greys only" },
        { id: "scheme-smart", name: "Smart", note: "Matugen picks for the wallpaper" }
    ]

    readonly property alias mode: adapter.mode
    readonly property alias scheme: adapter.scheme
    readonly property real contrast: Math.max(-1, Math.min(1, adapter.contrast))
    // Set here at all (else wallpaper-apply runs matugen as it always did).
    readonly property bool custom: adapter.mode !== "dark" || adapter.scheme !== "scheme-tonal-spot" || Math.abs(adapter.contrast) > 0.001

    readonly property string still: Quickshell.env("HOME") + "/.cache/current_wallpaper"

    // { scheme id: { primary, secondary, tertiary, surface, … } } for the
    // wallpaper, mode and contrast it was read for.
    property var previews: ({})
    property string previewsFor: ""
    readonly property bool reading: reader.running

    function setMode(m) {
        if ((m === "dark" || m === "light") && adapter.mode !== m) {
            adapter.mode = m;
            root.previews = ({});
            applyTimer.restart();
        }
    }

    function setScheme(s) {
        if (root.schemes.some(x => x.id === s) && adapter.scheme !== s) {
            adapter.scheme = s;
            applyTimer.restart();
        }
    }

    function setContrast(c) {
        const v = Math.round(Math.max(-1, Math.min(1, c)) * 10) / 10;
        if (Math.abs(adapter.contrast - v) > 0.001) {
            adapter.contrast = v;
            root.previews = ({});
            applyTimer.restart();
        }
    }

    function reset() {
        adapter.mode = "dark";
        adapter.scheme = "scheme-tonal-spot";
        adapter.contrast = 0;
        root.previews = ({});
        applyTimer.restart();
    }

    // Makes the scheme again from the wallpaper there is.
    function apply() {
        Quickshell.execDetached(["sh", "-c", "command -v matugen >/dev/null && exec nice -n 19 matugen image \"$1\" --source-color-index 0 -m \"$2\" -t \"$3\" --contrast \"$4\"", "sh", root.still, adapter.mode, adapter.scheme, String(root.contrast)]);
    }

    // Reads what each kind of scheme would make (the plate's swatches).
    function readPreviews() {
        const key = adapter.mode + "|" + root.contrast;
        if (reader.running || root.previewsFor === key && Object.keys(root.previews).length > 0)
            return;
        reader.key = key;
        reader.exec(["sh", "-c", "command -v matugen >/dev/null || exit 0; printf '{'; s=; for t in " + root.schemes.map(x => x.id).join(" ")
            + "; do printf '%s\"%s\":' \"$s\" \"$t\"; s=,; nice -n 19 matugen image \"$1\" --source-color-index 0 --dry-run -j hex -q -t \"$t\" -m \"$2\" --contrast \"$3\" 2>/dev/null || printf '{}'; done; printf '}'",
            "sh", root.still, adapter.mode, String(root.contrast)]);
    }

    Timer {
        id: applyTimer
        interval: 700
        onTriggered: root.apply()
    }

    Process {
        id: reader

        property string key: ""

        stdout: StdioCollector {
            onStreamFinished: {
                let all = {};
                try {
                    all = JSON.parse(text);
                } catch (e) {
                    return;
                }
                const roles = ["primary", "secondary", "tertiary", "primary_container", "surface", "surface_container", "surface_container_high", "on_surface", "background"];
                const out = {};
                for (const id of Object.keys(all)) {
                    const c = all[id].colors;
                    if (!c)
                        continue;
                    const m = {};
                    for (const r of roles)
                        m[r] = c[r]?.default?.color ?? c[r]?.[adapter.mode]?.color ?? "#808080";
                    out[id] = m;
                }
                root.previews = out;
                root.previewsFor = reader.key;
            }
        }
    }

    // ── Settings file ────────────────────────────────────────────────────────
    FileView {
        id: settingsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/palette.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        adapter: JsonAdapter {
            id: adapter
            property string mode: "dark"
            property string scheme: "scheme-tonal-spot"
            property real contrast: 0
        }
    }
}
