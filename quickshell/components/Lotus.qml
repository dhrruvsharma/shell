import QtQuick
import QtQuick.Shapes

// A lotus (padma) seen from the side, the Devaloka theme's mark: five
// petals opening from a curved base, drawn in a 24 × 16 box stretched to
// the item.
Shape {
    id: lotus

    property color stroke: "#d8a23a"
    property color fill: Qt.rgba(0.85, 0.63, 0.23, 0.22)
    property real lineWidth: 1

    readonly property real kx: width / 24
    readonly property real ky: height / 16

    preferredRendererType: Shape.CurveRenderer

    // A petal: a pointed lens from the base up its axis (`angle` in degrees
    // from straight up), `len` long and `half` wide at its widest.
    function petal(angle, len, half) {
        const a = angle * Math.PI / 180;
        const ax = Math.sin(a), ay = -Math.cos(a);
        const bx = 12, by = 14.2;
        const pts = [];
        const side = (sgn, from, to, step) => {
            for (let t = from; step > 0 ? t <= to : t >= to; t += step) {
                const w = half * Math.pow(Math.sin(Math.PI * t), 0.8) * (1 - 0.35 * t) * sgn;
                pts.push(Qt.point((bx + ax * len * t - ay * w) * kx, (by + ay * len * t + ax * w) * ky));
            }
        };
        side(1, 0, 1.0001, 1 / 14);
        side(-1, 1, -0.0001, -1 / 14);
        pts.push(pts[0]);
        return pts;
    }

    component Petal: ShapePath {
        fillColor: lotus.fill
        strokeColor: lotus.stroke
        strokeWidth: lotus.lineWidth
        joinStyle: ShapePath.RoundJoin
    }

    Petal {
        PathPolyline { path: lotus.petal(-66, 8.6, 2.6) }
    }

    Petal {
        PathPolyline { path: lotus.petal(66, 8.6, 2.6) }
    }

    Petal {
        PathPolyline { path: lotus.petal(-33, 11.2, 3.0) }
    }

    Petal {
        PathPolyline { path: lotus.petal(33, 11.2, 3.0) }
    }

    Petal {
        PathPolyline { path: lotus.petal(0, 13.2, 3.4) }
    }

    // The base the petals rise from.
    ShapePath {
        fillColor: "transparent"
        strokeColor: lotus.stroke
        strokeWidth: lotus.lineWidth
        capStyle: ShapePath.RoundCap
        startX: 5 * lotus.kx
        startY: 14.4 * lotus.ky

        PathQuad {
            x: 19 * lotus.kx
            y: 14.4 * lotus.ky
            controlX: 12 * lotus.kx
            controlY: 17 * lotus.ky
        }
    }
}
