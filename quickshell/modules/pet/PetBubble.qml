pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.colors
import qs.components
import qs.services as Services

// The pet's speech bubble (services/Pet.qml say()): a small window hanging
// under the bar beneath the pet, up for a few seconds. It exists only while
// it's showing, and clicks pass through it.
Scope {
    id: root

    property bool up: false
    property string text: ""
    property real anchorX: 0
    property real shown: 0

    Behavior on shown {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    Connections {
        target: Services.Pet

        function onBubbleSerialChanged() {
            // With the hub open, it speaks in the hub instead.
            if (!Services.Pet.shown || Services.Pet.hubOpen)
                return;
            root.text = Services.Pet.bubbleText;
            root.anchorX = Services.Pet.barX;
            root.up = true;
            root.shown = 1;
            hideTimer.interval = Services.Pet.bubbleMs;
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        onTriggered: root.shown = 0
    }

    // Unloads once the fade-out is done.
    Timer {
        interval: 200
        running: root.up && root.shown === 0
        onTriggered: root.up = false
    }

    LazyLoader {
        active: root.up

        PanelWindow {
            id: win

            readonly property real maxW: 300
            readonly property real screenW: screen ? screen.width : 1920
            readonly property real leftEdge: Math.max(8, Math.min(screenW - width - 8, root.anchorX - width / 2))

            anchors.top: true
            anchors.left: true
            margins.top: 44
            margins.left: leftEdge
            implicitWidth: card.width + 12
            implicitHeight: card.height + 16
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:pet-bubble"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            color: "transparent"
            mask: Region {}

            Item {
                id: card

                readonly property real tailX: Math.max(16, Math.min(width - 16, root.anchorX - win.leftEdge - 6))
                x: 6
                y: 8
                width: Math.min(win.maxW, label.implicitWidth + 28)
                height: label.implicitHeight + 18
                opacity: root.shown
                scale: 0.85 + 0.15 * root.shown
                transformOrigin: Item.Top

                // The tail, pointing up at the pet.
                Rectangle {
                    x: card.tailX - width / 2
                    y: -5
                    width: 11
                    height: 11
                    rotation: 45
                    color: body.color
                    border.width: 1
                    border.color: body.border.color
                }

                Rectangle {
                    id: body
                    anchors.fill: parent
                    radius: Services.DesktopTheme.panelRadius(14)
                    color: Colors.surface_container_high
                    border.width: 1
                    border.color: Services.DesktopTheme.enabled && Services.DesktopTheme.look.border
                        ? Services.DesktopTheme.borderColor(Services.DesktopTheme.look)
                        : Colors.withAlpha(Colors.outline_variant, 0.8)
                }

                // Covers the tail's base where it meets the body.
                Rectangle {
                    x: card.tailX - 7
                    y: 1
                    width: 14
                    height: 6
                    color: body.color
                }

                StyledText {
                    id: label
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, win.maxW - 28)
                    text: root.text
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 14
                    color: Colors.on_surface
                }
            }
        }
    }
}
