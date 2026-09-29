#version 440
// The sky over the wallpaper as an engraved star chart, looking at the
// meridian: a stereographic view centred on the horizon's south point (the
// north point, south of the equator) at the middle of the bottom edge, with
// the zenith at the top edge, so the horizon is the bottom edge and the
// meridian runs straight up the middle. This draws what the stars and their
// labels (modules/lock/themes/observatory/StarChart.qml) sit on: the night
// deepening towards the zenith, the Milky Way where it really runs tonight,
// the equatorial grid turning with the sidereal time, the ecliptic as a
// graduated band with the signs' boundaries, the meridian marked in
// altitude and the horizon in azimuth.
//
// Static: everything follows `lst`, which the chart moves once a minute.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float lst;         // local sidereal time, degrees
    float lat;         // site latitude, degrees
    float facing;      // azimuth at the middle of the view, degrees
    float night;       // 0 day .. 1 full night
    float boot;        // 0..1 switch-on: the lines are ruled in
    float lineScale;   // hairline width, > 1 when drawn scaled down
    float veil;        // how dark the night sky gets, 0..1
    float strength;    // how strongly the engraving shows, 0..1
    vec4 inkColor;     // grid lines
    vec4 brassColor;   // ecliptic, meridian and horizon scales
    vec4 skyColor;     // the night sky
    vec4 milkColor;    // the Milky Way
} ubuf;

const float PI = 3.14159265;
const float TAU = 6.28318531;
const float D2R = 0.01745329;

float hash3(vec3 p) {
    p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 x) {
    vec3 i = floor(x);
    vec3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
                   mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
               mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
                   mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm3(vec3 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise3(p);
        p = p * 2.07 + vec3(3.1, 7.7, 1.3);
        a *= 0.5;
    }
    return v;
}

// 1 on the lines where `v` is a multiple of `period`, `w` pixels wide.
// `fw` is how much `v` changes per pixel.
float rule(float v, float period, float fw, float w) {
    float f = abs(fract(v / period + 0.5) - 0.5) * period;
    float d = f / max(fw, 1e-6);
    return 1.0 - smoothstep(0.5 * w, 0.5 * w + 1.0, d);
}

// Per-pixel change of an angle that wraps at TAU, without the jump.
float angleWidth(float a) {
    return min(fwidth(a), fwidth(mod(a + PI, TAU)));
}

