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

    implicitHeight: 32

    property int maxWidth: 200

    property var media: Media
    visible: media.activePlayer !== null

    implicitWidth: Math.min(pill.implicitWidth, maxWidth)

    Rectangle {
        id: pill
        anchors.fill: parent

        // Desktop themes restyle the capsule; the HUD theme's is a chamfered
        // frame, Neon Noir's a cut-corner one, Art Deco's steps in at the
        // corners, Cathedral's is cusped, Broadsheet's ruled and
        // Wasteland's riveted.
        readonly property var look: DesktopTheme.look
        readonly property bool hud: look.shape === "chamfer"
        readonly property bool neon: look.shape === "neon"
        readonly property bool deco: look.shape === "deco"
        readonly property bool cusp: look.shape === "cusp"
        readonly property bool framed: hud || neon || deco || cusp
        radius: DesktopTheme.radius(look, height / 2, height)
        topLeftRadius: DesktopTheme.corner(look, radius, 0)
        topRightRadius: DesktopTheme.corner(look, radius, 1)
        bottomRightRadius: DesktopTheme.corner(look, radius, 2)
        bottomLeftRadius: DesktopTheme.corner(look, radius, 3)
        border.width: framed || look.shape === "print" ? 0 : look.border
        border.color: DesktopTheme.borderColor(look)
        height: 32
        color: framed ? "transparent" : Colors.background

        clip: true

        HudFrame {
            visible: pill.hud
            fill: Colors.background
        }

        NeonFrame {
            visible: pill.neon
            cut: 9
            fill: Colors.background
            glow: 0.5
        }

        DecoFrame {
            visible: pill.deco
            cut: 4
            steps: 2
            fill: Colors.background
            stroke: DesktopTheme.borderColor(pill.look)
        }

        CuspFrame {
            visible: pill.cusp
            cut: 8
            fill: Colors.background
            stroke: DesktopTheme.borderColor(pill.look)
        }

        Rectangle {
            visible: pill.look.shape === "print"
            width: parent.width
            height: 2
            color: DesktopTheme.borderColor(pill.look)
        }

        Rectangle {
            visible: pill.look.shape === "print"
            y: parent.height - 1
            width: parent.width
            height: 1
            color: DesktopTheme.borderColor(pill.look)
        }

        Repeater {
            model: pill.look.shape === "plate" ? 2 : 0

            Rivet {
                required property int index
                size: 5
                x: index === 0 ? 3 : pill.width - width - 3
                y: (pill.height - height) / 2
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

            Item {
                Layout.fillWidth: true
                Layout.preferredWidth: root.maxWidth - 20
                Layout.preferredHeight: mediaText.height
                clip: true

                Row {
                    id: marqueeRow
                    spacing: 50

                    StyledText {
                        id: mediaText
                        text: media.artist
                            ? media.title + " — " + media.artist
                            : media.title

                        font.pixelSize: 17
                    }

                    StyledText {
                        visible: mouseArea.containsMouse
                        text: mediaText.text
                        font.pixelSize: 17
                    }

                    SequentialAnimation {
                        id: marqueeAnimation
                        running: mouseArea.containsMouse
                        loops: Animation.Infinite

                        PauseAnimation { duration: 2000 }

                        NumberAnimation {
                            target: marqueeRow
                            property: "x"
                            from: 0
                            to: -(mediaText.implicitWidth + marqueeRow.spacing)
                            duration: (mediaText.implicitWidth + marqueeRow.spacing) * 20
                            easing.type: Easing.Linear
                        }

                        PropertyAction {
                            target: marqueeRow
                            property: "x"
                            value: 0
                        }
                    }

                    // Reset position when mouse leaves
                    Behavior on x {
                        enabled: !mouseArea.containsMouse
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }

        MouseArea {
            id: mouseArea
            onClicked: toggleProc.running = true
            onExited: marqueeRow.x = 0  // Reset position when mouse leaves
            anchors.fill: parent
            z: 2
            hoverEnabled: true
        }
    }

    Process {
        id: toggleProc
        command: ["qs", "ipc", "call", "mediaPanel", "toggle"]
    }
}