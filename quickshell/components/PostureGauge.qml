import QtQuick
import QtQuick.Shapes

// Sekiro's posture gauge: a slim track whose ends taper to a point, filled
// from the middle outwards as `value` (0..1) rises, gold turning orange as
// it nears breaking and red at the very end; a white tick stands at its
// middle and thin chevrons mark how far it can reach at either end. The
// fill takes the track's shape, so a little posture is a small lens in
// the middle, as in the game. `fromStart` fills it from the left end
// instead, the tick riding its leading edge (a slider's track, where the
// value must sit where it was set).
Item {
    id: gauge

    property real value: 0
    property bool fromStart: false
    // Breaking: the whole gauge flashes (0..1).
    property real flash: 0
    property bool chevrons: true
    property bool tick: true
    property color track: Qt.rgba(0, 0, 0, 0.5)
    property color line: Qt.rgba(1, 1, 1, 0.28)
    property color mark: "#f6f1e6"
    property color gold: "#e6b23c"
    property color orange: "#ee7a24"
    property color red: "#e8452c"
    property real lineWidth: 1

    readonly property real v: Math.max(0, Math.min(1, value))
    // Room each end keeps for its chevron.
    readonly property real chevronRoom: chevrons ? Math.round(height * 1.6) : 0
    readonly property real barH: height * 0.62
    readonly property real barW: width - 2 * chevronRoom
    readonly property real barX: chevronRoom
    readonly property real barY: (height - barH) / 2
    readonly property real taper: Math.min(barW / 2, barH * 2.6)
    readonly property real fillW: barW * v
    readonly property real fillX: fromStart ? barX : barX + (barW - fillW) / 2

    function mixc(a, b, t) {
        const x = Qt.color(a), y = Qt.color(b);
        return Qt.rgba(x.r + (y.r - x.r) * t, x.g + (y.g - x.g) * t, x.b + (y.b - x.b) * t, 1);
    }

    readonly property color fillColor: {
        const a = Math.max(0, Math.min(1, (v - 0.45) / 0.4));
        const b = Math.max(0, Math.min(1, (v - 0.9) / 0.1));
        return mixc(mixc(gold, orange, a), red, b);
    }
    readonly property color hotColor: mixc(fillColor, "#ffe2a0", 0.32 * (1 - Math.max(0, Math.min(1, (v - 0.8) / 0.2))) + 0.5 * flash)

    implicitWidth: 240
    implicitHeight: 12

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // The track.
        ShapePath {
            fillColor: gauge.track
            strokeColor: gauge.line
            strokeWidth: gauge.lineWidth
            joinStyle: ShapePath.MiterJoin

            PathPolyline {
                path: ThemeShapes.spindle(gauge.barX, gauge.barY, gauge.barW, gauge.barH, gauge.taper, 0.5)
            }
        }

        // The posture taken, from the middle out.
        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: gauge.fillX
                y1: 0
                x2: gauge.fillX + gauge.fillW
                y2: 0
                GradientStop { position: 0; color: gauge.mixc(gauge.fillColor, "#7a2a10", 0.25) }
                GradientStop { position: gauge.fromStart ? 0.85 : 0.5; color: gauge.hotColor }
                GradientStop { position: 1; color: gauge.mixc(gauge.fillColor, "#7a2a10", gauge.fromStart ? 0.05 : 0.25) }
            }

            PathPolyline {
                path: gauge.fillW > 0.5 ? ThemeShapes.spindle(gauge.fillX, gauge.barY + 0.5, gauge.fillW, gauge.barH - 1, gauge.taper * Math.min(1, gauge.fillW / gauge.barW + 0.35), 0) : []
            }
        }

        // The chevrons, at the reach of each end.
        ShapePath {
            fillColor: "transparent"
            strokeColor: gauge.chevrons ? gauge.mark : "transparent"
            strokeWidth: gauge.lineWidth
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap

            startX: gauge.chevronRoom * 0.75
            startY: gauge.height * 0.08
            PathLine { x: gauge.chevronRoom * 0.1; y: gauge.height / 2 }
            PathLine { x: gauge.chevronRoom * 0.75; y: gauge.height * 0.92 }
            PathMove { x: gauge.width - gauge.chevronRoom * 0.75; y: gauge.height * 0.08 }
            PathLine { x: gauge.width - gauge.chevronRoom * 0.1; y: gauge.height / 2 }
            PathLine { x: gauge.width - gauge.chevronRoom * 0.75; y: gauge.height * 0.92 }
        }
    }

    // The tick at the middle (or riding the fill's leading edge).
    Rectangle {
        visible: gauge.tick
        x: Math.round((gauge.fromStart ? gauge.fillX + gauge.fillW : gauge.width / 2) - width / 2)
        y: 0
        width: Math.max(1, gauge.lineWidth * 1.5)
        height: gauge.height
        color: gauge.mark
    }
}
