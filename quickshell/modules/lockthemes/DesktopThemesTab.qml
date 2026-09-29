pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import qs.colors
import qs.components
import qs.modules.desktoptheme
import qs.modules.desktopwidgets
import qs.modules.lock
import qs.services as Services

// Themes panel, Desktop tab: pick a desktop theme (services/DesktopTheme.qml)
// from the strip of cards, see it on a miniature of your desktop (its real
// layer and your desktop widgets over your wallpaper, with mock windows and
// bar), and set the shared options: screen effect, matching lock screen.
//
// Keys (forwarded by the panel): ←→↑↓ choose, Enter use (or turn off), W
// widgets.
Item {
    id: desk

    readonly property var dt: Services.DesktopTheme
    // Card 0 is "Off", then the registry.
    readonly property var entries: [null].concat(dt.themes)
    property int sel: Math.max(0, entries.findIndex(t => t && t.id === (dt.enabled ? dt.theme : "")))
    readonly property var info: entries[sel]
    readonly property string selId: info ? info.id : ""
    readonly property bool selActive: selId === (dt.enabled ? dt.theme : "")

    // The panel switches to its Widgets tab.
    signal openWidgets

    function use() {
        dt.setTheme(selId);
    }

    function handleKey(event) {
        const n = entries.length;
        if (event.key === Qt.Key_Right)
            sel = (sel + 1) % n;
        else if (event.key === Qt.Key_Left)
            sel = (sel + n - 1) % n;
        else if (event.key === Qt.Key_Down)
            sel = Math.min(n - 1, sel + strip.columns);
        else if (event.key === Qt.Key_Up)
            sel = Math.max(0, sel - strip.columns);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
            use();
        else if (event.key === Qt.Key_W)
            openWidgets();
        else
            return false;
        return true;
    }

    // ── Theme strip: two rows of cards ────────────────────────────────────────
    Grid {
        id: strip
        width: parent.width
        columns: Math.ceil(desk.entries.length / 2)
        spacing: 10

        Repeater {
            model: desk.entries

            ClickableRect {
                id: card

                required property var modelData
                required property int index
                readonly property bool selected: desk.sel === index
                readonly property bool active: (modelData ? modelData.id : "") === (desk.dt.enabled ? desk.dt.theme : "")
                // Too narrow for the icon beside the text (many themes): stack
                // them, and drop the tagline's trailing "desktop".
                readonly property bool compact: width < 170

                width: (strip.width - strip.spacing * (strip.columns - 1)) / strip.columns
                height: 62
                radius: Services.DesktopTheme.rad(18)
                color: active ? Colors.primary_container : card.hovered || selected ? Colors.surface_container_high : Colors.surface_container
                border.width: selected ? 2 : 0
                border.color: Colors.primary
                cursorShape: Qt.PointingHandCursor
                onClicked: desk.sel = index

                Behavior on color {
                    ColorAnimation { duration: 140 }
                }

                Glyph {
                    id: cardIcon
                    x: card.compact ? 14 : 16
                    y: card.compact ? 8 : (card.height - height) / 2
                    text: card.modelData ? card.modelData.icon : "do_not_disturb_on"
                    filled: card.active
                    font.pixelSize: card.compact ? 20 : 24
                    color: card.active ? Colors.on_primary_container : card.selected ? Colors.primary : Colors.on_surface_variant
                }

                Column {
                    x: card.compact ? 14 : cardIcon.x + cardIcon.width + 12
                    y: card.compact ? 30 : (card.height - height) / 2
                    width: card.width - x - (card.compact ? 10 : 12)
                    spacing: card.compact ? 0 : 2

                    StyledText {
                        width: parent.width
                        text: card.modelData ? card.modelData.name : "Off"
                        elide: Text.ElideRight
                        font.pixelSize: card.compact ? 14 : 15
                        font.weight: Font.DemiBold
                        color: card.active ? Colors.on_primary_container : Colors.on_surface
                    }

                    StyledText {
                        width: parent.width
                        text: card.active ? "In use" : card.modelData ? (card.compact ? card.modelData.tagline.replace(/ desktop$/, "") : card.modelData.tagline) : "Your normal rice"
                        elide: Text.ElideRight
                        font.pixelSize: 11
                        color: card.active ? Colors.withAlpha(Colors.on_primary_container, 0.8) : Colors.on_surface_variant
                    }
                }
            }
        }
    }

    // ── A miniature of the desktop in the selected theme ──────────────────────
    Item {
        id: mock

        readonly property real s: width / 1920
        readonly property var look: desk.dt.lookFor(desk.selId)
        readonly property var hypr: desk.info ? desk.info.hypr : null
        readonly property color glow: hypr ? (hypr.glow ? desk.dt.roleColor(hypr.glow, desk.selId) : "black") : "transparent"
        readonly property real rounding: (hypr ? hypr.rounding : 35) * s * 1.4

        anchors.top: strip.bottom
        anchors.topMargin: 20
        width: Math.min(parent.width * 0.56, (parent.height - strip.height - 20) * 1.6)
        height: width * 10 / 16

        Rectangle {
            id: mockMask
            anchors.fill: parent
            radius: Services.DesktopTheme.rad(18)
            visible: false
            layer.enabled: true
        }

        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: mockMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            Rectangle {
                anchors.fill: parent
                color: Colors.background
            }

            Image {
                id: mockWall
                anchors.fill: parent
                source: "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
                sourceSize: Qt.size(Math.max(1, width), Math.max(1, height))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
            }

            // The wallpaper as drawn, for a layer that reworks it.
            ShaderEffectSource {
                id: mockWallTexture
                width: mockWall.width
                height: mockWall.height
                visible: false
                sourceItem: mockLayer.usesWallpaper ? mockWall : null
            }

            // The theme's real desktop layer, drawn at full size and scaled.
            ThemeLayer {
                id: mockLayer
                width: 1920
                height: 1200
                scale: mock.s
                transformOrigin: Item.TopLeft
                pxScale: mock.s
                themeId: desk.selId
                wallpaper: mockWallTexture
            }

            WidgetPreview {
                scale: mock.s
                transformOrigin: Item.TopLeft
                themeId: desk.selId
            }

            component MockWindow: Rectangle {
                id: mockWin
                property bool focused: false
                // Themes that colour window borders show them here.
                readonly property var themedBorder: mock.hypr ? mock.hypr.border : undefined
                radius: mock.rounding
                color: Colors.withAlpha(Colors.surface_container, 0.9)
                border.width: 1
                border.color: themedBorder
                    ? desk.dt.roleColor(focused ? themedBorder.active[0] : themedBorder.inactive, desk.selId)
                    : Colors.withAlpha(Colors.outline, focused ? 0.5 : 0.3)

                Column {
                    x: parent.width * 0.07
                    y: parent.height * 0.1
                    spacing: parent.height * 0.055

                    Repeater {
                        model: [0.7, 0.45, 0.82, 0.3, 0.6, 0.52, 0.38]

                        Rectangle {
                            required property real modelData
                            required property int index
                            width: mockWin.width * 0.8 * modelData
                            height: Math.max(2, mockWin.height * 0.028)
                            radius: ["round", "pill", "pebble", "lume"].includes(mock.look.shape) ? height / 2 : 0
                            color: index === 0 && mockWin.focused ? desk.dt.accentOf(desk.selId) : Colors.withAlpha(Colors.on_surface, 0.28)
                        }
                    }
                }

                // Unfocused windows dim under themes that ask for it.
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    visible: !mockWin.focused && !!mock.hypr && !!mock.hypr.dim
                    color: Colors.withAlpha("black", mock.hypr && mock.hypr.dim ? mock.hypr.dim * 2 : 0)
                }
            }

            MockWindow {
                x: parent.width * 0.3
                y: parent.height * 0.15
                width: parent.width * 0.32
                height: parent.height * 0.52
            }

            MockWindow {
                x: parent.width * 0.5
                y: parent.height * 0.3
                width: parent.width * 0.34
                height: parent.height * 0.5
                focused: true
                layer.enabled: !!mock.hypr
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: mock.glow
                    // Hard, offset shadows (Broadsheet) as well as glows.
                    shadowBlur: mock.hypr && mock.hypr.sharp ? 0 : 1.0
                    blurMax: 32
                    shadowOpacity: mock.hypr && mock.hypr.glow ? 0.75 : mock.hypr && mock.hypr.sharp ? 0.6 : 0.45
                    shadowHorizontalOffset: mock.hypr && mock.hypr.offset ? mock.hypr.offset[0] * mock.s * 1.4 : 0
                    shadowVerticalOffset: mock.hypr && mock.hypr.offset ? mock.hypr.offset[1] * mock.s * 1.4 : 0
                }
            }

            // The bar, in the theme's look.
            component MockTag: Item {
                id: tag
                property string label
                width: tagText.implicitWidth + 18
                height: 20

                HudFrame {
                    visible: mock.look.shape === "chamfer"
                    cut: 5
                    fill: Colors.surface_container
                }

                NeonFrame {
                    visible: mock.look.shape === "neon"
                    cut: 5
                    fill: Colors.surface_container
                    glow: 0
                }

                DecoFrame {
                    visible: mock.look.shape === "deco"
                    cut: 3
                    fill: Colors.surface_container
                    stroke: desk.dt.borderColor(mock.look, desk.selId)
                }

                CuspFrame {
                    visible: mock.look.shape === "cusp"
                    cut: 4
                    fill: Colors.surface_container
                    stroke: desk.dt.borderColor(mock.look, desk.selId)
                }

                CrenelFrame {
                    visible: mock.look.shape === "crenel"
                    merlon: 5
                    depth: 2
                    fill: Colors.surface_container
                    stroke: desk.dt.borderColor(mock.look, desk.selId)
                }

                Rectangle {
                    anchors.fill: parent
                    visible: !["chamfer", "neon", "deco", "cusp", "crenel"].includes(mock.look.shape)
                    radius: desk.dt.radius(mock.look, 10, height)
                    topLeftRadius: desk.dt.corner(mock.look, radius, 0)
                    topRightRadius: desk.dt.corner(mock.look, radius, 1)
                    bottomRightRadius: desk.dt.corner(mock.look, radius, 2)
                    bottomLeftRadius: desk.dt.corner(mock.look, radius, 3)
                    color: Colors.surface_container
                    border.width: mock.look.shape === "print" ? 0 : mock.look.border
                    border.color: desk.dt.borderColor(mock.look, desk.selId)
                }

                // Broadsheet's rules, Wasteland's rivets.
                Rectangle {
                    visible: mock.look.shape === "print"
                    width: parent.width
                    height: 1
                    color: desk.dt.borderColor(mock.look, desk.selId)
                }

                Rectangle {
                    visible: mock.look.shape === "print"
                    y: parent.height - height
                    width: parent.width
                    height: 2
                    color: desk.dt.borderColor(mock.look, desk.selId)
                }

                Repeater {
                    model: mock.look.shape === "plate" ? 2 : 0

                    Rivet {
                        required property int index
                        size: 3
                        x: index === 0 ? 2 : tag.width - width - 2
                        y: (tag.height - height) / 2
                    }
                }

                // Observatory's graduated foot, Abyss's light strip,
                // Devaloka's temple border.
                ScaleTicks {
                    visible: mock.look.shape === "scale"
                    x: 4
                    y: tag.height - height - 1
                    width: tag.width - 8
                    height: 3
                    up: true
                    step: 3
                    major: 5
                    minorLength: 1
                    majorLength: 2.5
                    color: desk.dt.borderColor(mock.look, desk.selId)
                }

                TempleBorder {
                    visible: mock.look.shape === "zari"
                    x: 4
                    y: tag.height - height - 1
                    width: tag.width - 8
                    height: 2.5
                    step: 3.5
                    rule: 0
                    color: desk.dt.borderColor(mock.look, desk.selId)
                }

                Rectangle {
                    visible: mock.look.shape === "lume"
                    x: 6
                    y: tag.height - 3
                    width: tag.width - 12
                    height: 1.5
                    radius: 1
                    color: desk.dt.accent2Of(desk.selId)
                }

                Text {
                    id: tagText
                    anchors.centerIn: parent
                    text: tag.label
                    font.family: mock.look.font || defaultFont.font.family
                    font.pixelSize: 10
                    font.weight: mock.look.weight
                    font.letterSpacing: mock.look.letterSpacing
                    font.capitalization: mock.look.caps === "small" ? Font.SmallCaps : mock.look.caps ? Font.AllUppercase : Font.MixedCase
                    color: Colors.on_surface
                }
            }

            Text {
                id: defaultFont
                visible: false
            }

            Row {
                x: 10
                y: 6
                spacing: 6

                MockTag {
                    readonly property string pip: ({ chamfer: "◆", square: "■", neon: "▮", deco: "◆", cusp: "✦", print: "▪", plate: "✕", scale: "☉", lume: "◉", zari: "✿", crenel: "♜" })[mock.look.shape] ?? "●"
                    label: pip + " 2 " + pip + " " + pip + " " + pip
                }

                MockTag {
                    label: Qt.formatDateTime(new Date(), "d MMM · hh:mm AP")
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 10
                y: 6
                spacing: 6

                MockTag {
                    label: "󰕾 60%"
                }

                MockTag {
                    label: "󰁹 " + Math.round(Services.Battery.percentage) + "%"
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Services.DesktopTheme.rad(18)
            color: "transparent"
            border.width: 1
            border.color: Colors.withAlpha(Colors.outline_variant, 0.8)
        }
    }

    // The wallpaper palette every theme is coloured with.
    Row {
        anchors.top: mock.bottom
        anchors.topMargin: 18
        anchors.left: mock.left
        spacing: 10

        Repeater {
            model: ["primary", "secondary", "tertiary", "primary_container", "surface_container_high"]

            Rectangle {
                required property string modelData
                width: 30
                height: 30
                radius: Services.DesktopTheme.rad(9)
                color: Colors[modelData]
                border.width: 1
                border.color: Colors.withAlpha(Colors.outline_variant, 0.8)
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 6
            spacing: 1

            StyledText {
                text: "Coloured by your wallpaper"
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            StyledText {
                text: "Every theme re-tints itself when the wallpaper changes"
                font.pixelSize: 12
                color: Colors.on_surface_variant
            }
        }
    }

    // ── Controls ──────────────────────────────────────────────────────────────
    Flickable {
        anchors.left: mock.right
        anchors.leftMargin: 28
        anchors.right: parent.right
        anchors.top: mock.top
        anchors.bottom: parent.bottom
        contentHeight: controls.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: controls
            width: parent.width
            spacing: 16

            Row {
                spacing: 10

                StyledText {
                    id: themeName
                    text: desk.info ? desk.info.name : "Off"
                    font.pixelSize: 24
                    font.weight: Font.Bold
                }

                StyledText {
                    anchors.baseline: themeName.baseline
                    text: desk.info ? desk.info.tagline : "Your normal rice"
                    font.pixelSize: 13
                    color: Colors.primary
                }
            }

            StyledText {
                width: parent.width
                text: desk.info ? desk.info.description : "No desktop theme: Hyprland runs your config exactly as written, and the bar and wallpaper look as they always do."
                font.pixelSize: 13
                lineHeight: 1.2
                wrapMode: Text.WordWrap
                color: Colors.on_surface_variant
            }

            // Use / in use / turn off
            ClickableRect {
                id: useButton
                width: parent.width
                height: 56
                radius: Services.DesktopTheme.rad(18)
                color: desk.selActive ? Colors.surface_container : useButton.hovered ? Qt.lighter(Colors.primary, 1.08) : Colors.primary
                border.width: desk.selActive ? 1 : 0
                border.color: Colors.withAlpha(Colors.outline_variant, 0.8)
                cursorShape: desk.selActive ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: {
                    if (!desk.selActive)
                        desk.use();
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 10

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        text: desk.selActive ? "check_circle" : desk.info ? "palette" : "do_not_disturb_on"
                        filled: true
                        font.pixelSize: 22
                        color: desk.selActive ? Colors.primary : Colors.on_primary
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: desk.selActive ? (desk.info ? desk.info.name + " is on" : "Desktop themes are off")
                            : desk.info ? (desk.dt.enabled ? "Switch to " : "Use ") + desk.info.name
                            : "Turn desktop themes off"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        color: desk.selActive ? Colors.on_surface : Colors.on_primary
                    }
                }
            }

            // Shared options (hidden for "Off").
            Column {
                width: parent.width
                spacing: 16
                visible: desk.info !== null

                component CheckRow: ClickableRect {
                    id: checkRow
                    property bool checked
                    property string title
                    property string subtitle
                    width: controls.width
                    height: 52
                    radius: Services.DesktopTheme.rad(16)
                    color: checkRow.hovered ? Colors.surface_container_high : Colors.surface_container
                    cursorShape: Qt.PointingHandCursor

                    Rectangle {
                        id: box
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22
                        height: 22
                        radius: Services.DesktopTheme.rad(6)
                        color: checkRow.checked ? Colors.primary : "transparent"
                        border.width: checkRow.checked ? 0 : 2
                        border.color: Colors.outline

                        Glyph {
                            anchors.centerIn: parent
                            visible: checkRow.checked
                            text: "check"
                            weight: 700
                            font.pixelSize: 16
                            color: Colors.on_primary
                        }
                    }

                    Column {
                        anchors.left: box.right
                        anchors.leftMargin: 14
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            text: checkRow.title
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }

                        StyledText {
                            width: parent.width
                            elide: Text.ElideRight
                            text: checkRow.subtitle
                            font.pixelSize: 12
                            color: Colors.on_surface_variant
                        }
                    }
                }

                // Widgets live on their own tab.
                ClickableRect {
                    id: widgetsRow
                    width: controls.width
                    height: 52
                    radius: Services.DesktopTheme.rad(16)
                    color: widgetsRow.hovered ? Colors.surface_container_high : Colors.surface_container
                    cursorShape: Qt.PointingHandCursor
                    onClicked: desk.openWidgets()

                    Glyph {
                        id: widgetsIcon
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: "widgets"
                        filled: true
                        font.pixelSize: 22
                        color: Colors.primary
                    }

                    Column {
                        anchors.left: widgetsIcon.right
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            text: "Desktop widgets"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }

                        StyledText {
                            text: Services.DesktopWidgets.widgets.filter(w => Services.DesktopWidgets.enabled(w.id)).length + " on, restyled by this theme · choose and arrange them (W)"
                            font.pixelSize: 12
                            color: Colors.on_surface_variant
                        }
                    }

                    Glyph {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: "chevron_right"
                        font.pixelSize: 22
                        color: Colors.on_surface_variant
                    }
                }

                // Screen effect
                Column {
                    width: parent.width
                    spacing: 8

                    StyledText {
                        text: "Screen effect"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    Row {
                        spacing: 8

                        Repeater {
                            model: [
                                { id: "off", label: "Off" },
                                { id: "subtle", label: "Subtle" },
                                { id: "strong", label: "Strong" }
                            ]

                            ClickableRect {
                                id: effectChip
                                required property var modelData
                                readonly property bool current: desk.dt.screenEffect === modelData.id
                                width: effectLabel.implicitWidth + 30
                                height: 32
                                radius: Services.DesktopTheme.rad(16)
                                color: current ? Colors.secondary_container : effectChip.hovered ? Colors.surface_container_high : Colors.surface_container
                                border.width: current ? 0 : 1
                                border.color: Colors.withAlpha(Colors.outline_variant, 0.7)
                                cursorShape: Qt.PointingHandCursor
                                onClicked: desk.dt.setScreenEffect(modelData.id)

                                StyledText {
                                    id: effectLabel
                                    anchors.centerIn: parent
                                    text: effectChip.modelData.label
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    color: effectChip.current ? Colors.on_secondary_container : Colors.on_surface
                                }
                            }
                        }
                    }

                    StyledText {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: !desk.info ? "" : desk.dt.screenEffect === "off" ? "No screen shader: windows stay untouched."
                            : desk.info.effects[desk.dt.screenEffect]
                        font.pixelSize: 12
                        color: Colors.on_surface_variant
                    }
                }

                CheckRow {
                    checked: desk.dt.matchLock
                    title: "Match the lock screen"
                    subtitle: desk.info ? "Locks with " + Services.LockScreen.theme(desk.info.lockTheme).name + " while this theme is on" : ""
                    onClicked: desk.dt.setMatchLock(!desk.dt.matchLock)
                }

                // What it changes
                Column {
                    width: parent.width
                    spacing: 7

                    Repeater {
                        model: desk.info ? desk.info.changes : []

                        Row {
                            id: changeRow
                            required property var modelData
                            spacing: 10

                            Glyph {
                                anchors.verticalCenter: parent.verticalCenter
                                text: changeRow.modelData.icon
                                font.pixelSize: 17
                                color: Colors.primary
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: controls.width - 30
                                wrapMode: Text.WordWrap
                                text: changeRow.modelData.text
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }

            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Nothing animates while you're idle: the desktop layer is still once it has switched on, and widgets redraw only their own small patch when they change. The screen effect adds one light pass to frames Hyprland draws anyway. Switching themes or turning them off reloads your Hyprland config exactly as written."
                font.pixelSize: 12
                lineHeight: 1.2
                color: Colors.on_surface_variant
            }

            StyledText {
                width: parent.width
                visible: desk.dt.lastError.length > 0
                wrapMode: Text.WordWrap
                text: "Hyprland: " + desk.dt.lastError
                font.pixelSize: 12
                color: Colors.error
            }
        }
    }
}
