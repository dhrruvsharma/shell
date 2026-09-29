#version 440
// A disc of the sky for the Observatory theme (modules/lock/themes/
// observatory/Orb.qml): the Moon in its phase, the terminator an ellipse
// across a mottled face with a little earthshine on the dark side (mode 0),
// or the Sun with the Moon drawing across it (mode 1: `cover` 0 clear .. 1
// total, when the corona comes out). The Astrolabe lock's faillock lives
// are the eclipse. The disc fills 62% of the item, leaving room for its
// glow or corona.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float mode;
    float illum;     // mode 0: lit fraction, 0..1
    float side;      // mode 0: 1 lit from the right (waxing, north), -1 left
    float cover;     // mode 1: 0 clear .. 1 total
    float glow;      // halo, 0..1
    vec4 lightColor;
    vec4 darkColor;
    vec4 coronaColor;
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
    vec2 p = (qt_TexCoord0 - 0.5) * 2.0 / 0.62;
    float r = length(p);
    float aa = max(fwidth(r), 1e-4) * 1.2;
    float disc = 1.0 - smoothstep(1.0 - aa, 1.0 + aa, r);
    vec3 col;
    float alpha;

    if (ubuf.mode < 0.5) {
        // The terminator: an ellipse whose half-width follows the phase.
        float xt = (1.0 - 2.0 * ubuf.illum) * sqrt(max(0.0, 1.0 - p.y * p.y));
        float lit = smoothstep(xt - aa * 1.5, xt + aa * 1.5, p.x * ubuf.side);
        // Maria and highlands.
        float maria = noise(p * 2.3 + 1.7) * 0.65 + noise(p * 5.1) * 0.35;
        vec3 face = ubuf.lightColor.rgb * (0.78 + 0.26 * smoothstep(0.35, 0.75, maria));
        face *= 1.0 - 0.18 * (1.0 - sqrt(max(0.0, 1.0 - r * r)));
        vec3 shade = ubuf.darkColor.rgb + ubuf.lightColor.rgb * 0.06;
        col = mix(shade, face, lit);
        alpha = disc * mix(0.85, 1.0, lit);
        float halo = ubuf.glow * ubuf.illum * 0.35 * exp(-max(0.0, r - 1.0) * 5.0) * (1.0 - disc);
        col = mix(col, ubuf.lightColor.rgb, halo / max(alpha + halo, 1e-4));
        alpha = alpha + halo * (1.0 - alpha);
    } else {
        // The Sun, darker at its limb.
        vec3 sun = ubuf.lightColor.rgb * (1.0 - 0.4 * (1.0 - sqrt(max(0.0, 1.0 - r * r))));
        // The Moon comes in from the upper right.
        vec2 m = vec2(0.72, -0.69) * (1.0 - ubuf.cover) * 2.1;
        float rm = length(p - m);
        float moon = 1.0 - smoothstep(1.02 - aa, 1.02 + aa, rm);
        col = mix(sun, ubuf.darkColor.rgb, moon);
        alpha = disc;
        float total = smoothstep(0.9, 1.0, ubuf.cover);
        // Glare round the uncovered Sun; the corona's streamers at totality.
        float glare = ubuf.glow * (1.0 - total) * 0.3 * exp(-max(0.0, r - 1.0) * 6.0) * (1.0 - disc);
        float ang = atan(p.y, p.x);
        float streak = 0.55 + 0.45 * noise(vec2(ang * 3.2, 0.5)) + 0.25 * noise(vec2(ang * 9.0, 3.1));
        float corona = total * exp(-max(0.0, r - 1.0) * (3.2 / streak)) * (1.0 - disc) * 0.9;
        vec3 outer = mix(ubuf.lightColor.rgb, ubuf.coronaColor.rgb, total);
        float o = max(glare, corona);
        col = mix(col, outer, o / max(alpha + o, 1e-4));
        alpha = alpha + o * (1.0 - alpha);
        // At totality, a thin bright ring where the Sun's edge peeks out.
        float ring = total * smoothstep(aa * 3.0, 0.0, abs(rm - 1.02)) * 0.8;
        col = mix(col, ubuf.coronaColor.rgb, ring);
        alpha = max(alpha, ring);
    }

    fragColor = vec4(col * alpha, alpha) * ubuf.qt_Opacity;
}
