#version 440
// The Sekiro lock's world (modules/lock/themes/sekiro): the desktop as
// Ashina by night. `night` grades it towards moonlight (colour drained to
// blue-grey, the reds left smouldering), raises a great moon in the sky
// with its halo, and lays a mist along the ground. `death` takes the
// colour out of everything and darkens it towards ink with blood in the
// shadows, the way the world goes when the shinobi falls; `hurt` is the
// red at the edges of a blow taken; `flash` the white of a deathblow.
// At night 0 (and the rest 0) it is the desktop exactly.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float night;
    float death;
    float hurt;
    float flash;
    vec2 moonPos;     // px
    float moonR;      // px
    vec4 moonColor;
    vec4 bloodColor;
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
    vec2 px = uv * res;
    float aspect = res.x / res.y;
    vec4 src = texture(source, uv);
    vec3 c = src.rgb;
    float n = clamp(ubuf.night, 0.0, 1.0);

    // ── Moonlight ───────────────────────────────────────────────────────────
    float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
    float hue = 0.0;
    {
        float mx = max(c.r, max(c.g, c.b));
        float mn = min(c.r, min(c.g, c.b));
        // How red it is: the reds smoulder on through the night.
        hue = smoothstep(0.08, 0.3, mx - mn) * smoothstep(0.0, 0.12, c.r - max(c.g, c.b));
    }
    vec3 moonlit = vec3(lum) * vec3(0.5, 0.58, 0.76) + vec3(0.012, 0.016, 0.03);
    moonlit = mix(moonlit, c * vec3(0.62, 0.22, 0.22), hue * 0.55);
    vec3 g = mix(c, moonlit, n);

    // The sky lit round the moon, the moon itself, and a mist on the ground.
    vec2 dm = px - ubuf.moonPos;
    float r = length(dm);
    float halo = exp(-max(0.0, r - ubuf.moonR) / (ubuf.moonR * 1.6)) * 0.42 + exp(-max(0.0, r - ubuf.moonR) / (ubuf.moonR * 0.35)) * 0.35;
    g += ubuf.moonColor.rgb * halo * n * 0.5;
    float disc = smoothstep(ubuf.moonR + 1.5, ubuf.moonR - 1.5, r);
    vec2 mq = dm / max(ubuf.moonR, 1.0);
    float maria = fbm(mq * 2.2 + 4.0) * 0.8 + fbm(mq * 6.0) * 0.2;
    vec3 moon = ubuf.moonColor.rgb * (1.02 - smoothstep(0.45, 0.75, maria) * 0.2 - smoothstep(0.6, 1.0, length(mq)) * 0.12);
    g = mix(g, moon, disc * n);
    vec2 q = vec2(uv.x * aspect, uv.y) * 2.4;
    float wisp = fbm(q + vec2(fbm(q * 0.6 + 2.0) * 1.3, 0.0));
    float low = smoothstep(0.55, 1.0, uv.y + (wisp - 0.5) * 0.2);
    g = mix(g, ubuf.moonColor.rgb * 0.42, low * smoothstep(0.3, 0.75, wisp) * 0.4 * n);
    float vig = smoothstep(0.4, 0.95, length((uv - 0.5) * vec2(aspect * 0.75, 1.0)));
    g *= 1.0 - vig * 0.45 * n;

    // ── Death: the colour goes, ink and blood are left ─────────────────────
    float dd = clamp(ubuf.death, 0.0, 1.0);
    float l2 = dot(g, vec3(0.2126, 0.7152, 0.0722));
    vec3 dead = mix(vec3(0.02, 0.012, 0.014), ubuf.bloodColor.rgb * 0.45, smoothstep(0.05, 0.6, l2));
    dead = mix(dead, vec3(l2 * 0.75), smoothstep(0.5, 1.0, l2) * 0.6);
    g = mix(g, dead, dd * 0.92);

    // ── A blow taken: red at the edges ──────────────────────────────────────
    float edge = smoothstep(0.25, 0.85, length((uv - 0.5) * vec2(aspect * 0.7, 1.0)));
    g = mix(g, ubuf.bloodColor.rgb * 0.5, edge * clamp(ubuf.hurt, 0.0, 1.0) * 0.75);

    // ── The deathblow's flash ───────────────────────────────────────────────
    g = mix(g, vec3(1.0, 0.97, 0.93), clamp(ubuf.flash, 0.0, 1.0));

    fragColor = vec4(g, 1.0) * ubuf.qt_Opacity;
}
