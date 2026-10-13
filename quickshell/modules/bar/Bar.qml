import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.colors
import qs.components
import qs.services as Services

// The bar's surfaces, on whichever screen edge Services.BarLayout.edge says.
//
//  - zone: an invisible sliver along that edge holding the bar's exclusive
//    zone, so windows (and the panels that respect it) keep clear of the bar.
//  - bar: the bar itself (TopBar), in a surface of its own that ignores
//    exclusive zones, so it can grow without moving any window.
//
// Moving the bar: press an empty stretch of it and drag towards another
// edge; the edge it would land on lights up, and letting go moves it there.
// While the bar is held its surface covers the screen (the bar stays where
// it is inside it, like a desktop widget being dragged) and rises to the
// overlay layer, so the drag never leaves it: Hyprland only keeps a held
// pointer on the surface it was pressed on while some window has the
// keyboard, and Qt hears no release once the pointer has gone elsewhere.
//
// The bar's outermost two pixels don't take the mouse, so the hover strips
// on the screen's edges (shell.qml) still work where the bar lies over them.
Scope {
    id: root

    // A panel drawn over the bar is open: the bar drops beneath it.
    property bool coveredByPanel: false

    readonly property string edge: Services.BarLayout.edge
    readonly property bool vertical: Services.BarLayout.vertical
    readonly property int size: Services.BarLayout.size

    PanelWindow {
        id: zone

        WlrLayershell.namespace: "quickshell:bar-zone"
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: root.size
        anchors {
            top: root.edge !== "bottom"
            bottom: root.edge !== "top"
            left: root.edge !== "right"
            right: root.edge !== "left"
        }
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        mask: Region {}
    }

    // The bar's own 42px surface: hover animations and value updates in it
    // repaint a thin strip instead of the fullscreen panel surface. Declared
    // (in shell.qml) after the panel surface so it stacks above it on the Top
    // layer.
    //
    // Inside the old shared surface, panels declared after TopBar drew over
    // it while the ones before it (media, GitHub, system, updates, network,
    // which hang from the bar) drew under it. To keep that, the bar drops to
    // the Bottom layer — beneath the panels — while any of the later panels
    // is open. The layer changes in place (layer-shell set_layer), no remap.
    PanelWindow {
        id: bar

        WlrLayershell.namespace: "quickshell:bar"
        WlrLayershell.layer: bar.held ? WlrLayer.Overlay : root.coveredByPanel ? WlrLayer.Bottom : WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        readonly property real screenW: screen ? screen.width : 1920
        readonly property real screenH: screen ? screen.height : 1200
        // Where the bar's strip lies on the screen.
        readonly property real stripX: root.edge === "right" ? bar.screenW - root.size : 0
        readonly property real stripY: root.edge === "bottom" ? bar.screenH - root.size : 0

        // Pressed on an empty stretch: the surface covers the screen.
        property bool held: false
        // Dragged far enough to be a move, and towards which edge.
        property bool moving: false
        property string target: root.edge
        property point pointer: Qt.point(0, 0)
        property point pressPoint: Qt.point(0, 0)
        readonly property bool full: bar.width >= bar.screenW - 1 && bar.height >= bar.screenH - 1

        anchors {
            top: bar.held || root.edge !== "bottom"
            bottom: bar.held || root.edge !== "top"
            left: bar.held || root.edge !== "right"
            right: bar.held || root.edge !== "left"
        }
        implicitWidth: root.size
        implicitHeight: root.size

        // The strip, less its outer two pixels (the edge strips' line), and
        // nothing while the workspace disc is dragged past it. While held,
        // no mask at all: the surface takes the pointer wherever Hyprland
        // has it before Qt's next frame (see WorkspaceDiscWindow).
        mask: bar.held ? null : stripMask

        Region {
            id: stripMask
            x: root.edge === "left" ? 2 : 0
            y: root.edge === "top" ? 2 : 0
            width: Services.WorkspaceDiscService.moving ? 0 : bar.width - (root.vertical ? 2 : 0)
            height: bar.height - (root.vertical ? 0 : 2)
        }

        // The nearest edge to a point on the screen: the screen split along
        // its diagonals.
        function edgeAt(p) {
            const fx = p.x / bar.screenW, fy = p.y / bar.screenH;
            const d = { left: fx, right: 1 - fx, top: fy, bottom: 1 - fy };
            let best = "top";
            for (const k of ["top", "bottom", "left", "right"])
                if (d[k] < d[best])
                    best = k;
            return best;
        }

        function release() {
            if (bar.moving && bar.target !== root.edge)
                Services.BarLayout.setEdge(bar.target);
            bar.moving = false;
            bar.held = false;
        }

        Item {
            id: surface
            anchors.fill: parent

            // A press that loses the pointer to another surface gets no
            // release; once the surface is full screen, the pointer leaving
            // it can only mean that. Finish the move there.
            HoverHandler {
                onHoveredChanged: if (!hovered && bar.held && bar.full) bar.release()
            }

            // The bar's strip: at the surface's corner normally, at its own
            // place on the screen while the surface covers it.
            Item {
                id: strip
                x: bar.full ? bar.stripX : 0
                y: bar.full ? bar.stripY : 0
                width: root.vertical ? root.size : bar.screenW
                height: root.vertical ? bar.screenH : root.size

                // Empty stretches: press and drag to move the bar. Declared
                // before the bar, so its widgets, the pet and the tray take
                // their own presses.
                MouseArea {
                    id: grip

                    anchors.fill: parent
                    cursorShape: bar.moving ? Qt.ClosedHandCursor : Qt.ArrowCursor

                    function screenPoint(mouse) {
                        return Qt.point(bar.stripX + mouse.x, bar.stripY + mouse.y);
                    }

                    onPressed: mouse => {
                        bar.pressPoint = grip.screenPoint(mouse);
                        bar.pointer = bar.pressPoint;
                        bar.target = root.edge;
                        bar.moving = false;
                        bar.held = true;
                    }
                    onPositionChanged: mouse => {
                        if (!bar.held)
                            return;
                        bar.pointer = grip.screenPoint(mouse);
                        if (!bar.moving && Math.hypot(bar.pointer.x - bar.pressPoint.x, bar.pointer.y - bar.pressPoint.y) > 12)
                            bar.moving = true;
                        if (bar.moving)
                            bar.target = bar.edgeAt(bar.pointer);
                    }
                    onReleased: bar.release()
                    onCanceled: {
                        bar.moving = false;
                        bar.held = false;
                    }
                }

                TopBar {
                    id: topBar
                    opacity: bar.moving ? 0.35 : 1

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 160
                        }
                    }
                }
            }

            // Where the bar would go: its slot on the target edge, lit.
            Item {
                anchors.fill: parent
                visible: bar.moving && bar.full

                Rectangle {
                    id: slot

                    readonly property bool side: bar.target === "left" || bar.target === "right"
                    readonly property bool stays: bar.target === root.edge

                    x: bar.target === "right" ? bar.screenW - root.size + 3 : 3
                    y: bar.target === "bottom" ? bar.screenH - root.size + 3 : 3
                    width: slot.side ? root.size - 6 : bar.screenW - 6
                    height: slot.side ? bar.screenH - 6 : root.size - 6
                    radius: Services.DesktopTheme.rad(14)
                    // Dark enough to read over any wallpaper.
                    color: Colors.withAlpha(Colors.surface_container, slot.stays ? 0.35 : 0.65)
                    border.width: 2
                    border.color: Colors.withAlpha(Colors.primary, slot.stays ? 0.45 : 0.95)

                    Behavior on x {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on y {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on width {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on height {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        rotation: !slot.side ? 0 : bar.target === "left" ? -90 : 90
                        text: slot.stays ? "Let go to keep the bar here" : "Let go to move the bar here"
                        color: Colors.on_surface
                        font.pixelSize: 14
                    }
                }
            }
        }
    }
}
