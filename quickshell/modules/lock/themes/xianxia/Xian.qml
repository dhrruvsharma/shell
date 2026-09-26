pragma Singleton
import QtQuick
import Quickshell

// Palette, type and lore for the "Sealed Cave Abode" theme: cultivation realms
// mapped from the shared lock level, Chinese numerals and dates, and the
// traditional double-hour (shichen) with its zodiac animal.
Singleton {
    id: root

    readonly property string cjk: "Noto Serif CJK SC"
    readonly property string serif: "Noto Serif"

    readonly property color ink: "#0b0c11"
    readonly property color night: "#141826"
    readonly property color mist: "#aeb8c4"
    readonly property color paper: "#eadfc6"
    readonly property color paperDim: "#a79f8d"
    readonly property color gold: "#d9b35d"
    readonly property color goldHi: "#f5dc95"
    readonly property color jade: "#79c2ad"
    readonly property color cinnabar: "#cf3b2e"
    readonly property color ember: "#ff9d4d"

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    readonly property var digits: ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]

    function numeral(n) {
        if (n < 10)
            return digits[n];
        if (n < 20)
            return "十" + (n % 10 ? digits[n % 10] : "");
        return digits[Math.floor(n / 10)] + "十" + (n % 10 ? digits[n % 10] : "");
    }

    function chineseDate(d) {
        return numeral(d.getMonth() + 1) + "月" + numeral(d.getDate()) + "日";
    }

    readonly property string branches: "子丑寅卯辰巳午未申酉戌亥"
    readonly property var animals: ["Rat", "Ox", "Tiger", "Rabbit", "Dragon", "Snake", "Horse", "Goat", "Monkey", "Rooster", "Dog", "Pig"]

    // Double-hours start at 23:00 with 子 (Rat).
    function shichen(d) {
        const i = Math.floor(((d.getHours() + 1) % 24) / 2);
        return { zh: branches.charAt(i) + "时", en: "Hour of the " + animals[i] };
    }

    readonly property var realms: [
        { from: 1, to: 9, zh: "练气", en: "Qi Refining", layered: true },
        { from: 10, to: 12, zh: "筑基", en: "Foundation Establishment" },
        { from: 13, to: 15, zh: "金丹", en: "Golden Core" },
        { from: 16, to: 18, zh: "元婴", en: "Nascent Soul" },
        { from: 19, to: 21, zh: "化神", en: "Spirit Transformation" },
        { from: 22, to: 24, zh: "炼虚", en: "Void Refinement" },
        { from: 25, to: 27, zh: "合体", en: "Body Integration" },
        { from: 28, to: 30, zh: "大乘", en: "Great Vehicle" },
        { from: 31, to: 39, zh: "渡劫", en: "Tribulation", layered: true },
        { from: 40, to: 100000, zh: "真仙", en: "True Immortal", open: true }
    ]

    // { zh, en, stageZh, stageEn } for a lock level.
    function realm(level) {
        const r = realms.find(x => level >= x.from && level <= x.to) ?? realms[realms.length - 1];
        const i = Math.max(0, level - r.from);
        if (r.layered)
            return { zh: r.zh, en: r.en, stageZh: "第" + numeral(i + 1) + "层", stageEn: "Layer " + (i + 1) };
        if (r.open)
            return { zh: r.zh, en: r.en, stageZh: "", stageEn: "" };
        const stages = [["初期", "Early"], ["中期", "Middle"], ["后期", "Late"]];
        return { zh: r.zh, en: r.en, stageZh: stages[i][0], stageEn: stages[i][1] };
    }
}
