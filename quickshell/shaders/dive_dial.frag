#version 440
// A diver's watch for the Abyss theme (modules/lock/themes/abyss/
// DiveDial.qml): a ceramic bezel graduated for sixty minutes with a lume pip
// at zero and a coin edge, a dial engraved with waves and darkening to the
// rim, lume markers (a triangle at twelve, batons at three, six and nine,
// dots between) and sword hands filled with lume, all glowing faintly in the
// dark. Static: redrawn when the minute changes.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float hour;        // 0..12, fractional
    float minute;      // 0..60, fractional
    float bezel;       // bezel turned, degrees
    float glow;        // how brightly the lume glows, 0..1
    vec4 lumeColor;
    vec4 dialColor;
    vec4 bezelColor;
    vec4 metalColor;
} ubuf;

const float PI = 3.14159265;
const float TAU = 6.28318531;

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

float box(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// A sword hand along +y: widest a third of the way out, pointed at `len`,
// a short tail behind the pin.
float sword(vec2 p, float len, float w) {
    float y = p.y;
    float half_ = y < 0.0 ? w * 0.35 * (1.0 + y / 0.12) : y < len * 0.3 ? mix(w * 0.35, w * 0.5, y / (len * 0.3)) : w * 0.5 * (1.0 - (y - len * 0.3) / (len * 0.7));
    float inside = max(abs(p.x) - max(half_, 0.0), max(-0.12 - y, y - len));
    return inside;
}

vec2 rot(vec2 p, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    float R = 0.5 * min(res.x, res.y) / 1.08;
    vec2 p = (qt_TexCoord0 * res - res * 0.5) / R * vec2(1.0, -1.0);
    float px = 1.0 / R;
    float r = length(p);
    float ang = mod(atan(p.x, p.y), TAU);
    float light = 0.85 + 0.25 * dot(normalize(p + vec2(1e-4)), normalize(vec2(-0.5, 0.85))) * smoothstep(0.0, 0.4, r);
    vec3 lume = ubuf.lumeColor.rgb;
    vec3 metal = ubuf.metalColor.rgb;

    float alpha = smoothstep(1.0 + px, 1.0 - px, r);
    vec3 col = vec3(0.0);
    float glowField = 0.0;

    // ── Bezel ────────────────────────────────────────────────────────────────
    vec3 ceramic = ubuf.bezelColor.rgb * (0.9 + 0.15 * light) + vec3(0.03) * smoothstep(0.7, 1.0, light);
    col = ceramic;
    // Coin edge: fine grooves round the outside.
    float grooves = step(0.965, r) * (0.5 + 0.5 * sin(ang * 120.0));
    col = mix(col, metal * 0.55 * light, step(0.965, r));
    col *= 1.0 - grooves * 0.35;
    // The minutes, every one for the first fifteen, then every five.
    float ba = mod(ang - radians(ubuf.bezel), TAU);
    float m = ba / TAU * 60.0;
    float fromMin = abs(fract(m + 0.5) - 0.5) * TAU / 60.0 * r / px;
    float fromFive = abs(fract(m / 5.0 + 0.5) - 0.5) * TAU / 12.0 * r / px;
    float firstQuarter = step(m, 15.5);
    float minuteTick = (1.0 - smoothstep(0.8, 1.8, fromMin)) * firstQuarter * step(0.9, r) * step(r, 0.955);
    float fiveTick = (1.0 - smoothstep(1.2, 2.2, fromFive)) * step(0.87, r) * step(r, 0.955) * (1.0 - firstQuarter * 0.0);
    float engraved = max(minuteTick, fiveTick) * step(r, 0.96) * step(0.84, r);
    col = mix(col, metal * 1.1, engraved * 0.85);
    // The pip at zero: a lume triangle in a metal cup.
    vec2 pp = rot(p, radians(ubuf.bezel));
    vec2 tp = pp - vec2(0.0, 0.905);
    float tri = max(abs(tp.x) * 1.8 + tp.y * 0.9 - 0.045, -tp.y - 0.03);
    float pip = 1.0 - smoothstep(-px, px, tri);
    float cup = 1.0 - smoothstep(-px, px, length(tp - vec2(0.0, -0.004)) - 0.055);
    col = mix(col, metal * 1.15, cup * 0.9);
    col = mix(col, lume, pip);
    glowField = max(glowField, pip);
    // Chapter ring between the bezel and the dial.
    float chapter = smoothstep(0.84 + px, 0.84 - px, r);
    col = mix(col, metal * 0.8 * light, chapter);

    // ── Dial ─────────────────────────────────────────────────────────────────
    float onDial = smoothstep(0.815 + px, 0.815 - px, r);
    if (onDial > 0.0) {
        vec3 dial = ubuf.dialColor.rgb * mix(1.15, 0.55, smoothstep(0.1, 0.82, r));
        // Waves engraved across it.
        float wave = sin((p.y + 0.035 * sin(p.x * 11.0)) * 70.0);
        dial *= 1.0 + 0.07 * wave * (0.6 + 0.4 * light);
        dial *= 0.95 + 0.1 * light;
        // Minute track: small ticks round the edge.
        float mm = ang / TAU * 60.0;
        float trackD = abs(fract(mm + 0.5) - 0.5) * TAU / 60.0 * r / px;
        float track = (1.0 - smoothstep(0.6, 1.6, trackD)) * step(0.77, r) * step(r, 0.8);
        dial = mix(dial, metal * 0.8, track * 0.7);
        col = mix(col, dial, onDial);
    }

    // ── Markers ──────────────────────────────────────────────────────────────
    float hIdx = floor(ang / TAU * 12.0 + 0.5);
    float hA = hIdx * TAU / 12.0;
    vec2 mp = rot(p, hA);                  // marker frame: the marker up +y
    float marker;
    if (hIdx == 0.0 || hIdx == 12.0) {
        vec2 t = mp - vec2(0.0, 0.66);
        marker = max(abs(t.x) * 1.7 + t.y * 0.85 - 0.075, -t.y - 0.06);
    } else if (mod(hIdx, 3.0) == 0.0) {
        marker = box(mp - vec2(0.0, 0.64), vec2(0.028, 0.085)) - 0.006;
    } else {
        marker = length(mp - vec2(0.0, 0.66)) - 0.045;
    }
    float mFill = 1.0 - smoothstep(-px, px, marker);
    float mRim = 1.0 - smoothstep(-px, px, marker - 0.012);
    col = mix(col, metal * 1.1 * light, mRim * onDial);
    col = mix(col, lume * 0.92, mFill * onDial);
    glowField = max(glowField, mFill * onDial);

    // ── Hands ────────────────────────────────────────────────────────────────
    float hourA = ubuf.hour / 12.0 * TAU;
    float minA = ubuf.minute / 60.0 * TAU;
    vec2 hp = rot(p, hourA);
    vec2 mhp = rot(p, minA);
    // Shadows a touch down and right.
    float hs = sword(rot(p - vec2(0.012, -0.018), hourA), 0.5, 0.1);
    float ms = sword(rot(p - vec2(0.014, -0.022), minA), 0.74, 0.075);
    float shadow = max(1.0 - smoothstep(-px * 3.0, px * 3.0, hs), 1.0 - smoothstep(-px * 3.0, px * 3.0, ms));
    col *= 1.0 - shadow * 0.45 * onDial;
    float hd = sword(hp, 0.5, 0.1);
    float md = sword(mhp, 0.74, 0.075);
    float hFill = 1.0 - smoothstep(-px, px, hd);
    float hLume = 1.0 - smoothstep(-px, px, hd + 0.014);
    float mFillH = 1.0 - smoothstep(-px, px, md);
    float mLumeH = 1.0 - smoothstep(-px, px, md + 0.012);
    col = mix(col, metal * (1.0 + 0.2 * light), hFill);
    col = mix(col, lume, hLume * step(0.02, hp.y));
    col = mix(col, metal * (1.05 + 0.2 * light), mFillH);
    col = mix(col, lume, mLumeH * step(0.02, mhp.y));
    glowField = max(glowField, max(hLume * step(0.02, hp.y), mLumeH * step(0.02, mhp.y)));
    // The pin.
    float pin = 1.0 - smoothstep(0.045 - px, 0.045 + px, r);
    col = mix(col, metal * 1.25, pin);
    col = mix(col, metal * 0.5, 1.0 - smoothstep(0.014 - px, 0.014 + px, r));

    // ── Lume glow ────────────────────────────────────────────────────────────
    // A soft bloom round everything filled with lume, faked from the
    // fill itself and the distance to the markers and hands.
    float near = max(max(exp(-max(0.0, marker) * 28.0), exp(-max(0.0, hd + 0.014) * 30.0)), exp(-max(0.0, md + 0.012) * 30.0));
    col += lume * near * 0.22 * ubuf.glow * onDial;
    col += lume * glowField * 0.12 * ubuf.glow;

    fragColor = vec4(col * alpha, alpha) * ubuf.qt_Opacity;
}
