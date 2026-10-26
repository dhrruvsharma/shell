pragma Singleton
import QtQuick
import Quickshell

// What's in the customizer's book: its chapters, and its spreads in order
// (each a pair of facing pages, the plate and the settings). The contents
// spread comes first; a spread's pages are numbered from its place: the
// n-th spread's left page is 2n + 2 (so the contents are ii and iii).
Singleton {
    id: root

    readonly property var chapters: [
        { n: 1, id: "opening", title: "How Things Open", icon: "ads_click" },
        { n: 2, id: "bar", title: "The Bar", icon: "toolbar" },
        { n: 3, id: "disc", title: "The Workspace Disc", icon: "donut_large" },
        { n: 4, id: "gaps", title: "Windows", icon: "select_window" },
        { n: 5, id: "theme", title: "Theme & Colour", icon: "palette" },
        { n: 6, id: "desktop", title: "The Desktop", icon: "wallpaper" },
        { n: 7, id: "notices", title: "Notices", icon: "notifications" },
        { n: 8, id: "pet", title: "The Companion", icon: "pets" }
    ]

    readonly property var spreads: [
        { id: "contents", chapter: 0, section: "Contents" },
        { id: "opening", chapter: 1, section: "Hover or click" },
        { id: "bar", chapter: 2, section: "What it shows" },
        { id: "barColour", chapter: 2, section: "Colour and finish" },
        { id: "barWidths", chapter: 2, section: "Widths" },
        { id: "disc", chapter: 3, section: "Showing and hiding" },
        { id: "discForm", chapter: 3, section: "Its form and place" },
        { id: "gaps", chapter: 4, section: "Gaps, borders and corners" },
        { id: "glass", chapter: 4, section: "Glass and shadow" },
        { id: "theme", chapter: 5, section: "The desktop theme" },
        { id: "palette", chapter: 5, section: "The palette" },
        { id: "desktop", chapter: 6, section: "Widgets and wallpaper" },
        { id: "notices", chapter: 7, section: "Notices and the night" },
        { id: "pet", chapter: 8, section: "Your pet" }
    ]

    function indexOf(id) {
        const i = root.spreads.findIndex(s => s.id === id);
        return i;
    }

    function chapter(n) {
        return root.chapters.find(c => c.n === n) ?? null;
    }

    // The first spread of a chapter.
    function chapterStart(n) {
        return root.spreads.findIndex(s => s.chapter === n);
    }

    // The left page's number of the i-th spread.
    function pageOf(i) {
        return 2 * i + 2;
    }

    // Accepts a spread's id, a chapter's id or its number ("3"), for IPC.
    function resolve(what) {
        if (what === undefined || what === null || what === "")
            return -1;
        const s = String(what);
        let i = root.indexOf(s);
        if (i >= 0)
            return i;
        const c = root.chapters.find(ch => ch.id === s || String(ch.n) === s);
        return c ? root.chapterStart(c.n) : -1;
    }
}
