#version 440

// Lock screen tile-wave transition.
//
// The captured desktop is cut into square tiles that shrink and spin away in a
// wave spreading out from `origin` as progress runs 0 -> 1, uncovering whatever
// is drawn underneath (the lock HUD). Running progress back to 0 reassembles
// the capture. With `inward` = 1 the wave order is flipped, so on the way back
// the tiles return centre-first.
//
// `desat` greys the capture out (the "game paused" look); tiles in flight get
// a rim of `edgeColor` scaled by `edgeStrength`.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;     // 0 = intact capture, 1 = every tile gone
    float desat;        // 0..1
    float tileSize;     // px
    float inward;       // 1 = wave runs from the edges in towards origin
    float edgeStrength; // 0..1
    float itemWidth;
    float itemHeight;
    vec2 origin;        // wave origin, normalised item coordinates
    vec4 edgeColor;     // opaque
} ubuf;

layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 px = qt_TexCoord0 * res;
    float ts = max(ubuf.tileSize, 4.0);
    vec2 cell = floor(px / ts);
    vec2 centre = (cell + 0.5) * ts;

    // Distance of this tile from the origin: 0 at the origin, 1 at the farthest corner.
    vec2 o = ubuf.origin * res;
    float reach = max(length(max(o, res - o)), 1.0);
    float d = clamp(length(centre - o) / reach, 0.0, 1.0);
    if (ubuf.inward > 0.5)
        d = 1.0 - d;

    // Each tile animates inside its own `span` of the timeline, staggered by
    // distance plus a little per-tile noise so the wave front looks organic.
    const float span = 0.42;
    float delay = clamp(d * 0.88 + hash(cell) * 0.12, 0.0, 1.0) * (1.0 - span);
    float t = clamp((ubuf.progress - delay) / span, 0.0, 1.0);
    float e = t * t * (3.0 - 2.0 * t);
    float s = 1.0 - e;

    if (s <= 0.002) {
        fragColor = vec4(0.0);
        return;
    }

    // Inverse-transform this pixel into the tile's own (rotated, scaled) frame.
    // The spin grows with e, so a tile never pokes out of its cell while it is
    // still near full size.
    float spin = (hash(cell + 17.0) - 0.5) * 1.1 * e;
    float c = cos(spin);
    float sn = sin(spin);
    vec2 rel = px - centre;
    rel = vec2(c * rel.x + sn * rel.y, -sn * rel.x + c * rel.y) / s;

    float hs = ts * 0.5;
    if (abs(rel.x) > hs || abs(rel.y) > hs) {
        fragColor = vec4(0.0);
        return;
    }

    vec4 col = texture(source, (centre + rel) / res);
    float lum = dot(col.rgb, vec3(0.2126, 0.7152, 0.0722));
    col.rgb = mix(col.rgb, vec3(lum) * col.a, ubuf.desat);

    // Glowing rim on tiles that are in flight, fading as they vanish.
    float edge = max(abs(rel.x), abs(rel.y)) / hs;
    float rim = smoothstep(0.74, 1.0, edge) * smoothstep(0.0, 0.12, e) * (1.0 - e);
    col.rgb = mix(col.rgb, ubuf.edgeColor.rgb * col.a, clamp(rim * ubuf.edgeStrength, 0.0, 1.0));
    col.rgb *= 1.0 - 0.45 * e;

    fragColor = col * ubuf.qt_Opacity;
}
