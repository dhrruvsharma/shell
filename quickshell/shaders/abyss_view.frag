#version 440
// The view from the bathysphere's porthole (the "Bathysphere" lock): the
// wallpaper drowned in deep water, swimming a little, with light fingering
// down from far above, marine snow drifting past at three depths, and the
// lights of the deep: up to sixteen creatures that wake one keystroke at a
// time (`lit`), each a glowing lure with a trail of photophores, pulsing.
// A sonar ping spreads across the glass on each keystroke (`ping`); blowing
// the ballast (`rise`) fills the water with light and bubbles; a leak
// (`leak`) streams bubbles up from the rim. Drawn in a square round the
// porthole; the glass is the inscribed circle. Animated by `time` (the lock
// context's ambient clock, which stops while the screen dozes).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float lit;         // creatures awake, 0..16
    float ping;        // 0..1 the last ping spreading
    float rise;        // 0..1 blowing the ballast
    float leak;        // 0..1 a leak at the rim
    float shade;       // 0 shallows .. 1 the trenches
    vec4 wallRect;     // the wallpaper behind the porthole: uv offset, size
    vec4 glowColor;
    vec4 lumeColor;
    vec4 waterColor;
} ubuf;

layout(binding = 1) uniform sampler2D wall;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Bubbles in a grid of cells `g` moving up: some cells hold one, placed and
// sized at random, drawn as a ring.
float bubbles(vec2 g, float sparse) {
    vec2 cell = floor(g);
    vec2 o = hash2(cell + 5.0) * 0.5 - 0.25;
    float rr = 0.08 + 0.16 * hash(cell + 3.0);
    float d = abs(length(fract(g) - 0.5 - o) - rr);
    return step(sparse, hash(cell)) * smoothstep(0.05, 0.0, d);
}

// Flecks drifting down through a layer of water.
float snow(vec2 q, float scale, float speed, float seed) {
    vec2 g = (q + vec2(sin(ubuf.time * 0.1 + seed) * 0.05, -ubuf.time * speed)) * scale;
    vec2 cell = floor(g);
    float on = step(0.86, hash(cell + seed));
    return on * smoothstep(0.16, 0.0, length(fract(g) - hash2(cell + seed * 3.0) * 0.8 - 0.1));
}

void main() {
    vec2 q = (qt_TexCoord0 - 0.5) * 2.0;       // the glass is |q| < 1
    float r = length(q);
    float t = ubuf.time;
    float glass = smoothstep(1.0, 0.985, r);
    if (glass <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    // The wallpaper out there, swimming.
    vec2 swim = vec2(sin(q.y * 5.0 + t * 0.8), cos(q.x * 4.0 + t * 0.6)) * 0.004;
    vec2 wuv = ubuf.wallRect.xy + clamp(qt_TexCoord0 + swim, 0.0, 1.0) * ubuf.wallRect.zw;
    vec3 w = texture(wall, wuv).rgb;
    float path = mix(0.9, 3.0, ubuf.shade) + q.y * 0.35;
    vec3 through = exp(-vec3(0.6, 0.17, 0.09) * path * 1.3);
    vec3 col = w * through * mix(0.75, 0.3, ubuf.shade) + ubuf.waterColor.rgb * (1.0 - exp(-0.9 * path)) * mix(0.85, 0.35, ubuf.shade);

    // Light fingering down from far above, swaying.
    vec2 src = vec2(-0.3, -2.2);
    float ang = atan(q.x - src.x, q.y - src.y);
    float rays = pow(noise(vec2(ang * 11.0 + t * 0.05, 0.3)), 3.0) + pow(noise(vec2(ang * 23.0 - t * 0.04, 4.1)), 4.0) * 0.6;
    col += vec3(0.75, 0.95, 0.95) * rays * smoothstep(1.0, -0.8, q.y) * mix(0.16, 0.04, ubuf.shade);

    // Marine snow at three depths.
    float fl = snow(q, 11.0, 0.012, 1.0) * 0.5 + snow(q, 19.0, 0.02, 7.0) * 0.35 + snow(q, 32.0, 0.03, 13.0) * 0.25;
    col += mix(vec3(0.8), ubuf.lumeColor.rgb, 0.4) * fl * mix(0.5, 0.25, ubuf.shade);

    // The lights of the deep.
    for (int i = 0; i < 16; i++) {
        float fi = float(i);
        float l = clamp(ubuf.lit - fi, 0.0, 1.0);
        if (l <= 0.0)
            continue;
        vec2 h = hash2(vec2(fi, 7.3));
        float a = h.x * 6.2831853;
        float rad = 0.2 + 0.62 * sqrt(h.y);
        vec2 pos = vec2(cos(a), sin(a)) * rad + vec2(sin(t * 0.21 + fi), cos(t * 0.17 + fi * 1.3)) * 0.025;
        float pulse = 0.72 + 0.28 * sin(t * (1.1 + h.y * 1.4) + fi * 2.1);
        vec3 tint = mod(fi, 3.0) < 1.5 ? ubuf.glowColor.rgb : ubuf.lumeColor.rgb;
        float dd = length(q - pos);
        float glow = exp(-dd * 42.0) * 1.5 + exp(-dd * 9.0) * 0.4;
        // A trail of photophores behind the lure.
        vec2 dir = normalize(vec2(cos(a + 1.9), sin(a + 1.9)));
        for (int j = 1; j < 4; j++) {
            vec2 tp = pos + dir * 0.035 * float(j) + vec2(0.0, sin(t * 0.8 + fi + float(j)) * 0.006);
            glow += exp(-length(q - tp) * 90.0) * 0.7;
        }
        col += tint * glow * l * pulse;
    }

    // The ping, spreading.
    float pr = ubuf.ping * 1.35;
    float ring = exp(-abs(r - pr) * 38.0) * (1.0 - ubuf.ping) * step(0.001, ubuf.ping);
    col += ubuf.lumeColor.rgb * ring * 0.55;

    // Blowing the ballast: light pours down and bubbles rush up.
    float bub = bubbles(vec2(q.x * 9.0, q.y * 9.0 + t * 4.0), 0.7);
    col += vec3(0.85, 1.0, 1.0) * bub * ubuf.rise * 0.6;
    col += vec3(0.7, 0.95, 0.95) * ubuf.rise * smoothstep(0.9, -1.2, q.y) * 0.45;

    // A leak: bubbles streaming up from the upper right of the rim.
    float lb = bubbles(vec2((q.x - 0.62 + sin(q.y * 7.0 + t * 3.0) * 0.02) * 22.0, q.y * 14.0 + t * 6.0), 0.55);
    col += vec3(0.85, 1.0, 1.0) * lb * ubuf.leak * smoothstep(0.35, 0.0, abs(q.x - 0.62)) * 0.8;

    // The glass: a sheen at the top left, darker towards the rim.
    col += vec3(1.0) * smoothstep(0.55, 0.0, length(q - vec2(-0.42, -0.5))) * 0.035;
    col += vec3(1.0) * smoothstep(0.02, 0.0, abs(r - 0.9)) * smoothstep(0.2, -0.8, q.x + q.y) * 0.05;
    col *= 1.0 - smoothstep(0.7, 1.0, r) * 0.4;

    fragColor = vec4(col * glass, glass) * ubuf.qt_Opacity;
}
