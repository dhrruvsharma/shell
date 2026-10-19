pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.components
import qs.modules.lock
import qs.services as Services

// The bar's settings (services/BarSettings), opened by the gear on the bar,
// SUPER+B or `qs ipc call barSettings toggle`:
//
//  - Containers: what the bar shows. Switch any widget off and on (the gear
//    itself too, SUPER+B still opens this), or click it in the preview of
//    the bar at the top. Hidden widgets keep their place on the bar.
//  - Colour: the containers' colour and their text's, each from the
//    wallpaper (a tone of matugen's scheme) or picked by hand.
//  - Transparency and an outline for the containers.
//  - Position: which screen edge the bar sits on, and its widgets back in
//    their first order.
//  - The Width tab (WidthTab.qml): each container as wide as its text or
//    as wide as set, and what text that doesn't fit then does.
//
// Everything applies as it's set, on the bar itself (which stays above
// the scrim) as well as in the preview. Keys: Tab switches tabs, Esc
// closes; on General arrows pick a container and Space or Enter switches
// it, on Width see WidthTab.
Item {
    id: root

    anchors.fill: parent
    visible: false

    readonly property var bs: Services.BarSettings
    readonly property var widgets: root.bs.widgets
    property int sel: 0
    // The keyboard picked a container: its tile shows the ring until the
    // mouse is used again.
    property bool keyNav: false
    // What the colour section colours: "fill" or "ink".
    property string colorTarget: "fill"
    // "general" or "width".
    property string tab: "general"

    onTabChanged: root.keyNav = false

    function open() {
        visible = true;
        Services.BarSettings.panelOpen = true;
        root.forceActiveFocus();
        closeAnim.stop();
        openAnim.restart();
    }

    function close() {
        Services.BarSettings.panelOpen = false;
        openAnim.stop();
        closeAnim.restart();
    }

    function toggle() {
        if (visible && !closeAnim.running)
            close();
        else
            open();
    }

    Component.onDestruction: Services.BarSettings.panelOpen = false

    // Keys from the hex field come here too: it's inside.
    Keys.onPressed: event => {
        const n = root.widgets.length;
        const typing = picker.typing;
        if (event.key === Qt.Key_Escape) {
            if (typing)
                root.forceActiveFocus();
            else
                root.close();
        } else if (typing) {
            return;
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            root.tab = root.tab === "general" ? "width" : "general";
        } else if (root.tab === "width") {
            if (!widthTab.handleKey(event))
                return;
        } else if (!root.keyNav && [Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].includes(event.key)) {
            // The first arrow only shows which container is picked.
            root.keyNav = true;
        } else if (event.key === Qt.Key_Right) {
            root.sel = Math.min(n - 1, root.sel + 1);
        } else if (event.key === Qt.Key_Left) {
            root.sel = Math.max(0, root.sel - 1);
        } else if (event.key === Qt.Key_Down) {
            root.sel = Math.min(n - 1, root.sel + 2);
        } else if (event.key === Qt.Key_Up) {
            root.sel = Math.max(0, root.sel - 2);
        } else if (root.keyNav && (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            // Only a container you can see picked is switched.
            root.bs.toggle(root.widgets[root.sel].id);
        } else {
            return;
        }
        event.accepted = true;
    }

    // ── Scrim ────────────────────────────────────────────────────────────────

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Colors.scrim
        opacity: 0
        enabled: opacity > 0.01

        MouseArea {
            anchors.fill: parent
            enabled: parent.enabled
            onClicked: root.close()
        }
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: scrim; property: "opacity"; to: 0.5; duration: 240; easing.type: Easing.OutCubic }
        NumberAnimation { target: panel; property: "opacity"; to: 1; duration: 240; easing.type: Easing.OutCubic }
        NumberAnimation { target: panel; property: "scale"; to: 1; duration: 320; easing.type: Easing.OutBack }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation { target: scrim; property: "opacity"; to: 0; duration: 200; easing.type: Easing.InCubic }
        NumberAnimation { target: panel; property: "opacity"; to: 0; duration: 200; easing.type: Easing.InCubic }
        NumberAnimation { target: panel; property: "scale"; to: 0.94; duration: 200; easing.type: Easing.InCubic }
        onFinished: root.visible = false
    }

    // ── Panel ────────────────────────────────────────────────────────────────

    Rectangle {
        id: panel

        // Centred in the room the bar leaves, wherever it is; it moves
        // over when the bar does.
        readonly property real roomW: root.width - Services.BarLayout.reserveLeft - Services.BarLayout.reserveRight
        readonly property real roomH: root.height - Services.BarLayout.reserveTop - Services.BarLayout.reserveBottom

        x: Services.BarLayout.reserveLeft + (panel.roomW - width) / 2
        y: Services.BarLayout.reserveTop + (panel.roomH - height) / 2
        width: Math.min(1240, panel.roomW - 48)
        height: Math.min(900, panel.roomH - 40)
        radius: Services.DesktopTheme.rad(30)
        color: Colors.surface_container_lowest
        border.width: 1
        border.color: Colors.withAlpha(Colors.outline_variant, 0.6)
        clip: true
        opacity: 0
        scale: 0.94

        Behavior on x {
            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
        }

        // Clicks on the panel stay on it.
        MouseArea {
            anchors.fill: parent
            onClicked: root.forceActiveFocus()
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Colors.withAlpha(Colors.primary, 0.07) }
                GradientStop { position: 0.35; color: "transparent" }
            }
        }

        Item {
            id: content
            anchors.fill: parent
            anchors.margins: 28

            // ── Header ───────────────────────────────────────────────────────
            Item {
                id: header
                width: parent.width
                height: 52

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44
                        height: 44
                        radius: Services.DesktopTheme.rad(14)
                        color: Colors.primary_container

                        Glyph {
                            anchors.centerIn: parent
                            text: "toolbar"
                            filled: true
                            font.pixelSize: 24
                            color: Colors.on_primary_container
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        StyledText {
                            text: "Bar"
                            font.pixelSize: 21
                            font.weight: Font.Bold
                        }

                        StyledText {
                            text: root.tab === "width" ? "How wide each container is. Text that doesn't fit scrolls through."
                                : "What it shows, and how it looks. Changes apply as you make them."
                            font.pixelSize: 13
                            color: Colors.on_surface_variant
                        }
                    }
                }

                // General | Width
                Segmented {
                    anchors.centerIn: parent
                    options: [
                        { id: "general", label: "General", icon: "tune" },
                        { id: "width", label: "Width", icon: "width" }
                    ]
                    current: root.tab
                    onChosen: choice => root.tab = choice
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    // Back to the defaults of the tab: the look, or the
                    // widths.
                    ClickableRect {
                        id: resetLook
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.tab === "width" ? !root.bs.widthsAreDefault : !root.bs.lookIsDefault
                        width: resetRow.implicitWidth + 28
                        height: 38
                        radius: Services.DesktopTheme.rad(19)
                        color: resetLook.hovered ? Colors.surface_container_high : Colors.surface_container
                        border.width: 1
                        border.color: Colors.withAlpha(Colors.outline_variant, 0.7)
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.tab === "width")
                                root.bs.resetWidths();
                            else
                                root.bs.resetLook();
                        }

                        Row {
                            id: resetRow
                            anchors.centerIn: parent
                            spacing: 8

                            Glyph {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.tab === "width" ? "fit_width" : "format_color_reset"
                                font.pixelSize: 18
                                color: Colors.on_surface_variant
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.tab === "width" ? "Default widths" : "Default look"
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }
                        }
                    }

                    ClickableRect {
                        id: closeChip
                        anchors.verticalCenter: parent.verticalCenter
                        width: 38
                        height: 38
                        radius: Services.DesktopTheme.rad(19)
                        color: closeChip.hovered ? Colors.surface_container_high : "transparent"
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()

                        Glyph {
                            anchors.centerIn: parent
                            text: "close"
                            font.pixelSize: 20
                            color: Colors.on_surface_variant
                        }
                    }
                }
            }

            // ── Preview ──────────────────────────────────────────────────────
            Item {
                id: caption
                anchors.top: header.bottom
                anchors.topMargin: 18
                width: parent.width
                height: 18

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "PREVIEW"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 1.4
                    color: Colors.on_surface_variant
                }

                StyledText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: 12
                    color: preview.hoveredId ? Colors.primary : Colors.on_surface_variant
                    text: {
                        const e = preview.hoveredId ? root.bs.info(preview.hoveredId) : null;
                        if (root.tab === "width") {
                            if (!e)
                                return "Point at a container to see its text scroll · click one to pick its row";
                            const w = root.bs.widthOf(e.id);
                            return e.name + " · " + (e.id === "tray" ? "its width can't be set" : w ? w + " px wide" : "auto width");
                        }
                        if (!e)
                            return "Click anything here to hide or show it · drag widgets on the bar itself to move them";
                        return e.name + (root.bs.shown(e.id) ? " · click to hide it" : " · hidden, click to show it");
                    }
                }
            }

            BarMap {
                id: preview
                anchors.top: caption.bottom
                anchors.topMargin: 8
                width: parent.width
                barLength: Services.BarLayout.vertical ? root.height : root.width
                onPicked: which => {
                    if (root.tab === "width")
                        widthTab.pick(which);
                    else
                        root.bs.toggle(which);
                }
            }

            // ── Width tab ────────────────────────────────────────────────────
            WidthTab {
                id: widthTab
                anchors.top: preview.bottom
                anchors.topMargin: 18
                anchors.bottom: footer.top
                anchors.bottomMargin: 18
                width: parent.width
                visible: root.tab === "width"
                map: preview
            }

            // ── General tab ──────────────────────────────────────────────────
            Item {
                id: generalTab
                anchors.top: preview.bottom
                anchors.topMargin: 18
                anchors.bottom: footer.top
                anchors.bottomMargin: 18
                width: parent.width
                visible: root.tab === "general"

                // ── Containers ───────────────────────────────────────────────
                SectionCard {
                    id: containers
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.round((parent.width - 18) * 0.5)
                    title: "Containers"
                    icon: "widgets"

                    trailing: [
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.bs.shownCount + " of " + root.widgets.length + " shown"
                            font.pixelSize: 12
                            color: Colors.on_surface_variant
                        },
                        ClickableRect {
                            id: showAll
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.bs.shownCount < root.widgets.length
                            width: showAllText.implicitWidth + 22
                            height: 28
                            radius: Services.DesktopTheme.rad(14)
                            color: showAll.hovered ? Colors.surface_container_high : Colors.surface_container
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.bs.showAll()

                            StyledText {
                                id: showAllText
                                anchors.centerIn: parent
                                text: "Show all"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: Colors.primary
                            }
                        }
                    ]

                    Grid {
                        id: tiles
                        anchors.fill: parent
                        columns: 2
                        columnSpacing: 10
                        rowSpacing: 10

                        readonly property int rowCount: Math.ceil(root.widgets.length / 2)

                        Repeater {
                            model: root.widgets

                            WidgetTile {
                                required property var modelData
                                required property int index

                                entry: modelData
                                width: (tiles.width - tiles.columnSpacing) / 2
                                height: Math.min(68, (tiles.height - (tiles.rowCount - 1) * tiles.rowSpacing) / tiles.rowCount)
                                selected: root.keyNav && root.sel === index && root.activeFocus
                                note: modelData.id === "settings" && !root.bs.shown("settings") ? "Off the bar: SUPER+B opens these settings"
                                    : modelData.id === "media" && root.bs.shown("media") && !Services.Media.activePlayer ? "Shows up when something plays"
                                    : ""
                                onClicked: {
                                    root.sel = index;
                                    root.keyNav = false;
                                    root.forceActiveFocus();
                                }
                            }
                        }
                    }
                }

                // ── Colour ───────────────────────────────────────────────────
                SectionCard {
                    id: colour
                    anchors.top: containers.top
                    anchors.left: containers.right
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.bottom: styleRow.top
                    anchors.bottomMargin: 18
                    title: "Colour"
                    icon: "palette"

                    trailing: [
                        Segmented {
                            anchors.verticalCenter: parent.verticalCenter
                            options: [
                                { id: "fill", label: "Containers", icon: "rectangle" },
                                { id: "ink", label: "Text", icon: "text_fields" }
                            ]
                            current: root.colorTarget
                            onChosen: choice => root.colorTarget = choice
                        }
                    ]

                    ColorEditor {
                        id: picker
                        anchors.fill: parent
                        target: root.colorTarget
                    }
                }

                // ── Transparency and position ────────────────────────────────
                Item {
                    id: styleRow
                    anchors.left: colour.left
                    anchors.right: parent.right
                    anchors.bottom: containers.bottom
                    height: 238

                    SectionCard {
                        id: clarity
                        width: (parent.width - 18) / 2
                        height: parent.height
                        title: "Transparency"
                        icon: "opacity"

                        trailing: [
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Math.round(slider.shownValue * 100) + "%"
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                font.features: ({ "tnum": 1 })
                                color: Colors.primary
                            }
                        ]

                        Column {
                            width: parent.width
                            spacing: 14

                            TransparencySlider {
                                id: slider
                                width: parent.width
                                value: root.bs.transparency
                                fill: root.bs.fill
                                onMoved: v => root.bs.setTransparency(v)
                            }

                            Row {
                                width: parent.width
                                spacing: 0

                                StyledText {
                                    width: parent.width / 2
                                    text: "Solid"
                                    font.pixelSize: 11
                                    color: Colors.on_surface_variant
                                }

                                StyledText {
                                    width: parent.width / 2
                                    horizontalAlignment: Text.AlignRight
                                    text: "Clear"
                                    font.pixelSize: 11
                                    color: Colors.on_surface_variant
                                }
                            }

                            // The outline, a hairline in the text's colour (a
                            // theme with its own border keeps that).
                            ClickableRect {
                                id: outlineRow
                                width: parent.width
                                height: 44
                                radius: Services.DesktopTheme.rad(14)
                                color: outlineRow.hovered ? Colors.surface_container_high : Colors.surface_container
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.bs.setOutline(!root.bs.outline)

                                Glyph {
                                    id: outlineGlyph
                                    x: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "border_style"
                                    font.pixelSize: 19
                                    color: root.bs.outline ? Colors.primary : Colors.on_surface_variant
                                }

                                StyledText {
                                    anchors.left: outlineGlyph.right
                                    anchors.leftMargin: 10
                                    anchors.right: outlineSwitch.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Outline"
                                    elide: Text.ElideRight
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }

                                SettingSwitch {
                                    id: outlineSwitch
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    on: root.bs.outline
                                }
                            }
                        }
                    }

                    SectionCard {
                        id: position
                        anchors.left: clarity.right
                        anchors.leftMargin: 18
                        anchors.right: parent.right
                        height: parent.height
                        title: "Position"
                        icon: "dock_to_bottom"

                        EdgePicker {
                            id: edges
                            width: 128
                            height: 80
                        }

                        Column {
                            anchors.left: edges.right
                            anchors.leftMargin: 14
                            anchors.right: parent.right
                            anchors.verticalCenter: edges.verticalCenter
                            spacing: 4

                            StyledText {
                                text: ({ top: "Top", bottom: "Bottom", left: "Left", right: "Right" })[Services.BarLayout.edge] + " edge"
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                            }

                            StyledText {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: "Click an edge to move the bar there"
                                font.pixelSize: 12
                                lineHeight: 1.1
                                color: Colors.on_surface_variant
                            }
                        }

                        ClickableRect {
                            id: resetOrder
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 34
                            radius: Services.DesktopTheme.rad(12)
                            color: resetOrder.hovered ? Colors.surface_container_high : Colors.surface_container
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Services.BarLayout.reset()

                            Row {
                                anchors.centerIn: parent
                                spacing: 8

                                Glyph {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "restart_alt"
                                    font.pixelSize: 17
                                    color: Colors.on_surface_variant
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Widgets back in order"
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                }
                            }
                        }
                    }
                }
            }

            // ── Footer ───────────────────────────────────────────────────────
            Rectangle {
                id: footer
                anchors.bottom: parent.bottom
                width: parent.width
                height: 40
                radius: Services.DesktopTheme.rad(14)
                color: Colors.surface_container

                Row {
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "keyboard"
                        font.pixelSize: 17
                        color: Colors.primary
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "SUPER+B opens these settings, gear or no gear"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                }

                StyledText {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.tab === "width" ? "↑↓ pick · ←→ narrower or wider (Shift: faster) · Space auto · Tab general · Esc close"
                        : "←→↑↓ pick a container · Space switch it · Tab width · Esc close"
                    font.pixelSize: 12
                    color: Colors.on_surface_variant
                }
            }
        }

        PanelDecor {
            radius: panel.radius
            title: "bar"
        }
    }
}
