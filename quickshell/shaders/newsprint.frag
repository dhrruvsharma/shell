#version 440
// Broadsheet: a sheet of newsprint (modules/lock/themes/newspaper/Newsprint
// and NewsprintInk). Two passes share the sheet:
//   0  under the print: the paper, and its shadow on what it lies on. Grey-
//      cream stock, cloudy where the fibres bunched, with loose fibres, the
//      odd shive and specks of old ink the pulping missed; the back of the
//      page showing through, mirrored; edges yellowed with age; cut with
//      scissors in short straight snips that don't run quite square to the
//      print, or torn, the tear's fibres paler. The shadow hugs the sheet
//      where it lies flat and opens out under a corner that curls up.
//   1  over the print: what the paper does to the ink on it (starved in
//      blotches, pinholes where it didn't take, cracked along a crease),
//      the light across the sheet, its creases and its curl, and the tape
//      that holds it down.
// Everything is in pixels of the sheet, which sits `bleed` px inside the
// item on every side. Nothing depends on time: drawn once into a layer.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float bleed;
    float pass;        // 0 under the print, 1 over it
    float seed;
    vec4 paper;
    vec4 shade;        // what age turns it towards
    vec4 ink;          // the back page's
    float age;         // 0..1
    float show;        // the back page showing through, 0..1
    float foldX;       // a crease down the sheet at this fraction across (< 0: none)
    float foldY;       // and one across it, at this fraction down
    float lift;        // how far a corner curls up, 0..1
    float liftCorner;  // 0 top left, 1 top right, 2 bottom right, 3 bottom left
    vec4 torn;         // left, top, right, bottom: 0 cut .. 1 torn
    float wobble;      // how far a snip strays, px
    float skew;        // how far a cut's ends stray from square, px
    float shadow;      // 0..1
    float tape;        // 0 none, 1 over the top edge, 2 both top corners, 3 top left, 4 top right
} ubuf;

const float PI = 3.14159265;

