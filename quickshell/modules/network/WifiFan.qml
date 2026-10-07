pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.services as Services
import qs.colors
import qs.components

// The networks in range as the Wi-Fi sign opened out: this computer at the
// foot and the sign's four bars over it, a quarter of the signal strengths
// each, the strongest innermost; every network the radio hears sits on the
// bar of its strength, as far out as it is faint. 2.4 GHz has the left of
// the fan and 5 GHz (then 6 GHz) the right, each in channel order, so a
// crowded channel shows as a cluster; a network on both bands is on both
// sides. The network in use is a disc in the accent joined to the computer,
// and its bar is lit; saved ones are ringed, hidden ones specks.
// `highlight` (an SSID: the list's row under the pointer) and the one under
// the pointer are ringed in the second accent. Clicking a network joins it
// on the band it's on there. A scan lights the bars outwards in turn;
// switched off, the networks fall back into the computer.
Item {
    id: fan

    property bool live: true
    property bool scanning: false
    property string highlight: ""
    // `highlight` on this band only ("" for all its bands)
    property string highlightBand: ""
    // the SSID being joined, and on which band ("" for whichever)
    property string joining: ""
    property string joiningBand: ""
    // the point under the pointer
    property string hoverKey: ""
    // the signal of the network in use, or -1
    readonly property real homeSignal: points.find(p => p.active)?.signal ?? -1
    readonly property string hoverSsid: points.find(p => p.key === hoverKey)?.ssid ?? ""
    // what the fan is drawn on (the card's colour)
    property color ground: Colors.surface_container_low

    readonly property color accent: Services.DesktopTheme.accent
    readonly property color accent2: Services.DesktopTheme.accent2

    // a network clicked, on the band it was clicked on
    signal picked(string ssid, string band)

    // ── Geometry ──────────────────────────────────────────────────────────────

    // the computer
    readonly property real sx: width / 2
    readonly property real sy: height - 20
    readonly property real rMin: 40
    readonly property real rMax: Math.max(rMin + 20, Math.min(sx - 10, sy - 8))
    // the fan's sweep, in radians from the right
    readonly property real from: Math.PI * 0.95
    readonly property real to: Math.PI * 0.05

    // How far out a network sits: the fainter, the further.
    function radiusOf(signal) {
        return rMin + (1 - Math.max(0, Math.min(1, signal / 100))) * (rMax - rMin)
    }

    // ── The networks ──────────────────────────────────────────────────────────

    // A point per network and band, its strongest access point there (the
    // one in use, if it is); a hidden network is a point per access point.
    readonly property var points: {
        const best = new Map()
        for (const a of Services.Network.accessPoints) {
            const key = a.ssid !== "" ? a.ssid + "\n" + a.band : a.bssid
            const seen = best.get(key)
            if (!seen || (a.active && !seen.active) || (!seen.active && a.signal > seen.signal)) {
                best.set(key, {
                    key: key, ssid: a.ssid, band: a.band, channel: a.channel, signal: a.signal,
                    saved: a.saved, active: a.active, hidden: a.ssid === ""
                })
            }
        }
        return Array.from(best.values())
    }

    // Where each point sits along the fan (key -> radians), and the bands'
    // sectors: each band a share of the sweep by how many it has (a fifth at
    // least, so a lone network isn't squeezed against the edge).
    readonly property var plan: {
        const bands = ["2.4", "5", "6"].filter(b => points.some(p => p.band === b))
        const angles = {}
        const sectors = []
        const counts = bands.map(b => points.filter(p => p.band === b).length)
        const shares = counts.map(n => Math.max(n, points.length * 0.2))
        const total = shares.reduce((a, b) => a + b, 0)
        let at = from
        bands.forEach((band, i) => {
            const sweep = (from - to) * shares[i] / total
            const mine = points.filter(p => p.band === band)
                .sort((p, q) => (p.channel - q.channel) || (q.signal - p.signal))
            mine.forEach((p, j) => angles[p.key] = at - (j + 0.5) * sweep / mine.length)
            sectors.push({ band: band, from: at, to: at - sweep })
            at -= sweep
        })
        return { angles: angles, sectors: sectors }
    }

    // Kept by key, so a rescan moves the points rather than making them anew.
    ListModel { id: pointModel }

    function sync() {
        if (!live)
            return
        const keys = points.map(p => p.key)
        for (let i = pointModel.count - 1; i >= 0; i--) {
            if (!keys.includes(pointModel.get(i).key))
                pointModel.remove(i)
        }
        for (const k of keys) {
            let found = false
            for (let j = 0; j < pointModel.count; j++) {
                if (pointModel.get(j).key === k) {
                    found = true
                    break
                }
            }
            if (!found)
                pointModel.append({ key: k })
        }
    }

    onPointsChanged: sync()
    onLiveChanged: {
        if (!live)
            return
        pointModel.clear()
        sync()
    }
    Component.onCompleted: sync()

    // 1 with the radio on; off, the networks fall back into the computer.
    property real presence: live ? 1 : 0
    Behavior on presence { NumberAnimation { duration: 600; easing.type: Easing.InOutCubic } }

    // Where the names go (key -> "above" | "aboveLeft" | "aboveRight" |
    // "below" | "left" | "right"; none: no name): the network pointed at,
    // the saved ones, then the four strongest others, each on the side away
    // from the middle by preference, wherever it stays on the fan and
    // covers no name already placed, no other named network and not the
    // computer. The one pointed at is always named. The one in use goes
    // unnamed unless pointed at: the card under the fan names it, and its
    // neighbours need the room.
    readonly property var names: {
        const beacons = []
        for (let i = 0; i < beaconRepeater.count; i++) {
            const b = beaconRepeater.itemAt(i)
            if (b && b.visible && b.point)
                beacons.push(b)
        }
        const meets = (a, b) => a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h
        const home = { x: sx - 21, y: sy - 21, w: 42, h: 42 }
        const strongest = beacons.filter(b => !b.point.hidden && !b.point.active && !b.point.saved)
            .sort((p, q) => q.point.signal - p.point.signal).slice(0, 4)
        const rank = b => b.marked ? 0 : b.point.saved ? 1 : 2
        const named = beacons.filter(b => b.marked || (!b.point.hidden && !b.point.active && (b.point.saved || strongest.includes(b))))
            .sort((p, q) => (rank(p) - rank(q)) || (q.point.signal - p.point.signal))
        // a name may cover a nameless speck, not a named network (or the
        // one in use)
        const discs = named.concat(beacons.filter(b => b.point.active))
            .map(b => ({ x: b.x, y: b.y, w: b.width, h: b.height, b: b }))
        const taken = []
        const out = {}
        for (const b of named) {
            const sides = b.angle > Math.PI * 0.62 ? ["left", "above", "aboveLeft", "below", "aboveRight", "right"]
                : b.angle < Math.PI * 0.38 ? ["right", "above", "aboveRight", "below", "aboveLeft", "left"]
                : b.angle > Math.PI / 2 ? ["above", "aboveLeft", "left", "aboveRight", "right", "below"]
                : ["above", "aboveRight", "right", "aboveLeft", "left", "below"]
            const free = sides.find(side => {
                const r = b.nameRectAt(side)
                return r.x >= 0 && r.x + r.w <= width && r.y >= 0 && r.y + r.h <= height
                    && !meets(home, r) && !taken.some(t => meets(t, r)) && !discs.some(d => d.b !== b && meets(d, r))
            })
            const side = free ?? (b.marked ? sides[0] : "")
            if (side !== "") {
                taken.push(b.nameRectAt(side))
                out[b.key] = side
            }
        }
        return out
    }

    // ── The sign ──────────────────────────────────────────────────────────────

    Item {
        id: sign
        anchors.fill: parent
        opacity: 0.4 + 0.6 * fan.presence

        // the air it hears, faintly lit from the computer
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: fan.sx; centerY: fan.sy
                    centerRadius: fan.rMax
                    focalX: fan.sx; focalY: fan.sy
                    GradientStop { position: 0; color: Colors.withAlpha(fan.accent, 0.14) }
                    GradientStop { position: 0.5; color: Colors.withAlpha(fan.accent, 0.05) }
                    GradientStop { position: 1; color: "transparent" }
                }
                startX: fan.sx - fan.rMax
                startY: fan.sy
                PathArc {
                    x: fan.sx + fan.rMax
                    y: fan.sy
                    radiusX: fan.rMax
                    radiusY: fan.rMax
                }
                PathLine { x: fan.sx - fan.rMax; y: fan.sy }
            }
        }

        // a scan: the arcs light outwards in turn
        property real wave: -1
        NumberAnimation on wave {
            running: fan.scanning
            alwaysRunToEnd: true
            loops: Animation.Infinite
            from: -0.5
            to: 4.5
            duration: 1500
        }

        // The sign's bars: four bands, a quarter of the strengths each, the
        // strongest innermost; the one the connection is in is lit.
        Repeater {
            model: 4

            delegate: Shape {
                id: bar
                required property int index
                readonly property real r0: fan.radiusOf(100 - bar.index * 25)
                readonly property real r1: fan.radiusOf(75 - bar.index * 25)
                readonly property real mid: (r0 + r1) / 2
                readonly property real thickness: Math.max(2, r1 - r0 - 7)
                // its ends stop short of the ground, round caps and all
                readonly property real lift: Math.asin(Math.min(1, (thickness / 2 + 2) / mid)) * 180 / Math.PI
                readonly property bool home: fan.homeSignal >= 0
                    && fan.homeSignal <= 100 - bar.index * 25 && (fan.homeSignal > 75 - bar.index * 25 || bar.index === 3)
                // a scan lights the bars outwards in turn
                readonly property real glow: Math.max(0, 1 - Math.abs(sign.wave - (bar.index + 0.5)) * 1.3)
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Qt.tint(
                        Qt.tint(Colors.withAlpha(Colors.on_surface_variant, 0.06), Colors.withAlpha(fan.accent, bar.home ? 0.14 : 0)),
                        Colors.withAlpha(fan.accent2, bar.glow * 0.38))
                    strokeWidth: bar.thickness
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: fan.sx
                        centerY: fan.sy
                        radiusX: bar.mid
                        radiusY: bar.mid
                        startAngle: 180 + bar.lift
                        sweepAngle: 180 - 2 * bar.lift
                    }
                }
            }
        }

        // between the bands
        Repeater {
            model: fan.plan.sectors.slice(1)

            delegate: Shape {
                id: divider
                required property var modelData
                readonly property real a: modelData.from
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Colors.withAlpha(Colors.on_surface_variant, 0.22)
                    strokeWidth: 1
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [1, 4]
                    startX: fan.sx + (fan.rMin - 8) * Math.cos(divider.a)
                    startY: fan.sy - (fan.rMin - 8) * Math.sin(divider.a)
                    PathLine {
                        x: fan.sx + (fan.rMax + 4) * Math.cos(divider.a)
                        y: fan.sy - (fan.rMax + 4) * Math.sin(divider.a)
                    }
                }
            }
        }

        // the ground the sign stands on
        Rectangle {
            x: 0
            width: fan.sx - 26
            y: fan.sy
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Colors.withAlpha(Colors.on_surface_variant, 0.3) }
            }
        }
        Rectangle {
            x: fan.sx + 26
            width: fan.width - x
            y: fan.sy
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Colors.withAlpha(Colors.on_surface_variant, 0.3) }
                GradientStop { position: 1; color: "transparent" }
            }
        }

        // the bands' names at the ends of the fan
        StyledText {
            x: 2
            y: fan.sy + 4
            visible: fan.plan.sectors.length > 0
            text: (fan.plan.sectors[0]?.band ?? "") + " GHz"
            font.pixelSize: 10
            color: Colors.withAlpha(Colors.on_surface_variant, 0.6)
        }
        StyledText {
            anchors.right: parent.right
            anchors.rightMargin: 2
            y: fan.sy + 4
            visible: fan.plan.sectors.length > 1
            text: fan.plan.sectors.slice(1).map(s => s.band).join(" · ") + " GHz"
            font.pixelSize: 10
            color: Colors.withAlpha(Colors.on_surface_variant, 0.6)
        }
    }

    // ── The networks ──────────────────────────────────────────────────────────

    Repeater {
        id: beaconRepeater
        model: pointModel
        delegate: Beacon {}
    }

    Item {
        id: nameLayer
        anchors.fill: parent
        z: 50
    }

    // ── This computer ─────────────────────────────────────────────────────────

    Rectangle {
        x: fan.sx - width / 2
        y: fan.sy - height / 2
        width: 40
        height: 40
        radius: width / 2
        z: 20
        color: Qt.tint(Colors.surface_container_highest, Colors.withAlpha(fan.accent, fan.live ? 0.12 : 0))
        border.width: 1
        border.color: fan.live ? Colors.withAlpha(fan.accent, 0.6) : Colors.outline_variant
        Behavior on border.color { ColorAnimation { duration: 300 } }

        MaterialIcon {
            anchors.centerIn: parent
            text: "󰌢"
            font.pixelSize: 19
            color: fan.live ? fan.accent : Colors.on_surface_variant
        }
    }

    // A network: a dot, bigger and brighter the nearer it is, ringed once
    // saved (a hidden one a speck); the one in use a disc in the accent with
    // the sign on it, joined to the computer.
    component Beacon: Item {
        id: beacon

        required property string key

        readonly property var point: fan.points.find(p => p.key === key) ?? null
        readonly property bool active: point?.active ?? false
        readonly property bool saved: point?.saved ?? false
        readonly property bool hidden: point?.hidden ?? false
        readonly property real signal: point?.signal ?? 0
        readonly property string band: point?.band ?? ""
        readonly property bool marked: fan.hoverKey === key
            || (fan.highlight !== "" && (point?.ssid ?? "") === fan.highlight
                && (fan.highlightBand === "" || fan.highlightBand === band))
        readonly property bool joining: fan.joining !== "" && (point?.ssid ?? "") === fan.joining
            && (fan.joiningBand === "" || fan.joiningBand === band)
        // on more than one band: its name says which one, while pointed at
        readonly property bool twin: !hidden && fan.points.filter(p => p.ssid === point?.ssid).length > 1

        // where along the fan and how far out, eased as they change
        property bool settled: false
        property real angle: fan.plan.angles[key] ?? Math.PI / 2
        Behavior on angle {
            enabled: beacon.settled
            NumberAnimation { duration: 650; easing.type: Easing.InOutCubic }
        }
        property real distance: fan.radiusOf(signal)
        Behavior on distance {
            enabled: beacon.settled
            NumberAnimation { duration: 650; easing.type: Easing.InOutCubic }
        }
        Component.onCompleted: settled = true
        // comes out of the computer
        property real born
        NumberAnimation on born { from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }

        readonly property real reach: distance * born * fan.presence
        readonly property real px: fan.sx + reach * Math.cos(angle)
        readonly property real py: fan.sy - reach * Math.sin(angle)
        // near ones bigger: a strong network is close by, a faint one a speck
        readonly property real size: active ? 22 : hidden ? 4 : Math.round((saved ? 9 : 4) + 9 * signal / 100)

        x: px - width / 2
        y: py - height / 2
        width: size
        height: size
        z: active ? 10 : marked ? 9 : saved ? 5 : 1
        visible: point !== null && fan.presence > 0
        opacity: born * fan.presence * (active || marked ? 1 : hidden ? 0.45 : 0.5 + 0.5 * signal / 100)

        // the line to the computer
        Shape {
            id: beam
            x: -beacon.x
            y: -beacon.y
            width: fan.width
            height: fan.height
            z: -1
            visible: beacon.active || beacon.joining
            preferredRendererType: Shape.CurveRenderer

            readonly property real ux: Math.cos(beacon.angle)
            readonly property real uy: -Math.sin(beacon.angle)

            ShapePath {
                fillColor: "transparent"
                strokeColor: Colors.withAlpha(beacon.active ? fan.accent : fan.accent2, beacon.active ? 0.22 : 0)
                strokeWidth: 6
                capStyle: ShapePath.RoundCap
                startX: fan.sx + beam.ux * 22
                startY: fan.sy + beam.uy * 22
                PathLine { x: beacon.px - beam.ux * beacon.size / 2; y: beacon.py - beam.uy * beacon.size / 2 }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: Colors.withAlpha(beacon.active ? fan.accent : fan.accent2, 0.85)
                strokeWidth: 1.5
                strokeStyle: beacon.active ? ShapePath.SolidLine : ShapePath.DashLine
                dashPattern: [3, 3]
                capStyle: ShapePath.RoundCap
                startX: fan.sx + beam.ux * 22
                startY: fan.sy + beam.uy * 22
                PathLine { x: beacon.px - beam.ux * beacon.size / 2; y: beacon.py - beam.uy * beacon.size / 2 }

                NumberAnimation on dashOffset {
                    running: beacon.joining && !beacon.active
                    from: 6; to: 0
                    duration: 500
                    loops: Animation.Infinite
                }
            }
        }

        // a glow round the strong ones
        Shape {
            anchors.centerIn: parent
            width: parent.width * 3
            height: width
            visible: !beacon.hidden && beacon.signal > 35
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: beacon.size * 1.5; centerY: beacon.size * 1.5
                    centerRadius: beacon.size * 1.5
                    focalX: beacon.size * 1.5; focalY: beacon.size * 1.5
                    GradientStop { position: 0; color: Colors.withAlpha(beacon.tone, 0.32 * beacon.signal / 100) }
                    GradientStop { position: 1; color: "transparent" }
                }
                PathAngleArc {
                    centerX: beacon.size * 1.5; centerY: beacon.size * 1.5
                    radiusX: beacon.size * 1.5; radiusY: radiusX
                    startAngle: 0; sweepAngle: 360
                }
            }
        }

        readonly property color tone: active ? fan.accent : marked ? fan.accent2 : Colors.on_surface_variant

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: beacon.active ? fan.accent
                : beacon.hidden ? Colors.withAlpha(Colors.on_surface_variant, 0.55)
                : Qt.tint(fan.ground, Colors.withAlpha(beacon.tone, 0.45 + 0.5 * beacon.signal / 100))
            // saved: ringed
            border.width: beacon.marked ? 2 : beacon.saved && !beacon.active ? 1.5 : 0
            border.color: beacon.marked ? fan.accent2 : fan.ground
            Behavior on color { ColorAnimation { duration: 400 } }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 6
                height: width
                radius: width / 2
                visible: beacon.saved && !beacon.active && !beacon.marked
                color: "transparent"
                border.width: 1
                border.color: Colors.withAlpha(beacon.tone, 0.8)
            }

            SignalFan {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 1
                width: 12
                height: 10
                visible: beacon.active
                level: beacon.signal / 100
                tone: Colors.on_primary
                lit: true
            }
        }

        Spinner {
            anchors.centerIn: parent
            width: parent.width + 8
            visible: beacon.joining && !beacon.active
            border.width: 1.5
            arcColor: fan.accent2
        }

        // its name's place on the fan, by side
        readonly property real nameWidth: nameText.width
        readonly property real nameHeight: nameText.height
        readonly property string nameSide: fan.names[key] ?? ""

        function nameRectAt(side) {
            const w = nameWidth
            const h = nameHeight
            const gap = 3
            switch (side) {
            case "above": return { x: px - w / 2, y: py - size / 2 - gap - h, w: w, h: h }
            case "aboveLeft": return { x: px - w + 2, y: py - size / 2 - gap - h + 2, w: w, h: h }
            case "aboveRight": return { x: px - 2, y: py - size / 2 - gap - h + 2, w: w, h: h }
            case "below": return { x: px - w / 2, y: py + size / 2 + gap, w: w, h: h }
            case "right": return { x: px + size / 2 + gap + 1, y: py - h / 2, w: w, h: h }
            default: return { x: px - size / 2 - gap - 1 - w, y: py - h / 2, w: w, h: h }
            }
        }

        // (drawn over every network: the names have a layer of their own)
        StyledText {
            id: nameText
            readonly property var at: beacon.nameRectAt(beacon.nameSide || "above")
            parent: nameLayer
            x: at.x
            y: at.y
            width: Math.min(implicitWidth, fan.hoverKey === beacon.key ? 160 : 110)
            horizontalAlignment: beacon.nameSide === "left" || beacon.nameSide === "aboveLeft" ? Text.AlignRight
                : beacon.nameSide === "right" || beacon.nameSide === "aboveRight" ? Text.AlignLeft : Text.AlignHCenter
            visible: beacon.nameSide !== "" && beacon.visible
            opacity: Math.min(1, beacon.opacity * 1.3)
            style: Text.Outline
            styleColor: Colors.withAlpha(fan.ground, 0.85)
            text: !beacon.point ? ""
                : (beacon.point.ssid || "Hidden network")
                    + (beacon.twin && fan.hoverKey === beacon.key ? "  ·  " + beacon.band + " GHz" : "")
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font.pixelSize: 10
            font.weight: beacon.active ? Font.DemiBold : Font.Normal
            font.italic: beacon.hidden
            color: beacon.marked ? fan.accent2
                : beacon.active ? fan.accent
                : beacon.saved ? Colors.on_surface
                : Colors.withAlpha(Colors.on_surface_variant, 0.9)
        }

        MouseArea {
            anchors.centerIn: parent
            width: Math.max(18, parent.width + 8)
            height: width
            hoverEnabled: true
            cursorShape: beacon.hidden ? Qt.ArrowCursor : Qt.PointingHandCursor
            onContainsMouseChanged: {
                if (containsMouse)
                    fan.hoverKey = beacon.key
                else if (fan.hoverKey === beacon.key)
                    fan.hoverKey = ""
            }
            onClicked: {
                if (beacon.point && !beacon.hidden)
                    fan.picked(beacon.point.ssid, beacon.band)
            }
        }
    }
}
