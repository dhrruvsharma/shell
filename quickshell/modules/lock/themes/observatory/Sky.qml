pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services as Services

// Palette, type and the heavens for the Observatory desktop theme and its
// "Astrolabe" lock screen: aged brass and the wallpaper's colour as the
// enamel of the sky (services/DesktopTheme.qml accentOf/accent2Of, tone
// "brass"), parchment and ink; a small almanac reckoned for an observing
// site taken from the time zone (sidereal time, the Sun, the Moon and the
// five wandering planets from low-precision orbital elements, good to a
// degree or so, and some 150 bright stars with the old constellation
// figures); and the ranks of the observatory for the shared lock level. XP
// is observations logged.
Singleton {
    id: root

    readonly property string display: "IM FELL English"
    readonly property string caps: "IM FELL English SC"
    readonly property string book: "EB Garamond"
    readonly property string engraved: "Marcellus SC"
    readonly property string symbols: "Noto Sans Symbols"

    readonly property color brass: Services.DesktopTheme.accentOf("observatory")
    readonly property color enamel: Services.DesktopTheme.accent2Of("observatory")
    readonly property color brassHi: Qt.hsla(Math.max(0, brass.hslHue), 0.62, 0.74, 1)
    readonly property color brassDeep: Qt.hsla(Math.max(0, brass.hslHue), 0.42, 0.2, 1)
    readonly property color enamelDeep: Qt.hsla(Math.max(0, enamel.hslHue), 0.46, 0.13, 1)
    readonly property color night: "#090d18"
    readonly property color parchment: "#ece2c6"
    readonly property color ink: "#221b12"
    readonly property color verdigris: "#72b3a0"
    readonly property color lamp: "#ffd184"
    readonly property color danger: "#e36a4c"

    function alpha(c, x) {
        return Qt.rgba(c.r, c.g, c.b, x);
    }

    // 1240 -> "1,240"
    function count(n) {
        return Math.round(n).toLocaleString(Qt.locale("en_US"), "f", 0);
    }

    // ── The observing site ──────────────────────────────────────────────────
    // Taken from the time zone (the system's /etc/localtime): an observatory
    // or the zone's own city, near enough for a chart of the sky. Unknown
    // zones fall back to the zone's meridian at 35° north.
    readonly property var sites: ({
        "Asia/Kolkata": ["Jantar Mantar, Jaipur", 26.924, 75.824],
        "Asia/Calcutta": ["Jantar Mantar, Jaipur", 26.924, 75.824],
        "Asia/Karachi": ["Karachi", 24.86, 67.01],
        "Asia/Dhaka": ["Dhaka", 23.81, 90.41],
        "Asia/Kathmandu": ["Kathmandu", 27.72, 85.32],
        "Asia/Colombo": ["Colombo", 6.93, 79.85],
        "Asia/Dubai": ["Dubai", 25.2, 55.27],
        "Asia/Tehran": ["Maragheh Observatory", 37.39, 46.22],
        "Asia/Baghdad": ["House of Wisdom, Baghdad", 33.31, 44.37],
        "Asia/Samarkand": ["Ulugh Beg's Observatory, Samarkand", 39.67, 66.98],
        "Asia/Tashkent": ["Ulugh Beg's Observatory, Samarkand", 39.67, 66.98],
        "Asia/Shanghai": ["Ancient Observatory, Beijing", 39.9, 116.43],
        "Asia/Hong_Kong": ["Hong Kong", 22.32, 114.17],
        "Asia/Taipei": ["Taipei", 25.03, 121.57],
        "Asia/Seoul": ["Cheomseongdae, Gyeongju", 35.83, 129.22],
        "Asia/Tokyo": ["Tokyo", 35.68, 139.69],
        "Asia/Singapore": ["Singapore", 1.35, 103.82],
        "Asia/Bangkok": ["Bangkok", 13.75, 100.5],
        "Asia/Jakarta": ["Jakarta", -6.2, 106.85],
        "Asia/Manila": ["Manila", 14.6, 120.98],
        "Europe/London": ["Royal Observatory, Greenwich", 51.477, 0.0],
        "Europe/Dublin": ["Dunsink Observatory", 53.39, -6.34],
        "Europe/Paris": ["Paris Observatory", 48.836, 2.336],
        "Europe/Copenhagen": ["Uraniborg, Hven", 55.908, 12.696],
        "Europe/Stockholm": ["Stockholm", 59.33, 18.07],
        "Europe/Oslo": ["Oslo", 59.91, 10.75],
        "Europe/Helsinki": ["Helsinki", 60.17, 24.94],
        "Europe/Berlin": ["Berlin", 52.52, 13.4],
        "Europe/Amsterdam": ["Leiden Observatory", 52.155, 4.484],
        "Europe/Prague": ["The Astronomical Clock, Prague", 50.087, 14.421],
        "Europe/Vienna": ["Vienna", 48.21, 16.37],
        "Europe/Warsaw": ["Frombork", 54.357, 19.681],
        "Europe/Rome": ["Rome", 41.9, 12.5],
        "Europe/Madrid": ["Madrid", 40.42, -3.7],
        "Europe/Lisbon": ["Lisbon", 38.72, -9.14],
        "Europe/Athens": ["Athens", 37.98, 23.73],
        "Europe/Istanbul": ["Taqi ad-Din's Observatory, Istanbul", 41.03, 28.98],
        "Europe/Moscow": ["Moscow", 55.75, 37.62],
        "Europe/Kyiv": ["Kyiv", 50.45, 30.52],
        "Africa/Cairo": ["Alexandria", 31.2, 29.92],
        "Africa/Lagos": ["Lagos", 6.52, 3.38],
        "Africa/Nairobi": ["Nairobi", -1.29, 36.82],
        "Africa/Johannesburg": ["Johannesburg", -26.2, 28.05],
        "Australia/Sydney": ["Sydney Observatory", -33.86, 151.2],
        "Australia/Melbourne": ["Melbourne", -37.81, 144.96],
        "Australia/Brisbane": ["Brisbane", -27.47, 153.03],
        "Australia/Adelaide": ["Adelaide", -34.93, 138.6],
        "Australia/Perth": ["Perth", -31.95, 115.86],
        "Pacific/Auckland": ["Auckland", -36.85, 174.76],
        "America/New_York": ["New York", 40.71, -74.0],
        "America/Toronto": ["Toronto", 43.65, -79.38],
        "America/Chicago": ["Yerkes Observatory", 42.57, -88.56],
        "America/Denver": ["Denver", 39.74, -104.99],
        "America/Phoenix": ["Lowell Observatory, Flagstaff", 35.2, -111.66],
        "America/Los_Angeles": ["Mount Wilson Observatory", 34.22, -118.06],
        "America/Vancouver": ["Vancouver", 49.28, -123.12],
        "America/Mexico_City": ["Mexico City", 19.43, -99.13],
        "America/Merida": ["El Caracol, Chichén Itzá", 20.68, -88.57],
        "America/Bogota": ["Bogotá", 4.71, -74.07],
        "America/Lima": ["Lima", -12.05, -77.04],
        "America/Santiago": ["Santiago", -33.45, -70.67],
        "America/Sao_Paulo": ["São Paulo", -23.55, -46.63],
        "America/Argentina/Buenos_Aires": ["Buenos Aires", -34.6, -58.38],
        "UTC": ["Greenwich", 51.477, 0.0],
        "Etc/UTC": ["Greenwich", 51.477, 0.0]
    })

    property string zone: ""
    readonly property var site: {
        const s = sites[zone];
        if (s)
            return { name: s[0], lat: s[1], lon: s[2] };
        return { name: "your meridian", lat: 35, lon: -new Date().getTimezoneOffset() / 4 };
    }

    Process {
        running: true
        command: ["sh", "-c", "[ -n \"$TZ\" ] && echo \"${TZ#:}\" || readlink /etc/localtime"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                const i = t.indexOf("zoneinfo/");
                root.zone = i >= 0 ? t.slice(i + 9) : t;
            }
        }
    }

    // 26.924 -> "26°55′ N"
    function dms(v, pos, neg) {
        const a = Math.abs(v);
        const d = Math.floor(a);
        const m = Math.round((a - d) * 60);
        return (m === 60 ? d + 1 : d) + "°" + String(m === 60 ? 0 : m).padStart(2, "0") + "′ " + (v >= 0 ? pos : neg);
    }

    readonly property string siteLine: site.name + "  ·  " + dms(site.lat, "N", "S") + "  " + dms(site.lon, "E", "W")

    // ── Time ────────────────────────────────────────────────────────────────
    readonly property real d2r: Math.PI / 180

    function rev(x) {
        return x - Math.floor(x / 360) * 360;
    }

    function jd(date) {
        return date.getTime() / 86400000 + 2440587.5;
    }

    // Greenwich and local mean sidereal time, degrees.
    function gmst(date) {
        return rev(280.46061837 + 360.98564736629 * (jd(date) - 2451545.0));
    }

    function lst(date) {
        return rev(gmst(date) + site.lon);
    }

    // 213.5 -> "14ʰ 14ᵐ"
    function hm(deg) {
        const m = Math.floor(rev(deg) * 4);
        return Math.floor(m / 60) + "ʰ " + String(m % 60).padStart(2, "0") + "ᵐ";
    }

    // ── The Sun, the Moon and the planets ───────────────────────────────────
    // After Paul Schlyter's "How to compute planetary positions": elements
    // as linear functions of the day number, the main perturbations of the
    // Moon, Jupiter and Saturn, and the Moon's parallax.
    function _day(date) {
        return jd(date) - 2451543.5;
    }

    function _kepler(M, e) {
        let E = M + (e / d2r) * Math.sin(M * d2r) * (1 + e * Math.cos(M * d2r));
        for (let k = 0; k < 6; k++)
            E = E - (E - (e / d2r) * Math.sin(E * d2r) - M) / (1 - e * Math.cos(E * d2r));
        return E;
    }

    // Ecliptic longitude/latitude (degrees) and distance -> RA/Dec (degrees).
    function _toEquatorial(lon, lat, d) {
        const ecl = (23.4393 - 3.563e-7 * d) * d2r;
        const x = Math.cos(lon * d2r) * Math.cos(lat * d2r);
        const y = Math.sin(lon * d2r) * Math.cos(lat * d2r);
        const z = Math.sin(lat * d2r);
        const ye = y * Math.cos(ecl) - z * Math.sin(ecl);
        const ze = y * Math.sin(ecl) + z * Math.cos(ecl);
        return { ra: rev(Math.atan2(ye, x) / d2r), dec: Math.atan2(ze, Math.sqrt(x * x + ye * ye)) / d2r };
    }

    function sun(date) {
        const d = _day(date);
        const w = 282.9404 + 4.70935e-5 * d;
        const e = 0.016709 - 1.151e-9 * d;
        const M = rev(356.047 + 0.9856002585 * d);
        const E = _kepler(M, e);
        const xv = Math.cos(E * d2r) - e;
        const yv = Math.sqrt(1 - e * e) * Math.sin(E * d2r);
        const lon = rev(Math.atan2(yv, xv) / d2r + w);
        const r = Math.sqrt(xv * xv + yv * yv);
        const eq = _toEquatorial(lon, 0, d);
        return { lon: lon, lat: 0, r: r, ra: eq.ra, dec: eq.dec, M: M, L: rev(M + w), x: r * Math.cos(lon * d2r), y: r * Math.sin(lon * d2r) };
    }

    function _sin(x) {
        return Math.sin(x * d2r);
    }

    function _cos(x) {
        return Math.cos(x * d2r);
    }

    function moon(date) {
        const d = _day(date);
        const N = rev(125.1228 - 0.0529538083 * d);
        const i = 5.1454;
        const w = rev(318.0634 + 0.1643573223 * d);
        const a = 60.2666;
        const e = 0.0549;
        const M = rev(115.3654 + 13.0649929509 * d);
        const E = _kepler(M, e);
        const xv = a * (_cos(E) - e);
        const yv = a * Math.sqrt(1 - e * e) * _sin(E);
        const v = Math.atan2(yv, xv) / d2r;
        const r = Math.sqrt(xv * xv + yv * yv);
        const xh = r * (_cos(N) * _cos(v + w) - _sin(N) * _sin(v + w) * _cos(i));
        const yh = r * (_sin(N) * _cos(v + w) + _cos(N) * _sin(v + w) * _cos(i));
        const zh = r * _sin(v + w) * _sin(i);
        let lon = Math.atan2(yh, xh) / d2r;
        let lat = Math.atan2(zh, Math.sqrt(xh * xh + yh * yh)) / d2r;
        const s = sun(date);
        const Ms = s.M, Mm = M;
        const Lm = rev(N + w + M);
        const D = rev(Lm - s.L);
        const F = rev(Lm - N);
        lon += -1.274 * _sin(Mm - 2 * D) + 0.658 * _sin(2 * D) - 0.186 * _sin(Ms)
            - 0.059 * _sin(2 * Mm - 2 * D) - 0.057 * _sin(Mm - 2 * D + Ms) + 0.053 * _sin(Mm + 2 * D)
            + 0.046 * _sin(2 * D - Ms) + 0.041 * _sin(Mm - Ms) - 0.035 * _sin(D)
            - 0.031 * _sin(Mm + Ms) - 0.015 * _sin(2 * F - 2 * D) + 0.011 * _sin(Mm - 4 * D);
        lat += -0.173 * _sin(F - 2 * D) - 0.055 * _sin(Mm - F - 2 * D) - 0.046 * _sin(Mm + F - 2 * D)
            + 0.033 * _sin(F + 2 * D) + 0.017 * _sin(2 * Mm + F);
        lon = rev(lon);
        const eq = _toEquatorial(lon, lat, d);
        // Elongation from the Sun: how much of the disc is lit, and whether
        // it's growing.
        const el = rev(lon - s.lon);
        const cosElong = _cos(lon - s.lon) * _cos(lat);
        return {
            lon: lon, lat: lat, ra: eq.ra, dec: eq.dec,
            dist: r - 0.58 * _cos(Mm - 2 * D) - 0.46 * _cos(2 * D),
            illum: (1 - cosElong) / 2,
            waxing: el < 180,
            age: el / 360 * 29.530588
        };
    }

    // The five wanderers the ancients knew: elements at day 0 and their
    // rates, [N, dN, i, di, w, dw, a, e, de, M, dM].
    readonly property var planetElements: [
        { key: "mercury", name: "Mercury", glyph: "☿", el: [48.3313, 3.24587e-5, 7.0047, 5.0e-8, 29.1241, 1.01444e-5, 0.387098, 0.205635, 5.59e-10, 168.6562, 4.0923344368] },
        { key: "venus", name: "Venus", glyph: "♀", el: [76.6799, 2.4659e-5, 3.3946, 2.75e-8, 54.891, 1.38374e-5, 0.72333, 0.006773, -1.302e-9, 48.0052, 1.6021302244] },
        { key: "mars", name: "Mars", glyph: "♂", el: [49.5574, 2.11081e-5, 1.8497, -1.78e-8, 286.5016, 2.92961e-5, 1.523688, 0.093405, 2.516e-9, 18.6021, 0.5240207766] },
        { key: "jupiter", name: "Jupiter", glyph: "♃", el: [100.4542, 2.76854e-5, 1.303, -1.557e-7, 273.8777, 1.64505e-5, 5.20256, 0.048498, 4.469e-9, 19.895, 0.0830853001] },
        { key: "saturn", name: "Saturn", glyph: "♄", el: [113.6634, 2.3898e-5, 2.4886, -1.081e-7, 339.3939, 2.97661e-5, 9.55475, 0.055546, -9.499e-9, 316.967, 0.0334442282] }
    ]

    function planets(date) {
        const d = _day(date);
        const s = sun(date);
        const Mj = rev(19.895 + 0.0830853001 * d);
        const Msat = rev(316.967 + 0.0334442282 * d);
        const out = [];
        for (let k = 0; k < planetElements.length; k++) {
            const p = planetElements[k];
            const q = p.el;
            const N = q[0] + q[1] * d, i = q[2] + q[3] * d, w = q[4] + q[5] * d;
            const a = q[6], e = q[7] + q[8] * d, M = rev(q[9] + q[10] * d);
            const E = _kepler(M, e);
            const xv = a * (_cos(E) - e);
            const yv = a * Math.sqrt(1 - e * e) * _sin(E);
            const v = Math.atan2(yv, xv) / d2r;
            const r = Math.sqrt(xv * xv + yv * yv);
            let xh = r * (_cos(N) * _cos(v + w) - _sin(N) * _sin(v + w) * _cos(i));
            let yh = r * (_sin(N) * _cos(v + w) + _cos(N) * _sin(v + w) * _cos(i));
            let zh = r * _sin(v + w) * _sin(i);
            if (p.key === "jupiter" || p.key === "saturn") {
                let lon = Math.atan2(yh, xh) / d2r;
                let lat = Math.atan2(zh, Math.sqrt(xh * xh + yh * yh)) / d2r;
                if (p.key === "jupiter") {
                    lon += -0.332 * _sin(2 * Mj - 5 * Msat - 67.6) - 0.056 * _sin(2 * Mj - 2 * Msat + 21)
                        + 0.042 * _sin(3 * Mj - 5 * Msat + 21) - 0.036 * _sin(Mj - 2 * Msat)
                        + 0.022 * _cos(Mj - Msat) + 0.023 * _sin(2 * Mj - 3 * Msat + 52) - 0.016 * _sin(Mj - 5 * Msat - 69);
                } else {
                    lon += 0.812 * _sin(2 * Mj - 5 * Msat - 67.6) - 0.229 * _cos(2 * Mj - 4 * Msat - 2)
                        + 0.119 * _sin(Mj - 2 * Msat - 3) + 0.046 * _sin(2 * Mj - 6 * Msat - 69) + 0.014 * _sin(Mj - 3 * Msat + 32);
                    lat += -0.02 * _cos(2 * Mj - 4 * Msat - 2) + 0.018 * _sin(2 * Mj - 6 * Msat - 49);
                }
                xh = r * _cos(lon) * _cos(lat);
                yh = r * _sin(lon) * _cos(lat);
                zh = r * _sin(lat);
            }
            // Seen from the Earth.
            const xg = xh + s.x, yg = yh + s.y, zg = zh;
            const glon = rev(Math.atan2(yg, xg) / d2r);
            const glat = Math.atan2(zg, Math.sqrt(xg * xg + yg * yg)) / d2r;
            const eq = _toEquatorial(glon, glat, d);
            out.push({ key: p.key, name: p.name, glyph: glyph(p.glyph), lon: glon, lat: glat, ra: eq.ra, dec: eq.dec, dist: Math.sqrt(xg * xg + yg * yg + zg * zg) });
        }
        return out;
    }

    // Altitude and azimuth (degrees; azimuth from north through east) of
    // RA/Dec (degrees) at local sidereal time `lstDeg`.
    function altAz(ra, dec, lstDeg) {
        const H = (lstDeg - ra) * d2r, d = dec * d2r, p = site.lat * d2r;
        const alt = Math.asin(Math.sin(d) * Math.sin(p) + Math.cos(d) * Math.cos(p) * Math.cos(H));
        const x = -Math.cos(d) * Math.sin(H);
        const y = Math.sin(d) * Math.cos(p) - Math.cos(d) * Math.sin(p) * Math.cos(H);
        return { alt: alt / d2r, az: rev(Math.atan2(x, y) / d2r) };
    }

    // ── The zodiac and the Moon's face ──────────────────────────────────────
    // An astronomical sign as text: most of these default to colour emoji,
    // so each carries the text presentation selector (U+FE0E).
    function glyph(g) {
        return g + String.fromCharCode(0xFE0E);
    }

    readonly property var zodiac: [
        ["Aries", glyph("♈")], ["Taurus", glyph("♉")], ["Gemini", glyph("♊")], ["Cancer", glyph("♋")],
        ["Leo", glyph("♌")], ["Virgo", glyph("♍")], ["Libra", glyph("♎")], ["Scorpio", glyph("♏")],
        ["Sagittarius", glyph("♐")], ["Capricorn", glyph("♑")], ["Aquarius", glyph("♒")], ["Pisces", glyph("♓")]
    ]

    function signOf(lon) {
        return zodiac[Math.floor(rev(lon) / 30) % 12];
    }

    function phaseName(m) {
        const a = m.age;
        return a < 1.85 ? "New Moon" : a < 5.54 ? "Waxing Crescent" : a < 9.23 ? "First Quarter"
            : a < 12.92 ? "Waxing Gibbous" : a < 16.61 ? "Full Moon" : a < 20.3 ? "Waning Gibbous"
            : a < 23.99 ? "Last Quarter" : a < 27.68 ? "Waning Crescent" : "New Moon";
    }

    // ── The fixed stars ─────────────────────────────────────────────────────
    // [key, name ("" for none shown), RA (hours), Dec (degrees), magnitude]
    readonly property var stars: [
        ["betelgeuse", "Betelgeuse", 5.9195, 7.4071, 0.5], ["rigel", "Rigel", 5.2423, -8.2016, 0.13],
        ["bellatrix", "Bellatrix", 5.4189, 6.3497, 1.64], ["mintaka", "", 5.5334, -0.2991, 2.23],
        ["alnilam", "", 5.6036, -1.2019, 1.69], ["alnitak", "", 5.6793, -1.9426, 1.77],
        ["saiph", "", 5.7959, -9.6696, 2.09], ["meissa", "", 5.5856, 9.9342, 3.39],
        ["aldebaran", "Aldebaran", 4.5987, 16.5093, 0.86], ["elnath", "Elnath", 5.4382, 28.6075, 1.65],
        ["tianguan", "", 5.6275, 21.1426, 3.0], ["ain", "", 4.4769, 19.1804, 3.53],
        ["primahyadum", "", 4.33, 15.6276, 3.65], ["delta1tau", "", 4.3822, 17.5425, 3.76],
        ["lambdatau", "", 4.0114, 12.4903, 3.47], ["alcyone", "Pleiades", 3.7914, 24.1051, 2.87],
        ["castor", "Castor", 7.5767, 31.8883, 1.58], ["pollux", "Pollux", 7.7553, 28.0262, 1.14],
        ["alhena", "", 6.6285, 16.3993, 1.93], ["mebsuta", "", 6.7322, 25.1311, 2.98],
        ["tejat", "", 6.3827, 22.5136, 2.87], ["wasat", "", 7.3353, 21.9823, 3.53],
        ["propus", "", 6.2479, 22.5068, 3.3],
        ["sirius", "Sirius", 6.7525, -16.7161, -1.46], ["mirzam", "", 6.3783, -17.9559, 1.98],
        ["adhara", "Adhara", 6.9771, -28.9721, 1.5], ["wezen", "", 7.1399, -26.3932, 1.83],
        ["aludra", "", 7.4016, -29.3031, 2.45], ["furud", "", 6.3386, -30.0634, 3.02],
        ["procyon", "Procyon", 7.655, 5.225, 0.34], ["gomeisa", "", 7.4525, 8.2893, 2.89],
        ["capella", "Capella", 5.2782, 45.998, 0.08], ["menkalinan", "", 5.9921, 44.9474, 1.9],
        ["mahasim", "", 5.9954, 37.2126, 2.62], ["hassaleh", "", 4.9499, 33.1661, 2.69],
        ["regulus", "Regulus", 10.1395, 11.9672, 1.35], ["denebola", "Denebola", 11.8177, 14.5721, 2.13],
        ["algieba", "", 10.3329, 19.8415, 2.08], ["zosma", "", 11.2351, 20.5237, 2.56],
        ["chertan", "", 11.2373, 15.4296, 3.33], ["etaleo", "", 10.1222, 16.7627, 3.49],
        ["adhafera", "", 10.2782, 23.4173, 3.44], ["rasalas", "", 9.8794, 26.007, 3.88],
        ["epsleo", "", 9.7642, 23.7743, 2.98],
        ["spica", "Spica", 13.4199, -11.1613, 0.97], ["porrima", "", 12.6944, -1.4494, 2.74],
        ["vindemiatrix", "", 13.0363, 10.9592, 2.83], ["minelauva", "", 12.9267, 3.3975, 3.38],
        ["zavijava", "", 11.8449, 1.7647, 3.6], ["heze", "", 13.5783, -0.5958, 3.37],
        ["arcturus", "Arcturus", 14.261, 19.1824, -0.05], ["izar", "", 14.7498, 27.0742, 2.37],
        ["muphrid", "", 13.9114, 18.3977, 2.68], ["seginus", "", 14.5347, 38.3083, 3.03],
        ["nekkar", "", 15.0324, 40.3906, 3.5], ["deltaboo", "", 15.2584, 33.3148, 3.47],
        ["rhoboo", "", 14.5306, 30.3714, 3.58], ["alphecca", "Alphecca", 15.5781, 26.7147, 2.23],
        ["antares", "Antares", 16.4901, -26.432, 0.96], ["dschubba", "", 16.0056, -22.6217, 2.29],
        ["acrab", "", 16.0907, -19.8054, 2.62], ["fang", "", 15.9809, -26.1141, 2.89],
        ["alniyat", "", 16.3531, -25.5928, 2.89], ["tausco", "", 16.598, -28.216, 2.82],
        ["larawag", "", 16.8361, -34.2932, 2.29], ["mu1sco", "", 16.8645, -38.0474, 3.0],
        ["zeta2sco", "", 16.9097, -42.3614, 3.62], ["etasco", "", 17.2025, -43.2392, 3.33],
        ["sargas", "", 17.6219, -42.9978, 1.86], ["iota1sco", "", 17.7931, -40.127, 3.0],
        ["girtab", "", 17.7081, -39.03, 2.39], ["shaula", "Shaula", 17.5601, -37.1038, 1.62],
        ["kausaustralis", "", 18.4029, -34.3846, 1.85], ["nunki", "Nunki", 18.9211, -26.2967, 2.05],
        ["ascella", "", 19.0435, -29.8801, 2.6], ["kausmedia", "", 18.3499, -29.8281, 2.7],
        ["kausborealis", "", 18.4662, -25.4217, 2.8], ["alnasl", "", 18.0968, -30.4241, 2.98],
        ["phisgr", "", 18.7609, -26.9908, 3.17], ["tausgr", "", 19.1156, -27.6704, 3.3],
        ["vega", "Vega", 18.6156, 38.7837, 0.03], ["sheliak", "", 18.8347, 33.3627, 3.5],
        ["sulafat", "", 18.9824, 32.6896, 3.25], ["zetalyr", "", 18.7462, 37.6051, 4.3],
        ["delta2lyr", "", 18.9083, 36.8986, 4.3],
        ["deneb", "Deneb", 20.6905, 45.2803, 1.25], ["sadr", "", 20.3705, 40.2567, 2.23],
        ["albireo", "Albireo", 19.512, 27.9597, 3.05], ["aljanah", "", 20.7702, 33.9703, 2.48],
        ["fawaris", "", 19.7495, 45.1308, 2.87], ["zetacyg", "", 21.2156, 30.2269, 3.2],
        ["altair", "Altair", 19.8464, 8.8683, 0.76], ["tarazed", "", 19.771, 10.6133, 2.72],
        ["alshain", "", 19.9219, 6.4068, 3.71], ["okab", "", 19.0902, 13.8635, 2.99],
        ["deltaaql", "", 19.4249, 3.1148, 3.36], ["lambdaaql", "", 19.1041, -4.8826, 3.43],
        ["thetaaql", "", 20.1884, -0.8215, 3.24],
        ["dubhe", "Dubhe", 11.0621, 61.7508, 1.79], ["merak", "", 11.0307, 56.3824, 2.37],
        ["phecda", "", 11.8972, 53.6948, 2.44], ["megrez", "", 12.2571, 57.0326, 3.31],
        ["alioth", "Alioth", 12.9005, 55.9598, 1.77], ["mizar", "", 13.3988, 54.9254, 2.23],
        ["alkaid", "Alkaid", 13.7923, 49.3133, 1.86],
        ["polaris", "Polaris", 2.5303, 89.2641, 1.98], ["kochab", "Kochab", 14.8451, 74.1555, 2.08],
        ["pherkad", "", 15.3455, 71.834, 3.0], ["yildun", "", 17.5369, 86.5865, 4.35],
        ["epsumi", "", 16.7661, 82.0373, 4.2], ["zetaumi", "", 15.7343, 77.7945, 4.3],
        ["etaumi", "", 16.2918, 75.7553, 4.95],
        ["caph", "", 0.153, 59.1498, 2.28], ["schedar", "Schedar", 0.6751, 56.5373, 2.24],
        ["navi", "", 0.9451, 60.7167, 2.15], ["ruchbah", "", 1.4302, 60.2353, 2.66],
        ["segin", "", 1.9066, 63.6701, 3.35],
        ["mirfak", "Mirfak", 3.4054, 49.8612, 1.79], ["algol", "Algol", 3.1361, 40.9556, 2.1],
        ["deltaper", "", 3.7154, 47.7876, 3.0], ["epsper", "", 3.9642, 40.0102, 2.9],
        ["gammaper", "", 3.0799, 53.5064, 2.9], ["zetaper", "", 3.9022, 31.8836, 2.85],
        ["alpheratz", "Alpheratz", 0.1398, 29.0904, 2.06], ["deltaand", "", 0.6555, 30.861, 3.27],
        ["mirach", "", 1.1622, 35.6206, 2.07], ["almach", "", 2.065, 42.3297, 2.1],
        ["markab", "Markab", 23.0794, 15.2053, 2.49], ["scheat", "", 23.0629, 28.0828, 2.42],
        ["algenib", "", 0.2206, 15.1836, 2.83], ["enif", "Enif", 21.7364, 9.875, 2.39],
        ["homam", "", 22.691, 10.8314, 3.4], ["biham", "", 22.17, 6.1979, 3.53],
        ["hamal", "Hamal", 2.1196, 23.4624, 2.0], ["sheratan", "", 1.9107, 20.808, 2.64],
        ["mesarthim", "", 1.8922, 19.2939, 3.9],
        ["acrux", "Acrux", 12.4433, -63.099, 0.76], ["mimosa", "Mimosa", 12.7954, -59.6888, 1.25],
        ["gacrux", "", 12.5194, -57.1132, 1.63], ["imai", "", 12.2524, -58.7489, 2.79],
        ["rigilkent", "Rigil Kentaurus", 14.66, -60.835, -0.27], ["hadar", "Hadar", 14.0637, -60.373, 0.61],
        ["menkent", "", 14.1114, -36.37, 2.06],
        ["canopus", "Canopus", 6.3992, -52.6957, -0.74], ["miaplacidus", "", 9.22, -69.7172, 1.68],
        ["avior", "", 8.3752, -59.5095, 1.86],
        ["regor", "", 8.1589, -47.3366, 1.83], ["deltavel", "", 8.7451, -54.7088, 1.96],
        ["suhail", "", 9.1333, -43.4326, 2.2], ["markeb", "", 9.3686, -55.0107, 2.47],
        ["achernar", "Achernar", 1.6286, -57.2367, 0.46], ["fomalhaut", "Fomalhaut", 22.9608, -29.6222, 1.16],
        ["alphard", "Alphard", 9.4598, -8.6586, 1.98], ["rasalhague", "Rasalhague", 17.5822, 12.56, 2.07],
        ["kornephoros", "", 16.5037, 21.4896, 2.77], ["zetaher", "", 16.6881, 31.6019, 2.81],
        ["piher", "", 17.2507, 36.8092, 3.16], ["etaher", "", 16.7149, 38.9223, 3.48],
        ["epsher", "", 17.0048, 30.9264, 3.92],
        ["eltanin", "Eltanin", 17.9434, 51.4889, 2.24], ["rastaban", "", 17.5072, 52.3014, 2.79],
        ["thuban", "Thuban", 14.0731, 64.3758, 3.65],
        ["alnair", "Alnair", 22.1372, -46.9611, 1.74], ["peacock", "Peacock", 20.4275, -56.7351, 1.94],
        ["atria", "Atria", 16.8111, -69.0277, 1.91],
        ["gienahcrv", "", 12.2634, -17.5419, 2.59], ["kraz", "", 12.5731, -23.3968, 2.65],
        ["algorab", "", 12.4977, -16.5154, 2.95], ["minkar", "", 12.1683, -22.6198, 3.0],
        ["zubenelgenubi", "", 14.848, -16.0418, 2.75], ["zubeneschamali", "", 15.2835, -9.3829, 2.61],
        ["denebalgedi", "", 21.784, -16.1273, 2.87], ["dabih", "", 20.3502, -14.7814, 3.08],
        ["sadalsuud", "", 21.526, -5.5712, 2.9], ["sadalmelik", "", 22.0964, -0.3198, 2.95],
        ["alderamin", "Alderamin", 21.3097, 62.5856, 2.45]
    ]

    // The old figures, as lines between stars.
    readonly property var figures: [
        { name: "Orion", lines: [["meissa", "betelgeuse"], ["meissa", "bellatrix"], ["betelgeuse", "alnitak"], ["bellatrix", "mintaka"], ["mintaka", "alnilam"], ["alnilam", "alnitak"], ["alnitak", "saiph"], ["mintaka", "rigel"]] },
        { name: "Taurus", lines: [["primahyadum", "delta1tau"], ["delta1tau", "ain"], ["ain", "elnath"], ["primahyadum", "aldebaran"], ["aldebaran", "tianguan"], ["primahyadum", "lambdatau"]] },
        { name: "Gemini", lines: [["castor", "pollux"], ["castor", "mebsuta"], ["mebsuta", "tejat"], ["tejat", "propus"], ["pollux", "wasat"], ["wasat", "alhena"]] },
        { name: "Canis Major", lines: [["mirzam", "sirius"], ["sirius", "wezen"], ["wezen", "adhara"], ["wezen", "aludra"], ["adhara", "furud"]] },
        { name: "Canis Minor", lines: [["procyon", "gomeisa"]] },
        { name: "Auriga", lines: [["capella", "menkalinan"], ["menkalinan", "mahasim"], ["mahasim", "elnath"], ["elnath", "hassaleh"], ["hassaleh", "capella"]] },
        { name: "Leo", lines: [["regulus", "etaleo"], ["etaleo", "algieba"], ["algieba", "adhafera"], ["adhafera", "rasalas"], ["rasalas", "epsleo"], ["algieba", "zosma"], ["zosma", "denebola"], ["denebola", "chertan"], ["chertan", "regulus"], ["zosma", "chertan"]] },
        { name: "Virgo", lines: [["zavijava", "porrima"], ["porrima", "spica"], ["porrima", "minelauva"], ["minelauva", "vindemiatrix"], ["minelauva", "heze"], ["heze", "spica"]] },
        { name: "Boötes", lines: [["arcturus", "izar"], ["izar", "deltaboo"], ["deltaboo", "nekkar"], ["nekkar", "seginus"], ["seginus", "rhoboo"], ["rhoboo", "arcturus"], ["arcturus", "muphrid"]] },
        { name: "Scorpius", lines: [["acrab", "dschubba"], ["dschubba", "fang"], ["dschubba", "alniyat"], ["alniyat", "antares"], ["antares", "tausco"], ["tausco", "larawag"], ["larawag", "mu1sco"], ["mu1sco", "zeta2sco"], ["zeta2sco", "etasco"], ["etasco", "sargas"], ["sargas", "iota1sco"], ["iota1sco", "girtab"], ["girtab", "shaula"]] },
        { name: "Sagittarius", lines: [["alnasl", "kausmedia"], ["kausmedia", "kausaustralis"], ["kausaustralis", "alnasl"], ["kausmedia", "kausborealis"], ["kausborealis", "phisgr"], ["phisgr", "kausmedia"], ["phisgr", "nunki"], ["nunki", "tausgr"], ["tausgr", "ascella"], ["ascella", "phisgr"], ["ascella", "kausaustralis"]] },
        { name: "Lyra", lines: [["vega", "zetalyr"], ["zetalyr", "delta2lyr"], ["delta2lyr", "sulafat"], ["sulafat", "sheliak"], ["sheliak", "zetalyr"]] },
        { name: "Cygnus", lines: [["deneb", "sadr"], ["sadr", "albireo"], ["fawaris", "sadr"], ["sadr", "aljanah"], ["aljanah", "zetacyg"]] },
        { name: "Aquila", lines: [["okab", "tarazed"], ["tarazed", "altair"], ["altair", "alshain"], ["alshain", "thetaaql"], ["altair", "deltaaql"], ["deltaaql", "lambdaaql"]] },
        { name: "Ursa Major", lines: [["dubhe", "merak"], ["merak", "phecda"], ["phecda", "megrez"], ["megrez", "dubhe"], ["megrez", "alioth"], ["alioth", "mizar"], ["mizar", "alkaid"]] },
        { name: "Ursa Minor", lines: [["polaris", "yildun"], ["yildun", "epsumi"], ["epsumi", "zetaumi"], ["zetaumi", "kochab"], ["kochab", "pherkad"], ["pherkad", "etaumi"], ["etaumi", "zetaumi"]] },
        { name: "Cassiopeia", lines: [["caph", "schedar"], ["schedar", "navi"], ["navi", "ruchbah"], ["ruchbah", "segin"]] },
        { name: "Perseus", lines: [["gammaper", "mirfak"], ["mirfak", "deltaper"], ["deltaper", "epsper"], ["epsper", "zetaper"], ["mirfak", "algol"]] },
        { name: "Andromeda", lines: [["alpheratz", "deltaand"], ["deltaand", "mirach"], ["mirach", "almach"]] },
        { name: "Pegasus", lines: [["markab", "scheat"], ["scheat", "alpheratz"], ["alpheratz", "algenib"], ["algenib", "markab"], ["markab", "homam"], ["homam", "biham"], ["biham", "enif"]] },
        { name: "Aries", lines: [["hamal", "sheratan"], ["sheratan", "mesarthim"]] },
        { name: "Crux", lines: [["acrux", "gacrux"], ["mimosa", "imai"]] },
        { name: "Centaurus", lines: [["rigilkent", "hadar"], ["hadar", "menkent"]] },
        { name: "Vela", lines: [["regor", "deltavel"], ["deltavel", "markeb"], ["markeb", "suhail"], ["suhail", "regor"]] },
        { name: "Corvus", lines: [["gienahcrv", "algorab"], ["algorab", "kraz"], ["kraz", "minkar"], ["minkar", "gienahcrv"]] },
        { name: "Libra", lines: [["zubenelgenubi", "zubeneschamali"]] },
        { name: "Hercules", lines: [["zetaher", "etaher"], ["etaher", "piher"], ["piher", "epsher"], ["epsher", "zetaher"], ["zetaher", "kornephoros"]] },
        { name: "Draco", lines: [["eltanin", "rastaban"]] },
        { name: "Capricornus", lines: [["dabih", "denebalgedi"]] },
        { name: "Aquarius", lines: [["sadalsuud", "sadalmelik"]] }
    ]

    // key -> index into `stars`.
    readonly property var starIndex: {
        const m = {};
        for (let i = 0; i < stars.length; i++)
            m[stars[i][0]] = i;
        return m;
    }

    // The brightest named star now near the meridian and well up: the one
    // "culminating".
    function culminating(date) {
        const l = lst(date);
        let best = null;
        let bestH = 99;
        for (let i = 0; i < stars.length; i++) {
            const s = stars[i];
            if (!s[1] || s[4] > 1.7)
                continue;
            const aa = altAz(s[2] * 15, s[3], l);
            if (aa.alt < 12)
                continue;
            const h = Math.abs(((l - s[2] * 15) % 360 + 540) % 360 - 180);
            if (h < bestH) {
                bestH = h;
                best = s[1];
            }
        }
        return best ?? "";
    }

    // The rete's stars: the ones the old instrument makers chose, spread
    // round the sky (all inside the tropic of Capricorn, the rete's rim).
    // [name, RA (hours), Dec (degrees)]; shaders/astrolabe.frag has the same
    // list, in the same order.
    readonly property var reteStars: [
        ["Alpheratz", 0.1398, 29.0904], ["Algol", 3.1361, 40.9556], ["Aldebaran", 4.5987, 16.5093],
        ["Sirius", 6.7525, -16.7161], ["Regulus", 10.1395, 11.9672], ["Dubhe", 11.0621, 61.7508],
        ["Spica", 13.4199, -11.1613], ["Arcturus", 14.261, 19.1824], ["Rasalhague", 17.5822, 12.56],
        ["Vega", 18.6156, 38.7837], ["Deneb", 20.6905, 45.2803], ["Markab", 23.0794, 15.2053]
    ]

    // ── The observatory, by lock level (thresholds as LockStats' ranks) ────
    readonly property var ranks: [
        [1, "Stargazer"], [3, "Apprentice"], [5, "Calculator of Tables"], [8, "Observer"],
        [12, "Instrument Maker"], [16, "Cartographer of the Heavens"], [20, "Master of the Astrolabe"],
        [25, "Astronomer"], [30, "Keeper of the Observatory"], [40, "Astronomer Royal"], [50, "Master of the Heavens"]
    ]

    function rank(level) {
        let name = ranks[0][1];
        for (let i = 0; i < ranks.length; i++)
            if (level >= ranks[i][0])
                name = ranks[i][1];
        return name;
    }
}