// Hashes without sine (Dave Hoskins), so they hold up across a 4K screen.
float h1(float n) {
    float p = fract((n + ubuf.seed * 13.7) * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float h2(vec2 q) {
    vec3 p3 = fract(vec3(q.xyx + ubuf.seed * vec3(37.1, 17.3, 37.1)) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float n1(float x) {
    float i = floor(x);
    float f = fract(x);
    return mix(h1(i), h1(i + 1.0), f * f * (3.0 - 2.0 * f));
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(h2(i), h2(i + vec2(1.0, 0.0)), u.x),
               mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = p * 2.03 + vec2(13.1, 7.7);
        a *= 0.5;
    }
    return v / 0.9375;
}

// How far edge e (0 left, 1 top, 2 right, 3 bottom) stands out (+) or in
// (-) from the sheet's box, `t` px along it, of `len`; `tr`: how torn.
float edgeAt(float e, float t, float len, float tr) {
    float s = e * 37.3 + 11.0;
    // The cut's slant: its two ends stray from square.
    float a = h1(s + 0.1) - 0.5;
    float b = h1(s + 0.2) - 0.5;
    float o = mix(a, b, clamp(t / max(len, 1.0), 0.0, 1.0)) * 2.0 * ubuf.skew;
    // Snips about 70 px long, each straight, turning a little between them.
    float k = t / 70.0 + h1(s + 0.3) * 7.0;
    float i = floor(k);
    o += mix(h1(s + i * 1.7) - 0.5, h1(s + i * 1.7 + 1.7) - 0.5, fract(k)) * 2.0 * ubuf.wobble;
    // A tear wanders at every scale, and mostly eats into the sheet.
    if (tr > 0.0) {
        float u = t + s * 13.0;
        o += tr * ((n1(u / 43.0) - 0.5) * 7.0 + (n1(u / 8.5 + 3.0) - 0.5) * 3.2
                 + (n1(u / 2.1 + 7.0) - 0.5) * 1.5 - 2.6);
    }
    return o;
}

// Signed distance to the sheet's edge, px: + outside.
float sheetDist(vec2 p, vec2 S) {
    float dl = -edgeAt(0.0, p.y, S.y, ubuf.torn.x) - p.x;
    float dt = -edgeAt(1.0, p.x, S.x, ubuf.torn.y) - p.y;
    float dr = p.x - S.x - edgeAt(2.0, p.y, S.y, ubuf.torn.z);
    float db = p.y - S.y - edgeAt(3.0, p.x, S.x, ubuf.torn.w);
    vec2 q = vec2(max(dl, dr), max(dt, db));
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

// The torn edges' weight at p: how near a torn edge it is (0..1 per px).
float tornNear(vec2 p, vec2 S) {
    float w = 0.0;
    if (ubuf.torn.x > 0.0)
        w = max(w, ubuf.torn.x * exp(-max(p.x + edgeAt(0.0, p.y, S.y, ubuf.torn.x), 0.0) / 1.6));
    if (ubuf.torn.y > 0.0)
        w = max(w, ubuf.torn.y * exp(-max(p.y + edgeAt(1.0, p.x, S.x, ubuf.torn.y), 0.0) / 1.6));
    if (ubuf.torn.z > 0.0)
        w = max(w, ubuf.torn.z * exp(-max(S.x + edgeAt(2.0, p.y, S.y, ubuf.torn.z) - p.x, 0.0) / 1.6));
    if (ubuf.torn.w > 0.0)
        w = max(w, ubuf.torn.w * exp(-max(S.y + edgeAt(3.0, p.x, S.x, ubuf.torn.w) - p.y, 0.0) / 1.6));
    return w;
}

// How far the curl lifts the sheet at p, 0..1: most at the corner.
float liftAt(vec2 p, vec2 S) {
    if (ubuf.lift <= 0.0)
        return 0.0;
    int c = int(ubuf.liftCorner + 0.5);
    vec2 corner = vec2(c == 1 || c == 2 ? S.x : 0.0, c >= 2 ? S.y : 0.0);
    float r = clamp(min(S.x, S.y) * 0.8, 46.0, 200.0);
    float k = clamp(1.0 - length(p - corner) / r, 0.0, 1.0);
    return ubuf.lift * k * k;
}

// Loose fibres: in each 16 px cell, perhaps a hair a few px long at any
// angle, a few darker than the stock and a few bleached paler (-).
float fibres(vec2 p) {
    float f = 0.0;
    vec2 cell = floor(p / 16.0);
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 c = cell + vec2(float(i), float(j));
            float h = h2(c + 0.37);
            if (h < 0.5)
                continue;
            vec2 o = (c + vec2(h2(c + 4.1), h2(c + 5.3))) * 16.0;
            float ang = h2(c + 8.3) * PI;
            vec2 dir = vec2(cos(ang), sin(ang));
            float len = mix(1.5, 6.0, h2(c + 2.2));
            vec2 q = p - o;
            float t = clamp(dot(q, dir), -len, len);
            float w = smoothstep(0.9, 0.2, length(q - dir * t));
            f += w * (h > 0.92 ? -0.6 : 1.0) * mix(0.02, 0.055, h2(c + 6.6));
        }
    }
    return f;
}

// Shives (bark that got through, short and brown) and specks of old ink.
vec4 specks(vec2 p) {
    vec4 r = vec4(0.0);
    vec2 cell = floor(p / 58.0);
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 c = cell + vec2(float(i), float(j));
            float h = h2(c + 12.7);
            vec2 o = (c + vec2(h2(c + 1.9), h2(c + 3.7))) * 58.0;
            vec2 q = p - o;
            if (h > 0.92) {
                float ang = h2(c + 9.1) * PI;
                vec2 dir = vec2(cos(ang), sin(ang));
                float len = mix(1.0, 3.0, h2(c + 7.3));
                float t = clamp(dot(q, dir), -len, len);
                float w = smoothstep(1.0, 0.3, length(q - dir * t));
                r = max(r, vec4(0.45, 0.36, 0.25, w * 0.32));
            } else if (h < 0.3) {
                float rad = mix(0.45, 1.0, h2(c + 2.8));
                float w = smoothstep(rad + 0.5, rad - 0.3, length(q));
                r = max(r, vec4(0.16, 0.15, 0.14, w * mix(0.25, 0.6, h2(c + 4.4))));
            }
        }
    }
    return r;
}

