#version 440
// A planispheric astrolabe (modules/lock/themes/observatory/Astrolabe.qml),
// drawn the way the instrument works: the sky projected stereographically
// from the south celestial pole onto the plane of the equator.
//
//   mater  the brass body, its limb graduated in hours (and degrees when
//          it's big enough to read them)
//   plate  engraved for the site's latitude (`lat`): the tropics and the
//          equator, the horizon and the almucantars every ten degrees of
//          altitude up to the zenith, and the azimuths every thirty
//   rete   the star map laid over it, turned to the sidereal time
//          (`rete`, degrees): the rim on the tropic of Capricorn, the
//          ecliptic ring divided into the twelve signs, the colures, and a
//          flame-shaped pointer for each of twelve bright stars
//   rule   the straight edge across the front, at `rule` (degrees
//          clockwise from the top): the hour
//
// The lock lights stars (`litA/B/C`, one per pointer, 0..1) and signs
// (`litSigns`), clouds it over (`cloud`) and floods it (`bloom`). The star
// list matches Sky.reteStars, in order.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float rete;        // degrees: the sidereal time the rete is turned to
    float rule;        // degrees clockwise from the top
    float lat;         // plate latitude, degrees
    float litSigns;    // 0..12 signs lit round the ecliptic
    float glow;        // lamplight on the lit pointers
    float bloom;       // 0..1 flood of light
    float cloud;       // 0..1 cloud over the instrument
    float drift;       // cloud drift
    float fine;        // 1: degree ticks on the limb
    float inset;       // item size / instrument size (room for the halo)
    vec4 litA;         // stars 0-3
    vec4 litB;         // stars 4-7
    vec4 litC;         // stars 8-11
    vec4 brassColor;
    vec4 enamelColor;
    vec4 lampColor;
    vec4 cloudColor;
} ubuf;

const float PI = 3.14159265;
const float TAU = 6.28318531;
const float D2R = 0.01745329;
const float EPS = 23.4393 * D2R;

// The rete's stars: RA (hours), Dec (degrees).
const vec2 STARS[12] = vec2[12](
    vec2(0.1398, 29.0904), vec2(3.1361, 40.9556), vec2(4.5987, 16.5093),
    vec2(6.7525, -16.7161), vec2(10.1395, 11.9672), vec2(11.0621, 61.7508),
    vec2(13.4199, -11.1613), vec2(14.261, 19.1824), vec2(17.5822, 12.56),
    vec2(18.6156, 38.7837), vec2(20.6905, 45.2803), vec2(23.0794, 15.2053)
);

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
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = p * 2.03 + vec2(17.3, 9.1);
        a *= 0.5;
    }
    return v;
}

// Tapered capsule along +y from the origin (radius r1) to (0, h) (r2).
float taper(vec2 p, float r1, float r2, float h) {
    p.x = abs(p.x);
    float b = (r1 - r2) / h;
    float a = sqrt(max(0.0, 1.0 - b * b));
    float k = dot(p, vec2(-b, a));
    if (k < 0.0)
        return length(p) - r1;
    if (k > a * h)
        return length(p - vec2(0.0, h)) - r2;
    return dot(p, vec2(a, b)) - r1;
}

float litOf(int i) {
    return i < 4 ? ubuf.litA[i] : i < 8 ? ubuf.litB[i - 4] : ubuf.litC[i - 8];
}

// Where RA/Dec (radians) falls on the rete, in rete units with y up, the
// rete turned so RA `turn` (radians) is on the meridian at the top.
vec2 project(float ra, float dec, float req, float turn) {
    float r = req * tan((PI * 0.5 - dec) * 0.5);
    float h = turn - ra;       // hour angle: clockwise from the top
    return vec2(sin(h), cos(h)) * r;
}

