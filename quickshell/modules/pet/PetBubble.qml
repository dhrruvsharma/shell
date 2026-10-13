pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.colors
import qs.components
import qs.services as Services

// The pet's speech bubble (services/Pet.qml say()): a small window hanging
// from the bar by the pet (under it, over it on a bottom bar, beside it on a
// standing one), up for a few seconds. It exists only while it's showing,
// and clicks pass through it.
Scope {
    id: root

    property bool up: false
    property string text: ""
    // Where the pet was along the bar.
    property real anchorPos: 0
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
            root.anchorPos = Services.Pet.barPos;
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
            readonly property string edge: Services.BarLayout.edge
            readonly property bool vertical: Services.BarLayout.vertical
            readonly property real screenW: screen ? screen.width : 1920
            readonly property real screenH: screen ? screen.height : 1200
            // Its start along the bar: centred on the pet, kept on screen.
            readonly property real start: vertical
                ? Math.max(8, Math.min(screenH - height - 8, root.anchorPos - height / 2))
                : Math.max(8, Math.min(screenW - width - 8, root.anchorPos - width / 2))

            anchors.top: edge !== "bottom"
            anchors.bottom: edge === "bottom"
            anchors.left: edge !== "right"
            anchors.right: edge === "right"
            margins.top: edge === "top" ? 44 : vertical ? start : 0
            margins.bottom: edge === "bottom" ? 44 : 0
            margins.left: edge === "left" ? 44 : vertical ? 0 : start
            margins.right: edge === "right" ? 44 : 0
            // Room round the card for the tail, on the side facing the bar.
            implicitWidth: card.width + (vertical ? 16 : 12)
            implicitHeight: card.height + 16
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:pet-bubble"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            color: "transparent"
            mask: Region {}

            Item {
                id: card

                // Where the tail meets the card's side facing the bar.
                readonly property real tailAt: win.vertical
                    ? Math.max(16, Math.min(height - 16, root.anchorPos - win.start - 8))
                    : Math.max(16, Math.min(width - 16, root.anchorPos - win.start - 6))
                x: win.vertical ? 8 : 6
                y: 8
                width: Math.min(win.maxW, label.implicitWidth + 28)
                height: label.implicitHeight + 18
                opacity: root.shown
                scale: 0.85 + 0.15 * root.shown
                transformOrigin: ({ top: Item.Top, bottom: Item.Bottom, left: Item.Left, right: Item.Right })[win.edge]

                // The tail, pointing at the pet.
                Rectangle {
                    x: win.edge === "left" ? -5 : win.edge === "right" ? card.width - 6 : card.tailAt - width / 2
                    y: win.edge === "top" ? -5 : win.edge === "bottom" ? card.height - 6 : card.tailAt - height / 2
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
                    x: win.edge === "left" ? 1 : win.edge === "right" ? card.width - 7 : card.tailAt - 7
                    y: win.edge === "top" ? 1 : win.edge === "bottom" ? card.height - 7 : card.tailAt - 7
                    width: win.vertical ? 6 : 14
                    height: win.vertical ? 14 : 6
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
