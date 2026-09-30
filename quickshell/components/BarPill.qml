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
// newspaper deck, Wasteland's are riveted plates, Observatory's are
// graduated along the foot like an instrument's scale, Abyss's are backlit
// keys with a light strip, Devaloka's stand on a sari's temple border, and
// Siege's are cut into battlements along the top (CrenelMask). Widget
// colours are kept either way.
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
    readonly property bool crenel: look.shape === "crenel"
    // Shapes whose outline is a mask and a frame drawn over it.
    readonly property bool masked: hud || neon || deco || cusp || crenel

    signal clicked

    radius: Services.DesktopTheme.radius(root.look, 13, height)
    topLeftRadius: Services.DesktopTheme.corner(root.look, radius, 0)
    topRightRadius: Services.DesktopTheme.corner(root.look, radius, 1)
    bottomRightRadius: Services.DesktopTheme.corner(root.look, radius, 2)
    bottomLeftRadius: Services.DesktopTheme.corner(root.look, radius, 3)
    color: Colors.surface_container
    border.width: root.neon || root.deco || root.cusp || root.crenel || root.look.shape === "print" ? 0 : root.look.border
    border.color: Services.DesktopTheme.borderColor(root.look)
    layer.enabled: root.masked
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: maskLoader.item
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

    // Only the theme's own outline and trim are built (one mask, one set of
    // decorations): all of them at once, hidden, came to a dozen shapes per
    // pill, every one re-traced whenever a pill's text changed width.
    Loader {
        id: maskLoader
        anchors.fill: parent
        active: root.masked
        sourceComponent: root.neon ? neonMask : root.deco ? decoMask : root.cusp ? cuspMask : root.crenel ? crenelMask : hudMask
    }

    Loader {
        anchors.fill: parent
        sourceComponent: ({
            chamfer: hudTrim,
            neon: neonTrim,
            deco: decoTrim,
            cusp: cuspTrim,
            crenel: crenelTrim,
            print: printTrim,
            plate: plateTrim,
            scale: scaleTrim,
            zari: zariTrim,
            lume: lumeTrim
        })[root.look.shape] ?? null
    }

    Component {
        id: hudMask

        HudMask {
            active: true
        }
    }

    Component {
        id: neonMask

        NeonMask {
            active: true
        }
    }

    Component {
        id: decoMask

        DecoMask {
            active: true
            cut: 4
        }
    }

    Component {
        id: cuspMask

        CuspMask {
            active: true
            cut: 6
        }
    }

    Component {
        id: crenelMask

        CrenelMask {
            active: true
            merlon: 7
            depth: 3
        }
    }

    Component {
        id: hudTrim

        Item {
            HudTick {}
        }
    }

    Component {
        id: neonTrim

        Item {
            NeonFrame {
                cut: 7
                fill: "transparent"
                glow: 0
                inset: 1
            }
        }
    }

    Component {
        id: decoTrim

        Item {
            DecoFrame {
                cut: 4
                fill: "transparent"
                stroke: Services.DesktopTheme.borderColor(root.look)
                inset: 1
            }
        }
    }

    Component {
        id: cuspTrim

        Item {
            CuspFrame {
                cut: 6
                fill: "transparent"
                stroke: Services.DesktopTheme.borderColor(root.look)
                inset: 1
            }
        }
    }

    Component {
        id: crenelTrim

        Item {
            CrenelFrame {
                merlon: 7
                depth: 3
                fill: "transparent"
                stroke: Services.DesktopTheme.borderColor(root.look)
            }
        }
    }

    // Broadsheet: a thin rule above, a heavy one below.
    Component {
        id: printTrim

        Item {
            Rectangle {
                width: parent.width
                height: 1
                color: Services.DesktopTheme.borderColor(root.look)
            }

            Rectangle {
                y: parent.height - height
                width: parent.width
                height: 2
                color: Services.DesktopTheme.borderColor(root.look)
            }
        }
    }

    // Wasteland: bolted on at both ends.
    Component {
        id: plateTrim

        Item {
            Repeater {
                model: 2

                Rivet {
                    required property int index
                    size: 5
                    x: index === 0 ? 3 : root.width - width - 3
                    y: (root.height - height) / 2
                }
            }
        }
    }

    // Observatory: graduated along the foot.
    Component {
        id: scaleTrim

        Item {
            ScaleTicks {
                x: 5
                y: root.height - height - 1
                width: root.width - 10
                height: 4
                up: true
                step: 4
                major: 5
                minorLength: 1.5
                majorLength: 3.5
                color: Services.DesktopTheme.borderColor(root.look)
                opacity: 0.8
            }
        }
    }

    // Devaloka: a temple border along the foot.
    Component {
        id: zariTrim

        Item {
            TempleBorder {
                x: root.radius
                y: root.height - height - 1
                width: root.width - 2 * root.radius
                height: 3.5
                step: 5
                rule: 0
                color: Services.DesktopTheme.borderColor(root.look)
            }
        }
    }

    // Abyss: a strip of light along the foot, as under a backlit key.
    Component {
        id: lumeTrim

        Item {
            Item {
                x: root.radius
                y: root.height - 5
                width: root.width - 2 * root.radius
                height: 4

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -1
                    radius: 3
                    color: Colors.withAlpha(Services.DesktopTheme.accent2, 0.16)
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: 2
                    radius: 1
                    color: Colors.withAlpha(Services.DesktopTheme.accent2, 0.85)
                }
            }
        }
    }

    Process {
        id: proc
        command: root.command ?? []
    }
}
