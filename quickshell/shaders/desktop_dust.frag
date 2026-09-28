#version 440
// Wasteland over the wallpaper: a sky thick with dust (an amber haze that
// settles heavier towards the ground), grit and specks, rust and grime
// creeping in from the edges, and a length of hazard tape stuck across the
// bottom-left corner, torn at both ends and dusted over. Output is
// premultiplied and translucent. Nothing depends on time; `storm` (0..1)
// plays the switch-on: the dust blows in from the left.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float storm;       // 0..1
    float lineScale;   // >1 enlarges specks in small previews
    vec4 dustColor;    // opaque
    vec4 rustColor;    // opaque
    vec4 hazardColor;  // opaque
    vec4 grimeColor;   // opaque
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

vec4 over(vec4 dst, vec3 rgb, float a) {
    return vec4(rgb * a + dst.rgb * (1.0 - a), a + dst.a * (1.0 - a));
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * res;
    float aspect = res.x / res.y;
    vec4 col = vec4(0.0);

    // The storm front: everything below arrives from the left.
    float front = smoothstep(ubuf.storm * 1.5 - 0.3, ubuf.storm * 1.5 - 0.5, uv.x + (fbm(uv * 3.0) - 0.5) * 0.3);

    // ── Dust in the air ─────────────────────────────────────────────────
    vec2 q = uv * vec2(aspect, 1.0);
    float cloud = fbm(q * 2.2 + vec2(fbm(q * 1.3) * 1.4, 0.0));
    float ground = smoothstep(0.35, 1.0, uv.y);
    float sky = smoothstep(0.45, 0.0, uv.y) * 0.5;
    float haze = (0.09 + 0.12 * cloud + 0.15 * ground + 0.07 * sky) * front;
    col = over(col, ubuf.dustColor.rgb, haze);
    // Low streaks of blown dust near the ground.
    float streak = smoothstep(0.55, 0.9, noise(vec2(px.x / 260.0, px.y / 14.0))) * ground;
    col = over(col, mix(ubuf.dustColor.rgb, vec3(1.0), 0.15), streak * 0.08 * front);

    // ── Grit ────────────────────────────────────────────────────────────
    float s = ubuf.lineScale;
    vec2 cell = floor(px / (5.0 * s));
    float g = hash(cell);
    float speck = step(0.992, g) * smoothstep(0.5, 0.15, length(fract(px / (5.0 * s)) - 0.5));
    col = over(col, g > 0.996 ? vec3(0.95, 0.88, 0.72) : ubuf.grimeColor.rgb, speck * 0.55 * front);

    // ── Rust and grime creeping in from the edges ───────────────────────
    vec2 e = min(uv, 1.0 - uv) * vec2(aspect, 1.0);
    float edge = min(e.x, e.y);
    float rustN = fbm(q * 7.0 + 3.1);
    float rust = smoothstep(0.1, 0.0, edge + (rustN - 0.5) * 0.12) * smoothstep(0.35, 0.65, rustN) * mix(0.35, 1.0, smoothstep(0.02, 0.12, uv.y));
    col = over(col, ubuf.rustColor.rgb * (0.7 + 0.5 * noise(px / 3.0)), rust * 0.5 * front);
    vec2 c = uv - 0.5;
    c.x *= aspect;
    col = over(col, ubuf.grimeColor.rgb, smoothstep(0.5, 1.15, length(c) + (fbm(q * 3.0) - 0.5) * 0.25) * 0.5 * front);

    // ── Hazard tape across the bottom-left corner ───────────────────────
    vec2 dir = normalize(vec2(1.0, 1.0));      // along the tape
    vec2 nrm = vec2(-dir.y, dir.x);
    vec2 o = vec2(0.0, res.y - 250.0);         // passes through here
    vec2 d = px - o;
    float along = dot(d, dir);
    float across = dot(d, nrm);
    float halfW = 21.0;
    float torn = (noise(vec2(across * 0.25, 3.0)) - 0.5) * 16.0;
    float band = smoothstep(halfW + 0.8, halfW - 0.8, abs(across + (noise(vec2(along * 0.05, 1.0)) - 0.5) * 2.0))
               * smoothstep(-20.0 + torn, -12.0 + torn, along) * smoothstep(420.0 + torn, 410.0 + torn, along);
    float stripe = step(0.5, fract((along + across) / 36.0));
    vec3 tape = mix(ubuf.hazardColor.rgb, vec3(0.07, 0.065, 0.06), stripe);
    // Worn and dusted: scuffs through to nothing, dust over the top.
    float wear = smoothstep(0.62, 0.72, fbm(px / 18.0 + 5.0));
    tape = mix(tape, ubuf.dustColor.rgb, 0.18 + 0.2 * noise(px / 9.0));
    col = over(col, tape, band * (1.0 - wear * 0.8) * 0.9 * front);
    // Its shadow on the wall.
    float shadow = smoothstep(halfW + 7.0, halfW, abs(across - 3.0)) * (1.0 - band)
                 * smoothstep(-12.0, 0.0, along) * smoothstep(420.0, 405.0, along);
    col = over(col, vec3(0.0), shadow * 0.25 * front);

    fragColor = col * ubuf.qt_Opacity;
}
