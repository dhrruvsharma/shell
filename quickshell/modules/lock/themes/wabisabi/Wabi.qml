pragma Singleton
import QtQuick
import Quickshell
import qs.services as Services

// Palette, type and the old Japanese calendar for the Wabi-sabi desktop
// theme and its "Ensō" lock screen: the wallpaper's accents in muted Edo
// tones (services/DesktopTheme.qml accentOf), washi, sumi and kintsugi gold;
// kanji numerals and the Reiwa year; traditional month names; the 24 solar
// terms (sekki) and their 72 micro-seasons (kō); and kyū/dan grades for the
// shared lock level.
Singleton {
    id: root

    readonly property string serif: "Noto Serif CJK JP"

    readonly property color accent: Services.DesktopTheme.accentOf("wabisabi")
    readonly property color accent2: Services.DesktopTheme.accent2Of("wabisabi")
    readonly property color paper: "#e7dfcc"
    readonly property color paperDeep: "#cfc2a6"
    readonly property color sumi: "#2a2621"
    readonly property color sumiSoft: "#6a6152"
    readonly property color gold: "#c29a48"
    readonly property color goldHi: "#e9cd86"
    readonly property color shu: "#b04a33"

    function alpha(c, x) {
        return Qt.rgba(c.r, c.g, c.b, x);
    }

    readonly property var digits: ["〇", "一", "二", "三", "四", "五", "六", "七", "八", "九"]

    function numeral(n) {
        if (n < 10)
            return digits[n];
        if (n < 20)
            return "十" + (n % 10 ? digits[n % 10] : "");
        if (n < 100)
            return digits[Math.floor(n / 10)] + "十" + (n % 10 ? digits[n % 10] : "");
        return String(n);
    }

    // 令和八年: the Reiwa era began on 1 May 2019; its first year is 元年.
    function eraYear(d) {
        const reiwa = d >= new Date(2019, 4, 1);
        const n = d.getFullYear() - (reiwa ? 2018 : 1988);
        return (reiwa ? "令和" : "平成") + (n === 1 ? "元" : numeral(n)) + "年";
    }

    readonly property var months: [
        { ja: "睦月", en: "Mutsuki" }, { ja: "如月", en: "Kisaragi" }, { ja: "弥生", en: "Yayoi" },
        { ja: "卯月", en: "Uzuki" }, { ja: "皐月", en: "Satsuki" }, { ja: "水無月", en: "Minazuki" },
        { ja: "文月", en: "Fumizuki" }, { ja: "葉月", en: "Hazuki" }, { ja: "長月", en: "Nagatsuki" },
        { ja: "神無月", en: "Kannazuki" }, { ja: "霜月", en: "Shimotsuki" }, { ja: "師走", en: "Shiwasu" }
    ]

    readonly property var weekdays: ["日曜日", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日"]

    // 長月二十七日
    function date(d) {
        return months[d.getMonth()].ja + numeral(d.getDate()) + "日";
    }

    // 0 spring, 1 summer, 2 autumn, 3 winter.
    function season(d) {
        return Math.floor(((d.getMonth() + 10) % 12) / 3);
    }

    readonly property var sekki: [
        { ja: "立春", en: "Spring begins" }, { ja: "雨水", en: "Rain water" }, { ja: "啓蟄", en: "Insects awaken" },
        { ja: "春分", en: "Spring equinox" }, { ja: "清明", en: "Pure and clear" }, { ja: "穀雨", en: "Grain rain" },
        { ja: "立夏", en: "Summer begins" }, { ja: "小満", en: "Lesser ripening" }, { ja: "芒種", en: "Grain in ear" },
        { ja: "夏至", en: "Summer solstice" }, { ja: "小暑", en: "Lesser heat" }, { ja: "大暑", en: "Greater heat" },
        { ja: "立秋", en: "Autumn begins" }, { ja: "処暑", en: "Heat retreats" }, { ja: "白露", en: "White dew" },
        { ja: "秋分", en: "Autumn equinox" }, { ja: "寒露", en: "Cold dew" }, { ja: "霜降", en: "Frost falls" },
        { ja: "立冬", en: "Winter begins" }, { ja: "小雪", en: "Lesser snow" }, { ja: "大雪", en: "Greater snow" },
        { ja: "冬至", en: "Winter solstice" }, { ja: "小寒", en: "Lesser cold" }, { ja: "大寒", en: "Greater cold" }
    ]

    // The 72 kō, three to a sekki, from 立春 (about 4 February). Start days
    // shift by a day between years; these are the usual ones.
    readonly property var ko: [
        [2, 4, "東風解凍", "East wind melts the ice"], [2, 9, "黄鶯睍睆", "Bush warblers sing in the mountains"], [2, 14, "魚上氷", "Fish rise from the ice"],
        [2, 19, "土脉潤起", "Rain moistens the soil"], [2, 24, "霞始靆", "Mist starts to linger"], [3, 1, "草木萌動", "Grass sprouts, trees bud"],
        [3, 6, "蟄虫啓戸", "Hibernating insects surface"], [3, 11, "桃始笑", "First peach blossoms"], [3, 16, "菜虫化蝶", "Caterpillars become butterflies"],
        [3, 21, "雀始巣", "Sparrows start to nest"], [3, 26, "桜始開", "First cherry blossoms"], [3, 31, "雷乃発声", "Distant thunder"],
        [4, 5, "玄鳥至", "Swallows return"], [4, 10, "鴻雁北", "Wild geese fly north"], [4, 15, "虹始見", "First rainbows"],
        [4, 20, "葭始生", "First reeds sprout"], [4, 25, "霜止出苗", "Last frost, rice seedlings grow"], [4, 30, "牡丹華", "Peonies bloom"],
        [5, 5, "蛙始鳴", "Frogs start singing"], [5, 10, "蚯蚓出", "Worms surface"], [5, 15, "竹笋生", "Bamboo shoots sprout"],
        [5, 21, "蚕起食桑", "Silkworms feast on mulberry leaves"], [5, 26, "紅花栄", "Safflowers bloom"], [5, 31, "麦秋至", "Wheat ripens"],
        [6, 6, "蟷螂生", "Praying mantises hatch"], [6, 11, "腐草為螢", "Rotten grass becomes fireflies"], [6, 16, "梅子黄", "Plums turn yellow"],
        [6, 21, "乃東枯", "Self-heal withers"], [6, 27, "菖蒲華", "Irises bloom"], [7, 2, "半夏生", "Crow-dipper sprouts"],
        [7, 7, "温風至", "Warm winds blow"], [7, 12, "蓮始開", "First lotus blossoms"], [7, 17, "鷹乃学習", "Hawks learn to fly"],
        [7, 23, "桐始結花", "Paulownia trees bear seeds"], [7, 29, "土潤溽暑", "Earth is damp, air is humid"], [8, 3, "大雨時行", "Great rains sometimes fall"],
        [8, 8, "涼風至", "Cool winds blow"], [8, 13, "寒蝉鳴", "Evening cicadas sing"], [8, 18, "蒙霧升降", "Thick fog descends"],
        [8, 23, "綿柎開", "Cotton flowers bloom"], [8, 28, "天地始粛", "Heat starts to die down"], [9, 2, "禾乃登", "Rice ripens"],
        [9, 8, "草露白", "Dew glistens white on grass"], [9, 13, "鶺鴒鳴", "Wagtails sing"], [9, 18, "玄鳥去", "Swallows leave"],
        [9, 23, "雷乃収声", "Thunder ceases"], [9, 28, "蟄虫坏戸", "Insects hole up underground"], [10, 3, "水始涸", "Farmers drain the fields"],
        [10, 8, "鴻雁来", "Wild geese return"], [10, 13, "菊花開", "Chrysanthemums bloom"], [10, 18, "蟋蟀在戸", "Crickets chirp by the door"],
        [10, 23, "霜始降", "First frost"], [10, 28, "霎時施", "Light rains sometimes fall"], [11, 2, "楓蔦黄", "Maple leaves and ivy turn yellow"],
        [11, 7, "山茶始開", "Camellias bloom"], [11, 12, "地始凍", "The land starts to freeze"], [11, 17, "金盞香", "Daffodils bloom"],
        [11, 22, "虹蔵不見", "Rainbows hide"], [11, 27, "朔風払葉", "North wind strips the leaves"], [12, 2, "橘始黄", "Tachibana citrus turns yellow"],
        [12, 7, "閉塞成冬", "Cold sets in, winter begins"], [12, 12, "熊蟄穴", "Bears start hibernating"], [12, 16, "鱖魚群", "Salmon gather and swim upstream"],
        [12, 21, "乃東生", "Self-heal sprouts"], [12, 26, "麋角解", "Deer shed their antlers"], [12, 31, "雪下出麦", "Wheat sprouts under the snow"],
        [1, 5, "芹乃栄", "Parsley flourishes"], [1, 10, "水泉動", "Springs thaw"], [1, 15, "雉始雊", "Pheasants start to call"],
        [1, 20, "款冬華", "Butterburs bud"], [1, 25, "水沢腹堅", "Ice thickens on the streams"], [1, 30, "鶏始乳", "Hens start laying eggs"]
    ]

    // The micro-season a date falls in: { ja, en, sekki: { ja, en }, index }.
    function season72(d) {
        const at = (d.getMonth() + 1) * 32 + d.getDate();
        let best = -1;
        let bestAt = -1;
        let last = 0;
        let lastAt = -1;
        for (let i = 0; i < ko.length; i++) {
            const k = ko[i][0] * 32 + ko[i][1];
            if (k <= at && k > bestAt) {
                best = i;
                bestAt = k;
            }
            if (k > lastAt) {
                last = i;
                lastAt = k;
            }
        }
        // 1–4 January still belongs to the last kō of the year.
        const i = best >= 0 ? best : last;
        return { ja: ko[i][2], en: ko[i][3], sekki: sekki[Math.floor(i / 3)], index: i };
    }

    function ordinal(n) {
        const s = n % 100 >= 11 && n % 100 <= 13 ? "th" : ["th", "st", "nd", "rd"][n % 10] ?? "th";
        return n + s;
    }

    // The shared lock level as a grade in the arts (tea, calligraphy, go):
    // nine kyū counting down, then dan, then the titles of mastery.
    function grade(level) {
        if (level < 10)
            return { ja: numeral(10 - level) + "級", en: ordinal(10 - level) + " kyū" };
        if (level === 10)
            return { ja: "初段", en: "Shodan" };
        if (level < 20)
            return { ja: numeral(level - 9) + "段", en: ordinal(level - 9) + " dan" };
        if (level < 30)
            return { ja: "師範", en: "Shihan, master" };
        if (level < 40)
            return { ja: "名人", en: "Meijin, virtuoso" };
        return { ja: "宗匠", en: "Sōshō, grand master" };
    }
}
