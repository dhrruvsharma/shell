#version 440
// A Gothic rose window: an outer ring of stone, twelve lancets (pointed,
// leaded, three panes each) round a ring of twelve roundels and a
// six-lobed eye, all set in dark tracery. The glass takes its colours from
// the wallpaper (each pane the wallpaper's colour where it sits, made
// jewel-bright) mixed with the theme's glass.
//
// `lit` lights the lancets clockwise from twelve o'clock (fractional: the
// last one coming on), `litInner` the roundels, `glow` is the light behind
// it all, `bloom` floods it white-gold (with a halo past the rim), and up
// to four lancets can be `cracks`ed. Used by the Cathedral clock (the hours
// and the five minutes) and the "Rose Window" lock (the passcode). Static
// apart from those.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float lit;         // 0..12
    float litInner;    // 0..12
    float glow;        // 0..1
    float bloom;       // 0..1
    float wallMix;     // 0..1 how much of the pane colour is the wallpaper's
    vec4 cracks;       // lancet indices, -1 for none
    vec4 glassA;       // opaque
    vec4 glassB;
    vec4 glassC;
    vec4 glassD;
    vec4 leadColor;
    vec4 stoneColor;
} ubuf;

layout(binding = 1) uniform sampler2D wall;

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

vec3 palette(float i) {
    float k = mod(i, 4.0);
    return k < 1.0 ? ubuf.glassA.rgb : k < 2.0 ? ubuf.glassC.rgb : k < 3.0 ? ubuf.glassB.rgb : ubuf.glassD.rgb;
}

// The colour of a pane whose centre is at `c` (rose units, y down), the
// theme's glass `i` mixed with the wallpaper there, pushed jewel-bright.
vec3 paneColour(vec2 c, float i) {
    vec3 w = texture(wall, clamp(c * 0.5 + 0.5, 0.0, 1.0)).rgb;
    float l = dot(w, vec3(0.299, 0.587, 0.114));
    w = clamp(mix(vec3(l), w, 1.9), 0.0, 1.0);
    w = w / max(max(w.r, max(w.g, w.b)), 0.25) * 0.85;
    return mix(palette(i), w, ubuf.wallMix);
}

