import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.services
import Quickshell.Io
import qs.colors
import qs.components

Item {
    id: root

    // Its width: as set in the bar settings while the bar lies along the
    // top or bottom, else 200. A title that doesn't fit scrolls through
    // (components/MarqueeText) on hover, always or never, as set there too.
    property int maxWidth: (!BarLayout.vertical && BarSettings.widthOf("media")) || BarSettings.autoWidths.media

    property var media: Media
    // While something plays, unless it's hidden in the bar settings.
    visible: media.activePlayer !== null && BarSettings.shown("media")

    // The capsule lies along the bar. On a standing bar it is turned on its
    // side (reading up a left bar and down a right one, the tops of the
    // letters to the screen's edge) and this item swaps width and height to
    // match.
    readonly property bool vertical: BarLayout.vertical
    readonly property real length: Math.min(pill.implicitWidth, maxWidth)
    implicitWidth: vertical ? 32 : length
    implicitHeight: vertical ? length : 32

    Item {
        id: capsule
        anchors.centerIn: parent
        width: root.length
        height: 32
        rotation: !root.vertical ? 0 : BarLayout.atLeft ? -90 : 90

        Rectangle {
            id: pill
            anchors.fill: parent

            // Desktop themes restyle the capsule; the HUD theme's is a chamfered
            // frame, Neon Noir's a cut-corner one, Art Deco's steps in at the
            // corners, Cathedral's is cusped, Broadsheet's ruled, Wasteland's
            // riveted, Observatory's graduated, Abyss's lit from below,
            // Devaloka's bordered like a sari, Siege's cut into battlements and
            // Sekiro's tapered like the posture gauge.
            readonly property var look: DesktopTheme.look
            readonly property bool hud: look.shape === "chamfer"
            readonly property bool neon: look.shape === "neon"
            readonly property bool deco: look.shape === "deco"
            readonly property bool cusp: look.shape === "cusp"
            readonly property bool crenel: look.shape === "crenel"
            readonly property bool posture: look.shape === "posture"
            readonly property bool framed: hud || neon || deco || cusp || crenel || posture
            radius: DesktopTheme.radius(look, height / 2, height)
            topLeftRadius: DesktopTheme.corner(look, radius, 0)
            topRightRadius: DesktopTheme.corner(look, radius, 1)
            bottomRightRadius: DesktopTheme.corner(look, radius, 2)
            bottomLeftRadius: DesktopTheme.corner(look, radius, 3)
            // Its colours are the bar settings' (services/BarSettings), as
            // the widgets' are.
            border.width: framed || look.shape === "print" ? 0 : look.border || (BarSettings.outline ? 1 : 0)
            border.color: look.border ? DesktopTheme.borderColor(look) : BarSettings.outlineColor
            color: framed ? "transparent" : BarSettings.capsule

            clip: true

            // Only the theme's own capsule is built: every theme's, hidden,
            // were half a dozen shapes re-traced as the title changed width.
            Loader {
                anchors.fill: parent
                sourceComponent: ({
                    chamfer: hudCapsule,
                    neon: neonCapsule,
                    deco: decoCapsule,
                    cusp: cuspCapsule,
                    crenel: crenelCapsule,
                    posture: postureCapsule,
                    print: printCapsule,
                    plate: plateCapsule,
                    scale: scaleCapsule,
                    zari: zariCapsule,
                    lume: lumeCapsule
                })[pill.look.shape] ?? null
            }

            Component {
                id: hudCapsule

                HudFrame {
                    fill: BarSettings.capsule
                }
            }

            Component {
                id: neonCapsule

                NeonFrame {
                    cut: 9
                    fill: BarSettings.capsule
                    glow: 0.5
                }
            }

            Component {
                id: decoCapsule

                DecoFrame {
                    cut: 4
                    steps: 2
                    fill: BarSettings.capsule
                    stroke: DesktopTheme.borderColor(pill.look)
                }
            }

            Component {
                id: cuspCapsule

                CuspFrame {
                    cut: 8
                    fill: BarSettings.capsule
                    stroke: DesktopTheme.borderColor(pill.look)
                }
            }

            Component {
                id: crenelCapsule

                CrenelFrame {
                    merlon: 8
                    depth: 3.5
                    fill: BarSettings.capsule
                    stroke: DesktopTheme.borderColor(pill.look)
                }
            }

            Component {
                id: postureCapsule

                PostureFrame {
                    taper: 11
                    fill: BarSettings.capsule
                    stroke: DesktopTheme.borderColor(pill.look)
                    tick: 3
                }
            }

            Component {
                id: printCapsule

                Item {
                    Rectangle {
                        width: parent.width
                        height: 2
                        color: DesktopTheme.borderColor(pill.look)
                    }

                    Rectangle {
                        y: parent.height - 1
                        width: parent.width
                        height: 1
                        color: DesktopTheme.borderColor(pill.look)
                    }
                }
            }

            Component {
                id: plateCapsule

                Item {
                    Repeater {
                        model: 2

                        Rivet {
                            required property int index
                            size: 5
                            x: index === 0 ? 3 : pill.width - width - 3
                            y: (pill.height - height) / 2
                        }
                    }
                }
            }

            Component {
                id: scaleCapsule

                Item {
                    ScaleTicks {
                        x: 6
                        y: pill.height - height - 1
                        width: pill.width - 12
                        height: 4
                        up: true
                        step: 4
                        major: 5
                        minorLength: 1.5
                        majorLength: 3.5
                        color: DesktopTheme.borderColor(pill.look)
                        opacity: 0.8
                    }
                }
            }

            Component {
                id: zariCapsule

                Item {
                    TempleBorder {
                        x: pill.radius
                        y: pill.height - height - 1
                        width: pill.width - 2 * pill.radius
                        height: 3.5
                        step: 5
                        rule: 0
                        color: DesktopTheme.borderColor(pill.look)
                    }
                }
            }

            Component {
                id: lumeCapsule

                Item {
                    Rectangle {
                        x: pill.radius
                        y: pill.height - 4
                        width: pill.width - 2 * pill.radius
                        height: 2
                        radius: 1
                        color: Colors.withAlpha(DesktopTheme.accent2, 0.85)
                    }
                }
            }

            implicitWidth: row.implicitWidth + 20

            RowLayout {
                id: row

                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: 10
                    rightMargin: 10
                }

                spacing: 8
                z: 1

                MarqueeText {
                    Layout.fillWidth: true
                    Layout.preferredWidth: root.maxWidth - 20
                    Layout.preferredHeight: implicitHeight
                    text: media.artist
                        ? media.title + " — " + media.artist
                        : media.title
                    color: BarSettings.ink
                    font.pixelSize: 17
                    gap: 50
                    mode: BarSettings.overflow
                    speed: BarSettings.scrollPxPerSecond
                    hovered: mouseArea.containsMouse
                }
            }

            MouseArea {
                id: mouseArea
                onClicked: toggleProc.running = true
                anchors.fill: parent
                z: 2
                hoverEnabled: true
            }
        }
    }

    Process {
        id: toggleProc
        command: ["qs", "ipc", "call", "mediaPanel", "toggle"]
    }
}