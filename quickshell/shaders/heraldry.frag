#version 440
// A heater shield painted with arms (modules/lock/themes/siege/Arms.qml):
// the field, one ordinary (a chevron, bend, fess, pale, cross, saltire or
// chief) and its charges (mullets, roundels, crescents, annulets or
// lozenges), laid out as a herald would: "between three" two in chief and
// one in base, "between four" in the quarters, "on a chief" three in a row,
// or `lone`: one large charge alone on the field. Painted on a board curved
// like the real thing, lit from the upper left, with a steel rim round it
// and the knocks of use (`worn`: scratches through the paint, nicks in the
// rim). The shield fills the item: its width is the item's, its point at
// the item's foot.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float ordinary;    // 0 none, 1 chevron, 2 bend, 3 fess, 4 pale, 5 cross, 6 saltire, 7 chief
    float charge;      // 0 none, 1 mullet, 2 roundel, 3 crescent, 4 annulet, 5 lozenge
    float lone;        // 1: a single large charge (with no ordinary)
    float rim;         // rim width, px (0: none)
    float worn;        // 0..1
    float glow;        // 0..1, a gilt light over the whole
    float seed;        // varies the wear
    vec4 fieldColor;
    vec4 metalColor;   // the ordinary
    vec4 chargeColor;
    vec4 rimColor;
    vec4 glowColor;
} ubuf;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// The heater's outline, in shield units: x across -0.5..0.5, y down from
// the top edge to its point at `hs`. The lower sides are arcs of radius 1
// struck from the opposite side (squashed when the shield is short).
float heater(vec2 p, float hs) {
    float y0 = max(0.12 * hs, hs - 0.866);
    float k = (hs - y0) / 0.866;
    vec2 q = vec2(p.x, y0 + (p.y - y0) / k);
    float lens = max(length(q - vec2(0.5, y0)), length(q - vec2(-0.5, y0))) - 1.0;
    lens *= min(k, 1.0);
    float body = max(abs(p.x) - 0.5, -p.y);
    return max(body, min(p.y - y0, lens));
}

// Distance to the line through `a` along `dir` (normalised).
float band(vec2 p, vec2 a, vec2 dir) {
    vec2 d = p - a;
    return abs(d.x * dir.y - d.y * dir.x);
}

