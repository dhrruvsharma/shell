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
}
