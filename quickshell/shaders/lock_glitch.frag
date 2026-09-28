#version 440

// Glitch transition for the "Black ICE" lock theme.
//
// As progress runs 0 -> 1 the captured desktop breaks up like a bad signal:
// bands tear sideways, the channels split into red and blue, blocks flash
// neon and then drop out, until nothing is left. Run back from 1 to 0 the
// desktop reassembles. At progress 0 the capture passes through untouched.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float progress;
    vec4 neonA;        // opaque
    vec4 neonB;        // opaque
} ubuf;

layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float p = ubuf.progress;
    if (p <= 0.0) {
        fragColor = texture(source, uv) * ubuf.qt_Opacity;
        return;
    }

    // Bands of uneven height tear sideways; more of them as it goes.
    float row = floor(uv.y * 36.0);
    float band = floor(uv.y * (8.0 + 20.0 * hash(vec2(row, 1.0))));
    float torn = step(1.0 - p * 1.3, hash(vec2(band, 3.0)));
    float shift = (hash(vec2(band, 5.0)) - 0.5) * 0.22 * p * p * torn;

    // Blocks drop out at random moments; the ones about to go flash neon.
    vec2 grid = vec2(20.0, 12.0) * (1.0 + floor(hash(vec2(row, 9.0)) * 2.0));
    vec2 block = floor(vec2(uv.x + shift, uv.y) * grid);
    float at = hash(block + 13.0) * 0.85 + 0.1;
    if (p * 1.05 > at) {
        fragColor = vec4(0.0);
        return;
    }
    float flash = smoothstep(0.1, 0.0, at - p * 1.05) * step(0.6, hash(block + 21.0));

    float split = 0.018 * p;
    vec2 suv = vec2(uv.x + shift, uv.y);
    vec4 col = texture(source, suv);
    col.r = texture(source, suv + vec2(split, 0.0)).r;
    col.b = texture(source, suv - vec2(split, 0.0)).b;

    vec3 neon = mix(ubuf.neonA.rgb, ubuf.neonB.rgb, step(0.5, hash(block + 31.0)));
    col.rgb = mix(col.rgb, neon * col.a, flash * 0.85);

    // Interlace darkening as the signal fails, then a fade at the very end.
    col.rgb *= 1.0 - 0.3 * p * step(1.0, mod(gl_FragCoord.y, 2.0));
    col *= 1.0 - smoothstep(0.85, 1.0, p);

    fragColor = min(col, vec4(col.a)) * ubuf.qt_Opacity;
}
