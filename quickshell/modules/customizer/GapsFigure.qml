pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.colors
import qs.services as Services

// The plate for the windows' gaps, borders and corners: the whole screen
// as Hyprland would tile it, and a detail where the windows meet under the
// bar, magnified, with the gaps, the border and the corner's radius
// measured on it. The one pointed at on the facing page is lit.
Item {
    id: fig

    property string lit: ""

    readonly property real overW: Math.min(fig.width - 60, 470)
    readonly property real overZoom: fig.overW / 1920
    readonly property real lensD: 236
    readonly property real lensZoom: 2.4

    // ── The whole screen ─────────────────────────────────────────────────────
    WindowScene {
        id: overview
        x: 0
        y: 6
        width: fig.overW
        height: 1200 * fig.overZoom
        zoom: fig.overZoom
        lit: fig.lit
    }

    Rectangle {
        anchors.fill: overview
        anchors.margins: -1
        color: "transparent"
        border.width: 1
        border.color: BookStyle.line
    }

    // Where the detail is taken from, ringed.
    Rectangle {
        id: spot
        readonly property real r: fig.lensD / 2 / fig.lensZoom * fig.overZoom
        x: overview.x + overview.split * fig.overZoom - r
        y: overview.y + (Services.BarLayout.reserveTop + 18) * fig.overZoom - r
        width: 2 * r
        height: 2 * r
        radius: r
        color: "transparent"
        border.width: 1.5
        border.color: BookStyle.accent
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: BookStyle.accent
            strokeWidth: 1
            fillColor: "transparent"
            strokeStyle: ShapePath.DashLine
            dashPattern: [3, 3]
            startX: spot.x + spot.width / 2 + spot.r * 0.7
            startY: spot.y + spot.height / 2 + spot.r * 0.7

            PathLine {
                x: lens.x + lens.width * 0.15
                y: lens.y + lens.height * 0.15
            }
        }
    }

    // ── The detail, magnified ────────────────────────────────────────────────
    Item {
        id: lens
        x: fig.width - fig.lensD - 4
        y: Math.min(overview.y + overview.height - fig.lensD * 0.42, fig.height - fig.lensD - 8)
        width: fig.lensD
        height: fig.lensD

        Rectangle {
            anchors.fill: parent
            anchors.margins: -6
            radius: width / 2
            color: BookStyle.paper
            border.width: 1
            border.color: BookStyle.line
        }

        Item {
            id: glass
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: lensMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            WindowScene {
                id: detail
                anchors.fill: parent
                zoom: fig.lensZoom
                origin: Qt.point(overview.split - fig.lensD / 2 / fig.lensZoom, Services.BarLayout.reserveTop + 18 - fig.lensD / 2 / fig.lensZoom)
                lit: fig.lit
            }

            Measures {
                anchors.fill: parent
            }
        }

        Rectangle {
            id: lensMask
            anchors.fill: parent
            radius: width / 2
            visible: false
            layer.enabled: true
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: BookStyle.accent
        }

        BookText {
            anchors.right: parent.left
            anchors.rightMargin: 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            text: "Detail, × " + fig.lensZoom.toFixed(1)
            font.italic: true
            font.pixelSize: 12
            color: BookStyle.inkSoft
        }
    }

    // The measures on the detail: gaps, border, corner.
    component Measures: Item {
        id: m

        readonly property var d: detail
        readonly property real gapL: d.sx(d.split - d.gapsIn)
        readonly property real gapR: d.sx(d.split + d.gapsIn)
        readonly property real barY: d.sy(Services.BarLayout.reserveTop)
        readonly property real topY: d.sy(d.y0)

        // Between the windows.
        Dim {
            lit: fig.lit === "general.gaps_in"
            x1: m.gapL
            x2: m.gapR
            y1: m.topY + 70
            y2: m.topY + 70
            label: d.gapsIn > 0 ? "2 × " + Math.round(d.gapsIn) : "0"
            labelX: m.gapR + 6
            labelY: m.topY + 60
        }

        // Down from the bar to the windows.
        Dim {
            lit: fig.lit === "general.gaps_out"
            x1: m.gapR + 46
            x2: m.gapR + 46
            y1: m.barY
            y2: m.topY
            label: Math.round(d.gapsOut) + " px"
            labelX: m.gapR + 52
            labelY: (m.barY + m.topY) / 2 - 8
        }

        // The border, and the corner's radius.
        BookText {
            visible: d.border > 0
            x: m.gapR + 4
            y: m.topY + 104
            text: "border " + Math.round(d.border) + " px"
            font.pixelSize: 11
            font.italic: true
            style: Text.Outline
            styleColor: Colors.withAlpha("#000000", 0.6)
            color: fig.lit === "general.border_size" ? BookStyle.accent : "#ffffff"
        }

        BookText {
            x: m.gapL - width - 6
            y: m.topY + 6
            text: "r " + Math.round(d.rounding)
            font.pixelSize: 11
            font.italic: true
            style: Text.Outline
            styleColor: Colors.withAlpha("#000000", 0.6)
            color: fig.lit === "decoration.rounding" || fig.lit === "decoration.rounding_power" ? BookStyle.accent : "#ffffff"
        }
    }

    // A dimension line between two points, arrowed, with its figure.
    component Dim: Item {
        id: dim

        property bool lit: false
        property real x1
        property real y1
        property real x2
        property real y2
        property string label
        property real labelX
        property real labelY

        anchors.fill: parent

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: dim.lit ? BookStyle.accent : "#ffffff"
                strokeWidth: dim.lit ? 2 : 1.2
                fillColor: "transparent"
                startX: dim.x1
                startY: dim.y1

                PathLine {
                    x: dim.x2
                    y: dim.y2
                }
            }
        }

        BookText {
            x: dim.labelX
            y: dim.labelY
            text: dim.label
            font.pixelSize: 12
            font.weight: Font.DemiBold
            style: Text.Outline
            styleColor: Colors.withAlpha("#000000", 0.6)
            color: dim.lit ? BookStyle.accent : "#ffffff"
        }
    }
}