// The other side of the page, mirrored and seen through the sheet: columns
// of type in paragraphs, a headline now and then, the odd photograph, all
// blurred by the paper between. 0..1, how much ink.
float backPage(vec2 p, vec2 S) {
    vec2 q = vec2(S.x - p.x, p.y) + vec2(h1(41.0) * 300.0, h1(42.0) * 600.0);
    float colW = 166.0;
    float gut = 13.0;
    float col = floor(q.x / (colW + gut));
    float x = q.x - col * (colW + gut);
    float edge = smoothstep(-2.0, 2.5, x) * smoothstep(colW + 2.0, colW - 2.5, x);
    if (edge <= 0.0)
        return 0.0;
    float story = fract(q.y / 610.0 + h1(col + 50.0));
    // A photograph over some stories: a soft grey mass.
    if (h1(col + 60.0) > 0.62 && story > 0.1 && story < 0.42) {
        float m = fbm(q / 28.0 + col) * 0.8 + 0.2;
        float fr = smoothstep(0.1, 0.115, story) * smoothstep(0.42, 0.405, story);
        return m * fr * edge * 0.75;
    }
    bool head = story < 0.07;
    float lead = head ? 24.0 : 12.6;
    float line = floor(q.y / lead);
    float y = q.y - line * lead;
    float band = head ? smoothstep(2.0, 8.5, y) * smoothstep(22.0, 15.5, y)
                      : smoothstep(1.0, 5.5, y) * smoothstep(11.5, 7.0, y);
    // Words, and the letters in them.
    float cw = head ? 58.0 : 30.0;
    float wx = x + h2(vec2(col, line)) * 40.0;
    float wi = floor(wx / cw);
    float wf = fract(wx / cw);
    float fill = mix(0.7, 0.94, h2(vec2(wi, line + col * 97.0)));
    float word = smoothstep(0.0, 0.16, wf) * smoothstep(fill, fill - 0.16, wf);
    word *= 0.55 + 0.45 * noise(vec2(wx / (head ? 3.2 : 2.4), line * 3.7));
    // A paragraph's last line stops short; between stories, a blank line.
    float last = h2(vec2(line * 3.1, col + 2.0));
    float stop = last > 0.86 ? mix(0.25, 0.85, h2(vec2(line, col + 5.0))) * colW : colW + 3.0;
    word *= smoothstep(stop + 2.0, stop - 2.0, x);
    word *= story > 0.085 || head ? 1.0 : 0.0;
    return band * word * edge * (head ? 1.0 : 0.7);
}

vec3 paperAt(vec2 p, vec2 S, float d) {
    vec3 c = ubuf.paper.rgb;
    // Formation: where the fibres bunched and thinned, at two sizes, and the
    // pixel-fine tooth of the surface.
    float f = (fbm(p / 22.0) - 0.5) * 0.08 + (fbm(p / 90.0 + 17.0) - 0.5) * 0.06;
    f += (h2(floor(p)) - 0.5) * 0.03;
    c *= 1.0 + f;
    c *= 1.0 - fibres(p);

    // The back of the page.
    // (thinner here, thicker there: it shows through unevenly)
    c = mix(c, ubuf.ink.rgb, backPage(p, S) * (0.03 + 0.04 * fbm(p / 75.0 + 30.0)) * ubuf.show);

    vec4 sp = specks(p);
    c = mix(c, sp.rgb, sp.a);

    // Age: yellowed at the edges, browner right at them, and in blooms.
    float inside = max(-d, 0.0);
    float ag = exp(-inside / 4.0) * 0.55 + exp(-inside / 30.0) * 0.2 + exp(-inside / 160.0) * 0.12;
    ag += smoothstep(0.62, 0.86, fbm(p / 130.0 + 40.0)) * 0.22;
    c = mix(c, ubuf.shade.rgb, clamp(ag * ubuf.age, 0.0, 1.0));

    // A tear shows the paler fibres inside the sheet.
    float tw = tornNear(p, S);
    c = mix(c, vec3(0.965, 0.955, 0.93), tw * (0.55 + 0.45 * noise(p / 1.7)));
    return c;
}

