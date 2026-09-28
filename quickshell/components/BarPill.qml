pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell.Io
import qs.colors
import qs.services as Services

// One island atom in the top bar: a 28px rounded pill with centred text.
// A desktop theme restyles it through `look` (shape, type, hairline border);
// the HUD theme's chamfered tags are masked with HudMask and get an accent
// tick, Neon Noir's cut-corner tags are masked with NeonMask under a neon
// outline, Wabi-sabi's pebbles round each corner differently, Art Deco's
// step in at the corners under a gold line (DecoMask), Cathedral's are
// cusped (CuspMask), Broadsheet's are ruled above and below like a
// newspaper deck, and Wasteland's are riveted plates. Widget colours are
// kept either way.
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
    readonly property bool neon: look.shape === "neon"
    readonly property bool deco: look.shape === "deco"
    readonly property bool cusp: look.shape === "cusp"
    // Shapes whose outline is a mask and a frame drawn over it.
    readonly property bool masked: hud || neon || deco || cusp

    signal clicked

    radius: Services.DesktopTheme.radius(root.look, 13, height)
    topLeftRadius: Services.DesktopTheme.corner(root.look, radius, 0)
    topRightRadius: Services.DesktopTheme.corner(root.look, radius, 1)
    bottomRightRadius: Services.DesktopTheme.corner(root.look, radius, 2)
    bottomLeftRadius: Services.DesktopTheme.corner(root.look, radius, 3)
    color: Colors.surface_container
    border.width: root.neon || root.deco || root.cusp || root.look.shape === "print" ? 0 : root.look.border
    border.color: Services.DesktopTheme.borderColor(root.look)
    layer.enabled: root.masked
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: root.neon ? neonMask : root.deco ? decoMask : root.cusp ? cuspMask : hudMask
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
        font.capitalization: root.look.caps === "small" ? Font.SmallCaps : root.look.caps ? Font.AllUppercase : Font.MixedCase
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

    NeonMask {
        id: neonMask
        active: root.neon
    }

    NeonFrame {
        visible: root.neon
        cut: 7
        fill: "transparent"
        glow: 0
        inset: 1
    }

    DecoMask {
        id: decoMask
        active: root.deco
        cut: 4
    }

    DecoFrame {
        visible: root.deco
        cut: 4
        fill: "transparent"
        stroke: Services.DesktopTheme.borderColor(root.look)
        inset: 1
    }

    CuspMask {
        id: cuspMask
        active: root.cusp
        cut: 6
    }

    CuspFrame {
        visible: root.cusp
        cut: 6
        fill: "transparent"
        stroke: Services.DesktopTheme.borderColor(root.look)
        inset: 1
    }

    // Broadsheet: a thin rule above, a heavy one below.
    Rectangle {
        visible: root.look.shape === "print"
        width: parent.width
        height: 1
        color: Services.DesktopTheme.borderColor(root.look)
    }

    Rectangle {
        visible: root.look.shape === "print"
        y: parent.height - height
        width: parent.width
        height: 2
        color: Services.DesktopTheme.borderColor(root.look)
    }

    // Wasteland: bolted on at both ends.
    Repeater {
        model: root.look.shape === "plate" ? 2 : 0

        Rivet {
            required property int index
            size: 5
            x: index === 0 ? 3 : root.width - width - 3
            y: (root.height - height) / 2
        }
    }

    Process {
        id: proc
        command: root.command ?? []
    }
}
