#version 440
// A field of susuki, the silver grass of the Ashina Reservoir, for the
// Sekiro lock and power menu: stalks dark against the night, their plumes
// catching the moonlight, two depths of them, swaying in the wind (`time`,
// `wind`; a `gust` bends the whole field at once). `rise` brings the field
// up from below the screen's foot. Premultiplied.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float time;
    float rise;    // 0..1
    float wind;    // sway, 0..1
    float gust;    // -1..1, the whole field bent at once
    float unit;    // layout scale (1 on a 1920 px wide screen)
    vec4 stalkColor;
    vec4 plumeColor;
} ubuf;

float hash1(float x) {
    return fract(sin(x * 12.9898) * 43758.5453);
}

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x),
               mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

// One depth of the field: blades about `pitch` px apart, up to `tall` px
// high. Each is a thin stalk curving with the wind and, on most, a plume
// over its top: a silky tuft that droops further the way it leans.
// Returns premultiplied colour and alpha.
vec4 field(vec2 px, float pitch, float tall, float seed, float shade) {
    vec4 acc = vec4(0.0);
    float h = ubuf.itemHeight;
    float k0 = floor(px.x / pitch);
    for (int j = -4; j <= 4; j++) {
        float k = k0 + float(j);
        float r1 = hash1(k * 1.13 + seed);
        float r2 = hash1(k * 2.71 + seed * 3.1);
        float r3 = hash1(k * 0.37 + seed * 7.7);
        float height = tall * (0.4 + 0.6 * r1);
        float baseX = (k + 0.15 + 0.7 * r2) * pitch;
        float up = (h - px.y) / height;
        if (up < 0.0 || up > 1.2)
            continue;
        float sway = sin(ubuf.time * (0.8 + 0.5 * r3) + k * 0.7 + seed) * 0.6 + sin(ubuf.time * 2.1 + k * 1.9) * 0.15;
        float lean = (r3 - 0.5) * 0.4 + ubuf.gust * 0.7 + sway * ubuf.wind * 0.22;
        float x = baseX + lean * height * up * up * 0.55;
        float d = px.x - x;
        // The stalk, thinning to the tip.
        float w = mix(1.3, 0.35, clamp(up, 0.0, 1.0)) * (pitch / 8.0);
        float stalk = smoothstep(w + 0.6, w - 0.6, abs(d)) * step(up, 1.0);
        // The plume over the top fifth, on three blades in four.
        float t = clamp((up - 0.74) / 0.42, 0.0, 1.0);
        float has = step(0.25, r2);
        float droop = lean * height * 0.32 * t * t;
        float dp = px.x - (x + droop);
        float plumeW = (1.0 + 5.5 * pow(sin(t * 3.14159), 0.7)) * (pitch / 8.0) * (0.75 + 0.5 * r1);
        float feather = smoothstep(plumeW + 0.8, plumeW - 1.2, abs(dp)) * step(0.74, up) * step(up, 1.16) * has;
        // Silky: fine hairs along it.
        feather *= 0.55 + 0.45 * noise(vec2(dp * 0.9 + k * 7.0, px.y * 0.07));
        float a = max(stalk * 0.95, feather * 0.7);
        vec3 sc = mix(ubuf.stalkColor.rgb, ubuf.plumeColor.rgb * 0.35, clamp(up, 0.0, 1.0) * 0.5) * shade;
        vec3 pc = ubuf.plumeColor.rgb * (0.7 + 0.3 * r2) * shade;
        vec3 col = feather > stalk ? pc : sc;
        acc.rgb = acc.rgb * (1.0 - a) + col * a;
        acc.a = acc.a + a * (1.0 - acc.a);
    }
    return acc;
}

void main() {
    vec2 px = qt_TexCoord0 * vec2(ubuf.itemWidth, ubuf.itemHeight);
    // Risen from below.
    px.y += (1.0 - clamp(ubuf.rise, 0.0, 1.0)) * ubuf.itemHeight;
    float u = max(ubuf.unit, 0.05);
    vec4 back = field(px + vec2(37.0, 0.0), 7.0 * u, ubuf.itemHeight * 0.6, 1.7, 1.2);
    back.rgb *= 0.7;
    back.a *= 0.7;
    vec4 front = field(px, 11.0 * u, ubuf.itemHeight * 0.92, 4.3, 0.9);
    // A dark band at the foot, the ground the grass grows from.
    float ground = smoothstep(ubuf.itemHeight * 0.82, ubuf.itemHeight, px.y) * 0.85;
    vec4 col = back;
    col = vec4(col.rgb * (1.0 - front.a) + front.rgb, front.a + col.a * (1.0 - front.a));
    col = vec4(col.rgb * (1.0 - ground) + ubuf.stalkColor.rgb * 0.6 * ground, ground + col.a * (1.0 - ground));
    fragColor = col * ubuf.qt_Opacity;
}
