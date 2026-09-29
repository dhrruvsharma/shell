#version 440
// One of the treasures of the churning (modules/lock/themes/devaloka/
// Ratna.qml): a gem cut as a brilliant, seen from above, in a gold collet
// with six claws. `lit` fills it with light and throws a halo round it,
// `twinkle` flashes a star on its table, `spoil` (the poison) darkens it.
// The gem fills 62% of the item; the rest is for its halo.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float lit;
    float twinkle;
    float spoil;
    vec4 gemColor;
    vec4 goldColor;
    vec4 poisonColor;
} ubuf;

const float PI = 3.14159265;
const float TAU = 6.28318531;

float inside(float d, float px) {
    return 1.0 - smoothstep(-px, px, d);
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * 2.0 / 0.62;
    float px = 2.0 / 0.62 / max(1.0, ubuf.itemWidth);
    float r = length(p);
    float a = atan(p.y, p.x);

    // The facets: an octagonal table, eight star facets round it, then
    // sixteen running out to the girdle.
    float sector = TAU / 8.0;
    float kk = floor((a + sector * 0.5) / sector);
    float local = a - kk * sector;                      // -sector/2 .. sector/2
    float k = mod(kk, 8.0);                             // the same facet either side of ±π
    float oct = r * cos(local) / cos(sector * 0.5);     // octagonal distance
    float table = inside(oct - 0.48, px);
    float star = step(oct, 0.7) * (1.0 - table);
    float outer = step(0.7, oct) * step(r, 0.84);
    float sub = star > 0.0 ? 1.0 : (local > 0.0 ? 2.0 : 3.0);
    float facet = 0.55 + 0.45 * sin(k * 2.39 + sub * 1.71 + 0.6);
    // Light from the upper left, more on the facets facing it.
    facet *= 0.8 + 0.3 * cos(a + 2.3) * step(0.48, oct);
    vec3 gem = ubuf.gemColor.rgb;
    vec3 col = gem * (0.35 + 0.75 * facet) * (0.55 + 0.55 * ubuf.lit);
    col = mix(col, gem * 1.25 + 0.12, table * 0.45);
    // The edges between facets.
    float edge = 0.0;
    edge = max(edge, 1.0 - smoothstep(0.0, px * 1.4, abs(oct - 0.48)));
    edge = max(edge, (1.0 - smoothstep(0.0, px * 1.2, abs(local) * r)) * step(0.48, oct));
    edge = max(edge, (1.0 - smoothstep(0.0, px * 1.2, abs(oct - 0.7))) * step(r, 0.84));
    col *= 1.0 - edge * 0.35;

    // The collet: a gold band round the girdle, six claws over it.
    vec3 gold = ubuf.goldColor.rgb;
    float band = step(0.84, r) * inside(r - 0.96, px);
    float light = 0.85 + 0.25 * cos(a + 2.3);
    col = mix(col, gold * light, band);
    float claw = 0.0;
    for (int i = 0; i < 6; i++) {
        float ca = float(i) * TAU / 6.0 + PI / 6.0;
        claw = max(claw, inside(length(p - vec2(cos(ca), sin(ca)) * 0.86) - 0.085, px));
    }
    col = mix(col, gold * (light + 0.2), claw);
    float alpha = max(inside(r - 0.96, px), claw);

    // The poison spoils it.
    col = mix(col, ubuf.poisonColor.rgb * (0.4 + 0.3 * facet), ubuf.spoil * 0.85 * (1.0 - band - claw));

    // A star on the table, and the halo.
    vec2 sp = p - vec2(-0.22, -0.22);
    float twinkle = ubuf.twinkle * (exp(-abs(sp.x) * 40.0) * exp(-abs(sp.y) * 6.0) + exp(-abs(sp.y) * 40.0) * exp(-abs(sp.x) * 6.0));
    col += vec3(1.0) * twinkle * 0.9 * alpha;
    float halo = ubuf.lit * exp(-max(0.0, r - 0.9) * 3.2) * step(0.9, r) * 0.55 * (1.0 - ubuf.spoil);
    col = mix(col, gem, halo * (1.0 - alpha));
    alpha = max(alpha, halo);
    fragColor = vec4(col * alpha, alpha) * ubuf.qt_Opacity;
}
