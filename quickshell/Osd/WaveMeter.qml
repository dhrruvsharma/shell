pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.services as Services

// The volume OSD's meter: the level as a sound's waveform, read like a
// voice message's scrubber. Bars up to the level are lit, one accent
// fading into the other along it, the rest stay dim, and the louder it is
// the taller the lit bars stand. Every step sends a wavefront out of the
// speaker (`origin`, left of the meter) that bounces the bars as it rolls
// past; a held key keeps a train of them going. Past 100% (wpctl lets the
// keys run on) the far end runs hot. Muted, the sound goes flat and every
// bar drops to a dot.
Item {
    id: meter

    property real level: 0
    // How far past 100% the volume is (0.15 at 115%).
    property real boost: 0
    property bool muted: false
    property color lit: Services.DesktopTheme.accent
    property color lit2: Services.DesktopTheme.accent2
    property color unlit: Colors.outline_variant
    property color hot: Colors.error
    property bool squareCaps: false
    property real origin: -40

    readonly property real barWidth: 3.4
    readonly property real gap: 3.1
    readonly property int bars: Math.max(2, Math.floor((width + gap) / (barWidth + gap)))
    readonly property real pitch: (width - barWidth) / (bars - 1)
    readonly property real span: width + 36 - origin

    // 0 → a waveform, 1 → flat dots (muted)
    property real flat: muted ? 1 : 0

    Behavior on flat {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }

    // Three wavefronts in turn; x along the meter, from the origin.
    property real front0: -1000
    property real front1: -1000
    property real front2: -1000
    property int _last: -1

    function emit() {
        if (flat > 0.5)
            return;
        const anims = [anim0, anim1, anim2];
        const fronts = [front0, front1, front2];
        // Hold off until the last one has rolled a third of the way, so a
        // held key gives a train of fronts rather than a smear.
        if (_last >= 0 && anims[_last].running && fronts[_last] - origin < span * 0.32)
            return;
        let pick = anims.findIndex(a => !a.running);
        if (pick < 0)
            pick = fronts.indexOf(Math.max(...fronts));
        _last = pick;
        anims[pick].restart();
    }

    // Each parks off the meter when it's done (-1000: no front).
    NumberAnimation { id: anim0; target: meter; property: "front0"; from: meter.origin; to: meter.width + 36; duration: 560; easing.type: Easing.OutSine; onFinished: meter.front0 = -1000 }
    NumberAnimation { id: anim1; target: meter; property: "front1"; from: meter.origin; to: meter.width + 36; duration: 560; easing.type: Easing.OutSine; onFinished: meter.front1 = -1000 }
    NumberAnimation { id: anim2; target: meter; property: "front2"; from: meter.origin; to: meter.width + 36; duration: 560; easing.type: Easing.OutSine; onFinished: meter.front2 = -1000 }

    // A waveform that reads as a phrase of speech or music: peaks and
    // valleys, never silent. Sampled along the meter for any bar count.
    readonly property var shape: [0.42, 0.58, 0.74, 0.55, 0.88, 0.64, 0.46, 0.7, 0.95, 0.78, 0.52, 0.66, 0.84, 0.6, 0.4, 0.55,
        0.72, 1.0, 0.8, 0.58, 0.68, 0.5, 0.76, 0.9, 0.62, 0.45, 0.6, 0.82, 0.7, 0.5, 0.64, 0.48]

    function shapeAt(i) {
        const f = i / (bars - 1) * (shape.length - 1);
        const k = Math.min(shape.length - 2, Math.floor(f));
        return shape[k] + (shape[k + 1] - shape[k]) * (f - k);
    }

    function bumpAt(x) {
        let b = 0;
        for (const f of [front0, front1, front2]) {
            if (f < -999)
                continue;
            const fade = 1 - 0.6 * Math.max(0, Math.min(1, (f - origin) / span));
            const d = (x - f) / 13;
            b += fade * Math.exp(-d * d);
        }
        return Math.min(1.2, b);
    }

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }

    Repeater {
        model: meter.bars

        Rectangle {
            id: bar

            required property int index
            readonly property real t: index / (meter.bars - 1)
            readonly property real cx: index * meter.pitch + meter.barWidth / 2
            // How much of this bar the level lights (the leading one partly).
            readonly property real fill: Math.max(0, Math.min(1, meter.level * meter.bars - index))
            readonly property real loud: 0.46 + 0.54 * Math.min(1, meter.level)
            // Past 100% the lit bars are driven into the rails and clip.
            readonly property real drive: 1 + meter.boost * 3 * fill
            readonly property real wave: meter.shapeAt(index) * (0.4 + (loud - 0.4) * fill) * drive
            readonly property real bounce: meter.bumpAt(cx) * (0.24 + 0.3 * fill)
            readonly property real tall: Math.min(1, wave + bounce) * (1 - meter.flat)
            // The heat spreads in from the far end as the boost grows.
            readonly property real hotShare: Math.min(0.7, meter.boost * 1.8)
            readonly property real heat: meter.boost > 0 ? Math.max(0, Math.min(1, (t - (1 - hotShare)) / 0.12)) : 0

            x: index * meter.pitch
            width: meter.barWidth
            height: Math.max(meter.barWidth, tall * meter.height)
            y: (meter.height - height) / 2
            // Clipped bars square off against the rails.
            radius: meter.squareCaps || tall > 0.995 ? 0 : width / 2
            antialiasing: true
            color: meter.flat > 0.99 ? meter.unlit
                : Qt.tint(meter.unlit, Colors.withAlpha(meter.mix(meter.mix(meter.lit2, meter.lit, bar.t), meter.hot, bar.heat), bar.fill * (1 - meter.flat)))
        }
    }
}
