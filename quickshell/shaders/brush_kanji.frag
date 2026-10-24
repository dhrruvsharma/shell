#version 440
// Characters written with a loaded brush (Sekiro's 死, 忍殺, 回生, 危): the
// glyphs of a brush face (`source`, white on clear) given a brush's
// edges, eaten and swollen by the ink's spread; dry streaks through the
// strokes where the brush ran out; a faint bleed of ink into the paper
// round them; and written in as `progress` runs, from the top right down
// and to the left, the way a column of characters is.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    vec4 inkColor;
    float progress;  // 0..1 written
    float seed;
    float dry;       // 0..1 how dry the brush runs
    float bleed;     // 0..1 how far the ink spreads
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

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = p * 2.07 + vec2(11.3, 4.7);
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * res;
    float s = ubuf.seed * 13.7;
    float scale = res.y / 400.0;

    float a = texture(source, uv).a;
    // The coverage round about, for the spread and to find the edges.
    vec2 r1 = vec2(5.0 * scale) / res;
    vec2 r2 = vec2(14.0 * scale) / res;
    float near = 0.0;
    float far = 0.0;
    for (int i = 0; i < 8; i++) {
        float ang = float(i) * 0.7853982 + 0.39;
        vec2 d = vec2(cos(ang), sin(ang));
        near += texture(source, uv + d * r1).a;
        far += texture(source, uv + d * r2).a;
    }
    near /= 8.0;
    far /= 8.0;

    // A brush's edge: eaten in and swollen out by the ink.
    float n = fbm(px / (9.0 * scale) + s);
    float edgy = mix(a, near, 0.45) + (n - 0.5) * 0.3;
    float ink = smoothstep(0.38, 0.6, edgy);

    // Dry streaks where the brush ran out: combed along the strokes (the
    // way the edge runs, found from the glyph's slope nearby), only in a
    // band inside the edges and patchily, as bristles part.
    vec2 e = vec2(4.0 * scale) / res;
    vec2 grad = vec2(texture(source, uv + vec2(e.x, 0.0)).a - texture(source, uv - vec2(e.x, 0.0)).a,
                     texture(source, uv + vec2(0.0, e.y)).a - texture(source, uv - vec2(0.0, e.y)).a);
    float slope = length(grad);
    vec2 nrm = slope > 0.02 ? grad / slope : vec2(0.0, 1.0);
    float across = dot(px, nrm);
    float along = dot(px, vec2(-nrm.y, nrm.x));
    float comb = noise(vec2(along / (26.0 * scale), across / (1.6 * scale)) + s);
    float clump = smoothstep(0.35, 0.75, noise(px / (60.0 * scale) + s * 1.3));
    float band = smoothstep(0.05, 0.5, slope) * clump;
    ink *= 1.0 - band * ubuf.dry * (1.0 - smoothstep(0.32, 0.5, comb));

    // A faint bleed of ink round the strokes.
    float halo = smoothstep(0.02, 0.5, far) * (1.0 - ink) * 0.16 * ubuf.bleed;

    // Written in: top right first, then down and to the left, the front
    // ragged like a wet brush.
    float order = (1.0 - uv.x) * 0.38 + uv.y * 0.62 + (fbm(px / (40.0 * scale) + s * 0.7) - 0.5) * 0.22;
    float front = ubuf.progress * 1.35 - 0.2;
    float drawn = smoothstep(front + 0.03, front - 0.03, order);

    float shade = 0.84 + 0.16 * n;
    float alpha = max(ink, halo) * drawn * ubuf.inkColor.a;
    vec3 col = ubuf.inkColor.rgb * mix(1.0, shade, ink);
    fragColor = vec4(col * alpha, alpha) * ubuf.qt_Opacity;
}
