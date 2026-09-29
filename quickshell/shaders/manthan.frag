#version 440
// The churning of the ocean of milk, for the "Samudra Manthan" lock
// (modules/lock/themes/devaloka/DevalokaSurface.qml). Under a dusk sky the
// milk ocean runs to the horizon; Mount Mandara stands in it as the
// churning rod, on Kurma's shell under the water, and the serpent Vasuki is
// wound round it as the rope: the coils turn with `churn` (the rod turning
// back and forth as the two sides pull by turns), the sea swirls round the
// mountain's foot, and the serpent's body runs off to either side, the
// hooded head rising on the left, where the asuras hold it, the tail
// running off to the right, to the devas. `pull` slides the body towards
// whichever side is pulling. A keystroke throws up a ring of foam
// (`splash`); a wrong passcode spreads the Halahala poison across the sea
// from the churn (`poison`); the right one raises a pillar of light, the
// amrita, and turns the sea to gold (`amrita`). `time` keeps the sea and
// the stars alive while the lock is awake.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float time;
    float churn;       // radians the rod has turned
    float pull;        // -1 the asuras' side (left) .. 1 the devas' (right)
    float splash;      // 0..1, a ring of foam spreading from the churn
    float poison;      // 0..1, the Halahala across the sea
    float amrita;      // 0..1, the light of the amrita
    float mx;          // the mountain's centre, 0..1 across
    vec4 goldColor;
    vec4 pigmentColor;
    vec4 poisonColor;
    vec4 amritaColor;
} ubuf;

const float PI = 3.14159265;
const float TAU = 6.28318531;

// Heights, 0 at the top of the picture, 1 at the bottom.
const float HORIZON = 0.6;
const float FOOT = 0.655;      // where the mountain meets the water
const float SUMMIT = 0.155;    // its highest crag
const float COIL_TOP = 0.3;
const float COIL_BOTTOM = 0.585;
const float TURNS = 4.0;       // whole turns shown; the ends are behind
const float ROPE = 0.042;      // the serpent's thickness
const float LEFT_Y = 0.405;    // where the body leaves the mountain
const float RIGHT_Y = 0.465;

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
        p = p * 2.07 + vec2(13.1, 7.7);
        a *= 0.5;
    }
    return v;
}

// The mountain, a craggy column: its half-width at height y, a little wider
// at the foot.
float mountainW(float y) {
    float t = clamp((y - 0.25) / (FOOT - 0.25), 0.0, 1.0);
    float w = 0.084 + 0.03 * t * t;
    w += 0.007 * sin(y * 31.0 + 1.0) + 0.004 * sin(y * 83.0 + 2.1) + 0.002 * sin(y * 191.0);
    return w;
}

// How far below its outline the mountain's top is at x (negative: inside):
// three crags, the tallest in the middle, their sides broken.
float summit(float x) {
    float c = SUMMIT + abs(x) * 1.7;
    float l = SUMMIT + 0.05 + abs(x + 0.052) * 1.5;
    float r = SUMMIT + 0.035 + abs(x - 0.05) * 1.9;
    float top = min(c, min(l, r));
    top += 0.006 * sin(x * 120.0) + 0.003 * sin(x * 310.0 + 1.0);
    return top;
}

