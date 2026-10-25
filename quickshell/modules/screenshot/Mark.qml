pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

// One mark on a screenshot, in the image's own pixels: it covers the whole
// image and draws where its points say. The marks are plain objects:
//
//   pen, marker           { pts: [x0, y0, x1, y1, …] }  a stroke (the marker's
//                                                       goes on see-through,
//                                                       Sheet's doing)
//   line, arrow           { x1, y1, x2, y2 }
//   rect, ellipse         { x1, y1, x2, y2, fill }      outlined, or filled
//   pixelate              { x1, y1, x2, y2 }            the image in blocks
//                                                       `size` pixels across
//   counter               { x, y }                      a numbered dot
//   text                  { x, y, text, fill }          on a label if filled
//
// each with an id, a kind, a color and a size (the stroke's width, the
// dot's radius, the text's pixel size). `hit` and `bounds` serve the
// select tool.
Item {
    id: root

    property var mark: null
    // A counter's number.
    property int number: 1
    // The image, which a pixelated patch is cut from.
    property url source
    property real imageWidth
    property real imageHeight
    // Drawn this far over while it's dragged.
    property real shiftX: 0
    property real shiftY: 0

    readonly property string kind: mark ? mark.kind : ""
    readonly property string fontFamily: "Adwaita Sans"

    // The two corners' box (rect, ellipse, pixelate).
    readonly property rect box: mark && mark.x1 !== undefined ? Qt.rect(Math.min(mark.x1, mark.x2), Math.min(mark.y1, mark.y2), Math.abs(mark.x2 - mark.x1), Math.abs(mark.y2 - mark.y1)) : Qt.rect(0, 0, 0, 0)

    // An arrow's head: how long, and how wide either side of the shaft.
    readonly property real length: mark && mark.x1 !== undefined ? Math.hypot(mark.x2 - mark.x1, mark.y2 - mark.y1) : 0
    readonly property real head: kind === "arrow" ? Math.min(Math.max(14, mark.size * 4.5), length * 0.75) : 0
    readonly property real wing: head * 0.55

    // A stroke's points smoothed into curves through their midpoints.
    readonly property string strokePath: {
        const p = mark && mark.pts ? mark.pts : [];
        const n = p.length / 2;
        if (n < 2)
            return "";
        const f = v => v.toFixed(1);
        let d = "M " + f(p[0]) + " " + f(p[1]);
        if (n === 2)
            return d + " L " + f(p[2]) + " " + f(p[3]);
        for (let i = 1; i < n - 1; i++)
            d += " Q " + f(p[2 * i]) + " " + f(p[2 * i + 1]) + " " + f((p[2 * i] + p[2 * i + 2]) / 2) + " " + f((p[2 * i + 1] + p[2 * i + 3]) / 2);
        return d + " L " + f(p[2 * n - 2]) + " " + f(p[2 * n - 1]);
    }

    // What it covers, in image pixels (where it was, while dragged).
    readonly property rect bounds: {
        const m = mark;
        if (!m)
            return Qt.rect(0, 0, 0, 0);
        switch (m.kind) {
        case "pen":
        case "marker":
            {
                let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
                for (let i = 0; i + 1 < m.pts.length; i += 2) {
                    x0 = Math.min(x0, m.pts[i]);
                    x1 = Math.max(x1, m.pts[i]);
                    y0 = Math.min(y0, m.pts[i + 1]);
                    y1 = Math.max(y1, m.pts[i + 1]);
                }
                const r = m.size / 2;
                return Qt.rect(x0 - r, y0 - r, x1 - x0 + 2 * r, y1 - y0 + 2 * r);
            }
        case "line":
        case "arrow":
            {
                const r = Math.max(m.size / 2, wing);
                return Qt.rect(Math.min(m.x1, m.x2) - r, Math.min(m.y1, m.y2) - r, Math.abs(m.x2 - m.x1) + 2 * r, Math.abs(m.y2 - m.y1) + 2 * r);
            }
        case "counter":
            return Qt.rect(m.x - m.size, m.y - m.size, 2 * m.size, 2 * m.size);
        case "text":
            return Qt.rect(m.x, m.y, (shape.item as Item)?.width ?? 0, (shape.item as Item)?.height ?? 0);
        default:
            return box;
        }
    }

    x: shiftX
    y: shiftY
    width: imageWidth
    height: imageHeight

    // Whether the point is on it, give or take `tol` pixels.
    function hit(px: real, py: real, tol: real): bool {
        const m = mark;
        if (!m)
            return false;
        switch (m.kind) {
        case "pen":
        case "marker":
            {
                const p = m.pts;
                const reach = m.size / 2 + tol;
                if (p.length === 2)
                    return Math.hypot(px - p[0], py - p[1]) <= reach;
                for (let i = 0; i + 3 < p.length; i += 2) {
                    if (segment(px, py, p[i], p[i + 1], p[i + 2], p[i + 3]) <= reach)
                        return true;
                }
                return false;
            }
        case "line":
        case "arrow":
            return segment(px, py, m.x1, m.y1, m.x2, m.y2) <= m.size / 2 + tol || (m.kind === "arrow" && Math.hypot(px - m.x2, py - m.y2) <= head + tol);
        case "rect":
            {
                const b = box;
                if (px < b.x - tol || px > b.x + b.width + tol || py < b.y - tol || py > b.y + b.height + tol)
                    return false;
                const t = m.size + tol;
                return m.fill || !(px > b.x + t && px < b.x + b.width - t && py > b.y + t && py < b.y + b.height - t);
            }
        case "ellipse":
            {
                const b = box;
                const rx = b.width / 2, ry = b.height / 2;
                if (rx < 1 || ry < 1)
                    return false;
                const d = Math.hypot((px - b.x - rx) / rx, (py - b.y - ry) / ry);
                const r = Math.min(rx, ry);
                return m.fill ? d <= 1 + tol / r : Math.abs(d - 1) * r <= m.size + tol;
            }
        default:
            {
                const b = bounds;
                return px >= b.x - tol && px <= b.x + b.width + tol && py >= b.y - tol && py <= b.y + b.height + tol;
            }
        }
    }

    // How far a point is from the segment a–b.
    function segment(px: real, py: real, ax: real, ay: real, bx: real, by: real): real {
        const dx = bx - ax, dy = by - ay;
        const len2 = dx * dx + dy * dy;
        const t = len2 > 0 ? Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / len2)) : 0;
        return Math.hypot(px - ax - t * dx, py - ay - t * dy);
    }

    // Text that reads on a fill of `c`.
    function inkOn(c: color): color {
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b > 0.55 ? "#16130f" : "#fbf8f3";
    }

    Loader {
        id: shape
        sourceComponent: ({
                pen: strokeShape,
                marker: strokeShape,
                line: lineShape,
                arrow: lineShape,
                rect: rectShape,
                ellipse: ellipseShape,
                pixelate: pixelShape,
                counter: counterShape,
                text: textShape
            })[root.kind] ?? null
    }

    Component {
        id: strokeShape

        Shape {
            width: root.width
            height: root.height
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: root.mark.color
                strokeWidth: root.mark.size
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathSvg {
                    path: root.strokePath
                }
            }
        }
    }

    // A line, or an arrow: the shaft stops inside the head, so its round
    // end doesn't show past it.
    Component {
        id: lineShape

        Shape {
            id: line

            readonly property real ux: root.length > 0 ? (root.mark.x2 - root.mark.x1) / root.length : 1
            readonly property real uy: root.length > 0 ? (root.mark.y2 - root.mark.y1) / root.length : 0
            readonly property real baseX: root.mark.x2 - ux * root.head
            readonly property real baseY: root.mark.y2 - uy * root.head

            width: root.width
            height: root.height
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: root.mark.color
                strokeWidth: root.mark.size
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: root.mark.x1
                startY: root.mark.y1

                PathLine {
                    x: root.mark.x2 - line.ux * root.head * 0.7
                    y: root.mark.y2 - line.uy * root.head * 0.7
                }
            }

            ShapePath {
                strokeColor: "transparent"
                strokeWidth: -1
                fillColor: root.kind === "arrow" ? root.mark.color : "transparent"
                startX: root.mark.x2
                startY: root.mark.y2

                PathLine {
                    x: line.baseX - line.uy * root.wing
                    y: line.baseY + line.ux * root.wing
                }
                PathLine {
                    x: root.mark.x2 - line.ux * root.head * 0.78
                    y: root.mark.y2 - line.uy * root.head * 0.78
                }
                PathLine {
                    x: line.baseX + line.uy * root.wing
                    y: line.baseY - line.ux * root.wing
                }
                PathLine {
                    x: root.mark.x2
                    y: root.mark.y2
                }
            }
        }
    }

    Component {
        id: rectShape

        Rectangle {
            x: root.box.x
            y: root.box.y
            width: root.box.width
            height: root.box.height
            radius: Math.min(root.mark.size * 0.8, width / 2, height / 2)
            color: root.mark.fill ? root.mark.color : "transparent"
            border.width: root.mark.fill ? 0 : root.mark.size
            border.color: root.mark.color
            antialiasing: true
        }
    }

    Component {
        id: ellipseShape

        Shape {
            id: ellipse

            readonly property real inset: root.mark.fill ? 0 : root.mark.size / 2

            width: root.width
            height: root.height
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: root.mark.fill ? "transparent" : root.mark.color
                strokeWidth: root.mark.fill ? -1 : root.mark.size
                fillColor: root.mark.fill ? root.mark.color : "transparent"

                PathAngleArc {
                    centerX: root.box.x + root.box.width / 2
                    centerY: root.box.y + root.box.height / 2
                    radiusX: Math.max(0.5, root.box.width / 2 - ellipse.inset)
                    radiusY: Math.max(0.5, root.box.height / 2 - ellipse.inset)
                    startAngle: 0
                    sweepAngle: 360
                }
            }
        }
    }

    // The image again, shrunk to one pixel per block and blown back up
    // without smoothing, seen through the box. Loaded before it's shown (a
    // patch saved before its blocks came in would give the secret away).
    Component {
        id: pixelShape

        Item {
            x: root.box.x
            y: root.box.y
            width: root.box.width
            height: root.box.height
            clip: true

            Image {
                x: -parent.x
                y: -parent.y
                width: root.imageWidth
                height: root.imageHeight
                source: root.source
                sourceSize: Qt.size(Math.max(1, Math.round(root.imageWidth / root.mark.size)), Math.max(1, Math.round(root.imageHeight / root.mark.size)))
                smooth: false
                cache: false
                asynchronous: false
            }
        }
    }

    Component {
        id: counterShape

        Item {
            x: root.mark.x - root.mark.size
            y: root.mark.y - root.mark.size
            width: root.mark.size * 2
            height: width

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: root.mark.color
                border.width: Math.max(1.5, root.mark.size * 0.12)
                border.color: Qt.alpha(root.inkOn(root.mark.color), 0.9)
                antialiasing: true
            }

            Text {
                anchors.centerIn: parent
                text: root.number
                font.family: root.fontFamily
                font.pixelSize: Math.max(6, Math.round(root.mark.size * 1.1))
                font.weight: Font.Bold
                color: root.inkOn(root.mark.color)
            }
        }
    }

    // Text, with an edge in the other ink so it reads on any picture; on a
    // label of its colour when filled.
    Component {
        id: textShape

        Item {
            readonly property real pad: Math.round(root.mark.size * 0.3)

            x: root.mark.x
            y: root.mark.y
            width: label.implicitWidth + 2 * pad
            height: label.implicitHeight + 2 * pad

            Rectangle {
                visible: !!root.mark.fill
                anchors.fill: parent
                radius: parent.pad
                color: root.mark.color
                antialiasing: true
            }

            Text {
                id: label
                x: parent.pad
                y: parent.pad
                text: root.mark.text
                textFormat: Text.PlainText
                font.family: root.fontFamily
                font.pixelSize: Math.max(6, Math.round(root.mark.size))
                font.weight: Font.DemiBold
                color: root.mark.fill ? root.inkOn(root.mark.color) : root.mark.color
                style: root.mark.fill ? Text.Normal : Text.Outline
                styleColor: Qt.alpha(root.inkOn(root.mark.color), 0.55)
            }
        }
    }
}
