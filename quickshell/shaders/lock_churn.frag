#version 440
// The "Samudra Manthan" lock's way in and out (modules/lock/themes/devaloka):
// the desktop is churned into the ocean of milk. It starts to turn round
// the churning point (`centre`), faster near it, streaks of foam wheeling
// through it as it goes; its colour whitens to milk; then it thins away
// from the churn outwards to show the scene behind. Run backwards on the
// way out. At `progress` 0 it is exactly the desktop; at 1, transparent.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float progress;
    vec2 centre;       // 0..1
    vec4 milkColor;
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

void main() {
    vec2 uv = qt_TexCoord0;
    float p = clamp(ubuf.progress, 0.0, 1.0);
    if (p <= 0.0) {
        fragColor = texture(source, uv) * ubuf.qt_Opacity;
        return;
    }
    float aspect = ubuf.itemWidth / max(1.0, ubuf.itemHeight);
    vec2 d = (uv - ubuf.centre) * vec2(aspect, 1.0);
    float r = length(d);
    // The turn: more near the churn, gathering pace.
    float turn = pow(p, 1.7) * 5.5 * exp(-r / 0.55);
    float c = cos(turn), s = sin(turn);
    vec2 rd = vec2(d.x * c - d.y * s, d.x * s + d.y * c);
    vec2 suv = clamp(ubuf.centre + rd / vec2(aspect, 1.0), 0.0, 1.0);
    vec4 img = texture(source, suv);

    // Streaks of foam along the flow, and the milk rising through it.
    float a = atan(d.y, d.x);
    float streak = smoothstep(0.75, 1.0, sin(a * 5.0 + turn * 3.0 + log(r + 0.02) * 9.0 + noise(vec2(cos(a), sin(a)) * 2.5 + vec2(r * 8.0, 0.0)) * 2.0));
    float milky = smoothstep(0.08, 0.7, p) * (0.35 + 0.65 * exp(-r * 1.2));
    vec3 col = mix(img.rgb, ubuf.milkColor.rgb, milky * 0.85);
    col = mix(col, vec3(1.0), streak * smoothstep(0.05, 0.4, p) * (1.0 - smoothstep(0.75, 1.0, p)) * 0.55);

    // In the second half it thins away from the churn outwards, the front
    // ragged, out past the farthest corner.
    float front = (p - 0.5) / 0.45 * 1.6 - 0.15;
    float ragged = r + (noise(vec2(cos(a), sin(a)) * 3.0 + vec2(r * 6.0, 0.0)) - 0.5) * 0.25;
    float alpha = smoothstep(front - 0.05, front + 0.15, ragged);
    alpha *= 1.0 - smoothstep(0.92, 1.0, p);
    fragColor = vec4(col * alpha, alpha) * ubuf.qt_Opacity;
}
