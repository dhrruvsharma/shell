pragma Singleton
import QtQuick
import Quickshell
import qs.colors

// Heraldry for the Siege desktop theme: the tinctures (heraldry's colours)
// that the wallpaper's colour is named as, and your coat of arms, drawn
// from your name (FNV-1a) so it never changes: an ordinary argent on a
// field of your tincture between charges Or, with a motto. The field
// follows the wallpaper and the blazon names whichever tincture it is.
// Painted by shaders/heraldry.frag (modules/lock/themes/siege/Arms.qml).
Singleton {
    id: root

    // Heraldry's colours by hue, with the saturation a herald's paint has.
    // (Or and argent are its metals, sable its black; none of those is ever
    // the wallpaper's colour here.)
    readonly property var tinctures: [
        { name: "Gules", hue: 0.995, sat: 0.7 },
        { name: "Tenné", hue: 0.07, sat: 0.62 },
        { name: "Vert", hue: 0.37, sat: 0.5 },
        { name: "Azure", hue: 0.6, sat: 0.62 },
        { name: "Purpure", hue: 0.79, sat: 0.42 },
        { name: "Murrey", hue: 0.9, sat: 0.46 }
    ]

    function _gap(a, b) {
        const d = Math.abs(a - b);
        return Math.min(d, 1 - d);
    }

    // The tincture `c` would be blazoned as (`name`, `sat`), and its hue
    // drawn most of the way there (`h`); gules for a grey.
    function tinctureOf(c) {
        const q = Qt.color(c);
        if (q.hslHue < 0 || q.hslSaturation < 0.06)
            return { name: tinctures[0].name, sat: tinctures[0].sat, h: tinctures[0].hue };
        const hue = q.hslHue;
        let best = tinctures[0];
        for (let i = 1; i < tinctures.length; i++)
            if (_gap(hue, tinctures[i].hue) < _gap(hue, best.hue))
                best = tinctures[i];
        let d = best.hue - hue;
        if (d > 0.5)
            d -= 1;
        if (d < -0.5)
            d += 1;
        return { name: best.name, sat: best.sat, h: (hue + d * 0.7 + 1) % 1 };
    }

    // The wallpaper's.
    readonly property var tincture: tinctureOf(Colors.primary)

    function hash(s) {
        let h = 2166136261;
        for (let i = 0; i < s.length; i++) {
            h ^= s.charCodeAt(i);
            h = Math.imul(h, 16777619) >>> 0;
        }
        return h >>> 0;
    }

    readonly property string userName: Quickshell.env("USER") || "knight"
    readonly property double seed: hash(userName)

    // [id in shaders/heraldry.frag, name, how many charges go with it]
    readonly property var ordinaries: [
        [1, "chevron", 3], [2, "bend", 2], [3, "fess", 3], [4, "pale", 2],
        [5, "cross", 4], [6, "saltire", 4], [7, "chief", 3]
    ]
    // [id, singular, plural]
    readonly property var charges: [
        [1, "mullet", "mullets"], [2, "roundel", "roundels"], [3, "crescent", "crescents"],
        [4, "annulet", "annulets"], [5, "lozenge", "lozenges"]
    ]
    // Roundels are named for their tincture and need no other word.
    readonly property var roundelNames: ({ Or: "bezants", argent: "plates", Gules: "torteaux", Azure: "hurts", Vert: "pommes", Purpure: "golps", "Tenné": "oranges", Murrey: "roundels murrey" })
    readonly property var numbers: ["", "one", "two", "three", "four"]

    readonly property var mottos: [
        ["Vincit qui patitur", "he conquers who endures"],
        ["Audentes fortuna iuvat", "fortune favours the bold"],
        ["Si vis pacem, para bellum", "if you want peace, prepare for war"],
        ["Nec aspera terrent", "hardships do not daunt us"],
        ["Fortis et fidelis", "brave and faithful"],
        ["Virtute et armis", "by courage and by arms"],
        ["Semper paratus", "always ready"],
        ["Per ardua ad alta", "through hardship to the heights"],
        ["Fide et fortitudine", "by faith and by fortitude"],
        ["Dum spiro spero", "while I breathe, I hope"]
    ]

    readonly property var arms: {
        const o = ordinaries[seed % ordinaries.length];
        const c = charges[Math.floor(seed / ordinaries.length) % charges.length];
        const m = mottos[Math.floor(seed / (ordinaries.length * charges.length)) % mottos.length];
        const field = tincture.name;
        let blazon;
        if (o[1] === "chief") {
            // On the chief the charges take the field's tincture.
            const what = c[0] === 2 ? (roundelNames[field] ?? "roundels") : c[2] + " of the field";
            blazon = field + ", on a chief argent three " + what;
        } else {
            const what = c[0] === 2 ? roundelNames.Or : c[2] + " Or";
            blazon = field + ", a " + o[1] + " argent between " + numbers[o[2]] + " " + what;
        }
        return { ordinary: o[0], ordinaryName: o[1], charge: c[0], blazon: blazon, motto: m[0], mottoGloss: m[1] };
    }
}
