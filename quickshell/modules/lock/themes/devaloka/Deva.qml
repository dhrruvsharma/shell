pragma Singleton
import QtQuick
import Quickshell
import qs.modules.lock.themes.observatory
import qs.services as Services

// Palette, type and lore for the Devaloka desktop theme and its "Samudra
// Manthan" lock screen: marigold gold and the wallpaper's colour as a
// painter's pigment (services/DesktopTheme.qml accentOf/accent2Of, tone
// "temple"), lac, ivory and the milk of the ocean; the panchang, the Hindu
// almanac's five limbs of the day (tithi, vara, nakshatra, yoga, karana)
// with the lunar month, the season and the eras, reckoned from the Sun and
// the Moon (Sky, the Observatory's almanac) for the observing site; the
// muhurtas and praharas of the day; the treasures that came up out of the
// churned ocean; and the ranks of the sages for the shared lock level. XP is
// punya, merit.
Singleton {
    id: root

    readonly property string display: "Eczar"
    readonly property string book: "Tiro Devanagari Sanskrit"

    readonly property color gold: Services.DesktopTheme.accentOf("devaloka")
    readonly property color pigment: Services.DesktopTheme.accent2Of("devaloka")
    readonly property color goldHi: Qt.hsla(hueOf(gold), 0.92, 0.78, 1)
    readonly property color goldDeep: Qt.hsla(hueOf(gold), 0.62, 0.2, 1)
    readonly property color pigmentDeep: Qt.hsla(hueOf(pigment), 0.5, 0.13, 1)
    // Lacquered lac, nearly black; the ground of the plaques.
    readonly property color ground: "#170a08"
    readonly property color lac: "#5b1712"
    readonly property color kumkum: "#d8432b"
    readonly property color haldi: "#f4b73c"
    readonly property color ivory: "#f4ead6"
    readonly property color ink: "#2a140e"
    readonly property color milk: "#f3efe6"
    readonly property color poison: "#161c58"
    readonly property color poisonGlow: "#7a6bff"
    readonly property color amrita: "#ffd978"
    readonly property color lotus: "#ec8fb1"
    readonly property color danger: "#ff7456"

    function hueOf(c) {
        return Math.max(0, Qt.color(c).hslHue);
    }

    function alpha(c, x) {
        const q = Qt.color(c);
        return Qt.rgba(q.r, q.g, q.b, x);
    }

    // "10:45" -> "१०:४५".
    function numerals(s) {
        return String(s).replace(/[0-9]/g, d => String.fromCharCode(0x0966 + Number(d)));
    }

    // Indian grouping: 123456 -> "1,23,456".
    function count(n) {
        const s = String(Math.max(0, Math.round(n)));
        if (s.length <= 3)
            return s;
        const head = s.slice(0, -3);
        return head.replace(/\B(?=(\d{2})+(?!\d))/g, ",") + "," + s.slice(-3);
    }

    // 1 -> "1st", 22 -> "22nd".
    function ordinal(n) {
        const t = n % 100;
        return n + (t >= 11 && t <= 13 ? "th" : ["th", "st", "nd", "rd"][n % 10] ?? "th");
    }

    // ── The almanac ─────────────────────────────────────────────────────────
    // Sidereal longitudes, as the panchang reckons them: the tropical ones
    // less the precession since the zodiacs coincided (Lahiri's ayanamsa,
    // 23°51′11″ at J2000, growing 50.29″ a year).
    function ayanamsa(date) {
        return 23.8531 + (Sky.jd(date) - 2451545.0) / 365.25 * 0.0139694;
    }

    function sidereal(lon, date) {
        return Sky.rev(lon - ayanamsa(date));
    }

    // How far the Moon is ahead of the Sun, degrees.
    function elongation(date) {
        return Sky.rev(Sky.moon(date).lon - Sky.sun(date).lon);
    }

    // The new moon before (dir -1) or after (dir 1) `date`, to a minute or
    // so: stepped back by the Moon's mean gain on the Sun until the gap
    // closes.
    function newMoon(date, dir) {
        const e = elongation(date);
        let t = date.getTime() + (dir < 0 ? -e : 360 - e) / 12.19 * 86400000;
        for (let k = 0; k < 5; k++) {
            let x = elongation(new Date(t));
            if (x > 180)
                x -= 360;
            t -= x / 12.19 * 86400000;
        }
        return new Date(t);
    }

    // Sunrise, noon and sunset at the site on `date`'s civil day (the upper
    // limb on a refracted horizon).
    function sunEvents(date) {
        const lon = Sky.site.lon;
        const lat = Sky.site.lat;
        const base = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 12, 0, 0);
        let t = base.getTime() - (lon / 15 + base.getTimezoneOffset() / 60) * 3600000;
        let rise = t - 6 * 3600000;
        let set = t + 6 * 3600000;
        for (let k = 0; k < 2; k++) {
            const s = Sky.sun(new Date(t));
            let h = Sky.rev(Sky.gmst(new Date(t)) + lon - s.ra);
            if (h > 180)
                h -= 360;
            t -= h / 360.98564736629 * 86400000;
            const s2 = Sky.sun(new Date(t));
            const phi = lat * Sky.d2r;
            const dec = s2.dec * Sky.d2r;
            const cosH = (Math.sin(-0.833 * Sky.d2r) - Math.sin(phi) * Math.sin(dec)) / (Math.cos(phi) * Math.cos(dec));
            const half = Math.acos(Math.max(-1, Math.min(1, cosH))) / Sky.d2r / 360.98564736629 * 86400000;
            rise = t - half;
            set = t + half;
        }
        return { rise: new Date(rise), noon: new Date(t), set: new Date(set) };
    }

    readonly property var tithis: [
        ["Pratipada", "प्रतिपदा"], ["Dwitiya", "द्वितीया"], ["Tritiya", "तृतीया"], ["Chaturthi", "चतुर्थी"],
        ["Panchami", "पञ्चमी"], ["Shashthi", "षष्ठी"], ["Saptami", "सप्तमी"], ["Ashtami", "अष्टमी"],
        ["Navami", "नवमी"], ["Dashami", "दशमी"], ["Ekadashi", "एकादशी"], ["Dwadashi", "द्वादशी"],
        ["Trayodashi", "त्रयोदशी"], ["Chaturdashi", "चतुर्दशी"], ["Purnima", "पूर्णिमा"], ["Amavasya", "अमावस्या"]
    ]
    readonly property var pakshas: [["Shukla", "शुक्ल"], ["Krishna", "कृष्ण"]]
    // Each weekday is its graha's.
    readonly property var varas: [
        ["Ravivara", "रविवार", "Surya"], ["Somavara", "सोमवार", "Chandra"], ["Mangalavara", "मङ्गलवार", "Mangala"],
        ["Budhavara", "बुधवार", "Budha"], ["Guruvara", "गुरुवार", "Brihaspati"], ["Shukravara", "शुक्रवार", "Shukra"],
        ["Shanivara", "शनिवार", "Shani"]
    ]
    readonly property var nakshatras: [
        ["Ashvini", "अश्विनी"], ["Bharani", "भरणी"], ["Krittika", "कृत्तिका"], ["Rohini", "रोहिणी"],
        ["Mrigashira", "मृगशिरा"], ["Ardra", "आर्द्रा"], ["Punarvasu", "पुनर्वसु"], ["Pushya", "पुष्य"],
        ["Ashlesha", "आश्लेषा"], ["Magha", "मघा"], ["Purva Phalguni", "पूर्व फाल्गुनी"], ["Uttara Phalguni", "उत्तर फाल्गुनी"],
        ["Hasta", "हस्त"], ["Chitra", "चित्रा"], ["Swati", "स्वाति"], ["Vishakha", "विशाखा"],
        ["Anuradha", "अनुराधा"], ["Jyeshtha", "ज्येष्ठा"], ["Mula", "मूल"], ["Purva Ashadha", "पूर्वाषाढा"],
        ["Uttara Ashadha", "उत्तराषाढा"], ["Shravana", "श्रवण"], ["Dhanishtha", "धनिष्ठा"], ["Shatabhisha", "शतभिषा"],
        ["Purva Bhadrapada", "पूर्व भाद्रपद"], ["Uttara Bhadrapada", "उत्तर भाद्रपद"], ["Revati", "रेवती"]
    ]
    readonly property var yogas: [
        ["Vishkambha", "विष्कम्भ"], ["Priti", "प्रीति"], ["Ayushman", "आयुष्मान्"], ["Saubhagya", "सौभाग्य"],
        ["Shobhana", "शोभन"], ["Atiganda", "अतिगण्ड"], ["Sukarma", "सुकर्मा"], ["Dhriti", "धृति"],
        ["Shula", "शूल"], ["Ganda", "गण्ड"], ["Vriddhi", "वृद्धि"], ["Dhruva", "ध्रुव"],
        ["Vyaghata", "व्याघात"], ["Harshana", "हर्षण"], ["Vajra", "वज्र"], ["Siddhi", "सिद्धि"],
        ["Vyatipata", "व्यतीपात"], ["Variyana", "वरीयान्"], ["Parigha", "परिघ"], ["Shiva", "शिव"],
        ["Siddha", "सिद्ध"], ["Sadhya", "साध्य"], ["Shubha", "शुभ"], ["Shukla", "शुक्ल"],
        ["Brahma", "ब्रह्म"], ["Indra", "ऐन्द्र"], ["Vaidhriti", "वैधृति"]
    ]
    // Half-tithis: seven that turn over eight times a month, and four fixed
    // round the new moon.
    readonly property var karanas: [
        ["Bava", "बव"], ["Balava", "बालव"], ["Kaulava", "कौलव"], ["Taitila", "तैतिल"],
        ["Gara", "गर"], ["Vanija", "वणिज"], ["Vishti", "विष्टि"],
        ["Shakuni", "शकुनि"], ["Chatushpada", "चतुष्पाद"], ["Naga", "नाग"], ["Kimstughna", "किंस्तुघ्न"]
    ]
    readonly property var masas: [
        ["Chaitra", "चैत्र"], ["Vaishakha", "वैशाख"], ["Jyeshtha", "ज्येष्ठ"], ["Ashadha", "आषाढ"],
        ["Shravana", "श्रावण"], ["Bhadrapada", "भाद्रपद"], ["Ashvin", "आश्विन"], ["Kartika", "कार्तिक"],
        ["Margashirsha", "मार्गशीर्ष"], ["Pausha", "पौष"], ["Magha", "माघ"], ["Phalguna", "फाल्गुन"]
    ]
    readonly property var ritus: [
        ["Vasanta", "वसन्त", "spring"], ["Grishma", "ग्रीष्म", "summer"], ["Varsha", "वर्षा", "the rains"],
        ["Sharad", "शरद्", "autumn"], ["Hemanta", "हेमन्त", "the cool season"], ["Shishira", "शिशिर", "winter"]
    ]
    readonly property var rashis: [
        ["Mesha", "मेष"], ["Vrishabha", "वृषभ"], ["Mithuna", "मिथुन"], ["Karka", "कर्क"],
        ["Simha", "सिंह"], ["Kanya", "कन्या"], ["Tula", "तुला"], ["Vrishchika", "वृश्चिक"],
        ["Dhanu", "धनु"], ["Makara", "मकर"], ["Kumbha", "कुम्भ"], ["Meena", "मीन"]
    ]

    // The day's panchang at `date`. The tithi, nakshatra, yoga and karana
    // are the ones running now (they turn over at any hour); the vara, like
    // the day, begins at sunrise. Months are named the North Indian way
    // (pūrṇimānta: the dark fortnight belongs to the month that follows),
    // except a leap month (adhika), which runs new moon to new moon; the
    // Vikram year turns at the first of Chaitra's bright fortnight. The six
    // seasons are the Sun's, two signs to each.
    function panchang(date) {
        const s = Sky.sun(date);
        const m = Sky.moon(date);
        const e = Sky.rev(m.lon - s.lon);
        const t = Math.floor(e / 12);
        const paksha = t < 15 ? 0 : 1;
        const tIdx = t === 14 ? 14 : t === 29 ? 15 : t % 15;
        const ms = sidereal(m.lon, date);
        const ss = sidereal(s.lon, date);
        const nak = Math.floor(ms / (360 / 27)) % 27;
        const yoga = Math.floor(Sky.rev(ms + ss) / (360 / 27)) % 27;
        const k = Math.floor(e / 6);
        const karana = k === 0 ? 10 : k >= 57 ? 7 + (k - 57) : (k - 1) % 7;
        // The lunar month: named for the sign the Sun is in when it begins;
        // a month the Sun doesn't leave its sign in is a leap month.
        const nm0 = newMoon(date, -1);
        const nm1 = newMoon(date, 1);
        const r0 = Math.floor(sidereal(Sky.sun(nm0).lon, nm0) / 30) % 12;
        const r1 = Math.floor(sidereal(Sky.sun(nm1).lon, nm1) / 30) % 12;
        const amanta = (r0 + 1) % 12;
        const adhika = r0 === r1;
        const masa = adhika || paksha === 0 ? amanta : (amanta + 1) % 12;
        const ev = sunEvents(date);
        let day = new Date(date.getFullYear(), date.getMonth(), date.getDate());
        if (date < ev.rise)
            day = new Date(day.getTime() - 86400000);
        // The seasons follow the Sun, two signs each, spring from Meena.
        const ritu = Math.floor(((Math.floor(ss / 30) + 1) % 12) / 2);
        const month = date.getMonth();
        const vikram = date.getFullYear() + (amanta >= 9 && month <= 4 ? 56 : 57);
        return {
            tithi: t + 1, tithiIndex: tIdx, paksha: paksha, elongation: e,
            tithiName: tithis[tIdx][0], tithiDev: tithis[tIdx][1],
            pakshaName: pakshas[paksha][0], pakshaDev: pakshas[paksha][1],
            // "Shukla Ekadashi"; Purnima and Amavasya stand alone.
            tithiLine: tIdx >= 14 ? tithis[tIdx][0] : pakshas[paksha][0] + " " + tithis[tIdx][0],
            tithiLineDev: tIdx >= 14 ? tithis[tIdx][1] : pakshas[paksha][1] + " " + tithis[tIdx][1],
            nakshatra: nak, nakshatraName: nakshatras[nak][0], nakshatraDev: nakshatras[nak][1],
            yoga: yoga, yogaName: yogas[yoga][0], yogaDev: yogas[yoga][1],
            karana: karana, karanaName: karanas[karana][0], karanaDev: karanas[karana][1],
            vara: day.getDay(), varaName: varas[day.getDay()][0], varaDev: varas[day.getDay()][1], varaLord: varas[day.getDay()][2],
            masa: masa, adhika: adhika,
            masaName: (adhika ? "Adhika " : "") + masas[masa][0], masaDev: (adhika ? "अधिक " : "") + masas[masa][1],
            ritu: ritu, rituName: ritus[ritu][0], rituDev: ritus[ritu][1], rituEnglish: ritus[ritu][2],
            moonRashi: Math.floor(ms / 30) % 12, sunRashi: Math.floor(ss / 30) % 12,
            uttarayana: ss >= 270 || ss < 90,
            vikram: vikram, shaka: vikram - 135, kali: vikram + 3044,
            illum: (1 - Math.cos(e * Sky.d2r)) / 2, waxing: e < 180,
            sunrise: ev.rise, sunset: ev.set
        };
    }

    // ── The hours ───────────────────────────────────────────────────────────
    // Thirty muhurtas of 48 minutes on the mean day: fifteen from sunrise
    // to sunset, fifteen through the night. The eighth of the day is
    // Abhijit, "the victorious", at noon; the twenty-ninth is Brahma's,
    // before dawn, the hour for rising.
    readonly property var muhurtas: [
        "Rudra", "Ahi", "Mitra", "Pitri", "Vasu", "Varaha", "Vishvedeva", "Abhijit", "Satamukhi", "Puruhuta",
        "Vahini", "Naktanakara", "Varuna", "Aryaman", "Bhaga", "Girisha", "Ajapada", "Ahirbudhnya", "Pushya", "Ashvini",
        "Yama", "Agni", "Vidhatri", "Kanda", "Aditi", "Amrita", "Vishnu", "Dyumadgadyuti", "Brahma", "Samudra"
    ]

    function muhurta(date) {
        const today = sunEvents(date);
        let from, to, base;
        if (date >= today.rise && date < today.set) {
            from = today.rise;
            to = today.set;
            base = 0;
        } else if (date >= today.set) {
            from = today.set;
            to = sunEvents(new Date(date.getTime() + 86400000)).rise;
            base = 15;
        } else {
            from = sunEvents(new Date(date.getTime() - 86400000)).set;
            to = today.rise;
            base = 15;
        }
        const i = base + Math.max(0, Math.min(14, Math.floor((date - from) / (to - from) * 15)));
        return { index: i, name: muhurtas[i] };
    }

    // The eight praharas (watches) of three hours, the day's from six in
    // the morning, the night's from six in the evening, and the raga sung
    // in each.
    readonly property var ragas: ["Bhairav", "Bilawal", "Sarang", "Multani", "Yaman", "Bihag", "Darbari", "Lalit"]

    function prahar(date) {
        const h = date.getHours() + date.getMinutes() / 60;
        const i = Math.floor(((h - 6 + 24) % 24) / 3);
        return {
            index: i,
            night: i >= 4,
            line: ["first", "second", "third", "fourth"][i % 4] + " prahar of the " + (i >= 4 ? "night" : "day"),
            raga: ragas[i]
        };
    }

    // The part of the day, as a word to set after the hour instead of
    // a.m./p.m.
    function dayPart(date) {
        const h = date.getHours();
        return h >= 4 && h < 12 ? ["pratah", "प्रातः"] : h < 16 && h >= 12 ? ["aparahna", "अपराह्न"]
            : h >= 16 && h < 20 ? ["sayam", "सायं"] : ["ratri", "रात्रि"];
    }

    // ── The treasures of the churning ───────────────────────────────────────
    // Twelve come up for the passcode, one a keystroke; the poison comes up
    // for a wrong one, and Dhanvantari with the amrita for the right one.
    // [name, Devanagari, colour]
    readonly property var ratnas: [
        ["Chandra", "चन्द्र", "#eef1ff"], ["Kaustubha", "कौस्तुभ", "#e8374b"], ["Kamadhenu", "कामधेनु", "#f6dcaa"],
        ["Kalpavriksha", "कल्पवृक्ष", "#3fbf73"], ["Uchchaihshravas", "उच्चैःश्रवा", "#b9d3f5"], ["Parijata", "पारिजात", "#ff9b54"],
        ["Airavata", "ऐरावत", "#d6cff2"], ["Varuni", "वारुणी", "#9b5ce6"], ["Shankha", "शङ्ख", "#ffd9cf"],
        ["Rambha", "रम्भा", "#f07fb4"], ["Sharanga", "शार्ङ्ग", "#e0a040"], ["Lakshmi", "लक्ष्मी", "#ff6f91"]
    ]
    readonly property var ratnaLines: [
        "the Moon", "the jewel", "the wish-granting cow", "the wishing tree", "the seven-headed horse",
        "the flower of heaven", "the white elephant", "the goddess of wine", "the conch", "the apsara",
        "the bow of Vishnu", "the goddess of fortune"
    ]

    // ── The sages, by lock level (thresholds as LockStats' ranks) ──────────
    readonly property var ranks: [
        [1, "Shishya", "शिष्य"], [3, "Brahmachari", "ब्रह्मचारी"], [5, "Sadhaka", "साधक"], [8, "Yogi", "योगी"],
        [12, "Tapasvi", "तपस्वी"], [16, "Muni", "मुनि"], [20, "Rishi", "ऋषि"], [25, "Rajarshi", "राजर्षि"],
        [30, "Maharshi", "महर्षि"], [40, "Brahmarshi", "ब्रह्मर्षि"], [50, "Devarshi", "देवर्षि"]
    ]

    function rankEntry(level) {
        let e = ranks[0];
        for (let i = 0; i < ranks.length; i++)
            if (level >= ranks[i][0])
                e = ranks[i];
        return e;
    }

    function rank(level) {
        return rankEntry(level)[1];
    }

    function rankDev(level) {
        return rankEntry(level)[2];
    }
}
