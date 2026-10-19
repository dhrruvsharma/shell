import QtQuick

// What every power menu scene is built on (see PowerMenu). A scene draws
// the whole screen: the grabbed desktop (`menu.world`) turned into its
// setting by `menu.intro`, the five actions (`menu.actions`, lit by
// `menu.current`), and the ceremony of `menu.chosen` as `menu.rite` runs.
// Actions take the pointer with a PowerHit. The intro runs backwards on the
// way out, also after a quick action (lock, sleep) has had its short beat.
Item {
    id: scene

    required property var menu

    // How long its parts run, ms: the intro (the outro is the intro
    // backwards), the ceremony before logging out, restarting or shutting
    // down, and the beat a lock or sleep gets before the menu closes.
    property int introMs: 650
    property int outroMs: 340
    property int riteMs: 1800
    property int quickMs: 240
    // Whether it needs `menu.time` ticking.
    property bool ambient: false
    // The action lit as it opens (-1: none until pointed at).
    property int defaultCurrent: -1

    readonly property real sc: menu.sc
    readonly property real intro: menu.intro
    readonly property real rite: menu.rite
    readonly property int current: menu.current
    readonly property int chosen: menu.chosen
    readonly property var actions: menu.actions

    anchors.fill: parent

    // How far a part running from `a` to `b` of a 0..1 timeline `p` has
    // got, eased out (cubic) or straight.
    function seg(p, a, b) {
        const x = Math.max(0, Math.min(1, (p - a) / (b - a)));
        return 1 - Math.pow(1 - x, 3);
    }

    function lin(p, a, b) {
        return Math.max(0, Math.min(1, (p - a) / (b - a)));
    }

    // Eased in and out (smoothstep).
    function ease(p, a, b) {
        const x = lin(p, a, b);
        return x * x * (3 - 2 * x);
    }

    // The ceremony as seen by action `i`: 0 unless it is the chosen one.
    function riteOf(i) {
        return chosen === i ? rite : 0;
    }

    // How much the others step back while one is chosen.
    readonly property real aside: chosen >= 0 ? rite : 0

    function idOf(i) {
        return i >= 0 && i < actions.length ? actions[i].id : "";
    }

    // The chosen action's id, while there is one.
    readonly property string chosenId: idOf(chosen)
    readonly property bool quickChosen: chosen >= 0 && actions[chosen].quick

    // "4 h 12 min", "2 d 5 h", "38 min".
    function uptimeText(s) {
        const m = Math.floor(s / 60);
        const h = Math.floor(m / 60);
        const d = Math.floor(h / 24);
        return d > 0 ? d + " d " + h % 24 + " h" : h > 0 ? h + " h " + m % 60 + " min" : m + " min";
    }

    function cap(s) {
        return s.length > 0 ? s.charAt(0).toUpperCase() + s.slice(1) : s;
    }

    // `a` towards `b` by `t`.
    function mix(a, b, t) {
        return a + (b - a) * t;
    }
}
