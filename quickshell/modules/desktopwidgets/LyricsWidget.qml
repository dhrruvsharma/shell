pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import qs.colors
import qs.services as Services

// Desktop lyrics: the line being sung between the one before and the one
// after, in step with the song, straight on the wallpaper. No frame, only
// the desktop theme's type and a shadow to read it by. The lyrics are
// services/LyricsService's, so they follow Spotify.
//
// Only synced lyrics for the track that's playing are shown. With none
// (nothing playing, no synced lyrics for the song, still being fetched) it
// draws nothing and says it's `idle`, for its surface to take no input.
// Paused, the lines dim, and after half a minute they go.
//
// The box keeps one size, or every line would move the widget; the lines
// are set to the side of the screen it stands on (`place`).
Item {
    id: root

    property string themeId: Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""
    // In the Themes panel's miniatures: a sample stands in for lyrics there
    // are none of, so the widget can be arranged without a song.
    property bool preview: false
    // Where the widget's middle is across the screen, 0 (left) to 1 (right):
    // set by whatever holds it.
    property real place: 0.5

    readonly property var st: WidgetStyle.of(themeId)
    readonly property var service: Services.LyricsService
    readonly property var player: Services.Media.spotifyPlayer
    readonly property bool playing: player !== null && player.isPlaying
    // The service hears of a new track a moment after the player does, and
    // has the last one's lyrics till then.
    readonly property bool matched: player !== null && service.loaded && service.synced
        && service.trackid !== "" && service.trackid === Services.Media.spotifyTrackId()
    // Paused, the lines stay a while (`linger`): `awake` till then
    readonly property bool paused: player !== null && player.playbackState === MprisPlaybackState.Paused
    property bool awake: true
    readonly property bool live: matched && (playing || (paused && awake))

    // What to show: the service's lines, the sample, or nothing. `lines` is
    // what's drawn, made from `drawnFrom`; they change hands out of sight,
    // once the old ones have faded.
    readonly property var source: live ? service.lines : preview ? sample : null
    property var drawnFrom: null
    property var lines: []
    // The line being sung
    property int index: -1
    readonly property bool settled: drawnFrom === source
    readonly property bool idle: lines.length === 0

    readonly property var sample: [
        { startTimeMs: "0", words: "Lyrics follow the song here" },
        { startTimeMs: "1", words: "the line being sung, as it's sung" },
        { startTimeMs: "2", words: "and nothing at all without them" }
    ]

    // A line comes this long before it's sung: the time it takes to arrive
    readonly property int lead: 150
    readonly property int linger: 30000
    readonly property int textWidth: 620
    // Room for the shadow, which the surface's edge would cut
    readonly property int pad: 20
    readonly property int gap: 6
    // A row of the box: the face's own, or more where that is close-set,
    // for the scripts it borrows another face for
    readonly property real rowHeight: Math.max(metrics.height, metrics.lineSpacing, type.pixelSize * 1.35)
    readonly property color ink: Colors.on_surface
    // What the ink is read against: a shadow under the lines and a fine
    // edge round each letter, which is what tells on a bright wallpaper
    readonly property color shade: ink.hslLightness > 0.5 ? "black" : "white"
    // -1: the lines are set to the left, 0: centred, 1: to the right
    readonly property int side: place < 1 / 3 ? -1 : place > 2 / 3 ? 1 : 0
    // The theme's text face, at a size that reads alike in each (the old
    // styles are small on the body), slanted where the theme's own words are
    readonly property font type: face(["scroll", "lancet", "clipping", "brass", "patta", "banner"].includes(st.frame))
    // Scripts with no italic of their own would only be pushed over
    readonly property font upright: face(false)

    function face(italic) {
        const spec = {
            pixelSize: ({ chamfer: 22, console: 23, gilt: 27, lancet: 27, clipping: 27, scrap: 25, brass: 28, instrument: 23, patta: 26, banner: 25, sumi: 26 })[st.frame] ?? 24,
            weight: Math.max(st.weight, Font.Medium),
            italic: italic
        };
        // (An empty family isn't the default one: it loses whole scripts.)
        if (st.font)
            spec.family = st.font;
        return Qt.font(spec);
    }

    implicitWidth: textWidth + pad * 2
    // Three lines of two rows each
    implicitHeight: Math.ceil(rowHeight * 6) + gap * 2 + pad * 2

    FontMetrics {
        id: metrics
        font: root.type
    }

    // The service's lines as { at: ms, words }; a break in the singing is a
    // line without words, and so is the time before the first.
    function build(from) {
        const out = [];
        for (const l of from ?? []) {
            const at = parseInt(l.startTimeMs);
            if (isNaN(at))
                continue;
            const words = String(l.words ?? "").trim();
            out.push({ at: at, words: words === "♪" ? "" : words });
        }
        if (out.length > 0 && out[0].at > 0)
            out.unshift({ at: 0, words: "" });
        return out;
    }

    // Where the song is, in the lyrics' time
    function now() {
        return player ? player.position * 1000 + lead : 0;
    }

    // The last of `of` to have started by `ms`
    function lineAt(of, ms) {
        let lo = 0;
        let hi = of.length - 1;
        let at = -1;
        while (lo <= hi) {
            const mid = (lo + hi) >> 1;
            if (of[mid].at <= ms) {
                at = mid;
                lo = mid + 1;
            } else {
                hi = mid - 1;
            }
        }
        return at;
    }

    // Finds the line being sung and wakes for the next; it looks again
    // within a second whatever happens. (A seek shows at once when the
    // player announces it, as Spotify does: the shell only reckons the
    // position between a player's reports.) Lines on their way out stay as
    // they were.
    function sync() {
        tick.stop();
        if (idle || !settled || drawnFrom === sample || !player)
            return;
        const ms = now();
        index = lineAt(lines, ms);
        if (!playing)
            return;
        const next = index + 1 < lines.length ? lines[index + 1].at : Infinity;
        tick.interval = Math.max(16, Math.min(1000, (next - ms) / Math.max(0.1, player.rate || 1)));
        tick.start();
    }

    // Takes on the lines now wanted, while nothing shows.
    function settle() {
        if (settled || content.opacity > 0)
            return;
        const next = build(source);
        // The line first, for the rows to be made where they belong
        index = source === sample ? 1 : lineAt(next, now());
        lines = next;
        drawnFrom = source;
        sync();
    }

    onSourceChanged: Qt.callLater(root.settle)

    onPlayingChanged: {
        if (playing) {
            doze.stop();
            awake = true;
        } else {
            doze.restart();
        }
        sync();
    }

    Component.onCompleted: {
        if (!playing)
            doze.start();
        settle();
    }

    Timer {
        id: tick
        onTriggered: root.sync()
    }

    Timer {
        id: doze
        interval: root.linger
        onTriggered: root.awake = false
    }

    Connections {
        target: root.player

        function onPositionChanged() {
            root.sync();
        }
    }

    Item {
        id: content

        anchors.fill: parent
        opacity: !root.settled || root.idle ? 0 : root.playing || root.drawnFrom === root.sample ? 1 : 0.55
        visible: opacity > 0

        onOpacityChanged: {
            if (opacity === 0)
                Qt.callLater(root.settle);
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutCubic
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: root.shade
            shadowOpacity: 0.75
            shadowBlur: 0.45
            blurMax: 20
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 1
            autoPaddingEnabled: false
        }

        Column {
            id: column

            // Rows made or gone, for `sung` to be looked up again
            property int made: 0
            readonly property Item sung: made >= 0 && root.index >= 0 ? rows.itemAt(root.index) : null

            x: root.pad
            // The line being sung keeps to the middle of the box
            y: sung ? Math.round(root.height / 2 - sung.y - sung.height / 2) : root.pad
            width: root.textWidth
            spacing: root.gap

            // It glides from line to line; new lyrics fade in where they
            // belong
            Behavior on y {
                enabled: content.opacity === 1
                NumberAnimation {
                    duration: 420
                    easing.type: Easing.OutCubic
                }
            }

            Repeater {
                id: rows
                model: root.lines
                onItemAdded: column.made++
                onItemRemoved: column.made++

                // Only the rows by the line being sung are drawn; the rest
                // just keep their room.
                Item {
                    id: row

                    required property int index
                    required property var modelData
                    readonly property int off: index - root.index
                    // Latin, Greek and Cyrillic have italics
                    readonly property bool slants: !/[\u0530-\u1DFF\u2E80-\uFFFF]/.test(modelData.words)

                    width: column.width
                    height: label.implicitHeight

                    Text {
                        id: label

                        width: parent.width
                        text: row.modelData.words || "♪"
                        font: row.slants ? root.type : root.upright
                        color: root.ink
                        style: Text.Outline
                        styleColor: Qt.rgba(root.shade.r, root.shade.g, root.shade.b, 0.3)
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        horizontalAlignment: root.side < 0 ? Text.AlignLeft : root.side > 0 ? Text.AlignRight : Text.AlignHCenter
                        transformOrigin: root.side < 0 ? Item.Left : root.side > 0 ? Item.Right : Item.Center
                        opacity: row.off === 0 ? 1 : Math.abs(row.off) === 1 ? 0.55 : 0
                        scale: row.off === 0 ? 1 : 0.8
                        visible: opacity > 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 320
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 420
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }
    }
}
