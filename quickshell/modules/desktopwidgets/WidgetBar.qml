pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import qs.colors
import qs.components
import qs.services as Services

// A 0..1 meter in the look of a desktop theme (WidgetStyle.bar): a rounded
// line, HUD segments, an ASCII gauge, an orbit with a glowing body, a
// hairline, a tapering brush stroke, a neon tube with a lit tip, a line of
// ink ending in a blot, a gilt bar with a diamond tip, a strip of leaded
// glass lighting pane by pane, a newspaper's ruled bar, hazard tape in a
// steel channel, a brass vernier scale with its pointer, a lit tube with a
// bright head and bubbles rising off it, a string of prayer beads told
// up to the value, or a sword drawn from its scabbard as far as the value.
Item {
    id: bar

    property string themeId
    property real value: 0
    readonly property var st: WidgetStyle.of(themeId)
    readonly property color accent: WidgetStyle.accent(themeId)
    readonly property real v: Math.max(0, Math.min(1, value))
    readonly property color ink: WidgetStyle.ink(themeId)
    readonly property color track: Colors.withAlpha(ink, 0.14)

    implicitWidth: st.bar === "ascii" ? ascii.implicitWidth : 200
    implicitHeight: st.bar === "ascii" ? ascii.implicitHeight
        : ({ orbit: 10, segments: 6, neon: 6, ink: 6, hairline: 3, deco: 9, glass: 9, rule: 8, hazard: 9, vernier: 11, sonar: 12, mala: 10, sword: 12 })[st.bar] ?? 4

    // line
    Rectangle {
        visible: bar.st.bar === "line"
        width: parent.width
        height: 4
        radius: 2
        color: bar.track

        Rectangle {
            width: parent.width * bar.v
            height: parent.height
            radius: 2
            color: bar.accent
        }
    }

    // segments
    Row {
        visible: bar.st.bar === "segments"
        spacing: 2

        Repeater {
            model: 20

            Rectangle {
                required property int index
                width: (bar.width - 19 * 2) / 20
                height: 6
                color: (index + 0.5) / 20 <= bar.v ? bar.accent : bar.track
            }
        }
    }

    // ascii
    Row {
        id: ascii
        visible: bar.st.bar === "ascii"

        readonly property int cells: 22
        readonly property int filled: Math.round(bar.v * cells)

        component Cell: Text {
            font.family: bar.st.mono
            font.pixelSize: 13
        }

        Cell { text: "["; color: Colors.withAlpha(Colors.on_surface, 0.6) }
        Cell { text: "#".repeat(ascii.filled); color: bar.accent }
        Cell { text: "·".repeat(ascii.cells - ascii.filled); color: Colors.withAlpha(Colors.on_surface, 0.3) }
        Cell { text: "]"; color: Colors.withAlpha(Colors.on_surface, 0.6) }
    }

    // orbit
    Item {
        visible: bar.st.bar === "orbit"
        anchors.fill: parent

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 1
            color: Colors.withAlpha(Colors.on_surface, 0.22)
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * bar.v
            height: 2
            radius: 1
            color: Colors.withAlpha(bar.accent, 0.85)
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: parent.width * bar.v - width / 2
            width: 14
            height: 14
            radius: 7
            color: Colors.withAlpha(bar.accent, 0.22)

            Rectangle {
                anchors.centerIn: parent
                width: 7
                height: 7
                radius: 3.5
                color: bar.accent
            }
        }
    }

    // hairline
    Rectangle {
        visible: bar.st.bar === "hairline"
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 1
        color: Colors.withAlpha(Colors.on_surface, 0.16)

        Rectangle {
            width: parent.width * bar.v
            height: 1
            color: Colors.withAlpha(Colors.on_surface, 0.8)
        }
    }

    // brush
    Item {
        visible: bar.st.bar === "brush"
        anchors.fill: parent

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 1
            color: Colors.withAlpha(bar.accent, 0.18)
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * bar.v
            height: 4
            radius: 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Colors.withAlpha(bar.accent, 0.15) }
                GradientStop { position: 0.7; color: Colors.withAlpha(bar.accent, 0.75) }
                GradientStop { position: 1; color: bar.accent }
            }
        }
    }

    // neon
    Item {
        id: neonBar
        visible: bar.st.bar === "neon"
        anchors.fill: parent

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 1
            color: Colors.withAlpha(bar.accent, 0.25)
        }

        Repeater {
            model: 9

            Rectangle {
                required property int index
                x: neonBar.width * (index + 1) / 10
                y: (neonBar.height - height) / 2
                width: 1
                height: 5
                color: Colors.withAlpha(bar.accent, 0.3)
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * bar.v
            height: 6
            color: Colors.withAlpha(bar.accent, 0.22)
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * bar.v
            height: 2
            color: bar.accent
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, parent.width * bar.v - width)
            width: 3
            height: 8
            color: Services.DesktopTheme.accent2Of(bar.themeId)
        }
    }

    // ink
    Item {
        visible: bar.st.bar === "ink"
        anchors.fill: parent

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 1
            color: Colors.withAlpha(Colors.on_surface, 0.14)
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * bar.v
            height: 3
            radius: 1.5
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Colors.withAlpha(bar.accent, 0.5) }
                GradientStop { position: 1; color: bar.accent }
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: parent.width * bar.v - width / 2
            visible: bar.v > 0.01
            width: 6
            height: 6
            radius: 3
            color: bar.accent
        }
    }

    // deco
    Item {
        visible: bar.st.bar === "deco"
        anchors.fill: parent

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 1
            color: Colors.withAlpha(bar.accent, 0.35)
        }

        Repeater {
            model: 3

            Rectangle {
                required property int index
                x: bar.width * (index + 1) / 4
                y: (bar.height - height) / 2
                width: 1
                height: 7
                color: Colors.withAlpha(bar.accent, 0.45)
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * bar.v
            height: 3
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.darker(bar.accent, 1.6) }
                GradientStop { position: 0.7; color: bar.accent }
                GradientStop { position: 1; color: Qt.lighter(bar.accent, 1.25) }
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: parent.width * bar.v - width / 2
            visible: bar.v > 0.01
            width: 7
            height: 7
            rotation: 45
            color: Qt.lighter(bar.accent, 1.3)
            border.width: 1
            border.color: "#0d0b08"
        }
    }

    // glass
    Rectangle {
        visible: bar.st.bar === "glass"
        anchors.fill: parent
        color: "#070606"

        Row {
            x: 1
            y: 1
            spacing: 2

            Repeater {
                model: 14

                Rectangle {
                    required property int index
                    readonly property var panes: [bar.accent, "#e0a83e", Services.DesktopTheme.accent2Of(bar.themeId), Qt.hsla((Math.max(0, bar.accent.hslHue) + 0.5) % 1, 0.7, 0.46, 1)]
                    readonly property bool lit: (index + 0.5) / 14 <= bar.v
                    width: (bar.width - 2 - 13 * 2) / 14
                    height: bar.height - 2
                    color: panes[index % 4]
                    opacity: lit ? 0.95 : 0.16
                }
            }
        }
    }

    // rule
    Item {
        visible: bar.st.bar === "rule"
        anchors.fill: parent

        Rectangle {
            width: parent.width
            height: 6
            color: "transparent"
            border.width: 1
            border.color: bar.ink

            Rectangle {
                x: 1
                y: 1
                width: (parent.width - 2) * bar.v
                height: parent.height - 2
                color: bar.accent
            }
        }

        Repeater {
            model: 9

            Rectangle {
                required property int index
                x: bar.width * (index + 1) / 10
                y: 6
                width: 1
                height: index === 4 ? 2 : 1
                color: bar.ink
            }
        }
    }

    // hazard
    Rectangle {
        visible: bar.st.bar === "hazard"
        anchors.fill: parent
        color: "#16120e"
        border.width: 1
        border.color: "#6c685f"

        HazardStripes {
            x: 1
            y: 1
            width: (parent.width - 2) * bar.v
            height: parent.height - 2
            stripe: 4
            colorA: bar.accent
            colorB: "#16120e"
        }
    }

    // vernier: a brass scale graduated in twentieths, read by a pointer.
    Item {
        visible: bar.st.bar === "vernier"
        anchors.fill: parent

        Rectangle {
            y: 3
            width: parent.width
            height: 1
            color: Colors.withAlpha(bar.accent, 0.45)
        }

        ScaleTicks {
            y: 3
            width: parent.width
            height: 6
            step: parent.width / 20
            major: 5
            minorLength: 3
            majorLength: 6
            color: Colors.withAlpha(bar.accent, 0.55)
        }

        Rectangle {
            y: 2
            width: parent.width * bar.v
            height: 3
            color: bar.accent
        }

        Text {
            x: parent.width * bar.v - width / 2
            y: -height + 6
            visible: bar.v > 0.005
            text: "▼"
            font.pixelSize: 8
            color: Qt.lighter(bar.accent, 1.2)
        }
    }

    // sonar: a lit tube with a bright head, bubbles rising off it.
    Item {
        visible: bar.st.bar === "sonar"
        anchors.fill: parent

        Rectangle {
            y: parent.height - 7
            width: parent.width
            height: 6
            radius: 3
            color: Colors.withAlpha("#02090e", 0.55)
            border.width: 1
            border.color: Colors.withAlpha(Services.DesktopTheme.accent2Of(bar.themeId), 0.3)

            Rectangle {
                x: 1
                y: 1
                width: Math.max(height, (parent.width - 2) * bar.v)
                height: parent.height - 2
                radius: height / 2
                visible: bar.v > 0.005
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Colors.withAlpha(bar.accent, 0.35) }
                    GradientStop { position: 1; color: Services.DesktopTheme.accent2Of(bar.themeId) }
                }
            }
        }

        Rectangle {
            x: parent.width * bar.v - width / 2
            y: parent.height - 4 - height / 2
            visible: bar.v > 0.005
            width: 9
            height: 9
            radius: 4.5
            color: Colors.withAlpha(Services.DesktopTheme.accent2Of(bar.themeId), 0.3)
        }

        Repeater {
            model: [{ dx: -3, dy: -9, s: 3 }, { dx: 2, dy: -13, s: 2 }]

            Rectangle {
                required property var modelData
                x: bar.width * bar.v + modelData.dx - width / 2
                y: bar.height + modelData.dy - height / 2
                visible: bar.v > 0.05
                width: modelData.s
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Colors.withAlpha(Services.DesktopTheme.accent2Of(bar.themeId), 0.7)
            }
        }
    }

    // mala: a string of prayer beads, told in gold up to the value, the guru
    // bead (meru) in the pigment at its head, with a tassel.
    Item {
        id: mala
        visible: bar.st.bar === "mala"
        anchors.fill: parent

        readonly property real span: width - 14
        readonly property int beads: Math.max(8, Math.floor(span / 9))
        readonly property color meru: Services.DesktopTheme.accent2Of(bar.themeId)

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: mala.span
            height: 1
            color: Colors.withAlpha(bar.accent, 0.4)
        }

        Repeater {
            model: mala.beads

            Rectangle {
                required property int index
                readonly property bool told: (index + 0.5) / mala.beads <= bar.v
                x: (index + 0.5) * mala.span / mala.beads - width / 2
                y: (mala.height - height) / 2
                width: 6
                height: 6
                radius: 3
                color: told ? bar.accent : Colors.withAlpha(bar.accent, 0.16)
                border.width: 1
                border.color: told ? Qt.lighter(bar.accent, 1.25) : Colors.withAlpha(bar.accent, 0.45)
            }
        }

        Rectangle {
            x: mala.span + 1
            anchors.verticalCenter: parent.verticalCenter
            width: 9
            height: 9
            radius: 4.5
            color: mala.meru
            border.width: 1
            border.color: bar.accent
        }

        Repeater {
            model: 3

            Rectangle {
                required property int index
                x: mala.span + 5 + (index - 1) * 2.2
                y: mala.height / 2 + 4
                width: 1
                height: 5 - Math.abs(index - 1)
                color: mala.meru
            }
        }
    }

    // sword: a sword drawn from its scabbard as far as the value: the hilt
    // at the start, the bared blade bright, the rest of it still sheathed
    // in leather of the tincture with a gilt locket at its mouth and a
    // chape at its tip.
    Item {
        id: sword
        visible: bar.st.bar === "sword"
        anchors.fill: parent

        readonly property real guard: 22
        readonly property real len: width - guard - 1
        readonly property real drawn: len * bar.v
        readonly property color steel: Services.DesktopTheme.accent2Of(bar.themeId)
        readonly property color gold: "#e3b24a"
        readonly property real mid: height / 2

        // The whole blade, most of it under the scabbard.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Colors.withAlpha("black", 0.55)
                strokeWidth: 0.5
                fillGradient: LinearGradient {
                    x1: 0
                    y1: sword.mid - 2.5
                    x2: 0
                    y2: sword.mid + 2.5
                    GradientStop { position: 0; color: Qt.lighter(sword.steel, 1.2) }
                    GradientStop { position: 0.5; color: sword.steel }
                    GradientStop { position: 0.52; color: Qt.darker(sword.steel, 1.35) }
                    GradientStop { position: 1; color: Qt.darker(sword.steel, 1.15) }
                }
                startX: sword.guard
                startY: sword.mid - 2.5
                PathLine { x: sword.width - 8; y: sword.mid - 2 }
                PathLine { x: sword.width; y: sword.mid }
                PathLine { x: sword.width - 8; y: sword.mid + 2 }
                PathLine { x: sword.guard; y: sword.mid + 2.5 }
                PathLine { x: sword.guard; y: sword.mid - 2.5 }
            }
        }

        Rectangle {
            x: sword.guard + 2
            y: sword.mid - 0.5
            width: Math.max(0, Math.min(sword.drawn, sword.len - 12) - 4)
            height: 1
            color: Qt.darker(sword.steel, 1.6)
        }

        // The scabbard, over what's still sheathed.
        Rectangle {
            visible: sword.drawn < sword.len - 1
            x: sword.guard + sword.drawn
            y: sword.mid - 3.5
            width: sword.len - sword.drawn + 1
            height: 7
            radius: 2
            color: Qt.hsla(Math.max(0, bar.accent.hslHue), 0.45, 0.2, 1)
            border.width: 0.5
            border.color: Colors.withAlpha("black", 0.7)

            Rectangle {
                width: 3
                height: parent.height
                color: sword.gold
            }

            Rectangle {
                anchors.right: parent.right
                width: Math.min(7, parent.width)
                height: parent.height
                radius: 2
                color: sword.gold
            }
        }

        // The hilt: pommel, grip and crossguard.
        Rectangle {
            x: 5
            y: sword.mid - 2
            width: sword.guard - 7
            height: 4
            color: "#3a2418"
        }

        Rectangle {
            y: sword.mid - 3.5
            width: 7
            height: 7
            radius: 3.5
            color: sword.gold
            border.width: 0.5
            border.color: Colors.withAlpha("black", 0.6)
        }

        Rectangle {
            x: sword.guard - 3
            y: sword.mid - 6
            width: 3
            height: 12
            radius: 1
            color: sword.gold
            border.width: 0.5
            border.color: Colors.withAlpha("black", 0.6)
        }
    }
}
