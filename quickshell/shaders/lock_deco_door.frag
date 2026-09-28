#version 440
// One leaf of the "Express Elevator" lock's doors (Art Deco). Black lacquer
// in a double gold frame stepped at the corners; an engraved panel showing
// the wallpaper as gold linework on lacquer (each leaf engraved with its own
// half, so the closed doors show the whole picture); a band of chevrons; and
// a brass kick plate with half a sunburst, the two halves meeting at the
// seam. The right leaf is the left one mirrored (`mirror`).
//
// `flash` gilds everything (the unlock's ding), `alarm` warms it red (a
// wrong floor). Static otherwise; the leaves move as items.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float screenWidth;
    float closedX;     // where this leaf's left edge sits when closed
    float mirror;      // 1 for the right leaf
    float uiScale;     // layout scale (px per reference px)
    float flash;       // 0..1
    float alarm;       // 0..1
    vec4 goldColor;    // opaque
    vec4 jewelColor;   // opaque
    vec4 lacquerColor; // opaque
} ubuf;

layout(binding = 1) uniform sampler2D wall;

const float PI = 3.14159265;

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

// Distance outside a box stepped at its corners (<= 0 inside), with
// `c` the step.
float steppedBox(vec2 p, vec2 lo, vec2 hi, float c) {
    vec2 q = min(p - lo, hi - p);          // distance to each side, inside > 0
    float inside = min(q.x, q.y);
    // Cut the corner squares out.
    vec2 k = step(q, vec2(c));
    float corner = k.x * k.y;
    return corner > 0.5 ? max(c - q.x, c - q.y) : -inside;
}

float line(float d, float w) {
    return smoothstep(w, w * 0.3, abs(d));
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 px = qt_TexCoord0 * res;
    float s = ubuf.uiScale;
    // x from the seam: 0 at the seam, growing outwards.
    float fromSeam = ubuf.mirror > 0.5 ? px.x : res.x - px.x;
    // A layout mirrored so both leaves read the same: seam on the right.
    vec2 p = vec2(res.x - fromSeam, px.y);
    vec3 gold = ubuf.goldColor.rgb;
    vec3 lacquer = ubuf.lacquerColor.rgb;
    float lw = max(1.0, 1.2 * s);

    // Lacquer, catching a little light towards the seam and the top.
    vec3 col = lacquer * (1.0 + 0.5 * smoothstep(res.x, 0.0, fromSeam) + 0.25 * smoothstep(res.y * 0.6, 0.0, px.y));
    col += lacquer * (noise(vec2(px.x / 3.0, px.y / 240.0)) - 0.5) * 0.4;

    // ── Frame: a double gold rule, stepped at the corners ───────────────
    vec2 lo = vec2(28.0 * s, 26.0 * s);
    vec2 hi = vec2(res.x - 16.0 * s, res.y - 26.0 * s);
    float f1 = steppedBox(p, lo, hi, 14.0 * s);
    float f2 = steppedBox(p, lo + 7.0 * s, hi - 7.0 * s, 10.0 * s);
    col = mix(col, gold, line(f1, lw) * 0.95);
    col = mix(col, gold * 0.8, line(f2, lw * 0.8) * 0.6);

    // ── The engraved panel ─────────────────────────────────────────────
    vec2 plo = vec2(74.0 * s, 70.0 * s);
    vec2 phi = vec2(res.x - 48.0 * s, res.y * 0.62);
    float pd = steppedBox(p, plo, phi, 12.0 * s);
    if (pd < 0.0) {
        // This leaf's half of the wallpaper, where it sits when closed.
        vec2 wuv = vec2((ubuf.closedX + px.x) / ubuf.screenWidth, (px.y + res.y * 0.05) / (res.y * 1.1));
        vec3 w = texture(wall, clamp(wuv, 0.0, 1.0)).rgb;
        float lum = pow(dot(w, vec3(0.299, 0.587, 0.114)), 0.85);
        // Engraving: horizontal lines, fatter where the picture is bright.
        float pitch = 4.0 * s;
        float fy = abs(fract(px.y / pitch) - 0.5) * 2.0;
        float cut = smoothstep(lum + 0.12, lum - 0.12, fy);
        vec3 etched = mix(lacquer * 1.4, gold * (0.75 + 0.35 * lum), cut);
        // A trace of the picture's own colour, as if the gold were tinted.
        etched = mix(etched, etched * (0.6 + 0.8 * w), 0.25);
        col = mix(col, etched, smoothstep(0.0, -1.5, pd));
    }
    col = mix(col, gold, line(pd, lw) * 0.9);

    // ── Chevrons under the panel ────────────────────────────────────────
    float cy = res.y * 0.665;
    float band = 26.0 * s;
    if (abs(px.y - cy) < band * 0.5 && p.x > lo.x + 14.0 * s && p.x < hi.x - 8.0 * s) {
        float zig = abs(fract(p.x / (band * 1.2)) - 0.5) * band * 1.2;
        float d1 = abs(px.y - cy - zig + band * 0.3);
        col = mix(col, gold, smoothstep(lw * 1.2, lw * 0.3, d1) * 0.85);
        float d2 = abs(px.y - cy - zig + band * 0.3 + 8.0 * s);
        col = mix(col, gold * 0.7, smoothstep(lw, lw * 0.3, d2) * 0.5);
    }

    // ── Kick plate with half a sunburst ─────────────────────────────────
    float ky = res.y * 0.735;
    vec2 klo = vec2(lo.x + 16.0 * s, ky);
    vec2 khi = vec2(hi.x - 10.0 * s, res.y - lo.y - 18.0 * s);
    if (p.x > klo.x && p.x < khi.x && px.y > klo.y && px.y < khi.y) {
        // Brushed brass.
        vec3 brass = gold * (0.3 + 0.1 * noise(vec2(px.x / 90.0, px.y / 1.5)) + 0.06 * noise(vec2(px.x / 12.0, px.y / 0.8)));
        // Rays from the foot of the seam, alternately bright and dark.
        vec2 o = vec2(res.x, khi.y);
        vec2 d = p - o;
        float ang = atan(-d.y, -d.x);           // 0 along the floor, up to PI/2 at the seam
        float ray = floor(ang / (PI / 34.0));
        brass *= mod(ray, 2.0) < 0.5 ? 1.35 : 0.7;
        float r = length(d);
        // The sun: a gilt half disc with a lacquer rim and a gold ring.
        float sun = smoothstep(118.0 * s + 1.0, 118.0 * s - 1.0, r);
        brass = mix(brass, gold * (0.95 + 0.1 * noise(p / 3.0)), sun);
        brass = mix(brass, lacquer, line(r - 126.0 * s, lw * 2.2) * 0.95);
        brass = mix(brass, gold, line(r - 134.0 * s, lw) * 0.8);
        col = brass;
    }
    col = mix(col, gold, line(steppedBox(p, klo, khi, 8.0 * s), lw) * 0.9);

    // ── The seam: shadow, then a lit edge ───────────────────────────────
    col *= 1.0 - smoothstep(4.0 * s, 0.0, fromSeam) * 0.7;
    col = mix(col, gold * 1.2, line(fromSeam - 5.0 * s, lw * 0.8) * 0.5);

    // ── The ding (gilded) and a wrong floor (warmed red) ────────────────
    col = mix(col, col + gold * 0.35, ubuf.flash);
    col = mix(col, col * vec3(1.35, 0.55, 0.5), ubuf.alarm * 0.6);

    fragColor = vec4(col, 1.0) * ubuf.qt_Opacity;
}
