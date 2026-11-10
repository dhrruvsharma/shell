pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.colors
import qs.services as Services

// A panel coming out of the bar while it's one strip (services/StripShape):
// its body, from the strip's inner edge out, in the strip's colour, its
// free corners as the desktop theme has them and the strip's hairline on
// round it. While it's out it tells StripShape where it joins the strip,
// and the strip (components/StripBand) draws the fillets either side and
// brings its hairline down them to where this takes it on: the two are
// surfaces of their own, but read as one.
//
// It fills its parent (the panel). `edge` is the panel's side against the
// bar; `inset` is how much of it the strip covers (a panel laid out on the
// whole screen starts under the strip; one in a window of its own, at the
// strip's inner edge); `start` and `stop` keep its body that far in from
// the panel's ends along the bar. `atEnd`: it lies against the bar's far
// end (the right end of a lying bar, the bottom of a standing one), joined
// to the screen's side there by a fillet of its own in the `foot` it keeps
// below its body; `atStart`, the same at the bar's start (the left end, or
// the top). `origin` is where its window lies on the screen.
Item {
    id: drawer

    // What it's called in StripShape.joins; "" reports nothing.
    property string key: ""
    property string edge: Services.BarLayout.edge
    property real inset: Services.BarLayout.size
    property real start: 0
    property real stop: 0
    property bool atEnd: false
    property bool atStart: false
    property real foot: 0
    property point origin: Qt.point(0, 0)
    property color fill: Services.StripShape.panel
    // Whether it reports its joint (it does while it shows).
    property bool joined: drawer.visible

    readonly property bool vertical: drawer.edge === "left" || drawer.edge === "right"
    readonly property var style: Services.StripShape.style

    // Its place on the screen, along the bar: its parents' offsets added
    // up (bindings to each, so it follows the panel as it's moved).
    readonly property real along: {
        let x = drawer.origin.x, y = drawer.origin.y;
        for (let p = drawer; p; p = p.parent) {
            x += p.x;
            y += p.y;
        }
        return drawer.vertical ? y : x;
    }

    // Lying along the top (see StripShape): its length along the bar, its
    // depth away from the edge, and its body's.
    readonly property real l: drawer.vertical ? drawer.height : drawer.width
    readonly property real d: drawer.vertical ? drawer.width : drawer.height
    // The body's ends along the bar, on whole pixels of the screen, as the
    // strip's fillets are.
    readonly property real a: drawer.atStart ? 0 : Math.round(drawer.along + drawer.start) - drawer.along
    readonly property real b: drawer.atEnd ? drawer.l : Math.round(drawer.along + drawer.l - drawer.stop) - drawer.along
    readonly property real reach: drawer.d - drawer.foot
    readonly property real depth: Math.max(0, drawer.reach - drawer.inset)
    // The strip's fillets at its top, its own corners, and (at the bar's
    // end) the fillet into the screen's side.
    readonly property real r: Services.StripShape.filletOf(drawer.depth)
    readonly property real c: Math.max(0, Math.min(drawer.style.c, (drawer.b - drawer.a) / 2, drawer.depth - drawer.r))
    readonly property real r2: drawer.atEnd || drawer.atStart ? Math.max(0, Math.min(drawer.style.r, drawer.foot, (drawer.b - drawer.a) / 2)) : 0
    readonly property bool out: drawer.depth > 0.5 && drawer.b - drawer.a > 1

    readonly property string fillPath: {
        if (!drawer.out)
            return "";
        const S = Services.StripShape, ck = drawer.style.corner, t = drawer.inset, a = drawer.a, b = drawer.b, y = drawer.reach, c = drawer.c;
        let s = "M " + a + " " + t + " L " + b + " " + t;
        if (drawer.atEnd) {
            const r2 = drawer.r2;
            s += " L " + b + " " + (y + r2) + S.turn(drawer.style.fillet, { x: b, y: y + r2 }, { x: b, y: y }, { x: b - r2, y: y });
        } else {
            s += " L " + b + " " + (y - c) + S.turn(ck, { x: b, y: y - c }, { x: b, y: y }, { x: b - c, y: y });
        }
        if (drawer.atStart) {
            const r2 = drawer.r2;
            s += " L " + (a + r2) + " " + y + S.turn(drawer.style.fillet, { x: a + r2, y: y }, { x: a, y: y }, { x: a, y: y + r2 });
        } else {
            s += " L " + (a + c) + " " + y + S.turn(ck, { x: a + c, y: y }, { x: a, y: y }, { x: a, y: y - c });
        }
        return s + " Z";
    }

    readonly property string linePath: {
        if (!drawer.out || !Services.StripShape.lined)
            return "";
        const t = drawer.inset, a = drawer.a, b = drawer.b, y = drawer.reach, top = t + drawer.r;
        const pts = drawer.atStart ? [{ x: a, y: y + drawer.r2 }, { x: a, y: y, kind: drawer.style.fillet, size: drawer.r2 }]
            : [{ x: a, y: top }, { x: a, y: y, kind: drawer.style.corner, size: drawer.c }];
        if (drawer.atEnd)
            pts.push({ x: b, y: y, kind: drawer.style.fillet, size: drawer.r2 }, { x: b, y: y + drawer.r2 });
        else
            pts.push({ x: b, y: y, kind: drawer.style.corner, size: drawer.c }, { x: b, y: top });
        return Services.StripShape.trace(pts, 0.5);
    }

    anchors.fill: parent

    // Where it joins the strip, while it's out, reported under its key
    // (and withdrawn under the key it was reported under, whatever the key
    // is by then).
    readonly property var joint: drawer.key !== "" && drawer.joined && drawer.out
        ? { from: drawer.along + drawer.a, to: drawer.along + drawer.b, depth: drawer.depth, start: drawer.atStart, end: drawer.atEnd } : null
    property string _reported: ""

    function _report() {
        if (drawer._reported !== "" && (!drawer.joint || drawer._reported !== drawer.key)) {
            Services.StripShape.part(drawer._reported);
            drawer._reported = "";
        }
        if (drawer.joint) {
            Services.StripShape.join(drawer.key, drawer.joint.from, drawer.joint.to, drawer.joint.depth, drawer.joint.start, drawer.joint.end);
            drawer._reported = drawer.key;
        }
    }

    onJointChanged: drawer._report()
    onKeyChanged: drawer._report()
    Component.onCompleted: drawer._report()
    Component.onDestruction: if (drawer._reported !== "") Services.StripShape.part(drawer._reported)

    Item {
        id: flat

        width: drawer.l
        height: drawer.d
        transform: Matrix4x4 {
            matrix: drawer.edge === "bottom" ? Qt.matrix4x4(1, 0, 0, 0, 0, -1, 0, drawer.height, 0, 0, 1, 0, 0, 0, 0, 1)
                : drawer.edge === "left" ? Qt.matrix4x4(0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                : drawer.edge === "right" ? Qt.matrix4x4(0, -1, 0, drawer.width, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                : Qt.matrix4x4(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: drawer.fill
                strokeColor: "transparent"
                strokeWidth: 0

                PathSvg {
                    path: drawer.fillPath
                }
            }
        }

        Shape {
            anchors.fill: parent
            visible: Services.StripShape.lined
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: Services.StripShape.line
                strokeWidth: 1
                capStyle: ShapePath.FlatCap
                joinStyle: ShapePath.MiterJoin

                PathSvg {
                    path: drawer.linePath
                }
            }
        }
    }
}
