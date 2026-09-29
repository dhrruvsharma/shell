pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.colors
import qs.services as Services

// The desktop theme's frame on a panel's outer surface. Put it last inside
// the surface (so it draws over the edges) and give it the surface's radius;
// it never takes input. HUD: accent hairline and corner brackets. Mainframe:
// console border, faint scanlines and a title tab. Astral: hairline with a
// glow along the top. Still: nothing. Cave Abode: double border and a seal.
// Neon Noir: neon hairline, a duotone rail along the top, corner tabs and a
// title tag. Wabi-sabi: a quiet hairline and kintsugi seams running in from
// the rim (short enough to stay in the margins). Art Deco: a double gold
// rule stepped in at the corners and a sunburst at the head. Cathedral: a
// cusped jewel line lined with lead, and a quatrefoil. Broadsheet: a heavy
// and a thin rule under the head, the title as a section flag. Wasteland:
// rivets, a length of hazard tape and the title on masking tape.
// Observatory: an engraved double rim, graduated along the head like an
// instrument's limb, with a star at its middle. Abyss: a lume hairline, a
// lit status strip, a sonar ping in the far corner and the title on an
// instrument label. Devaloka: a gold rim lined inside, temple borders
// hanging from the head and standing along the foot like a sari's, and a
// lotus at the middle of the head. Siege: iron straps nailed over the
// corners, battlements along the head and the shield of your arms at its
// middle.
Item {
    id: decor

    property real radius: 0
    // Mainframe's tab and Neon Noir's tag; empty for none.
    property string title: ""
    property string seal: "印"

    readonly property string shape: Services.DesktopTheme.look.shape
    readonly property color accent: shape === "seal" ? Colors.tertiary : Services.DesktopTheme.accent
    readonly property color accent2: Services.DesktopTheme.accent2
    readonly property color gold: "#c29a48"

    anchors.fill: parent
    visible: Services.DesktopTheme.enabled && shape !== "soft"
    z: 1000

    // Hairline border (all but Still; Art Deco and Cathedral draw their own).
    Rectangle {
        anchors.fill: parent
        visible: decor.shape !== "deco" && decor.shape !== "cusp"
        radius: decor.radius
        color: "transparent"
        border.width: 1
        border.color: decor.shape === "print" ? Colors.withAlpha(decor.accent2, 0.45)
            : decor.shape === "lume" ? Colors.withAlpha(decor.accent2, 0.4)
            : Colors.withAlpha(decor.accent, decor.shape === "square" ? 0.5 : decor.shape === "seal" ? 0.55 : decor.shape === "neon" ? 0.6 : decor.shape === "pebble" ? 0.28 : decor.shape === "plate" ? 0.45 : decor.shape === "scale" || decor.shape === "zari" || decor.shape === "crenel" ? 0.6 : 0.32)
    }

    // HUD: corner brackets.
    Repeater {
        model: decor.shape === "chamfer" ? 4 : 0

        Item {
            id: bracket
            required property int index
            readonly property bool isRight: index === 1 || index === 2
            readonly property bool isBottom: index >= 2
            x: isRight ? decor.width - width : 0
            y: isBottom ? decor.height - height : 0
            width: 18
            height: 18

            Rectangle {
                y: bracket.isBottom ? parent.height - 2 : 0
                width: parent.width
                height: 2
                color: decor.accent
            }

            Rectangle {
                x: bracket.isRight ? parent.width - 2 : 0
                width: 2
                height: parent.height
                color: decor.accent
            }
        }
    }

    // Mainframe: scanlines and a tab.
    ShaderEffect {
        anchors.fill: parent
        visible: decor.shape === "square"

        property real itemWidth: width
        property real itemHeight: height
        property real gridSize: 30
        property real dotAlpha: 0
        property real scanAlpha: 0.07
        property real tintAlpha: 0
        property real vignette: 0
        property color tintColor: "black"
        property color dotColor: "black"

        fragmentShader: Qt.resolvedUrl("../shaders/lock_backdrop.frag.qsb")
    }

    Rectangle {
        visible: decor.shape === "square" && decor.title.length > 0
        x: 18
        width: tabText.implicitWidth + 16
        height: 17
        color: decor.accent

        Text {
            id: tabText
            anchors.centerIn: parent
            text: decor.title
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 11
            font.weight: Font.Bold
            color: Colors.on_primary
        }
    }

    // Astral: a glow along the top edge.
    Rectangle {
        visible: decor.shape === "pill"
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.6
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: Colors.withAlpha(decor.accent, 0.9) }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    // Cave Abode: inner border and a seal in the corner.
    Rectangle {
        visible: decor.shape === "seal"
        anchors.fill: parent
        anchors.margins: 5
        radius: Math.max(0, decor.radius - 3)
        color: "transparent"
        border.width: 1
        border.color: Colors.withAlpha(decor.accent, 0.22)
    }

    Rectangle {
        visible: decor.shape === "seal"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 9
        width: 17
        height: 17
        radius: 2
        rotation: -4
        color: decor.accent

        Text {
            anchors.centerIn: parent
            text: decor.seal
            font.family: "Noto Serif CJK SC"
            font.pixelSize: 11
            font.weight: Font.Bold
            color: Colors.on_tertiary
        }
    }

    // Neon Noir: a rail of light along the top, one neon fading into the
    // other, solid tabs at two corners, and the title on a hanging tag.
    Item {
        anchors.fill: parent
        visible: decor.shape === "neon"

        Rectangle {
            width: parent.width
            height: 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: decor.accent }
                GradientStop { position: 0.55; color: Colors.withAlpha(decor.accent, 0.25) }
                GradientStop { position: 1; color: decor.accent2 }
            }
        }

        Rectangle {
            x: 14
            y: 2
            width: 28
            height: 3
            color: decor.accent
        }

        Rectangle {
            x: parent.width - 5
            y: parent.height - 34
            width: 3
            height: 26
            color: decor.accent2
        }

        Rectangle {
            visible: decor.title.length > 0
            x: parent.width - width - 22
            y: 2
            width: tagText.implicitWidth + 16
            height: 17
            color: decor.accent

            Text {
                id: tagText
                anchors.centerIn: parent
                text: "// " + decor.title.toUpperCase()
                font.family: "Fragile Bombers"
                font.pixelSize: 13
                font.letterSpacing: 1
                color: "#07080c"
            }
        }
    }

    // Wabi-sabi: cracks mended with gold, short enough to stay in the
    // panel's margin.
    Shape {
        anchors.fill: parent
        visible: decor.shape === "pebble"
        preferredRendererType: Shape.CurveRenderer

        component Seam: ShapePath {
            fillColor: "transparent"
            strokeColor: Colors.withAlpha(decor.gold, 0.9)
            strokeWidth: 1.5
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
        }

        Seam {
            startX: decor.width * 0.72
            startY: 0
            PathLine { x: decor.width * 0.72 + 4; y: 5 }
            PathLine { x: decor.width * 0.72 + 2; y: 9 }
            PathLine { x: decor.width * 0.72 + 9; y: 13 }
            PathLine { x: decor.width * 0.72 + 8; y: 17 }
        }

        Seam {
            startX: decor.width * 0.72 + 4
            startY: 5
            PathLine { x: decor.width * 0.72 + 12; y: 6 }
            PathLine { x: decor.width * 0.72 + 15; y: 10 }
        }

        Seam {
            startX: 0
            startY: decor.height * 0.62
            PathLine { x: 5; y: decor.height * 0.62 + 3 }
            PathLine { x: 8; y: decor.height * 0.62 + 1 }
            PathLine { x: 13; y: decor.height * 0.62 + 5 }
        }

    }

    // Art Deco: a double gold rule stepped in at the corners, and a sunburst
    // fanning down from the middle of the top edge.
    DecoFrame {
        visible: decor.shape === "deco"
        cut: 6
        steps: 2
        fill: "transparent"
        stroke: Colors.withAlpha(decor.accent, 0.75)
        gap: 5
        innerStroke: Colors.withAlpha(decor.accent, 0.3)
    }

    Shape {
        visible: decor.shape === "deco"
        x: (decor.width - width) / 2
        y: 0.5
        width: 46
        height: 17
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: Colors.withAlpha(decor.accent, 0.75)
            strokeWidth: 1
            capStyle: ShapePath.FlatCap

            PathMultiline {
                paths: {
                    const out = [];
                    for (let i = 0; i < 11; i++) {
                        const a = (15 + i * 15) * Math.PI / 180;
                        const r1 = i % 2 === 0 ? 16 : 11;
                        out.push([Qt.point(23 + Math.cos(a) * 7.5, Math.sin(a) * 7.5), Qt.point(23 + Math.cos(a) * r1, Math.sin(a) * r1)]);
                    }
                    return out;
                }
            }
        }

        ShapePath {
            fillColor: decor.accent
            strokeColor: "transparent"

            PathAngleArc {
                centerX: 23
                centerY: 0
                radiusX: 5.5
                radiusY: 5.5
                startAngle: 0
                sweepAngle: 180
            }
        }
    }

    // Cathedral: a cusped line in the theme's glass, lined with lead, and a
    // quatrefoil at the head.
    CuspFrame {
        visible: decor.shape === "cusp"
        cut: 12
        fill: "transparent"
        stroke: Colors.withAlpha(decor.accent, 0.6)
        gap: 4
        innerStroke: Colors.withAlpha(decor.accent2, 0.35)
    }

    Shape {
        visible: decor.shape === "cusp"
        x: (decor.width - width) / 2
        y: 4
        width: 16
        height: 16
        preferredRendererType: Shape.CurveRenderer

        component Foil: PathAngleArc {
            radiusX: 3.6
            radiusY: 3.6
            startAngle: 0
            sweepAngle: 360
        }

        ShapePath {
            fillColor: Colors.withAlpha(decor.accent2, 0.25)
            strokeColor: Colors.withAlpha(decor.accent, 0.85)
            strokeWidth: 1

            PathMove { x: 11.6; y: 4 }
            Foil { centerX: 8; centerY: 4 }
            PathMove { x: 15.6; y: 8 }
            Foil { centerX: 12; centerY: 8 }
            PathMove { x: 11.6; y: 12 }
            Foil { centerX: 8; centerY: 12 }
            PathMove { x: 7.6; y: 8 }
            Foil { centerX: 4; centerY: 8 }
        }
    }

    // Broadsheet: a heavy rule and a thin one under the head, like a
    // masthead, a thin one at the foot, and the title as a section flag.
    Item {
        anchors.fill: parent
        visible: decor.shape === "print"

        Rectangle {
            x: 12
            y: 8
            width: parent.width - 24
            height: 3
            color: Colors.withAlpha(decor.accent2, 0.8)
        }

        Rectangle {
            x: 12
            y: 13
            width: parent.width - 24
            height: 1
            color: Colors.withAlpha(decor.accent2, 0.6)
        }

        Rectangle {
            x: 12
            y: parent.height - 9
            width: parent.width - 24
            height: 1
            color: Colors.withAlpha(decor.accent2, 0.45)
        }

        Rectangle {
            visible: decor.title.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            y: 3
            width: flagText.implicitWidth + 16
            height: 15
            color: decor.accent2

            Text {
                id: flagText
                anchors.centerIn: parent
                text: decor.title
                font.family: "Old Standard TT"
                font.pixelSize: 11
                font.weight: Font.Bold
                font.capitalization: Font.SmallCaps
                font.letterSpacing: 1
                color: Colors.surface_container_lowest
            }
        }
    }

    // Wasteland: bolted at the corners, a length of hazard tape along the
    // top and the title on a strip of masking tape.
    Item {
        anchors.fill: parent
        visible: decor.shape === "plate"

        Repeater {
            model: 4

            Rivet {
                required property int index
                size: 6
                x: index % 2 === 0 ? 6 : decor.width - width - 6
                y: index < 2 ? 6 : decor.height - height - 6
            }
        }

        HazardStripes {
            x: 26
            width: Math.min(150, parent.width * 0.26)
            height: 5
            stripe: 5
            colorA: decor.accent2
            opacity: 0.9
        }

        Rectangle {
            visible: decor.title.length > 0
            x: parent.width - width - 34
            y: 4
            rotation: -2
            width: tapeText.implicitWidth + 16
            height: 17
            color: "#d6c6a0"
            opacity: 0.93

            Text {
                id: tapeText
                anchors.centerIn: parent
                text: decor.title.toUpperCase()
                font.family: "Special Elite"
                font.pixelSize: 11
                color: "#2a241c"
            }
        }
    }

    // Observatory: a second, finer rim inside the first, the head graduated
    // between them like the limb of an instrument, and a little half-dial
    // hanging at its middle.
    Item {
        anchors.fill: parent
        visible: decor.shape === "scale"

        Rectangle {
            anchors.fill: parent
            anchors.margins: 5
            radius: Math.max(0, decor.radius - 4)
            color: "transparent"
            border.width: 1
            border.color: Colors.withAlpha(decor.accent, 0.25)
        }

        Repeater {
            model: 2

            ScaleTicks {
                required property int index
                x: index === 0 ? 22 : decor.width / 2 + 16
                y: 1
                width: decor.width / 2 - 38
                height: 4
                step: 6
                major: 5
                minorLength: 2
                majorLength: 4
                color: Colors.withAlpha(decor.accent, 0.5)
            }
        }

        Shape {
            x: decor.width / 2 - 10
            y: 0
            width: 20
            height: 12
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Colors.withAlpha(decor.accent, 0.12)
                strokeColor: Colors.withAlpha(decor.accent, 0.75)
                strokeWidth: 1

                PathAngleArc {
                    centerX: 10
                    centerY: 0.5
                    radiusX: 9
                    radiusY: 9
                    startAngle: 0
                    sweepAngle: 180
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: Colors.withAlpha(decor.accent, 0.75)
                strokeWidth: 1
                capStyle: ShapePath.FlatCap

                PathMultiline {
                    paths: {
                        const out = [];
                        for (let i = 1; i < 6; i++) {
                            const a = i * Math.PI / 6;
                            out.push([Qt.point(10 + Math.cos(a) * 5.5, 0.5 + Math.sin(a) * 5.5), Qt.point(10 + Math.cos(a) * 8.5, 0.5 + Math.sin(a) * 8.5)]);
                        }
                        // The index, pointing straight down.
                        out.push([Qt.point(10, 0.5), Qt.point(10, 7.5)]);
                        return out;
                    }
                }
            }
        }
    }

    // Abyss: a lit status strip at the head, a sonar ping in the far corner,
    // and the title on an instrument label.
    Item {
        anchors.fill: parent
        visible: decor.shape === "lume"

        Rectangle {
            x: Math.max(14, decor.radius)
            y: 0
            width: 34
            height: 2
            radius: 1
            color: decor.accent2
        }

        Rectangle {
            x: Math.max(14, decor.radius) - 2
            y: -1
            width: 38
            height: 5
            radius: 2.5
            color: Colors.withAlpha(decor.accent2, 0.18)
        }

        PingArcs {
            anchors.fill: parent
            cx: width - Math.max(14, decor.radius)
            cy: Math.max(14, decor.radius)
            gap: 6
            color: Colors.withAlpha(decor.accent2, 0.45)
        }

        Rectangle {
            visible: decor.title.length > 0
            x: Math.max(14, decor.radius) + 44
            y: 5
            width: labelText.implicitWidth + 16
            height: 16
            radius: 8
            color: Colors.withAlpha(decor.accent2, 0.1)
            border.width: 1
            border.color: Colors.withAlpha(decor.accent2, 0.5)

            Text {
                id: labelText
                anchors.centerIn: parent
                text: decor.title.toUpperCase()
                font.family: "B612"
                font.pixelSize: 9
                font.weight: Font.Bold
                font.letterSpacing: 1.5
                color: decor.accent2
            }
        }
    }

    // Devaloka: a second rule inside the rim, temple borders hanging from
    // the head (parted for a lotus at its middle) and standing along the
    // foot.
    Item {
        id: zari
        anchors.fill: parent
        visible: decor.shape === "zari"

        readonly property real inset: Math.max(12, decor.radius + 4)

        Rectangle {
            anchors.fill: parent
            anchors.margins: 5
            radius: Math.max(0, decor.radius - 4)
            color: "transparent"
            border.width: 1
            border.color: Colors.withAlpha(decor.accent, 0.25)
        }

        Repeater {
            model: 2

            TempleBorder {
                required property int index
                x: index === 0 ? zari.inset : decor.width / 2 + 16
                y: 1
                width: decor.width / 2 - 16 - zari.inset
                height: 4
                step: 6
                down: true
                rule: 0
                color: Colors.withAlpha(decor.accent, 0.5)
            }
        }

        TempleBorder {
            x: zari.inset
            y: decor.height - height - 1
            width: decor.width - 2 * zari.inset
            height: 3
            step: 6
            rule: 0
            color: Colors.withAlpha(decor.accent, 0.35)
        }

        Lotus {
            x: (decor.width - width) / 2
            y: 1
            width: 22
            height: 14
            stroke: Colors.withAlpha(decor.accent, 0.85)
            fill: Colors.withAlpha(decor.accent2, 0.3)
        }
    }

    // Siege: a finer steel line inside the rim, battlements along the head
    // (parted for the shield of your arms), and an iron strap nailed over
    // each corner.
    Item {
        id: siege
        anchors.fill: parent
        visible: decor.shape === "crenel"

        readonly property real inset: Math.max(26, decor.radius + 8)

        Rectangle {
            anchors.fill: parent
            anchors.margins: 5
            color: "transparent"
            border.width: 1
            border.color: Colors.withAlpha(decor.accent2, 0.18)
        }

        Repeater {
            model: 2

            Shape {
                required property int index
                x: index === 0 ? siege.inset : decor.width / 2 + 16
                y: 5
                width: decor.width / 2 - 16 - siege.inset
                height: 7
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: Colors.withAlpha(decor.accent, 0.16)
                    strokeColor: Colors.withAlpha(decor.accent, 0.5)
                    strokeWidth: 1
                    joinStyle: ShapePath.MiterJoin

                    PathPolyline {
                        path: ThemeShapes.crenel(0, 0, siege.width / 2 - 16 - siege.inset, 7, 9, 3.5, 0.5)
                    }
                }
            }
        }

        // The shield of your arms (services/Heraldry.qml).
        ShaderEffect {
            x: (decor.width - width) / 2
            y: 2
            width: 16
            height: 19

            property real itemWidth: width
            property real itemHeight: height
            property real ordinary: Services.Heraldry.arms.ordinary
            property real charge: 0
            property real lone: 0
            property real rim: 1
            property real worn: 0
            property real glow: 0
            property real seed: 1
            property color fieldColor: Qt.hsla(Services.Heraldry.tincture.h, Math.min(0.78, Services.Heraldry.tincture.sat + 0.06), 0.4, 1)
            property color metalColor: "#e4e6e6"
            property color chargeColor: "#e3b24a"
            property color rimColor: decor.accent2
            property color glowColor: "black"

            fragmentShader: Qt.resolvedUrl("../shaders/heraldry.frag.qsb")
        }

        Repeater {
            model: 4

            Item {
                id: strap
                required property int index
                readonly property bool isRight: index === 1 || index === 2
                readonly property bool isBottom: index >= 2
                x: isRight ? decor.width - width : 0
                y: isBottom ? decor.height - height : 0
                width: 22
                height: 22

                component Iron: Rectangle {
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#58575a" }
                        GradientStop { position: 1; color: "#2c2b2d" }
                    }
                    border.width: 0.5
                    border.color: "#0b0a0a"
                }

                Iron {
                    y: strap.isBottom ? strap.height - 4 : 0
                    width: strap.width
                    height: 4
                }

                Iron {
                    x: strap.isRight ? strap.width - 4 : 0
                    width: 4
                    height: strap.height
                }

                Repeater {
                    model: [[0.62, 0], [0, 0.62]]

                    Rectangle {
                        required property var modelData
                        readonly property real along: modelData[0] > 0 ? modelData[0] * strap.width : 2
                        readonly property real down: modelData[1] > 0 ? modelData[1] * strap.height : 2
                        x: (strap.isRight ? strap.width - along : along) - width / 2
                        y: (strap.isBottom ? strap.height - down : down) - height / 2
                        width: 3
                        height: 3
                        radius: 1.5
                        color: "#8d8f93"
                    }
                }
            }
        }
    }
}
