pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.colors
import qs.modules.desktoptheme
import qs.modules.desktopwidgets
import qs.modules.lock.themes.abyss
import qs.modules.lock.themes.artdeco
import qs.modules.lock.themes.cyberpunk
import qs.modules.lock.themes.devaloka
import qs.modules.lock.themes.gothic
import qs.modules.lock.themes.newspaper
import qs.modules.lock.themes.observatory
import qs.modules.lock.themes.sekiro
import qs.modules.lock.themes.siege
import qs.modules.lock.themes.wabisabi
import qs.modules.lock.themes.wasteland
import qs.modules.lock.themes.xianxia

// The head of the control centre: the time in the theme's display face,
// the day the way the theme keeps it (the watch of the siege, where the
// shinobi is in Ashina, the canonical
// hour, the tithi, the depth of the boat, the edition on the street…) and
// your picture in the theme's frame (a click picks another). Redrawn once a
// minute.
Item {
    id: root

    signal avatarClicked

    implicitHeight: Math.max(face.implicitHeight, art.y + art.height + ControlStyle.artBleed)

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    FileView {
        id: hostFile
        path: "/etc/hostname"
        printErrors: false
    }

    readonly property date now: clock.date
    readonly property string user: Quickshell.env("USER") || "user"
    readonly property string host: (hostFile.text() || "").trim().split(".")[0] || "localhost"

    // { kicker, time, suffix, face: { time, suffix }, lines: [[segment]] },
    // a segment being { text, font, size, weight, spacing, italic, tone,
    // tape }; tone is "ink", "soft", "faint", "accent" or "accent2".
    readonly property var spec: specFor(ControlStyle.themeId, now)

    function seg(text, font, size, extra) {
        return Object.assign({ text: text, font: font, size: size, weight: Font.Normal, spacing: 0, italic: false, tone: "ink", tape: false }, extra ?? {});
    }

    function specFor(id, d) {
        const hm = Qt.formatDateTime(d, "h:mm AP").split(" ");
        const ap = hm[1] ?? "";
        const dots = ap.toLowerCase().split("").join(".") + ".";
        const day = Clocks.dayOfYear(d);
        switch (id) {
        case "hud":
            return {
                kicker: seg("STAGE TIME", ControlStyle.mono, 11, { spacing: 3, tone: "accent", weight: Font.Bold }),
                time: seg(Qt.formatDateTime(d, "hh:mm"), "Orbitron", 54, { weight: Font.Bold }),
                suffix: seg(ap, "Orbitron", 17, { weight: Font.Bold, tone: "accent" }),
                lines: [[seg(Qt.formatDateTime(d, "ddd · d MMM").toUpperCase() + "  ·  DAY " + day, ControlStyle.mono, 13, { spacing: 2, tone: "soft" })]]
            };
        case "terminal":
            return {
                kicker: seg(user + "@" + host + ":~$ date", ControlStyle.mono, 13, { tone: "accent" }),
                time: seg(Qt.formatDateTime(d, "hh:mm"), ControlStyle.mono, 60, { weight: Font.Medium }),
                suffix: seg(ap, ControlStyle.mono, 20, { tone: "accent" }),
                lines: [[seg(Qt.formatDateTime(d, "ddd yyyy-MM-dd").toLowerCase() + "  ·  week " + Clocks.isoWeek(d) + "  ·  day " + day, ControlStyle.mono, 13, { tone: "soft" })]]
            };
        case "cosmos":
            return {
                time: seg(Qt.formatDateTime(d, "hh:mm"), "ESPACION", 50),
                suffix: seg(Qt.formatDateTime(d, "AP · ddd d MMM").toUpperCase(), "Adwaita Sans", 12, { spacing: 2.5, tone: "accent" }),
                lines: [[seg("YEAR " + d.getFullYear() + "  ·  " + Math.round(Clocks.yearFraction(d) * 100) + "% AROUND THE SUN", "Adwaita Sans", 11, { spacing: 2.5, tone: "soft" })]]
            };
        case "zen":
            return {
                time: seg(hm[0], "Adwaita Sans", 66, { weight: Font.ExtraLight }),
                suffix: seg(ap.toLowerCase(), "Adwaita Sans", 20, { weight: Font.Light, tone: "soft" }),
                lines: [[seg(Qt.formatDate(d, "dddd, d MMMM").toLowerCase(), "Adwaita Sans", 15, { weight: Font.Light, tone: "soft", spacing: 0.6 })]]
            };
        case "xianxia": {
            const hour = Xian.shichen(d);
            return {
                kicker: seg(hour.zh + "  ·  " + hour.en, Xian.cjk, 13, { tone: "accent", spacing: 1 }),
                time: seg(hm[0], Xian.serif, 56),
                suffix: seg(ap.toLowerCase(), Xian.serif, 18, { tone: "soft" }),
                lines: [[seg(Xian.chineseDate(d), Xian.cjk, 15, { tone: "accent" }), seg(Qt.formatDate(d, "dddd, d MMMM"), Xian.serif, 14, { tone: "soft" })]]
            };
        }
        case "cyberpunk":
            return {
                time: seg(Qt.formatDateTime(d, "hh:mm"), Neon.display, 58, { tone: "accent", ghost: true }),
                suffix: seg(ap, Neon.ui, 20, { spacing: 2, tone: "accent2" }),
                lines: [
                    [seg(Neon.weekdays[d.getDay()], Neon.kana, 15, { weight: Font.Black, tone: "accent2" }), seg(Qt.formatDate(d, "ddd d MMM yyyy").toUpperCase(), Neon.ui, 16, { spacing: 2 })],
                    [seg(Neon.shift(d) + "  //  WK " + Clocks.isoWeek(d) + "  ·  DAY " + day, Neon.ui, 12, { spacing: 3, tone: "soft" })]
                ]
            };
        case "wabisabi": {
            const kou = Wabi.season72(d);
            return {
                time: seg(hm[0], Wabi.serif, 58, { weight: Font.Light }),
                suffix: seg((d.getHours() < 12 ? "午前" : "午後") + "  ·  " + Wabi.weekdays[d.getDay()], Wabi.serif, 14, { tone: "soft" }),
                lines: [
                    [seg(Wabi.eraYear(d) + Wabi.date(d), Wabi.serif, 15, { tone: "accent" })],
                    [seg(kou.sekki.ja + "  ·  " + kou.sekki.en.toLowerCase() + "  ·  " + Wabi.months[d.getMonth()].en.toLowerCase(), Wabi.serif, 12, { tone: "soft", spacing: 0.8 })]
                ]
            };
        }
        case "artdeco":
            return {
                time: seg(hm[0], Deco.display, 64),
                suffix: seg(ap, Deco.ui, 16, { spacing: 2, tone: "accent", weight: Font.DemiBold }),
                lines: [
                    [seg(Deco.date(d), Deco.ui, 12, { spacing: 2.5, tone: "accent" })],
                    [seg(Deco.hour(d), Deco.marquee, 14, { spacing: 3, tone: "soft" })]
                ]
            };
        case "gothic": {
            const hour = Gothic.canonicalHour(d);
            return {
                time: seg(hm[0], Gothic.blackletter, 60),
                suffix: seg(ap, Gothic.caps, 16, { tone: "accent" }),
                lines: [
                    [seg(hour.en + "  ·  " + hour.gloss, Gothic.book, 16, { italic: true, tone: "accent" })],
                    [seg(Gothic.date(d), Gothic.book, 14, { tone: "soft" })],
                    [seg((Gothic.year(d) + "  ·  " + Gothic.season(d).la).toUpperCase(), Gothic.caps, 10, { spacing: 2, tone: "faint" })]
                ]
            };
        }
        case "newspaper":
            return {
                kicker: seg(Press.volume(d) + "  ·  " + Press.number(d) + "  ·  " + Press.edition(d), Press.body, 10, { spacing: 1.2, weight: Font.Bold }),
                time: seg(hm[0], Press.masthead, 60, { weight: Font.Black }),
                suffix: seg(dots, Press.masthead, 22, { weight: Font.Bold }),
                lines: [[seg(Press.dateline(d), Press.body, 11, { spacing: 1, weight: Font.Bold, tone: "soft" })]]
            };
        case "wasteland":
            return {
                time: seg(hm[0], Waste.stencil, 64, { weight: Font.Bold }),
                suffix: seg(ap, Waste.cond, 22, { weight: Font.Bold, tone: "accent2" }),
                lines: [
                    [seg("DAY " + day + "  ·  " + Qt.formatDate(d, "ddd d MMM yyyy").toUpperCase(), Waste.cond, 17, { weight: Font.Bold, spacing: 1.5, tone: "accent2" })],
                    [seg(Waste.watch(d).toLowerCase(), Waste.type, 13, { tape: true })]
                ]
            };
        case "observatory": {
            const sun = Sky.sun(d);
            return {
                time: seg(hm[0], Sky.display, 60),
                suffix: seg(dots, Sky.caps, 18, { tone: "accent" }),
                lines: [
                    [seg("Sidereal " + Sky.hm(Sky.lst(d)) + "  ·  the Sun in " + Sky.signOf(sun.lon)[0], Sky.display, 16, { italic: true, tone: "accent" })],
                    [seg(Qt.formatDate(d, "dddd") + ", the " + Clocks.ordinal(d.getDate()) + " of " + Qt.formatDate(d, "MMMM"), Sky.book, 14, { tone: "soft" })],
                    [seg((Sky.phaseName(Sky.moon(d)) + "  ·  Anno " + Clocks.roman(d.getFullYear())).toUpperCase(), Sky.caps, 10, { spacing: 2, tone: "faint" })]
                ]
            };
        }
        case "abyss": {
            const m = Deep.depthAt(d);
            const zone = Deep.zoneAt(m);
            return {
                time: seg(Qt.formatTime(d, "HH:mm"), Deep.display, 50),
                suffix: seg("", Deep.ui, 12),
                lines: [
                    [seg("−" + Deep.metres(m) + "  ·  " + zone.name.toUpperCase(), Deep.ui, 13, { weight: Font.Bold, spacing: 2, tone: "accent2" })],
                    [seg(Deep.temperature(m).toFixed(1) + " °C  ·  " + Math.round(Deep.pressure(m)) + " ATM  ·  " + zone.latin.toUpperCase(), Deep.mono, 11, { tone: "soft" })],
                    [seg(Qt.formatDate(d, "ddd d MMM yyyy").toUpperCase(), Deep.ui, 11, { spacing: 2, tone: "faint" })]
                ]
            };
        }
        case "devaloka": {
            const pan = Deva.panchang(d);
            return {
                time: seg(Deva.numerals(hm[0]), Deva.display, 58),
                suffix: seg(Deva.dayPart(d)[1], Deva.display, 20, { tone: "accent" }),
                lines: [
                    [seg(pan.masaName + " " + pan.tithiLine + "  ·  " + pan.nakshatraName, Deva.book, 15, { italic: true, tone: "accent" })],
                    [seg(pan.varaName + ", the " + Deva.ordinal(d.getDate()) + " of " + Qt.formatDate(d, "MMMM"), Deva.book, 14, { tone: "soft" })]
                ]
            };
        }
        case "siege": {
            const watch = War.watch(d);
            return {
                time: seg(hm[0], War.display, 62),
                suffix: seg(dots, War.display, 20, { tone: "accent" }),
                lines: [
                    [seg(watch.name + "  ·  " + watch.deed, War.book, 15, { italic: true, tone: "accent" })],
                    [seg(War.date(d), War.book, 14, { tone: "soft" })],
                    [seg(("Day " + War.siegeDay(d) + " of the siege  ·  " + War.year(d)).toUpperCase(), War.display, 11, { spacing: 2, tone: "faint" })]
                ]
            };
        }
        case "sekiro": {
            const st = Shinobi.stretch(d);
            return {
                time: seg(hm[0], Shinobi.display, 62),
                suffix: seg(dots, Shinobi.book, 20, { tone: "accent2" }),
                lines: [
                    [seg(Shinobi.place(st), Shinobi.book, 15, { weight: Font.Bold, tone: "accent2" })],
                    [seg(st.deed, Shinobi.book, 14, { tone: "soft" })],
                    [seg((Shinobi.date(d) + "  ·  " + Shinobi.season(d).name).toUpperCase(), Shinobi.book, 10, { spacing: 2, tone: "faint" })]
                ]
            };
        }
        default:
            return {
                time: seg(hm[0], ControlStyle.body, 64, { weight: Font.Light }),
                suffix: seg(ap, ControlStyle.body, 20, { tone: "soft" }),
                lines: [[seg(Qt.formatDate(d, "dddd, d MMMM"), ControlStyle.body, 15, { tone: "soft" })]]
            };
        }
    }

    function tone(t) {
        switch (t) {
        case "soft":
            return Colors.withAlpha(ControlStyle.ink, 0.72);
        case "faint":
            return Colors.withAlpha(ControlStyle.ink, 0.5);
        case "accent":
            return ControlStyle.accent;
        case "accent2":
            return ControlStyle.accent2;
        default:
            return ControlStyle.ink;
        }
    }

    component Segment: Text {
        required property var modelData
        text: modelData.text
        font.family: modelData.font
        font.pixelSize: modelData.size
        font.weight: modelData.weight
        font.letterSpacing: modelData.spacing
        font.italic: modelData.italic
        color: root.tone(modelData.tone)
    }

    Column {
        id: face
        width: parent.width - art.width - 16
        spacing: 4

        Segment {
            visible: !!root.spec.kicker
            modelData: root.spec.kicker ?? root.seg("", ControlStyle.body, 1)
            width: parent.width
            elide: Text.ElideRight
        }

        Item {
            width: parent.width
            height: time.implicitHeight

            // Neon Noir's numerals split like a bad signal.
            Segment {
                visible: !!root.spec.time.ghost
                x: 2.5
                modelData: root.spec.time
                color: Colors.withAlpha(ControlStyle.accent2, 0.6)
            }

            Segment {
                id: time
                modelData: root.spec.time
            }

            Segment {
                anchors.left: time.right
                anchors.leftMargin: 10
                anchors.baseline: time.baseline
                width: parent.width - time.implicitWidth - 10
                elide: Text.ElideRight
                modelData: root.spec.suffix
            }
        }

        Repeater {
            model: root.spec.lines

            Row {
                id: line
                required property var modelData
                spacing: 10

                Repeater {
                    model: line.modelData

                    Item {
                        id: piece
                        required property var modelData
                        width: words.implicitWidth + (modelData.tape ? 18 : 0)
                        height: words.implicitHeight + (modelData.tape ? 8 : 0)

                        // Wasteland: the watch on a strip of masking tape.
                        Rectangle {
                            visible: piece.modelData.tape
                            anchors.fill: parent
                            anchors.topMargin: 2
                            anchors.bottomMargin: 2
                            rotation: -1.5
                            color: Waste.tape
                            opacity: 0.95
                        }

                        Segment {
                            id: words
                            anchors.centerIn: parent
                            rotation: piece.modelData.tape ? -1.5 : 0
                            modelData: piece.modelData
                            color: piece.modelData.tape ? Waste.tapeInk : root.tone(piece.modelData.tone)
                        }
                    }
                }
            }
        }
    }

    WidgetArt {
        id: art
        anchors.right: parent.right
        // (clear of Cave Abode's seal, in the scroll's corner)
        anchors.rightMargin: ControlStyle.frame === "scroll" ? 18 : ControlStyle.artBleed
        anchors.top: parent.top
        anchors.topMargin: ControlStyle.frame === "scroll" ? 12 : 2 + ControlStyle.artBleed
        width: 76
        height: 76
        themeId: ControlStyle.themeId
        source: "file://" + Quickshell.env("HOME") + "/.cache/current_avatar"

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.avatarClicked()
        }
    }
}
