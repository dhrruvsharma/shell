#version 440
// The gatehouse of the "Portcullis" lock screen
// (modules/lock/themes/siege/SiegeSurface.qml), over the desktop at night:
// ashlar jambs and a lintel framing the gate, iron sconces for the torches,
// and in the opening the portcullis, a lattice of oak beams with iron
// plates bolted over the crossings and iron-shod spikes along its foot,
// running in grooves cut in the jambs. The torches and the moon light it.
// `frame` brings the stonework in from the edges, `drop` lets the
// portcullis down (0: up out of sight; 1: down), `lift` winches it back up
// by so many pixels. Clear between the beams; premultiplied. All sizes are
// design pixels times `uiScale`.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float uiScale;
    float frame;
    float drop;
    float lift;        // px
    float light;
    float reach;       // px
    vec2 torchA;       // px, the top of each sconce
    vec2 torchB;
    vec4 stoneColor;
    vec4 oakColor;
    vec4 ironColor;
    vec4 fireColor;
    vec4 moonColor;
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

// Coverage of the interval |d| < h, antialiased.
float cover(float d, float h) {
    return 1.0 - smoothstep(h - 0.75, h + 0.75, abs(d));
}

// Warm light from the torches at `px`.
float torchlight(vec2 px) {
    return exp(-pow(length(px - ubuf.torchA) / ubuf.reach, 2.0))
         + exp(-pow(length(px - ubuf.torchB) / ubuf.reach, 2.0));
}

