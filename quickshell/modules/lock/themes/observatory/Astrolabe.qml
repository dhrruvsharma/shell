pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.desktoptheme

// An astrolabe (shaders/astrolabe.frag), the Observatory's mark: a plate
// engraved for the observing site's latitude, the rete turned to the
// sidereal time with its twelve star pointers and the ring of the zodiac,
// and the rule across it; here the engraved hours on the limb, the signs of
// the zodiac turning with the rete, and (big enough) the stars' names. The
// clock sets the rete to the sky and the rule to the hour; the Astrolabe
// lock turns the rete keystroke by keystroke and lights the stars.
Item {
    id: astro

    // Degrees: the sidereal time the rete is turned to, and the rule
    // clockwise from the top (noon; the limb's hours run clockwise).
    property real rete: 0
    property real rule: 0
    property real latitude: Sky.site.lat
    // Light on each of the rete's stars (Sky.reteStars), 0..1, and how many
    // of the signs are lit.
    property var lit: []
    property real litSigns: 0
    property real glow: 1
    property real bloom: 0
    property real cloud: 0
    property real drift: 0
    property bool starNames: false

    readonly property real radius: Math.min(width, height) / 2
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property real mirror: latitude < 0 ? -1 : 1
    readonly property real eps: 23.4393 * Math.PI / 180
    readonly property real rCap: 0.8
    readonly property real rEq: rCap / Math.tan((Math.PI / 2 + eps) / 2)
    readonly property real rCan: rEq * Math.tan((Math.PI / 2 - eps) / 2)
    // Small instruments show every third hour and leave the signs to the
    // ring's divisions.
    readonly property bool small: radius < 150

    function litAt(i) {
        return lit[i] ?? 0;
    }

    // Where RA (degrees) / Dec (degrees) falls on the turned rete, in the
    // item's pixels.
    function place(ra, dec) {
        const d2r = Math.PI / 180;
        const r = rEq * Math.tan((90 - dec) * d2r / 2) * radius;
        const h = (rete - ra) * d2r;
        return Qt.point(cx + mirror * Math.sin(h) * r, cy - Math.cos(h) * r);
    }

    ShaderEffect {
        anchors.centerIn: parent
        width: astro.radius * 2 * inset
        height: width

        // The instrument fills the middle 1/inset of the item, leaving room
        // for the bloom's halo.
        property real inset: 1.12
        property real itemWidth: width
        property real itemHeight: height
        property real rete: astro.rete
        property real rule: astro.rule
        property real lat: astro.latitude
        property real litSigns: astro.litSigns
        property real glow: astro.glow
        property real bloom: astro.bloom
        property real cloud: astro.cloud
        property real drift: astro.drift
        property real fine: astro.radius > 220 ? 1 : 0
        property vector4d litA: Qt.vector4d(astro.litAt(0), astro.litAt(1), astro.litAt(2), astro.litAt(3))
        property vector4d litB: Qt.vector4d(astro.litAt(4), astro.litAt(5), astro.litAt(6), astro.litAt(7))
        property vector4d litC: Qt.vector4d(astro.litAt(8), astro.litAt(9), astro.litAt(10), astro.litAt(11))
        property color brassColor: Sky.brass
        property color enamelColor: Sky.enamelDeep
        property color lampColor: Sky.lamp
        property color cloudColor: "#8c96a6"

        fragmentShader: Qt.resolvedUrl("../../../../shaders/astrolabe.frag.qsb")
    }

    // The hours, engraved round the inside of the limb: noon at the top,
    // midnight at the foot.
    Repeater {
        model: 24

        Text {
            required property int index
            readonly property real a: index * 15 * Math.PI / 180 * astro.mirror
            readonly property real r: astro.radius * 0.875
            visible: !astro.small || index % 3 === 0
            x: astro.cx + Math.sin(a) * r - width / 2
            y: astro.cy - Math.cos(a) * r - height / 2
            rotation: index * 15 * astro.mirror
            text: Clocks.roman(index % 12 === 0 ? 12 : index % 12)
            font.family: Sky.engraved
            font.pixelSize: Math.max(7, astro.radius * (astro.small ? 0.075 : 0.05))
            color: Sky.alpha(Sky.brassDeep, 0.9)
            opacity: astro.cloud > 0 ? 1 - astro.cloud * 0.5 : 1
        }
    }

    // The signs, on the ecliptic ring, turning with the rete.
    Repeater {
        model: astro.small ? 0 : 12

        Text {
            required property int index
            readonly property real lam: (index * 30 + 15) * Math.PI / 180
            readonly property real ra: Math.atan2(Math.sin(lam) * Math.cos(astro.eps), Math.cos(lam)) * 180 / Math.PI
            readonly property real dec: Math.asin(Math.sin(astro.eps) * Math.sin(lam)) * 180 / Math.PI
            readonly property point on: astro.place(ra, dec)
            // The ring's centre, towards RA 18h; the glyph sits in the band,
            // just inside the ecliptic.
            readonly property point centre: astro.place(270, 90 - 2 * Math.atan(((astro.rCap - astro.rCan) / 2) / astro.rEq) * 180 / Math.PI)
            readonly property real k: 1 - (0.024 * astro.radius) / Math.max(1, Math.hypot(on.x - centre.x, on.y - centre.y))
            readonly property real gx: centre.x + (on.x - centre.x) * k
            readonly property real gy: centre.y + (on.y - centre.y) * k
            x: gx - width / 2
            y: gy - height / 2
            rotation: Math.atan2(on.x - centre.x, centre.y - on.y) * 180 / Math.PI
            text: Sky.zodiac[index][1]
            font.family: Sky.symbols
            font.pixelSize: astro.radius * 0.038
            color: Sky.alpha(Sky.brassDeep, 0.95)
        }
    }

    // The stars' names, beside their pointers.
    Repeater {
        model: astro.starNames && !astro.small ? Sky.reteStars.length : 0

        Text {
            required property int index
            readonly property var star: Sky.reteStars[index]
            readonly property point at: astro.place(star[1] * 15, star[2])
            readonly property real l: astro.litAt(index)
            x: at.x + (at.x >= astro.cx ? 10 : -10 - width)
            y: at.y - height / 2
            text: star[0]
            font.family: Sky.display
            font.italic: true
            font.pixelSize: Math.max(11, astro.radius * 0.042)
            color: l > 0.5 ? Sky.lamp : Sky.alpha(Sky.parchment, 0.78)
            style: Text.Outline
            styleColor: Sky.alpha(Sky.night, 0.85)
            opacity: 1 - astro.cloud * 0.6
        }
    }
}