// Lays `src` at opacity `sa` over (col, a), both unpremultiplied.
void over(inout vec3 col, inout float a, vec3 src, float sa) {
    float oa = sa + a * (1.0 - sa);
    col = oa > 1e-5 ? (src * sa + col * a * (1.0 - sa)) / oa : col;
    a = oa;
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 px = qt_TexCoord0 * res;
    float lw = ubuf.lineScale;

    // Back from the screen to a direction in the sky (x east, y north,
    // z up): the inverse stereographic projection.
    float R2 = res.y;
    vec2 q = vec2(px.x - res.x * 0.5, res.y - px.y) / R2;
    float rho2 = dot(q, q);
    float cz = (1.0 - rho2) / (1.0 + rho2);
    float k = 2.0 / (1.0 + rho2);
    float a0 = ubuf.facing * D2R;
    vec3 c = vec3(sin(a0), cos(a0), 0.0);
    vec3 e1 = vec3(sin(a0 + PI * 0.5), cos(a0 + PI * 0.5), 0.0);
    vec3 s = normalize(cz * c + k * q.x * e1 + vec3(0.0, 0.0, k * q.y));
    float alt = asin(clamp(s.z, -1.0, 1.0));
    float az = mod(atan(s.x, s.y), TAU);

    // Equatorial coordinates.
    float phi = ubuf.lat * D2R;
    vec3 pole = vec3(0.0, cos(phi), sin(phi));
    vec3 meq = vec3(0.0, -sin(phi), cos(phi));
    float dec = asin(clamp(dot(s, pole), -1.0, 1.0));
    float ha = atan(-s.x, dot(s, meq));
    float ra = mod(ubuf.lst * D2R - ha, TAU);
    vec3 eq = vec3(cos(dec) * cos(ra), cos(dec) * sin(ra), sin(dec));

    float draw = ubuf.boot * ubuf.strength;
    vec3 col = vec3(0.0);
    float alpha = 0.0;

    // ── The night, deepening towards the zenith ────────────────────────────
    float up = clamp(1.0 - px.y / res.y, 0.0, 1.0);
    float dark = mix(0.08, 0.5, pow(up, 1.3)) * mix(0.4, 1.0, ubuf.night) * ubuf.veil * ubuf.boot;
    col = ubuf.skyColor.rgb;
    alpha = dark;

    // ── The Milky Way ──────────────────────────────────────────────────────
    const float aG = 192.85948 * D2R;
    const float dG = 27.12825 * D2R;
    const float lN = 122.93192 * D2R;
    float sb = sin(dec) * sin(dG) + cos(dec) * cos(dG) * cos(ra - aG);
    float b = asin(clamp(sb, -1.0, 1.0));
    float gl = lN - atan(cos(dec) * sin(ra - aG), sin(dec) * cos(dG) - cos(dec) * sin(dG) * cos(ra - aG));
    gl = mod(gl + PI, TAU) - PI;    // galactic longitude about the centre
    float width = 0.13 + 0.07 * exp(-gl * gl / 0.5);
    float band = exp(-(b * b) / (width * width));
    float core = 0.45 + 0.55 * exp(-gl * gl / 0.7);
    float clumps = fbm3(eq * 7.0);
    // The Great Rift: dust splitting the band from Cygnus to Sagittarius.
    float rift = exp(-pow((b - 0.02 - 0.03 * sin(gl * 3.0)) / 0.028, 2.0)) * smoothstep(1.7, 0.6, abs(gl - 0.55));
    float milk = band * core * (0.35 + 0.9 * clumps) * (1.0 - 0.7 * rift);
    float milkA = milk * 0.22 * mix(0.3, 1.0, ubuf.night) * draw * step(0.0, alt);
    over(col, alpha, ubuf.milkColor.rgb, milkA);

    // ── Engraving ──────────────────────────────────────────────────────────
    float above = smoothstep(-0.002, 0.004, alt);
    float fwDec = fwidth(dec);
    float fwRa = angleWidth(ra);
    float grid = max(rule(dec, 15.0 * D2R, fwDec, lw), rule(ra, 30.0 * D2R, fwRa, lw));
    float equator = rule(dec + 90.0 * D2R, 90.0 * D2R, fwDec, lw * 1.4) * step(abs(dec), 10.0 * D2R);
    float ink = max(grid * 0.11, equator * 0.2) * above * draw;

    // The ecliptic: a band a degree wide, chequered every five degrees like
    // an old chart's, crossed at the signs' boundaries.
    const float eps = 23.4393 * D2R;
    float beta = asin(clamp(sin(dec) * cos(eps) - cos(dec) * sin(eps) * sin(ra), -1.0, 1.0));
    float lambda = mod(atan(sin(ra) * cos(eps) + tan(clamp(dec, -1.55, 1.55)) * sin(eps), cos(ra)), TAU);
    float fwB = fwidth(beta);
    float fwL = angleWidth(lambda);
    float halfW = 0.5 * D2R;
    float edges = max(rule(beta - halfW, 1000.0, fwB, lw), rule(beta + halfW, 1000.0, fwB, lw));
    float inBand = 1.0 - smoothstep(halfW - fwB * 0.5, halfW + fwB * 0.5, abs(beta));
    float chequer = step(0.5, fract(lambda / (10.0 * D2R))) * inBand;
    float signs = rule(lambda, 30.0 * D2R, fwL, lw * 1.3) * (1.0 - smoothstep(2.2 * D2R, 2.2 * D2R + fwB, abs(beta)));
    float ecliptic = max(max(edges, signs), chequer * 0.55) * above * draw;

    // The meridian, up the middle, marked every ten degrees of altitude.
    float fromMid = abs(px.x - res.x * 0.5);
    float meridian = (1.0 - smoothstep(0.5 * lw, 0.5 * lw + 1.0, fromMid)) * 0.8;
    float altTick = rule(alt, 10.0 * D2R, fwidth(alt), lw);
    float tickLen = (rule(alt, 30.0 * D2R, fwidth(alt), lw) > 0.5 ? 14.0 : 7.0) * lw;
    meridian = max(meridian, altTick * (1.0 - smoothstep(tickLen, tickLen + 1.0, fromMid)));
    meridian *= above * draw;

    // The horizon (the bottom edge) graduated in azimuth: every 5°, longer
    // every 15° and at the cardinal and half-cardinal points.
    float fromFloor = res.y - px.y;
    float fwAz = angleWidth(az);
    float len = rule(az, 45.0 * D2R, fwAz, lw) > 0.5 ? 18.0 : rule(az, 15.0 * D2R, fwAz, lw) > 0.5 ? 11.0 : 6.0;
    float azTick = rule(az, 5.0 * D2R, fwAz, lw) * (1.0 - smoothstep(len * lw, len * lw + 1.0, fromFloor));
    float floorLine = 1.0 - smoothstep(0.5 * lw, 0.5 * lw + 1.0, fromFloor - 2.0 * lw);
    float horizon = max(azTick, floorLine * 0.7) * draw;

    // Laid over the sky: ink first, then brass.
    over(col, alpha, ubuf.inkColor.rgb, ink * ubuf.inkColor.a);
    over(col, alpha, ubuf.brassColor.rgb, max(max(ecliptic * 0.5, meridian * 0.45), horizon * 0.55) * ubuf.brassColor.a);

    fragColor = vec4(col * alpha, alpha) * ubuf.qt_Opacity;
}