// Ashlar: courses of dressed blocks of uneven length with mortar between,
// weathered and sooted; `sp` in the stone's own frame.
vec3 ashlar(vec2 sp, float s) {
    float rowH = 58.0 * s;
    float row = floor(sp.y / rowH);
    float bw = 168.0 * s;
    float bx = sp.x / bw + (mod(row, 2.0) * 0.5 + hash(vec2(row, 3.0)) * 0.3);
    vec2 cell = vec2(floor(bx), row);
    float fx = fract(bx);
    // Some blocks are cut in two, off-centre.
    float cut = 0.35 + 0.3 * hash(cell + 9.1);
    bool split = hash(cell + 4.2) > 0.55;
    vec2 id = cell * 2.0 + (split && fx > cut ? vec2(1.0, 0.0) : vec2(0.0));
    float left = split && fx > cut ? cut : 0.0;
    float right = split && fx <= cut ? cut : 1.0;
    vec2 f = vec2((fx - left) * bw, fract(sp.y / rowH) * rowH);
    float wBlock = (right - left) * bw;
    float edge = min(min(f.x, wBlock - f.x), min(f.y, rowH - f.y));
    vec3 col = ubuf.stoneColor.rgb * (0.62 + 0.32 * hash(id));
    // Weathering: blotches, grit, and the odd chipped arris.
    col *= 0.8 + 0.3 * noise(sp / (22.0 * s) + id) + 0.1 * noise(sp / (3.0 * s));
    col *= 1.0 - 0.14 * smoothstep(0.62, 0.8, noise(sp / (9.0 * s) + id * 3.0));
    // Each face catches light along its top, and falls into shadow below.
    col *= 1.0 + 0.12 * (1.0 - smoothstep(0.0, 6.0 * s, f.y)) - 0.22 * (1.0 - smoothstep(0.0, 7.0 * s, rowH - f.y));
    float mortar = 1.0 - smoothstep(1.2 * s, 3.4 * s, edge + (noise(sp / (4.0 * s)) - 0.5) * 2.0 * s);
    return mix(col, col * 0.22, mortar);
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 px = qt_TexCoord0 * res;
    float s = ubuf.uiScale;
    float W = res.x;
    float H = res.y;

    float J = 112.0 * s;
    float L = 104.0 * s;
    float slideX = (1.0 - ubuf.frame) * (J + 30.0 * s);
    float slideY = (1.0 - ubuf.frame) * (L + 30.0 * s);
    float warm = torchlight(px) * ubuf.light;
    vec3 fire = ubuf.fireColor.rgb;
    vec3 moon = ubuf.moonColor.rgb;

    vec3 col = vec3(0.0);
    float a = 0.0;

    // ── The portcullis ─────────────────────────────────────────────────────
    float P = 136.0 * s;
    float VW = 30.0 * s;
    float HH = 24.0 * s;
    float SPIKE = 48.0 * s;
    // The foot beam's centre line.
    float yb = mix(-SPIKE - HH - 20.0 * s, H - 14.0 * s, clamp(ubuf.drop, 0.0, 1.2)) - ubuf.lift;
    float gx = px.x - W * 0.5;
    float cx = gx - P * floor(gx / P + 0.5);
    float colId = floor(gx / P + 0.5);
    float ry = yb - px.y;
    float cy = ry - P * floor(ry / P + 0.5);
    float rowId = floor(ry / P + 0.5);
    // It runs in the grooves, a little way into each jamb.
    float inside = step(J - 16.0 * s, px.x) * step(px.x, W - J + 16.0 * s);
    float below = px.y - (yb + HH * 0.5);
    float spikeT = clamp(below / SPIKE, 0.0, 1.0);
    float halfV = VW * 0.5 * (below > 0.0 ? 1.0 - spikeT : 1.0);
    float vbeam = cover(cx, halfV) * step(px.y, yb + HH * 0.5 + SPIKE) * inside;
    float hbeam = cover(cy, HH * 0.5) * step(-HH * 0.5 - 1.0, ry) * inside;
    float grille = max(vbeam, hbeam);
    if (grille > 0.0) {
        // Oak: grain along each beam, rounded across it.
        vec3 oak = ubuf.oakColor.rgb;
        vec3 v = oak * (0.8 + 0.3 * noise(vec2(cx / (5.0 * s), px.y / (60.0 * s)) + colId * 7.1))
                     * (0.72 + 0.34 * cos(cx / max(halfV, 1.0) * 1.2));
        vec3 h = oak * (0.78 + 0.3 * noise(vec2(px.x / (60.0 * s), cy / (4.0 * s)) + rowId * 3.3))
                     * (0.72 + 0.3 * cos(cy / (HH * 0.5) * 1.2));
        // The uprights stand in front: the rails behind them fall into
        // their shadow near them, and catch the moon along their tops.
        h *= 0.5 + 0.5 * smoothstep(VW * 0.5, VW * 0.5 + 12.0 * s, abs(cx));
        h += moon * 0.12 * (1.0 - smoothstep(0.0, 4.0 * s, HH * 0.5 - cy));
        vec3 wood = mix(h, v, vbeam);
        // Iron-shod spikes.
        float shod = step(0.0, below) * vbeam;
        vec3 iron = ubuf.ironColor.rgb * (0.8 + 0.5 * cos(cx / max(halfV, 1.0) * 1.3));
        wood = mix(wood, iron, shod);
        // An iron plate bolted over each crossing.
        vec2 q = vec2(cx, cy);
        float plate = cover(q.x, 21.0 * s) * cover(q.y, 19.0 * s) * step(-HH * 0.5, ry);
        vec3 plateCol = ubuf.ironColor.rgb * (0.85 + 0.25 * noise(px / (6.0 * s)));
        plateCol *= 1.0 + 0.25 * (1.0 - smoothstep(0.0, 3.0 * s, 19.0 * s + q.y));
        vec2 bq = abs(q) - vec2(13.0 * s, 11.0 * s);
        float bolt = 1.0 - smoothstep(2.6 * s, 3.6 * s, length(bq));
        plateCol = mix(plateCol, ubuf.ironColor.rgb * 2.2, bolt * 0.7);
        wood = mix(wood, plateCol, plate * inside);
        // Light: dim moonlight, the torches warm up what's near them.
        wood *= 0.55;
        wood += wood * fire * warm * 1.6;
        col = wood;
        a = grille;
    }

    // ── The stonework ──────────────────────────────────────────────────────
    float leftJ = 1.0 - smoothstep(J - slideX - 0.75, J - slideX + 0.75, px.x);
    float rightJ = smoothstep(W - J + slideX - 0.75, W - J + slideX + 0.75, px.x);
    float lintel = 1.0 - smoothstep(L - slideY - 0.75, L - slideY + 0.75, px.y);
    float stone = max(max(leftJ, rightJ), lintel);
    if (stone > 0.0) {
        vec2 sp = lintel >= max(leftJ, rightJ) ? vec2(px.x, px.y + slideY) : vec2(px.x + (px.x < W * 0.5 ? slideX : -slideX), px.y);
        vec3 st = ashlar(sp, s);
        // The inner faces fall into shadow; the grooves are dark slots.
        float toOpenX = px.x < W * 0.5 ? (J - slideX) - px.x : px.x - (W - J + slideX);
        float toOpenY = (L - slideY) - px.y;
        float inner = lintel >= max(leftJ, rightJ) ? toOpenY : toOpenX;
        st *= 0.55 + 0.45 * smoothstep(0.0, 22.0 * s, inner);
        float groove = (1.0 - lintel) * cover(toOpenX - 9.0 * s, 5.0 * s);
        st = mix(st, vec3(0.02), groove * 0.85);
        // Moonlit and sooted, darker towards the top; the torches warm what
        // is near them.
        st *= mix(vec3(0.34), moon * 0.4, 0.5) * (0.85 + 0.15 * smoothstep(0.0, H * 0.6, px.y));
        st += st * fire * warm * 2.2;
        col = mix(col, st, stone);
        a = max(a, stone);
    }

    // ── The sconces ────────────────────────────────────────────────────────
    for (int i = 0; i < 2; i++) {
        vec2 t = i == 0 ? ubuf.torchA : ubuf.torchB;
        vec2 q = px - t;
        // A cup of iron, a band round it, and the bracket down to the wall.
        float cupHalf = mix(15.0, 8.0, clamp(q.y / (26.0 * s), 0.0, 1.0)) * s;
        float cup = cover(q.x, cupHalf) * step(0.0, q.y) * step(q.y, 26.0 * s);
        float stem = cover(q.x, 3.5 * s) * step(26.0 * s, q.y) * step(q.y, 64.0 * s);
        float foot = cover(q.x, 10.0 * s) * cover(q.y - 66.0 * s, 4.0 * s);
        float iron = max(max(cup, stem), foot) * stone;
        vec3 ic = ubuf.ironColor.rgb * (0.55 + 0.5 * (1.0 - smoothstep(0.0, cupHalf, abs(q.x + 3.0 * s))));
        ic += ic * fire * 0.9 * ubuf.light;
        col = mix(col, ic, iron);
    }

    fragColor = vec4(col * a, a) * ubuf.qt_Opacity;
}
