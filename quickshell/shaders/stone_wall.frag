#version 440
// The parapet of the Siege power menu (modules/power/SiegePower.qml): a
// wall of ashlar under the moon, its top cut into battlements, each stone
// a little different, the mortar sunk between them, grit and chips on the
// faces, the merlons' tops catching the moonlight and the stone warmed
// round each torch standing on it (up to six, px within the item).
// Premultiplied; clear above the battlements.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float merlon;      // px
    float depth;       // px from the merlons' tops to the crenels' floors
    float course;      // px, the height of a course of stones
    float light;       // 0..1 the torches
    float reach;       // px
    vec4 torchA;       // two torches: x, y, x, y
    vec4 torchB;
    vec4 torchC;
    vec4 stoneColor;   // opaque
    vec4 moonColor;    // opaque
    vec4 fireColor;    // opaque
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

float warmth(vec2 px, vec2 t) {
    vec2 d = (px - t) / ubuf.reach;
    return exp(-dot(d, d));
}

void main() {
    vec2 size = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 px = qt_TexCoord0 * size;

    // Battlements: merlons and the crenels between them, centred.
    float m = ubuf.merlon;
    float period = m * 1.65;
    float sx = px.x - size.x * 0.5 + m * 0.5;
    float f = sx - floor(sx / period) * period;
    bool onMerlon = f < m;
    float topY = onMerlon ? 0.0 : ubuf.depth;
    if (px.y < topY) {
        fragColor = vec4(0.0);
        return;
    }

    // Ashlar: courses of stones, every other one set over by half a stone;
    // the merlons' own stones line up with them.
    float row = floor(px.y / ubuf.course);
    float w = ubuf.course * 2.1;
    float off = mod(row, 2.0) * 0.5 * w;
    float col = floor((px.x + off) / w);
    vec2 cell = vec2(col, row);
    vec2 inCell = vec2(px.x + off - col * w, px.y - row * ubuf.course);
    float mortar = 1.0 - smoothstep(1.0, 3.0, min(min(inCell.x, w - inCell.x), min(inCell.y, ubuf.course - inCell.y)));
    float stone = 0.78 + 0.34 * hash(cell);
    float grit = noise(px * 0.35) * 0.5 + noise(px * 0.09 + cell) * 0.5;
    vec3 c = ubuf.stoneColor.rgb * stone * (0.82 + 0.3 * grit);
    c = mix(c, ubuf.stoneColor.rgb * 0.25, mortar * 0.85);
    // Chips knocked out of the faces.
    c *= 1.0 - 0.35 * smoothstep(0.82, 0.9, noise(px * 0.06 + cell * 3.1));

    // Moonlight on the tops, the face falling into shadow below.
    float edge = 1.0 - smoothstep(0.0, 5.0, px.y - topY);
    c = mix(c, ubuf.moonColor.rgb * 0.6, edge * 0.5);
    c *= mix(0.9, 0.3, smoothstep(0.0, size.y, px.y));

    // The torches' warmth.
    float t = warmth(px, ubuf.torchA.xy) + warmth(px, ubuf.torchA.zw) + warmth(px, ubuf.torchB.xy)
        + warmth(px, ubuf.torchB.zw) + warmth(px, ubuf.torchC.xy) + warmth(px, ubuf.torchC.zw);
    c += ubuf.fireColor.rgb * c * t * 1.6 * ubuf.light;

    // Antialias the battlement edges.
    float aa = smoothstep(topY - 0.5, topY + 1.0, px.y);
    fragColor = vec4(c, 1.0) * aa * ubuf.qt_Opacity;
}
