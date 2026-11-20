// SPDX-License-Identifier: MIT
//
// The panorama shader's sums (shaders/panorama.frag), forwards and back,
// for what QML draws over it (labels) and for hit tests. The geometry is
// Panaroma Workspace Switcher's (MIT, (c) 2026 hawike22405, see the shader
// for the notice); keep both files in step.
//
// `p` holds the shader's uniforms: w, h (resolution), dist, zoom, kappa,
// scroll, pitch, cardW, cardH, count.
.pragma library

// The strip's point at strip coordinate `us` (px along it) and height `y`
// (px from its middle line) on screen: { x, y, z, scale } or null when it's
// behind the camera.
function project(p, us, y) {
    const D = Math.max(p.dist, 0.001);
    const f = Math.max(D * p.zoom, 0.001);
    const k = p.kappa;
    const s = us - p.scroll;
    let X, Z;
    if (k > 0.00001) {
        const R = 1 / k;
        const a = s * k;
        X = R * Math.sin(a);
        Z = (D - R) + R * Math.cos(a);
    } else {
        X = s;
        Z = D;
    }
    if (Z <= 1)
        return null;
    return { x: p.w / 2 + f * X / Z, y: p.h / 2 + f * y / Z, z: Z, scale: f / Z };
}

// The card under screen point (sx, sy): { idx (unwrapped), inside, lx, py }.
function hit(p, sx, sy) {
    const D = Math.max(p.dist, 0.001);
    const f = Math.max(D * p.zoom, 0.001);
    const k = p.kappa;
    const dx = (sx - p.w / 2) / f;
    const dy = (sy - p.h / 2) / f;
    const a = k * (1 + dx * dx);
    const b = 2 * (1 - k * D);
    const c = -D * (2 - k * D);
    const disc = Math.max(b * b - 4 * a * c, 0);
    const t = -2 * c / Math.max(b + Math.sqrt(disc), 0.000001);
    const Px = t * dx;
    const Py = t * dy;
    let s = Px;
    if (k > 0.00001)
        s = Math.atan2(k * Px, 1 + k * (t - D)) / k;
    const pitch = Math.max(p.pitch, 1);
    const us = s + p.scroll;
    const idx = Math.floor(us / pitch + 0.5);
    const lx = us - idx * pitch;
    const n = Math.max(1, Math.min(10, p.count));
    const rel = idx - p.scroll / pitch;
    const shown = Math.abs(rel) <= n * 0.5;
    const inside = shown && Math.abs(lx) <= p.cardW / 2 && Math.abs(Py) <= p.cardH / 2;
    return { idx: idx, inside: inside, lx: lx, py: Py };
}

// Ring slot of an unwrapped strip index.
function slotOf(idx, n) {
    const m = Math.max(1, n);
    return ((idx % m) + m) % m;
}

// The unwrapped index nearest `pos` that lands on ring slot `slot`.
function nearest(slot, pos, n) {
    const m = Math.max(1, n);
    return slot + m * Math.round((pos - slot) / m);
}

// Smoothstep, and a cubic from (p0, v0) to (p1, 0): v0 in units per `u`.
function smooth(a, b, x) {
    const t = Math.max(0, Math.min(1, (x - a) / (b - a)));
    return t * t * (3 - 2 * t);
}

function hermite(p0, v0, p1, u) {
    const t = Math.max(0, Math.min(1, u));
    const t2 = t * t, t3 = t2 * t;
    return p0 * (2 * t3 - 3 * t2 + 1) + v0 * (t3 - 2 * t2 + t) + p1 * (3 * t2 - 2 * t3);
}

function hermiteSlope(p0, v0, p1, u) {
    const t = Math.max(0, Math.min(1, u));
    const t2 = t * t;
    return p0 * (6 * t2 - 6 * t) + v0 * (3 * t2 - 4 * t + 1) + p1 * (6 * t - 6 * t2);
}