// The light across a crease, `u` px from it: the face towards the light
// lighter, the other darker, a dark valley and a bright lip.
float creaseLight(float u) {
    float s = -sign(u) * (0.04 * exp(-abs(u) / 34.0) + 0.018 * exp(-abs(u) / 200.0));
    s -= 0.13 * exp(-abs(u + 0.3) / 0.8);
    s += 0.09 * exp(-abs(u - 1.5) / 1.0);
    return s;
}

// Strips of yellowed tape. Premultiplied.
vec4 tapeAt(vec2 p, vec2 S) {
    int n = int(ubuf.tape + 0.5);
    if (n == 0)
        return vec4(0.0);
    vec4 acc = vec4(0.0);
    for (int i = 0; i < 2; i++) {
        float fi = float(i);
        vec2 c;
        float ang;
        vec2 size;
        if (n == 1) {
            if (i > 0)
                break;
            c = vec2(S.x * (0.5 + (h1(71.0) - 0.5) * 0.36), 1.5);
            ang = (h1(72.0) - 0.5) * 0.14;
            size = vec2(min(84.0, S.x * 0.4), 22.0);
        } else {
            bool right = n == 4 || (n == 2 && i == 1);
            if (n != 2 && i > 0)
                break;
            c = vec2(right ? S.x - 8.0 : 8.0, 7.0);
            ang = (right ? 0.76 : -0.76) + (h1(73.0 + fi) - 0.5) * 0.22;
            size = vec2(58.0, 19.0);
        }
        vec2 q = p - c;
        q = vec2(cos(ang) * q.x + sin(ang) * q.y, -sin(ang) * q.x + cos(ang) * q.y);
        // The dispenser's teeth on its ends.
        float teeth = abs(fract(q.y / 2.6 + h1(74.0 + fi)) - 0.5) * 1.8;
        float ex = size.x * 0.5 - teeth - abs(q.x);
        float ey = size.y * 0.5 - abs(q.y);
        float cover = clamp(min(ex, ey) + 0.5, 0.0, 1.0);
        if (cover <= 0.0)
            continue;
        // Film gone amber with age, a little cloudy, dirt along its edges
        // where the glue shows, and a gloss down its length.
        float al = 0.34 + (noise(q / 7.0 + fi * 9.0) - 0.5) * 0.1;
        float rim = exp(-max(ey, 0.0) / 1.0) * 0.26 + exp(-max(ex, 0.0) / 0.9) * 0.14;
        float sheen = exp(-pow((q.y + size.y * 0.2) / 2.6, 2.0)) * (0.5 + 0.5 * noise(vec2(q.x / 9.0, fi)));
        vec3 col = mix(vec3(0.83, 0.72, 0.47), vec3(0.6, 0.5, 0.33), rim / max(al + rim, 0.001));
        col = mix(col, vec3(1.0, 0.98, 0.92), sheen * 0.85);
        al = clamp(al + rim + sheen * 0.2, 0.0, 0.75) * cover;
        vec4 t = vec4(col * al, al);
        acc = t + acc * (1.0 - t.a);
    }
    return acc;
}