// iq's five-pointed star.
float star5(vec2 p, float r, float rf) {
    const vec2 k1 = vec2(0.809016994375, -0.587785252292);
    const vec2 k2 = vec2(-k1.x, k1.y);
    p.x = abs(p.x);
    p -= 2.0 * max(dot(k1, p), 0.0) * k1;
    p -= 2.0 * max(dot(k2, p), 0.0) * k2;
    p.x = abs(p.x);
    p.y -= r;
    vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
    float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
    return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

// One charge centred on `c`, `r` its size; y runs down.
float chargeAt(vec2 p, vec2 c, float r, int kind) {
    vec2 q = p - c;
    if (kind == 1)
        return star5(vec2(q.x, -q.y), r, 0.42);
    if (kind == 2)
        return length(q) - r * 0.82;
    if (kind == 3) {
        // Horns up.
        float outer = length(q) - r * 0.86;
        float inner = length(q - vec2(0.0, -r * 0.34)) - r * 0.68;
        return max(outer, -inner);
    }
    if (kind == 4)
        return abs(length(q) - r * 0.64) - r * 0.2;
    if (kind == 5) {
        vec2 a = abs(q) / vec2(0.62 * r, r);
        return (a.x + a.y - 1.0) * 0.6 * r;
    }
    return 1.0;
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    float w = res.x;
    float hs = res.y / w;
    vec2 p = vec2(qt_TexCoord0.x - 0.5, qt_TexCoord0.y * hs);
    float px = 1.0 / w;
    int ord = int(ubuf.ordinary + 0.5);
    int kind = int(ubuf.charge + 0.5);

    // Nicks out of the edge where blows landed.
    float d = heater(p, hs);
    float wear = clamp(ubuf.worn, 0.0, 1.0);
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        vec2 nick = vec2(hash(vec2(fi, ubuf.seed)) - 0.5, hash(vec2(ubuf.seed, fi + 3.0)) * hs * 0.8);
        // Put it on the edge: the nearest side, or the top.
        nick.x = (nick.x < 0.0 ? -0.5 : 0.5);
        if (i == 3)
            nick = vec2(hash(vec2(fi, ubuf.seed + 7.0)) * 0.8 - 0.4, 0.0);
        float rn = (0.012 + 0.02 * hash(vec2(fi + 9.0, ubuf.seed))) * wear;
        d = max(d, -(length(p - nick) - rn));
    }
    float alpha = 1.0 - smoothstep(-px, px, d);
    if (alpha <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    float rimW = ubuf.rim * px;
    float inRim = rimW > 0.0 ? smoothstep(-rimW - px, -rimW + px, d) : 0.0;

    // ── The arms ────────────────────────────────────────────────────────────
    vec3 col = ubuf.fieldColor.rgb;
    float cy = 0.44 * hs;          // the fess point
    float ordMask = 0.0;
    float bw = 0.12;               // half the width of a band
    if (ord == 1) {
        vec2 apex = vec2(0.0, 0.3 * hs);
        vec2 dl = normalize(vec2(-0.5, 0.48 * hs));
        vec2 dr = normalize(vec2(0.5, 0.48 * hs));
        float l = p.x <= 0.0 ? band(p, apex, dl) : band(p, apex, dr);
        ordMask = 1.0 - smoothstep(0.105 - px, 0.105 + px, l);
    } else if (ord == 2) {
        vec2 dir = normalize(vec2(1.0, 0.85 * hs));
        ordMask = 1.0 - smoothstep(bw - px, bw + px, band(p, vec2(-0.5, 0.0), dir));
    } else if (ord == 3) {
        ordMask = 1.0 - smoothstep(bw - px, bw + px, abs(p.y - cy));
    } else if (ord == 4) {
        ordMask = 1.0 - smoothstep(bw - px, bw + px, abs(p.x));
    } else if (ord == 5) {
        float c = min(abs(p.x), abs(p.y - cy));
        ordMask = 1.0 - smoothstep(0.1 - px, 0.1 + px, c);
    } else if (ord == 6) {
        vec2 ctr = vec2(0.0, cy);
        float a = band(p, ctr, normalize(vec2(-0.5, -cy)));
        float b = band(p, ctr, normalize(vec2(0.5, -cy)));
        ordMask = 1.0 - smoothstep(0.1 - px, 0.1 + px, min(a, b));
    } else if (ord == 7) {
        ordMask = 1.0 - smoothstep(0.3 * hs - px, 0.3 * hs + px, p.y);
    }
    col = mix(col, ubuf.metalColor.rgb, ordMask);

    // The charges, where the ordinary leaves room for them.
    if (kind > 0) {
        float cd = 1.0;
        if (ubuf.lone > 0.5) {
            cd = chargeAt(p, vec2(0.0, 0.42 * hs), 0.3, kind);
        } else if (ord == 0) {
            cd = min(min(chargeAt(p, vec2(-0.2, 0.26 * hs), 0.12, kind), chargeAt(p, vec2(0.2, 0.26 * hs), 0.12, kind)),
                     chargeAt(p, vec2(0.0, 0.62 * hs), 0.12, kind));
        } else if (ord == 1) {
            cd = min(min(chargeAt(p, vec2(-0.26, 0.19 * hs), 0.095, kind), chargeAt(p, vec2(0.26, 0.19 * hs), 0.095, kind)),
                     chargeAt(p, vec2(0.0, 0.68 * hs), 0.095, kind));
        } else if (ord == 2) {
            cd = min(chargeAt(p, vec2(0.22, 0.2 * hs), 0.1, kind), chargeAt(p, vec2(-0.2, 0.7 * hs), 0.1, kind));
        } else if (ord == 3) {
            cd = min(min(chargeAt(p, vec2(-0.22, 0.17 * hs), 0.09, kind), chargeAt(p, vec2(0.22, 0.17 * hs), 0.09, kind)),
                     chargeAt(p, vec2(0.0, 0.72 * hs), 0.09, kind));
        } else if (ord == 4) {
            cd = min(chargeAt(p, vec2(-0.3, 0.42 * hs), 0.085, kind), chargeAt(p, vec2(0.3, 0.42 * hs), 0.085, kind));
        } else if (ord == 5) {
            cd = min(min(chargeAt(p, vec2(-0.28, 0.19 * hs), 0.08, kind), chargeAt(p, vec2(0.28, 0.19 * hs), 0.08, kind)),
                     min(chargeAt(p, vec2(-0.22, 0.7 * hs), 0.075, kind), chargeAt(p, vec2(0.22, 0.7 * hs), 0.075, kind)));
        } else if (ord == 6) {
            cd = min(min(chargeAt(p, vec2(0.0, 0.12 * hs), 0.075, kind), chargeAt(p, vec2(0.0, 0.76 * hs), 0.075, kind)),
                     min(chargeAt(p, vec2(-0.33, cy), 0.075, kind), chargeAt(p, vec2(0.33, cy), 0.075, kind)));
        } else if (ord == 7) {
            cd = min(min(chargeAt(p, vec2(-0.25, 0.145 * hs), 0.075, kind), chargeAt(p, vec2(0.0, 0.145 * hs), 0.075, kind)),
                     chargeAt(p, vec2(0.25, 0.145 * hs), 0.075, kind));
        }
        col = mix(col, ubuf.chargeColor.rgb, 1.0 - smoothstep(-px, px, cd));
    }

    // ── Paint on a curved board ─────────────────────────────────────────────
    // Brushed paint, a little uneven; the board bows forward, so the light
    // falls across it from the upper left and dies towards the far edge.
    float grain = noise(p * vec2(30.0, 90.0) + ubuf.seed) * 0.5 + noise(p * 140.0) * 0.5;
    col *= 0.94 + 0.1 * grain;
    float bow = p.x / 0.5;
    float light = 1.02 - 0.2 * bow - 0.14 * (p.y / hs) + 0.1 * exp(-pow((bow + 0.45) * 2.2, 2.0));
    col *= light;
    // Darker into the rim, where the paint meets the steel.
    col *= 1.0 - 0.28 * smoothstep(-rimW - 0.06, -rimW, d);

    // Scratches through the paint to the pale wood beneath.
    for (int i = 0; i < 7; i++) {
        float fi = float(i);
        vec2 a = vec2(hash(vec2(fi, ubuf.seed + 1.0)) - 0.5, hash(vec2(fi + 2.0, ubuf.seed)) * hs);
        float ang = hash(vec2(ubuf.seed, fi * 1.7)) * 3.14159;
        vec2 dir = vec2(cos(ang), sin(ang));
        vec2 rel = p - a;
        float along = dot(rel, dir);
        float len = 0.06 + 0.12 * hash(vec2(fi, fi + ubuf.seed));
        float s = band(p, a, dir) + max(0.0, abs(along) - len);
        float cut = (1.0 - smoothstep(0.0, 1.5 * px, s)) * step(fi, wear * 7.0);
        col = mix(col, vec3(0.74, 0.66, 0.55) * light, cut * 0.55);
    }

    // ── The rim ─────────────────────────────────────────────────────────────
    if (rimW > 0.0) {
        vec3 steel = ubuf.rimColor.rgb;
        // Rolled: lit along its upper left, dark along its lower right.
        vec2 e = vec2(px * 2.0, 0.0);
        vec2 n = normalize(vec2(heater(p + e.xy, hs) - heater(p - e.xy, hs), heater(p + e.yx, hs) - heater(p - e.yx, hs)) + 1e-6);
        float lit = dot(n, normalize(vec2(-0.7, -0.7)));
        float across = clamp(-d / max(rimW, px), 0.0, 1.0);
        vec3 r = steel * (0.72 + 0.4 * lit * (1.0 - across) + 0.12 * noise(p * 200.0));
        r = mix(r, steel * 1.25, pow(max(0.0, lit), 6.0) * 0.5);
        col = mix(col, r, inRim);
        // The joint between rim and board.
        float joint = exp(-pow((d + rimW) / (px * 0.9), 2.0));
        col *= 1.0 - 0.45 * joint;
    }

    // A thin dark line round the edge, so it reads on any wallpaper.
    col *= 1.0 - 0.55 * (1.0 - smoothstep(-2.0 * px, -0.5 * px, d));

    col += ubuf.glowColor.rgb * ubuf.glow * (0.25 + 0.35 * max(0.0, 1.0 - bow));

    fragColor = vec4(col * alpha, alpha) * ubuf.qt_Opacity;
}
