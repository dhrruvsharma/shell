#version 440

// CRT screen for the "Mainframe" lock theme.
//
// `crt` fades in barrel curvature, chromatic fringing, scanlines, a vignette
// and flicker; `bloom` adds a phosphor glow. `squashY` / `squashX` collapse the
// picture into a bright horizontal line and then a dot, like an old set
// powering off (run them back up to power on). `glitch` tears horizontal
// bands. With crt = bloom = flash = glitch = 0 and both squashes at 1 the
// source passes through untouched.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float crt;
    float bloom;
    float squashX;
    float squashY;
    float flash;
    float glitch;
    float time;
} ubuf;

layout(binding = 1) uniform sampler2D source;

float hash(float n) {
    return fract(sin(n) * 43758.5453);
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 c = qt_TexCoord0 - 0.5;

    // Barrel curvature: each pixel samples slightly further out, so the
    // picture bulges and the corners round off into black.
    c *= 1.0 + 0.05 * ubuf.crt * dot(c, c) * 4.0;

    // Power-off collapse, never thinner than a few pixels so the line and
    // the dot stay visible.
    vec2 sq = vec2(max(ubuf.squashX, 3.0 / res.x), max(ubuf.squashY, 2.5 / res.y));
    vec2 uv = c / sq + 0.5;
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    if (ubuf.glitch > 0.0) {
        float band = floor(uv.y * 38.0);
        float t = floor(ubuf.time * 24.0);
        if (hash(band * 13.17 + t * 7.31) > 0.72)
            uv.x += (hash(band + t * 3.1) - 0.5) * 0.14 * ubuf.glitch;
    }

    vec4 col;
    if (ubuf.crt > 0.0) {
        float fringe = 0.0006 * ubuf.crt * (1.0 + 3.0 * dot(c, c));
        vec4 mid = texture(source, uv);
        col = vec4(texture(source, uv + vec2(fringe, 0.0)).r, mid.g, texture(source, uv - vec2(fringe, 0.0)).b, mid.a);
    } else {
        col = texture(source, uv);
    }

    // Phosphor glow: two soft rings of taps, wide enough not to read as a
    // doubled copy of thin text strokes.
    if (ubuf.bloom > 0.0) {
        vec4 glow = vec4(0.0);
        for (int ring = 1; ring <= 2; ring++) {
            vec2 r = float(ring) * 4.0 / res;
            glow += (texture(source, uv + vec2(r.x, 0.0)) + texture(source, uv - vec2(r.x, 0.0))
                + texture(source, uv + vec2(0.0, r.y)) + texture(source, uv - vec2(0.0, r.y))
                + texture(source, uv + r * 0.7071) + texture(source, uv - r * 0.7071)
                + texture(source, uv + vec2(r.x, -r.y) * 0.7071) + texture(source, uv + vec2(-r.x, r.y) * 0.7071))
                * (ring == 1 ? 0.045 : 0.025);
        }
        col.rgb += glow.rgb * ubuf.bloom;
    }

    if (ubuf.crt > 0.0) {
        // One darker line every other pixel row, a soft vignette, flicker.
        float line = 0.5 + 0.5 * cos(uv.y * res.y * 3.14159265);
        col.rgb *= mix(1.0, 0.84 + 0.16 * line, ubuf.crt);
        float vig = smoothstep(0.8, 0.22, length(c * vec2(0.95, 1.15)));
        col.rgb *= mix(1.0, 0.62 + 0.38 * vig, ubuf.crt);
        col.rgb *= 1.0 - 0.03 * ubuf.crt * hash(floor(ubuf.time * 30.0) + 0.5);
    }

    // Energy concentrates as the picture collapses.
    float collapse = (1.0 - ubuf.squashY) * 1.6 + (1.0 - ubuf.squashX) * 2.5;
    float boost = 1.0 + collapse + ubuf.flash * 1.4;
    col.rgb = min(col.rgb * boost + vec3((ubuf.flash * 0.16 + collapse * 0.12) * col.a), vec3(col.a));

    fragColor = col * ubuf.qt_Opacity;
}
