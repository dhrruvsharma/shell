#version 440
// A page of the customizer's book (modules/customizer): the paper, its
// grain and fibres, a shadow running into the gutter where the page bends
// down into the binding, the outer edges aged a little, and a few foxing
// spots on old stock. Some themes print a faint pattern on the page too:
// a dot grid (1), scanlines (2), stars (3), rain (4) or sonar rings (5).
// Static: it draws once for each size or colour.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 paper;
    vec4 shade;       // the gutter's and aged edges' tone
    float itemWidth;
    float itemHeight;
    float spineSide;  // 0: the binding on the right (a left page), 1: on the left
    float grain;      // fine grain, 0..1
    float fibres;     // long fibres, 0..1
    float age;        // darkened edges and foxing, 0..1
    float gutter;     // the gutter's shadow, 0..1
    float seed;
    vec4 ink;         // the pattern's colour
    float pattern;    // 0 none .. 5, see above
} ubuf;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7)) + ubuf.seed * 17.13) * 43758.5453);
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
        p = p * 2.03 + vec2(13.1, 7.7);
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 px = qt_TexCoord0 * res;
    vec3 c = ubuf.paper.rgb;
    float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
    // Light paper darkens towards its shade; dark paper lifts a touch less.
    float tex = 0.0;

    // Fine grain, pixel-sized, and a cloudier formation under it.
    tex += (hash(floor(px)) - 0.5) * 0.035 * ubuf.grain;
    tex += (fbm(px / 38.0) - 0.5) * 0.06 * ubuf.grain;

    // Fibres: short streaks laid along the sheet.
    float f = noise(vec2(px.x / 26.0, px.y / 1.6));
    tex -= smoothstep(0.78, 0.95, f) * 0.05 * ubuf.fibres;
    float f2 = noise(vec2(px.x / 9.0 + 40.0, px.y / 0.9));
    tex += smoothstep(0.86, 0.98, f2) * 0.03 * ubuf.fibres;

    c += tex * (lum > 0.45 ? 1.0 : 0.7);

    // The gutter: where the page curves down into the binding.
    float d = ubuf.spineSide > 0.5 ? px.x : res.x - px.x;
    float g = exp(-d / 22.0) * 0.55 + exp(-d / 110.0) * 0.18;
    // And a soft lift of light just before it, where the page rises.
    float rise = exp(-pow((d - 70.0) / 60.0, 2.0)) * 0.04;
    c = mix(c, ubuf.shade.rgb, clamp(g * ubuf.gutter, 0.0, 1.0));
    c += rise * ubuf.gutter * (lum > 0.45 ? 0.6 : 0.3);

    // Aged outer edges, and foxing on old stock.
    float outer = ubuf.spineSide > 0.5 ? res.x - px.x : px.x;
    float edge = min(outer, min(px.y, res.y - px.y));
    float a = exp(-edge / 14.0) * 0.45 + exp(-edge / 90.0) * 0.12;
    float blot = fbm(px / 140.0 + 3.0);
    a += smoothstep(0.62, 0.8, blot) * 0.18 * smoothstep(260.0, 0.0, edge);
    c = mix(c, ubuf.shade.rgb, clamp(a * ubuf.age, 0.0, 1.0));

    // The theme's pattern, faint, kept off the margins' edge.
    int pat = int(ubuf.pattern + 0.5);
    float pa = 0.0;
    if (pat == 1) {
        vec2 q = mod(px, 22.0) - 11.0;
        pa = smoothstep(1.6, 0.6, length(q)) * 0.22;
    } else if (pat == 2) {
        pa = step(2.0, mod(px.y, 4.0)) * 0.06;
    } else if (pat == 3) {
        vec2 cell = floor(px / 36.0);
        vec2 q = fract(px / 36.0) - 0.5;
        float h = hash(cell + 7.0);
        vec2 o = vec2(hash(cell + 1.3), hash(cell + 2.9)) - 0.5;
        float r = length(q - o * 0.7);
        pa = step(0.82, h) * smoothstep(0.05, 0.0, r) * (0.4 + 0.6 * hash(cell + 5.1));
    } else if (pat == 4) {
        float lane = floor((px.x + px.y * 0.18) / 7.0);
        float h = hash(vec2(lane, 3.0));
        float run = fract(px.y / (180.0 + 220.0 * h) + h * 9.0);
        pa = step(0.93, h) * smoothstep(0.0, 0.3, run) * smoothstep(0.55, 0.3, run) * 0.16;
    } else if (pat == 5) {
        vec2 o = vec2(ubuf.spineSide > 0.5 ? res.x : 0.0, res.y);
        float r = length(px - o);
        pa = smoothstep(1.2, 0.0, abs(mod(r, 64.0) - 32.0) - 31.0) * 0.12 * smoothstep(res.y * 1.1, res.y * 0.2, r);
    }
    c = mix(c, ubuf.ink.rgb, pa);

    fragColor = vec4(c, 1.0) * ubuf.qt_Opacity;
}
