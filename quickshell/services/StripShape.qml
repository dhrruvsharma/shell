pragma Singleton
import QtQuick
import Quickshell
import qs.colors

// The bar as one strip (BarSettings.strip) and the panels that come out of
// it, as one surface: their shape, as the desktop theme has it, and where
// the panels join the strip.
//
// Shape: the strip's ends turn down into the screen's sides, and each panel
// leaves the strip's inner edge, through a fillet of the theme's kind: a
// curve ("arc"), a cut ("cut"), steps ("step") or none ("none": a square
// shoulder); `r` is its size. A panel's free corners are rounded, cut,
// stepped or square the same way (`corner`, size `c`). `trim` is what more
// the theme runs along the strip's inner edge: Broadsheet's rules,
// Observatory's graduation, Devaloka's temple border, Abyss's light,
// Wasteland's rivets, Siege's battlements, Sekiro's gauge tick.
//
// Joints: a panel hanging from the strip reports, while it's out, the
// stretch its body takes along the strip (`from`, `to`: screen px along the
// bar), how far it has come out past the strip's inner edge (`depth`), and
// whether it lies against the bar's start or far end (`start`, `end`: in a
// corner, joined to the screen's side there too). The strip
// (components/StripBand) draws the fillets either side of it and runs its
// outline down them; the panel (components/StripDrawer) draws its body from
// there, so the outline goes on round it unbroken, though the two are
// surfaces of their own.
//
// Paths are SVG path strings in "flat" coordinates: lying along the top of
// the screen, x along the bar, y away from the screen's edge. StripBand and
// StripDrawer turn them onto the bar's edge.
Singleton {
    id: root

    readonly property var look: DesktopTheme.look
    // Whether the bar is one strip on the screen now (not in minimal mode).
    readonly property bool active: BarSettings.strip && BarLayout.shown

    readonly property var styles: ({
            round: { fillet: "arc", r: 18, corner: "arc", c: 20, trim: "" },
            pill: { fillet: "arc", r: 22, corner: "arc", c: 26, trim: "" },
            soft: { fillet: "arc", r: 16, corner: "arc", c: 18, trim: "" },
            pebble: { fillet: "arc", r: 16, corner: "arc", c: 22, trim: "", uneven: true },
            seal: { fillet: "arc", r: 9, corner: "arc", c: 5, trim: "" },
            lume: { fillet: "arc", r: 12, corner: "arc", c: 12, trim: "lume" },
            zari: { fillet: "arc", r: 10, corner: "arc", c: 8, trim: "temple" },
            scale: { fillet: "arc", r: 9, corner: "arc", c: 9, trim: "ticks" },
            plate: { fillet: "arc", r: 6, corner: "arc", c: 3, trim: "rivets" },
            cusp: { fillet: "arc", r: 10, corner: "cut", c: 7, trim: "" },
            chamfer: { fillet: "cut", r: 12, corner: "cut", c: 10, trim: "" },
            neon: { fillet: "cut", r: 12, corner: "cut", c: 12, trim: "" },
            posture: { fillet: "cut", r: 14, corner: "cut", c: 8, trim: "gauge" },
            deco: { fillet: "step", r: 12, corner: "step", c: 9, trim: "" },
            square: { fillet: "none", r: 0, corner: "none", c: 0, trim: "" },
            print: { fillet: "none", r: 0, corner: "none", c: 0, trim: "rules" },
            crenel: { fillet: "none", r: 0, corner: "none", c: 0, trim: "merlons" }
        })
    readonly property var style: root.styles[root.look.shape] ?? root.styles.round

    // How far below the strip's inner edge it draws (its fillets, and
    // Siege's battlements): the bar's surface is that much deeper.
    readonly property int overhang: root.active ? Math.max(root.style.r, root.style.trim === "merlons" ? 5 : 0) : 0

    // The outline: the theme's hairline (HUD's faint one), else the bar's
    // outline when that's on, else none.
    readonly property color line: root.look.shape === "chamfer" ? Colors.withAlpha(Colors.on_surface, BarSettings.outline ? 0.3 : 0.16)
        : root.look.border ? DesktopTheme.borderColor(root.look)
        : BarSettings.outline ? BarSettings.outlineColor : "transparent"
    readonly property bool lined: Qt.color(root.line).a > 0

    // The strip's colour, and the panels': the same, though never so faint
    // that what's in a panel stops reading.
    readonly property color band: BarSettings.band
    readonly property color panel: Colors.withAlpha(BarSettings.fill, Math.max(BarSettings.fillOpacity, 0.86))

    // ── Joints ───────────────────────────────────────────────────────────────
    // [{ key, from, to, depth, start, end }], by `from`.
    property var joins: []

    // (Past the deepest fillet a panel's depth changes nothing here: it's
    // kept no deeper, so a panel unfolding further doesn't redraw the strip
    // every frame.)
    function join(key, from, to, depth, start, end) {
        const j = { key: key, from: Math.round(from), to: Math.round(to), depth: Math.max(0, Math.min(depth, 40)), start: !!start, end: !!end };
        const old = root.joins.find(x => x.key === key);
        if (old && old.from === j.from && old.to === j.to && Math.abs(old.depth - j.depth) < 0.01 && old.start === j.start && old.end === j.end)
            return;
        root.joins = root.joins.filter(x => x.key !== key).concat([j]).sort((a, b) => a.from - b.from);
    }

    function part(key) {
        if (root.joins.some(x => x.key === key))
            root.joins = root.joins.filter(x => x.key !== key);
    }

    // A joint's fillet, as big as the theme has it, or as deep as the panel
    // has come out while it's still coming.
    function filletOf(depth) {
        return Math.max(0, Math.min(root.style.r, depth));
    }

    // How near the bar's ends a panel may come out of the strip and keep a
    // stretch of it either side of the fillets; nearer, it goes into the
    // corner (CalendarWindow).
    readonly property real cornerRoom: 2 * root.style.r + 24

    // ── Paths ────────────────────────────────────────────────────────────────

    function _n(v) {
        return (Math.round(v * 100) / 100).toString();
    }

    // A turn from P round the corner K to Q (the current point is P), as
    // `kind` has it; an arc's centre is P + Q - K, so the one function does
    // a panel's rounded corners and the fillets that turn the other way.
    function turn(kind, P, K, Q) {
        const size = Math.hypot(P.x - K.x, P.y - K.y);
        if (size < 0.01 || kind === "none")
            return " L " + root._n(Q.x) + " " + root._n(Q.y);
        if (kind === "arc") {
            const C = { x: P.x + Q.x - K.x, y: P.y + Q.y - K.y };
            const cross = (P.x - C.x) * (Q.y - C.y) - (P.y - C.y) * (Q.x - C.x);
            return " A " + root._n(size) + " " + root._n(size) + " 0 0 " + (cross > 0 ? 1 : 0) + " " + root._n(Q.x) + " " + root._n(Q.y);
        }
        if (kind === "step") {
            // Two steps in towards the corner.
            const n = 2;
            const a = { x: (P.x - K.x) / n, y: (P.y - K.y) / n };
            const b = { x: (Q.x - K.x) / n, y: (Q.y - K.y) / n };
            let s = "", x = P.x, y = P.y;
            for (let i = 0; i < n; i++) {
                x += b.x;
                y += b.y;
                s += " L " + root._n(x) + " " + root._n(y);
                x -= a.x;
                y -= a.y;
                s += " L " + root._n(x) + " " + root._n(y);
            }
            return s;
        }
        return " L " + root._n(Q.x) + " " + root._n(Q.y);
    }

    // A run of straight edges (each along x or y) through `pts`, turning
    // at each point between the ends as its `kind` and `size` say. With
    // `d`, the run is moved that far towards its filled side, which lies
    // to the left of the way it runs (a hairline `d` = half its width in
    // from the edge stays sharp); the turns grow or shrink to keep their
    // centres.
    function trace(pts, d) {
        const dir = (p, q) => {
            const dx = q.x - p.x, dy = q.y - p.y, l = Math.hypot(dx, dy) || 1;
            return { x: dx / l, y: dy / l };
        };
        const left = u => ({ x: u.y, y: -u.x });
        let s = "";
        for (let i = 0; i < pts.length; i++) {
            const p = pts[i];
            const uin = i > 0 ? dir(pts[i - 1], p) : null;
            const uout = i < pts.length - 1 ? dir(p, pts[i + 1]) : null;
            const nin = uin ? left(uin) : { x: 0, y: 0 };
            const nout = uout ? left(uout) : { x: 0, y: 0 };
            const o = { x: p.x + d * (nin.x + nout.x), y: p.y + d * (nin.y + nout.y) };
            if (i === 0) {
                s += "M " + root._n(o.x) + " " + root._n(o.y);
                continue;
            }
            if (i === pts.length - 1 || !(p.size > 0) || p.kind === "none") {
                s += " L " + root._n(o.x) + " " + root._n(o.y);
                continue;
            }
            // Turning right, the filled side is outside the turn (a fillet):
            // moved in, it grows; turning left (a corner), it shrinks.
            const right = uin.x * uout.y - uin.y * uout.x > 0;
            const k = p.kind === "cut" ? 0.586 : 1;
            const size = Math.max(0, p.size + (right ? 1 : -1) * d * k);
            const P = { x: o.x - uin.x * size, y: o.y - uin.y * size };
            const Q = { x: o.x + uout.x * size, y: o.y + uout.y * size };
            s += " L " + root._n(P.x) + " " + root._n(P.y) + root.turn(p.kind, P, o, Q);
        }
        return s;
    }
}
