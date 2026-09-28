#version 440
// The blast shutter of the "Blast Door" lock (Wasteland): corrugated steel,
// ribs lit from above, rust running down from the grooves and blooming in
// patches, grime gathered at the foot, and your wallpaper spray-painted
// across it as a mural in a few flat tones, flaking off where the paint has
// given up. A heavy bottom rail carries worn hazard stripes. Opaque, static:
// it moves as an item.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float uiScale;     // layout scale
    float mural;       // 0..1 how much of the painting is left
    float rail;        // bottom rail height, px
    vec4 steelColor;   // opaque
    vec4 rustColor;    // opaque
    vec4 hazardColor;  // opaque
    vec4 grimeColor;   // opaque
    vec4 paintColor;   // opaque, the theme's weathered paint
} ubuf;

layout(binding = 1) uniform sampler2D wall;

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
    vec2 px = uv * res;
    float s = ubuf.uiScale;
    float railTop = res.y - ubuf.rail;

    // ── Corrugation: ribs lit on their upper faces ──────────────────────
    float pitch = 34.0 * s;
    float ph = fract(px.y / pitch);
    float shade = 0.72 + 0.36 * cos(ph * 6.2831853 - 0.6);
    vec3 steel = ubuf.steelColor.rgb * (0.82 + 0.22 * noise(vec2(px.x / 70.0, px.y / 2.0)));
    steel *= 0.9 + 0.2 * fbm(px / 90.0);

    // ── The mural: the wallpaper in flat spray-paint tones ─────────────
    vec2 wob = vec2(noise(px / 40.0), noise(px / 40.0 + 7.0)) - 0.5;
    vec3 w = texture(wall, clamp(uv + wob * 0.004, 0.0, 1.0)).rgb;
    float l = dot(w, vec3(0.299, 0.587, 0.114));
    float level = floor(clamp(l, 0.0, 0.999) * 4.0);
    vec3 bone = vec3(0.9, 0.85, 0.74);
    vec3 dark = ubuf.grimeColor.rgb * 1.4;
    vec3 tone = level < 1.0 ? dark : level < 2.0 ? ubuf.paintColor.rgb * 0.7 : level < 3.0 ? mix(ubuf.paintColor.rgb, bone, 0.35) : bone;
    // A trace of the picture's own colour, sun-bleached.
    tone = mix(tone, mix(vec3(l), w, 0.8) * 0.9 + 0.08, 0.3);
    // Flaking: paint gone in patches, more of it towards the foot.
    float flake = fbm(px / 16.0 + 3.0) + (uv.y - 0.5) * 0.18;
    float painted = smoothstep(0.29, 0.35, flake) * ubuf.mural;
    // Soft overspray at the mural's edges.
    vec2 e = min(uv, 1.0 - uv) * vec2(res.x / res.y, 1.0);
    painted *= smoothstep(0.0, 0.05, min(e.x, e.y) + (noise(px / 30.0) - 0.5) * 0.04);
    vec3 col = mix(steel, tone, painted * 0.88) * shade;

    // ── Rust: streaks from the grooves, and patches ─────────────────────
    float streak = smoothstep(0.55, 0.85, fbm(vec2(px.x / 22.0, px.y / 380.0) + 11.0)) * (0.5 + 0.5 * smoothstep(0.7, 0.95, ph));
    float blotch = smoothstep(0.58, 0.72, fbm(px / 70.0 + 5.0));
    float rust = clamp(streak * 0.55 + blotch * 0.7 + smoothstep(0.55, 1.0, uv.y) * 0.25 * fbm(px / 25.0), 0.0, 1.0);
    vec3 rustC = ubuf.rustColor.rgb * (0.6 + 0.7 * noise(px / 3.0)) * shade;
    col = mix(col, rustC, rust * (1.0 - painted * 0.6) * 0.85);

    // Grime at the foot and along the ribs.
    col = mix(col, ubuf.grimeColor.rgb, smoothstep(0.6, 1.0, uv.y) * 0.35 + smoothstep(0.85, 1.0, ph) * 0.15);

    // A shadow under the housing at the top.
    col *= 0.55 + 0.45 * smoothstep(0.0, 40.0 * s, px.y);

    // ── The bottom rail, hazard-striped ─────────────────────────────────
    if (px.y > railTop) {
        float ry = (px.y - railTop) / ubuf.rail;
        vec3 metal = ubuf.steelColor.rgb * (1.15 - ry * 0.4) * (0.85 + 0.2 * noise(vec2(px.x / 60.0, px.y / 2.0)));
        float stripe = step(0.5, fract((px.x + px.y) / (46.0 * s)));
        vec3 hz = mix(ubuf.hazardColor.rgb, vec3(0.06, 0.055, 0.05), stripe);
        float band = step(0.18, ry) * step(ry, 0.82);
        float wear = smoothstep(0.55, 0.68, fbm(px / 12.0 + 9.0));
        col = mix(metal, hz * (0.85 + 0.2 * noise(px / 4.0)), band * (1.0 - wear * 0.85));
        col = mix(col, rustC, smoothstep(0.62, 0.8, fbm(px / 30.0)) * 0.6);
        // Lit top edge and a shadow line above the rail.
        col *= 1.0 + smoothstep(3.0 * s, 0.0, px.y - railTop) * 0.5;
    }
    col *= 1.0 - smoothstep(8.0 * s, 0.0, railTop - px.y) * step(px.y, railTop) * 0.5;

    fragColor = vec4(col, 1.0) * ubuf.qt_Opacity;
}
