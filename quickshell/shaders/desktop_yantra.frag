#version 440
// Devaloka's seal (modules/desktoptheme/DevalokaLayer.qml): a yantra drawn
// in gold, from the bindu out: the dot at the centre, a downward triangle
// round it, the six-pointed star of two triangles (the shatkona), an
// eight-petalled lotus, a sixteen-petalled lotus, three circles, and the
// bhupura, the square enclosure of three lines with a gate at each quarter.
// The lotuses are washed with the pigment and the bindu is kumkum; `halo`
// lays a dark ground under it so the lines read on anything. Drawn small,
// it keeps to the lines that still read: two circles, two lines of the
// bhupura, one ring of petals. As the theme switches on (`boot`) it is
// drawn outwards like a rangoli, a bright edge running ahead.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float boot;        // 0..1
    float lineScale;   // screen pixels per layer pixel, inverted (>= 1 in previews)
    float strength;    // overall presence, 0..1
    float size;        // the bhupura's half-width, pixels
    float halo;        // the dark ground under it, 0..1
    vec2 centre;       // pixels
    vec4 goldColor;
    vec4 pigmentColor;
    vec4 groundColor;
    vec4 bindColor;
} ubuf;

const float PI = 3.14159265;
const float TAU = 6.28318531;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float sdBox(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// An equilateral triangle of circumradius r round its centroid, apex up
// (after Inigo Quilez).
float sdTri(vec2 p, float r) {
    const float k = sqrt(3.0);
    float s = r * k * 0.5;   // half the side
    p.x = abs(p.x) - s;
    p.y = p.y + s / k;
    if (p.x + k * p.y > 0.0)
        p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
    p.x -= clamp(p.x, -2.0 * s, 0.0);
    return -length(p) * sign(p.y);
}

// The bhupura's outline: a square of half-width 1 with a T-shaped gate
// standing out from the middle of each side.
float sdBhupura(vec2 p) {
    vec2 q = abs(p);
    if (q.x > q.y)
        q = q.yx;
    // Each piece overlaps the one inside it, so the union has no seams.
    float d = sdBox(q, vec2(1.0));
    d = min(d, sdBox(q - vec2(0.0, 1.0), vec2(0.17, 0.1)));
    d = min(d, sdBox(q - vec2(0.0, 1.11), vec2(0.28, 0.05)));
    return d;
}

// A ring of `n` pointed petals standing on the circle r0, `h` tall: the
// signed distance (roughly, in yantra units) to the nearest petal's
// outline, each side an arc meeting its neighbour's at the tip.
float sdPetals(vec2 p, float r0, float h, float n, float turn) {
    float r = length(p);
    float a = atan(p.x, p.y) + turn;
    float slot = TAU / n;
    float local = (fract(a / slot + 0.5) - 0.5) * slot;   // angle from the petal's axis
    float x = abs(local) * max(r, 1e-4);                   // across, as arc length
    float y = r - r0;                                      // up the petal
    float w = PI * r0 / n;                                 // half-width at the base
    float rc = (w * w + h * h) / (2.0 * w);
    float edge = sqrt(max(0.0, rc * rc - y * y)) - (rc - w);
    float d = x - edge;
    d = max(d, -y);
    d = max(d, y - h);
    return d;
}

void main() {
    vec2 px = qt_TexCoord0 * vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 p = (px - ubuf.centre) / ubuf.size * vec2(1.0, -1.0);
    float r = length(p);
    float unit = 1.0 / ubuf.size;                    // one pixel in yantra units
    float lw = 1.25 * max(1.0, ubuf.lineScale) * unit;
    float aa = unit * max(1.0, ubuf.lineScale);
    // Full detail only when it's drawn large enough to hold it.
    float fine = step(110.0, ubuf.size / max(1.0, ubuf.lineScale));
    float bhuStep = mix(0.065, 0.035, fine);
    float ringStep = mix(0.05, 0.03, fine);

    // Drawn outwards as it switches on.
    float reach = ubuf.boot * 1.75;
    float shown = 1.0 - smoothstep(reach - 0.12, reach, r);
    float front = exp(-abs(r - reach + 0.04) * 22.0) * step(ubuf.boot, 0.999) * step(0.001, ubuf.boot);

    // Distances to every line.
    float bhu = sdBhupura(p);
    float lines = 0.0;
    float wash = 0.0;       // pigment fill
    float gild = 0.0;       // gold fill

    // The bhupura: three lines (two, small), the band between them washed.
    for (int i = 0; i < 3; i++)
        lines = max(lines, (1.0 - smoothstep(lw * 0.5, lw * 0.5 + aa, abs(bhu + float(i) * bhuStep))) * step(float(i), 1.0 + fine));
    wash = max(wash, (1.0 - smoothstep(-aa, aa, bhu)) * smoothstep(-bhuStep * (1.0 + fine) - aa, -bhuStep * (1.0 + fine) + aa, bhu) * 0.35);
    // A dot in each gate.
    vec2 q = abs(p);
    if (q.x > q.y)
        q = q.yx;
    float dotR = max(0.02, 1.6 * unit);
    gild = max(gild, 1.0 - smoothstep(dotR, dotR + aa, length(q - vec2(0.0, 1.075))));

    // Three circles (two, small).
    for (int i = 0; i < 3; i++)
        lines = max(lines, (1.0 - smoothstep(lw * 0.5, lw * 0.5 + aa, abs(r - 0.86 + float(i) * ringStep))) * step(float(i), 1.0 + fine));

    // The sixteen-petalled lotus, a second ring of petals behind it.
    float p16 = sdPetals(p, 0.56, 0.21, 16.0, 0.0);
    float p16b = sdPetals(p, 0.56, 0.16, 16.0, PI / 16.0);
    lines = max(lines, 1.0 - smoothstep(lw * 0.5, lw * 0.5 + aa, abs(p16)));
    lines = max(lines, (1.0 - smoothstep(lw * 0.4, lw * 0.4 + aa, abs(p16b))) * step(0.0, p16) * 0.7 * fine);
    wash = max(wash, (1.0 - smoothstep(-aa, aa, p16)) * 0.55);
    wash = max(wash, (1.0 - smoothstep(-aa, aa, p16b)) * step(0.0, p16) * 0.3 * fine);
    lines = max(lines, 1.0 - smoothstep(lw * 0.5, lw * 0.5 + aa, abs(r - 0.56)));

    // The eight-petalled lotus.
    float p8 = sdPetals(p, 0.36, 0.19, 8.0, 0.0);
    lines = max(lines, 1.0 - smoothstep(lw * 0.5, lw * 0.5 + aa, abs(p8)));
    wash = max(wash, (1.0 - smoothstep(-aa, aa, p8)) * 0.75);
    lines = max(lines, 1.0 - smoothstep(lw * 0.5, lw * 0.5 + aa, abs(r - 0.36)));
    lines = max(lines, (1.0 - smoothstep(lw * 0.5, lw * 0.5 + aa, abs(r - 0.34))) * fine);

    // The shatkona, and the downward triangle inside it.
    float up = sdTri(p, 0.335);
    float down = sdTri(vec2(p.x, -p.y), 0.335);
    lines = max(lines, 1.0 - smoothstep(lw * 0.5, lw * 0.5 + aa, abs(up)));
    lines = max(lines, 1.0 - smoothstep(lw * 0.5, lw * 0.5 + aa, abs(down)));
    gild = max(gild, (1.0 - smoothstep(-aa, aa, max(up, down))) * 0.22);
    float inner = sdTri(vec2(p.x, -p.y), 0.13);
    lines = max(lines, 1.0 - smoothstep(lw * 0.5, lw * 0.5 + aa, abs(inner)));
    gild = max(gild, (1.0 - smoothstep(-aa, aa, inner)) * 0.3);

    // The bindu.
    float binduR = max(0.024, 2.2 * unit);
    float bindu = 1.0 - smoothstep(binduR, binduR + aa, r);

    // A soft glow off the lines, so they read on a bright wallpaper.
    float glowD = min(min(abs(bhu), abs(r - 0.86)), min(abs(p16), abs(p8)));
    glowD = min(glowD, min(abs(up), abs(down)));
    float glow = exp(-glowD / (0.012 + unit * 3.0)) * 0.35;

    vec3 gold = ubuf.goldColor.rgb;
    vec3 pigment = ubuf.pigmentColor.rgb;
    // The halo under it: darkest in the middle.
    float halo = (exp(-pow(r / 1.05, 2.0) * 1.6) * 0.42 + (1.0 - smoothstep(-0.02, 0.02, bhu)) * 0.12) * ubuf.halo;
    vec4 col = vec4(ubuf.groundColor.rgb, 1.0) * halo;
    col = mix(col, vec4(pigment * 0.9, 1.0), wash * 0.2);
    col = mix(col, vec4(gold, 1.0), gild * 0.45);
    col = mix(col, vec4(gold * 1.05, 1.0), glow * 0.35);
    col = mix(col, vec4(gold * 1.12, 1.0), lines * 0.85);
    col = mix(col, vec4(ubuf.bindColor.rgb, 1.0), bindu);
    col *= shown;
    col = mix(col, vec4(mix(gold, vec3(1.0, 0.95, 0.8), 0.5), 1.0), front * 0.5 * (1.0 - smoothstep(1.25, 1.7, r)));

    fragColor = col * ubuf.strength * ubuf.qt_Opacity;
}
