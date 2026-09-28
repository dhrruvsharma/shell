#version 440
// Cathedral over the wallpaper: shafts of coloured light falling from a
// high window of four lancets up to the left, each shaft taking the colours
// of the panes it came through, dust hanging in the light, candlelight
// warming the foot of the screen, and stone shadow gathering in the vault
// above. Output is premultiplied and translucent. Nothing depends on time;
// `light` (0..1) plays the switch-on: the shafts reach down as the light
// comes in.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float light;       // 0..1
    float lineScale;   // >1 enlarges dust in small previews
    vec4 glassA;       // opaque: the panes
    vec4 glassB;
    vec4 glassC;
    vec4 glassD;
    vec4 stoneColor;   // opaque, shadow
    vec4 candleColor;  // opaque
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

vec4 over(vec4 dst, vec3 rgb, float a) {
    return vec4(rgb * a + dst.rgb * (1.0 - a), a + dst.a * (1.0 - a));
}

vec3 pane(float i) {
    float k = mod(i, 4.0);
    return k < 1.0 ? ubuf.glassA.rgb : k < 2.0 ? ubuf.glassC.rgb : k < 3.0 ? ubuf.glassB.rgb : ubuf.glassD.rgb;
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * res;
    float W = res.x, H = res.y;
    vec4 col = vec4(0.0);

    // ── Shafts ──────────────────────────────────────────────────────────
    // Light slants down to the right; x0 is where a shaft crosses the top
    // edge, t how far down it has come. Light adds to what's beneath
    // (premultiplied with no coverage), so it brightens rather than veils.
    vec2 dir = normalize(vec2(0.5, 1.0));
    float x0 = px.x - px.y * dir.x / dir.y;
    float t = px.y / dir.y;
    // The window: four lancets side by side, mullions between them; the
    // shafts spread a little as they fall.
    float spread = 1.0 + t / (H * 3.0);
    float wx = (x0 - W * 0.02) / (W * 0.5 * spread);
    float lancet = floor(wx * 4.0);
    float inL = fract(wx * 4.0);
    float soft = 0.1 + 0.12 * smoothstep(0.0, H, t);
    float open = step(0.0, wx) * step(wx, 1.0) * smoothstep(0.0, soft, inL) * smoothstep(1.0, 1.0 - soft, inL);
    // Each lancet's glass: three panes across, blending into each other.
    float q = inL * 3.0 - 0.5;
    float k = floor(q);
    float m = smoothstep(0.3, 0.7, fract(q));
    vec3 glass = mix(pane(lancet * 3.0 + k + floor(lancet / 2.0)), pane(lancet * 3.0 + k + 1.0 + floor(lancet / 2.0)), m);
    // Unevenness along the shaft, as through old glass and dust.
    float haze = 0.7 + 0.3 * noise(vec2(x0 / 34.0, t / 240.0));
    float reach = H * 1.1 * ubuf.light;
    float fall = smoothstep(0.0, 90.0, t) * (1.0 - smoothstep(reach * 0.25, reach, t));
    float shaft = open * fall * haze;
    col.rgb += mix(glass, vec3(1.0), 0.2) * shaft * 0.16;

    // ── Dust in the light ───────────────────────────────────────────────
    float s = ubuf.lineScale;
    vec2 cell = floor(px / (9.0 * s));
    vec2 f = fract(px / (9.0 * s)) - 0.5;
    float mote = step(0.972, hash(cell)) * smoothstep(0.26, 0.06, length(f + (vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5) * 0.4));
    col.rgb += mix(glass, vec3(1.0), 0.6) * mote * shaft * 0.8;

    // ── Candlelight at the foot ─────────────────────────────────────────
    vec2 a = (px - vec2(W * 0.08, H * 1.02)) / H;
    vec2 b = (px - vec2(W * 0.92, H * 1.02)) / H;
    float candle = exp(-dot(a, a) * 9.0) + exp(-dot(b, b) * 9.0);
    col.rgb += ubuf.candleColor.rgb * candle * 0.12 * ubuf.light;

    // ── Stone shadow: the vault above, the aisles to the sides ──────────
    vec2 c = uv - 0.5;
    c.x *= W / H;
    float shade = smoothstep(0.42, 1.1, length(c * vec2(1.0, 1.25))) * 0.5 + smoothstep(0.35, 0.0, uv.y) * 0.18;
    col = over(col, ubuf.stoneColor.rgb, clamp(shade, 0.0, 0.6));

    fragColor = col * ubuf.qt_Opacity;
}
