pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.colors
import qs.components

// The body of a desktop widget in the look of a desktop theme (WidgetStyle):
// a Material card, a chamfered HUD panel, a console box with its title on a
// tab, a glass pane, nothing at all (text shadow only), or a paper slip with
// a seal. Children stack in a Column under the title.
Item {
    id: frame

    property string themeId
    property string title
    // Character on the Cave Abode seal.
    property string seal: "印"
    property real spacing: 10
    default property alias content: body.data

    readonly property var st: WidgetStyle.of(themeId)
    readonly property color accent: Colors[st.accentRole]
    readonly property bool isConsole: st.frame === "console"
    readonly property bool hasTitle: title.length > 0 && !isConsole
    // Room above the console box for its title tab, which straddles the top
    // edge: a widget's surface ends at its frame, so it would be cut off.
    readonly property real tabRoom: isConsole && title.length > 0 ? 10 : 0

    implicitWidth: body.implicitWidth + st.pad * 2
    implicitHeight: tabRoom + body.implicitHeight + st.pad * 2 + (hasTitle ? titleText.implicitHeight + frame.spacing : 0)

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

    Text {
        id: titleText
        x: frame.st.pad
        y: frame.st.pad
        visible: frame.hasTitle
        text: (frame.st.frame === "chamfer" ? "▸ " : "") + WidgetStyle.label(frame.title, frame.st)
        font.family: frame.st.cjk ?? (frame.st.frame === "chamfer" ? frame.st.mono : frame.st.font)
        font.pixelSize: 11
        font.weight: frame.st.frame === "chamfer" ? Font.Bold : Font.Medium
        font.letterSpacing: frame.st.labelSpacing
        color: Colors[frame.st.labelRole]
    }

    Column {
        id: body
        x: frame.st.pad
        y: frame.tabRoom + frame.st.pad + (frame.hasTitle ? titleText.implicitHeight + frame.spacing : 0)
        spacing: frame.spacing
    }
}
