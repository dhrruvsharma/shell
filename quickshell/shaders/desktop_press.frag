#version 440
// Broadsheet: the wallpaper printed in the morning paper. Four inks (cyan,
// magenta, yellow, black) laid down as halftone dots, each on its own
// screen angle so they fall into rosettes, soaked into grey-cream newsprint
// with its fibres and a little ink spread; the fold across the middle of the
// page. `press` (0..1) runs the press: the dots grow from blank paper. The
// result is opaque. Nothing depends on time.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float press;       // 0..1
    float cell;        // halftone cell, px
    float fold;        // 0..1 the crease across the middle
    vec4 paperColor;   // opaque
} ubuf;

layout(binding = 1) uniform sampler2D source;

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

vec4 cmyk(vec3 c) {
    float k = 1.0 - max(max(c.r, c.g), c.b);
    float d = max(1.0 - k, 0.0001);
    return vec4((1.0 - c.r - k) / d, (1.0 - c.g - k) / d, (1.0 - c.b - k) / d, k);
}

// Coverage (0..1) of one ink at `px` on a screen turned by `a`, for an
// ink amount 0..1: a round spot that grows into a checkerboard at 50% and
// into white holes beyond, so the inked area follows the amount across the
// whole range.
float screen(vec2 px, float a, float amount) {
    mat2 r = mat2(cos(a), -sin(a), sin(a), cos(a));
    vec2 q = r * px * (6.2831853 / ubuf.cell);
    float spot = 0.5 + 0.25 * (cos(q.x) + cos(q.y));
    // A little dot gain and wobble, like ink soaking into cheap paper.
    float t = 1.0 - clamp(amount * ubuf.press * (1.04 + 0.08 * (noise(px * 0.21) - 0.5)), 0.0, 1.0);
    float w = max(fwidth(spot) * 0.75, 0.001);
    return smoothstep(t - w, t + w, spot) * step(0.015, amount);
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * res;

    // Newsprint: grey-cream, uneven, with short fibres.
    vec3 paper = ubuf.paperColor.rgb;
    paper *= 0.97 + 0.03 * noise(px / 60.0) + 0.02 * (noise(px / 7.0) - 0.5);
    float fibre = smoothstep(0.04, 0.0, abs(noise(vec2(px.x / 90.0, px.y / 3.0)) - 0.5)) * noise(px / 20.0);
    paper *= 1.0 - fibre * 0.05;

    // The inks, laid down one after another (each absorbs what it can), on
    // the classic screen angles: cyan 15, magenta 75, yellow 0, black 45.
    vec4 ink = cmyk(texture(source, uv).rgb);
    float c = screen(px, 0.2618, ink.x);
    float m = screen(px, 1.309, ink.y);
    float y = screen(px, 0.0, ink.z);
    float k = screen(px, 0.7854, ink.w);
    vec3 col = paper;
    col *= mix(vec3(1.0), vec3(0.1, 0.66, 0.9), c * 0.92);
    col *= mix(vec3(1.0), vec3(0.93, 0.18, 0.55), m * 0.9);
    col *= mix(vec3(1.0), vec3(1.0, 0.92, 0.18), y * 0.9);
    col *= mix(vec3(1.0), vec3(0.12, 0.11, 0.1), k * 0.94);

    // The fold: a soft valley across the middle of the page.
    float dy = (px.y - res.y * 0.5) / res.y;
    col *= 1.0 - ubuf.fold * (exp(-abs(dy) * 180.0) * 0.1 - exp(-abs(dy - 0.006) * 260.0) * 0.04);

    fragColor = vec4(col, 1.0) * ubuf.qt_Opacity;
}
