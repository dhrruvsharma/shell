#version 440
// The season falling over the wallpaper for the Sekiro desktop theme
// (modules/desktoptheme/SekiroLayer.qml): sakura petals in spring,
// fireflies in summer, maple leaves in autumn and snow in winter (`fall`
// 0..3), caught in mid-air near the edges and the top of the screen and
// thinning out towards the middle so the picture stays clear; a low mist
// along the foot; and the bottom corners shaded a little so the shinobi's
// HUD reads there. Still: drawn once (and again only while `boot` runs, as
// the season drifts in). The lock screen and the power menu reuse it with
// `drift` running (px the season has fallen) and `chrome` 0 (no mist, no
// shading). Premultiplied.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float boot;        // 0..1 as the theme switches on
    float lineScale;   // screen px per layer px, inverted (previews)
    float fall;        // 0 sakura, 1 fireflies, 2 maple leaves, 3 snow
    float drift;       // px fallen since the start (the lock's, running)
    float chrome;      // 1 with the mist and the shading, 0 without
    float unit;        // layout scale: the lock's thumbnails draw it small
    vec4 mistColor;
    vec4 tintA;        // the season's colours
    vec4 tintB;
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

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = p * 2.03 + vec2(17.3, 9.1);
        a *= 0.5;
    }
    return v;
}

mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, -s, s, c);
}

// A petal at p (its own frame, about unit size): an egg narrowing to its
// base, a notch at its broad end.
float petal(vec2 p) {
    p.y += 0.15;
    float w = 0.36 + 0.24 * clamp(p.y + 0.5, 0.0, 1.0);
    float d = length(vec2(p.x / w, p.y / 0.62)) - 1.0;
    float notch = length(vec2(p.x * 2.2, p.y - 0.62)) - 0.16;
    return max(d, -notch);
}

