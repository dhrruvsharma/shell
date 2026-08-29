import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services as Services
import qs.components
import qs.Core
import "../../colors" as ColorsModule

// Draggable desktop cava visualizer.
//
// Two windows share the persisted geometry in Services.CavaWidget:
//  - display: WlrLayer.Bottom, fully click-through, shown while enabled.
//  - edit:    WlrLayer.Top, focusable, shown while editMode; a drag frame with
//             move/resize/skew handles and a small toolbar. Exiting persists.
//
// Toggled/edited via IPC (see shell.qml): cavaWidget.toggle / .edit / .reset.
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

    function resolveAccent(a) {
        if (!a || a.length === 0)
            return ColorsModule.Colors.primary;
        if (a.charAt(0) === "@")
            return root.roleColor(a.substring(1));
        return a;
    }
    function roleColor(name) {
        switch (name) {
        case "secondary":
            return ColorsModule.Colors.secondary;
        case "tertiary":
            return ColorsModule.Colors.tertiary;
        case "error":
            return ColorsModule.Colors.error;
        case "on_surface":
            return ColorsModule.Colors.on_surface;
        default:
            return ColorsModule.Colors.primary;
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
        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }
        // Input region = the box plus a small margin (so the gear at the
        // corner is included). Only this area catches the mouse; the rest of
        // the desktop stays click-through. Being in the mask is also what lets
        // us detect hover at all — regions outside it never see the pointer.
        mask: Region { item: hoverZone }

        Item {
            id: hoverZone
            x: Services.CavaWidget.posX - 16
            y: Services.CavaWidget.posY - 16
            width: Services.CavaWidget.boxWidth + 32
            height: Services.CavaWidget.boxHeight + 32

            // Tracks hover without swallowing clicks (the gear handles those).
            MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }
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
            color: editBtnArea.containsMouse ? root.resolvedAccent : ColorsModule.Colors.surface_container_high
            border.color: root.resolvedAccent
            border.width: 1
            opacity: editBtn.shown ? (editBtnArea.containsMouse ? 1 : 0.85) : 0

            Text {
                anchors.centerIn: parent
                text: Icons.settings
                font.family: "Material Design Icons"
                font.pixelSize: 15
                color: editBtnArea.containsMouse ? ColorsModule.Colors.background : root.resolvedAccent
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
                    color: ColorsModule.Colors.tertiary
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
                    color: ColorsModule.Colors.secondary

                    Text {
                        anchors.centerIn: parent
                        text: "↻"   // ↻
                        color: ColorsModule.Colors.background
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
                    color: ColorsModule.Colors.primary

                    Text {
                        anchors.centerIn: parent
                        text: "◈"
                        color: ColorsModule.Colors.background
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
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 16
                radius: 18
                color: ColorsModule.Colors.surface_container
                border.color: ColorsModule.Colors.outline_variant
                border.width: 1
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

                    // Swatches store a theme-role *token* (not a frozen hex),
                    // so the accent follows the wallpaper: when matugen rewrites
                    // Colors.json the widget recolours itself. The first is Auto
                    // (wallpaper primary); the rest pin a specific role.
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Repeater {
                            model: [
                                { token: "",            swatch: ColorsModule.Colors.primary,    auto: true },
                                { token: "@secondary",  swatch: ColorsModule.Colors.secondary,  auto: false },
                                { token: "@tertiary",   swatch: ColorsModule.Colors.tertiary,   auto: false },
                                { token: "@error",      swatch: ColorsModule.Colors.error,      auto: false },
                                { token: "@on_surface", swatch: ColorsModule.Colors.on_surface, auto: false }
                            ]
                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                color: modelData.swatch
                                border.width: Services.CavaWidget.accentColor === modelData.token ? 3 : 1
                                border.color: ColorsModule.Colors.on_surface

                                // "A" marks the wallpaper-following Auto swatch.
                                Text {
                                    anchors.centerIn: parent
                                    visible: modelData.auto
                                    text: "A"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: ColorsModule.Colors.background
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
        color: chip.accent ? root.resolvedAccent : ColorsModule.Colors.surface_container_high
        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            color: chip.accent ? ColorsModule.Colors.background : ColorsModule.Colors.on_surface
            font.pixelSize: 13
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }
}
