pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.components
import qs.services as Services

// A 0..1 meter in the look of a desktop theme (WidgetStyle.bar): a rounded
// line, HUD segments, an ASCII gauge, an orbit with a glowing body, a
// hairline, a tapering brush stroke, a neon tube with a lit tip, a line of
// ink ending in a blot, a gilt bar with a diamond tip, a strip of leaded
// glass lighting pane by pane, a newspaper's ruled bar, or hazard tape in a
// steel channel.
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
        : ({ orbit: 10, segments: 6, neon: 6, ink: 6, hairline: 3, deco: 9, glass: 9, rule: 8, hazard: 9 })[st.bar] ?? 4

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
}
