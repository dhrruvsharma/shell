import QtQuick

// The pet itself, drawn on a small canvas: a chibi cat (or fox, or bunny)
// in a sticker style, in one of a few poses, wearing the desktop theme's
// costume. It only repaints when something it shows changes, so a pet at
// rest costs nothing; BarPet drives `phase` (and everything else) while it
// moves.
//
// Drawn in a 64 x 56 box, facing right, standing on y = 54; `facing` -1
// mirrors it.
Canvas {
    id: fig

    // stand | walk | sit | sleep | groom | look | happy | dangle | eat
    property string pose: "stand"
    property int facing: 1
    // Walk cycle / hop / sway, in radians; advanced by the owner.
    property real phase: 0
    // 0..1: eyes shut (a blink, or asleep).
    property real blink: 0
    // Lift off the floor (px in design units) and squash (1 = none).
    property real lift: 0
    property real squash: 1
    // Swing while dangling, radians.
    property real swing: 0
    // Hearts (0..1 of their float), a "!" mark, sleep z's.
    property real hearts: 0
    property bool alert: false
    property string species: "cat"
    property var coat: ({ base: "#f4e4c6", belly: "#fff7e8", shade: "#dcc4a0", line: "#5a4633", inner: "#f5b3b3", eye: "#2b2230", nose: "#ea8a96" })
    // The desktop theme's costume ("" for just a collar) and its colours.
    property string costume: ""
    property color accent: "#8ab4f8"
    property color accent2: "#f2b8d8"

    implicitWidth: 64
    implicitHeight: 56
    renderStrategy: Canvas.Immediate
    antialiasing: true

    onPoseChanged: requestPaint()
    onFacingChanged: requestPaint()
    onPhaseChanged: requestPaint()
    onBlinkChanged: requestPaint()
    onLiftChanged: requestPaint()
    onSquashChanged: requestPaint()
    onSwingChanged: requestPaint()
    onHeartsChanged: requestPaint()
    onAlertChanged: requestPaint()
    onSpeciesChanged: requestPaint()
    onCoatChanged: requestPaint()
    onCostumeChanged: requestPaint()
    onAccentChanged: requestPaint()
    onAccent2Changed: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    // ── Geometry per pose ───────────────────────────────────────────────
    function layout() {
        const p = fig.pose;
        const ph = fig.phase;
        const g = {
            body: { cx: 27, cy: 41, rx: 15, ry: 9.5 },
            head: { cx: 42, cy: 26, r: 12.5, tilt: 0 },
            legs: [],
            haunch: null,
            tail: { x0: 13, y0: 38, c1x: 4, c1y: 35, c2x: 4, c2y: 22, x1: 9, y1: 17 },
            eyes: "open",
            mouth: "w",
            paw: null,
            zs: false,
            bob: 0,
            earDroop: 0
        };
        const leg = (x, top, len, far) => ({ x: x, top: top, len: len, far: far });
        if (p === "walk") {
            const a = Math.sin(ph), b = Math.sin(ph + Math.PI);
            const la = Math.max(0, -Math.cos(ph)) * 1.6, lb = Math.max(0, Math.cos(ph)) * 1.6;
            g.bob = Math.abs(Math.sin(ph)) * 0.9;
            g.legs = [leg(17 + b * 2.4, 43, 10 - lb, true), leg(33 + a * 2.4, 43, 10 - la, true),
                      leg(22 + a * 2.4, 43, 10 - la, false), leg(38 + b * 2.4, 43, 10 - lb, false)];
            g.tail.c2x += Math.sin(ph * 0.5) * 3;
            g.tail.x1 += Math.sin(ph * 0.5) * 3.5;
        } else if (p === "sit" || p === "groom" || p === "happy" || p === "eat") {
            g.body = { cx: 28, cy: 42, rx: 12.5, ry: 11 };
            g.head = { cx: 40, cy: p === "eat" ? 31 : 24, r: 12.5, tilt: p === "eat" ? 0.18 : 0 };
            g.haunch = { cx: 21, cy: 47, rx: 8.5, ry: 6.5 };
            g.legs = [leg(31, 42, 12, true), leg(36, 42, 12, false)];
            g.tail = { x0: 15, y0: 48, c1x: 10, c1y: 56, c2x: 34, c2y: 57, x1: 45, y1: 52 };
            if (p === "groom") {
                g.eyes = "shut";
                g.paw = { x: 44, y: 33 };
                g.mouth = "tongue";
                g.legs = [leg(31, 42, 12, true)];
            } else if (p === "happy") {
                g.eyes = "joy";
                g.mouth = "open";
            } else if (p === "eat") {
                g.eyes = "joy";
                g.mouth = "open";
            }
        } else if (p === "sleep") {
            g.body = { cx: 30, cy: 46, rx: 18, ry: 8.5 };
            g.head = { cx: 43, cy: 42, r: 11.5, tilt: 0.28 };
            g.tail = { x0: 13, y0: 48, c1x: 8, c1y: 57, c2x: 36, c2y: 57, x1: 48, y1: 52 };
            g.eyes = "shut";
            g.mouth = "w";
            g.zs = true;
            g.earDroop = 1;
        } else if (p === "look") {
            g.head = { cx: 42, cy: 24.5, r: 12.5, tilt: -0.12 };
            g.eyes = "wide";
            g.legs = [leg(17, 43, 10, true), leg(33, 43, 10, true), leg(22, 43, 10, false), leg(38, 43, 10, false)];
            g.tail.x1 = 6;
            g.tail.y1 = 13;
        } else if (p === "dangle") {
            g.body = { cx: 30, cy: 39, rx: 12, ry: 10.5 };
            g.head = { cx: 32, cy: 21, r: 12.5, tilt: 0 };
            g.legs = [leg(22, 43, 12, true), leg(38, 43, 12, true), leg(26, 44, 11, false), leg(34, 44, 11, false)];
            g.tail = { x0: 20, y0: 45, c1x: 16, c1y: 50, c2x: 20, c2y: 56, x1: 14, y1: 56 };
            g.eyes = "wide";
            g.mouth = "o";
        } else {
            g.legs = [leg(17, 43, 10, true), leg(33, 43, 10, true), leg(22, 43, 10, false), leg(38, 43, 10, false)];
            g.tail.c2x += Math.sin(ph) * 2;
            g.tail.x1 += Math.sin(ph) * 2.5;
        }
        return g;
    }

    // ── Drawing helpers ─────────────────────────────────────────────────
    function ink(ctx, fill, stroke, lw) {
        if (fill) {
            ctx.fillStyle = fill;
            ctx.fill();
        }
        if (stroke) {
            ctx.lineWidth = lw ?? 2;
            ctx.strokeStyle = stroke;
            ctx.stroke();
        }
    }

    function oval(ctx, cx, cy, rx, ry) {
        ctx.beginPath();
        ctx.ellipse(cx - rx, cy - ry, rx * 2, ry * 2);
    }

    function drawTail(ctx, g, c) {
        const t = g.tail;
        if (fig.species === "bunny") {
            oval(ctx, t.x0 + 1, t.y0 - 3, 4.4, 4.2);
            ink(ctx, c.belly, c.line, 1.9);
            return;
        }
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        const path = () => {
            ctx.beginPath();
            ctx.moveTo(t.x0, t.y0);
            ctx.bezierCurveTo(t.c1x, t.c1y, t.c2x, t.c2y, t.x1, t.y1);
        };
        const fox = fig.species === "fox";
        path();
        ctx.lineWidth = fox ? 10 : 6.4;
        ctx.strokeStyle = c.line;
        ctx.stroke();
        path();
        ctx.lineWidth = fox ? 7 : 3.6;
        ctx.strokeStyle = c.base;
        ctx.stroke();
        if (fox) {
            // A white tip.
            oval(ctx, t.x1, t.y1, 3.6, 3.6);
            ink(ctx, "#fbf6ee", null);
        }
    }

    function drawLeg(ctx, l, c) {
        ctx.beginPath();
        ctx.roundedRect(l.x - 2.6, l.top, 5.2, l.len, 2.5, 2.5);
        ink(ctx, l.far ? c.shade : c.base, c.line, 1.8);
    }

    function drawEars(ctx, h, c) {
        const r = h.r;
        const droop = fig.pose === "sleep" ? 1 : 0;
        if (fig.species === "bunny") {
            // In the air, the ears stream back.
            const flop = Math.min(1, fig.lift / 6);
            const ear = (x, lean) => {
                ctx.save();
                ctx.translate(h.cx + x, h.cy - r * 0.62);
                ctx.rotate(lean + droop * 0.9 * Math.sign(lean || 1) - flop * 1.05);
                oval(ctx, 0, -r * 0.72, r * 0.26, r * 0.78);
                ink(ctx, c.base, c.line, 1.9);
                oval(ctx, 0, -r * 0.66, r * 0.12, r * 0.56);
                ink(ctx, c.inner, null);
                ctx.restore();
            };
            ear(-r * 0.36, -0.18);
            ear(r * 0.3, 0.22);
            return;
        }
        const tall = fig.species === "fox" ? 1.32 : 1;
        const ear = (bx0, bx1, tipX, tipY) => {
            const by = h.cy - r * 0.55;
            const ty = h.cy - r * (1.02 * tall) + droop * r * 0.35;
            ctx.beginPath();
            ctx.moveTo(h.cx + bx0 * r, by);
            ctx.quadraticCurveTo(h.cx + tipX * r - 1, ty + 2, h.cx + tipX * r, ty);
            ctx.quadraticCurveTo(h.cx + tipX * r + 1, ty + 2, h.cx + bx1 * r, by + 1.5);
            ctx.closePath();
            ink(ctx, c.base, c.line, 1.9);
            // Inner ear.
            ctx.beginPath();
            ctx.moveTo(h.cx + (bx0 * 0.7 + tipX * 0.3) * r, by - 0.5);
            ctx.lineTo(h.cx + tipX * r, ty + 3.2 * tall);
            ctx.lineTo(h.cx + (bx1 * 0.7 + tipX * 0.3) * r, by + 0.8);
            ctx.closePath();
            ink(ctx, fig.species === "fox" ? c.line : c.inner, null);
        };
        ear(-0.92, -0.22, -0.76, 0);
        ear(0.2, 0.9, 0.68, 0);
    }

    function drawFace(ctx, g, c) {
        const h = g.head;
        const r = h.r;
        const ex0 = h.cx - r * 0.34, ex1 = h.cx + r * 0.38, ey = h.cy + r * 0.02;
        const eye = (x) => {
            const shut = Math.max(fig.blink, g.eyes === "shut" ? 1 : 0);
            ctx.lineCap = "round";
            if (g.eyes === "joy") {
                ctx.beginPath();
                ctx.moveTo(x - 2.3, ey + 0.8);
                ctx.quadraticCurveTo(x, ey - 2.4, x + 2.3, ey + 0.8);
                ink(ctx, null, c.eye, 1.7);
            } else if (g.eyes === "dizzy") {
                ctx.beginPath();
                ctx.moveTo(x - 2, ey - 2);
                ctx.lineTo(x + 2, ey + 2);
                ctx.moveTo(x + 2, ey - 2);
                ctx.lineTo(x - 2, ey + 2);
                ink(ctx, null, c.eye, 1.5);
            } else if (shut > 0.6) {
                ctx.beginPath();
                ctx.moveTo(x - 2.3, ey);
                ctx.quadraticCurveTo(x, ey + 2.2, x + 2.3, ey);
                ink(ctx, null, c.eye, 1.6);
            } else {
                const ry = (g.eyes === "wide" ? 3.5 : 3.0) * (1 - shut * 0.8);
                oval(ctx, x, ey, 2.35, ry);
                ink(ctx, c.eye, null);
                oval(ctx, x + 0.8, ey - ry * 0.4, 0.95, 0.95);
                ink(ctx, "#ffffff", null);
                oval(ctx, x - 0.8, ey + ry * 0.45, 0.45, 0.45);
                ink(ctx, "rgba(255,255,255,0.7)", null);
            }
        };
        eye(ex0);
        eye(ex1);
        // Blush.
        oval(ctx, h.cx - r * 0.62, h.cy + r * 0.34, 2.3, 1.3);
        ink(ctx, "rgba(240,120,140,0.42)", null);
        oval(ctx, h.cx + r * 0.72, h.cy + r * 0.34, 2.3, 1.3);
        ink(ctx, "rgba(240,120,140,0.42)", null);
        // Muzzle, nose and mouth.
        const nx = h.cx + r * 0.03, ny = h.cy + r * 0.3;
        if (fig.species === "fox") {
            oval(ctx, nx, ny + 1.6, 4.4, 3.2);
            ink(ctx, "#fbf6ee", null);
        }
        ctx.beginPath();
        ctx.moveTo(nx - 1.3, ny - 0.6);
        ctx.lineTo(nx + 1.3, ny - 0.6);
        ctx.lineTo(nx, ny + 0.8);
        ctx.closePath();
        ink(ctx, c.nose, null);
        ctx.lineCap = "round";
        if (g.mouth === "open") {
            ctx.beginPath();
            ctx.moveTo(nx - 2, ny + 1.6);
            ctx.quadraticCurveTo(nx, ny + 5, nx + 2, ny + 1.6);
            ctx.closePath();
            ink(ctx, "#a8404f", c.line, 1.1);
        } else if (g.mouth === "o") {
            oval(ctx, nx, ny + 2.8, 1.2, 1.5);
            ink(ctx, "#a8404f", c.line, 0.9);
        } else {
            ctx.beginPath();
            ctx.moveTo(nx - 2.2, ny + 1.4);
            ctx.quadraticCurveTo(nx - 1.1, ny + 2.9, nx, ny + 1.3);
            ctx.quadraticCurveTo(nx + 1.1, ny + 2.9, nx + 2.2, ny + 1.4);
            ink(ctx, null, c.line, 1.1);
            if (g.mouth === "tongue") {
                oval(ctx, nx + 0.4, ny + 3, 1, 1.2);
                ink(ctx, "#ee7f8f", null);
            }
        }
        // Whiskers (not on the bunny).
        if (fig.species !== "bunny") {
            ctx.lineWidth = 0.7;
            ctx.strokeStyle = fig.withAlpha(c.line, 0.55);
            ctx.beginPath();
            ctx.moveTo(h.cx + r * 0.95, ny);
            ctx.lineTo(h.cx + r * 1.32, ny - 1);
            ctx.moveTo(h.cx + r * 0.95, ny + 1.3);
            ctx.lineTo(h.cx + r * 1.3, ny + 1.9);
            ctx.stroke();
        }
    }

    function withAlpha(col, a) {
        const q = Qt.color(col);
        return Qt.rgba(q.r, q.g, q.b, a);
    }

    // Under the chin: a collar and bell in the theme's accent, or the
    // costume's own neckwear (Art Deco's bow tie, Wasteland's bandana,
    // Devaloka's garland of marigolds).
    // Drawn before the head, so only the part below the chin shows.
    function drawNeckwear(ctx, g, c) {
        if (fig.pose === "sleep")
            return;
        const h = g.head;
        const r = h.r;
        const acc = fig.accent;
        const cx = h.cx - r * 0.05, cy = h.cy + r * 0.93;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        if (fig.costume === "artdeco") {
            ctx.beginPath();
            ctx.moveTo(cx, cy + 1.5);
            ctx.lineTo(cx - 5, cy - 1.2);
            ctx.lineTo(cx - 5, cy + 4.2);
            ctx.closePath();
            ctx.moveTo(cx, cy + 1.5);
            ctx.lineTo(cx + 5, cy - 1.2);
            ctx.lineTo(cx + 5, cy + 4.2);
            ctx.closePath();
            ink(ctx, acc, "#2a2010", 1);
            oval(ctx, cx, cy + 1.5, 1.4, 1.4);
            ink(ctx, "#2a2010", null);
            return;
        }
        if (fig.costume === "devaloka") {
            // A garland of marigolds, orange and yellow by turns, hanging a
            // little lower in the middle.
            for (let i = 0; i < 7; i++) {
                const t = i / 6;
                const a = Math.PI * (0.2 + 0.6 * t);
                const fx = h.cx + Math.cos(a) * r * 1.1 * 1.04;
                const fy = h.cy + Math.sin(a) * r * 1.1 * 0.92 + Math.sin(t * Math.PI) * 1.8;
                oval(ctx, fx, fy, 2.3, 2.2);
                ink(ctx, i % 2 === 0 ? "#ff9a1f" : "#ffcf3a", "#a84f0c", 0.8);
                oval(ctx, fx, fy, 0.8, 0.8);
                ink(ctx, "#c2600e", null);
            }
            ctx.beginPath();
            ctx.moveTo(cx - 1.6, cy + 4.6);
            ctx.quadraticCurveTo(cx, cy + 8.8, cx + 1.6, cy + 4.6);
            ctx.closePath();
            ink(ctx, "#3f8f3a", "#245c22", 0.7);
            return;
        }
        if (fig.costume === "wasteland") {
            ctx.beginPath();
            ctx.moveTo(cx - r * 0.72, cy - 2.2);
            ctx.quadraticCurveTo(cx, cy + 1.2, cx + r * 0.72, cy - 2.2);
            ctx.lineTo(cx + 1, cy + 7);
            ctx.closePath();
            ink(ctx, "#a4432a", "#4a1e12", 1);
            oval(ctx, cx + 1, cy + 2.4, 0.8, 0.8);
            ink(ctx, "#e6d2b0", null);
            return;
        }
        // The collar: a band just outside the head's lower edge.
        ctx.save();
        ctx.translate(h.cx, h.cy);
        ctx.scale(1.06, 0.94);
        ctx.beginPath();
        ctx.arc(0, 0, r * 1.08, Math.PI * 0.26, Math.PI * 0.74);
        ctx.restore();
        ink(ctx, null, c.line, 4.4);
        ctx.save();
        ctx.translate(h.cx, h.cy);
        ctx.scale(1.06, 0.94);
        ctx.beginPath();
        ctx.arc(0, 0, r * 1.08, Math.PI * 0.27, Math.PI * 0.73);
        ctx.restore();
        ink(ctx, null, acc, 2.4);
        oval(ctx, h.cx + r * 0.1, h.cy + r * 1.17, 2, 2);
        ink(ctx, "#f2c14e", c.line, 1);
        ctx.beginPath();
        ctx.moveTo(h.cx + r * 0.1 - 1, h.cy + r * 1.24);
        ctx.lineTo(h.cx + r * 0.1 + 1, h.cy + r * 1.24);
        ink(ctx, null, c.line, 0.6);
    }

    // The desktop theme's costume, on the head.
    function drawCostume(ctx, g, c) {
        const h = g.head;
        const r = h.r;
        const acc = fig.accent;
        const cos = fig.costume;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        switch (cos) {
        case "hud": {
            // A gaming headset: band over the head, a cup and a boom mic.
            ctx.beginPath();
            ctx.arc(h.cx, h.cy, r + 1.4, Math.PI * 1.08, Math.PI * 1.92);
            ink(ctx, null, "#1d1f24", 3.2);
            ctx.beginPath();
            ctx.arc(h.cx, h.cy, r + 1.4, Math.PI * 1.1, Math.PI * 1.9);
            ink(ctx, null, acc, 1.4);
            ctx.beginPath();
            ctx.roundedRect(h.cx + r * 0.62, h.cy - 4.5, 5, 9, 2, 2);
            ink(ctx, "#1d1f24", acc, 1.2);
            ctx.beginPath();
            ctx.moveTo(h.cx + r * 0.8, h.cy + 4);
            ctx.quadraticCurveTo(h.cx + r * 0.95, h.cy + r * 0.75, h.cx + r * 0.35, h.cy + r * 0.72);
            ink(ctx, null, "#1d1f24", 1.3);
            oval(ctx, h.cx + r * 0.33, h.cy + r * 0.72, 1.2, 1.2);
            ink(ctx, acc, null);
            break;
        }
        case "terminal": {
            // Hacker shades with a phosphor glint.
            const y = h.cy + r * 0.02;
            ctx.beginPath();
            ctx.roundedRect(h.cx - r * 0.62, y - 2.8, r * 0.56, 5, 1.6, 1.6);
            ctx.roundedRect(h.cx + r * 0.12, y - 2.8, r * 0.56, 5, 1.6, 1.6);
            ink(ctx, "#101412", "#101412", 1);
            ctx.beginPath();
            ctx.moveTo(h.cx - r * 0.06, y - 1.2);
            ctx.lineTo(h.cx + r * 0.12, y - 1.2);
            ink(ctx, null, "#101412", 1.2);
            ctx.beginPath();
            ctx.moveTo(h.cx - r * 0.5, y - 1.4);
            ctx.lineTo(h.cx - r * 0.3, y - 1.4);
            ctx.moveTo(h.cx + r * 0.24, y - 1.4);
            ctx.lineTo(h.cx + r * 0.44, y - 1.4);
            ink(ctx, null, acc, 0.9);
            break;
        }
        case "cosmos": {
            // A glass space helmet.
            oval(ctx, h.cx, h.cy + 1, r + 4.6, r + 4.2);
            ink(ctx, "rgba(190,220,255,0.16)", withAlpha(acc, 0.85), 1.3);
            ctx.beginPath();
            ctx.arc(h.cx, h.cy + 1, r + 2.4, Math.PI * 1.15, Math.PI * 1.45);
            ink(ctx, null, "rgba(255,255,255,0.8)", 1.4);
            break;
        }
        case "zen": {
            // A sprout on the head.
            const bx = h.cx - 1, by = h.cy - r * 0.96;
            ctx.beginPath();
            ctx.moveTo(bx, by + 1);
            ctx.quadraticCurveTo(bx + 0.5, by - 3, bx - 0.2, by - 5);
            ink(ctx, null, "#4f7a3a", 1.1);
            ctx.beginPath();
            ctx.moveTo(bx - 0.2, by - 4.5);
            ctx.quadraticCurveTo(bx - 5, by - 7.5, bx - 6, by - 3.8);
            ctx.quadraticCurveTo(bx - 2.5, by - 2.8, bx - 0.2, by - 4.5);
            ink(ctx, "#8cc56b", "#4f7a3a", 0.9);
            ctx.beginPath();
            ctx.moveTo(bx - 0.1, by - 4.8);
            ctx.quadraticCurveTo(bx + 4.4, by - 8.4, bx + 5.6, by - 4.6);
            ctx.quadraticCurveTo(bx + 2.2, by - 3.4, bx - 0.1, by - 4.8);
            ink(ctx, "#a4d884", "#4f7a3a", 0.9);
            break;
        }
        case "xianxia": {
            // A topknot with a jade pin.
            oval(ctx, h.cx - 0.5, h.cy - r * 1.02, 3.6, 3.2);
            ink(ctx, "#23202a", "#23202a", 1);
            ctx.beginPath();
            ctx.moveTo(h.cx - 6, h.cy - r * 1.14);
            ctx.lineTo(h.cx + 5.5, h.cy - r * 0.94);
            ink(ctx, null, "#5fbf8f", 1.4);
            oval(ctx, h.cx + 5.8, h.cy - r * 0.93, 1.1, 1.1);
            ink(ctx, "#c6f0d8", null);
            break;
        }
        case "cyberpunk": {
            // A neon visor across the eyes.
            ctx.save();
            ctx.shadowColor = acc;
            ctx.shadowBlur = 4;
            ctx.beginPath();
            ctx.roundedRect(h.cx - r * 0.72, h.cy - 2.6, r * 1.5, 4.8, 2.2, 2.2);
            ink(ctx, withAlpha(acc, 0.85), "#0b0c12", 1);
            ctx.restore();
            ctx.beginPath();
            ctx.moveTo(h.cx - r * 0.55, h.cy - 1.2);
            ctx.lineTo(h.cx + r * 0.2, h.cy - 1.2);
            ink(ctx, null, "rgba(255,255,255,0.75)", 0.8);
            ctx.beginPath();
            ctx.moveTo(h.cx + r * 0.3, h.cy + 0.8);
            ctx.lineTo(h.cx + r * 0.62, h.cy + 0.8);
            ink(ctx, null, fig.accent2, 0.9);
            break;
        }
        case "wabisabi": {
            // A kasa: a wide straw hat.
            const y = h.cy - r * 0.62;
            ctx.beginPath();
            ctx.moveTo(h.cx - r * 1.42, y + 2.2);
            ctx.quadraticCurveTo(h.cx - r * 0.3, y - r * 0.75, h.cx + 0.5, y - r * 0.82);
            ctx.quadraticCurveTo(h.cx + r * 0.4, y - r * 0.75, h.cx + r * 1.48, y + 2.2);
            ctx.quadraticCurveTo(h.cx, y + 3.6, h.cx - r * 1.42, y + 2.2);
            ink(ctx, "#d8b877", "#6b5230", 1.1);
            ctx.beginPath();
            for (let i = -3; i <= 3; i++) {
                ctx.moveTo(h.cx + 0.5, y - r * 0.8);
                ctx.lineTo(h.cx + i * r * 0.42, y + 2.5);
            }
            ink(ctx, null, "rgba(107,82,48,0.45)", 0.6);
            break;
        }
        case "artdeco": {
            // A little top hat, worn at an angle (the bow tie is neckwear).
            ctx.save();
            ctx.translate(h.cx + 2.5, h.cy - r * 0.86);
            ctx.rotate(0.22);
            ctx.beginPath();
            ctx.roundedRect(-6.5, -1, 13, 2.4, 1, 1);
            ink(ctx, "#15120e", "#15120e", 0.8);
            ctx.beginPath();
            ctx.roundedRect(-4.2, -9, 8.4, 8.6, 0.8, 0.8);
            ink(ctx, "#15120e", "#15120e", 0.8);
            ctx.beginPath();
            ctx.rect(-4.2, -3.2, 8.4, 1.6);
            ink(ctx, acc, null);
            ctx.restore();
            break;
        }
        case "gothic": {
            // A golden halo.
            ctx.save();
            ctx.shadowColor = "#ffd978";
            ctx.shadowBlur = 3;
            oval(ctx, h.cx - 1, h.cy - r * 1.28, r * 0.62, r * 0.19);
            ink(ctx, null, "#f3c95a", 1.6);
            ctx.restore();
            break;
        }
        case "newspaper": {
            // A newsboy cap.
            ctx.save();
            ctx.translate(h.cx, h.cy - r * 0.58);
            ctx.beginPath();
            ctx.moveTo(-r * 0.98, 2.2);
            ctx.quadraticCurveTo(-r * 0.9, -r * 0.62, 0, -r * 0.66);
            ctx.quadraticCurveTo(r * 0.95, -r * 0.6, r * 1.02, 1.8);
            ctx.closePath();
            ink(ctx, "#5f5a52", "#26231f", 1);
            ctx.beginPath();
            ctx.moveTo(r * 0.35, 1.8);
            ctx.quadraticCurveTo(r * 1.1, 1.2, r * 1.42, 3.4);
            ctx.quadraticCurveTo(r * 0.9, 4.4, r * 0.3, 3.2);
            ctx.closePath();
            ink(ctx, "#4a463f", "#26231f", 0.9);
            oval(ctx, 0, -r * 0.62, 1.3, 0.9);
            ink(ctx, "#26231f", null);
            ctx.beginPath();
            ctx.moveTo(-r * 0.6, -r * 0.2);
            ctx.lineTo(r * 0.7, -r * 0.24);
            ink(ctx, null, "rgba(255,255,255,0.15)", 0.6);
            ctx.restore();
            break;
        }
        case "observatory": {
            // A stargazer's hat: a tall cone of night blue, a brass band and
            // two stars on it, worn at an angle.
            ctx.save();
            ctx.translate(h.cx + 1.5, h.cy - r * 0.84);
            ctx.rotate(0.16);
            ctx.beginPath();
            ctx.moveTo(-6.8, 0);
            ctx.quadraticCurveTo(-2.5, -8, 1.5, -16.5);
            ctx.quadraticCurveTo(2.5, -7, 6.8, 0);
            ctx.closePath();
            ink(ctx, "#1f2748", "#0e1224", 1);
            ctx.beginPath();
            ctx.roundedRect(-8.6, -1.2, 17.2, 2.8, 1.2, 1.2);
            ink(ctx, "#1f2748", "#0e1224", 0.9);
            ctx.beginPath();
            ctx.rect(-6, -3.4, 12, 1.7);
            ink(ctx, acc, null);
            const star = (x, y, s) => {
                ctx.beginPath();
                ctx.moveTo(x, y - s);
                ctx.lineTo(x + s * 0.3, y - s * 0.3);
                ctx.lineTo(x + s, y);
                ctx.lineTo(x + s * 0.3, y + s * 0.3);
                ctx.lineTo(x, y + s);
                ctx.lineTo(x - s * 0.3, y + s * 0.3);
                ctx.lineTo(x - s, y);
                ctx.lineTo(x - s * 0.3, y - s * 0.3);
                ctx.closePath();
                ink(ctx, "#ffd98a", null);
            };
            star(-1.2, -7.5, 1.9);
            star(1.6, -11.8, 1.3);
            ctx.restore();
            break;
        }
        case "abyss": {
            // A snorkel mask over the eyes, its strap round the head and the
            // snorkel up behind.
            const y = h.cy + r * 0.02;
            ctx.beginPath();
            ctx.moveTo(h.cx - r * 1.0, y - 1.4);
            ctx.quadraticCurveTo(h.cx, y - 3.2, h.cx + r * 1.0, y - 1.6);
            ink(ctx, null, "#17262d", 2);
            ctx.beginPath();
            ctx.moveTo(h.cx - r * 0.84, y + 2.5);
            ctx.lineTo(h.cx - r * 0.98, y - r * 0.9);
            ctx.quadraticCurveTo(h.cx - r * 1.0, y - r * 1.25, h.cx - r * 0.72, y - r * 1.28);
            ink(ctx, null, "#17262d", 3.2);
            ctx.beginPath();
            ctx.moveTo(h.cx - r * 0.84, y + 2.5);
            ctx.lineTo(h.cx - r * 0.98, y - r * 0.9);
            ctx.quadraticCurveTo(h.cx - r * 1.0, y - r * 1.25, h.cx - r * 0.72, y - r * 1.28);
            ink(ctx, null, fig.accent2, 1.6);
            ctx.beginPath();
            ctx.roundedRect(h.cx - r * 0.66, y - 3.6, r * 1.38, 6.6, 3, 3);
            ink(ctx, "rgba(140, 228, 236, 0.38)", "#17262d", 1.4);
            ctx.beginPath();
            ctx.moveTo(h.cx - r * 0.45, y - 1.8);
            ctx.lineTo(h.cx - r * 0.1, y - 1.8);
            ink(ctx, null, "rgba(255,255,255,0.8)", 0.9);
            break;
        }
        case "siege": {
            // A kettle hat: a steel dome with a broad brim, the ears poking
            // out under it, and a plume of the tincture streaming back from
            // its crown.
            const by = h.cy - r * 0.7;
            ctx.beginPath();
            ctx.moveTo(h.cx - r * 0.12, by - r * 0.58);
            ctx.quadraticCurveTo(h.cx - r * 0.7, by - r * 1.35, h.cx - r * 1.3, by - r * 0.95);
            ctx.quadraticCurveTo(h.cx - r * 0.8, by - r * 0.95, h.cx - r * 0.36, by - r * 0.42);
            ctx.closePath();
            ink(ctx, acc, "#2a1512", 0.9);
            ctx.beginPath();
            ctx.arc(h.cx, by, r * 0.6, Math.PI, 0);
            ctx.closePath();
            ink(ctx, "#b9bec5", "#34373c", 1.1);
            ctx.beginPath();
            ctx.arc(h.cx, by, r * 0.42, Math.PI * 1.15, Math.PI * 1.45);
            ink(ctx, null, "rgba(255,255,255,0.75)", 1);
            oval(ctx, h.cx, by + 0.4, r * 1.08, 2.3);
            ink(ctx, "#9aa0a8", "#34373c", 1.1);
            // A rivet on the crown.
            oval(ctx, h.cx, by - r * 0.6, 1.1, 1.1);
            ink(ctx, "#e3b24a", "#34373c", 0.6);
            break;
        }
        case "devaloka": {
            // A blessing: a tika of kumkum on the forehead, a grain of rice
            // on it.
            oval(ctx, h.cx + 0.3, h.cy - r * 0.5, 1.35, 2.1);
            ink(ctx, "#d8232a", "#8e1216", 0.6);
            oval(ctx, h.cx + 0.3, h.cy - r * 0.54, 0.45, 0.7);
            ink(ctx, "#fff4dc", null);
            break;
        }
        case "wasteland": {
            // Goggles pushed up on the forehead, and a bandana.
            const gy = h.cy - r * 0.52;
            ctx.beginPath();
            ctx.moveTo(h.cx - r * 0.98, gy + 1.5);
            ctx.quadraticCurveTo(h.cx, gy - 2.2, h.cx + r * 0.98, gy + 1.2);
            ink(ctx, null, "#3a2a1d", 2.2);
            oval(ctx, h.cx - r * 0.32, gy - 0.4, 3.3, 3.1);
            ink(ctx, "#6e8a8f", "#3a2a1d", 1.3);
            oval(ctx, h.cx + r * 0.36, gy - 0.6, 3.3, 3.1);
            ink(ctx, "#6e8a8f", "#3a2a1d", 1.3);
            oval(ctx, h.cx - r * 0.32 + 1, gy - 1.4, 0.9, 0.9);
            ink(ctx, "rgba(255,255,255,0.7)", null);
            oval(ctx, h.cx + r * 0.36 + 1, gy - 1.6, 0.9, 0.9);
            ink(ctx, "rgba(255,255,255,0.7)", null);
            break;
        }
        }
    }

    // Supper: a bowl, a fish tail sticking out of it.
    function drawBowl(ctx, c) {
        ctx.beginPath();
        ctx.moveTo(47, 49);
        ctx.lineTo(61, 49);
        ctx.quadraticCurveTo(60, 55, 54, 55);
        ctx.quadraticCurveTo(48, 55, 47, 49);
        ctx.closePath();
        ink(ctx, fig.accent, c.line, 1.3);
        ctx.beginPath();
        ctx.moveTo(52, 49);
        ctx.lineTo(55, 44.5);
        ctx.lineTo(57.5, 46);
        ctx.lineTo(55.5, 49);
        ctx.closePath();
        ink(ctx, "#8fb4d9", c.line, 1);
    }

    function drawEffects(ctx, g) {
        if (g.zs) {
            ctx.fillStyle = withAlpha(fig.coat.line, 0.75);
            ctx.font = "bold 7px sans-serif";
            ctx.fillText("z", 50, 30);
            ctx.font = "bold 9px sans-serif";
            ctx.fillText("z", 55, 22);
        }
        if (fig.hearts > 0 && fig.hearts < 1) {
            const k = fig.hearts;
            const heart = (x, y, s, a) => {
                ctx.save();
                ctx.translate(x, y);
                ctx.scale(s, s);
                ctx.beginPath();
                ctx.moveTo(0, 1.8);
                ctx.bezierCurveTo(-3.6, -0.6, -2.2, -3.8, 0, -1.8);
                ctx.bezierCurveTo(2.2, -3.8, 3.6, -0.6, 0, 1.8);
                ctx.fillStyle = Qt.rgba(0.96, 0.38, 0.52, a);
                ctx.fill();
                ctx.restore();
            };
            heart(50 + Math.sin(k * 7) * 2, 20 - k * 16, 1.1, 1 - k);
            heart(56 - Math.sin(k * 6) * 2, 26 - k * 20, 0.8, 1 - k * 0.8);
        }
        if (fig.alert) {
            ctx.fillStyle = "#f2c14e";
            ctx.strokeStyle = fig.coat.line;
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.roundedRect(52, 4, 4, 9, 2, 2);
            ctx.fill();
            ctx.stroke();
            oval(ctx, 54, 16, 2, 2);
            ink(ctx, "#f2c14e", fig.coat.line, 1);
        }
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const c = fig.coat;
        const g = fig.layout();
        const s = Math.min(width / 64, height / 56);
        ctx.save();
        ctx.translate((width - 64 * s) / 2, height - 56 * s);
        ctx.scale(s, s);
        if (fig.facing < 0) {
            ctx.translate(64, 0);
            ctx.scale(-1, 1);
        }
        // The whole body: lifted, squashed about the feet, swung.
        ctx.translate(32, 54);
        ctx.rotate(fig.swing);
        ctx.scale(1 + (1 - fig.squash) * 0.6, fig.squash);
        ctx.translate(-32, -54 - fig.lift - g.bob);

        fig.drawTail(ctx, g, c);
        for (const l of g.legs)
            if (l.far)
                fig.drawLeg(ctx, l, c);
        if (g.haunch) {
            fig.oval(ctx, g.haunch.cx, g.haunch.cy, g.haunch.rx, g.haunch.ry);
            fig.ink(ctx, c.shade, c.line, 1.9);
        }
        fig.oval(ctx, g.body.cx, g.body.cy, g.body.rx, g.body.ry);
        fig.ink(ctx, c.base, c.line, 2);
        // Belly.
        fig.oval(ctx, g.body.cx + g.body.rx * 0.18, g.body.cy + g.body.ry * 0.3, g.body.rx * 0.55, g.body.ry * 0.5);
        fig.ink(ctx, c.belly, null);
        for (const l of g.legs)
            if (!l.far)
                fig.drawLeg(ctx, l, c);
        // Head (ears first, so the head covers their bases).
        ctx.save();
        ctx.translate(g.head.cx, g.head.cy);
        ctx.rotate(g.head.tilt);
        ctx.translate(-g.head.cx, -g.head.cy);
        fig.drawEars(ctx, g.head, c);
        fig.drawNeckwear(ctx, g, c);
        fig.oval(ctx, g.head.cx, g.head.cy, g.head.r * 1.06, g.head.r * 0.94);
        fig.ink(ctx, c.base, c.line, 2);
        fig.drawFace(ctx, g, c);
        fig.drawCostume(ctx, g, c);
        ctx.restore();
        if (g.paw) {
            fig.oval(ctx, g.paw.x, g.paw.y, 3, 2.6);
            fig.ink(ctx, c.base, c.line, 1.6);
        }
        if (fig.pose === "eat")
            fig.drawBowl(ctx, c);
        ctx.restore();
        // Effects stay upright and unmirrored.
        ctx.save();
        ctx.translate((width - 64 * s) / 2, height - 56 * s);
        ctx.scale(s, s);
        fig.drawEffects(ctx, g);
        ctx.restore();
    }
}
