#version 440

// Singularity transition for the "Astral" lock theme: as progress runs 0 -> 1
// the captured desktop is pulled into `center`, twisting into a spiral that
// shrinks to a point and burns out; run back to 0 it unspirals out of a white
// hole. At progress 0 the capture passes through untouched.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float progress;
    vec2 center;       // normalised
    vec4 glowColor;    // opaque
} ubuf;

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;
    float pr = ubuf.progress;
    if (pr <= 0.0) {
        fragColor = texture(source, uv) * ubuf.qt_Opacity;
        return;
    }

    vec2 aspect = vec2(ubuf.itemWidth / ubuf.itemHeight, 1.0);
    vec2 p = (uv - ubuf.center) * aspect;
    float r = length(p);

    // Sample further out as progress grows (the picture contracts), rotated
    // more the closer a pixel is to the centre (the spiral). Both grow with
    // progress squared, so the start is a gentle pull, not a spin.
    float pull = 1.0 + pr * pr * 11.0;
    float swirl = pr * pr * 10.0 * exp(-r * 2.2);
    float c = cos(swirl);
    float s = sin(swirl);
    vec2 q = vec2(c * p.x - s * p.y, s * p.x + c * p.y) * pull;
    vec2 suv = q / aspect + ubuf.center;
    if (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    vec4 col = texture(source, suv);

    // Heat up towards the centre as it falls in, then burn out.
    float heat = exp(-r * (10.0 - pr * 6.0)) * pr;
    col.rgb = mix(col.rgb, ubuf.glowColor.rgb * col.a, clamp(heat * 1.2, 0.0, 1.0));
    col.rgb += ubuf.glowColor.rgb * heat * 0.4 * col.a;
    col *= 1.0 - smoothstep(0.82, 1.0, pr);

    fragColor = min(col, vec4(col.a)) * ubuf.qt_Opacity;
}
