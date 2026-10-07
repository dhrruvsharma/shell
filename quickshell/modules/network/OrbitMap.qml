pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.services as Services
import qs.colors
import qs.components

// The Bluetooth devices in orbit round this computer, seen a little from
// above: connected ones on the inner orbit, joined to it by a line and
// ringed by their battery; paired ones on the middle orbit; ones a scan
// found on the outer, dashed one. A device glides to its new orbit as it
// connects or pairs. `highlight` (a device's D-Bus path: the list's row
// under the pointer) and the device under the pointer are ringed in the
// second accent; clicking one is clicking its row.
Item {
    id: orbits

    // the devices to show (BluetoothDevice), the panel's order
    property var devices: []
    property bool powered: true
    property bool scanning: false
    property bool discoverable: false
    property string highlight: ""
    property string hoverPath: ""
    // what's going on with each device: dbusPath -> "pairing" | "connecting"
    property var busy: ({})

    readonly property color accent: Services.DesktopTheme.accent
    readonly property color accent2: Services.DesktopTheme.accent2
    property color ground: Colors.surface_container_low

    signal picked(var device)

    // ── Geometry ──────────────────────────────────────────────────────────────

    readonly property real cx: width / 2
    readonly property real cy: height / 2 + 2
    // how flat the orbits look: the plane seen from above at a slant
    readonly property real tilt: 0.36
    readonly property var radii: [width * 0.2, width * 0.335, width * 0.47]
    // Where the devices sit along their orbits (radians: 0 to the right, a
    // quarter turn the near side): each a golden angle on from the one
    // before, across all the orbits, so no two line up whatever their
    // number; the first, connected, near and to the right.
    readonly property real firstAngle: 0.45
    readonly property real goldenAngle: Math.PI * (3 - Math.sqrt(5))
    // past this many, found devices are only in the list
    readonly property int maxFound: 12

    function orbitOf(d) {
        return d.connected && d.paired ? 0 : d.paired ? 1 : 2
    }

    readonly property var placed: {
        const near = devices.filter(d => orbitOf(d) < 2)
        return near.concat(devices.filter(d => orbitOf(d) === 2).slice(0, maxFound))
    }

    // Kept by D-Bus path, so a device that changes orbit moves rather than
    // being made anew.
    ListModel { id: placedModel }

    function sync() {
        const paths = placed.map(d => d.dbusPath)
        for (let i = placedModel.count - 1; i >= 0; i--) {
            if (!paths.includes(placedModel.get(i).path))
                placedModel.remove(i)
        }
        for (const p of paths) {
            let found = false
            for (let j = 0; j < placedModel.count; j++) {
                if (placedModel.get(j).path === p) {
                    found = true
                    break
                }
            }
            if (!found)
                placedModel.append({ path: p })
        }
    }

    onPlacedChanged: sync()
    Component.onCompleted: sync()

    // Where the names go (path -> "above" | "below" | "right" | "left";
    // none: no name): the connected first, then the paired, each on its
    // far side from the computer by preference, else below or above, else
    // beside, wherever it stays on the map and covers no name already
    // placed, no known device and not the computer. A connected device is
    // always named, and the one pointed at.
    readonly property var names: {
        const planets = []
        for (let i = 0; i < deviceRepeater.count; i++) {
            const p = deviceRepeater.itemAt(i)
            if (p && p.visible)
                planets.push(p)
        }
        const meets = (a, b) => a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h
        const home = { x: cx - 25, y: cy - 25, w: 50, h: 50 }
        const discs = planets.filter(p => p.orbit < 2).map(p => ({ x: p.x, y: p.y, w: p.width, h: p.height, p: p }))
        const taken = []
        const out = {}
        const named = planets.filter(p => p.orbit < 2 || p.marked)
            .sort((a, b) => (b.marked - a.marked) || (a.orbit - b.orbit) || (a.slot - b.slot))
        for (const p of named) {
            const sides = (p.nameAbove ? ["above", "below"] : ["below", "above"]).concat(p.px > cx ? ["right", "left"] : ["left", "right"])
            const free = sides.find(side => {
                const r = p.nameRectAt(side)
                return r.x >= 0 && r.x + r.w <= width && r.y >= 0 && r.y + r.h <= height
                    && !meets(home, r) && !taken.some(t => meets(t, r)) && !discs.some(d => d.p !== p && meets(d, r))
            })
            const side = free ?? (p.orbit === 0 || p.marked ? sides[0] : "")
            if (side !== "") {
                taken.push(p.nameRectAt(side))
                out[p.path] = side
            }
        }
        return out
    }

    // ── The orbits ────────────────────────────────────────────────────────────

    Item {
        anchors.fill: parent
        opacity: orbits.powered ? 1 : 0.35
        Behavior on opacity { NumberAnimation { duration: 400 } }

        // the plane they turn in, faintly lit from the middle
        Shape {
            x: orbits.cx - width / 2
            y: orbits.cy - height / 2
            width: orbits.radii[2] * 2
            height: width
            transform: Scale {
                origin.x: orbits.radii[2]
                origin.y: orbits.radii[2]
                yScale: orbits.tilt
            }
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: orbits.radii[2]; centerY: orbits.radii[2]
                    centerRadius: orbits.radii[2]
                    focalX: orbits.radii[2]; focalY: orbits.radii[2]
                    GradientStop { position: 0; color: Colors.withAlpha(orbits.accent, 0.1) }
                    GradientStop { position: 0.6; color: Colors.withAlpha(orbits.accent, 0.04) }
                    GradientStop { position: 1; color: "transparent" }
                }
                PathAngleArc {
                    centerX: orbits.radii[2]; centerY: orbits.radii[2]
                    radiusX: orbits.radii[2]; radiusY: orbits.radii[2]
                    startAngle: 0; sweepAngle: 360
                }
            }
        }

        Repeater {
            model: 3

            delegate: Shape {
                id: ring
                required property int index
                readonly property bool lit: ring.index === 0 && orbits.placed.some(d => orbits.orbitOf(d) === 0)
                readonly property color tone: ring.lit ? orbits.accent : Colors.on_surface_variant
                readonly property real strength: ring.lit ? 0.55 : ring.index === 2 ? 0.26 : 0.34
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                // the far half fainter than the near
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Colors.withAlpha(ring.tone, ring.strength * 0.45)
                    strokeWidth: 1
                    strokeStyle: ring.index === 2 ? ShapePath.DashLine : ShapePath.SolidLine
                    dashPattern: [2, 4]
                    PathAngleArc {
                        centerX: orbits.cx
                        centerY: orbits.cy
                        radiusX: orbits.radii[ring.index]
                        radiusY: orbits.radii[ring.index] * orbits.tilt
                        startAngle: 180
                        sweepAngle: 180
                    }
                }
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Colors.withAlpha(ring.tone, ring.strength)
                    strokeWidth: ring.lit ? 1.4 : 1.1
                    strokeStyle: ring.index === 2 ? ShapePath.DashLine : ShapePath.SolidLine
                    dashPattern: [2, 4]
                    PathAngleArc {
                        centerX: orbits.cx
                        centerY: orbits.cy
                        radiusX: orbits.radii[ring.index]
                        radiusY: orbits.radii[ring.index] * orbits.tilt
                        startAngle: 0
                        sweepAngle: 180
                    }
                }
            }
        }
    }

    // A scan: rings going out from the computer.
    Repeater {
        model: 2

        delegate: Shape {
            id: wave
            required property int index
            property real spread: 0
            anchors.fill: parent
            visible: orbits.scanning || waveAnim.running
            opacity: (1 - spread) * 0.8
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: orbits.accent2
                strokeWidth: 1.5
                PathAngleArc {
                    centerX: orbits.cx
                    centerY: orbits.cy
                    radiusX: 26 + wave.spread * (orbits.radii[2] + 12 - 26)
                    radiusY: radiusX * orbits.tilt
                    startAngle: 0
                    sweepAngle: 360
                }
            }

            SequentialAnimation on spread {
                id: waveAnim
                running: orbits.scanning
                alwaysRunToEnd: true
                loops: Animation.Infinite
                PauseAnimation { duration: wave.index * 900 }
                NumberAnimation { from: 0; to: 1; duration: 1800; easing.type: Easing.OutQuad }
                PauseAnimation { duration: (1 - wave.index) * 900 }
            }
        }
    }

    // ── The devices ───────────────────────────────────────────────────────────

    Repeater {
        id: deviceRepeater
        model: placedModel
        delegate: Planet {}
    }

    Item {
        id: nameLayer
        anchors.fill: parent
        z: 50
    }

    // ── This computer ─────────────────────────────────────────────────────────

    Item {
        x: orbits.cx - width / 2
        y: orbits.cy - height / 2
        width: 46
        height: 46
        z: 0

        // seen: it glows
        Shape {
            anchors.centerIn: parent
            width: 120
            height: 120
            visible: orbits.powered
            opacity: orbits.discoverable ? 1 : 0.45
            Behavior on opacity { NumberAnimation { duration: 400 } }
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: 60; centerY: 60
                    centerRadius: 60
                    focalX: 60; focalY: 60
                    GradientStop { position: 0; color: Colors.withAlpha(orbits.discoverable ? orbits.accent2 : orbits.accent, 0.38) }
                    GradientStop { position: 0.45; color: Colors.withAlpha(orbits.discoverable ? orbits.accent2 : orbits.accent, 0.1) }
                    GradientStop { position: 1; color: "transparent" }
                }
                PathAngleArc {
                    centerX: 60; centerY: 60
                    radiusX: 60; radiusY: 60
                    startAngle: 0; sweepAngle: 360
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Qt.tint(Colors.surface_container_highest, Colors.withAlpha(orbits.accent, orbits.powered ? 0.12 : 0))
            border.width: 1
            border.color: orbits.powered ? Colors.withAlpha(orbits.accent, 0.6) : Colors.outline_variant
            Behavior on border.color { ColorAnimation { duration: 300 } }

            MaterialIcon {
                anchors.centerIn: parent
                text: "󰌢"
                font.pixelSize: 22
                color: orbits.powered ? orbits.accent : Colors.on_surface_variant
            }
        }
    }

    // A device: a disc with its kind's glyph, its name beside it. Connected:
    // filled in the accent, a line home and its battery round it.
    component Planet: Item {
        id: planet

        required property string path

        readonly property var device: Services.Bluetooth.deviceFor(path)
        readonly property int orbit: device ? orbits.orbitOf(device) : 2
        readonly property int slot: Math.max(0, orbits.placed.findIndex(d => d.dbusPath === path))
        readonly property real target: (orbits.firstAngle + slot * orbits.goldenAngle) % (2 * Math.PI)
        readonly property string work: orbits.busy[path] ?? ""
        readonly property bool working: work !== "" || (device?.pairing ?? false)
        readonly property bool marked: orbits.hoverPath === path || orbits.highlight === path
        readonly property bool linked: orbit === 0

        // the orbit it's on and where along it, eased between orbits
        property real reach: orbits.radii[orbit]
        Behavior on reach { NumberAnimation { duration: 700; easing.type: Easing.InOutCubic } }
        // (turned the short way round: the target wraps at a full turn)
        property real angle: 0
        property bool settled: false
        Behavior on angle {
            enabled: planet.settled
            NumberAnimation { duration: 700; easing.type: Easing.InOutCubic }
        }
        Component.onCompleted: {
            angle = target
            settled = true
        }
        onTargetChanged: {
            if (!settled)
                return
            let t = target
            while (t - angle > Math.PI)
                t -= 2 * Math.PI
            while (angle - t > Math.PI)
                t += 2 * Math.PI
            angle = t
        }
        // appears out of the computer
        property real born
        NumberAnimation on born { from: 0; to: 1; duration: 650; easing.type: Easing.OutCubic }

        readonly property real px: orbits.cx + reach * born * Math.cos(angle)
        readonly property real py: orbits.cy + reach * born * orbits.tilt * Math.sin(angle)
        // which way it is from the computer
        readonly property real dist: Math.max(1, Math.hypot(px - orbits.cx, py - orbits.cy))
        readonly property real ux: (px - orbits.cx) / dist
        readonly property real uy: (py - orbits.cy) / dist
        // the near side bigger, the far side smaller and fainter
        readonly property real near: (1 + Math.sin(angle)) / 2
        readonly property real size: (orbit === 0 ? 34 : orbit === 1 ? 30 : 24) * (0.84 + 0.2 * near)

        x: px - width / 2
        y: py - height / 2
        width: size
        height: size
        z: Math.sin(angle) * 10
        visible: device !== null && orbits.powered
        opacity: born * (orbit === 2 ? 0.75 + 0.25 * near : 0.85 + 0.15 * near)

        // the line home
        Shape {
            x: -planet.x
            y: -planet.y
            width: orbits.width
            height: orbits.height
            z: -100
            visible: planet.linked || planet.work === "connecting"
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                id: tether
                fillColor: "transparent"
                strokeColor: Colors.withAlpha(planet.linked ? orbits.accent : orbits.accent2, planet.linked ? 0.6 : 0.8)
                strokeWidth: 1.5
                strokeStyle: planet.linked ? ShapePath.SolidLine : ShapePath.DashLine
                dashPattern: [3, 3]
                capStyle: ShapePath.RoundCap
                // from the computer's rim to the device's
                startX: orbits.cx + planet.ux * 25
                startY: orbits.cy + planet.uy * 25
                PathLine { x: planet.px - planet.ux * planet.size / 2; y: planet.py - planet.uy * planet.size / 2 }

                NumberAnimation on dashOffset {
                    running: planet.work === "connecting"
                    from: 6; to: 0
                    duration: 500
                    loops: Animation.Infinite
                }
            }
        }

        // the battery, round it
        Shape {
            anchors.centerIn: parent
            width: parent.width + 10
            height: parent.height + 10
            visible: planet.linked && (planet.device?.batteryAvailable ?? false)
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: Colors.withAlpha(orbits.accent2, 0.2)
                strokeWidth: 2
                PathAngleArc {
                    centerX: planet.width / 2 + 5; centerY: planet.height / 2 + 5
                    radiusX: planet.width / 2 + 3.5; radiusY: radiusX
                    startAngle: 0; sweepAngle: 360
                }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: orbits.accent2
                strokeWidth: 2
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: planet.width / 2 + 5; centerY: planet.height / 2 + 5
                    radiusX: planet.width / 2 + 3.5; radiusY: radiusX
                    startAngle: -90
                    sweepAngle: 360 * Math.max(0, Math.min(1, planet.device?.battery ?? 0))
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: planet.linked ? orbits.accent
                : planet.orbit === 1 ? Colors.surface_container_highest
                : orbits.ground
            border.width: planet.marked ? 2 : 1
            border.color: planet.marked ? orbits.accent2
                : planet.linked ? Qt.lighter(orbits.accent, 1.15)
                : Colors.withAlpha(Colors.on_surface_variant, planet.orbit === 1 ? 0.35 : 0.3)
            Behavior on color { ColorAnimation { duration: 400 } }

            MaterialIcon {
                anchors.centerIn: parent
                text: Services.Bluetooth.glyphFor(planet.device)
                font.pixelSize: Math.round(planet.size * 0.5)
                color: planet.linked ? Colors.on_primary
                    : planet.orbit === 1 ? Colors.on_surface
                    : Colors.on_surface_variant
            }
        }

        Spinner {
            anchors.centerIn: parent
            width: parent.width + 8
            visible: planet.working
            border.width: 1.5
            arcColor: orbits.accent2
        }

        // its name's side, by preference: on the far side above the disc,
        // clear of the computer; OrbitMap.names has the last word
        readonly property bool nameAbove: Math.sin(angle) < -0.2
        readonly property real nameWidth: nameText.width
        readonly property real nameHeight: nameText.height
        readonly property string nameSide: orbits.names[path] ?? ""

        // where its name would sit on that side, in the map's coordinates
        function nameRectAt(side) {
            const w = nameWidth
            const h = nameHeight
            const gap = 3
            switch (side) {
            case "above": return { x: px - w / 2, y: py - size / 2 - gap - h, w: w, h: h }
            case "below": return { x: px - w / 2, y: py + size / 2 + gap, w: w, h: h }
            case "right": return { x: px + size / 2 + gap + 2, y: py - h / 2, w: w, h: h }
            default: return { x: px - size / 2 - gap - 2 - w, y: py - h / 2, w: w, h: h }
            }
        }

        // its name, for the ones you know (and any pointed at), room allowing
        // (drawn over every device: the names have a layer of their own)
        StyledText {
            id: nameText
            readonly property var at: planet.nameRectAt(planet.nameSide || "below")
            parent: nameLayer
            x: at.x
            y: at.y
            width: Math.min(implicitWidth, 92)
            horizontalAlignment: Text.AlignHCenter
            visible: planet.nameSide !== "" && planet.visible
            opacity: planet.opacity
            style: Text.Outline
            styleColor: Colors.withAlpha(orbits.ground, 0.85)
            text: planet.device ? (planet.device.name || "Unknown") : ""
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font.pixelSize: 10
            font.weight: planet.linked ? Font.DemiBold : Font.Normal
            color: planet.marked ? orbits.accent2
                : planet.linked ? Colors.on_surface
                : Colors.withAlpha(Colors.on_surface_variant, 0.85)
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: {
                if (containsMouse)
                    orbits.hoverPath = planet.path
                else if (orbits.hoverPath === planet.path)
                    orbits.hoverPath = ""
            }
            onClicked: if (planet.device) orbits.picked(planet.device)
        }
    }
}
