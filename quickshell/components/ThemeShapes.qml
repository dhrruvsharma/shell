pragma Singleton
import QtQuick
import Quickshell

// Outlines for the desktop themes' cut shapes, as closed point lists for a
// PathPolyline (Shape): Art Deco's stepped corners, Cathedral's cusped
// (scooped) corners and its pointed arch, Siege's battlements, heater
// shield and swallowtailed banner. Every list ends where it starts.
// `x`/`y` offset the outline, so the inner line of a double border is the
// same outline inset.
Singleton {
    // Every corner stepped in `steps` times by `cut`, like a ziggurat.
    function deco(x, y, w, h, cut, steps) {
        const n = Math.max(1, steps);
        const c = Math.max(0, Math.min(cut, w / (2 * n + 1), h / (2 * n + 1)));
        const l = x, t = y, r = x + w, b = y + h;
        const pts = [];
        // Top left: up the left edge, then right and up the stairs.
        for (let i = n; i >= 1; i--) {
            pts.push(Qt.point(l + (n - i) * c, t + i * c));
            pts.push(Qt.point(l + (n - i + 1) * c, t + i * c));
        }
        pts.push(Qt.point(l + n * c, t));
        // Top right: down and right.
        pts.push(Qt.point(r - n * c, t));
        for (let i = 1; i <= n; i++) {
            pts.push(Qt.point(r - (n - i + 1) * c, t + i * c));
            pts.push(Qt.point(r - (n - i) * c, t + i * c));
        }
        // Bottom right: left and down.
        for (let i = n; i >= 1; i--) {
            pts.push(Qt.point(r - (n - i) * c, b - i * c));
            pts.push(Qt.point(r - (n - i + 1) * c, b - i * c));
        }
        pts.push(Qt.point(r - n * c, b));
        // Bottom left: up and left.
        pts.push(Qt.point(l + n * c, b));
        for (let i = 1; i <= n; i++) {
            pts.push(Qt.point(l + (n - i + 1) * c, b - i * c));
            pts.push(Qt.point(l + (n - i) * c, b - i * c));
        }
        pts.push(pts[0]);
        return pts;
    }

    // Every corner scooped out by a quarter circle of radius `r`.
    function cusp(x, y, w, h, r) {
        const c = Math.max(0, Math.min(r, w / 2, h / 2));
        const seg = Math.max(4, Math.round(c / 1.5));
        const l = x, t = y, rt = x + w, b = y + h;
        const pts = [];
        // A scoop centred on the corner (cx, cy), from angle a0 to a1
        // (radians, y down).
        const scoop = (cx, cy, a0, a1) => {
            for (let i = 0; i <= seg; i++) {
                const a = a0 + (a1 - a0) * i / seg;
                pts.push(Qt.point(cx + Math.cos(a) * c, cy + Math.sin(a) * c));
            }
        };
        scoop(l, t, Math.PI / 2, 0);
        scoop(rt, t, Math.PI, Math.PI / 2);
        scoop(rt, b, -Math.PI / 2, -Math.PI);
        scoop(l, b, 0, -Math.PI / 2);
        pts.push(pts[0]);
        return pts;
    }

    // A rectangle whose top is a pointed, four-centred (Tudor) arch rising
    // `rise` above its shoulders: each side turns in through a tight arc
    // (leaving the wall going straight up) and runs on straight to the apex,
    // where the two halves meet in a point.
    function arch(x, y, w, h, rise) {
        const half = w / 2;
        const k = Math.max(0.5, Math.min(rise, h * 0.6, w * 0.8));
        // The straight runs' slope, and the haunch radius that makes them
        // meet at the apex.
        const alpha = 0.55 * Math.atan2(k, half);
        const r1 = (k - half * Math.tan(alpha)) * Math.cos(alpha) / (1 - Math.sin(alpha));
        const seg = 14;
        const left = [];
        for (let i = 0; i <= seg; i++) {
            const phi = Math.PI - (Math.PI / 2 - alpha) * i / seg;
            left.push(Qt.point(x + r1 + r1 * Math.cos(phi), y + k - r1 * Math.sin(phi)));
        }
        const pts = [Qt.point(x, y + h)].concat(left);
        pts.push(Qt.point(x + half, y));
        for (let i = left.length - 1; i >= 0; i--)
            pts.push(Qt.point(2 * x + w - left[i].x, left[i].y));
        pts.push(Qt.point(x + w, y + h));
        pts.push(pts[0]);
        return pts;
    }

    // A wall's top: the top edge cut into battlements, merlons `depth` proud
    // of the crenels between them, a whole number of merlons about `merlon`
    // wide with one at each corner (a crenel is 0.65 of a merlon). `inset`
    // draws the same battlements that much inside the outline (so a frame's
    // line and a mask cut from the same box agree).
    function crenel(x, y, w, h, merlon, depth, inset) {
        const i = inset ?? 0;
        const d = Math.max(0, Math.min(depth, h / 3));
        const n = Math.max(2, Math.round((w / Math.max(2, merlon) + 0.65) / 1.65));
        const m = w / (n + 0.65 * (n - 1));
        const c = m * 0.65;
        const top = y + i, floor = y + d + i;
        const pts = [Qt.point(x + i, y + h - i), Qt.point(x + i, top)];
        for (let k = 0; k < n; k++) {
            const right = x + k * (m + c) + m;
            pts.push(Qt.point(k === n - 1 ? x + w - i : right - i, top));
            if (k === n - 1)
                break;
            pts.push(Qt.point(right - i, floor));
            pts.push(Qt.point(right + c + i, floor));
            pts.push(Qt.point(right + c + i, top));
        }
        pts.push(Qt.point(x + w - i, y + h - i));
        pts.push(pts[0]);
        return pts;
    }

    // A heater shield: a straight top, sides that run straight down a
    // little way and then curve in to a point, each curve an arc struck from
    // the opposite side (squashed when the shield is short for its width).
    function heater(x, y, w, h) {
        const y0 = Math.max(h * 0.12, h - 0.866 * w);
        const k = (h - y0) / (0.866 * w);
        const seg = 16;
        const pts = [Qt.point(x, y), Qt.point(x + w, y), Qt.point(x + w, y + y0)];
        for (let i = 1; i <= seg; i++) {
            const a = Math.PI / 3 * i / seg;
            pts.push(Qt.point(x + w * Math.cos(a), y + y0 + k * w * Math.sin(a)));
        }
        for (let i = seg - 1; i >= 0; i--) {
            const a = Math.PI / 3 * i / seg;
            pts.push(Qt.point(x + w - w * Math.cos(a), y + y0 + k * w * Math.sin(a)));
        }
        pts.push(pts[0]);
        return pts;
    }

    // A banner hanging from its top edge, its foot cut into `notches` V
    // notches `tail` deep (one notch: a swallowtail).
    function banner(x, y, w, h, tail, notches) {
        const n = Math.max(1, notches ?? 1);
        const pts = [Qt.point(x, y), Qt.point(x + w, y)];
        for (let i = 0; i <= 2 * n; i++)
            pts.push(Qt.point(x + w - i * w / (2 * n), y + h - (i % 2 === 1 ? tail : 0)));
        pts.push(pts[0]);
        return pts;
    }
}
