#version 440
// A single stroke of a sumi brush, left to right across the item (Sekiro's
// brushwork: the swash under a title, the stroke that strikes out a spent
// resurrection node). The brush comes down in a round, wet blot, runs on
// thinning a little and wavering, and lifts off dry: the bristles part
// into streaks towards the end and the edge is ragged all along. `reveal`
// draws it (0 nothing .. 1 the whole stroke), the bristles running a little
// ahead of one another. Premultiplied ink.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    vec4 inkColor;
    float seed;
    float reveal;   // 0..1
    float dry;      // 0 wet .. 1 a dry brush
    float weight;   // the stroke's thickness, as a share of the height
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

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 px = qt_TexCoord0 * res;
    float u = qt_TexCoord0.x;
    float s = ubuf.seed * 7.31;
    float h = res.y;

    // The line the brush follows, wavering a little.
    float centre = h * (0.5 + 0.035 * sin(u * 2.6 + s) + 0.02 * sin(u * 7.3 + s * 1.7));
    // Its half thickness: full where the brush came down, thinning as it
    // runs, narrowing as it lifts off.
    float half0 = 0.5 * h * clamp(ubuf.weight, 0.05, 1.0);
    float half1 = half0 * (1.0 - 0.22 * u) * (1.0 + 0.08 * (noise(vec2(u * 5.0, s)) - 0.5));
    half1 *= mix(1.0, 0.42, smoothstep(0.72, 1.0, u));
    // The round blot where it came down.
    float capR = half0 * 1.04;
    float cap = px.x < capR ? sqrt(max(0.0, capR * capR - (capR - px.x) * (capR - px.x))) : 1e5;
    float halfW = min(half1, cap);
    // A ragged edge.
    float dy = px.y - centre;
    float side = dy > 0.0 ? 1.0 : -1.0;
    float rag = (noise(vec2(px.x / 5.0, side * 3.1 + s)) - 0.5) * 0.16 * half0
        + (noise(vec2(px.x / 1.7, side * 5.3 + s)) - 0.5) * 0.07 * half0;
    float edge = halfW + rag;
    float aa = 0.9;
    float body = smoothstep(edge + aa, edge - aa, abs(dy));

    // The bristles: streaks along the stroke, parting where it runs dry.
    float across = dy / max(half0, 1.0);
    float bristle = noise(vec2(px.x / 42.0 + s, across * 7.5 + s * 0.3));
    float fine = noise(vec2(px.x / 11.0, across * 19.0 + s));
    float dryness = ubuf.dry * (0.1 + 0.9 * smoothstep(0.18, 1.0, u));
    float streak = smoothstep(dryness - 0.08, dryness + 0.08, bristle * 0.75 + fine * 0.25);
    // Ink pooled where the brush came down and along the edges.
    float density = mix(1.0, 0.8, u) * (0.88 + 0.12 * fine);
    density = mix(density, 1.0, smoothstep(0.55, 1.0, abs(across)) * 0.3);

    // Drawn so far: the bristles a little ahead of or behind one another.
    float lag = (noise(vec2(across * 6.0 + s, 1.7)) - 0.5) * 0.07;
    float front = ubuf.reveal * 1.1 - 0.05 + lag;
    float drawn = smoothstep(front + 0.012, front - 0.012, u);

    float a = body * streak * density * drawn * ubuf.inkColor.a;
    fragColor = vec4(ubuf.inkColor.rgb * a, a) * ubuf.qt_Opacity;
}
