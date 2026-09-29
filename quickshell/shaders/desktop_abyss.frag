#version 440
// Abyss desktop theme: the wallpaper sunk under the sea. `source` is the
// wallpaper as drawn (ThemeLayer's `wallpaper`); it's refracted a touch and
// seen through water that soaks up red first, then green, the way the sea
// does, and fills with its own blue-green haze. How deep we are (`depth`, 0
// surface .. 1 the trenches) comes from the hour: by day the light net of
// caustics and shafts of sun come down from the surface; by night they
// fade and the water fills with points of bioluminescence in the theme's
// glows. Marine snow hangs in it throughout.
//
// Static: no time uniform; the pattern is fixed. `flood` is the switch-on:
// the waterline rises up the screen with a bright meniscus.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float depth;       // 0 surface .. 1 the trenches
    float flood;       // 0..1 the water rising as it switches on
    float lineScale;   // > 1 when drawn scaled down
    vec4 glowColor;    // bioluminescence
    vec4 lumeColor;    // sea-glow
    vec4 waterColor;   // the water's own colour
    vec4 sunColor;     // light from the surface
} ubuf;

layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
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
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = p * 2.03 + vec2(17.3, 9.1);
        a *= 0.5;
    }
    return v;
}

// Distance to the nearest cell border of a jittered grid: thin along the
// borders, wide in the middle of the cells.
float border(vec2 p) {
    vec2 g = floor(p);
    vec2 f = fract(p);
    float d1 = 8.0;
    float d2 = 8.0;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 o = vec2(float(i), float(j));
            vec2 r = o + hash2(g + o) * 0.9 + 0.05 - f;
            float d = dot(r, r);
            if (d < d1) {
                d2 = d1;
                d1 = d;
            } else if (d < d2) {
                d2 = d;
            }
        }
    }
    return sqrt(d2) - sqrt(d1);
}

// The net of light a rippled surface throws down: bright seams of a warped
// cell pattern, a coarse net over a finer one.
float caustics(vec2 p) {
    vec2 w = p + 0.8 * vec2(fbm(p * 0.45), fbm(p * 0.45 + 5.2)) - 0.4;
    float a = exp(-border(w) * 17.0);
    float b = exp(-border(w * 1.7 + 3.7) * 19.0);
    // Where two seams cross the light gathers.
    return a * 0.7 + b * 0.35 + a * b * 0.8;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    float aspect = res.x / max(1.0, res.y);
    vec2 sp = vec2(uv.x * aspect, uv.y);
    float d = clamp(ubuf.depth, 0.0, 1.0);
    float px = 1.0 / res.y;

    vec4 dry = texture(source, uv);

    // The waterline, rising as the theme comes on.
    float level = 1.06 - ubuf.flood * 1.18;
    float surf = level + 0.012 * sin(uv.x * 17.0 + 1.3) + 0.006 * sin(uv.x * 43.0 + 0.4);
    float under = smoothstep(surf - px, surf + px, uv.y);
    if (under <= 0.0) {
        fragColor = dry * ubuf.qt_Opacity;
        return;
    }

    // Refraction: the picture swims a little.
    vec2 wob = vec2(fbm(sp * 3.1 + 2.0), fbm(sp * 3.1 + 7.3)) - 0.5;
    vec3 wall = texture(source, clamp(uv + wob * 0.006, 0.0, 1.0)).rgb;

    // Water between us and the picture: longer the deeper we are, and a
    // little longer towards the bottom of the screen, seawards.
    float path = mix(0.35, 2.4, d) + uv.y * mix(0.35, 0.9, d);
    vec3 absorb = vec3(0.6, 0.17, 0.09);
    vec3 through = exp(-absorb * path * 1.35);
    float ambient = mix(1.0, 0.5, pow(d, 0.8));
    vec3 haze = ubuf.waterColor.rgb * (1.0 - exp(-0.85 * path)) * mix(1.15, 0.45, d);
    vec3 col = wall * through * ambient + haze;

    // Daylight from the surface: the shimmer overhead, shafts slanting
    // down, and the caustic net, all fading with depth.
    float day = pow(1.0 - d, 1.6);
    col += ubuf.sunColor.rgb * exp(-uv.y * 5.5) * 0.16 * day;
    vec2 src = vec2(0.38 * aspect, -0.35);
    vec2 toSrc = sp - src;
    float ang = atan(toSrc.x, toSrc.y);
    float shafts = pow(noise(vec2(ang * 16.0, 0.5)), 3.0) * 0.8 + pow(noise(vec2(ang * 41.0, 3.0)), 4.0) * 0.5;
    shafts *= smoothstep(1.4, 0.1, length(toSrc)) * smoothstep(-0.1, 0.25, uv.y + 0.1);
    col += ubuf.sunColor.rgb * shafts * 0.2 * day;
    float net = caustics(sp * vec2(4.6, 6.2) + vec2(0.0, uv.y * 1.5));
    col += ubuf.sunColor.rgb * net * 0.1 * day * smoothstep(0.8, 0.0, uv.y);

    // Marine snow: flecks drifting in the water, a few near and blurred.
    vec2 g = sp * 70.0;
    vec2 cell = floor(g);
    vec2 h = hash2(cell);
    float fleck = step(0.93, hash(cell + 11.0)) * smoothstep(0.09, 0.0, length(fract(g) - h));
    vec2 g2 = sp * 17.0;
    vec2 cell2 = floor(g2);
    float blur = step(0.88, hash(cell2 + 4.0)) * smoothstep(0.28, 0.0, length(fract(g2) - hash2(cell2 + 2.0)));
    float snowLight = mix(0.5, 0.18, d);
    col += ubuf.lumeColor.rgb * 0.15 * (fleck * 0.9 + blur * 0.28) * snowLight + vec3(0.8) * fleck * 0.12 * snowLight;

    // Bioluminescence: sparse points of light in the dark, more the deeper.
    vec2 g3 = sp * 26.0;
    vec2 cell3 = floor(g3);
    float r3 = hash(cell3 + 21.0);
    float lit = step(1.0 - 0.07 * smoothstep(0.25, 1.0, d), r3);
    float dist3 = length(fract(g3) - hash2(cell3 + 8.0) * 0.8 - 0.1);
    vec3 tint = mix(ubuf.glowColor.rgb, ubuf.lumeColor.rgb, step(0.5, hash(cell3 + 3.0)));
    float spark = lit * (exp(-dist3 * 38.0) * 1.1 + exp(-dist3 * 9.0) * 0.18);
    col += tint * spark * smoothstep(0.2, 0.9, d) * 0.9;

    // The dark all round, as through a porthole.
    vec2 c = (uv - 0.5) * vec2(aspect / 1.6, 1.0);
    col *= 1.0 - smoothstep(0.45, 1.05, length(c)) * mix(0.28, 0.45, d);

    // The meniscus while the water rises.
    float line = exp(-abs(uv.y - surf) / (2.5 * px * ubuf.lineScale)) * step(ubuf.flood, 0.999);
    col = mix(col, ubuf.sunColor.rgb, line * 0.55);

    vec3 outc = mix(dry.rgb, col, under);
    fragColor = vec4(outc, 1.0) * ubuf.qt_Opacity;
}
