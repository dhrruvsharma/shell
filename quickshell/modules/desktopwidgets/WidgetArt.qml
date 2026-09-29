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
// taped up at two corners; Observatory's is an engraved portrait medallion
// in a brass ring; Abyss's is seen through a bolted porthole, under water.
Item {
    id: art

    property string themeId
    property string source
    readonly property var st: WidgetStyle.of(themeId)
    readonly property color accent: WidgetStyle.accent(themeId)
    readonly property bool round: ["circle", "medallion", "porthole"].includes(st.art)
    readonly property real radius: round ? width / 2 : st.art === "rounded" || st.art === "pebble" ? 14 : st.art === "soft" ? 12 : st.art === "seal" ? 4 : st.art === "taped" ? 2 : 0
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
            saturation: art.st.art === "pebble" ? -0.3 : art.st.art === "taped" ? -0.45 : art.st.art === "medallion" ? -0.35 : art.st.art === "porthole" ? -0.2 : 0
            colorization: art.st.art === "taped" ? 0.25 : art.st.art === "medallion" ? 0.18 : art.st.art === "porthole" ? 0.3 : 0
            colorizationColor: art.st.art === "porthole" ? "#1d6f82" : "#a0784a"
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

    // Observatory: a medallion in a brass ring, graduated round its edge.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        visible: art.st.art === "medallion"
        radius: width / 2
        color: "transparent"
        border.width: 3
        border.color: art.accent

        Rectangle {
            anchors.fill: parent
            anchors.margins: 5
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Colors.withAlpha(art.accent, 0.5)
        }
    }

    Repeater {
        model: art.st.art === "medallion" ? 24 : 0

        Rectangle {
            required property int index
            readonly property real a: index * 15 * Math.PI / 180
            readonly property real r: art.width / 2 + 7
            x: art.width / 2 + Math.sin(a) * r - width / 2
            y: art.height / 2 - Math.cos(a) * r - height / 2
            width: 1
            height: index % 6 === 0 ? 5 : 3
            rotation: index * 15
            color: art.accent
        }
    }

    // Abyss: behind the glass of a porthole, its steel ring bolted round.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -6
        visible: art.st.art === "porthole"
        radius: width / 2
        color: "transparent"
        border.width: 6
        border.color: "#2c4048"

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Colors.withAlpha("#9fb7bf", 0.55)
        }
    }

    Repeater {
        model: art.st.art === "porthole" ? 8 : 0

        Rectangle {
            required property int index
            readonly property real a: (index * 45 + 22.5) * Math.PI / 180
            readonly property real r: art.width / 2 + 3
            x: art.width / 2 + Math.sin(a) * r - width / 2
            y: art.height / 2 - Math.cos(a) * r - height / 2
            width: 4
            height: 4
            radius: 2
            color: "#a9bec5"
            border.width: 0.5
            border.color: "#0b1418"
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: art.st.art === "porthole"
        radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0; color: Colors.withAlpha("#e6fbff", 0.22) }
            GradientStop { position: 0.45; color: "transparent" }
        }
    }
}
