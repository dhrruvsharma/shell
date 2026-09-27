pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell.Io
import qs.colors
import qs.services as Services

// One island atom in the top bar: a 28px rounded pill with centred text.
// A desktop theme restyles it through `look` (shape, type, hairline border);
// the HUD theme's chamfered tags are masked with HudMask and get an accent
// tick. Widget colours are kept either way.
//
// `maxWidth` (0 = unbounded) turns on the truncating behaviour — clip + elide —
// that only the pills with variable-length labels used.
Rectangle {
    id: root

    property alias text: label.text
    property color textColor: Colors.on_surface
    property int fontPixelSize: 17
    property int horizontalPadding: 16
    property int maxWidth: 0
    // Optional command to run on click, e.g. ["qs", "ipc", "call", "systemPanel", "toggle"].
    property var command: null
    property bool interactive: root.command !== null
    property alias cursorShape: mouse.cursorShape
    readonly property var look: Services.DesktopTheme.look
    readonly property bool hud: look.shape === "chamfer"

    signal clicked

    radius: Services.DesktopTheme.radius(root.look, 13, height)
    color: Colors.surface_container
    border.width: root.look.border
    border.color: Services.DesktopTheme.borderColor(root.look)
    layer.enabled: root.hud
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: hudMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
    implicitHeight: 28
    clip: root.maxWidth > 0
    implicitWidth: root.maxWidth > 0
        ? Math.min(label.implicitWidth + root.horizontalPadding, root.maxWidth)
        : label.implicitWidth + root.horizontalPadding

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive
        onClicked: {
            if (root.command)
                proc.running = true;
            root.clicked();
        }
    }

    StyledText {
        id: label
        anchors.centerIn: parent
        color: root.textColor
        font.pixelSize: root.fontPixelSize + root.look.sizeDelta
        font.family: root.look.font || defaultFont.font.family
        font.weight: root.look.weight
        font.letterSpacing: root.look.letterSpacing
        elide: root.maxWidth > 0 ? Text.ElideRight : Text.ElideNone
        maximumLineCount: 1
    }

    // The shell's default family, to return to when the theme is off.
    Text {
        id: defaultFont
        visible: false
    }

    HudMask {
        id: hudMask
        active: root.hud
    }

    HudTick {
        visible: root.hud
    }

    Process {
        id: proc
        command: root.command ?? []
    }
}