void main() {
    vec2 full = vec2(ubuf.itemWidth, ubuf.itemHeight);
    vec2 S = full - 2.0 * ubuf.bleed;
    vec2 p = qt_TexCoord0 * full - ubuf.bleed;
    float d = sheetDist(p, S);
    float L = liftAt(p, S);
    float cover = clamp(0.5 - d, 0.0, 1.0);

    if (ubuf.pass < 0.5) {
        // The shadow: close and soft where the sheet lies flat, wider and
        // fainter under the curl, and a fine dark line where it meets the
        // desk.
        float sa = 0.0;
        if (cover < 1.0 && ubuf.shadow > 0.0) {
            vec2 off = mix(vec2(0.7, 1.4), vec2(3.2, 4.8), L);
            float blur = mix(2.4, 8.5, L);
            float ds = sheetDist(p - off, S);
            sa = (1.0 - smoothstep(-blur * 0.5, blur, ds)) * mix(0.36, 0.26, L);
            sa = max(sa, exp(-max(d, 0.0) / 0.8) * 0.3 * (1.0 - L));
            sa *= ubuf.shadow;
        }
        if (cover <= 0.0) {
            fragColor = vec4(0.0, 0.0, 0.0, sa) * ubuf.qt_Opacity;
            return;
        }
        vec3 c = paperAt(p, S, d);
        fragColor = vec4(c * cover, cover + sa * (1.0 - cover)) * ubuf.qt_Opacity;
        return;
    }

    vec4 o = vec4(0.0);
    if (cover > 0.0) {
        // The ink: starved in blotches, pinholes where it didn't take, and
        // the tooth of the paper through it. Paper-coloured, so it shows on
        // the ink and hardly at all on the bare paper.
        float v = smoothstep(0.5, 0.9, fbm(p / 14.0 + 9.0)) * 0.11;
        v += step(0.988, h2(floor(p) + 5.5)) * 0.42;
        v += step(0.9975, h2(floor(p / 2.0) + 2.5)) * 0.32;
        v += h2(floor(p) + 8.8) * 0.05;

        // The light: from above left, the sheet never quite flat.
        float s = 0.028 * (0.5 - (p.x / S.x * 0.4 + p.y / S.y * 0.6));
        s += (fbm(p / 170.0 + 21.0) - 0.5) * 0.06;

        // Creases, a little off square; the ink cracks along them.
        if (ubuf.foldY >= 0.0) {
            float u = p.y - ubuf.foldY * S.y - (p.x - S.x * 0.5) * (h1(81.0) - 0.5) * 0.02;
            s += creaseLight(u);
            v += exp(-abs(u) / 0.7) * 0.5 * smoothstep(0.35, 0.6, n1(p.x / 3.5 + 3.0));
        }
        if (ubuf.foldX >= 0.0) {
            float u = p.x - ubuf.foldX * S.x - (p.y - S.y * 0.5) * (h1(82.0) - 0.5) * 0.02;
            s += creaseLight(u);
            v += exp(-abs(u) / 0.7) * 0.5 * smoothstep(0.35, 0.6, n1(p.y / 3.5 + 9.0));
        }

        // The curl turns the corner away from the light; a sheen where it
        // starts to bend.
        s -= 0.085 * pow(L, 1.4);
        s += 0.03 * exp(-pow((L / max(ubuf.lift, 0.001) - 0.22) / 0.09, 2.0)) * step(0.001, L);

        v = clamp(v, 0.0, 0.8);
        float k = clamp(abs(s), 0.0, 0.5);
        vec3 lc = s > 0.0 ? vec3(1.0) : vec3(0.0);
        o = vec4(lc * k + ubuf.paper.rgb * v * (1.0 - k), 1.0 - (1.0 - v) * (1.0 - k)) * cover;
    }
    vec4 t = tapeAt(p, S);
    fragColor = (t + o * (1.0 - t.a)) * ubuf.qt_Opacity;
}
