#version 440
// Smoke and embers over the wallpaper for the Siege desktop theme
// (modules/desktoptheme/SiegeLayer.qml): the pall of a burning town hanging
// along the top of the screen and drifting in at the sides, the glow of
// fires somewhere below the bottom edge lighting it from beneath, and
// embers carried up on the heat. Still: it's drawn once (and again only
// while `boot` runs), so an idle desktop costs nothing. Premultiplied: the
// smoke darkens what's under it, the firelight and the embers add to it.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float boot;        // 0..1 as the theme switches on
    float lineScale;   // screen px per layer px, inverted (previews)
    vec4 smokeColor;
    vec4 fireColor;
    vec4 emberColor;
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

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 uv = qt_TexCoord0;
    float aspect = res.x / res.y;
    vec2 frag = uv * res;
    float boot = clamp(ubuf.boot, 0.0, 1.0);

    // ── The pall ────────────────────────────────────────────────────────────
    // Billows along the top, thinning down the screen, a tongue of it
    // drifting in at each side.
    vec2 q = vec2(uv.x * aspect, uv.y) * 2.4;
    vec2 warp = vec2(fbm(q + vec2(3.1, 0.0)), fbm(q + vec2(0.0, 7.7))) - 0.5;
    float billow = fbm(q + warp * 1.6 + vec2(0.0, 1.3));
    float top = 1.0 - smoothstep(0.0, 0.46, uv.y + (billow - 0.5) * 0.22);
    float side = (1.0 - smoothstep(0.0, 0.2, min(uv.x, 1.0 - uv.x))) * (1.0 - smoothstep(0.2, 0.75, uv.y)) * 0.6;
    float density = smoothstep(0.3, 0.72, billow) * max(top, side);
    // Settling in as the theme comes up.
    density *= smoothstep(0.0, 0.7, boot);
    float smoke = density * 0.56;

    // ── Fires below the bottom edge ─────────────────────────────────────────
    float fromBottom = 1.0 - uv.y;
    float tongues = fbm(vec2(uv.x * aspect * 3.2, fromBottom * 2.0 - 0.3));
    float glow = pow(1.0 - smoothstep(0.0, 0.34 + 0.16 * tongues, fromBottom), 2.0);
    glow *= 0.55 + 0.7 * tongues;
    glow *= smoothstep(0.1, 0.9, boot);
    vec3 fire = ubuf.fireColor.rgb * glow * 0.2;
    // The smoke low down catches it.
    vec3 smokeCol = mix(ubuf.smokeColor.rgb, ubuf.fireColor.rgb * 0.5, glow * 0.6);

    // ── Embers on the heat ──────────────────────────────────────────────────
    // A few to each cell of a coarse grid, more of them lower down, each a
    // bright point trailing a short streak below it where it has risen.
    vec3 embers = vec3(0.0);
    float lw = max(1.0, ubuf.lineScale);
    for (int li = 0; li < 2; li++) {
        float cell = li == 0 ? 96.0 : 61.0;
        vec2 g = frag / cell;
        vec2 id = floor(g) + float(li) * 31.7;
        float chance = hash(id + 0.37);
        float height = 1.0 - (floor(g.y) * cell) / res.y;
        // Most embers low; a few carried high.
        float low = 1.0 - height;
        float keep = step(chance, li == 0 ? mix(0.015, 0.42, pow(low, 2.2)) : mix(0.0, 0.3, pow(low, 3.0)));
        vec2 at = (floor(g) + vec2(hash(id + 1.3), hash(id + 5.1)) * 0.8 + 0.1) * cell;
        float size = (0.7 + 1.5 * hash(id + 2.2)) * lw;
        vec2 d = frag - at;
        // The streak: below the point, thinning.
        float streakLen = (4.0 + 10.0 * hash(id + 8.8)) * lw;
        float along = clamp(d.y / streakLen, 0.0, 1.0);
        float streak = exp(-pow(d.x / (size * 0.6), 2.0)) * step(0.0, d.y) * (1.0 - along) * step(d.y, streakLen);
        float point = exp(-dot(d, d) / (size * size));
        float heat = 0.55 + 0.45 * hash(id + 4.4);
        float e = (point + streak * 0.45) * keep * heat;
        // Hot ones yellow, cooling ones red.
        embers += mix(ubuf.emberColor.rgb, vec3(1.0, 0.86, 0.5), heat * point) * e;
    }
    embers *= smoothstep(0.3, 1.0, boot) * 0.9;

    // A little darker at the corners.
    vec2 c = uv - 0.5;
    float vig = smoothstep(0.45, 0.85, length(c * vec2(aspect * 0.8, 1.0))) * 0.22 * boot;

    float a = clamp(smoke + vig, 0.0, 1.0);
    vec3 rgb = smokeCol * smoke + fire + embers;
    fragColor = vec4(rgb, a) * ubuf.qt_Opacity;
}
