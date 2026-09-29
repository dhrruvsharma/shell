#version 440
// Inside the bathysphere (the "Bathysphere" lock): painted steel lit only by
// what comes through the porthole, plate seams across it, and the porthole
// itself: a heavy steel ring on a rubber gasket, held by sixteen bolts. The
// glass (r < radius) is left clear for the view (abyss_view.frag) under it.
// Static: the lock caches it in a layer.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    vec2 centre;       // the porthole, px
    float radius;      // its glass, px
    float unit;        // the lock's scale: plates and grain keep their size
    vec4 steelColor;
    vec4 glowColor;
} ubuf;

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

// A hexagon of circumradius `r`.
float hexagon(vec2 p, float r) {
    const vec3 k = vec3(-0.866025404, 0.5, 0.577350269);
    p = abs(p);
    p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
    p -= vec2(clamp(p.x, -k.z * r, k.z * r), r);
    return length(p) * sign(p.y);
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 px = qt_TexCoord0 * res;
    vec2 d = px - ubuf.centre;
    // Pattern space: design pixels.
    vec2 pp = px / max(ubuf.unit, 0.05);
    float r = length(d);
    float R = ubuf.radius;
    float outer = R * 1.22;
    vec2 n = d / max(r, 1.0);
    vec2 lightDir = normalize(vec2(-0.55, -0.83));

    // ── The hull ─────────────────────────────────────────────────────────────
    float grain = noise(pp / 190.0) * 0.5 + noise(pp / 45.0) * 0.3 + noise(pp / 7.0) * 0.2;
    vec3 steel = ubuf.steelColor.rgb * (0.7 + 0.35 * grain);
    // What light there is comes through the glass.
    float fall = exp(-max(r - outer, 0.0) / (R * 1.5));
    vec3 hull = steel * (0.4 + 0.9 * fall) + ubuf.glowColor.rgb * fall * 0.035;
    // Plate seams: the curved plates of the sphere, bands across it.
    float seamY = abs(fract(pp.y / 300.0 + 0.3) - 0.5) * 300.0 * ubuf.unit;
    float seamX = abs(fract(pp.x / 460.0 + 0.1) - 0.5) * 460.0 * ubuf.unit;
    float seam = max(smoothstep(2.5, 0.5, seamY), smoothstep(2.5, 0.5, seamX) * step(0.5, fract(pp.y / 600.0 + 0.45)));
    float lip = max(smoothstep(4.0, 2.5, seamY) * step(2.5, seamY), 0.0);
    hull *= 1.0 - seam * 0.45;
    hull *= 1.0 + lip * 0.25;
    // The sphere curves away from us at the edges.
    vec2 c = qt_TexCoord0 - 0.5;
    hull *= 1.0 - smoothstep(0.35, 0.95, length(c * vec2(res.x / res.y, 1.0))) * 0.6;

    vec3 col = hull;
    float alpha = 1.0;

    // ── The ring ─────────────────────────────────────────────────────────────
    if (r < outer + 2.0) {
        float t = clamp((r - R) / (outer - R), 0.0, 1.0);
        // A rounded section: facing up to the light on its outer half.
        float slope = cos(t * 3.14159265);
        float lit = dot(n, lightDir) * slope;
        vec3 ring = ubuf.steelColor.rgb * 2.2 * (0.62 + 0.55 * lit) * (0.9 + 0.2 * noise(vec2(atan(d.y, d.x) * 40.0, t * 3.0)));
        // A groove round the middle, and the gasket at the glass.
        ring *= 1.0 - smoothstep(0.03, 0.0, abs(t - 0.5)) * 0.45;
        ring = mix(ring, vec3(0.03, 0.035, 0.04), smoothstep(0.1, 0.06, t));
        // The bolts.
        float ang = atan(d.y, d.x);
        float k = floor(ang / (TAU / 16.0) + 0.5);
        float ba = k * TAU / 16.0;
        vec2 bc = ubuf.centre + vec2(cos(ba), sin(ba)) * R * 1.11;
        vec2 bp = px - bc;
        float br = R * 0.034;
        float bolt = 1.0 - smoothstep(-1.0, 1.0, hexagon(vec2(bp.x * cos(ba) + bp.y * sin(ba), -bp.x * sin(ba) + bp.y * cos(ba)), br));
        float boltLit = 0.65 + 0.5 * dot(normalize(bp + vec2(1e-3)), lightDir);
        ring = mix(ring, ubuf.steelColor.rgb * 2.6 * boltLit, bolt);
        float edge = smoothstep(outer + 1.5, outer - 0.5, r) * smoothstep(R - 1.0, R + 1.0, r);
        col = mix(col, ring, edge);
        // A shadow the ring throws on the hull.
        col *= 1.0 - smoothstep(outer + 22.0, outer, r) * step(outer, r) * 0.35;
        alpha = smoothstep(R - 1.0, R + 1.0, r);
    }

    fragColor = vec4(col * alpha, alpha) * ubuf.qt_Opacity;
}
