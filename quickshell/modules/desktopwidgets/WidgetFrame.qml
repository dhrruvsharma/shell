pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.colors
import qs.components
import qs.modules.lock.themes.wasteland
import qs.services as Services

// The body of a desktop widget in the look of a desktop theme (WidgetStyle):
// a Material card, a chamfered HUD panel, a console box with its title on a
// tab, a glass pane, nothing at all (text shadow only), a paper slip with a
// seal, a cut-corner neon panel, a pebble of washi mended with gold, black
// lacquer in a stepped gold rule, a leaded lancet window, a newspaper
// clipping, or a plate of scrap with its name on masking tape. Children
// stack in a Column under the title; set their text in `ink`.
Item {
    id: frame

    property string themeId
    property string title
    // Character on the Cave Abode seal.
    property string seal: "印"
    property real spacing: 10
    default property alias content: body.data

    readonly property var st: WidgetStyle.of(themeId)
    readonly property color accent: WidgetStyle.accent(themeId)
    // What text is set in: the scheme's, or printer's ink on newsprint.
    readonly property color ink: WidgetStyle.ink(themeId)
    readonly property bool isConsole: st.frame === "console"
    readonly property bool hasTitle: title.length > 0 && !isConsole
    readonly property bool centredTitle: st.frame === "gilt" || st.frame === "lancet"
    // Room above the console box for its title tab, which straddles the top
    // edge: a widget's surface ends at its frame, so it would be cut off.
    readonly property real tabRoom: isConsole && title.length > 0 ? 10 : 0
    // The lancet's pointed head, and the heavy rule over a clipping's
    // kicker, both above the title.
    readonly property real archRise: Math.min(66, width * 0.18)
    readonly property real headRoom: st.frame === "lancet" ? archRise * 0.62 : st.frame === "clipping" ? 8 : 0

    implicitWidth: body.implicitWidth + st.pad * 2
    implicitHeight: tabRoom + headRoom + body.implicitHeight + st.pad * 2 + (hasTitle ? titleText.implicitHeight + frame.spacing : 0)

    // Legibility for frameless widgets straight on the wallpaper.
    layer.enabled: st.frame === "bare"
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: "black"
        shadowOpacity: 0.45
        shadowBlur: 0.7
        blurMax: 24
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 1
    }

    Rectangle {
        anchors.fill: parent
        visible: frame.st.frame === "card"
        radius: 22
        color: Colors.withAlpha(Colors.surface_container, 0.86)
        border.width: 1
        border.color: Colors.withAlpha(Colors.outline_variant, 0.5)
    }

    HudFrame {
        visible: frame.st.frame === "chamfer"
        cut: 14
        fill: Colors.withAlpha(Colors.background, 0.68)
        stroke: Colors.withAlpha(frame.accent, 0.35)
        tickColor: frame.accent
    }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: frame.tabRoom
        visible: frame.isConsole
        color: Colors.withAlpha(Colors.background, 0.8)
        border.width: 1
        border.color: Colors.withAlpha(frame.accent, 0.45)

        Rectangle {
            x: 16
            y: -10
            visible: frame.title.length > 0
            width: tabText.implicitWidth + 18
            height: 20
            color: Colors.background
            border.width: 1
            border.color: Colors.withAlpha(frame.accent, 0.45)

            Text {
                id: tabText
                anchors.centerIn: parent
                text: frame.title
                font.family: frame.st.mono
                font.pixelSize: 12
                font.weight: Font.Medium
                color: frame.accent
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: frame.st.frame === "glass"
        radius: 28
        color: Colors.withAlpha(Colors.background, 0.46)
        border.width: 1
        border.color: Colors.withAlpha(frame.accent, 0.3)
    }

    Rectangle {
        anchors.fill: parent
        visible: frame.st.frame === "scroll"
        radius: 4
        color: Colors.withAlpha(Colors.surface_container, 0.8)
        border.width: 1
        border.color: Colors.withAlpha(frame.accent, 0.55)

        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: 2
            color: "transparent"
            border.width: 1
            border.color: Colors.withAlpha(frame.accent, 0.22)
        }

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            width: 22
            height: 22
            radius: 3
            rotation: -4
            color: frame.accent

            Text {
                anchors.centerIn: parent
                text: frame.seal
                font.family: frame.st.cjk ?? frame.st.font
                font.pixelSize: 13
                font.weight: Font.Bold
                color: Colors.on_tertiary
            }
        }
    }

    // Neon Noir: a dark panel with a cut corner, a neon hairline and a tab.
    NeonFrame {
        visible: frame.st.frame === "neon"
        cut: 18
        fill: Colors.withAlpha(Qt.tint(Colors.background, "#59000000"), 0.8)
        stroke: frame.accent
        edge: Services.DesktopTheme.accent2Of(frame.themeId)
        glow: 0.7
    }

    Rectangle {
        visible: frame.st.frame === "neon"
        x: 1
        y: frame.st.pad - 2
        width: 3
        height: 24
        color: frame.accent
    }

    // Wabi-sabi: washi on a pebble, with a crack mended in gold running in
    // from the rim.
    Rectangle {
        anchors.fill: parent
        visible: frame.st.frame === "washi"
        radius: 20
        topLeftRadius: radius * Services.DesktopTheme.pebbleCorners[0]
        topRightRadius: radius * Services.DesktopTheme.pebbleCorners[1]
        bottomRightRadius: radius * Services.DesktopTheme.pebbleCorners[2]
        bottomLeftRadius: radius * Services.DesktopTheme.pebbleCorners[3]
        color: Colors.withAlpha(Qt.tint(Colors.surface_container, "#1ad9b88c"), 0.82)
        border.width: 1
        border.color: Colors.withAlpha(frame.accent, 0.3)

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: "#c9a24f"
                strokeWidth: 1.7
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: frame.width * 0.66
                startY: 0
                PathLine { x: frame.width * 0.66 + 5; y: 6 }
                PathLine { x: frame.width * 0.66 + 3; y: 11 }
                PathLine { x: frame.width * 0.66 + 11; y: 16 }
                PathLine { x: frame.width * 0.66 + 9; y: 21 }
                PathLine { x: frame.width * 0.66 + 14; y: 26 }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: "#c9a24f"
                strokeWidth: 1.2
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: frame.width * 0.66 + 11
                startY: 16
                PathLine { x: frame.width * 0.66 + 19; y: 15 }
                PathLine { x: frame.width * 0.66 + 23; y: 19 }
            }
        }
    }

    // Art Deco: black lacquer in a double gold rule stepped at the corners,
    // the title centred between two short rules.
    DecoFrame {
        visible: frame.st.frame === "gilt"
        cut: 7
        steps: 2
        fill: Colors.withAlpha("#0d0b08", 0.84)
        stroke: frame.accent
        gap: 5
        innerStroke: Colors.withAlpha(frame.accent, 0.35)
    }

    Repeater {
        model: frame.st.frame === "gilt" && frame.hasTitle ? 2 : 0

        Rectangle {
            required property int index
            x: index === 0 ? titleText.x - width - 10 : titleText.x + titleText.width + 10
            y: Math.round(titleText.y + titleText.height / 2 - 1)
            width: 26
            height: 1
            color: frame.accent
        }
    }

    // Cathedral: a lancet window of dark stone, its lead line doubled inside
    // with a line of the theme's glass.
    Shape {
        anchors.fill: parent
        visible: frame.st.frame === "lancet"
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: Colors.withAlpha("#141210", 0.86)
            strokeColor: "#060505"
            strokeWidth: 3
            joinStyle: ShapePath.RoundJoin

            PathPolyline {
                path: ThemeShapes.arch(1.5, 1.5, frame.width - 3, frame.height - 3, frame.archRise)
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: Colors.withAlpha(frame.accent, 0.75)
            strokeWidth: 1.2
            joinStyle: ShapePath.RoundJoin

            PathPolyline {
                path: ThemeShapes.arch(5.5, 5.5, frame.width - 11, frame.height - 11, frame.archRise - 3)
            }
        }
    }

    // Broadsheet: a clipping of newsprint casting a hard shadow, its title a
    // kicker under a heavy rule.
    Rectangle {
        visible: frame.st.frame === "clipping"
        x: 5
        y: 5
        width: frame.width
        height: frame.height
        color: Colors.withAlpha("black", 0.42)
    }

    Rectangle {
        anchors.fill: parent
        visible: frame.st.frame === "clipping"
        color: "#ebe6d9"
    }

    Rectangle {
        visible: frame.st.frame === "clipping" && frame.hasTitle
        x: frame.st.pad
        y: frame.st.pad
        width: frame.width - frame.st.pad * 2
        height: 3
        color: frame.ink
    }

    // Wasteland: a plate of scrap, its name on a strip of masking tape.
    ScrapPlate {
        anchors.fill: parent
        visible: frame.st.frame === "scrap"
        seed: frame.title.length * 1.7 + 0.3
        rust: 0.5
        fill: 0.9
    }

    Rectangle {
        visible: frame.st.frame === "scrap" && frame.hasTitle
        x: titleText.x - 9
        y: titleText.y - 3
        width: titleText.implicitWidth + 18
        height: titleText.implicitHeight + 5
        rotation: -1.5
        color: Waste.tape
        opacity: 0.95
    }

    // Neon Noir's title splits like a bad signal: a ghost in the other neon.
    Text {
        x: titleText.x + 1.5
        y: titleText.y
        visible: frame.hasTitle && frame.st.frame === "neon"
        text: titleText.text
        font: titleText.font
        color: Colors.withAlpha(frame.accent, 0.55)
    }

    Text {
        id: titleText
        x: frame.centredTitle ? Math.round((frame.width - implicitWidth) / 2) : frame.st.pad + (frame.st.frame === "neon" ? 4 : 0)
        y: frame.headRoom + frame.st.pad
        visible: frame.hasTitle
        rotation: frame.st.frame === "scrap" ? -1.5 : 0
        text: (frame.st.frame === "chamfer" ? "▸ " : "") + WidgetStyle.label(frame.title, frame.st)
        font.family: frame.st.frame === "scrap" ? Waste.type : frame.st.ui ?? frame.st.cjk ?? (frame.st.frame === "chamfer" ? frame.st.mono : frame.st.font)
        font.pixelSize: ({ neon: 15, washi: 12, lancet: 17, clipping: 13, scrap: 13, gilt: 11 })[frame.st.frame] ?? 11
        font.weight: frame.st.frame === "chamfer" || frame.st.frame === "clipping" ? Font.Bold : frame.st.frame === "neon" || frame.st.frame === "scrap" ? Font.Normal : frame.st.frame === "gilt" ? Font.DemiBold : Font.Medium
        font.letterSpacing: frame.st.labelSpacing
        font.capitalization: WidgetStyle.caps(frame.st)
        color: frame.st.frame === "scrap" ? Waste.tapeInk : WidgetStyle.labelColor(frame.themeId)
    }

    Column {
        id: body
        x: frame.st.pad
        y: frame.tabRoom + frame.headRoom + frame.st.pad + (frame.hasTitle ? titleText.implicitHeight + frame.spacing : 0)
        spacing: frame.spacing
    }
}
