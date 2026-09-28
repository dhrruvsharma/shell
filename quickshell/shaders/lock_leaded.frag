#version 440

// Lock-in for the "Rose Window" theme (Cathedral).
//
// As progress runs 0 -> 1 the captured desktop turns to leaded glass: lead
// grows along the edges of irregular panes, each pane settles into a single
// colour (its own, a little richer), then the panes darken and fall away
// one by one into the nave behind. Run back from 1 to 0 it goes the other
// way. At progress 0 the capture passes through untouched.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float progress;
    float cell;        // pane size, px
    vec4 leadColor;    // opaque
} ubuf;

layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 own = texture(source, uv);
    float p = ubuf.progress;
    if (p <= 0.0) {
        fragColor = own * ubuf.qt_Opacity;
        return;
    }

    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 g = uv * res / ubuf.cell;
    vec2 cellId = floor(g);
    vec2 f = fract(g);
    float d1 = 8.0;
    float d2 = 8.0;
    vec2 best = vec2(0.0);
    vec2 bestPt = vec2(0.0);
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 o = vec2(float(i), float(j));
            vec2 pt = o + vec2(hash(cellId + o), hash(cellId + o + 17.0)) * 0.85 + 0.075;
            float d = length(pt - f);
            if (d < d1) {
                d2 = d1;
                d1 = d;
                best = cellId + o;
                bestPt = pt;
            } else if (d < d2) {
                d2 = d;
            }
        }
    }

    // The pane's one colour, taken at its heart and made a little richer.
    vec2 heart = (cellId + bestPt) * ubuf.cell / res;
    vec3 pane = texture(source, clamp(heart, 0.0, 1.0)).rgb;
    float l = dot(pane, vec3(0.299, 0.587, 0.114));
    pane = clamp(mix(vec3(l), pane, 1.35) * 1.08, 0.0, 1.0);
    float glassy = smoothstep(0.0, 0.35, p);
    vec3 col = mix(own.rgb, pane, glassy * 0.9);

    // Lead along the pane edges, thickening as the glass sets.
    float edge = (d2 - d1) * ubuf.cell * 0.5;
    float w = mix(0.0, 2.6, smoothstep(0.02, 0.3, p));
    col = mix(col, ubuf.leadColor.rgb, smoothstep(w, w - 1.2, edge) * step(0.01, w));

    // Each pane darkens, then falls away, in its own time.
    float t = 0.4 + 0.45 * hash(best * 1.7 + 5.0);
    col *= mix(1.0, 0.35, smoothstep(t - 0.28, t, p));
    float keep = 1.0 - smoothstep(t - 0.02, t + 0.06, p);

    fragColor = vec4(col, 1.0) * keep * ubuf.qt_Opacity;
}
