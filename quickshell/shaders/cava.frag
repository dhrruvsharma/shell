#version 440

// SPDX-License-Identifier: GPL-3.0-or-later
//
// GPU cava spectrum shader.
// Copyright (C) 2026 Squirrel Modeller (zesis-shell)
//   https://github.com/zesis-shell/zesis  (widgets/cava/cavashader/cava.frag)
//
// This shader is taken verbatim from zesis-shell and is used here with the
// author's permission under the GNU General Public License, version 3 or (at
// your option) any later version. The compiled cava.frag.qsb produced from this
// file is a derivative of it and covered by the same license. See the full
// license text in shaders/LICENSE. Distributed WITHOUT ANY WARRANTY.
//
// The CPU only uploads a 1-row, barCount-wide texture whose red channel is the
// normalized bar height (0..1); this shader does all the drawing on the GPU, so
// a full-size visualizer costs one quad instead of a per-frame CPU repaint.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    int barCount;
    int styleMode;   // 0 = bars, 1 = area
    int orientation; // 0 = bottom, 1 = top, 2 = left, 3 = right
    int flip;        // 1 = reverse bar order along the cross axis
    float gapPx;
    float lineWidthPx;
    vec4 accentColor;
} ubuf;

// 1 row, barCount texels; grayscale = normalized 0 .. 1 bar height
layout(binding = 1) uniform sampler2D dataTex;

float sampleBar(int i) {
    int n = ubuf.barCount;
    int ci = clamp(i, 0, n - 1);
    float u = (float(ci) + 0.5) / float(n);
    return texture(dataTex, vec2(u, 0.5)).r;
}

// Smooths peaks, no sharp nonsense
float catmullRom(float u) {
    int i1 = int(floor(u));
    float t = u - float(i1);
    float p0 = sampleBar(i1 - 1);
    float p1 = sampleBar(i1);
    float p2 = sampleBar(i1 + 1);
    float p3 = sampleBar(i1 + 2);

    float a = -0.5 * p0 + 1.5 * p1 - 1.5 * p2 + 0.5 * p3;
    float b = p0 - 2.5 * p1 + 2.0 * p2 - 0.5 * p3;
    float c = -0.5 * p0 + 0.5 * p2;
    float d = p1;
    return ((a * t + b) * t + c) * t + d;
}

void main() {
    int n = ubuf.barCount;
    if (n < 1) {
        fragColor = vec4(0.0);
        return;
    }

    float px = qt_TexCoord0.x * ubuf.itemWidth;
    float py = qt_TexCoord0.y * ubuf.itemHeight;

    bool vertical = (ubuf.orientation == 2 || ubuf.orientation == 3);
    float crossExtent = vertical ? ubuf.itemHeight : ubuf.itemWidth;
    float barExtent = vertical ? ubuf.itemWidth : ubuf.itemHeight;
    float cross = vertical ? py : px;
    if (ubuf.flip != 0)
        cross = crossExtent - cross;

    float alongFromEdge;
    if (ubuf.orientation == 1)
        alongFromEdge = py; // top
    else if (ubuf.orientation == 2)
        alongFromEdge = px; // left
    else if (ubuf.orientation == 3)
        alongFromEdge = ubuf.itemWidth - px; // right
    else
        alongFromEdge = ubuf.itemHeight - py; // bottom

    float alpha;

    if (ubuf.styleMode == 1) {
        // area filled curve, stroked top edge, gradient
        float step = n > 1 ? crossExtent / float(n - 1) : 0.0;
        float u = step > 0.0 ? clamp(cross / step, 0.0, float(n - 1)) : 0.0;
        // CatmullRom can clip past the defined bounds on a sharp transient.
        // We clamp the value
        float curveVal = clamp(catmullRom(u), 0.0, 1.0) * barExtent;

        float dist = alongFromEdge - curveVal;
        float aa = max(fwidth(dist), 0.0001);
        float fillMask = 1.0 - smoothstep(-aa, aa, dist);

        float gradT = clamp(alongFromEdge / max(barExtent, 0.0001), 0.0, 1.0);
        float gradAlpha = mix(0.08, 0.75, gradT);

        float halfLineWidth = ubuf.lineWidthPx * 0.5;
        float strokeMask = 1.0 - smoothstep(0.0, aa * 2.0, abs(dist) - halfLineWidth);

        alpha = max(fillMask * gradAlpha, strokeMask);
    } else {
        // bars: flat rectangles with a gap between cells
        float pitch = max(1.0, (crossExtent - ubuf.gapPx * float(n - 1)) / float(n));
        float cellPitch = pitch + ubuf.gapPx;
        float idxF = floor(cross / cellPitch);
        int idx = int(clamp(idxF, 0.0, float(n - 1)));
        float posInCell = cross - idxF * cellPitch;

        float barLen = sampleBar(idx) * barExtent;

        float aaCell = max(fwidth(posInCell), 0.0001);
        float cellMask = 1.0 - smoothstep(pitch - aaCell, pitch + aaCell, posInCell);

        float aaFill = max(fwidth(alongFromEdge), 0.0001);
        float fillMask = 1.0 - smoothstep(barLen - aaFill, barLen + aaFill, alongFromEdge);

        alpha = cellMask * fillMask;
    }

    fragColor = vec4(ubuf.accentColor.rgb * alpha, alpha) * ubuf.qt_Opacity;
}