bool cracked(float k) {
    return k == ubuf.cracks.x || k == ubuf.cracks.y || k == ubuf.cracks.z || k == ubuf.cracks.w;
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    float R = 0.5 * min(res.x, res.y);
    vec2 p = (qt_TexCoord0 * res - res * 0.5) / R;     // rose units, y down
    float px = 1.0 / R;                                 // one pixel
    float r = length(p);
    // Clockwise from twelve o'clock.
    float th = mod(atan(p.x, -p.y), TAU);
    float lead = max(0.011, 1.3 * px);

    vec3 col = vec3(0.0);
    float alpha = 0.0;
    float glassMask = 0.0;
    vec3 glass = vec3(0.0);
    float lightOn = 0.0;
    float leadLine = 0.0;

    // ── Lancets: r 0.48 .. 0.92 ─────────────────────────────────────────
    float sector = TAU / 12.0;
    float k = floor(th / sector);
    float a = (th / sector - k - 0.5) * sector;         // radians off centre
    float across = a * r;
    float hw = 0.1;
    float spring = 0.92 - hw * 1.732;
    float y = r - spring;
    float half_ = y < 0.0 ? hw : sqrt(max(0.0, 4.0 * hw * hw - y * y)) - hw;
    float inLancet = step(0.48, r) * step(r, 0.92) * step(abs(across), half_);
    float edgeL = min(min(half_ - abs(across), r - 0.48), 0.92 - r);
    if (inLancet > 0.0) {
        float along = (r - 0.48) / 0.44;
        float j = along < 0.34 ? 0.0 : along < 0.66 ? 1.0 : 2.0;
        float mid = (j + 0.5) / 3.0 * 0.44 + 0.48;
        vec2 cp = vec2(sin((k + 0.5) * sector), -cos((k + 0.5) * sector)) * mid;
        glass = paneColour(cp, k * 3.0 + j + k);
        // Lead: the outline and between the panes.
        float bar = min(abs(along - 0.34), abs(along - 0.66)) * 0.44;
        leadLine = max(smoothstep(lead, lead - px, edgeL), smoothstep(lead * 0.8, lead * 0.8 - px, bar));
        lightOn = clamp(ubuf.lit - k, 0.0, 1.0);
        if (cracked(k)) {
            // A jagged break across the pane, and the light behind it dims.
            float c = abs(across - (noise(vec2(r * 30.0, k)) - 0.5) * 0.07 - (along - 0.5) * 0.12 * (hash(vec2(k, 2.0)) - 0.5));
            leadLine = max(leadLine, smoothstep(lead * 0.7, lead * 0.7 - px, c));
            lightOn *= 0.45;
        }
        glassMask = 1.0;
    }

    // ── Roundels: twelve circles round r = 0.36, between the lancets ────
    if (glassMask == 0.0) {
        float kk = floor((th / sector) - 0.5 + 12.0);
        float kr = mod(kk, 12.0);
        float ang = (kr + 1.0) * sector;
        vec2 c = vec2(sin(ang), -cos(ang)) * 0.36;
        float d = length(p - c);
        if (d < 0.075) {
            glass = paneColour(c, kr + 2.0);
            leadLine = smoothstep(lead, lead - px, 0.075 - d);
            lightOn = clamp(ubuf.litInner - kr, 0.0, 1.0);
            glassMask = 1.0;
        }
    }

    // ── The eye: six lobes and a centre ─────────────────────────────────
    if (glassMask == 0.0 && r < 0.23) {
        float lobeK = floor(mod(th + PI / 6.0, TAU) / (PI / 3.0));
        float la = lobeK * PI / 3.0;
        vec2 lc = vec2(sin(la), -cos(la)) * 0.12;
        float dl = length(p - lc);
        if (r < 0.065) {
            glass = paneColour(vec2(0.0), 1.0);
            leadLine = smoothstep(lead, lead - px, 0.065 - r);
            glassMask = 1.0;
        } else if (dl < 0.085) {
            glass = paneColour(lc, lobeK * 2.0 + 3.0);
            leadLine = smoothstep(lead, lead - px, 0.085 - dl);
            glassMask = 1.0;
        }
        lightOn = 1.0;
    }

    // ── Tracery and the stone ring ──────────────────────────────────────
    float inside = smoothstep(1.0 + px, 1.0 - px, r);
    vec3 stone = ubuf.stoneColor.rgb * (0.22 + 0.08 * noise(p * 40.0) + 0.05 * noise(p * 7.0));
    // Lit from above: the upper half of every ring a shade brighter.
    stone *= 0.9 + 0.2 * smoothstep(0.4, -0.6, p.y);
    // The outer ring stands proud; grooves cut round the rings of glass.
    float ring = smoothstep(0.93 - px, 0.93 + px, r);
    stone *= 1.0 + ring * 0.45;
    float groove = 0.0;
    groove = max(groove, smoothstep(px * 1.4, 0.0, abs(r - 0.965)));
    groove = max(groove, smoothstep(px * 1.4, 0.0, abs(r - 0.455)));
    groove = max(groove, smoothstep(px * 1.4, 0.0, abs(r - 0.255)));
    stone *= 1.0 - groove * 0.55;
    // A highlight just outside each groove, as on carved stone.
    float lip = max(max(smoothstep(px * 1.6, 0.0, abs(r - 0.965 - px * 2.0)), smoothstep(px * 1.6, 0.0, abs(r - 0.455 - px * 2.0))), smoothstep(px * 1.6, 0.0, abs(r - 0.255 - px * 2.0)));
    stone *= 1.0 + lip * 0.35;
    col = stone;
    alpha = inside;

    if (glassMask > 0.0) {
        // Old glass: uneven, streaked, thicker at the bottom of each pane.
        float streak = 0.82 + 0.3 * noise(p * vec2(26.0, 9.0)) - 0.12 * noise(p * 70.0);
        float light = mix(0.24, 1.0, lightOn * ubuf.glow);
        vec3 g = glass * streak * light;
        // Light through: a hot core when fully lit.
        g += glass * lightOn * ubuf.glow * 0.25 * smoothstep(0.9, 0.3, r);
        col = mix(g, ubuf.leadColor.rgb, leadLine);
    }

    // ── Bloom ───────────────────────────────────────────────────────────
    vec3 white = vec3(1.0, 0.95, 0.82);
    col = mix(col, white, ubuf.bloom * (glassMask > 0.0 ? 0.75 : 0.35));
    float halo = ubuf.bloom * exp(-(r - 1.0) * 5.0) * step(1.0, r);
    col = mix(col, white, halo * (1.0 - inside));
    alpha = max(alpha, halo * 0.8);

    fragColor = vec4(col * alpha, alpha) * ubuf.qt_Opacity;
}
