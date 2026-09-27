#version 440
// Wallpaper change, one look per desktop theme (`mode`):
//   0 grow   - a soft circle grows from the centre (the plain rice)
//   1 tiles  - square tiles flip in along a diagonal wave (HUD)
//   2 scan   - a bright scanline wipes down the screen (Mainframe)
//   3 warp   - an iris opens with a glowing rim while the new image settles
//              from a slight zoom (Astral)
//   4 fade   - a slow crossfade (Still)
//   5 ink    - the new image bleeds in along fbm ink edges (Cave Abode)
// Only drawn while a transition runs; the wallpaper is a plain Image otherwise.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;    // 0..1
    float mode;
    float aspect;      // width / height
    vec4 edgeColor;    // opaque accent for rims and scan lines
    // Visible part of each texture (offset.xy, size.zw in texture UV): the
    // images are loaded to cover the screen and cropped, so sampling the
    // whole texture would squash the picture during the transition.
    vec4 fromRect;
    vec4 toRect;
} ubuf;

layout(binding = 1) uniform sampler2D fromTex;
layout(binding = 2) uniform sampler2D toTex;

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
    vec2 uv = qt_TexCoord0;
    float p = clamp(ubuf.progress, 0.0, 1.0);
    int mode = int(ubuf.mode + 0.5);
    vec2 c = (uv - 0.5) * vec2(ubuf.aspect, 1.0);
    float maxR = 0.5 * sqrt(ubuf.aspect * ubuf.aspect + 1.0);

    vec2 toUv = uv;
    if (mode == 3)
        toUv = (uv - 0.5) * (1.0 - 0.12 * (1.0 - p)) + 0.5;

    vec4 a = texture(fromTex, ubuf.fromRect.xy + uv * ubuf.fromRect.zw);
    vec4 b = texture(toTex, ubuf.toRect.xy + toUv * ubuf.toRect.zw);
    vec3 edge = vec3(0.0);
    float m;

    if (mode == 1) {
        vec2 grid = vec2(18.0 * ubuf.aspect / 1.6, 18.0);
        vec2 cell = floor(uv * grid);
        float delay = (cell.x / grid.x + cell.y / grid.y) * 0.5;
        float t = clamp((p * 1.6 - delay * 0.6 - hash(cell) * 0.1) / 0.45, 0.0, 1.0);
        vec2 f = abs(fract(uv * grid) - 0.5);
        float inside = step(max(f.x, f.y), t * 0.5);
        m = inside;
        float rim = inside * (1.0 - step(max(f.x, f.y), t * 0.5 - 0.06)) * step(t, 0.999);
        edge = ubuf.edgeColor.rgb * rim * 0.8;
    } else if (mode == 2) {
        float line = p * 1.08 - 0.04;
        m = step(uv.y, line);
        float glow = exp(-abs(uv.y - line) * 90.0) * step(p, 0.999);
        edge = ubuf.edgeColor.rgb * glow * 0.9;
        m *= 0.9 + 0.1 * step(1.0, mod(gl_FragCoord.y, 2.0) + p * 2.0);
    } else if (mode == 3) {
        float r = p * maxR * 1.05;
        float d = length(c);
        m = smoothstep(r, r - 0.03, d);
        edge = ubuf.edgeColor.rgb * exp(-abs(d - r) * 40.0) * step(p, 0.999) * 0.9;
    } else if (mode == 4) {
        m = smoothstep(0.0, 1.0, p);
    } else if (mode == 5) {
        float n = fbm(uv * vec2(3.0 * ubuf.aspect, 3.0));
        float front = p * 1.3 - 0.15;
        m = smoothstep(n - 0.06, n + 0.02, front);
        float band = smoothstep(n - 0.14, n - 0.04, front) * (1.0 - m);
        a.rgb *= 1.0 - band * 0.85;
    } else {
        float r = p * maxR * 1.05;
        m = smoothstep(r, r - 0.04, length(c));
    }

    fragColor = vec4(mix(a.rgb, b.rgb, m) + edge, 1.0) * ubuf.qt_Opacity;
}
