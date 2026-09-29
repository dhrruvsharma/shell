#version 440
// The sun wheel of Konark (modules/lock/themes/devaloka/KonarkWheel.qml):
// one of the twenty-four carved wheels of Surya's chariot at the Sun
// Temple, each a sundial, here cast in temple gold. Eight broad spokes part
// the day into its eight praharas of three hours, eight slender ones halve
// them, and sixty beads run between each pair of broad spokes, three
// minutes a bead. Noon is at the top and the hours run clockwise, sunrise
// on the left and sunset on the right. The hand is the shadow's line, with
// the Sun at its tip; the prahar it stands in is lit, and its beads light
// up as its minutes pass. The broad spokes' medallions are enamelled in the
// pigment.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float hour;        // 0..24, local time
    float glow;        // light in the current prahar, 0..1
    float inset;       // item size / wheel size (room for the glow)
    vec4 goldColor;
    vec4 pigmentColor;
    vec4 groundColor;
    vec4 lightColor;
} ubuf;

const float PI = 3.14159265;
const float TAU = 6.28318531;

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

// An engraved line `w` wide along the zero of `d`.
float ring(float d, float w, float px) {
    return 1.0 - smoothstep(w * 0.5, w * 0.5 + px, abs(d));
}

// Inside a shape whose signed distance is `d` (antialiased).
float inside(float d, float px) {
    return 1.0 - smoothstep(-px, px, d);
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    float R = 0.5 * min(res.x, res.y) / max(1.0, ubuf.inset);
    // Wheel units, y up; the rim's outer edge at 1.
    vec2 p = (qt_TexCoord0 * res - res * 0.5) / R * vec2(1.0, -1.0);
    float px = 1.0 / R;
    float r = length(p);
    float ang = mod(atan(p.x, p.y), TAU);      // clockwise from the top
    float lw = max(1.0, R / 190.0) * px;       // engraving width
    float hourNow = mod(ubuf.hour, 24.0);

    // Cast gold, lit from the upper left, with a little grain.
    vec2 dirL = normalize(vec2(-0.6, 0.8));
    float light = 0.84 + 0.3 * dot(p / max(r, 1e-4), dirL) * smoothstep(0.0, 0.3, r);
    float grain = noise(vec2(r * 260.0, ang * 24.0)) * 0.05 + noise(p * 46.0) * 0.06;
    vec3 gold = ubuf.goldColor.rgb;
    vec3 metal = gold * (0.8 + grain) * light;
    vec3 dark = mix(ubuf.groundColor.rgb, gold * 0.12, 0.25);

    // The hour this point of the wheel stands for, and the prahar lit now.
    float hAt = mod(12.0 + ang / TAU * 24.0, 24.0);
    float prStart = floor(hourNow / 3.0) * 3.0;
    float inPrahar = step(prStart, hAt) * step(hAt, prStart + 3.0);

    // ── Spokes ──────────────────────────────────────────────────────────────
    float sector = TAU / 8.0;
    float aMaj = (fract(ang / sector + 0.5) - 0.5) * sector;   // to the nearest broad spoke
    float aMin = (fract(ang / sector) - 0.5) * sector;         // to the nearest slender one
    float dMaj = abs(sin(aMaj)) * r;
    float dMin = abs(sin(aMin)) * r;
    float along = clamp((r - 0.25) / 0.61, 0.0, 1.0);
    float wMaj = mix(0.072, 0.052, along);
    float wMin = 0.022;
    float spokeBand = step(0.2, r) * step(r, 0.87);
    float majIn = inside(dMaj - wMaj, px) * spokeBand * step(0.0, cos(aMaj));
    float minIn = inside(dMin - wMin, px) * spokeBand * step(0.0, cos(aMin));
    // A medallion on each broad spoke, a bead on each slender one.
    float angMaj = ang - aMaj;
    float angMin = ang - aMin;
    vec2 cMaj = vec2(sin(angMaj), cos(angMaj)) * 0.56;
    vec2 cMin = vec2(sin(angMin), cos(angMin)) * 0.56;
    float dMed = length(p - cMaj);
    float dBead = length(p - cMin);
    float medIn = inside(dMed - 0.105, px);
    float beadIn = inside(dBead - 0.034, px);

    // ── The rim, the hub ────────────────────────────────────────────────────
    float rimIn = step(0.855, r) * inside(r - 1.0, px);
    float hubIn = inside(r - 0.25, px);
    float solid = max(max(max(majIn, minIn), max(medIn, beadIn)), max(rimIn, hubIn));

    vec3 col = dark;
    float alpha = inside(r - 1.0, px);
    // Through the openings, the dark behind the wheel, lit warm in the
    // prahar of the hour.
    float opening = alpha * (1.0 - solid);
    float warm = inPrahar * ubuf.glow * smoothstep(0.22, 0.5, r) * (1.0 - smoothstep(0.62, 0.86, r) * 0.35);
    col = mix(col, ubuf.lightColor.rgb * 0.7 + dark * 0.4, warm * 0.72);

    // Spokes: bevelled along their edges, an incised line down the middle
    // of the broad ones.
    vec3 spokeCol = metal * (0.96 + 0.08 * sign(aMaj) * -1.0);
    spokeCol *= 1.0 - ring(dMaj - wMaj + lw * 1.5, lw, px) * 0.35;
    spokeCol *= 1.0 - ring(dMaj, lw * 0.8, px) * 0.3 * step(0.3, r) * step(dMed, 2.0) * step(0.125, dMed);
    col = mix(col, spokeCol, majIn);
    col = mix(col, metal * 0.94, minIn * (1.0 - majIn));
    col *= 1.0 - ring(dMaj - wMaj, lw, px) * 0.55 * spokeBand * step(0.0, cos(aMaj)) * (1.0 - step(0.87, r));
    col *= 1.0 - ring(dMin - wMin, lw, px) * 0.45 * spokeBand * step(0.0, cos(aMin)) * (1.0 - majIn) * (1.0 - step(0.87, r));

    // Medallions: a gold ring round an enamelled disc with an eight-petalled
    // flower in gold.
    if (medIn > 0.0) {
        vec2 q = p - cMaj;
        float qa = atan(q.x, q.y) - angMaj;
        float qr = length(q);
        float petal = 0.03 + 0.042 * pow(abs(cos(qa * 4.0)), 0.7);
        vec3 enamel = ubuf.pigmentColor.rgb * (0.62 + 0.18 * noise(q * 90.0)) * (0.9 + 0.2 * (light - 0.84));
        vec3 m = metal * 1.04;
        m = mix(m, enamel, inside(qr - 0.078, px));
        m = mix(m, metal * 1.1, inside(qr - petal, px));
        m *= 1.0 - ring(qr - petal, lw * 0.8, px) * 0.4 * step(0.02, qr);
        m = mix(m, metal * 0.55, inside(qr - 0.016, px));
        m *= 1.0 - ring(qr - 0.078, lw, px) * 0.5;
        col = mix(col, m, medIn);
        col *= 1.0 - ring(dMed - 0.105, lw, px) * 0.6;
    }
    col = mix(col, metal * 1.08, beadIn * (1.0 - medIn));
    col *= 1.0 - ring(dBead - 0.034, lw, px) * 0.5 * (1.0 - medIn);

    // The felloe: a band of beads, three minutes each, sixty to a prahar;
    // a running vine; a moulded outer edge.
    if (rimIn > 0.0) {
        vec3 m = metal;
        // Beads.
        float bead = floor(hAt * 20.0);
        float hb = (bead + 0.5) / 20.0;
        float bAng = mod((hb - 12.0) / 24.0 * TAU, TAU);
        vec2 bc = vec2(sin(bAng), cos(bAng)) * 0.8775;
        float bSize = min(0.0155, TAU * 0.8775 / 480.0 * 0.42);
        float bd = length(p - bc);
        float onBead = inside(bd - bSize, px * 0.7) * step(0.86, r) * step(r, 0.895);
        float litBead = step(prStart, hb) * step(hb, hourNow) * onBead;
        vec3 bm = metal * (1.08 + 0.3 * (0.5 - clamp(bd / max(bSize, 1e-4), 0.0, 1.0)));
        m = mix(metal * 0.62, bm, onBead);
        m = mix(m, ubuf.lightColor.rgb * 1.15, litBead * (0.55 + 0.45 * ubuf.glow));
        // The vine.
        float band = step(0.9, r) * step(r, 0.955);
        float vine = ring(r - (0.9275 + 0.011 * sin(ang * 72.0)), lw * 1.2, px);
        float leaf = inside(length(vec2((fract(ang * 72.0 / TAU * 0.5 + 0.25) - 0.5) * TAU * 0.9275 / 36.0, r - 0.9275)) - 0.009, px);
        m = mix(m, metal * 0.92, band);
        m *= 1.0 - (vine * 0.45 + leaf * 0.25) * band;
        // The moulding.
        float mould = step(0.955, r);
        m = mix(m, metal * (1.1 + 0.25 * (light - 0.84)), mould);
        m *= 1.0 - ring(r - 0.978, lw * 0.8, px) * 0.35;
        col = mix(col, m, rimIn);
        col *= 1.0 - ring(r - 0.9, lw, px) * 0.5;
        col *= 1.0 - ring(r - 0.955, lw, px) * 0.5;
    }
    col *= 1.0 - ring(r - 0.855, lw * 1.2, px) * 0.6;

    // The hub: a beaded ring round a sixteen-petalled lotus and the axle.
    if (hubIn > 0.0) {
        vec3 m = metal * 1.02;
        float hubBeads = inside(length(vec2((fract(ang / TAU * 32.0) - 0.5) * TAU * 0.232 / 32.0, r - 0.232)) - 0.011, px);
        m = mix(m, metal * 0.7, step(0.212, r));
        m = mix(m, metal * 1.12, hubBeads * step(0.212, r));
        float pa = (fract(ang / TAU * 16.0) - 0.5) * 2.0;
        float petalR = 0.198 - 0.1 * pow(abs(pa), 1.35);
        float inPetal = inside(r - petalR, px) * step(0.07, r);
        m = mix(m, metal * 0.66, step(r, 0.212) * (1.0 - inPetal) * step(0.07, r));
        m = mix(m, metal * (1.02 + 0.14 * (1.0 - abs(pa))), inPetal);
        m *= 1.0 - ring(r - petalR, lw, px) * 0.55 * step(0.07, r) * step(r, 0.212);
        m *= 1.0 - ring(pa * r * 0.2, lw * 0.7, px) * 0.25 * inPetal * step(0.09, r);
        m = mix(m, metal * 1.14, inside(r - 0.07, px));
        m *= 1.0 - ring(r - 0.07, lw, px) * 0.5;
        m = mix(m, metal * 0.5, inside(r - 0.026, px));
        col = mix(col, m, hubIn);
        col *= 1.0 - ring(r - 0.25, lw, px) * 0.6;
    }

    // ── The hand: the shadow's line, the Sun at its tip ─────────────────────
    float hAng = (hourNow - 12.0) / 24.0 * TAU;
    vec2 hu = vec2(sin(hAng), cos(hAng));
    float hAlong = dot(p, hu);
    float hAcross = dot(p, vec2(hu.y, -hu.x));
    float halfW = mix(0.02, 0.006, smoothstep(0.08, 0.86, hAlong));
    float span = step(-0.06, hAlong) * step(hAlong, 0.86);
    float casing = (1.0 - smoothstep(halfW + px * 1.5, halfW + px * 3.0, abs(hAcross))) * span;
    float hand = (1.0 - smoothstep(halfW, halfW + px, abs(hAcross))) * span;
    col = mix(col, vec3(0.06, 0.025, 0.015), casing * 0.75);
    col = mix(col, mix(ubuf.lightColor.rgb, vec3(1.0, 0.97, 0.9), 0.3), hand);
    alpha = max(alpha, casing);
    // The Sun: a disc with eight rays, on the vine at the hour.
    vec2 sp = p - hu * 0.9275;
    float sr = length(sp);
    float sa = atan(sp.x, sp.y);
    float rays = inside(sr - (0.034 + 0.018 * pow(abs(cos(sa * 4.0)), 8.0)), px);
    col = mix(col, vec3(0.08, 0.03, 0.01), inside(sr - 0.058, px) * 0.35);
    col = mix(col, ubuf.lightColor.rgb * 1.1, rays);
    col = mix(col, vec3(1.0, 0.96, 0.84), inside(sr - 0.022, px));
    // The pin at the axle.
    col = mix(col, metal * 1.2, inside(r - 0.036, px));
    col = mix(col, metal * 0.45, inside(r - 0.013, px));

    // Openings stay a little see-through.
    alpha *= 1.0 - opening * 0.22;
    // A warm halo round the wheel, as round the Sun.
    float halo = ubuf.glow * exp(-max(0.0, r - 1.0) * 9.0) * step(1.0, r) * 0.28;
    col = mix(col, ubuf.lightColor.rgb, halo * (1.0 - alpha));
    alpha = max(alpha, halo);

    fragColor = vec4(col * alpha, alpha) * ubuf.qt_Opacity;
}
