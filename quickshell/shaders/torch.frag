#version 440
// A torch's flame for the "Portcullis" lock screen (SiegeSurface.qml): a
// tongue of fire rising from the foot of the item's middle, swaying and
// guttering with `time` (the lock's ambient clock, still while it dozes),
// white-yellow at its heart, red at its edges, with a glow round it.
// `flare` makes it leap up (the gate opening). Premultiplied; the glow is
// added light.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float time;
    float flare;
    float seed;
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
    vec2 uv = qt_TexCoord0;
    float t = ubuf.time + ubuf.seed * 13.0;
    float flare = max(ubuf.flare, 0.0);

    // Flame space: its root at the bottom middle, y up, 1 at a full
    // flame's tip.
    float tall = res.y * 0.74 * (0.92 + 0.12 * noise(vec2(t * 2.3, ubuf.seed)) + 0.35 * flare);
    vec2 p = vec2((uv.x - 0.5) * res.x, (0.94 - uv.y) * res.y) / tall;
    float y = p.y;
    float sway = (noise(vec2(y * 2.2 - t * 1.6, t * 0.5 + ubuf.seed)) - 0.5) * 0.36 * y;
    float x = p.x - sway;
    float w = 0.2 * pow(max(y, 0.0), 0.4) * pow(max(1.0 - y, 0.0), 0.85) + 0.02;
    float d = abs(x) / w;
    d += (noise(vec2(x * 9.0, y * 6.0 - t * 5.0)) - 0.5) * 0.55;
    float inside = step(0.0, y) * step(y, 1.0);
    float body = (1.0 - smoothstep(0.55, 1.0, d)) * inside;
    float core = (1.0 - smoothstep(0.0, 0.5, d)) * inside * (1.0 - smoothstep(0.35, 0.8, y));
    vec3 col = mix(vec3(0.85, 0.18, 0.05), vec3(1.0, 0.55, 0.12), smoothstep(0.1, 0.8, 1.0 - d));
    col = mix(col, vec3(1.0, 0.93, 0.7), core);
    float alpha = body * (1.0 - smoothstep(0.55, 1.0, y) * 0.6);

    // The glow round it.
    vec2 g = (uv - vec2(0.5, 0.72)) * res / res.y;
    float glow = exp(-dot(g, g) * 16.0) * (0.22 + 0.25 * flare) * (0.9 + 0.2 * noise(vec2(t * 3.0, 1.0)));

    fragColor = vec4(col * alpha + vec3(1.0, 0.55, 0.2) * glow, alpha) * ubuf.qt_Opacity;
}
