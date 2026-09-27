pragma ComponentBehavior: Bound
import QtQuick
import qs.colors

// A 0..1 meter in the look of a desktop theme (WidgetStyle.bar): a rounded
// line, HUD segments, an ASCII gauge, an orbit with a glowing body, a
// hairline, or a tapering brush stroke.
Item {
    id: bar

    property string themeId
    property real value: 0
    readonly property var st: WidgetStyle.of(themeId)
    readonly property color accent: Colors[st.accentRole]
    readonly property real v: Math.max(0, Math.min(1, value))
    readonly property color track: Colors.withAlpha(Colors.on_surface, 0.14)

    implicitWidth: st.bar === "ascii" ? ascii.implicitWidth : 200
    implicitHeight: st.bar === "ascii" ? ascii.implicitHeight : st.bar === "orbit" ? 10 : st.bar === "segments" ? 6 : st.bar === "hairline" ? 3 : 4

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
}
