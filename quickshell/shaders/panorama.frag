#version 440
// SPDX-License-Identifier: MIT
//
// Derived from Panaroma Workspace Switcher's src/panorama.frag
//   https://github.com/hawike22405/Panaroma-Workspace-Switcher
// Copyright (c) 2026 hawike22405
// Modifications copyright (C) 2026 dhrruvsharma: the backdrop is the
// wallpaper, where it lies on screen, cards without a picture show the wallpaper, a card can be lit
// for the overview, each card shows once (no repeats around the ring), soft
// contact shadows.
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to permit
// persons to whom the Software is furnished to do so, subject to the
// following conditions: The above copyright notice and this permission
// notice shall be included in all copies or substantial portions of the
// Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
// NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
// DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
// OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
// USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// The camera sits inside a ring of workspace cards. Every pixel casts a ray,
// hits the (bendable) strip analytically and samples the card under it.
// kappa = 0 is a flat, pixel-exact picture of one card, so the effect starts
// and ends seamlessly over the real desktop. modules/panorama/Projection.js
// does the same sums forwards (labels, hit tests); keep the two in step.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    vec4 accent;      // a lit card's outline
    vec4 bgRect;      // wallpaper cover-fit: uv' = bgRect.xy + uv * bgRect.zw
    float scroll;     // camera position along the strip, in px
    float kappa;      // strip curvature (1 / radius); 0 = flat
    float dist;       // distance to the strip's front point
    float zoom;       // 1 = card is 1:1, <1 pulls the camera back
    float cardW;
    float cardH;
    float pitch;      // card spacing along the strip
    float count;      // number of cards in the ring
    float radius;     // card corner radius
    float depthFade;
    float blankMask;  // bit i set: card i has no picture, it shows the wallpaper
    float lit;        // ring index of the lit card (overview), -1 for none
    float glow;       // 0..1, how strongly it's lit
    float veil;       // 0..1, how much the backdrop is darkened
} ubuf;

layout(binding = 1) uniform sampler2D src0;
layout(binding = 2) uniform sampler2D src1;
layout(binding = 3) uniform sampler2D src2;
layout(binding = 4) uniform sampler2D src3;
layout(binding = 5) uniform sampler2D src4;
layout(binding = 6) uniform sampler2D src5;
layout(binding = 7) uniform sampler2D src6;
layout(binding = 8) uniform sampler2D src7;
layout(binding = 9) uniform sampler2D src8;
layout(binding = 10) uniform sampler2D src9;
layout(binding = 11) uniform sampler2D wall;

vec4 pick(int i, vec2 uv) {
    if (i == 0) return texture(src0, uv);
    if (i == 1) return texture(src1, uv);
    if (i == 2) return texture(src2, uv);
    if (i == 3) return texture(src3, uv);
    if (i == 4) return texture(src4, uv);
    if (i == 5) return texture(src5, uv);
    if (i == 6) return texture(src6, uv);
    if (i == 7) return texture(src7, uv);
    if (i == 8) return texture(src8, uv);
    return texture(src9, uv);
}

float bitOf(float mask, float i) {
    return mod(floor(mask / exp2(i) + 0.001), 2.0);
}

vec3 wallAt(vec2 uv) {
    return texture(wall, ubuf.bgRect.xy + clamp(uv, 0.0, 1.0) * ubuf.bgRect.zw).rgb;
}

void main() {
    vec2 px = qt_TexCoord0 * ubuf.resolution - 0.5 * ubuf.resolution;
    float D = max(ubuf.dist, 0.001);
    float f = max(D * ubuf.zoom, 0.001);
    float dx = px.x / f;
    float dy = px.y / f;
    float k = ubuf.kappa;

    // Ray (dx, 1) from the camera vs. the concave circle of radius 1/k whose
    // nearest point is at depth D. Numerically stable down to k = 0.
    float a = k * (1.0 + dx * dx);
    float b = 2.0 * (1.0 - k * D);
    float c = -D * (2.0 - k * D);
    float disc = max(b * b - 4.0 * a * c, 0.0);
    float t = -2.0 * c / max(b + sqrt(disc), 0.000001);

    float Px = t * dx;
    float Py = t * dy;

    float ang = 0.0;
    float s = Px;
    if (k > 0.00001) {
        ang = atan(k * Px, 1.0 + k * (t - D));
        s = ang / k;
    }

    float pitch = max(ubuf.pitch, 1.0);
    float n = clamp(ubuf.count, 1.0, 10.0);
    float us = s + ubuf.scroll;
    float idx = floor(us / pitch + 0.5);
    float lx = us - idx * pitch;

    // Each card once: only the n nearest the camera's heading are drawn,
    // the outermost faded in and out (with few cards the ring stays open,
    // and a card leaving one side comes back on the other).
    float rel = idx - ubuf.scroll / pitch;
    float shown = clamp((n * 0.5 - abs(rel)) * 2.5 + 0.5, 0.0, 1.0);

    vec2 hs = vec2(ubuf.cardW, ubuf.cardH) * 0.5 + vec2(1.0);
    float r = min(ubuf.radius, min(hs.x, hs.y));
    vec2 qd = abs(vec2(lx, Py)) - hs + vec2(r);
    float d = length(max(qd, vec2(0.0))) + min(max(qd.x, qd.y), 0.0) - r;
    float aa = max(t / f, 0.5);       // strip px per screen px here
    float cover = (1.0 - smoothstep(-aa, aa, d)) * shown;

    vec2 uv = clamp(vec2(lx / ubuf.cardW + 0.5, Py / ubuf.cardH + 0.5), 0.0, 1.0);
    float slotF = mod(idx, n);
    int slot = int(floor(slotF + 0.5));
    vec3 col;
    if (bitOf(ubuf.blankMask, slotF) > 0.5) {
        col = wallAt(uv);
    } else {
        vec4 tex = pick(slot, uv);
        col = mix(wallAt(uv), tex.rgb, tex.a);
    }

    // The backdrop: the wallpaper itself, where it lies on screen.
    vec3 back = wallAt(qt_TexCoord0);

    // Cards resting on it cast a soft shadow.
    float sh = shown * exp(-max(d, 0.0) / (34.0 * aa)) * (1.0 - cover);
    back *= 1.0 - 0.45 * sh * ubuf.veil;

    float fade = ubuf.depthFade * pow(clamp((1.0 - cos(ang)) * 0.5, 0.0, 1.0), 1.25);
    col = mix(col, back, fade);

    vec3 outc = mix(back, col, cover);

    // The lit card: an outline just outside its edge and a little glow.
    float isLit = (1.0 - step(0.5, abs(idx - ubuf.lit))) * shown * ubuf.glow;
    if (isLit > 0.0) {
        float w = 2.5 * aa;
        float line = 1.0 - smoothstep(w - aa, w + aa, abs(d - w));
        float halo = exp(-max(d, 0.0) / (22.0 * aa)) * step(0.0, d) * 0.45;
        outc = mix(outc, ubuf.accent.rgb, clamp(line + halo * (1.0 - line), 0.0, 1.0) * isLit);
    }

    fragColor = vec4(outc, 1.0) * ubuf.qt_Opacity;
}
