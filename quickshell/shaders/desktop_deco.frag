#version 440
// Art Deco over the wallpaper, like a 1920s poster: a sunburst fanning up
// from behind a skyline of setback towers along the bottom edge, gold light
// on every ledge and a few windows still lit, and a lacquer vignette.
// Output is premultiplied and translucent. Nothing depends on time, so it
// only costs a quad on frames that are drawn anyway; `rise` (0..1) plays
// the switch-on: the towers rise and the rays fan open.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float rise;        // 0..1
    float lineScale;   // >1 thickens hairlines in small previews
    vec4 goldColor;    // opaque
    vec4 jewelColor;   // opaque
    vec4 nightColor;   // opaque, the lacquer
} ubuf;

const float PI = 3.14159265;

float hash(float n) {
    return fract(sin(n * 127.1) * 43758.5453);
}

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec4 over(vec4 dst, vec3 rgb, float a) {
    return vec4(rgb * a + dst.rgb * (1.0 - a), a + dst.a * (1.0 - a));
}

// Height of a setback tower at `xl` (0..1 across its cell) for a tower
// `h` px tall: the base, then two narrower storeys stepped back.
float setback(float xl, float h, float steps) {
    float d = abs(xl - 0.5);
    if (d > 0.44)
        return 0.0;
    if (steps > 1.5 && d <= 0.16)
        return h;
    if (d <= 0.3)
        return h * (steps > 1.5 ? 0.86 : 1.0);
    return h * 0.7;
}

void main() {
    vec2 res = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 px = qt_TexCoord0 * res;
    float H = res.y;
    float up = H - px.y;                 // px above the bottom edge
    float lw = ubuf.lineScale;
    float rise = ubuf.rise;
    vec3 gold = ubuf.goldColor.rgb;
    vec3 night = ubuf.nightColor.rgb;
    vec4 col = vec4(0.0);

    // ── The central tower, whose crown the sun rises behind ─────────────
    float cx = res.x * 0.5;
    float tw = abs(px.x - cx);
    float tower = 0.0;
    if (tw < 70.0) tower = H * 0.15;
    if (tw < 50.0) tower = H * 0.195;
    if (tw < 32.0) tower = H * 0.225;
    // The crown: a narrowing spike over the last setback.
    if (tw < 18.0) tower = H * 0.225 + (H * 0.045) * (1.0 - tw / 18.0);
    tower *= rise;

    // ── Sunburst ────────────────────────────────────────────────────────
    vec2 sun = vec2(cx, H - H * 0.235 * rise);
    vec2 d = px - sun;
    float dist = length(d);
    float ang = atan(d.x, -d.y);         // 0 straight up, +-PI/2 level
    float n = 38.0;
    float slot = (ang + PI * 0.5) / (PI / n);
    float frac = fract(slot);
    float reach = 1.0 - smoothstep(0.0, H * 1.25 * rise, dist);
    float above = step(abs(ang), PI * 0.5);
    float alt = mod(floor(slot), 2.0);
    col = over(col, gold, above * alt * 0.05 * reach);
    float edge = min(frac, 1.0 - frac) * (PI / n) * dist;
    col = over(col, gold, above * smoothstep(0.9 * lw, 0.0, edge) * 0.2 * reach * smoothstep(20.0, 90.0, dist));
    // The glow of the sun itself, jewel into gold.
    float glow = exp(-dist / (H * 0.16)) * rise;
    col = over(col, mix(ubuf.jewelColor.rgb, gold, 0.55), glow * 0.18);

    // ── Skyline ─────────────────────────────────────────────────────────
    // Back row: taller, fainter towers.
    float wb = 76.0;
    float ib = floor(px.x / wb);
    float hb = H * (0.05 + 0.075 * hash(ib + 3.0)) * rise;
    float sb = hash(ib + 11.0) > 0.45 ? 2.0 : 1.0;
    float xb = fract(px.x / wb);
    float back = setback(xb, hb, sb);
    // Front row: squatter blocks, offset from the back row.
    float wf = 112.0;
    float xf0 = px.x + 37.0;
    float iff = floor(xf0 / wf);
    float hf = H * (0.025 + 0.045 * hash(iff + 29.0)) * rise;
    float sf = hash(iff + 5.0) > 0.6 ? 2.0 : 1.0;
    float xf = fract(xf0 / wf);
    float front = setback(xf, hf, sf);

    float aa = 0.8;
    float inBack = smoothstep(back + aa, back - aa, up) * step(0.5, back);
    float inFront = smoothstep(front + aa, front - aa, up) * step(0.5, front);
    float inTower = smoothstep(tower + aa, tower - aa, up) * step(0.5, tower);

    // Gold on the ledges: a line along every tower top.
    float ledgeB = smoothstep(lw * 1.1, 0.0, abs(up - back)) * step(0.5, back);
    float ledgeF = smoothstep(lw * 1.1, 0.0, abs(up - front)) * step(0.5, front);
    float ledgeT = smoothstep(lw * 1.3, 0.0, abs(up - tower)) * step(0.5, tower);

    col = over(col, night, inBack * 0.42);
    col = over(col, gold, ledgeB * 0.34 * (1.0 - inFront) * (1.0 - inTower));
    // Lit windows, a few per tower: small panes on a 6 x 9 px grid.
    vec2 win = vec2(floor(px.x / 6.0), floor(up / 9.0));
    float pane = step(0.5, fract(px.x / 6.0)) * step(0.5, fract(up / 9.0));
    float lit = step(0.93, hash2(win + 7.0)) * pane;
    col = over(col, gold, lit * inBack * (1.0 - inFront) * (1.0 - inTower) * 0.32);
    col = over(col, night, inFront * 0.62);
    col = over(col, gold, ledgeF * 0.45 * (1.0 - inTower));
    float litF = step(0.92, hash2(win + 31.0)) * pane;
    col = over(col, gold, litF * inFront * (1.0 - inTower) * 0.45);
    col = over(col, night, inTower * 0.82);
    col = over(col, gold, ledgeT * 0.6);
    // The tower's fluting: fine gold verticals up its face.
    float flute = smoothstep(lw * 0.9, 0.0, (0.5 - abs(fract(tw / 12.0) - 0.5)) * 12.0);
    col = over(col, gold, inTower * flute * 0.08 * step(tw, 70.0));

    // ── Lacquer vignette ────────────────────────────────────────────────
    vec2 c = qt_TexCoord0 - 0.5;
    c.x *= res.x / res.y;
    col = over(col, night, smoothstep(0.45, 1.15, length(c)) * 0.42);

    fragColor = col * ubuf.qt_Opacity;
}