float ring(float d, float w, float px) {
    return 1.0 - smoothstep(w * 0.5, w * 0.5 + px, abs(d));
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    float R = 0.5 * min(res.x, res.y) / max(1.0, ubuf.inset);
    // Instrument units, y up.
    vec2 p = (qt_TexCoord0 * res - res * 0.5) / R * vec2(1.0, -1.0);
    float px = 1.0 / R;
    float r = length(p);
    // South of the equator the instrument is made for the other pole:
    // mirror it and work with the site's latitude as if north.
    float south = ubuf.lat < 0.0 ? -1.0 : 1.0;
    p.x *= south;
    float phi = abs(ubuf.lat) * D2R;
    float lw = max(1.0, R / 260.0);   // engraving width in pixels

    // Radii: the plate ends at the tropic of Capricorn.
    float rCap = 0.8;
    float rEq = rCap / tan((PI * 0.5 + EPS) * 0.5);
    float rCan = rEq * tan((PI * 0.5 - EPS) * 0.5);

    // Lit from the upper left.
    float light = 0.86 + 0.26 * dot(normalize(p + vec2(1e-4)), normalize(vec2(-0.6, 0.8))) * smoothstep(0.0, 0.3, r);

    vec3 brass = ubuf.brassColor.rgb;
    float grain = noise(vec2(r * 420.0, 0.5)) * 0.06 + noise(p * 60.0) * 0.05;
    vec3 metal = brass * (0.8 + grain) * light;

    vec3 col = vec3(0.0);
    float alpha = smoothstep(1.0 + px, 1.0 - px, r);

    // ── Mater: the limb and its rim ──────────────────────────────────────────
    float ang = mod(atan(p.x, p.y), TAU);          // clockwise from the top
    col = metal * 0.92;
    // The rim stands proud.
    float rim = smoothstep(0.965 - px, 0.965 + px, r);
    col = mix(col, metal * (1.05 + 0.25 * (light - 0.86)), rim);
    col *= 1.0 - ring(r - 0.966, px * 1.2, px) * 0.5;
    col *= 1.0 - ring(r - 0.845, px * 1.4, px) * 0.55;
    // The hour scale between two lines round the outside of the limb (the
    // numerals go inside it): the hours marked long, the quarters short,
    // the degrees finer still.
    float tickBand = step(0.905, r) * step(r, 0.95);
    float hourA = abs(fract(ang / TAU * 24.0 + 0.5) - 0.5) * TAU / 24.0 * r / px;
    float quarterA = abs(fract(ang / TAU * 96.0 + 0.5) - 0.5) * TAU / 96.0 * r / px;
    float degA = abs(fract(ang / TAU * 360.0 + 0.5) - 0.5) * TAU / 360.0 * r / px;
    float ticks = 0.0;
    ticks = max(ticks, 1.0 - smoothstep(lw * 0.7, lw * 0.7 + 1.0, hourA));
    ticks = max(ticks, (1.0 - smoothstep(lw * 0.5, lw * 0.5 + 1.0, quarterA)) * step(0.924, r));
    ticks = max(ticks, (1.0 - smoothstep(lw * 0.35, lw * 0.35 + 1.0, degA)) * step(0.938, r) * ubuf.fine);
    col *= 1.0 - ticks * tickBand * 0.62;
    col *= 1.0 - ring(r - 0.905, lw * px, px) * 0.6;
    col *= 1.0 - ring(r - 0.95, lw * px, px) * 0.6;

    // ── Plate ────────────────────────────────────────────────────────────────
    float onPlate = smoothstep(0.845, 0.845 - px, r);
    if (onPlate > 0.0) {
        vec3 enamel = ubuf.enamelColor.rgb * (0.9 + 0.12 * noise(p * 9.0) + 0.05 * noise(p * 70.0));
        enamel *= 0.9 + 0.12 * (light - 0.86);
        float lines = 0.0;
        float faint = 0.0;
        // The tropics and the equator.
        lines = max(lines, ring(r - rCan, lw * px, px) * 0.8);
        lines = max(lines, ring(r - rEq, lw * px, px) * 0.8);
        lines = max(lines, ring(r - rCap, lw * px * 1.4, px));
        // Almucantars: circles of equal altitude, the horizon bolder, and
        // the zenith.
        float horizonR = 0.0;
        float horizonC = 0.0;
        for (int i = 0; i < 9; i++) {
            float h = float(i) * 10.0 * D2R;
            float top = rEq * tan((PI - h - phi) * 0.5);
            float bot = -rEq * tan((phi - h) * 0.5);
            float cy = (top + bot) * 0.5;
            float rad = (top - bot) * 0.5;
            if (i == 0) {
                horizonR = rad;
                horizonC = cy;
            }
            float d = length(p - vec2(0.0, cy)) - rad;
            lines = max(lines, ring(d, (i == 0 ? 1.8 : 1.0) * lw * px, px) * (i == 0 ? 1.0 : 0.6));
        }
        float zy = rEq * tan((PI * 0.5 - phi) * 0.5);
        vec2 zp = p - vec2(0.0, zy);
        lines = max(lines, (1.0 - smoothstep(0.012, 0.012 + px, length(zp))) * 0.8);
        // Azimuths every 30°, above the horizon only.
        float above = step(length(p - vec2(0.0, horizonC)), horizonR);
        float ny = -rEq * tan((PI * 0.5 + phi) * 0.5);
        float half_ = (zy - ny) * 0.5;
        float my = (zy + ny) * 0.5;
        for (int i = 1; i < 6; i++) {
            float A = float(i) * 30.0 * D2R;
            float cx = half_ / tan(A);
            float rad = half_ / sin(A);
            float d1 = length(p - vec2(cx, my)) - rad;
            float d2 = length(p - vec2(-cx, my)) - rad;
            faint = max(faint, ring(min(abs(d1), abs(d2)), lw * px, px) * above);
        }
        // The meridian and the east-west line.
        faint = max(faint, ring(p.x, lw * px, px) * step(-rCap, p.y));
        faint = max(faint, ring(p.y, lw * px, px) * 0.8);
        faint *= step(r, rCap);
        lines *= step(r, rCap + px * 2.0);
        vec3 engraved = mix(enamel, brass * 1.15, max(lines, faint * 0.55) * 0.75);
        // Past the tropic of Capricorn the plate is plain brass.
        vec3 plateCol = mix(engraved, metal * 0.7, smoothstep(rCap + px, rCap + px * 3.0, r));
        col = mix(col, plateCol, onPlate);
    }

    // ── Rete ─────────────────────────────────────────────────────────────────
    float turn = ubuf.rete * D2R;
    // Rotate the pixel into the rete's own frame (RA 0 up when turn = 0).
    float ca = cos(turn), sa = sin(turn);
    float reteAlpha = 0.0;
    vec3 reteCol = metal * 1.08;
    float lamp = 0.0;

    // The rim on the tropic of Capricorn.
    reteAlpha = max(reteAlpha, ring(r - (rCap - 0.018), 0.036, px));
    // The ecliptic: a circle through the solstices, its centre towards RA
    // 18h; a band with the signs marked across it.
    vec2 eCentre = project(18.0 * PI / 12.0, 0.0, 1.0, turn);
    eCentre = normalize(eCentre) * (rCap - rCan) * 0.5;
    float eRad = (rCap + rCan) * 0.5;
    float eD = length(p - eCentre) - eRad;
    float band = ring(eD + 0.022, 0.05, px);
    if (band > 0.0) {
        // Ecliptic longitude of this point of the band, from its RA/Dec.
        float rr = length(p);
        float dec = PI * 0.5 - 2.0 * atan(rr / rEq);
        float ra = turn - atan(p.x, p.y);
        float lam = mod(atan(sin(ra) * cos(EPS) + tan(dec) * sin(EPS), cos(ra)), TAU);
        float signIdx = floor(lam / (PI / 6.0));
        float divA = abs(fract(lam / (PI / 6.0) + 0.5) - 0.5) * (PI / 6.0) * rr / px;
        float tenA = abs(fract(lam / (PI / 18.0) + 0.5) - 0.5) * (PI / 18.0) * rr / px;
        float div = 1.0 - smoothstep(lw * 0.8, lw * 0.8 + 1.0, divA);
        float ten = (1.0 - smoothstep(lw * 0.5, lw * 0.5 + 1.0, tenA)) * step(abs(eD + 0.022), 0.012);
        vec3 bandCol = metal * 1.08 * (1.0 - div * 0.55) * (1.0 - ten * 0.35);
        float signLit = clamp(ubuf.litSigns - signIdx, 0.0, 1.0);
        bandCol = mix(bandCol, ubuf.lampColor.rgb * (1.1 - div * 0.4), signLit * 0.7 * ubuf.glow);
        reteCol = mix(reteCol, bandCol, band);
        lamp = max(lamp, signLit * band * 0.6);
        reteAlpha = max(reteAlpha, band);
    }
    // The colures: bars through the pole at RA 0h/12h and 6h/18h.
    vec2 q = vec2(p.x * ca - p.y * sa, p.x * sa + p.y * ca);
    float bars = max(ring(q.x, 0.016, px), ring(q.y, 0.016, px)) * step(r, rCap - 0.01) * step(0.05, r);
    reteAlpha = max(reteAlpha, bars * 0.95);
    // The pointers: a short flame pointing at each star, held to the
    // nearest part of the rete (the boss, the ecliptic ring or the rim) by a
    // thin strut along the same line.
    for (int i = 0; i < 12; i++) {
        vec2 st = STARS[i];
        float ra = st.x * PI / 12.0;
        float dec = st.y * D2R;
        vec2 tip = project(ra, dec, rEq, turn);
        float tr = length(tip);
        vec2 u = tr > 1e-4 ? tip / tr : vec2(0.0, 1.0);
        float uc = dot(u, eCentre);
        float te = uc + sqrt(max(0.0, uc * uc - dot(eCentre, eCentre) + eRad * eRad)) - 0.022;
        float tb = rCap - 0.018;
        if (abs(te - tr) < abs(tb - tr))
            tb = te;
        if (abs(0.045 - tr) < abs(tb - tr))
            tb = 0.045;
        float away = tb - tr;
        float side = away >= 0.0 ? 1.0 : -1.0;
        float flame = clamp(abs(away), 0.065, 0.095);
        vec2 base = u * (tr + side * flame);
        vec2 dir = normalize(tip - base);
        vec2 lp = p - base;
        vec2 local = vec2(dot(lp, vec2(dir.y, -dir.x)), dot(lp, dir));
        // A little flame: wide at the base, a curl in it, a point at the star.
        local.x += sin(local.y / flame * PI) * 0.01;
        float d = taper(local, 0.019, 0.0035, flame);
        float fill = 1.0 - smoothstep(-px, px, d);
        // The strut, where the rete is further off than the flame.
        vec2 hold = u * tb;
        vec2 ba = hold - base;
        float t = clamp(dot(p - base, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
        float strut = ring(length(p - base - ba * t), 0.009, px) * step(flame + 0.005, abs(away));
        float l = litOf(i);
        float eye = 1.0 - smoothstep(0.009, 0.009 + px, length(p - tip));
        reteAlpha = max(reteAlpha, max(fill, strut));
        reteCol = mix(reteCol, metal * 1.06, strut * (1.0 - fill));
        reteCol = mix(reteCol, mix(metal * 1.14, ubuf.lampColor.rgb * 1.25, l * ubuf.glow), fill);
        // The star itself: a pierced eye, lit.
        reteCol = mix(reteCol, mix(ubuf.enamelColor.rgb * 0.5, vec3(1.0, 0.97, 0.88), l), eye * fill);
        lamp = max(lamp, l * ubuf.glow * exp(-length(p - tip) / 0.05) * 0.75);
    }
    // The central boss.
    reteAlpha = max(reteAlpha, 1.0 - smoothstep(0.045, 0.045 + px, r));
    col = mix(col, reteCol * (0.95 + 0.1 * (light - 0.86)), reteAlpha);

    // ── The rule ─────────────────────────────────────────────────────────────
    float rr = ubuf.rule * D2R * south;
    vec2 ru = vec2(sin(rr), cos(rr));
    float along = dot(p, ru);
    float across = dot(p, vec2(ru.y, -ru.x));
    float halfW = mix(0.028, 0.006, smoothstep(0.55, 0.955, abs(along)));
    float ruleIn = (1.0 - smoothstep(halfW, halfW + px, abs(across))) * step(abs(along), 0.955);
    vec3 ruleCol = metal * (1.12 + 0.12 * sign(across));
    // The fiducial edge: the line the hour is read on.
    ruleCol *= 1.0 - ring(across, lw * px, px) * 0.6 * step(abs(along), 0.95);
    col = mix(col, ruleCol, ruleIn);
    // The pin, with its wedge.
    float pin = 1.0 - smoothstep(0.03, 0.03 + px, r);
    col = mix(col, metal * 1.2, pin);
    col = mix(col, metal * 0.45, 1.0 - smoothstep(0.011, 0.011 + px, r));

    // ── Light, weather ───────────────────────────────────────────────────────
    col += ubuf.lampColor.rgb * lamp * 0.9;
    float sky = fbm(p * 2.2 + vec2(ubuf.drift, ubuf.drift * 0.3)) * 1.1 - 0.15;
    float cloud = clamp(sky, 0.0, 1.0) * ubuf.cloud;
    col = mix(col, ubuf.cloudColor.rgb * (0.7 + 0.5 * sky), cloud * 0.85);
    col = mix(col, ubuf.lampColor.rgb * 1.2 + 0.1, ubuf.bloom * 0.55);
    // A halo past the rim when it blooms.
    float halo = ubuf.bloom * exp(-max(0.0, r - 1.0) * 7.0) * step(1.0, r) * 0.8;
    col = mix(col, ubuf.lampColor.rgb, halo * (1.0 - alpha));
    alpha = max(alpha, halo);

    fragColor = vec4(col * alpha, alpha) * ubuf.qt_Opacity;
}
