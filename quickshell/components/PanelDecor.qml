pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.services as Services

// The desktop theme's frame on a panel's outer surface. Put it last inside
// the surface (so it draws over the edges) and give it the surface's radius;
// it never takes input. HUD: accent hairline and corner brackets. Mainframe:
// console border, faint scanlines and a title tab. Astral: hairline with a
// glow along the top. Still: nothing. Cave Abode: double border and a seal.
Item {
    id: decor

    property real radius: 0
    // Mainframe's tab; empty for none.
    property string title: ""
    property string seal: "印"

    readonly property string shape: Services.DesktopTheme.look.shape
    readonly property color accent: shape === "seal" ? Colors.tertiary : Colors.primary

    anchors.fill: parent
    visible: Services.DesktopTheme.enabled && shape !== "soft"
    z: 1000

    // Hairline border (all but Still).
    Rectangle {
        anchors.fill: parent
        radius: decor.radius
        color: "transparent"
        border.width: 1
        border.color: Colors.withAlpha(decor.accent, decor.shape === "square" ? 0.5 : decor.shape === "seal" ? 0.55 : 0.32)
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
}
