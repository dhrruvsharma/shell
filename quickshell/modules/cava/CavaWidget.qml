import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services as Services
import qs.components
import qs.Core
import qs.colors
import qs.modules.desktopwidgets

// Draggable desktop cava visualizer.
//
// Two windows share the persisted geometry in Services.CavaWidget:
//  - display: WlrLayer.Bottom, fully click-through, shown while enabled.
//  - edit:    WlrLayer.Top, focusable, shown while editMode; a drag frame with
//             move/resize/skew handles and a small toolbar. Exiting persists.
//
// Toggled/edited via IPC (see shell.qml): cavaWidget.toggle / .edit / .reset,
// and from the Themes panel's Widgets tab. Drag the widget itself to move it:
// while held, the display surface grows to the whole screen so the box moves
// with plain Qt dragging, then shrinks back around it.
Scope {
    id: root

    property bool editMode: false

    // accentColor holds one of:
    //   ""            -> Auto: follow the wallpaper (theme primary), live.
    //   "@<role>"     -> follow that theme role live (re-reads matugen output).
    //   "#rrggbb"     -> a fixed literal colour.
    // Resolving through a function keeps the binding reactive: whichever
    // Colors.<role> it reads becomes a dependency, so a matugen rewrite of
    // Colors.json repaints the widget automatically.
    readonly property color resolvedAccent: root.resolveAccent(Services.CavaWidget.accentColor)

    // The desktop theme's look (modules/desktopwidgets/WidgetStyle): its
    // accent for "Auto", and a frame behind the spectrum.
    readonly property string themeId: Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""
    readonly property var themeStyle: WidgetStyle.of(themeId)

    function resolveAccent(a) {
        if (!a || a.length === 0)
            return Colors[root.themeStyle.accentRole];
        if (a.charAt(0) === "@")
            return root.roleColor(a.substring(1));
        return a;
    }
    function roleColor(name) {
        switch (name) {
        case "secondary":
            return Colors.secondary;
        case "tertiary":
            return Colors.tertiary;
        case "error":
            return Colors.error;
        case "on_surface":
            return Colors.on_surface;
        default:
            return Colors.primary;
        }
    }

    function toggle() {
        Services.CavaWidget.enabled = !Services.CavaWidget.enabled;
        Services.CavaWidget.save();
    }
    function enterEdit() {
        Services.CavaWidget.enabled = true;
        root.editMode = true;
    }
    function exitEdit() {
        root.editMode = false;
        Services.CavaWidget.save();
    }
    function edit() {
        if (root.editMode)
            root.exitEdit();
        else
            root.enterEdit();
    }

    // Run cava only while the widget wants it; `when` avoids fighting other
    // consumers of the shared Cava.running flag (it only ever forces true).
    Binding {
        target: Services.Cava
        property: "running"
        value: true
        when: Services.CavaWidget.enabled || root.editMode
    }

    // Just the skewed spectrum, no interaction. Used by both windows.
    // Rotation is applied by the caller (display Item / editBox) so it never
    // double-applies; this only holds the shader + its horizontal shear.
    component CavaVisual: Item {
        CavaShader {
            anchors.fill: parent
            accentColor: root.resolvedAccent
            orientation: Services.CavaWidget.orientation
            style: Services.CavaWidget.style
            flip: Services.CavaWidget.flip
            bezierEnabled: Services.CavaWidget.bezierEnabled
            bezierFit: Services.CavaWidget.bezierFit
            bezierY0: Services.CavaWidget.bezierY0
            bezierY1: Services.CavaWidget.bezierY1
            bezierY2: Services.CavaWidget.bezierY2
            bezierY3: Services.CavaWidget.bezierY3
            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(1, Services.CavaWidget.skew, 0, 0,
                                     0, 1, 0, 0,
                                     0, 0, 1, 0,
                                     0, 0, 0, 1)
            }
        }
    }

    // ---- display (desktop, click-through) --------------------------------
    PanelWindow {
        id: displayWin
        visible: Services.CavaWidget.enabled && !root.editMode
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        // The surface only covers the widget, not the whole screen. Every
        // repaint of a Bottom-layer surface makes Hyprland recomposite what is
        // above it, so a fullscreen surface redrawing at cava's framerate made
        // the whole desktop expensive. The square is centred on the box and
        // wide enough for any rotation and for the skew (which shears about
        // the box's top-left, pushing one corner further out), with slack for
        // the 3D tilt's perspective and the hover margin + gear.
        readonly property real boxCX: Services.CavaWidget.posX + Services.CavaWidget.boxWidth / 2
        readonly property real boxCY: Services.CavaWidget.posY + Services.CavaWidget.boxHeight / 2
        readonly property real extent: Math.ceil(Math.hypot(
            Services.CavaWidget.boxWidth + 2 * Math.abs(Services.CavaWidget.skew) * Services.CavaWidget.boxHeight,
            Services.CavaWidget.boxHeight) / 2 * 1.2) + 32
        readonly property real screenW: displayWin.screen ? displayWin.screen.width : 100000
        readonly property real screenH: displayWin.screen ? displayWin.screen.height : 100000
        readonly property int restX: Math.max(0, Math.floor(displayWin.boxCX - displayWin.extent))
        readonly property int restY: Math.max(0, Math.floor(displayWin.boxCY - displayWin.extent))
        // Held for a drag: the surface covers the screen (see the header).
        property bool held: false
        readonly property bool full: displayWin.width >= displayWin.screenW - 1 && displayWin.height >= displayWin.screenH - 1
        readonly property int winX: displayWin.held ? 0 : displayWin.restX
        readonly property int winY: displayWin.held ? 0 : displayWin.restY

        anchors {
            left: true
            top: true
        }
        margins.left: displayWin.winX
        margins.top: displayWin.winY
        implicitWidth: displayWin.held ? displayWin.screenW : Math.max(1, Math.min(displayWin.screenW, Math.ceil(displayWin.boxCX + displayWin.extent)) - displayWin.restX)
        implicitHeight: displayWin.held ? displayWin.screenH : Math.max(1, Math.min(displayWin.screenH, Math.ceil(displayWin.boxCY + displayWin.extent)) - displayWin.restY)

        // Input region = the box plus a small margin (so the gear at the
        // corner is included). Only this area catches the mouse; the rest of
        // the desktop stays click-through. Being in the mask is also what lets
        // us detect hover at all — regions outside it never see the pointer.
        mask: Region { item: hoverZone }

        // Children keep using screen coordinates (posX/posY); this shifts them
        // into the smaller surface.
        Item {
            x: displayWin.full ? 0 : -displayWin.restX
            y: displayWin.full ? 0 : -displayWin.restY

            Item {
                id: hoverZone
                x: Services.CavaWidget.posX - 16
                y: Services.CavaWidget.posY - 16
                width: Services.CavaWidget.boxWidth + 32
                height: Services.CavaWidget.boxHeight + 32

                // Hover (for the gear) and dragging the widget around.
                MouseArea {
                    id: hoverArea

                    property real pressX: 0
                    property real pressY: 0

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onPressed: mouse => {
                        pressX = mouse.x;
                        pressY = mouse.y;
                        displayWin.held = true;
                    }
                    onPositionChanged: mouse => {
                        if (!pressed || !displayWin.full)
                            return;
                        Services.CavaWidget.posX = Math.round(Math.max(0, Math.min(displayWin.screenW - Services.CavaWidget.boxWidth, Services.CavaWidget.posX + mouse.x - pressX)));
                        Services.CavaWidget.posY = Math.round(Math.max(0, Math.min(displayWin.screenH - Services.CavaWidget.boxHeight, Services.CavaWidget.posY + mouse.y - pressY)));
                    }
                    onReleased: {
                        displayWin.held = false;
                        Services.CavaWidget.save();
                    }
                    onCanceled: displayWin.held = false
                }
            }

            // The desktop theme's frame behind the spectrum.
            WidgetFrame {
                id: cavaFrame
                visible: ["chamfer", "console", "glass", "scroll"].includes(root.themeStyle.frame)
                x: Services.CavaWidget.posX - 12
                y: Services.CavaWidget.posY - 12 - cavaFrame.tabRoom
                width: Services.CavaWidget.boxWidth + 24
                height: Services.CavaWidget.boxHeight + 24 + cavaFrame.tabRoom
                rotation: Services.CavaWidget.rotation
                themeId: root.themeId
                title: root.themeStyle.frame === "console" ? "~ $ cava" : ""
                seal: "音"
            }

            CavaVisual {
                x: Services.CavaWidget.posX
                y: Services.CavaWidget.posY
                width: Services.CavaWidget.boxWidth
                height: Services.CavaWidget.boxHeight
                rotation: Services.CavaWidget.rotation
                // 3D perspective tilt (out-of-plane). Turning about the vertical
                // axis foreshortens the far side; near 90° the bars stack up.
                // NOTE: origin must be a resolvable reference — a bare `width` here
                // resolves to the file root (NaN), which poisons the matrix once the
                // angle is non-zero and flings the widget away. Use the box size.
                transform: [
                    Rotation {
                        origin.x: Services.CavaWidget.boxWidth / 2
                        origin.y: Services.CavaWidget.boxHeight / 2
                        axis.x: 1; axis.y: 0; axis.z: 0
                        angle: Services.CavaWidget.tiltX
                    },
                    Rotation {
                        origin.x: Services.CavaWidget.boxWidth / 2
                        origin.y: Services.CavaWidget.boxHeight / 2
                        axis.x: 0; axis.y: 1; axis.z: 0
                        angle: Services.CavaWidget.tiltY
                    }
                ]
            }

            // Small gear that enters edit mode. Hidden until the pointer is over
            // the widget, then fades in. Pinned to the box's top-right corner.
            Rectangle {
                id: editBtn
                width: 26
                height: 26
                radius: 13
                x: Services.CavaWidget.posX + Services.CavaWidget.boxWidth - width / 2
                y: Services.CavaWidget.posY - height / 2
                readonly property bool shown: hoverArea.containsMouse || editBtnArea.containsMouse
                color: editBtnArea.containsMouse ? root.resolvedAccent : Colors.surface_container_high
                border.color: root.resolvedAccent
                border.width: 1
                opacity: editBtn.shown ? (editBtnArea.containsMouse ? 1 : 0.85) : 0

                MaterialIcon {
                    anchors.centerIn: parent
                    text: Icons.settings
                    font.pixelSize: 15
                    color: editBtnArea.containsMouse ? Colors.background : root.resolvedAccent
                }

                MouseArea {
                    id: editBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.enterEdit()
                }

                Behavior on opacity {
                    NumberAnimation { duration: 120 }
                }
            }
        }
    }

    // ---- edit (above windows, interactive) -------------------------------
    PanelWindow {
        id: editWin
        visible: root.editMode
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusionMode: ExclusionMode.Ignore
        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }

        Item {
            id: editRoot
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.exitEdit()

            // Dim backdrop; clicking empty space exits edit mode.
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.35)
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.exitEdit()
                }
            }

            // The draggable / resizable / skewable box.
            Item {
                id: editBox
                x: Services.CavaWidget.posX
                y: Services.CavaWidget.posY
                width: Services.CavaWidget.boxWidth
                height: Services.CavaWidget.boxHeight
                rotation: Services.CavaWidget.rotation   // around center (default origin)
                // Same 3D tilt as the display, so edit mode is WYSIWYG.
                transform: [
                    Rotation {
                        origin.x: Services.CavaWidget.boxWidth / 2
                        origin.y: Services.CavaWidget.boxHeight / 2
                        axis.x: 1; axis.y: 0; axis.z: 0
                        angle: Services.CavaWidget.tiltX
                    },
                    Rotation {
                        origin.x: Services.CavaWidget.boxWidth / 2
                        origin.y: Services.CavaWidget.boxHeight / 2
                        axis.x: 0; axis.y: 1; axis.z: 0
                        angle: Services.CavaWidget.tiltY
                    }
                ]

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.color: root.resolvedAccent
                    border.width: 1
                    radius: 4
                }

                CavaVisual {
                    anchors.fill: parent
                }

                // Move
                MouseArea {
                    id: moveArea
                    anchors.fill: parent
                    cursorShape: Qt.SizeAllCursor
                    property real grabX: 0
                    property real grabY: 0
                    property real startX: 0
                    property real startY: 0
                    onPressed: mouse => {
                        var p = moveArea.mapToItem(editRoot, mouse.x, mouse.y);
                        moveArea.grabX = p.x;
                        moveArea.grabY = p.y;
                        moveArea.startX = Services.CavaWidget.posX;
                        moveArea.startY = Services.CavaWidget.posY;
                    }
                    onPositionChanged: mouse => {
                        var p = moveArea.mapToItem(editRoot, mouse.x, mouse.y);
                        Services.CavaWidget.posX = Math.round(moveArea.startX + (p.x - moveArea.grabX));
                        Services.CavaWidget.posY = Math.round(moveArea.startY + (p.y - moveArea.grabY));
                    }
                    onReleased: Services.CavaWidget.save()
                }

                // Bezier baseline control points, shown while the curve is on.
                // They sit at 0, 1/3, 2/3, 1 across the widget (screen order —
                // the shader places the curve before applying flip) and drag
                // along the growth axis only. Value = distance from the edge
                // the bars grow from, as a fraction of the bar extent (-1..1).
                // The x follows the shader's skew so each puck sits on the curve.
                Repeater {
                    model: Services.CavaWidget.bezierEnabled ? 4 : 0

                    Rectangle {
                        id: puck
                        required property int index

                        readonly property int orient: Services.CavaWidget.orientation
                        readonly property bool vertical: puck.orient === 2 || puck.orient === 3
                        readonly property real t: puck.index / 3
                        readonly property real value: [Services.CavaWidget.bezierY0, Services.CavaWidget.bezierY1,
                            Services.CavaWidget.bezierY2, Services.CavaWidget.bezierY3][puck.index]
                        readonly property real extent: puck.vertical ? editBox.width : editBox.height
                        readonly property real along: puck.value * puck.extent
                        readonly property real centerY: puck.vertical ? puck.t * editBox.height
                            : (puck.orient === 1 ? puck.along : editBox.height - puck.along)
                        readonly property real centerX: (puck.vertical
                            ? (puck.orient === 2 ? puck.along : editBox.width - puck.along)
                            : puck.t * editBox.width) + Services.CavaWidget.skew * puck.centerY

                        width: 14
                        height: 14
                        radius: 7
                        x: puck.centerX - width / 2
                        y: puck.centerY - height / 2
                        color: Colors.background
                        border.color: root.resolvedAccent
                        border.width: 2

                        MouseArea {
                            id: puckArea
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: puck.vertical ? Qt.SizeHorCursor : Qt.SizeVerCursor
                            property real grab: 0
                            property real startValue: 0
                            // Pointer position along the growth axis, in box space
                            // (so it stays correct under the box's rotation).
                            function axisPos(mouse) {
                                var p = puckArea.mapToItem(editBox, mouse.x, mouse.y);
                                return puck.vertical ? p.x : p.y;
                            }
                            onPressed: mouse => {
                                puckArea.grab = puckArea.axisPos(mouse);
                                puckArea.startValue = puck.value;
                            }
                            onPositionChanged: mouse => {
                                // Top/left grow along +axis; bottom/right grow against it.
                                var sign = (puck.orient === 1 || puck.orient === 2) ? 1 : -1;
                                var d = (puckArea.axisPos(mouse) - puckArea.grab) / Math.max(1, puck.extent);
                                Services.CavaWidget.setBezierPoint(puck.index, puckArea.startValue + sign * d);
                            }
                            onReleased: Services.CavaWidget.save()
                        }
                    }
                }

                // Resize (bottom-right)
                Rectangle {
                    width: 18
                    height: 18
                    radius: 4
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    color: root.resolvedAccent
                    MouseArea {
                        id: resizeArea
                        anchors.fill: parent
                        cursorShape: Qt.SizeFDiagCursor
                        property real grabX: 0
                        property real grabY: 0
                        property real startW: 0
                        property real startH: 0
                        onPressed: mouse => {
                            var p = resizeArea.mapToItem(editRoot, mouse.x, mouse.y);
                            resizeArea.grabX = p.x;
                            resizeArea.grabY = p.y;
                            resizeArea.startW = Services.CavaWidget.boxWidth;
                            resizeArea.startH = Services.CavaWidget.boxHeight;
                        }
                        onPositionChanged: mouse => {
                            var p = resizeArea.mapToItem(editRoot, mouse.x, mouse.y);
                            Services.CavaWidget.boxWidth = Math.max(60, Math.round(resizeArea.startW + (p.x - resizeArea.grabX)));
                            Services.CavaWidget.boxHeight = Math.max(30, Math.round(resizeArea.startH + (p.y - resizeArea.grabY)));
                        }
                        onReleased: Services.CavaWidget.save()
                    }
                }

                // Skew (top-right, drag horizontally)
                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    anchors.right: parent.right
                    anchors.top: parent.top
                    color: Colors.tertiary
                    MouseArea {
                        id: skewArea
                        anchors.fill: parent
                        cursorShape: Qt.SizeHorCursor
                        property real grabX: 0
                        property real startSkew: 0
                        onPressed: mouse => {
                            var p = skewArea.mapToItem(editRoot, mouse.x, mouse.y);
                            skewArea.grabX = p.x;
                            skewArea.startSkew = Services.CavaWidget.skew;
                        }
                        onPositionChanged: mouse => {
                            var p = skewArea.mapToItem(editRoot, mouse.x, mouse.y);
                            var d = (p.x - skewArea.grabX) / Math.max(1, Services.CavaWidget.boxHeight);
                            Services.CavaWidget.skew = Math.max(-0.8, Math.min(0.8, skewArea.startSkew + d));
                        }
                        onReleased: Services.CavaWidget.save()
                    }
                }

                // Rotate (bottom-left, drag around the box centre)
                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    color: Colors.secondary

                    StyledText {
                        anchors.centerIn: parent
                        text: "↻"   // ↻
                        color: Colors.background
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: rotateArea
                        anchors.fill: parent
                        cursorShape: Qt.CrossCursor
                        property real startPointerAngle: 0
                        property real startRotation: 0
                        // Box centre is rotation-invariant: it stays put in
                        // editRoot space no matter the current angle.
                        function pointerAngle(mouse) {
                            var p = rotateArea.mapToItem(editRoot, mouse.x, mouse.y);
                            var cx = Services.CavaWidget.posX + Services.CavaWidget.boxWidth / 2;
                            var cy = Services.CavaWidget.posY + Services.CavaWidget.boxHeight / 2;
                            return Math.atan2(p.y - cy, p.x - cx) * 180 / Math.PI;
                        }
                        onPressed: mouse => {
                            rotateArea.startPointerAngle = rotateArea.pointerAngle(mouse);
                            rotateArea.startRotation = Services.CavaWidget.rotation;
                        }
                        onPositionChanged: mouse => {
                            var delta = rotateArea.pointerAngle(mouse) - rotateArea.startPointerAngle;
                            var a = rotateArea.startRotation + delta;
                            // Normalise to (-180, 180]; snap near 15° steps for tidy angles.
                            a = ((a % 360) + 540) % 360 - 180;
                            var snapped = Math.round(a / 15) * 15;
                            if (Math.abs(a - snapped) < 3)
                                a = snapped;
                            Services.CavaWidget.rotation = Math.round(a);
                        }
                        onReleased: Services.CavaWidget.save()
                    }
                }

                // 3D tilt (top-left): drag horizontally to yaw (turn like a
                // door), vertically to pitch. mapToItem→editRoot gives the true
                // pointer position, so it's stable under the box's own tilt.
                Rectangle {
                    width: 18
                    height: 18
                    radius: 4
                    anchors.left: parent.left
                    anchors.top: parent.top
                    color: Colors.primary

                    StyledText {
                        anchors.centerIn: parent
                        text: "◈"
                        color: Colors.background
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: tiltArea
                        anchors.fill: parent
                        cursorShape: Qt.SizeAllCursor
                        property real grabX: 0
                        property real grabY: 0
                        property real startTiltX: 0
                        property real startTiltY: 0
                        onPressed: mouse => {
                            var p = tiltArea.mapToItem(editRoot, mouse.x, mouse.y);
                            tiltArea.grabX = p.x;
                            tiltArea.grabY = p.y;
                            tiltArea.startTiltX = Services.CavaWidget.tiltX;
                            tiltArea.startTiltY = Services.CavaWidget.tiltY;
                        }
                        onPositionChanged: mouse => {
                            var p = tiltArea.mapToItem(editRoot, mouse.x, mouse.y);
                            var yaw = tiltArea.startTiltY + (p.x - tiltArea.grabX) * 0.6;
                            var pitch = tiltArea.startTiltX - (p.y - tiltArea.grabY) * 0.6;
                            Services.CavaWidget.tiltY = Math.round(Math.max(-180, Math.min(180, yaw)));
                            Services.CavaWidget.tiltX = Math.round(Math.max(-180, Math.min(180, pitch)));
                        }
                        onReleased: Services.CavaWidget.save()
                    }
                }
            }

            // Toolbar (top center)
            Card {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 16
                radius: 18
                implicitWidth: toolRow.implicitWidth + 24
                implicitHeight: 44

                Row {
                    id: toolRow
                    anchors.centerIn: parent
                    spacing: 8

                    ChipBtn {
                        label: Services.CavaWidget.style === 1 ? "Area" : "Bars"
                        onClicked: {
                            Services.CavaWidget.style = Services.CavaWidget.style === 1 ? 0 : 1;
                            Services.CavaWidget.save();
                        }
                    }
                    ChipBtn {
                        label: ["Bottom", "Top", "Left", "Right"][Services.CavaWidget.orientation]
                        onClicked: {
                            Services.CavaWidget.orientation = (Services.CavaWidget.orientation + 1) % 4;
                            Services.CavaWidget.save();
                        }
                    }
                    ChipBtn {
                        label: Services.CavaWidget.flip ? "Flip: on" : "Flip: off"
                        onClicked: {
                            Services.CavaWidget.flip = Services.CavaWidget.flip ? 0 : 1;
                            Services.CavaWidget.save();
                        }
                    }
                    ChipBtn {
                        label: Math.round(Services.CavaWidget.rotation) + "°"
                        onClicked: {
                            Services.CavaWidget.rotation = 0;
                            Services.CavaWidget.save();
                        }
                    }
                    ChipBtn {
                        label: "3D " + Math.round(Services.CavaWidget.tiltX) + "/" + Math.round(Services.CavaWidget.tiltY)
                        onClicked: {
                            Services.CavaWidget.tiltX = 0;
                            Services.CavaWidget.tiltY = 0;
                            Services.CavaWidget.save();
                        }
                    }
                    ChipBtn {
                        label: Services.CavaWidget.bezierEnabled ? "Curve: on" : "Curve: off"
                        onClicked: {
                            Services.CavaWidget.bezierEnabled = !Services.CavaWidget.bezierEnabled;
                            Services.CavaWidget.save();
                        }
                    }
                    // Fit: keep the baseline inside the box and shrink bars into
                    // the room above it, instead of cutting them off at the edge.
                    ChipBtn {
                        visible: Services.CavaWidget.bezierEnabled
                        label: Services.CavaWidget.bezierFit ? "Fit: on" : "Fit: off"
                        onClicked: {
                            Services.CavaWidget.bezierFit = !Services.CavaWidget.bezierFit;
                            Services.CavaWidget.save();
                        }
                    }
                    ChipBtn {
                        visible: Services.CavaWidget.bezierEnabled
                        label: "Reset curve"
                        onClicked: Services.CavaWidget.resetBezier()
                    }

                    // Swatches store a theme-role *token* (not a frozen hex),
                    // so the accent follows the wallpaper: when matugen rewrites
                    // Colors.json the widget recolours itself. The first is Auto
                    // (wallpaper primary); the rest pin a specific role.
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Repeater {
                            model: [
                                { token: "",            swatch: Colors.primary,    auto: true },
                                { token: "@secondary",  swatch: Colors.secondary,  auto: false },
                                { token: "@tertiary",   swatch: Colors.tertiary,   auto: false },
                                { token: "@error",      swatch: Colors.error,      auto: false },
                                { token: "@on_surface", swatch: Colors.on_surface, auto: false }
                            ]
                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                color: modelData.swatch
                                border.width: Services.CavaWidget.accentColor === modelData.token ? 3 : 1
                                border.color: Colors.on_surface

                                // "A" marks the wallpaper-following Auto swatch.
                                StyledText {
                                    anchors.centerIn: parent
                                    visible: modelData.auto
                                    text: "A"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: Colors.background
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Services.CavaWidget.accentColor = modelData.token;
                                        Services.CavaWidget.save();
                                    }
                                }
                            }
                        }
                    }

                    ChipBtn {
                        label: "Done"
                        accent: true
                        onClicked: root.exitEdit()
                    }
                }
            }
        }
    }

    // Small pill button used in the edit toolbar.
    component ChipBtn: Rectangle {
        id: chip
        property string label: ""
        property bool accent: false
        signal clicked
        implicitWidth: chipText.implicitWidth + 20
        implicitHeight: 30
        radius: 15
        color: chip.accent ? root.resolvedAccent : Colors.surface_container_high
        StyledText {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            color: chip.accent ? Colors.background : Colors.on_surface
            font.pixelSize: 13
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }
}
