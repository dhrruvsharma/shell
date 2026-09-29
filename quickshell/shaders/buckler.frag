#version 440
// The Siege clock's face (modules/lock/themes/siege/Buckler.qml): a round
// buckler, the small fist-shield of sword-and-buckler fighting, as a
// twelve-hour dial. A rolled steel rim with a rivet at each hour (heavier
// at the quarters), a face painted gyronny of twelve in the tincture, the
// quarter of the dial the watch is in lit by firelight, sixty punched
// marks for the minutes and a domed steel boss in the middle. The hour hand
// is a sword, the minute hand a spear; both cast a shadow on the face.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float hour;        // 0..24, local time
    float minute;      // 0..60
    float inset;       // item size / buckler size (room round it)
    vec4 fieldColor;
    vec4 steelColor;
    vec4 goldColor;
    vec4 fireColor;
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

float fill(float d, float px) {
    return 1.0 - smoothstep(-px, px, d);
}

float box(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// A hand's frame: `a` clockwise from twelve; u runs out along the hand, v
// across it (y up).
vec2 handSpace(vec2 p, float a) {
    vec2 dir = vec2(sin(a), cos(a));
    return vec2(dot(p, dir), dot(p, vec2(dir.y, -dir.x)));
}

// The sword: pommel, grip, crossguard and a blade tapering to its point.
// Returns the nearest part (1 blade, 2 guard or pommel, 3 grip) and its
// distance in `d`.
float sword(vec2 q, out float d) {
    float pommel = length(q - vec2(-0.15, 0.0)) - 0.042;
    float grip = box(q - vec2(-0.045, 0.0), vec2(0.075, 0.021));
    float guard = box(q - vec2(0.045, 0.0), vec2(0.018, 0.13)) - 0.006;
    float t = clamp((q.x - 0.06) / 0.56, 0.0, 1.0);
    float half_ = mix(0.044, 0.03, t) * (1.0 - smoothstep(0.84, 1.0, t));
    float blade = max(abs(q.y) - half_, max(0.06 - q.x, q.x - 0.62));
    // The nearest part, so its colour runs out to the antialiased edge.
    d = blade;
    float part = 1.0;
    if (guard < d) { d = guard; part = 2.0; }
    if (pommel < d) { d = pommel; part = 2.0; }
    if (grip < d) { d = grip; part = 3.0; }
    return part;
}

// The spear: an ash shaft and a leaf-shaped head on a socket.
float spear(vec2 q, out float d) {
    float shaft = box(q - vec2(0.24, 0.0), vec2(0.45, 0.013));
    float socket = box(q - vec2(0.7, 0.0), vec2(0.022, 0.02));
    float t = clamp((q.x - 0.71) / 0.17, 0.0, 1.0);
    float half_ = 0.056 * sin(pow(t, 0.62) * PI) * (1.0 - 0.2 * t);
    float head = max(abs(q.y) - half_, max(0.71 - q.x, q.x - 0.88));
    float butt = length(q - vec2(-0.21, 0.0)) - 0.02;
    d = head;
    float part = 1.0;
    if (socket < d) { d = socket; part = 2.0; }
    if (butt < d) { d = butt; part = 2.0; }
    if (shaft < d) { d = shaft; part = 3.0; }
    return part;
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    float R = 0.5 * min(res.x, res.y) / max(1.0, ubuf.inset);
    // Buckler units, y up; the rim's outer edge at 1.
    vec2 p = (qt_TexCoord0 * res - res * 0.5) / R * vec2(1.0, -1.0);
    float px = 1.0 / R;
    float r = length(p);
    float ang = mod(atan(p.x, p.y), TAU);   // clockwise from twelve

    vec3 steel = ubuf.steelColor.rgb;
    vec3 gold = ubuf.goldColor.rgb;
    vec3 fire = ubuf.fireColor.rgb;
    vec2 L = normalize(vec2(-0.6, 0.8));
    float h12 = mod(ubuf.hour, 12.0);

    // Its shadow on whatever it hangs against.
    float shadow = (1.0 - smoothstep(0.96, 1.12, length(p - vec2(0.03, -0.05)))) * 0.55;

    vec3 col = vec3(0.0);
    float a = fill(r - 1.0, px);

    // ── The face ────────────────────────────────────────────────────────────
    // Gyronny of twelve: wedges of the tincture and a deeper shade of it,
    // meeting on the hours; the watch's quarter lit warm.
    float gyron = mod(floor(ang / (TAU / 12.0)), 2.0);
    vec3 field = ubuf.fieldColor.rgb * mix(1.0, 0.72, gyron);
    float quarter = floor(h12 / 3.0);
    float inQuarter = step(quarter * PI / 2.0, ang) * step(ang, (quarter + 1.0) * PI / 2.0);
    field = mix(field, field * 1.25 + fire * 0.18, inQuarter * 0.85);
    // Painted leather over wood: a little uneven, darker to the rim.
    field *= 0.9 + 0.12 * noise(p * 18.0) + 0.05 * noise(vec2(r * 60.0, ang * 7.0));
    field *= 0.78 + 0.3 * (1.0 - smoothstep(0.2, 0.9, r)) + 0.1 * dot(p, L);
    col = field;

    // Sixty punched marks for the minutes, a heavier one each five.
    float m = ang / (TAU / 60.0);
    float mi = floor(m + 0.5);
    vec2 mp = vec2(sin(mi * TAU / 60.0), cos(mi * TAU / 60.0)) * 0.83;
    float five = step(mod(mi, 5.0), 0.5);
    float punch = fill(length(p - mp) - mix(0.012, 0.022, five), px);
    col = mix(col, steel * 0.9, punch * 0.9);

    // ── The rim ─────────────────────────────────────────────────────────────
    float rim = smoothstep(0.885 - px, 0.885 + px, r);
    // Rolled: the light runs round its upper left.
    float roll = cos((r - 0.945) / 0.055 * PI * 0.5);
    float lit = dot(normalize(p + 1e-5), L);
    vec3 rimCol = steel * (0.62 + 0.28 * roll + 0.3 * lit * roll) * (0.92 + 0.12 * noise(vec2(ang * 40.0, r * 30.0)));
    col = mix(col, rimCol, rim);
    // The joint between rim and face.
    col *= 1.0 - 0.5 * exp(-pow((r - 0.885) / (px * 1.2), 2.0));

    // A rivet on each hour, heavier at the quarters.
    float hi = floor(ang / (TAU / 12.0) + 0.5);
    vec2 hp = vec2(sin(hi * TAU / 12.0), cos(hi * TAU / 12.0)) * 0.943;
    float big = step(mod(hi, 3.0), 0.5);
    float rr = mix(0.028, 0.04, big);
    vec2 rq = (p - hp) / rr;
    float rivet = fill(length(p - hp) - rr, px);
    vec3 rivCol = steel * (0.75 + 0.45 * clamp(dot(rq, L), -1.0, 1.0)) + steel * 0.35 * exp(-dot(rq + L * 0.4, rq + L * 0.4) * 4.0);
    col = mix(col, rivCol, rivet);
    col *= 1.0 - 0.35 * (1.0 - smoothstep(0.0, 1.8 * px, abs(length(p - hp) - rr)));

    // ── The boss ────────────────────────────────────────────────────────────
    float bossR = 0.2;
    float boss = fill(r - bossR, px);
    vec2 bq = p / bossR;
    float dome = sqrt(max(0.0, 1.0 - dot(bq, bq)));
    vec3 n = normalize(vec3(bq, dome * 1.4));
    float diff = clamp(dot(n, normalize(vec3(-0.6, 0.8, 0.9))), 0.0, 1.0);
    float spec = pow(clamp(dot(reflect(-normalize(vec3(-0.6, 0.8, 0.9)), n), vec3(0.0, 0.0, 1.0)), 0.0, 1.0), 18.0);
    vec3 bossCol = steel * (0.35 + 0.75 * diff) + vec3(1.0) * spec * 0.6;
    // Its flange, and eight rivets through it.
    float flange = smoothstep(bossR - px, bossR + px, r) * fill(r - 0.265, px);
    col = mix(col, steel * (0.7 + 0.25 * lit), flange);
    float bi = floor(ang / (TAU / 8.0) + 0.5);
    vec2 bp = vec2(sin(bi * TAU / 8.0), cos(bi * TAU / 8.0)) * 0.235;
    col = mix(col, steel * (0.9 + 0.4 * dot(normalize(p - bp + 1e-5), L)), fill(length(p - bp) - 0.016, px));
    col = mix(col, bossCol, boss);
    col *= 1.0 - 0.4 * exp(-pow((r - bossR) / (px * 1.2), 2.0)) * (1.0 - boss * 0.5);

    // ── The hands ───────────────────────────────────────────────────────────
    float ha = h12 / 12.0 * TAU + ubuf.minute / 60.0 * TAU / 12.0;
    float ma = ubuf.minute / 60.0 * TAU;
    vec2 off = vec2(0.022, -0.032);
    float dS, dP, dSs, dPs;
    float partS = sword(handSpace(p, ha), dS);
    float partP = spear(handSpace(p, ma), dP);
    sword(handSpace(p - off, ha), dSs);
    spear(handSpace(p - off, ma), dPs);
    // Shadows first, soft.
    float sh = max(1.0 - smoothstep(-0.005, 0.03, dSs), 1.0 - smoothstep(-0.005, 0.03, dPs));
    col *= 1.0 - 0.45 * sh * a;

    // The spear under the sword.
    float spearA = fill(dP, px);
    vec2 sq = handSpace(p, ma);
    vec3 spearCol = partP == 1.0 ? steel * (1.05 - 0.17 * sign(sq.y)) : partP == 2.0 ? steel * 0.55 : vec3(0.42, 0.29, 0.17) * (0.85 + 0.2 * noise(vec2(sq.x * 90.0, sq.y * 400.0)));
    // A spine down the head.
    spearCol *= partP == 1.0 ? 1.0 - 0.35 * exp(-pow(sq.y / 0.004, 2.0)) : 1.0;
    col = mix(col, spearCol, spearA);
    col *= 1.0 - 0.6 * (1.0 - smoothstep(0.0, 1.6 * px, abs(dP))) * spearA;

    float swordA = fill(dS, px);
    vec2 wq = handSpace(p, ha);
    vec3 swordCol;
    if (partS == 1.0) {
        // Bright steel, the fuller running down the middle of the blade.
        float fuller = exp(-pow(wq.y / 0.009, 2.0)) * (1.0 - smoothstep(0.4, 0.5, wq.x));
        swordCol = steel * (1.0 + 0.18 * sign(wq.y)) * (1.0 - 0.3 * fuller);
    } else if (partS == 2.0) {
        swordCol = gold * (0.85 + 0.3 * clamp(dot(normalize(p + 1e-5), L), -1.0, 1.0));
    } else {
        // Leather wound round the grip.
        swordCol = vec3(0.24, 0.14, 0.09) * (0.8 + 0.4 * step(0.5, fract(wq.x * 70.0 + wq.y * 20.0)));
    }
    col = mix(col, swordCol, swordA);
    col *= 1.0 - 0.6 * (1.0 - smoothstep(0.0, 1.6 * px, abs(dS))) * swordA;

    // The pivot: a gold rivet through both.
    float pivot = fill(r - 0.032, px);
    col = mix(col, gold * (0.9 + 0.5 * dot(normalize(p + 1e-5), L)), pivot);

    // A dark line round the whole, so it reads on any wallpaper.
    col *= 1.0 - 0.6 * (1.0 - smoothstep(0.0, 2.0 * px, abs(r - 1.0)));

    vec4 outc = vec4(col * a, a);
    // Its shadow, under it.
    outc = outc + vec4(0.0, 0.0, 0.0, shadow) * (1.0 - a);
    fragColor = outc * ubuf.qt_Opacity;
}
