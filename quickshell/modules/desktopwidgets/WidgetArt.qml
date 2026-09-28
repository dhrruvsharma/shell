pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.colors
import qs.components
import qs.modules.lock
import qs.services as Services

// Album art cut to a desktop theme's shape (WidgetStyle.art), with a
// placeholder note when there is none. Neon Noir's is cut at a corner and
// splits into its two neons; Wabi-sabi's is a faded pebble; Art Deco's
// steps in at the corners inside a gold rule; Cathedral's is a leaded
// lancet; Broadsheet prints it in halftone; Wasteland's is a faded photo
// taped up at two corners.
Item {
    id: art

    property string themeId
    property string source
    readonly property var st: WidgetStyle.of(themeId)
    readonly property color accent: WidgetStyle.accent(themeId)
    readonly property real radius: st.art === "circle" ? width / 2 : st.art === "rounded" || st.art === "pebble" ? 14 : st.art === "soft" ? 12 : st.art === "seal" ? 4 : st.art === "taped" ? 2 : 0
    readonly property bool cut: ["chamfer", "neon", "deco", "arch"].includes(st.art)

    implicitWidth: 76
    implicitHeight: 76

    Rectangle {
        id: shapeMask
        anchors.fill: parent
        radius: art.radius
        topLeftRadius: art.st.art === "pebble" ? radius * Services.DesktopTheme.pebbleCorners[0] : radius
        topRightRadius: art.st.art === "pebble" ? radius * Services.DesktopTheme.pebbleCorners[1] : radius
        bottomRightRadius: art.st.art === "pebble" ? radius * Services.DesktopTheme.pebbleCorners[2] : radius
        bottomLeftRadius: art.st.art === "pebble" ? radius * Services.DesktopTheme.pebbleCorners[3] : radius
        visible: false
        layer.enabled: !art.cut
    }

    HudMask {
        id: chamferMask
        cut: 10
        active: art.st.art === "chamfer"
    }

    NeonMask {
        id: neonMask
        cut: 14
        active: art.st.art === "neon"
    }

    DecoMask {
        id: decoMask
        cut: 6
        steps: 2
        active: art.st.art === "deco"
    }

    Shape {
        id: archMask
        anchors.fill: parent
        visible: false
        layer.enabled: art.st.art === "arch"
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "white"
            strokeColor: "transparent"

            PathPolyline {
                path: ThemeShapes.arch(0, 0, art.width, art.height, art.height * 0.3)
            }
        }
    }

    // Neon Noir: the frame again in each neon, knocked out of register.
    Repeater {
        model: art.st.art === "neon" ? [{ dx: -3, dy: 3, a: false }, { dx: 3, dy: -3, a: true }] : []

        NeonFrame {
            required property var modelData
            anchors.fill: undefined
            x: modelData.dx
            y: modelData.dy
            width: art.width
            height: art.height
            cut: 14
            fill: "transparent"
            glow: 0
            stroke: modelData.a ? art.accent : Services.DesktopTheme.accent2Of(art.themeId)
            edge: stroke
            opacity: 0.6
        }
    }

    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: ({ chamfer: chamferMask, neon: neonMask, deco: decoMask, arch: archMask })[art.st.art] ?? shapeMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
            saturation: art.st.art === "pebble" ? -0.3 : art.st.art === "taped" ? -0.45 : 0
            colorization: art.st.art === "taped" ? 0.25 : 0
            colorizationColor: "#a0784a"
        }

        Rectangle {
            anchors.fill: parent
            color: Colors.withAlpha(art.accent, 0.18)

            Glyph {
                anchors.centerIn: parent
                text: "music_note"
                font.pixelSize: art.width * 0.42
                color: art.accent
            }
        }

        Image {
            id: cover
            anchors.fill: parent
            source: art.source
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(art.width * 2, art.height * 2)
            asynchronous: true
            visible: status === Image.Ready
        }

        // Broadsheet: printed in the paper, in halftone on newsprint.
        ShaderEffect {
            anchors.fill: parent
            visible: art.st.art === "halftone" && cover.status === Image.Ready

            property variant source: cover
            property real itemWidth: width
            property real itemHeight: height
            property real press: 1
            property real cell: 3.2
            property real fold: 0
            property color paperColor: "#ebe6d9"

            fragmentShader: Qt.resolvedUrl("../../shaders/desktop_press.frag.qsb")
        }
    }

    // Theme touches.
    Rectangle {
        anchors.fill: parent
        visible: art.st.art === "square" || art.st.art === "seal"
        radius: art.radius
        color: "transparent"
        border.width: 1
        border.color: Colors.withAlpha(art.accent, art.st.art === "seal" ? 0.8 : 0.5)
    }

    HudTick {
        visible: art.st.art === "chamfer"
        cut: 10
        color: art.accent
    }

    NeonFrame {
        visible: art.st.art === "neon"
        cut: 14
        fill: "transparent"
        glow: 0
        inset: 1
        stroke: art.accent
        edge: Services.DesktopTheme.accent2Of(art.themeId)
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -5
        visible: art.st.art === "circle"
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: Colors.withAlpha(art.accent, 0.35)
    }

    DecoFrame {
        visible: art.st.art === "deco"
        cut: 6
        steps: 2
        fill: "transparent"
        stroke: art.accent
        strokeWidth: 1.5
        inset: 0.75
    }

    Shape {
        anchors.fill: parent
        visible: art.st.art === "arch"
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: "#060505"
            strokeWidth: 3
            joinStyle: ShapePath.RoundJoin

            PathPolyline {
                path: ThemeShapes.arch(1, 1, art.width - 2, art.height - 2, art.height * 0.3 - 1)
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: Colors.withAlpha(art.accent, 0.8)
            strokeWidth: 1
            joinStyle: ShapePath.RoundJoin

            PathPolyline {
                path: ThemeShapes.arch(3, 3, art.width - 6, art.height - 6, art.height * 0.3 - 3)
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: art.st.art === "halftone"
        color: "transparent"
        border.width: 1
        border.color: "#1b1a17"
    }

    // Wasteland: masking tape over two corners.
    Repeater {
        model: art.st.art === "taped" ? [{ x: -9, y: 3, r: -42 }, { x: art.width - 23, y: art.height - 13, r: -40 }] : []

        Rectangle {
            required property var modelData
            x: modelData.x
            y: modelData.y
            width: 32
            height: 11
            rotation: modelData.r
            color: "#d6c6a0"
            opacity: 0.88
        }
    }
}
