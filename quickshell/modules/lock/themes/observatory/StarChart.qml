pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

// The sky over the observing site (Sky) right now, as an engraved star
// chart looking at the meridian: the stars where they stand, sized by
// magnitude, the old figures ruled between them, the brightest named, the
// Moon in its phase and the planets by their signs, and the Sun when it's
// up; under them (shaders/star_chart.frag) the night, the Milky Way, the
// equatorial grid, the ecliptic and the graduated meridian and horizon. The
// Observatory's desktop layer draws it faint over the wallpaper; the
// Astrolabe lock bright over the night.
//
// Stereographic from the horizon's south point (north, south of the
// equator) at the middle of the bottom edge, the zenith at the top edge:
// conformal, so the figures keep their shapes. Redrawn when `now` moves
// (the desktop's minute clock).
Item {
    id: chart

    property date now: new Date()
    property real boot: 1
    property real pxScale: 1
    // How strongly it's engraved, and how dark the night gets.
    property real strength: 1
    property real veil: 1
    // Named stars, figures and the points of the compass.
    property bool labels: true
    property color inkColor: Sky.parchment
    property color starColor: "#f6eed8"
    property color brassColor: Sky.brass

    readonly property real line: pxScale < 1 ? 1 / pxScale : 1
    readonly property real lstDeg: Sky.lst(now)
    readonly property real facing: Sky.site.lat >= 0 ? 180 : 0
    readonly property var sun: Sky.sun(now)
    readonly property var sunAt: Sky.altAz(sun.ra, sun.dec, lstDeg)
    // 0 by day .. 1 once the Sun is 12° down (nautical dusk).
    readonly property real night: Math.max(0, Math.min(1, (4 - sunAt.alt) / 16))
    readonly property var moon: Sky.moon(now)
    readonly property var moonAt: {
        const aa = Sky.altAz(moon.ra, moon.dec, lstDeg);
        // Parallax: the Moon sits a little lower than from the Earth's centre.
        aa.alt -= Math.asin(1 / Math.max(50, moon.dist)) / Sky.d2r * Math.cos(aa.alt * Sky.d2r);
        return aa;
    }
    readonly property var planetList: Sky.planets(now)

    // How bright the stars come out: faint by day, full at night.
    readonly property real starLight: (0.55 + 0.45 * night) * strength

    // Screen position of an altitude/azimuth (degrees): [x, y, shown].
    function project(alt, az) {
        const d2r = Sky.d2r;
        const ca = Math.cos(alt * d2r);
        const s = [ca * Math.sin(az * d2r), ca * Math.cos(az * d2r), Math.sin(alt * d2r)];
        const a0 = facing * d2r;
        const dot = s[0] * Math.sin(a0) + s[1] * Math.cos(a0);
        if (dot < -0.6)
            return [0, 0, false];
        const k = height / (1 + dot);
        const ex = s[0] * Math.sin(a0 + Math.PI / 2) + s[1] * Math.cos(a0 + Math.PI / 2);
        const x = width / 2 + k * ex;
        const y = height - k * s[2];
        return [x, y, alt > 0 && x > -40 && x < width + 40 && y > -40];
    }

    function place(ra, dec) {
        const aa = Sky.altAz(ra, dec, lstDeg);
        return project(aa.alt, aa.az);
    }

    // Every star's [x, y, shown], in the order of Sky.stars.
    readonly property var pos: {
        const out = [];
        if (width <= 0 || height <= 0)
            return out;
        for (let i = 0; i < Sky.stars.length; i++) {
            const s = Sky.stars[i];
            out.push(place(s[2] * 15, s[3]));
        }
        return out;
    }

    function starSize(mag) {
        return Math.max(1.3, 5.6 - mag * 1.15) * line;
    }

    ShaderEffect {
        anchors.fill: parent

        property real itemWidth: width
        property real itemHeight: height
        property real lst: chart.lstDeg
        property real lat: Sky.site.lat
        property real facing: chart.facing
        property real night: chart.night
        property real boot: chart.boot
        property real lineScale: Math.min(2.5, chart.line)
        property real veil: chart.veil
        property real strength: chart.strength
        property color inkColor: chart.inkColor
        property color brassColor: chart.brassColor
        property color skyColor: Sky.night
        property color milkColor: "#dfe6ff"

        fragmentShader: Qt.resolvedUrl("../../../../shaders/star_chart.frag.qsb")
    }

    // The figures: lines stopping short of the stars, as a chart's do.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: chart.boot * chart.strength

        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.rgba(chart.inkColor.r, chart.inkColor.g, chart.inkColor.b, 0.26 + 0.12 * chart.night)
            strokeWidth: chart.line
            capStyle: ShapePath.RoundCap

            PathMultiline {
                paths: {
                    const out = [];
                    const pos = chart.pos;
                    if (pos.length === 0)
                        return out;
                    for (let f = 0; f < Sky.figures.length; f++) {
                        const lines = Sky.figures[f].lines;
                        for (let j = 0; j < lines.length; j++) {
                            const ia = Sky.starIndex[lines[j][0]];
                            const ib = Sky.starIndex[lines[j][1]];
                            const a = pos[ia], b = pos[ib];
                            if (!a || !b || !(a[2] || b[2]))
                                continue;
                            const dx = b[0] - a[0], dy = b[1] - a[1];
                            const len = Math.sqrt(dx * dx + dy * dy);
                            if (len < 1 || len > chart.height * 0.6)
                                continue;
                            const ga = (chart.starSize(Sky.stars[ia][4]) / 2 + 4 * chart.line) / len;
                            const gb = (chart.starSize(Sky.stars[ib][4]) / 2 + 4 * chart.line) / len;
                            if (ga + gb >= 1)
                                continue;
                            out.push([Qt.point(a[0] + dx * ga, a[1] + dy * ga), Qt.point(b[0] - dx * gb, b[1] - dy * gb)]);
                        }
                    }
                    return out;
                }
            }
        }
    }

    // The stars.
    Repeater {
        model: Sky.stars.length

        Item {
            id: star
            required property int index
            readonly property var at: chart.pos[index] ?? [0, 0, false]
            readonly property real mag: Sky.stars[index][4]
            readonly property real size: chart.starSize(mag)
            visible: at[2]
            x: at[0] - width / 2
            y: at[1] - height / 2
            width: size * 3
            height: size * 3
            opacity: chart.boot * chart.starLight

            // A soft glow round the brightest.
            Rectangle {
                anchors.centerIn: parent
                visible: star.mag < 1.6
                width: star.size * 2.6
                height: width
                radius: width / 2
                color: Qt.rgba(chart.starColor.r, chart.starColor.g, chart.starColor.b, 0.12 + 0.06 * chart.night)
            }

            Rectangle {
                anchors.centerIn: parent
                width: star.size
                height: width
                radius: width / 2
                color: chart.starColor
            }

            // First-magnitude stars get a ring, as on the old charts.
            Rectangle {
                anchors.centerIn: parent
                visible: star.mag < 1
                width: star.size + 5 * chart.line
                height: width
                radius: width / 2
                color: "transparent"
                border.width: chart.line
                border.color: Qt.rgba(chart.brassColor.r, chart.brassColor.g, chart.brassColor.b, 0.7)
            }
        }
    }

    component Label: Text {
        font.family: Sky.display
        font.italic: true
        font.pixelSize: 14
        color: Qt.rgba(chart.inkColor.r, chart.inkColor.g, chart.inkColor.b, 0.72)
        style: Text.Raised
        styleColor: Qt.rgba(0, 0, 0, 0.35)
    }

    // Names of the bright stars.
    readonly property var namedStars: Sky.stars.map((s, i) => s[1] ? i : -1).filter(i => i >= 0)

    Repeater {
        model: chart.labels ? chart.namedStars : []

        Label {
            required property int modelData
            readonly property var at: chart.pos[modelData] ?? [0, 0, false]
            visible: at[2] && at[1] > 30
            x: at[0] + chart.starSize(Sky.stars[modelData][4]) / 2 + 6
            y: at[1] - height / 2 + 1
            text: Sky.stars[modelData][1]
            opacity: chart.boot * chart.starLight
        }
    }

    // The figures' names, spaced out under their stars.
    Repeater {
        model: chart.labels ? Sky.figures.length : 0

        Text {
            id: figureName
            required property int index
            readonly property var at: {
                const pos = chart.pos;
                const lines = Sky.figures[index].lines;
                const seen = {};
                let x = 0, y = 0, n = 0, maxY = 0;
                for (let j = 0; j < lines.length; j++) {
                    for (let e = 0; e < 2; e++) {
                        const i = Sky.starIndex[lines[j][e]];
                        const p = pos[i];
                        if (seen[i] || !p || !p[2])
                            continue;
                        seen[i] = true;
                        x += p[0];
                        y += p[1];
                        maxY = Math.max(maxY, p[1]);
                        n += 1;
                    }
                }
                return n >= 2 ? [x / n, maxY, true] : [0, 0, false];
            }
            visible: at[2] && at[1] < chart.height - 60
            x: at[0] - width / 2
            y: at[1] + 16
            text: Sky.figures[index].name.toUpperCase()
            font.family: Sky.caps
            font.pixelSize: 13
            font.letterSpacing: 4
            color: Qt.rgba(chart.brassColor.r, chart.brassColor.g, chart.brassColor.b, 0.55)
            opacity: chart.boot * chart.strength
        }
    }

    // The planets by their signs, the wanderers among the fixed stars.
    Repeater {
        model: 5

        Item {
            id: planet
            required property int index
            readonly property var p: chart.planetList[index]
            readonly property var at: p ? chart.place(p.ra, p.dec) : [0, 0, false]
            visible: at[2]
            x: at[0]
            y: at[1]
            opacity: chart.boot * (0.7 + 0.3 * chart.night) * chart.strength

            Rectangle {
                x: -width / 2
                y: -height / 2
                width: 4 * chart.line
                height: width
                radius: width / 2
                color: chart.starColor
            }

            Text {
                x: 5 * chart.line
                y: -height + 2
                text: planet.p ? planet.p.glyph : ""
                font.family: Sky.symbols
                font.pixelSize: 17
                color: chart.brassColor
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.4)
            }

            Label {
                visible: chart.labels
                x: 7 * chart.line
                y: 1
                text: planet.p ? planet.p.name : ""
                font.pixelSize: 12
            }
        }
    }

    // The Moon, in its phase.
    Item {
        readonly property var at: chart.project(chart.moonAt.alt, chart.moonAt.az)
        visible: at[2]
        x: at[0] - width / 2
        y: at[1] - height / 2
        width: 44 * chart.line
        height: width
        opacity: chart.boot * chart.strength

        Orb {
            anchors.fill: parent
            illum: chart.moon.illum
            waxing: chart.moon.waxing
            glow: 0.5 + 0.5 * chart.night
        }
    }

    // The Sun, when it's up.
    Item {
        readonly property var at: chart.project(chart.sunAt.alt, chart.sunAt.az)
        visible: at[2]
        x: at[0] - width / 2
        y: at[1] - height / 2
        width: 50 * chart.line
        height: width
        opacity: chart.boot * chart.strength

        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: width
            radius: width / 2
            color: Qt.rgba(1, 0.86, 0.55, 0.12)
        }

        Text {
            anchors.centerIn: parent
            text: Sky.glyph("☉")
            font.family: Sky.symbols
            font.pixelSize: 26
            color: Sky.lamp
        }
    }

    // The points of the compass on the horizon, and altitudes up the
    // meridian.
    Repeater {
        model: chart.labels ? [["E", 90], ["SE", 135], ["S", 180], ["SW", 225], ["W", 270], ["NW", 315], ["N", 0], ["NE", 45]] : []

        Text {
            required property var modelData
            readonly property var at: chart.project(0, modelData[1])
            visible: at[0] > 20 && at[0] < chart.width - 20
            x: at[0] - width / 2
            y: chart.height - 22 * chart.line - height
            text: modelData[0]
            font.family: Sky.caps
            font.pixelSize: 15
            font.letterSpacing: 2
            color: Qt.rgba(chart.brassColor.r, chart.brassColor.g, chart.brassColor.b, 0.8)
            opacity: chart.boot * chart.strength
        }
    }

    Repeater {
        model: chart.labels ? [30, 60] : []

        Text {
            required property int modelData
            readonly property var at: chart.project(modelData, chart.facing)
            x: chart.width / 2 + 18 * chart.line
            y: at[1] - height / 2
            text: modelData + "°"
            font.family: Sky.caps
            font.pixelSize: 12
            color: Qt.rgba(chart.brassColor.r, chart.brassColor.g, chart.brassColor.b, 0.6)
            opacity: chart.boot * chart.strength
        }
    }
}
