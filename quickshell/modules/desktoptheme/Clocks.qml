pragma Singleton
import QtQuick
import Quickshell

// Calendar helpers for the desktop theme clocks.
Singleton {
    function dayOfYear(d) {
        return Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - new Date(d.getFullYear(), 0, 1)) / 86400000) + 1;
    }

    // ISO 8601 week number.
    function isoWeek(d) {
        const t = new Date(d.getFullYear(), d.getMonth(), d.getDate());
        t.setDate(t.getDate() + 3 - (t.getDay() + 6) % 7);
        const week1 = new Date(t.getFullYear(), 0, 4);
        return 1 + Math.round(((t - week1) / 86400000 - 3 + (week1.getDay() + 6) % 7) / 7);
    }

    // How far through the year, 0..1.
    function yearFraction(d) {
        const start = new Date(d.getFullYear(), 0, 1);
        const end = new Date(d.getFullYear() + 1, 0, 1);
        return (d - start) / (end - start);
    }

    // 2026 -> "MMXXVI".
    function roman(n) {
        const table = [[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"], [90, "XC"], [50, "L"], [40, "XL"], [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]];
        let out = "";
        let v = Math.max(0, Math.floor(n));
        for (let i = 0; i < table.length; i++) {
            while (v >= table[i][0]) {
                out += table[i][1];
                v -= table[i][0];
            }
        }
        return out;
    }

    // 1 -> "1st", 22 -> "22nd".
    function ordinal(n) {
        const t = n % 100;
        return n + (t >= 11 && t <= 13 ? "th" : ["th", "st", "nd", "rd"][n % 10] ?? "th");
    }
}
