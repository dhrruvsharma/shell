pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.colors
import qs.services as Services

// The bar as one strip (services/BarSettings, style "strip"): a band of the
// containers' colour the length of the bar, flush to the screen's edge,
// and with the panels that come out of it (components/StripDrawer) one
// surface. Its shape is the desktop theme's (services/StripShape): at its
// ends it turns down into the screen's sides, and where a panel comes out
// of it it turns down into the panel's sides, through fillets that are
// curves for the round themes, cuts for HUD, Neon Noir and Sekiro, steps
// for Art Deco, and none for Mainframe, Broadsheet and Siege. The theme's
// hairline (or the bar's outline, when that's on) runs along its inner
// edge and down every fillet, and the panel takes it on from there; along
// the straight stretches between run the theme's rules, graduation, temple
// border, light or battlements, and Wasteland bolts its ends.
//
// Floating (services/BarSettings, style "floating") it's a pill of its own,
// this item its box: its ends don't reach the screen's sides, its four
// corners are the theme's (StripShape.ends) and the hairline goes all the
// way round it. Panels still come out of its inner edge through fillets;
// one against either end runs straight on down from the pill's end.
//
// It draws past its own edge by StripShape.overhang (the bar's surface is
// that much deeper): the fillets hang below the inner edge. It's built
// lying along the top of the screen and turned onto its edge (`edge`).
Item {
    id: band

    property string edge: Services.BarLayout.edge
    property color fill: Services.StripShape.band
    // The panels coming out of it: the live ones on the bar; the
    // customizer's pictures of it pass none. `origin` is where the band
    // starts along the bar, on the screen.
    property var joins: Services.StripShape.joins
    property real origin: 0
    // Its ends turning down into the screen's sides.
    property bool ends: true
    // A pill of its own (see above).
    property bool floating: Services.StripShape.floating

    readonly property bool vertical: band.edge === "left" || band.edge === "right"
    readonly property var style: Services.StripShape.style
    readonly property color line: Services.StripShape.line
    readonly property bool lined: Services.StripShape.lined
    readonly property string trim: band.style.trim

    // Lying along the top: x runs along the bar, y from the screen's edge
    // (0) to the inner edge (t).
    readonly property real l: band.vertical ? band.height : band.width
    readonly property real t: band.vertical ? band.width : band.height

    // The panels out of it, in band coordinates, those that touch merged:
    // [{ from, to, r, end }], `r` the fillets' size either side.
    readonly property var spans: {
        const out = [];
        for (const j of band.joins) {
            const r = Services.StripShape.filletOf(j.depth);
            const s = { from: j.from - band.origin, to: j.to - band.origin, r: r, start: j.start || j.from - band.origin <= 0.5, end: j.end || j.to - band.origin >= band.l - 0.5 };
            if (s.to <= 0 || s.from >= band.l || j.depth <= 0)
                continue;
            const last = out[out.length - 1];
            if (last && s.from - s.r <= last.to + last.r) {
                last.to = Math.max(last.to, s.to);
                last.r = Math.max(last.r, s.r);
                last.end = last.end || s.end;
                last.start = last.start || s.start;
            } else {
                out.push(s);
            }
        }
        return out;
    }
    // The ends' fillets: none where a panel lies against that end, or
    // comes out of the strip too near it for both.
    readonly property real endR: band.ends ? band.style.r : 0
    readonly property bool endSpan: band.spans.some(s => s.end)
    readonly property real leftR: band.spans.length > 0 && band.spans[0].from - band.spans[0].r < band.endR ? 0 : band.endR
    readonly property real rightR: band.spans.some(s => s.end || s.to + s.r > band.l - band.endR) ? 0 : band.endR
    // Floating: its corners, clockwise from the start of its outer edge
    // (none it's too thin or short for), and whether a panel lies against
    // either end.
    readonly property var corners: Services.StripShape.ends.map(e => band.floating ? Math.max(0, Math.min(e, band.t / 2, band.l / 2)) : 0)
    readonly property bool flushLeft: band.spans.length > 0 && band.spans[0].start
    readonly property bool flushRight: band.endSpan
    // Floating along the top of the screen, Siege's battlements stand on
    // its outer edge, as on a wall, rather than hang from the inner one.
    readonly property bool crowned: band.floating && band.edge === "top"

    // The band and its fillets, as one outline.
    readonly property string fillPath: {
        const S = Services.StripShape, k = band.style.fillet, l = band.l, t = band.t;
        const ck = band.style.corner, c = band.corners;
        let s;
        if (band.floating) {
            // Along the outer edge and down the far end.
            s = "M " + c[0] + " 0 L " + (l - c[1]) + " 0" + S.turn(ck, { x: l - c[1], y: 0 }, { x: l, y: 0 }, { x: l, y: c[1] });
            if (band.flushRight)
                s += " L " + l + " " + t;
            else
                s += " L " + l + " " + (t - c[2]) + S.turn(ck, { x: l, y: t - c[2] }, { x: l, y: t }, { x: l - c[2], y: t });
        } else {
            s = "M -1 -1 L " + (l + 1) + " -1";
            if (band.rightR > 0)
                s += " L " + (l + 1) + " " + (t + band.rightR) + " L " + l + " " + (t + band.rightR)
                    + S.turn(k, { x: l, y: t + band.rightR }, { x: l, y: t }, { x: l - band.rightR, y: t });
            else
                s += " L " + (l + 1) + " " + t;
        }
        for (let i = band.spans.length - 1; i >= 0; i--) {
            const j = band.spans[i], r = j.r;
            if (!j.end)
                s += " L " + (j.to + r) + " " + t + S.turn(k, { x: j.to + r, y: t }, { x: j.to, y: t }, { x: j.to, y: t + r }) + " L " + j.to + " " + t;
            s += " L " + j.from + " " + t;
            if (!j.start)
                s += " L " + j.from + " " + (t + r) + S.turn(k, { x: j.from, y: t + r }, { x: j.from, y: t }, { x: j.from - r, y: t });
        }
        if (band.floating) {
            // Up the near end and round to where it began.
            if (band.flushLeft)
                s += " L 0 " + t;
            else
                s += " L " + c[3] + " " + t + S.turn(ck, { x: c[3], y: t }, { x: 0, y: t }, { x: 0, y: t - c[3] });
            return s + " L 0 " + c[0] + S.turn(ck, { x: 0, y: c[0] }, { x: 0, y: 0 }, { x: c[0], y: 0 }) + " Z";
        }
        if (band.leftR > 0)
            s += " L " + band.leftR + " " + t + S.turn(k, { x: band.leftR, y: t }, { x: 0, y: t }, { x: 0, y: t + band.leftR })
                + " L -1 " + (t + band.leftR);
        else
            s += " L -1 " + t;
        return s + " Z";
    }

    // Its inner edge between the fillets: [[from, to]], for the trim.
    readonly property var stretches: {
        const out = [];
        let a = band.floating ? (band.flushLeft ? 0 : band.corners[3]) : band.leftR;
        for (const j of band.spans) {
            out.push([a, j.from - j.r]);
            a = j.to + j.r;
        }
        if (!band.endSpan)
            out.push([a, band.l - (band.floating ? band.corners[2] : band.rightR)]);
        return out.filter(p => p[1] - p[0] > 1);
    }

    // The hairline: along the inner edge, down each fillet to where a
    // panel takes it on, and down the ends into the screen's sides.
    // Floating, all the way round the pill instead (the filled side is to
    // the left of the way a run goes: along the inner edge, up the far end,
    // back along the outer edge and down the near end), broken only where
    // a panel is out.
    readonly property string linePath: {
        if (!band.lined)
            return "";
        const S = Services.StripShape, k = band.style.fillet, l = band.l, t = band.t;
        const runs = [];
        if (band.floating) {
            const ck = band.style.corner, c = band.corners, n = band.spans.length;
            // Where the line leaves the inner edge for a panel's side, and
            // comes back to it past the panel (a square shoulder's line
            // covers the corner, as below).
            const leave = j => j.r >= 0.5 ? [{ x: j.from, y: t, kind: k, size: j.r }, { x: j.from, y: t + j.r }] : [{ x: j.from + 1, y: t }];
            const rejoin = j => j.r >= 0.5 ? [{ x: j.to, y: t + j.r }, { x: j.to, y: t, kind: k, size: j.r }] : [{ x: j.to - 1, y: t }];
            const outer = [{ x: l, y: 0, kind: ck, size: c[1] }, { x: 0, y: 0, kind: ck, size: c[0] }];
            if (n === 0)
                return S.trace([{ x: l / 2, y: t }, { x: l, y: t, kind: ck, size: c[2] }]
                    .concat(outer, [{ x: 0, y: t, kind: ck, size: c[3] }, { x: l / 2, y: t }]), 0.5);
            for (let i = 0; i < n - 1; i++)
                runs.push(rejoin(band.spans[i]).concat(leave(band.spans[i + 1])));
            // From the last panel round the pill to the first: a panel
            // against an end takes the line on from the pill's end itself.
            const first = band.spans[0], last = band.spans[n - 1];
            const round = (last.end ? [{ x: l, y: t }] : rejoin(last).concat([{ x: l, y: t, kind: ck, size: c[2] }]))
                .concat(outer, first.start ? [{ x: 0, y: t }] : [{ x: 0, y: t, kind: ck, size: c[3] }].concat(leave(first)));
            runs.push(round);
            return runs.map(r => S.trace(r, 0.5)).join(" ");
        }
        let run = band.leftR > 0 ? [{ x: 0, y: t + band.leftR }, { x: 0, y: t, kind: k, size: band.leftR }] : [{ x: -1, y: t }];
        for (const j of band.spans) {
            // (A panel in the corner at the start takes the line on from
            // the screen's side itself.)
            if (j.start) {
            } else if (j.r >= 0.5) {
                run.push({ x: j.from, y: t, kind: k, size: j.r }, { x: j.from, y: t + j.r });
                runs.push(run);
            } else {
                // A square shoulder: the line covers the corner, the panel's
                // side goes down from under it.
                run.push({ x: j.from + 1, y: t });
                runs.push(run);
            }
            run = null;
            if (j.end)
                break;
            run = j.r >= 0.5 ? [{ x: j.to, y: t + j.r }, { x: j.to, y: t, kind: k, size: j.r }] : [{ x: j.to - 1, y: t }];
        }
        if (run) {
            if (band.rightR > 0)
                run.push({ x: l, y: t, kind: k, size: band.rightR }, { x: l, y: t + band.rightR });
            else
                run.push({ x: l + 1, y: t });
            runs.push(run);
        }
        return runs.map(r => S.trace(r, 0.5)).join(" ");
    }

    Item {
        id: flat

        width: band.l
        height: band.t
        // Onto its edge: the top as it is, the bottom mirrored, the sides
        // turned (x and y swapped, and the right one mirrored).
        transform: Matrix4x4 {
            matrix: band.edge === "bottom" ? Qt.matrix4x4(1, 0, 0, 0, 0, -1, 0, band.t, 0, 0, 1, 0, 0, 0, 0, 1)
                : band.edge === "left" ? Qt.matrix4x4(0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                : band.edge === "right" ? Qt.matrix4x4(0, -1, 0, band.t, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                : Qt.matrix4x4(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: band.fill
                strokeColor: "transparent"
                strokeWidth: 0

                PathSvg {
                    path: band.fillPath
                }
            }
        }

        // The theme's trim along the straight stretches.
        Loader {
            anchors.fill: parent
            sourceComponent: ({
                rules: rulesTrim,
                ticks: ticksTrim,
                temple: templeTrim,
                lume: lumeTrim,
                rivets: rivetsTrim,
                merlons: merlonsTrim,
                gauge: gaugeTrim
            })[band.trim] ?? null
        }

        Shape {
            anchors.fill: parent
            visible: band.lined
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: band.line
                strokeWidth: 1
                capStyle: ShapePath.FlatCap
                joinStyle: ShapePath.MiterJoin

                PathSvg {
                    path: band.linePath
                }
            }
        }
    }

    // Broadsheet: a thin rule over the heavy one the hairline makes, as
    // under a masthead.
    Component {
        id: rulesTrim

        Item {
            Repeater {
                model: band.stretches

                Item {
                    id: rules

                    required property var modelData

                    Rectangle {
                        x: rules.modelData[0]
                        y: band.t - 2
                        width: rules.modelData[1] - rules.modelData[0]
                        height: 2
                        color: band.line
                    }

                    Rectangle {
                        x: rules.modelData[0]
                        y: band.t - 5
                        width: rules.modelData[1] - rules.modelData[0]
                        height: 1
                        color: band.line
                    }
                }
            }
        }
    }

    // Observatory: graduated along the stretches, like an instrument's limb.
    Component {
        id: ticksTrim

        Item {
            Repeater {
                model: band.stretches

                ScaleTicks {
                    required property var modelData
                    x: modelData[0] + 4
                    y: band.t - height - 1
                    width: Math.max(0, modelData[1] - modelData[0] - 8)
                    height: 4
                    up: true
                    step: 5
                    major: 5
                    minorLength: 1.5
                    majorLength: 3.5
                    color: band.line
                    opacity: 0.75
                }
            }
        }
    }

    // Devaloka: a temple border standing on the inner edge.
    Component {
        id: templeTrim

        Item {
            Repeater {
                model: band.stretches

                TempleBorder {
                    required property var modelData
                    x: modelData[0] + 2
                    y: band.t - height - 1
                    width: Math.max(0, modelData[1] - modelData[0] - 4)
                    height: 4.5
                    step: 6
                    rule: 0
                    color: band.line
                    opacity: 0.85
                }
            }
        }
    }

    // Abyss: light along the inner edge, as under a backlit key, fading out
    // at the ends of each stretch.
    Component {
        id: lumeTrim

        Item {
            Repeater {
                model: band.stretches

                Rectangle {
                    required property var modelData
                    x: modelData[0]
                    y: band.t - 6
                    width: modelData[1] - modelData[0]
                    height: 5
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Colors.withAlpha(Services.DesktopTheme.accent2, 0) }
                        GradientStop { position: 0.5; color: Colors.withAlpha(Services.DesktopTheme.accent2, 0.13) }
                        GradientStop { position: 1; color: Colors.withAlpha(Services.DesktopTheme.accent2, 0) }
                    }
                }
            }
        }
    }

    // Wasteland: bolted at its ends.
    Component {
        id: rivetsTrim

        Item {
            Repeater {
                model: 4

                Rivet {
                    required property int index
                    size: 4
                    x: index % 2 === 0 ? 8 : band.l - width - 8
                    y: index < 2 ? 6 : band.t - height - 6
                }
            }
        }
    }

    // Siege: battlements hanging from the inner edge along the stretches
    // (the lower edge of a bar along the top; standing on the upper one of
    // a bar along the bottom), or standing along the outer edge (`crowned`).
    Component {
        id: merlonsTrim

        Item {
            Repeater {
                model: band.crowned ? [[band.corners[0], band.l - band.corners[1]]] : band.stretches

                Item {
                    id: run

                    required property var modelData
                    readonly property real pitch: 26
                    readonly property int count: Math.max(0, Math.floor((modelData[1] - modelData[0] - 12) / run.pitch))

                    Repeater {
                        model: run.count

                        Rectangle {
                            required property int index
                            x: run.modelData[0] + (run.modelData[1] - run.modelData[0] - run.count * run.pitch) / 2 + index * run.pitch + 7
                            y: band.crowned ? -4 : band.t - 1
                            width: 12
                            height: 5
                            color: band.fill
                            border.width: band.lined ? 1 : 0
                            border.color: band.line
                        }
                    }
                }
            }
        }
    }

    // Sekiro: the gauge's tick at the middle of the inner edge.
    Component {
        id: gaugeTrim

        Item {
            readonly property real mid: band.l / 2

            Rectangle {
                visible: band.stretches.some(p => p[0] < parent.mid - 6 && p[1] > parent.mid + 6)
                x: parent.mid - width / 2
                y: band.t - height / 2 - 1
                width: 6
                height: 6
                rotation: 45
                antialiasing: true
                color: Services.DesktopTheme.accent
            }
        }
    }
}
