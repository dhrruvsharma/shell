pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import qs.colors
import qs.components
import qs.modules.lock
import qs.services as Services

// Themes panel, two tabs.
//
// Desktop: desktop themes (services/DesktopTheme.qml), a coordinated look for
// the whole rice that still follows the wallpaper colours: pick one (or Off)
// with a live preview, plus clock, screen effect and lock matching. See
// DesktopThemesTab.qml.
//
// Widgets: desktop widgets on/off and their arrangement (WidgetsTab.qml).
//
// Lock screen: each card shows a live, scaled-down render of the theme itself.
// Click a card to make it the lock screen; with Shuffle on, clicking adds or
// removes themes from the rotation and every lock picks one of them at
// random. Preview runs a theme full screen (LockPreview.qml, never a real
// lock); Lock now locks straight away.
//
// Keys: Tab switches tabs, Esc closes. Lock screen tab: arrows move,
// Enter/Space choose, P preview, S shuffle, L lock now. Desktop tab: ←→
// choose, Enter use, W widgets. Widgets tab: ↑↓ choose, Enter toggle, R reset
// positions.
// `qs ipc call lockscreen toggle` (ALT+SHIFT+H), `qs ipc call themes desktop`.
Item {
    id: root

    anchors.fill: parent
    visible: false

    property int cursor: 0
    property string tab: "lock"
    readonly property int columns: panel.width - 56 > 1000 ? 3 : 2
    readonly property var themes: Services.LockScreen.themes
    readonly property bool shuffle: Services.LockScreen.shuffle

    function open() {
        visible = true;
        cursor = Math.max(0, themes.findIndex(t => t.id === Services.LockScreen.current));
        keys.forceActiveFocus();
        closeAnim.stop();
        openAnim.restart();
    }

    function close() {
        openAnim.stop();
        closeAnim.restart();
    }

    function toggle() {
        if (visible)
            close();
        else
            open();
    }

    readonly property var tabs: ["desktop", "widgets", "lock"]

    function openTab(which) {
        tab = tabs.includes(which) ? which : "lock";
        if (!visible)
            open();
    }

    // Waits out the close fade, so a capture never includes this panel.
    function launch(command) {
        close();
        Quickshell.execDetached(["sh", "-c", "sleep 0.35; " + command]);
    }

    function preview(id) {
        if (Services.LockScreen.has(id))
            launch("QS_LOCK_THEME=" + id + " exec quickshell -p \"$HOME/.config/quickshell/LockPreview.qml\"");
    }

    function lockNow() {
        launch("exec quickshell -p \"$HOME/.config/quickshell/Lock.qml\"");
    }

    // ── Scrim ─────────────────────────────────────────────────────────────────

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
        NumberAnimation { target: scrim; property: "opacity"; to: 0.55; duration: 240; easing.type: Easing.OutCubic }
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

    // ── Panel ─────────────────────────────────────────────────────────────────

    Rectangle {
        id: panel

        PanelDecor {
            radius: panel.radius
            title: "themes"
        }

        anchors.centerIn: parent
        width: Math.min(1220, parent.width * 0.86)
        height: Math.min(900, parent.height * 0.9)
        radius: Services.DesktopTheme.rad(30)
        color: Colors.surface_container_lowest
        border.width: 1
        border.color: Colors.withAlpha(Colors.outline_variant, 0.6)
        clip: true
        opacity: 0
        scale: 0.94

        // Keyboard handling for the whole panel.
        Item {
            id: keys
            focus: true

            Keys.onPressed: event => {
                const n = root.themes.length;
                const cols = root.columns;
                if (event.key === Qt.Key_Escape) {
                    root.close();
                } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                    const i = root.tabs.indexOf(root.tab) + (event.key === Qt.Key_Tab ? 1 : root.tabs.length - 1);
                    root.tab = root.tabs[i % root.tabs.length];
                } else if (root.tab === "desktop") {
                    const desktopTab = desktopLoader.item as DesktopThemesTab;
                    if (!desktopTab || !desktopTab.handleKey(event))
                        return;
                } else if (root.tab === "widgets") {
                    const widgetsTab = widgetsLoader.item as WidgetsTab;
                    if (!widgetsTab || !widgetsTab.handleKey(event))
                        return;
                } else if (event.key === Qt.Key_Right) {
                    root.cursor = (root.cursor + 1) % n;
                } else if (event.key === Qt.Key_Left) {
                    root.cursor = (root.cursor + n - 1) % n;
                } else if (event.key === Qt.Key_Down) {
                    root.cursor = Math.min(n - 1, root.cursor + cols);
                } else if (event.key === Qt.Key_Up) {
                    root.cursor = Math.max(0, root.cursor - cols);
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    Services.LockScreen.select(root.themes[root.cursor].id);
                } else if (event.key === Qt.Key_P) {
                    root.preview(root.themes[root.cursor].id);
                } else if (event.key === Qt.Key_S) {
                    Services.LockScreen.setShuffle(!root.shuffle);
                } else if (event.key === Qt.Key_L) {
                    root.lockNow();
                } else {
                    return;
                }
                event.accepted = true;
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Colors.withAlpha(Colors.primary, 0.07) }
                GradientStop { position: 0.4; color: "transparent" }
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 18

            // ── Header ────────────────────────────────────────────────────────
            Item {
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
                            text: root.tab === "desktop" ? "desktop_windows" : root.tab === "widgets" ? "widgets" : "lock"
                            filled: true
                            font.pixelSize: 24
                            color: Colors.on_primary_container
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        StyledText {
                            text: "Themes"
                            font.pixelSize: 21
                            font.weight: Font.Bold
                        }

                        StyledText {
                            text: root.tab === "desktop"
                                ? (Services.DesktopTheme.enabled ? Services.DesktopTheme.themeFor(Services.DesktopTheme.theme).name + " is on across the desktop" : "One look for the whole rice, in your wallpaper's colours")
                                : root.tab === "widgets" ? "Clock, music, system monitor and more on your desktop, dressed by the theme"
                                : root.shuffle ? "Shuffle: each lock picks one of the selected themes"
                                : "Pick the design used when you lock"
                            font.pixelSize: 13
                            color: Colors.on_surface_variant
                        }
                    }
                }

                // Desktop | Lock screen
                Rectangle {
                    anchors.centerIn: parent
                    width: tabRow.implicitWidth + 8
                    height: 40
                    radius: Services.DesktopTheme.rad(20)
                    color: Colors.surface_container

                    Row {
                        id: tabRow
                        anchors.centerIn: parent
                        spacing: 4

                        Repeater {
                            model: [
                                { id: "desktop", label: "Desktop", icon: "desktop_windows" },
                                { id: "widgets", label: "Widgets", icon: "widgets" },
                                { id: "lock", label: "Lock screen", icon: "lock" }
                            ]

                            ClickableRect {
                                id: tabChip
                                required property var modelData
                                readonly property bool current: root.tab === modelData.id
                                width: tabChipRow.implicitWidth + 28
                                height: 32
                                radius: Services.DesktopTheme.rad(16)
                                color: current ? Colors.primary : tabChip.hovered ? Colors.surface_container_high : "transparent"
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.tab = modelData.id

                                Behavior on color {
                                    ColorAnimation { duration: 140 }
                                }

                                Row {
                                    id: tabChipRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Glyph {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: tabChip.modelData.icon
                                        filled: tabChip.current
                                        font.pixelSize: 17
                                        color: tabChip.current ? Colors.on_primary : Colors.on_surface_variant
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: tabChip.modelData.label
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        color: tabChip.current ? Colors.on_primary : Colors.on_surface
                                    }
                                }
                            }
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    // Shuffle switch
                    ClickableRect {
                        id: shuffleChip
                        visible: root.tab === "lock"
                        anchors.verticalCenter: parent.verticalCenter
                        width: shuffleRow.implicitWidth + 28
                        height: 38
                        radius: Services.DesktopTheme.rad(19)
                        color: root.shuffle ? Colors.secondary_container
                            : shuffleChip.hovered ? Colors.surface_container_high : Colors.surface_container
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.LockScreen.setShuffle(!root.shuffle)

                        Row {
                            id: shuffleRow
                            anchors.centerIn: parent
                            spacing: 8

                            Glyph {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "shuffle"
                                font.pixelSize: 18
                                color: root.shuffle ? Colors.on_secondary_container : Colors.on_surface_variant
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Shuffle"
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                color: root.shuffle ? Colors.on_secondary_container : Colors.on_surface
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 30
                                height: 18
                                radius: Services.DesktopTheme.rad(9)
                                color: root.shuffle ? Colors.primary : Colors.surface_container_highest

                                Rectangle {
                                    width: 12
                                    height: 12
                                    radius: Services.DesktopTheme.rad(6)
                                    y: 3
                                    x: root.shuffle ? 15 : 3
                                    color: root.shuffle ? Colors.on_primary : Colors.outline

                                    Behavior on x {
                                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                                    }
                                }
                            }
                        }
                    }

                    ClickableRect {
                        id: lockNowChip
                        visible: root.tab === "lock"
                        anchors.verticalCenter: parent.verticalCenter
                        width: lockRow.implicitWidth + 28
                        height: 38
                        radius: Services.DesktopTheme.rad(19)
                        color: lockNowChip.hovered ? Qt.lighter(Colors.primary, 1.08) : Colors.primary
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.lockNow()

                        Row {
                            id: lockRow
                            anchors.centerIn: parent
                            spacing: 8

                            Glyph {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "lock"
                                filled: true
                                font.pixelSize: 17
                                color: Colors.on_primary
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Lock now"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: Colors.on_primary
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

            // ── Theme cards (live previews, created only while open) ──────────
            Loader {
                id: gridLoader
                width: parent.width
                height: parent.height - 52 - footer.height - 2 * parent.spacing
                visible: root.tab === "lock"
                active: root.visible && root.tab === "lock"
                sourceComponent: gridComponent
            }

            // ── Desktop themes ────────────────────────────────────────────────
            Loader {
                id: desktopLoader
                width: parent.width
                height: gridLoader.height
                visible: root.tab === "desktop"
                active: root.visible && root.tab === "desktop"
                sourceComponent: desktopComponent
            }

            // ── Desktop widgets ───────────────────────────────────────────────
            Loader {
                id: widgetsLoader
                width: parent.width
                height: gridLoader.height
                visible: root.tab === "widgets"
                active: root.visible && root.tab === "widgets"
                sourceComponent: WidgetsTab {}
            }

            // ── Footer: progression shared by every theme ─────────────────────
            Item {
                id: footer
                width: parent.width
                height: 44

                Rectangle {
                    anchors.fill: parent
                    radius: Services.DesktopTheme.rad(16)
                    color: Colors.surface_container

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 16
                        spacing: 18

                        Repeater {
                            model: [
                                { icon: "military_tech", text: "Level " + Services.LockStats.level + " · " + Services.LockStats.rank },
                                { icon: "bolt", text: Services.LockStats.xp.toLocaleString(Qt.locale(), "f", 0) + " XP" },
                                { icon: "local_fire_department", text: Services.LockStats.liveStreak + "-day streak" },
                                { icon: "emoji_events", text: Services.LockStats.achievements.length + "/" + Services.LockStats.achievementDefs.length + " trophies" }
                            ]

                            Row {
                                id: stat
                                required property var modelData
                                spacing: 6

                                Glyph {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: stat.modelData.icon
                                    filled: true
                                    font.pixelSize: 17
                                    color: Colors.primary
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: stat.modelData.text
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }
                            }
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "progress is shared by every theme"
                            font.pixelSize: 12
                            color: Colors.on_surface_variant
                        }
                    }

                    StyledText {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.tab === "lock" ? "←→ choose · Enter set · P preview · S shuffle · L lock · Tab desktop"
                            : root.tab === "widgets" ? "↑↓ choose · Enter toggle · R reset · drag to move · Tab lock screens"
                            : "←→ choose · Enter use · W widgets · Tab widgets · Esc close"
                        font.pixelSize: 12
                        color: Colors.on_surface_variant
                    }
                }
            }
        }
    }

    Component {
        id: gridComponent

        Item {
            // Demo context for the thumbnails: never talks to PAM; its ambient
            // clock runs only while the panel is open.
            LockContext {
                id: previewCtx
                preview: true
                ambient: root.visible
                phase: "ready"
            }

            Flickable {
                anchors.fill: parent
                contentHeight: grid.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Grid {
                    id: grid
                    width: parent.width
                    columns: root.columns
                    spacing: 18

                    readonly property real cardW: (width - (columns - 1) * spacing) / columns

                    Repeater {
                        model: root.themes

                        Rectangle {
                            id: card

                            required property var modelData
                            required property int index
                            readonly property bool chosen: root.shuffle
                                ? Services.LockScreen.activeIds.includes(modelData.id)
                                : Services.LockScreen.current === modelData.id
                            readonly property bool focused: root.cursor === index

                            width: grid.cardW
                            height: thumb.height + info.implicitHeight + 34
                            radius: Services.DesktopTheme.rad(22)
                            color: cardArea.containsMouse || focused ? Colors.surface_container_high : Colors.surface_container
                            border.width: chosen ? 2 : 1
                            border.color: chosen ? Colors.primary
                                : focused ? Colors.withAlpha(Colors.primary, 0.5) : Colors.withAlpha(Colors.outline_variant, 0.7)

                            Behavior on color {
                                ColorAnimation { duration: 140 }
                            }

                            MouseArea {
                                id: cardArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.cursor = card.index
                                onClicked: Services.LockScreen.select(card.modelData.id)
                            }

                            // Live thumbnail of the theme itself.
                            Item {
                                id: thumb
                                x: 10
                                y: 10
                                width: parent.width - 20
                                height: Math.round(width * 10 / 16)

                                Rectangle {
                                    id: thumbMask
                                    anchors.fill: parent
                                    radius: Services.DesktopTheme.rad(14)
                                    visible: false
                                    layer.enabled: true
                                }

                                // Rounded through its own layer effect: the content must
                                // stay visible, or themes that render through nested
                                // layers (the CRT terminal) never update.
                                Item {
                                    anchors.fill: parent
                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        maskEnabled: true
                                        maskSource: thumbMask
                                        maskThresholdMin: 0.5
                                        maskSpreadAtMin: 1.0
                                    }

                                    ThemeHost {
                                        anchors.fill: parent
                                        ctx: previewCtx
                                        themeId: card.modelData.id
                                        still: true
                                        minScale: 0
                                    }
                                }

                                // Preview button, on hover.
                                ClickableRect {
                                    id: previewChip
                                    anchors.centerIn: parent
                                    width: previewRow.implicitWidth + 26
                                    height: 36
                                    radius: Services.DesktopTheme.rad(18)
                                    visible: cardArea.containsMouse || previewChip.hovered
                                    color: previewChip.hovered ? Colors.primary : Colors.withAlpha(Colors.scrim, 0.62)
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.preview(card.modelData.id)

                                    Row {
                                        id: previewRow
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Glyph {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "play_arrow"
                                            filled: true
                                            font.pixelSize: 18
                                            color: previewChip.hovered ? Colors.on_primary : "white"
                                        }

                                        StyledText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Preview"
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                            color: previewChip.hovered ? Colors.on_primary : "white"
                                        }
                                    }
                                }

                                // Active badge.
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 10
                                    visible: card.chosen
                                    width: badgeRow.implicitWidth + 18
                                    height: 26
                                    radius: Services.DesktopTheme.rad(13)
                                    color: Colors.primary

                                    Row {
                                        id: badgeRow
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Glyph {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: root.shuffle ? "shuffle" : "check"
                                            font.pixelSize: 15
                                            color: Colors.on_primary
                                        }

                                        StyledText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: root.shuffle ? "In rotation" : "Active"
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            color: Colors.on_primary
                                        }
                                    }
                                }
                            }

                            Column {
                                id: info
                                anchors.top: thumb.bottom
                                anchors.topMargin: 12
                                x: 16
                                width: parent.width - 32
                                spacing: 3

                                Row {
                                    spacing: 8

                                    StyledText {
                                        id: nameLabel
                                        text: card.modelData.name
                                        font.pixelSize: 16
                                        font.weight: Font.Bold
                                    }

                                    StyledText {
                                        anchors.baseline: nameLabel.baseline
                                        text: card.modelData.tagline
                                        font.pixelSize: 12
                                        color: Colors.primary
                                    }
                                }

                                StyledText {
                                    width: parent.width
                                    text: card.modelData.description
                                    font.pixelSize: 12
                                    color: Colors.on_surface_variant
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    lineHeight: 1.15
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: desktopComponent

        DesktopThemesTab {
            onOpenWidgets: root.tab = "widgets"
        }
    }
}
