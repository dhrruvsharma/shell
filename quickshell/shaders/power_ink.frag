#version 440
// The Cave Abode power menu's night (modules/power/XianxiaPower.qml): the
// grabbed desktop sinks into an ink-wash painting by moonlight, its lights
// turned to mist and its darks to ink, while ink bleeds in from the edges
// along a broken line, mist banks drift low in the valleys and motes of qi
// rise through the dark. `amount` takes it there (0: the desktop as it was).
// `dissolve` then eats the picture away from `origin` into plain ink, the
// front burning with a thin gold rim (a burned talisman's spell taking
// hold). Opaque.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float amount;      // 0..1 the desktop into the night
    float dissolve;    // 0..1 into plain ink from `origin`
    float time;        // seconds, for the mist and the motes
    vec2 origin;       // normalised
    vec4 inkColor;     // opaque
    vec4 mistColor;    // opaque
    vec4 goldColor;    // opaque
    vec4 moteColor;    // opaque
} ubuf;

layout(binding = 1) uniform sampler2D source;

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

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 uv = qt_TexCoord0;
    float aspect = res.x / res.y;
    float a = ubuf.amount;
    float t = ubuf.time;

    vec3 src = texture(source, uv).rgb;

    // The picture as an ink painting: its darks in ink, its lights in mist,
    // by moonlight.
    float lum = dot(src, vec3(0.299, 0.587, 0.114));
    vec3 wash = mix(ubuf.inkColor.rgb, ubuf.mistColor.rgb, pow(smoothstep(0.04, 1.0, lum), 1.3) * 0.46);
    // a breath of the picture's own colour left in it
    wash = mix(wash, src * 0.4, 0.1);
    // Night deepest overhead.
    wash *= mix(0.72, 1.0, smoothstep(0.0, 0.7, uv.y));
    // A pool of shadow where the talismans hang, so they and their names
    // stand out.
    vec2 pc = (uv - vec2(0.5, 0.42)) * vec2(aspect * 0.9, 1.6);
    wash *= 1.0 - 0.38 * exp(-dot(pc, pc) * 2.2);
    vec3 col = mix(src, wash, a);

    // Ink bleeding in from the edges, the front spreading as it comes.
    vec2 c = uv - 0.5;
    c.x *= aspect;
    float n = fbm(uv * 3.0 + 3.0);
    float edge = smoothstep(0.42, 1.05, length(c) + (n - 0.5) * 0.42 + (1.0 - a) * 0.5);
    col = mix(col, ubuf.inkColor.rgb, edge * a * 0.94);

    // Mist banks in the valleys, drifting very slowly.
    vec2 mp = uv * vec2(2.2, 5.0) + vec2(t * 0.008, 0.0);
    float m = fbm(mp);
    float m2 = fbm(uv * vec2(4.6, 8.0) + vec2(7.0 - t * 0.012, 7.0));
    float bank = smoothstep(0.46, 0.86, m * 0.7 + m2 * 0.3);
    float depth = 0.05 + 0.5 * smoothstep(0.45, 1.0, uv.y);
    col = mix(col, ubuf.mistColor.rgb * 0.62, bank * depth * a);

    // Into plain ink, from the origin out, behind a thin gold rim.
    if (ubuf.dissolve > 0.0) {
        vec2 o = ubuf.origin;
        vec2 d2 = uv - o;
        d2.x *= aspect;
        // Ink spreading through wet paper: a soft, fingered edge.
        vec2 w = uv + (vec2(fbm(uv * 2.0 + 5.0), fbm(uv * 2.0 + 9.0)) - 0.5) * 0.12;
        float d = length(d2) + (fbm(w * 2.6 + 11.0) - 0.5) * 0.3 + (fbm(w * 11.0) - 0.5) * 0.05;
        float front = ubuf.dissolve * 2.0 - 0.1;
        float behind = 1.0 - smoothstep(front - 0.05, front + 0.02, d);
        col = mix(col, ubuf.inkColor.rgb * 0.55, behind);
        float rim = exp(-abs(d - front) * 150.0) * (1.0 - smoothstep(0.55, 0.9, ubuf.dissolve));
        col += ubuf.goldColor.rgb * rim * 0.3;
    }

    // Motes of qi rising through the dark, a few of them always.
    vec2 p = vec2(uv.x * aspect, uv.y + t * 0.012) * 15.0;
    vec2 cell = floor(p);
    float h = hash(cell + 3.0);
    if (h > 0.86) {
        vec2 jitter = vec2(hash(cell + 7.0), hash(cell + 13.0)) - 0.5;
        vec2 f = fract(p) - 0.5 - jitter * 0.6 - vec2(sin(t * 0.6 + h * 40.0) * 0.08, 0.0);
        float dm = length(f);
        float twinkle = 0.55 + 0.45 * sin(t * (1.0 + h * 2.0) + h * 60.0);
        float glow = smoothstep(0.055, 0.0, dm) + smoothstep(0.2, 0.0, dm) * 0.3;
        col += ubuf.moteColor.rgb * glow * a * twinkle * (0.45 + 0.55 * hash(cell + 21.0));
    }

    fragColor = vec4(col, 1.0) * ubuf.qt_Opacity;
}
