#version 440
// A world of the Astral power menu's orrery (modules/power/CosmosPower.qml):
// a sphere lit from `lightDir` (towards the system's star, so every world
// shows its day side to it), banded like a gas giant by `bands`, pocked
// like a moon by `craters`, with a thin atmosphere on its limb, an
// optional ring tilted towards us (its far side hidden behind the globe),
// and a halo when pointed at (`glow`). The globe's radius is `radius` px;
// the rest of the item is room for the ring and the halo. Premultiplied.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float radius;      // px
    float bands;       // 0..1
    float craters;     // 0..1
    float ring;        // 0..1
    float glow;        // 0..1
    float seed;
    vec2 lightDir;     // screen space, towards the star
    vec4 baseColor;    // opaque
    vec4 bandColor;    // opaque
    vec4 airColor;     // opaque
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

vec4 over(vec4 top, vec4 under) {
    return top + under * (1.0 - top.a);
}

void main() {
    vec2 size = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 p = (qt_TexCoord0 - 0.5) * size;
    float R = ubuf.radius;
    float r = length(p);
    vec3 L = normalize(vec3(ubuf.lightDir.x, ubuf.lightDir.y, 0.45));

    // The ring: an ellipse in the plane, tilted towards us.
    vec4 ringBack = vec4(0.0);
    vec4 ringFront = vec4(0.0);
    if (ubuf.ring > 0.0) {
        vec2 q = vec2(p.x, p.y / 0.32) / R;
        float rho = length(q);
        float inRing = smoothstep(1.32, 1.36, rho) * (1.0 - smoothstep(2.05, 2.12, rho));
        float lanes = 0.7 + 0.3 * sin(rho * 38.0 + ubuf.seed);
        float lit = 0.55 + 0.45 * max(0.0, dot(normalize(vec2(p.x, p.y + 0.001)), ubuf.lightDir));
        vec3 rc = mix(ubuf.bandColor.rgb, vec3(0.92, 0.88, 0.8), 0.45) * lanes * lit;
        float a = inRing * 0.85 * ubuf.ring;
        // In front of the globe below its centre line, behind it above.
        if (p.y >= 0.0)
            ringFront = vec4(rc * a, a);
        else
            ringBack = vec4(rc * a, a);
    }

    vec4 globe = vec4(0.0);
    if (r < R + 1.0) {
        vec2 s = p / R;
        float z = sqrt(max(0.0, 1.0 - dot(s, s)));
        vec3 n = vec3(s, z);
        float diff = max(0.0, dot(n, L));
        // Latitude bands, wavering.
        float lat = s.y * 7.0 + (noise(vec2(s.x * 3.0 + ubuf.seed, s.y * 9.0)) - 0.5) * 1.6;
        float band = 0.5 + 0.5 * sin(lat * 3.14159 + ubuf.seed * 3.0);
        vec3 albedo = mix(ubuf.baseColor.rgb, ubuf.bandColor.rgb, band * ubuf.bands);
        // Craters and mottling.
        float m = noise(s * 6.0 + ubuf.seed * 7.0) * 0.6 + noise(s * 13.0 + ubuf.seed) * 0.4;
        albedo *= 1.0 - ubuf.craters * 0.35 * smoothstep(0.55, 0.8, m);
        vec3 col = albedo * (0.06 + 1.0 * diff);
        // Air on the limb, brightest on the day side.
        float limb = pow(1.0 - z, 2.4);
        col += ubuf.airColor.rgb * limb * (0.2 + 0.8 * smoothstep(-0.2, 0.6, dot(n.xy, L.xy))) * 0.7;
        float a = 1.0 - smoothstep(R - 1.0, R + 0.5, r);
        globe = vec4(col * a, a);
    }

    // The halo of a world pointed at.
    float edge = min(size.x, size.y) * 0.5;
    float halo = ubuf.glow * exp(-max(0.0, r - R) / (R * 0.7)) * 0.55 * step(R, r) * (1.0 - smoothstep(edge * 0.7, edge, r));
    vec4 glowC = vec4(ubuf.airColor.rgb * halo, halo);

    vec4 col = over(ringFront, over(globe, over(ringBack, glowC)));
    fragColor = col * ubuf.qt_Opacity;
}
