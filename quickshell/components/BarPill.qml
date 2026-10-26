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
// keys with a light strip, Devaloka's stand on a sari's temple border,
// Siege's are cut into battlements along the top (CrenelMask), and Sekiro's
// taper to a point at each end like the posture gauge (PostureMask).
// Widget colours are kept either way.
//
// Its colours are the bar settings' (services/BarSettings): the wallpaper's
// container surface by default, or a tone or colour picked there, faded by
// the transparency set there, with an outline round it when that's on and
// the theme draws none of its own.
//
// Its width is its text's, or the width set for its widget (`barId`) in
// the bar settings; `maxWidth` (0 = unbounded) caps the first, for the
// pills with variable-length labels. Text that doesn't fit is cut short
// and scrolled through like the media pill's (components/MarqueeText), on
// hover, always or never as the settings say.
//
// A widget that opens a panel names it in `opens` (a services/Opening
// target): a click opens it, or the pointer resting on it when the bar's
// panels are set to open on hover. `opensArg` gives what the panel needs
// to hang from it (the calendar: where the clock sits).
//
// On a standing bar (left or right screen edge) the bar sets `vertical`: the
// pill keeps its thickness and shows a compact upright face instead, `vIcon`
// over `vLabel`, each shrunk to fit. By default the text splits at its first
// space (glyph, then value); widgets whose text doesn't split that way set
// them.
Rectangle {
    id: root

    property alias text: label.text
    property color textColor: Services.BarSettings.ink
    property int fontPixelSize: 17
    property int horizontalPadding: 16
    property int maxWidth: 0
    property bool vertical: false
    // Which of the bar's widgets this is (TopBar and the settings' preview
    // set it), for the width set for it.
    property string barId: ""
    // Hovered, as far as scrolling goes, when something over the pill takes
    // the pointer (the settings' preview).
    property bool forceHover: false
    // The width set for it (0: as wide as its text), on a lying bar: a
    // standing one keeps its upright face.
    readonly property real setWidth: root.vertical ? 0 : Services.BarSettings.widthOf(root.barId)
    // As wide as its text, with its padding.
    readonly property real naturalWidth: label.implicitWidth + root.horizontalPadding
    readonly property var _parts: {
        const t = root.text;
        const i = t.indexOf(" ");
        return i < 0 ? [t, ""] : [t.slice(0, i), t.slice(i + 1).trim()];
    }
    property string vIcon: root._parts[0]
    property string vLabel: root._parts[1]
    property int vIconSize: 15
    property int vLabelSize: 11
    // Optional command to run on click, e.g. ["qs", "ipc", "call", "controlCenter", "changeVisible"].
    property var command: null
    // The panel it opens (see above), and a function giving its argument.
    property string opens: ""
    property var opensArg: null
    // Drawn as a picture of itself (the customizer's plates): it opens
    // nothing.
    property bool preview: false
    property bool interactive: root.command !== null || root.opens !== ""
    property alias cursorShape: mouse.cursorShape
    readonly property var look: Services.DesktopTheme.look
    readonly property bool hud: look.shape === "chamfer"
    readonly property bool neon: look.shape === "neon"
    readonly property bool deco: look.shape === "deco"
    readonly property bool cusp: look.shape === "cusp"
    readonly property bool crenel: look.shape === "crenel"
    readonly property bool posture: look.shape === "posture"
    // Shapes whose outline is a mask and a frame drawn over it.
    readonly property bool masked: hud || neon || deco || cusp || crenel || posture

    signal clicked

    radius: Services.DesktopTheme.radius(root.look, 13, Math.min(width, height))
    topLeftRadius: Services.DesktopTheme.corner(root.look, radius, 0)
    topRightRadius: Services.DesktopTheme.corner(root.look, radius, 1)
    bottomRightRadius: Services.DesktopTheme.corner(root.look, radius, 2)
    bottomLeftRadius: Services.DesktopTheme.corner(root.look, radius, 3)
    color: Services.BarSettings.pill
    border.width: root.neon || root.deco || root.cusp || root.crenel || root.posture || root.look.shape === "print" ? 0 : root.look.border || (Services.BarSettings.outline ? 1 : 0)
    border.color: root.look.border ? Services.DesktopTheme.borderColor(root.look) : Services.BarSettings.outlineColor
    layer.enabled: root.masked
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: maskLoader.item
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
    implicitHeight: root.vertical ? upright.implicitHeight + 12 : 28
    implicitWidth: root.vertical ? 28
        : root.setWidth > 0 ? root.setWidth
        : root.maxWidth > 0 ? Math.min(root.naturalWidth, root.maxWidth)
        : root.naturalWidth

    function _arg() {
        return typeof root.opensArg === "function" ? root.opensArg() : root.opensArg;
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (!root.opens || root.preview)
                return;
            if (hovered)
                Services.Opening.entered(root.opens, root._arg());
            else
                Services.Opening.left(root.opens);
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive && !root.preview
        onClicked: {
            if (root.opens)
                Services.Opening.clicked(root.opens, root._arg());
            else if (root.command)
                proc.running = true;
            root.clicked();
        }
    }

    MarqueeText {
        id: label
        anchors.centerIn: parent
        width: Math.max(0, root.width - root.horizontalPadding)
        visible: !root.vertical
        color: root.textColor
        font.pixelSize: root.fontPixelSize + root.look.sizeDelta
        font.family: root.look.font || defaultFont.font.family
        font.weight: root.look.weight
        font.letterSpacing: root.look.letterSpacing
        font.capitalization: root.look.caps === "small" ? Font.SmallCaps : root.look.caps ? Font.AllUppercase : Font.MixedCase
        mode: Services.BarSettings.overflow
        speed: Services.BarSettings.scrollPxPerSecond
        hovered: hover.hovered || root.forceHover
    }

    // The upright face, on a standing bar.
    Column {
        id: upright
        anchors.centerIn: parent
        visible: root.vertical
        spacing: 1

        StyledText {
            id: vIconText
            width: root.width - 4
            visible: root.vertical && text !== ""
            text: root.vIcon
            // Centred by its ink, not its advance: Nerd Font glyphs such as
            // the Wi-Fi fans draw wider than they advance, and spill right.
            transform: Translate {
                x: root.vertical ? (iconInk.advanceWidth - iconInk.tightBoundingRect.width) / 2 - iconInk.tightBoundingRect.x : 0
            }

            TextMetrics {
                id: iconInk
                font: vIconText.font
                text: root.vertical ? root.vIcon : ""
            }
            horizontalAlignment: Text.AlignHCenter
            color: root.textColor
            font.pixelSize: root.vIconSize + root.look.sizeDelta
            font.family: root.look.font || defaultFont.font.family
            font.weight: root.look.weight
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 7
            maximumLineCount: 1
        }

        StyledText {
            width: root.width - 4
            visible: root.vertical && text !== ""
            text: root.vLabel
            horizontalAlignment: Text.AlignHCenter
            color: root.textColor
            font.pixelSize: root.vLabelSize + root.look.sizeDelta
            font.family: root.look.font || defaultFont.font.family
            font.weight: root.look.weight
            font.capitalization: root.look.caps === "small" ? Font.SmallCaps : root.look.caps ? Font.AllUppercase : Font.MixedCase
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 7
            maximumLineCount: 1
        }
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
        sourceComponent: root.neon ? neonMask : root.deco ? decoMask : root.cusp ? cuspMask : root.crenel ? crenelMask : root.posture ? postureMask : hudMask
    }

    Loader {
        anchors.fill: parent
        sourceComponent: ({
            chamfer: hudTrim,
            neon: neonTrim,
            deco: decoTrim,
            cusp: cuspTrim,
            crenel: crenelTrim,
            posture: postureTrim,
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
        id: postureMask

        PostureMask {
            active: true
            taper: 9
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

    Component {
        id: postureTrim

        Item {
            PostureFrame {
                taper: 9
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
