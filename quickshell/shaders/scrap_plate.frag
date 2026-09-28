#version 440
// A salvaged steel plate for the Wasteland theme: brushed steel gone dull,
// scratched, with rust blooming in from the edges and around the rivet
// holes, and a worn highlight along the top edge. `seed` makes each plate
// its own. Premultiplied; `fill` sets the plate's opacity. Static.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float seed;
    float rust;        // 0..1 how far the rust has got
    float fill;        // 0..1 opacity of the plate
    float inset;       // rivets' distance from the corners, px
    vec4 steelColor;   // opaque
    vec4 rustColor;    // opaque
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

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 px = qt_TexCoord0 * res;
    vec2 sd = vec2(ubuf.seed * 13.7, ubuf.seed * 7.3);

    // Brushed steel: fine streaks along the plate.
    float brush = noise(vec2(px.x / 90.0, px.y / 1.6) + sd) * 0.6 + noise(vec2(px.x / 30.0, px.y / 0.9) + sd) * 0.4;
    vec3 steel = ubuf.steelColor.rgb * (0.86 + 0.24 * brush);
    // Mottled, dull patches.
    steel *= 0.9 + 0.18 * fbm(px / 40.0 + sd);

    // Scratches: a few thin, straight, pale lines.
    float scratch = 0.0;
    for (int i = 0; i < 5; i++) {
        float fi = float(i) + ubuf.seed * 5.0;
        vec2 o = vec2(hash(vec2(fi, 1.0)), hash(vec2(fi, 2.0))) * res;
        float a = hash(vec2(fi, 3.0)) * 3.1416;
        vec2 dir = vec2(cos(a), sin(a));
        vec2 d = px - o;
        float len = 30.0 + 90.0 * hash(vec2(fi, 4.0));
        float along = dot(d, dir);
        float dist = abs(dot(d, vec2(-dir.y, dir.x)));
        scratch = max(scratch, smoothstep(0.9, 0.0, dist) * step(abs(along), len) * (0.4 + 0.6 * noise(vec2(along / 6.0, fi))));
    }
    steel = mix(steel, vec3(0.78, 0.76, 0.7), scratch * 0.35);

    // Rust from the edges and round the rivets.
    float edge = min(min(px.x, res.x - px.x), min(px.y, res.y - px.y));
    float ins = ubuf.inset;
    vec2 cr = min(px, res - px) - ins;
    float rivet = length(cr);
    float r = fbm(px / 14.0 + sd * 2.0);
    float amount = ubuf.rust * (smoothstep(26.0, 0.0, edge + (r - 0.5) * 30.0) + smoothstep(14.0, 2.0, rivet) * 0.8);
    float rustMask = smoothstep(0.35, 0.55, amount * (0.6 + r));
    vec3 rust = ubuf.rustColor.rgb * (0.6 + 0.7 * noise(px / 2.5 + sd)) * (0.8 + 0.4 * r);
    vec3 colr = mix(steel, rust, rustMask * 0.85);

    // Worn highlight on the top edge, shadow on the bottom.
    colr *= 1.0 + smoothstep(2.0, 0.0, px.y) * 0.35 - smoothstep(3.0, 0.0, res.y - px.y) * 0.35;
    colr *= 1.0 - smoothstep(2.0, 0.0, min(px.x, res.x - px.x)) * 0.2;

    fragColor = vec4(colr, 1.0) * ubuf.fill * ubuf.qt_Opacity;
}