// A maple leaf: seven pointed lobes round a heart, on a short stem.
float maple(vec2 p) {
    float a = atan(p.x, -p.y);
    float r = length(p);
    float lobes = abs(cos(a * 3.5));
    float bound = 0.36 + 0.5 * pow(lobes, 2.5) * smoothstep(3.1, 1.8, abs(a));
    float leaf = r - bound;
    float stem = max(abs(p.x) - 0.04, max(-p.y - 0.0, p.y - 0.62));
    return min(leaf, stem);
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 uv = qt_TexCoord0;
    float aspect = res.x / res.y;
    vec2 frag = uv * res;
    float boot = clamp(ubuf.boot, 0.0, 1.0);
    int fall = int(ubuf.fall + 0.5);
    float lw = max(1.0, ubuf.lineScale);

    // ── Mist along the foot ─────────────────────────────────────────────────
    vec2 q = vec2(uv.x * aspect, uv.y) * 2.2;
    float wisp = fbm(q + vec2(fbm(q * 0.7 + 3.0) * 1.4, 0.0));
    float low = smoothstep(0.62, 1.0, uv.y + (wisp - 0.5) * 0.18);
    float mist = low * smoothstep(0.32, 0.75, wisp) * 0.22 * smoothstep(0.0, 0.8, boot) * ubuf.chrome;

    // ── Shade for the HUD in the bottom corners, and a vignette ─────────────
    vec2 bl = (uv - vec2(0.0, 1.0)) * vec2(aspect, 1.0);
    vec2 br = (uv - vec2(1.0, 1.0)) * vec2(aspect, 1.0);
    float corner = max(1.0 - smoothstep(0.08, 0.5, length(bl * vec2(0.8, 1.6))), 1.0 - smoothstep(0.08, 0.55, length(br * vec2(0.75, 1.5))));
    float shade = corner * 0.34 * boot * ubuf.chrome;
    vec2 c = uv - 0.5;
    float vig = smoothstep(0.45, 0.9, length(c * vec2(aspect * 0.78, 1.0))) * 0.24 * boot * ubuf.chrome;

    // ── The season, caught in the air ───────────────────────────────────────
    // Thick along the top and the sides, thin in the middle of the picture.
    float edge = max(1.0 - smoothstep(0.0, 0.26, min(uv.x, 1.0 - uv.x)), 1.0 - smoothstep(0.0, 0.3, uv.y));
    vec3 col = vec3(0.0);
    float cover = 0.0;
    for (int li = 0; li < 2; li++) {
        float cell = (li == 0 ? 92.0 : 57.0) * max(ubuf.unit, 0.05);
        // Drifting in as the theme comes up.
        float depth = li == 0 ? 1.0 : 0.6;
        vec2 g = (frag + vec2(-18.0, -60.0) * (1.0 - boot) * depth - vec2(0.3, 1.0) * ubuf.drift * depth) / cell;
        vec2 id = floor(g) + float(li) * 41.3;
        float chance = hash(id + 0.17);
        float want = mix(0.03, li == 0 ? 0.38 : 0.26, edge);
        if (fall == 1)
            want = mix(0.04, 0.22, max(edge, smoothstep(0.5, 1.0, uv.y)));
        if (chance > want)
            continue;
        vec2 at = (floor(g) + vec2(hash(id + 1.3), hash(id + 5.1)) * 0.76 + 0.12) * cell;
        float size = (li == 0 ? 7.5 : 5.0) * (0.7 + 0.6 * hash(id + 2.2)) * lw * max(ubuf.unit, 0.05);
        // Petals and flakes read only a little larger than leaves.
        if (fall == 0)
            size *= 1.55;
        else if (fall == 3)
            size *= 0.85;
        vec2 d = (frag - at) / size;
        float spin = hash(id + 3.9) * 6.2832;
        float tone = hash(id + 7.7);
        // Nearer ones a little soft, as if out of focus.
        float soft = (li == 0 ? 0.08 : 0.16) + 0.1 * hash(id + 9.1);
        float a = 0.0;
        vec3 tint;
        if (fall == 0) {
            vec2 pd = rot(spin) * d;
            pd.y /= 0.75 + 0.25 * abs(sin(spin * 2.0)); // seen edge-on, a little
            a = smoothstep(soft, -soft, petal(pd));
            tint = mix(ubuf.tintA.rgb, ubuf.tintB.rgb, tone) * (0.92 + 0.12 * smoothstep(0.3, -0.5, pd.y));
            a *= 0.8;
        } else if (fall == 1) {
            float r = length(d);
            float core = exp(-r * r * 3.5);
            float halo = exp(-r * 0.9) * 0.32;
            a = clamp(core + halo, 0.0, 1.0) * (0.45 + 0.55 * tone);
            tint = mix(ubuf.tintA.rgb, ubuf.tintB.rgb, core);
        } else if (fall == 2) {
            vec2 md = rot(spin) * d * 0.62;
            md.y /= 0.7 + 0.3 * abs(cos(spin * 1.7));
            float m = maple(md);
            a = smoothstep(soft * 0.6, -soft * 0.6, m);
            // Veins, and the leaf darker towards its stem.
            float vein = smoothstep(0.035, 0.0, abs(sin(atan(md.x, -md.y) * 3.5)) * length(md)) * 0.25;
            tint = mix(ubuf.tintA.rgb, ubuf.tintB.rgb, tone) * (0.85 + 0.25 * smoothstep(0.5, 0.0, length(md)) - vein);
            a *= 0.86;
        } else {
            float r = length(d) * (0.8 + 0.4 * tone);
            a = smoothstep(0.9, 0.2 - soft, r) * (0.5 + 0.5 * tone);
            tint = mix(ubuf.tintA.rgb, ubuf.tintB.rgb, tone);
        }
        a *= smoothstep(0.1 + 0.25 * float(li), 0.9, boot);
        col = col * (1.0 - a) + tint * a;
        cover = cover + a * (1.0 - cover);
    }

    // Mist and shade beneath the season.
    float dark = clamp(shade + vig, 0.0, 1.0);
    vec3 under = ubuf.mistColor.rgb * mist;
    float underA = clamp(mist + dark, 0.0, 1.0);
    vec3 rgb = col + under * (1.0 - cover);
    float a = cover + underA * (1.0 - cover);
    fragColor = vec4(rgb, a) * ubuf.qt_Opacity;
}
