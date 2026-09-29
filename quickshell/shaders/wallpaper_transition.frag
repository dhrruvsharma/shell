#version 440
// Wallpaper change, one look per desktop theme (`mode`):
//   0 grow   - a soft circle grows from the centre (the plain rice)
//   1 tiles  - square tiles flip in along a diagonal wave (HUD)
//   2 scan   - a bright scanline wipes down the screen (Mainframe)
//   3 warp   - an iris opens with a glowing rim while the new image settles
//              from a slight zoom (Astral)
//   4 fade   - a slow crossfade (Still)
//   5 ink    - the new image bleeds in along fbm ink edges (Cave Abode)
//   6 glitch - blocks of the new image cut in at random moments, torn
//              sideways and split into red and blue as they switch (Neon Noir)
//   7 fusuma - the old image slides away left like a painted sliding door,
//              wooden stile and round pull included (Wabi-sabi)
//   8 fan    - the new image fans open ray by ray from the middle of the
//              bottom edge, gold along the rays' edges (Art Deco)
//   9 glass  - leaded panes turn over one at a time, each flashing with
//              coloured light, the lead showing while it happens (Cathedral)
//  10 press  - six columns set top to bottom one after another, each
//              front a band of growing halftone dots, rules between them
//              (Broadsheet)
//  11 dust   - a dust storm blows through from the left: the old picture
//              is lost in it, the new one clears behind (Wasteland)
//  12 rule   - an astrolabe's rule sweeps round from noon, the new picture
//              behind its edge, a graduated limb showing as it turns
//              (Observatory)
//  13 tide   - the tide comes in: the new picture rises from the bottom
//              under a rippling waterline, swimming as it settles, bubbles
//              on the way (Abyss)
//  14 lotus  - a lotus opens from the middle: the new picture inside two
//              rings of pointed petals that grow and turn a little as they
//              unfold, gold along their edges (Devaloka)
//  15 fire   - the old picture burns away from the bottom up: a ragged
//              front of glowing embers eats into it, scorching it brown
//              ahead of the flames, sparks going up (Siege)
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
    // A veil laid over the result (rgb, amount): Wasteland's dust.
    vec4 veil = vec4(0.0);
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
    } else if (mode == 6) {
        vec2 block = vec2(floor(uv.x * 7.0), floor(uv.y * 28.0));
        float at = 0.06 + 0.78 * hash(block * vec2(0.37, 1.0));
        float spike = exp(-abs(p - at) * 22.0) * step(p, 0.999);
        float tear = (hash(vec2(block.y, 7.0)) - 0.5) * 0.14 * spike;
        vec2 suv = vec2(fract(uv.x + tear), uv.y);
        float split = 0.014 * spike;
        a = texture(fromTex, ubuf.fromRect.xy + suv * ubuf.fromRect.zw);
        b = texture(toTex, ubuf.toRect.xy + suv * ubuf.toRect.zw);
        b.r = texture(toTex, ubuf.toRect.xy + vec2(fract(suv.x + split), suv.y) * ubuf.toRect.zw).r;
        b.b = texture(toTex, ubuf.toRect.xy + vec2(fract(suv.x - split), suv.y) * ubuf.toRect.zw).b;
        m = step(at, p);
        edge = ubuf.edgeColor.rgb * spike * 0.3 * step(0.55, hash(block + 3.0));
    } else if (mode == 7) {
        // The door's right edge, from just off the right of the screen to
        // just off the left.
        float door = 1.012 - p * 1.06;
        float px = 1.0 / 1080.0;
        m = step(door, uv.x);
        vec2 suv = vec2(uv.x + (1.012 - door), uv.y);
        a = texture(fromTex, ubuf.fromRect.xy + clamp(suv, 0.0, 1.0) * ubuf.fromRect.zw);
        // The door's shadow on what it uncovers.
        b.rgb *= 1.0 - (1.0 - smoothstep(0.0, 0.05, uv.x - door)) * m * 0.4;
        // Lacquered wooden stile along its edge, with a highlight.
        float x = (door - uv.x) * ubuf.aspect;
        float stile = step(0.0, x) * step(x, 12.0 * px);
        vec3 wood = mix(vec3(0.16, 0.1, 0.07), vec3(0.34, 0.22, 0.14), smoothstep(12.0 * px, 3.0 * px, x));
        a.rgb = mix(a.rgb, wood, stile);
        // Round recessed pull (hikite) near the edge, halfway down, with a
        // gilt rim.
        float d = length(vec2(x - 34.0 * px, (uv.y - 0.5)));
        a.rgb = mix(a.rgb, vec3(0.08, 0.06, 0.05), smoothstep(13.0 * px, 11.0 * px, d));
        a.rgb = mix(a.rgb, vec3(0.78, 0.62, 0.32), smoothstep(2.0 * px, 0.0, abs(d - 13.0 * px)));
    } else if (mode == 8) {
        // Rays from just below the middle of the bottom edge; every other
        // ray a beat behind, the outer ones last, each opening from its
        // centre line.
        vec2 d = (uv - vec2(0.5, 1.02)) * vec2(ubuf.aspect, 1.0);
        float ang = atan(d.x, -d.y);
        float n = 18.0;
        float slot = (ang / 3.14159265 + 0.5) * n;
        float ray = floor(slot);
        float f = abs(fract(slot) - 0.5) * 2.0;
        float delay = mod(ray, 2.0) * 0.16 + abs(ray + 0.5 - n * 0.5) / n * 0.3;
        float t = clamp((p * 1.55 - delay) / 0.95, 0.0, 1.0);
        float open = step(f, t);
        m = max(open, step(0.999, p));
        float rimW = 0.02 + 0.5 / max(1.0, length(d) * 900.0 / n);
        float rim = open * (1.0 - step(f, t - rimW)) * step(t, 0.999) * step(0.001, t);
        edge = ubuf.edgeColor.rgb * rim * 0.95;
    } else if (mode == 9) {
        // Voronoi panes, each turning over at its own moment.
        vec2 g = uv * vec2(ubuf.aspect, 1.0) * 7.0;
        vec2 cell = floor(g);
        vec2 f = fract(g);
        float d1 = 8.0;
        float d2 = 8.0;
        vec2 best = vec2(0.0);
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                vec2 o = vec2(float(i), float(j));
                vec2 pt = o + vec2(hash(cell + o), hash(cell + o + 17.0)) * 0.9 + 0.05;
                float dd = length(pt - f);
                if (dd < d1) {
                    d2 = d1;
                    d1 = dd;
                    best = cell + o;
                } else if (dd < d2) {
                    d2 = dd;
                }
            }
        }
        float at = 0.08 + 0.78 * hash(best * 1.37 + 3.0);
        m = smoothstep(at - 0.035, at + 0.035, p);
        float flash = exp(-abs(p - at) * 13.0) * step(p, 0.999);
        vec3 tint = mix(ubuf.edgeColor.rgb, vec3(1.0, 0.78, 0.36), step(0.5, hash(best + 9.0)));
        edge = tint * flash * 0.4;
        float lead = smoothstep(0.07, 0.025, d2 - d1) * sin(p * 3.14159265);
        a.rgb *= 1.0 - lead * 0.85;
        b.rgb *= 1.0 - lead * 0.85;
        edge *= 1.0 - lead;
    } else if (mode == 10) {
        // Six columns, set one after another from the left.
        float cols = 6.0;
        float col = floor(uv.x * cols);
        float t = clamp((p - col / cols * 0.6) / 0.4, 0.0, 1.0);
        float front = t * 1.12;
        float band = 0.09;
        // Behind the front the page is printed; in the band the dots grow.
        vec2 q = gl_FragCoord.xy / 7.0;
        float dotR = length(fract(q) - 0.5);
        float grown = clamp((front - uv.y) / band, 0.0, 1.0);
        m = uv.y < front - band ? 1.0 : uv.y > front ? 0.0 : step(dotR, grown * 0.72);
        m = max(m, step(0.999, p));
        // Column rules while the page is being set.
        float gutter = abs(fract(uv.x * cols + 0.5) - 0.5) / cols * ubuf.aspect;
        float rule = smoothstep(0.0012, 0.0, gutter) * sin(p * 3.14159265);
        a.rgb *= 1.0 - rule * 0.7;
        b.rgb *= 1.0 - rule * 0.7;
    } else if (mode == 11) {
        // The storm front, ragged and churning.
        float n = fbm(uv * vec2(3.0 * ubuf.aspect, 3.0) + vec2(-p * 1.6, p * 0.3));
        float front = p * 1.7 - 0.35;
        float x = uv.x + (n - 0.5) * 0.4;
        m = smoothstep(front + 0.04, front - 0.16, x);
        float dust = exp(-pow((x - front) / 0.2, 2.0)) * step(p, 0.999);
        veil = vec4(vec3(0.76, 0.6, 0.42) * (0.75 + 0.4 * n), dust * 0.9);
    } else if (mode == 12) {
        // Clockwise from twelve o'clock, round the middle of the screen.
        const float TAU = 6.2831853;
        float a = mod(atan(c.x, -c.y), TAU);
        float front = p * TAU * 1.04;
        float d = length(c);
        m = max(1.0 - smoothstep(front - 0.008, front + 0.008, a), step(0.999, p));
        // The rule's edge, bright; the limb's degrees while it turns.
        float running = step(0.001, p) * step(p, 0.999);
        float ruleLine = exp(-abs(a - front) * max(d, 0.02) * 420.0) * running;
        float limb = exp(-abs(d - 0.45) * 700.0) + exp(-abs(d - 0.47) * 900.0) * 0.6;
        float ticks = step(0.82, fract(a / TAU * 72.0)) * step(abs(d - 0.435), 0.012);
        float bold = step(0.9, fract(a / TAU * 12.0 + 0.05)) * step(abs(d - 0.43), 0.02);
        float scale = (limb * 0.5 + max(ticks * 0.4, bold * 0.6)) * sin(p * 3.14159265);
        edge = ubuf.edgeColor.rgb * (ruleLine * 1.1 + scale);
    } else if (mode == 13) {
        float level = 1.08 - p * 1.16;
        float surf = level + 0.014 * sin(uv.x * 19.0 + p * 14.0) + 0.007 * sin(uv.x * 47.0 - p * 23.0);
        m = max(smoothstep(surf - 0.002, surf + 0.002, uv.y), step(0.999, p));
        // Under the surface the new picture swims as it settles.
        vec2 ruv = uv + vec2(sin(uv.y * 40.0 + p * 20.0), cos(uv.x * 30.0 + p * 15.0)) * 0.004 * (1.0 - p);
        b = texture(toTex, ubuf.toRect.xy + clamp(ruv, 0.0, 1.0) * ubuf.toRect.zw);
        float below = step(surf, uv.y);
        b.rgb *= 1.0 - 0.28 * exp(-(uv.y - surf) * 16.0) * below * (1.0 - p);
        float line = exp(-abs(uv.y - surf) * 260.0) * step(p, 0.999);
        // Bubbles just under the waterline.
        vec2 g = vec2(uv.x * ubuf.aspect, uv.y) * 38.0 + vec2(0.0, p * 10.0);
        float bub = step(0.9, hash(floor(g))) * smoothstep(0.3, 0.18, length(fract(g) - 0.5)) * smoothstep(0.16, 0.0, uv.y - surf) * below;
        edge = mix(ubuf.edgeColor.rgb, vec3(0.9, 1.0, 1.0), 0.5) * (line * 0.85 + bub * 0.3);
    } else if (mode == 14) {
        // Two rings of eight petals, each a pointed arch standing on the
        // circle where its neighbours meet, the back ring turned half a
        // petal and a little taller: their outline is how far the flower
        // has opened at this angle.
        const float TAU = 6.2831853;
        float d = length(c);
        float a = atan(c.x, -c.y) + p * 0.5;
        float R = p * maxR * 1.25;
        float r0 = R * 0.52;
        float slot = TAU / 8.0;
        float w = 3.14159265 * r0 / 8.0;
        float h = R - r0;
        float xf = abs(fract(a / slot + 0.5) - 0.5) * slot * r0;
        float xb = abs(fract(a / slot) - 0.5) * slot * r0;
        float rcf = (w * w + h * h) / max(2.0 * w, 1e-5);
        float hb = h * 1.12;
        float rcb = (w * w + hb * hb) / max(2.0 * w, 1e-5);
        float front = r0 + sqrt(max(0.0, rcf * rcf - pow(xf + rcf - w, 2.0)));
        float back = r0 + sqrt(max(0.0, rcb * rcb - pow(xb + rcb - w, 2.0)));
        float edgeR = max(front, back);
        m = max(smoothstep(edgeR + 0.004, edgeR - 0.004, d), step(0.999, p));
        float running = step(0.001, p) * step(p, 0.999);
        float rim = exp(-abs(d - edgeR) * 300.0) * running;
        // The front petals' edges where they lie over the back ones.
        float over = exp(-abs(d - front) * 380.0) * step(d, back) * running * 0.6;
        edge = ubuf.edgeColor.rgb * (rim * 1.05 + over);
        // A warm light at the heart of the flower as it opens.
        edge += ubuf.edgeColor.rgb * exp(-d * 7.0) * sin(p * 3.14159265) * 0.25;
    } else if (mode == 15) {
        // How soon each point burns: the bottom first, the front ragged
        // with licks of flame that run on ahead.
        vec2 q = vec2(uv.x * ubuf.aspect, uv.y);
        float lick = fbm(q * 3.0 + vec2(0.0, 1.7)) * 0.55 + fbm(q * 9.0) * 0.18;
        float key = (1.0 - uv.y) * 0.78 + lick;
        float t = p * 1.24 + 0.12;
        float dd = key - t;
        m = max(smoothstep(0.004, -0.004, dd), step(0.999, p));
        float running = step(0.001, p) * step(p, 0.999);
        // Scorched brown ahead of the flames, black just before them.
        float scorch = smoothstep(0.1, 0.0, dd) * step(0.0, dd) * running;
        a.rgb = mix(a.rgb, a.rgb * vec3(0.45, 0.3, 0.18), scorch * 0.7);
        a.rgb *= 1.0 - smoothstep(0.03, 0.0, dd) * step(0.0, dd) * 0.85 * running;
        // The burning edge, and sparks rising off it.
        float glow = exp(-abs(dd) * 90.0) * running;
        vec3 flame = mix(vec3(1.0, 0.36, 0.06), vec3(1.0, 0.82, 0.42), exp(-abs(dd) * 260.0));
        edge = flame * glow * 1.3;
        vec2 g = vec2(uv.x * ubuf.aspect, uv.y) * 42.0 + vec2(0.0, p * 18.0);
        float spark = step(0.93, hash(floor(g))) * smoothstep(0.24, 0.08, length(fract(g) - 0.5));
        edge += vec3(1.0, 0.6, 0.2) * spark * smoothstep(0.16, 0.02, dd) * step(0.0, dd) * running;
    } else {
        float r = p * maxR * 1.05;
        m = smoothstep(r, r - 0.04, length(c));
    }

    vec3 col = mix(a.rgb, b.rgb, m) + edge;
    col = mix(col, veil.rgb, veil.a);
    fragColor = vec4(col, 1.0) * ubuf.qt_Opacity;
}