// The serpent's skin: dark scales over a pale belly, `u` along the body,
// `v` across it (-1 top .. 1 bottom), lit round the tube from above.
vec3 skin(float u, float v, vec3 tint) {
    float tube = sqrt(max(0.0, 1.0 - v * v));
    vec3 back = mix(vec3(0.06, 0.2, 0.17), tint * 0.5, 0.3);
    vec3 belly = vec3(0.88, 0.78, 0.52);
    float bellyW = smoothstep(0.35, 0.62, v);
    vec3 c = mix(back, belly, bellyW);
    // Scales: offset rows of little lozenges; broad plates on the belly.
    vec2 g = vec2(u * 52.0, v * 4.0);
    g.x += floor(g.y) * 0.5;
    vec2 f = abs(fract(g) - 0.5);
    float scale = smoothstep(0.38, 0.5, f.x + f.y);
    c *= 1.0 - scale * 0.22 * (1.0 - bellyW);
    c *= 0.9 + 0.2 * noise(vec2(u * 3.0, 0.5));
    c *= 1.0 - smoothstep(0.46, 0.5, abs(fract(u * 15.0) - 0.5)) * 0.15 * bellyW;
    // A gold stripe down the back, the jewels of a naga.
    c = mix(c, vec3(0.97, 0.74, 0.32), (1.0 - smoothstep(0.05, 0.12, abs(v + 0.3))) * 0.5);
    float light = 0.3 + 0.75 * tube * (0.75 + 0.25 * (-v));
    c *= light;
    // A sheen along the top of the tube.
    c += vec3(0.9, 0.95, 0.85) * exp(-pow((v + 0.45) * 4.0, 2.0)) * 0.1;
    return c;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float aspect = ubuf.itemWidth / max(1.0, ubuf.itemHeight);
    // Scene units: x across from the mountain's centre in heights, y down.
    float x = (uv.x - ubuf.mx) * aspect;
    float y = uv.y;
    float px = 1.0 / ubuf.itemHeight;
    float t = ubuf.time;

    vec3 gold = ubuf.goldColor.rgb;
    vec3 pigment = ubuf.pigmentColor.rgb;
    vec3 duskHi = vec3(0.98, 0.58, 0.26);

    // ── The sky ──────────────────────────────────────────────────────────────
    vec3 col = mix(vec3(0.02, 0.03, 0.1), vec3(0.12, 0.06, 0.2), smoothstep(0.0, 0.42, y));
    col = mix(col, vec3(0.46, 0.18, 0.16), smoothstep(0.34, HORIZON, y));
    col = mix(col, pigment * 0.3, 0.2 * (1.0 - smoothstep(0.0, 0.5, y)));
    float glowR = length(vec2(x * 0.6, (y - HORIZON) * 1.7));
    col += duskHi * exp(-glowR * 3.0) * 0.5;
    // Stars.
    vec2 sg = uv * vec2(aspect, 1.0) * 90.0;
    vec2 sc = floor(sg);
    float sh = hash(sc);
    float star = step(0.975, sh) * smoothstep(0.2, 0.0, length(fract(sg) - 0.5 - (vec2(hash(sc + 3.0), hash(sc + 7.0)) - 0.5) * 0.5));
    star *= (0.6 + 0.4 * sin(t * 1.7 + sh * 40.0)) * (1.0 - smoothstep(0.1, 0.5, y));
    col += vec3(1.0, 0.95, 0.85) * star * 0.9;
    // Rays of the amrita's light, and the poison darkening the heavens.
    float rayA = atan(x, (FOOT - y));
    float rays = (0.5 + 0.5 * sin(rayA * 22.0)) * exp(-length(vec2(x, y - FOOT)) * 1.6);
    col += ubuf.amritaColor.rgb * rays * ubuf.amrita * 0.5 * step(y, HORIZON + 0.02);
    col = mix(col, ubuf.poisonColor.rgb * 0.45, ubuf.poison * 0.45 * step(y, HORIZON));
    vec3 skyLow = col;

    // ── The ocean of milk ────────────────────────────────────────────────────
    float onSea = step(HORIZON, y);
    if (onSea > 0.0) {
        float depth = y - HORIZON;
        float z = 1.0 / (depth + 0.025);
        // Milk, catching the dusk towards the horizon.
        // Milk under a dusk sky: warm towards the horizon, cooling to a
        // blue-grey in front.
        vec3 milk = mix(vec3(0.8, 0.76, 0.72), vec3(0.5, 0.54, 0.63), smoothstep(0.0, 0.34, depth));
        float fres = exp(-depth * 11.0);
        vec3 reflect_ = mix(vec3(0.5, 0.24, 0.2), duskHi, exp(-abs(x) * 1.6) * 0.8);
        vec3 sea = mix(milk, reflect_, fres * 0.6);
        // Long, low swell in perspective.
        float swell = fbm(vec2(x * z * 0.3, z * 5.5 + t * 0.35)) - 0.5;
        swell *= smoothstep(0.0, 0.05, depth);
        sea *= 1.0 + swell * 0.3;
        // The whole sea turns round the mountain: the churn's arms, as seen
        // low across the water, fading with distance from it.
        vec2 q = vec2(x, (y - FOOT) * 4.4);
        float r = length(q);
        float a = atan(q.y, q.x);
        float arms = sin(a * 3.0 + log(r + 0.03) * 2.6 - t * 0.8 - ubuf.churn * 2.0);
        float streak = smoothstep(0.9, 0.995, arms) * exp(-r * 1.1) * smoothstep(0.03, 0.12, r);
        float band = (0.5 + 0.5 * arms) * exp(-r * 1.6);
        sea = mix(sea, sea * 0.9, band * 0.5);
        sea = mix(sea, vec3(0.95, 0.94, 0.92), streak * 0.7);
        // Curls of foam close in, whipped up by the churning.
        float spin = a - t * 0.3 - ubuf.churn * 0.5;
        float curls = smoothstep(0.5, 0.78, fbm(vec2(cos(spin), sin(spin)) * 2.2 + vec2(r * 9.0, 0.0))) * exp(-r * 3.0) * smoothstep(0.02, 0.07, r);
        sea = mix(sea, vec3(0.96, 0.95, 0.93), curls * 0.75);
        // A collar of foam where the milk breaks on the mountain's foot.
        float collar = exp(-max(0.0, r - 0.09) * 22.0) * smoothstep(0.03, 0.08, r) * (0.6 + 0.4 * noise(vec2(a * 9.0 - t * 1.2, 1.0)));
        sea = mix(sea, vec3(1.0, 0.99, 0.97), collar * 0.8);
        // Glints.
        vec2 gg = vec2(x * z * 6.0, z * 14.0);
        float glint = step(0.96, hash(floor(gg + vec2(floor(t * 1.5), 0.0)))) * smoothstep(0.3, 0.0, length((fract(gg) - 0.5) * vec2(0.55, 2.2)));
        sea += vec3(1.0, 0.86, 0.66) * glint * 0.3 * smoothstep(0.0, 0.03, depth) * (1.0 - smoothstep(0.08, 0.3, depth));
        // The mountain's shadow on the water in front of it.
        sea *= 1.0 - 0.3 * exp(-x * x / 0.012) * smoothstep(0.0, 0.02, y - FOOT) * exp(-(y - FOOT) * 5.0);
        // A ring of foam from the last keystroke.
        float ringR = ubuf.splash * 0.6;
        float ring = exp(-abs(r - ringR) * 36.0) * (1.0 - ubuf.splash) * step(0.001, ubuf.splash);
        sea = mix(sea, vec3(1.0), ring * 0.75);
        // Halahala: the poison spreading out over the milk from the churn,
        // a violet fire at its edge.
        float reach = ubuf.poison * 1.35;
        float ragged = reach + (fbm(q * 3.0 + vec2(t * 0.2, 0.0)) - 0.5) * 0.35;
        float venom = smoothstep(ragged, ragged - 0.12, r) * step(0.001, ubuf.poison);
        float venomEdge = exp(-abs(r - ragged) * 18.0) * step(0.001, ubuf.poison);
        sea = mix(sea, ubuf.poisonColor.rgb * (0.55 + 0.3 * fbm(q * 6.0 - t * 0.3)) + streak * 0.08, venom * 0.92);
        sea += vec3(0.5, 0.42, 1.0) * venomEdge * 0.5 * ubuf.poison;
        // The amrita: the sea turns to gold from the churn outwards.
        float goldReach = ubuf.amrita * 1.6;
        float golden = smoothstep(goldReach, goldReach - 0.4, r);
        sea = mix(sea, mix(ubuf.amritaColor.rgb, vec3(1.0, 0.98, 0.9), streak * 0.6 + curls * 0.5), golden * ubuf.amrita * 0.8);
        col = sea;
    }

    // A haze lying on the horizon.
    col = mix(col, mix(vec3(0.82, 0.5, 0.36), duskHi, exp(-abs(x) * 1.2) * 0.5), exp(-abs(y - HORIZON) * 90.0) * 0.45);

    // ── Mount Mandara ────────────────────────────────────────────────────────
    float w = mountainW(y);
    float top = summit(x);
    float inMountain = (1.0 - smoothstep(w - px * 1.5, w + px * 1.5, abs(x)))
        * smoothstep(top - px * 1.5, top + px * 1.5, y) * step(y, FOOT);
    if (inMountain > 0.0) {
        float nx = clamp(x / max(w, 1e-4), -1.0, 1.0);
        float round_ = sqrt(max(0.0, 1.0 - nx * nx));
        // Lit from the left and from behind by the dusk.
        float lit = 0.35 + 0.65 * clamp(0.55 - nx * 0.6, 0.0, 1.0);
        float rock = fbm(vec2(x * 26.0, y * 30.0));
        // Ledges: broken horizontal strata, lighter on their tops.
        float ledgeY = y * 22.0 + rock * 1.6 + sin(x * 40.0) * 0.2;
        float ledge = smoothstep(0.0, 0.08, fract(ledgeY)) * (1.0 - smoothstep(0.08, 0.5, fract(ledgeY)));
        vec3 stone = mix(vec3(0.12, 0.11, 0.15), vec3(0.3, 0.26, 0.29), rock);
        stone *= (0.5 + 0.5 * round_) * lit;
        stone += vec3(0.25, 0.2, 0.18) * ledge * lit * 0.5;
        // Fine veins of gold.
        float vein = 1.0 - smoothstep(0.0, 0.02, abs(fbm(vec2(x * 18.0 + 3.0, y * 24.0)) - 0.5));
        stone = mix(stone, gold * 0.95, vein * 0.3 * lit);
        // The dusk behind it catching its edges.
        stone += duskHi * pow(abs(nx), 5.0) * 0.35;
        stone += duskHi * exp(-(y - top) * 60.0) * 0.25;
        stone += ubuf.amritaColor.rgb * ubuf.amrita * 0.35 * (1.0 - abs(nx));
        stone = mix(stone, ubuf.poisonColor.rgb * 0.4, ubuf.poison * 0.35);
        // Its foot wet with milk.
        stone = mix(stone, vec3(0.86, 0.84, 0.8), smoothstep(FOOT - 0.014, FOOT, y) * 0.55);
        col = mix(col, stone, inMountain);
    }

    // ── Vasuki ───────────────────────────────────────────────────────────────
    vec3 tint = pigment;
    // The coils, where they pass in front of the mountain; a shadow under
    // each on the rock.
    if (y > COIL_TOP - ROPE && y < COIL_BOTTOM + ROPE * 1.5) {
        float rc = mountainW(y) + ROPE * 0.3;
        float pitch = (COIL_BOTTOM - COIL_TOP) / TURNS;
        // Where a coil turns behind the mountain: its rounded side, seen as
        // it goes.
        for (int k = 0; k < 2; k++) {
            float sgn = k == 0 ? -1.0 : 1.0;
            float turnPh = (sgn * PI * 0.5 + ubuf.churn) / TAU;
            // The band's middle is half a turn on from its start; only the
            // whole turns are shown, so the rope's ends stay out of sight.
            float n = floor((y - COIL_TOP) / pitch - turnPh);
            float cy = COIL_TOP + pitch * (n + 0.5 + turnPh);
            vec2 cp = vec2(sgn * (mountainW(cy) + ROPE * 0.3), cy);
            vec2 dv = (vec2(x, y) - cp) / (ROPE * 0.36);
            float cap = (1.0 - smoothstep(0.85, 1.0, length(dv))) * step(0.0, n) * step(n, TURNS - 1.0);
            if (cap > 0.0) {
                vec3 s = skin(0.4 * n + 0.1, dv.y * 0.9, tint) * (0.6 + 0.3 * sqrt(max(0.0, 1.0 - dot(dv, dv))));
                col = mix(col, s, cap);
            }
        }
        if (abs(x) < rc) {
            float phi = asin(clamp(x / rc, -1.0, 1.0));
            float along = (y - COIL_TOP) / pitch - (phi + ubuf.churn) / TAU;
            float band = (fract(along) - 0.5) * pitch;
            float turn = floor(along);
            float within = step(0.0, turn) * step(turn, TURNS - 1.0);
            // Where the coil turns away round the side, it narrows.
            float half_ = ROPE * 0.5 * (0.7 + 0.3 * cos(phi));
            float v = band / half_;
            float on = (1.0 - smoothstep(0.85, 1.0, abs(v))) * within;
            float shadow = exp(-max(0.0, band - half_) / (ROPE * 0.35)) * step(half_, band) * step(0.0, turn) * step(turn, TURNS - 0.5) * inMountain;
            col *= 1.0 - shadow * 0.5;
            if (on > 0.0) {
                vec3 s = skin(phi / TAU * 2.5 + floor(along) * 0.37, v, tint);
                s *= 0.45 + 0.55 * cos(phi);
                col = mix(col, s, on);
            }
        }
    }
    // The body, off to either side: to the asuras on the left, rising into
    // the hood, and to the devas on the right, sagging a little.
    float headX = -(ubuf.mx * aspect - 0.11);
    float side = x < 0.0 ? -1.0 : 1.0;
    float y0 = side < 0.0 ? LEFT_Y : RIGHT_Y;
    float edgeX = abs(x) - mountainW(y0);
    if (edgeX > -0.02 && (side > 0.0 || x > headX)) {
        float slide = ubuf.pull * 0.08 + t * 0.005;
        float span = side < 0.0 ? abs(headX) - mountainW(y0) : 1.0;
        float yc = y0 + 0.035 * sin(clamp(edgeX / span, 0.0, 1.0) * PI) + 0.012 * sin(edgeX * 7.0 + side);
        // To the right it sags away over the sea to the devas, beyond the
        // horizon.
        if (side > 0.0) {
            float dip = max(0.1, (0.56 - ubuf.mx) * aspect - mountainW(y0));
            float fr = edgeX / dip;
            yc = y0 + (HORIZON + 0.05 - y0) * fr * fr + 0.008 * sin(edgeX * 9.0);
        }
        // Rising into the neck at the left end.
        if (side < 0.0)
            yc -= 0.1 * smoothstep(headX + 0.09, headX, x);
        float v = (y - yc) / (ROPE * 0.5);
        float on = (1.0 - smoothstep(0.85, 1.0, abs(v))) * (1.0 - inMountain * step(0.0, -edgeX + 0.004));
        // Nothing of it shows below the horizon.
        on *= side > 0.0 ? 1.0 - smoothstep(HORIZON - 0.001, HORIZON + 0.002, y) : 1.0;
        if (on > 0.0) {
            vec3 s = skin(edgeX * 2.2 - slide * side, v, tint);
            col = mix(col, s, on);
        }
    }
    // The neck and the hood, spread, facing us; the head at its crown.
    {
        vec2 h = vec2(x - headX, y);
        float nv = (h.x + 0.004) / (ROPE * 0.5);
        float neck = (1.0 - smoothstep(0.85, 1.0, abs(nv))) * step(0.28, y) * step(y, LEFT_Y - 0.1 + ROPE * 0.2);
        col = mix(col, skin(y * 2.5, nv * 0.8 - 0.1, tint), neck);
        // A hood: widest above its middle, drawn in to the neck below.
        vec2 hq = (h - vec2(0.0, 0.262)) / vec2(0.052, 0.062);
        float hw = mix(0.32, 1.0, smoothstep(-1.0, -0.1, hq.y)) * sqrt(max(0.0, 1.0 - pow(max(hq.y, 0.0) / 1.0, 2.0)));
        hw = hq.y > 1.0 ? 0.0 : hw;
        float hood = (1.0 - smoothstep(hw - 0.06, hw, abs(hq.x))) * step(-1.0, hq.y);
        if (hood > 0.0) {
            float rim = smoothstep(hw - 0.2, hw - 0.06, abs(hq.x));
            vec3 hc = mix(vec3(0.06, 0.2, 0.17), tint * 0.5, 0.3);
            // The pale throat plates down the middle.
            float throat = 1.0 - smoothstep(0.26, 0.34, abs(hq.x) / max(hw, 0.2));
            float plates = smoothstep(0.4, 0.5, abs(fract(hq.y * 3.5) - 0.5));
            hc = mix(hc, vec3(0.86, 0.76, 0.5) * (1.0 - plates * 0.3), throat * 0.85);
            hc *= 0.55 + 0.45 * sqrt(max(0.0, 1.0 - pow(hq.x / max(hw, 0.2), 2.0)));
            hc = mix(hc, gold, rim * 0.75);
            col = mix(col, hc, hood);
        }
        // The head at the crown of the hood, looking out over the sea.
        vec2 hh = (h - vec2(0.0, 0.2)) / vec2(0.02, 0.026);
        float head = 1.0 - smoothstep(0.9, 1.0, length(hh * vec2(1.0, 1.0 + 0.25 * step(0.0, hh.y))));
        vec3 headCol = mix(vec3(0.07, 0.22, 0.18), tint * 0.5, 0.3) * (0.6 + 0.4 * sqrt(max(0.0, 1.0 - dot(hh, hh))));
        col = mix(col, headCol, head);
        float eyes = (1.0 - smoothstep(0.12, 0.22, length(hh - vec2(-0.42, -0.05)))) + (1.0 - smoothstep(0.12, 0.22, length(hh - vec2(0.42, -0.05))));
        col = mix(col, mix(vec3(1.0, 0.78, 0.3), vec3(1.0, 0.25, 0.15), ubuf.poison), eyes * head);
    }

    // The amrita: a pillar of light rising from the churn.
    float pillar = exp(-abs(x) * 26.0) * smoothstep(FOOT + 0.02, 0.0, y) * ubuf.amrita;
    col += ubuf.amritaColor.rgb * pillar * 0.9;
    col = mix(col, ubuf.amritaColor.rgb * 1.1 + 0.1, ubuf.amrita * ubuf.amrita * 0.18);

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0) * ubuf.qt_Opacity;
}
