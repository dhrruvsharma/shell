import QtQuick
import Quickshell
import qs.modules.network
import qs.modules.control
import qs.modules.calendar
import qs.modules.media
import qs.modules.bar
import qs.modules.system
import qs.modules.switcher
import Quickshell.Io
import qs.services as Services
import qs.components
import qs.Osd
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.modules.launcher
import qs.modules.wallpaper
import qs.modules.manga
import qs.modules.novel
import qs.modules.anime
import qs.modules.workspacedisc
import qs.modules.expose
import qs.modules.cava
import qs.aikira
import qs.modules.notes
import qs.modules.clipboard
import qs.modules.notepad
import qs.modules.ollama
import qs.modules.power
import qs.modules.github
import qs.modules.avatar
import qs.modules.updates
import qs.modules.lockthemes
import qs.modules.desktoptheme
import qs.modules.desktopwidgets
import qs.modules.pet
import qs.modules.keybinds

ShellRoot {
    id: root

    // This instance owns the compositor side of desktop themes and writes
    // Firefox's stylesheets (the lock screen instance only reads the choice).
    Component.onCompleted: {
        Services.DesktopTheme.manage = true
        Services.FirefoxTheme.manage = true
    }

    // The wallpaper, with the desktop theme's layer over it.
    WallpaperLayer {}
    NotificationToasts {}
    CalendarWindow {}
    DesktopWidgetsLayer {}
    WorkspaceDiscWindow {}
    Expose {}
    CavaWidget { id: cavaWidget }
    WindowSwitcher{}
    Visualizer {
        id: visBottom
        anchorBottom: true
        visible: false
    }
    Visualizer {
        id: visTop
        anchorBottom: false
        visible: visBottom.visible
    }
    // Hover strips along the screen edges that open the launcher, the notes
    // drawer and the GitHub popout. Each is a tiny surface of its own, so the
    // full-screen panel surface below can shrink away while no panel is open.
    // Declared before it: surfaces on one layer stack in creation order, and
    // the panels must cover the strips (rootPanel's mask leaves them out, so
    // they keep working while a panel is open, as when they lived inside it).
    component EdgeTrigger: PanelWindow {
        id: trigger

        signal hovered
        signal clicked

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: trigger.hovered()
            onClicked: trigger.clicked()

            Rectangle {
                anchors.fill: parent
                color: parent.containsMouse ? "#40FFFFFF" : "transparent"
                visible: parent.containsMouse
            }
        }
    }

    EdgeTrigger {
        id: notesDrawerTrigger
        anchors.bottom: true
        implicitWidth: 900
        implicitHeight: 2
        onClicked: notesDrawer.opened = !notesDrawer.opened
    }

    EdgeTrigger {
        id: githubTrigger
        anchors.right: true
        anchors.bottom: true
        implicitWidth: 2
        implicitHeight: 500
        onHovered: ghPopout.opened = !ghPopout.opened
    }

    EdgeTrigger {
        id: launcherTrigger
        anchors.left: true
        anchors.bottom: true
        implicitWidth: 2
        implicitHeight: 600
        onHovered: launcherWindow.toggle()
    }

    OsdWindow {}

    PanelWindow {
        id: rootPanel

        // Whether any panel is up (or on its way out). While none is, the
        // surface shrinks to a pixel in the corner rather than being unmapped
        // (a new map would stack it over the bar and take keyboard focus):
        // its full-screen buffers cost GPU memory, and the compositor blends
        // it into every frame it draws. hypr/quickshell.lua turns Hyprland's
        // layer animation off for this namespace, or the panels would be
        // drawn growing out of the corner as the surface grows.
        WlrLayershell.namespace: "quickshell:panels"
        readonly property bool needed: mediaPanelLoader.active
            || ghPopout.visible
            || systemPanel.visible
            || updatesPanel.visible
            || networkPanelLoader.active
            || notesDrawer.opened || notesDrawer.implicitHeight > 0
            || launcherWindow.isOpen
            || wallpaperLoader.active
            || controlCenterLoader.active
            || chatLoader.active
            || (mangaLoader.item !== null && mangaLoader.item.visible)
            || (novelLoader.item !== null && novelLoader.item.visible)
            || (animeLoader.item !== null && animeLoader.item.visible)
            || aikiraLoader.active
            || clipboardLoader.active
            || notepad.visible
            || powerMenu.visible
            || avatarPicker.visible
            || lockThemes.visible
            || keybindsLoader.active
        readonly property real screenW: screen ? screen.width : 1920
        readonly property real screenH: screen ? screen.height : 1200

        exclusionMode: ExclusionMode.Ignore
        implicitHeight: needed ? screenH : 1
        implicitWidth: needed ? screenW : 1
        anchors {
            top: true
            bottom: needed
            left: true
            right: needed
        }
        color: "transparent"
        focusable: true

        // The panels, laid out on the whole screen whatever the surface's
        // size at the moment (it grows from and shrinks to the top-left
        // corner, so nothing moves).
        Item {
            width: rootPanel.screenW
            height: rootPanel.screenH

            Loader {
                id: mediaPanelLoader
                active: false
                anchors.horizontalCenter: parent.horizontalCenter
                sourceComponent: MediaPanel {
                    id: mediaPanel
                }
                focus: true
            }
            GhPopout {
                id: ghPopout
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                }
            }
            SystemPanel {
                id: systemPanel
            }
            UpdatesPanel {
                id: updatesPanel
                anchors {
                    right: parent.right
                    top: parent.top
                }
            }
            Loader {
                id: networkPanelLoader
                active: false
                anchors.fill: parent
                sourceComponent: NetworkPanel {
                    id: networkPanel
                }
            }

            NotesDrawer{
                id: notesDrawer
            }

            LauncherWindow{
                id: launcherWindow
            }

            Loader {
                id: wallpaperLoader
                active: false
                anchors.fill: parent
                sourceComponent: Wallpaper {}
                focus: true
            }

            Loader {
                active: false
                id: controlCenterLoader
                anchors.fill: parent
                sourceComponent: ControlCenter {
                    id: controlCenter
                }
                focus: true
            }
            Loader {
                active: false
                id: chatLoader
                anchors.centerIn: parent
                sourceComponent: OllamaChat{
                    id: ollamaChat
                }
                focus: true
            }
            Loader {
                active: false
                id: mangaLoader
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
                sourceComponent: MangaReader{
                    id: mangaReader
                }
            }
            Loader {
                active: false
                id: novelLoader
                anchors {
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                }
                sourceComponent: NovelReader{
                    id: novelReaderReader
                }
            }
            Loader {
                active: false
                id: animeLoader
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
                sourceComponent: AnimePanel{
                    id: animePlayer
                }
            }

            Loader {
                active: false
                id: aikiraLoader
                anchors.centerIn: parent
                sourceComponent: Aikira {
                    id: aikiraChat
                }
                focus: true
            }

            // Built for each opening (the emoji and kaomoji lists, the history
            // and its thumbnails stayed in memory behind the closed panel), on
            // the tab it was last left on.
            Loader {
                id: clipboardLoader
                active: false
                anchors.fill: parent
                focus: true

                property int lastTab: 0

                sourceComponent: ClipboardManager {
                    currentTab: clipboardLoader.lastTab
                    onCurrentTabChanged: clipboardLoader.lastTab = currentTab
                }
            }

            NotepadPanel {
                id: notepad
            }

            PowerMenu {
                id: powerMenu
            }

            AvatarPicker {
                id: avatarPicker
            }

            LockThemesPanel {
                id: lockThemes
            }

            // Built for each opening, like the clipboard: the keyboard, the
            // list and the apps' icons go again once it has closed.
            Loader {
                id: keybindsLoader
                active: false
                anchors.fill: parent
                focus: true
                sourceComponent: KeybindsPanel {}
            }

        }

        property bool altHeld: false

        mask: Region{
            Region{
                item: mediaPanelLoader.active ? mediaPanelLoader : null
            }
            Region{
                item: systemPanel
            }
            Region {
                item: networkPanelLoader.item && networkPanelLoader.item.visible ? networkPanelLoader.item : null
            }
            Region{
                item: notesDrawer.opened ? notesDrawer : null
            }
            Region{
                item: controlCenterLoader.item && controlCenterLoader.item.visible ? controlCenterLoader.item : null
            }
            Region {
                item: ghPopout
            }
            Region {
                item: updatesPanel.opened ? updatesPanel : null
            }
            Region {
                item: launcherWindow.isOpen ? launcherWindow : null
            }
            Region{
                item: wallpaperLoader.item && wallpaperLoader.item.visible ? wallpaperLoader.item : null
            }
            Region{
                item: chatLoader.active ? chatLoader : null
            }
            Region{
                item: mangaLoader.item && mangaLoader.item.visible ? mangaLoader.item : null
            }
            Region{
                item: novelLoader.item && novelLoader.item.visible ? novelLoader.item : null
            }
            Region{
                item: animeLoader.item && animeLoader.item.visible ? animeLoader.item : null
            }
            Region {
                item: aikiraLoader.active ? aikiraLoader : null
            }
            Region {
                item: clipboardLoader.item && clipboardLoader.item.visible ? clipboardLoader.item : null
            }
            Region {
                item: notepad.visible ? notepad : null
            }
            Region {
                item: powerMenu.visible ? powerMenu : null
            }
            Region {
                item: avatarPicker
            }
            Region {
                item: lockThemes.visible ? lockThemes : null
            }
            Region {
                item: keybindsLoader.item && keybindsLoader.item.visible ? keybindsLoader.item : null
            }
            // The edge strips stay with their own surfaces below.
            Region {
                intersection: Intersection.Subtract
                x: (rootPanel.screenW - notesDrawerTrigger.implicitWidth) / 2
                y: rootPanel.screenH - notesDrawerTrigger.implicitHeight
                width: notesDrawerTrigger.implicitWidth
                height: notesDrawerTrigger.implicitHeight
            }
            Region {
                intersection: Intersection.Subtract
                x: rootPanel.screenW - githubTrigger.implicitWidth
                y: rootPanel.screenH - githubTrigger.implicitHeight
                width: githubTrigger.implicitWidth
                height: githubTrigger.implicitHeight
            }
            Region {
                intersection: Intersection.Subtract
                x: 0
                y: rootPanel.screenH - launcherTrigger.implicitHeight
                width: launcherTrigger.implicitWidth
                height: launcherTrigger.implicitHeight
            }
        }
    }

    // The bar has its own 42px surface: hover animations and value updates in
    // the bar then repaint a thin strip instead of the fullscreen panel
    // surface above. It also reserves the bar's exclusive zone. Declared after
    // rootPanel so it stacks above it on the Top layer.
    //
    // Inside the old shared surface, panels declared after TopBar drew over
    // it while the ones before it (media, GitHub, system, updates, network,
    // which hang from the bar) drew under it. To keep that, the bar drops to
    // the Bottom layer — beneath rootPanel — while any of the later panels is
    // open. The layer changes in place (layer-shell set_layer), no remap.
    PanelWindow {
        id: barWindow

        readonly property bool coveredByPanel: notesDrawer.opened
            || launcherWindow.isOpen
            || (wallpaperLoader.item !== null && wallpaperLoader.item.visible)
            || (controlCenterLoader.item !== null && controlCenterLoader.item.visible)
            || chatLoader.active
            || (mangaLoader.item !== null && mangaLoader.item.visible)
            || (novelLoader.item !== null && novelLoader.item.visible)
            || (animeLoader.item !== null && animeLoader.item.visible)
            || aikiraLoader.active
            || (clipboardLoader.item !== null && clipboardLoader.item.visible)
            || notepad.visible
            || powerMenu.visible
            || avatarPicker.visible
            || lockThemes.visible
            || (keybindsLoader.item !== null && keybindsLoader.item.visible)

        WlrLayershell.layer: coveredByPanel ? WlrLayer.Bottom : WlrLayer.Top
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: 42
        color: "transparent"

        TopBar {
            id: topBar
        }
    }

    // The bar pet's hub and speech bubble (the pet itself lives in TopBar).
    // Both are windows only while they're showing.
    PetHub {}
    PetBubble {}

    Connections {
        target: mediaPanelLoader.item
        function onOpenedChanged() {
            if (!mediaPanelLoader.item.opened) {
                closeTimer.start()
            }
        }
    }

    Timer {
        id: closeTimer
        interval: 600
        onTriggered: mediaPanelLoader.active = false
    }

    Timer {
        id: closeChatTimer
        interval: 600
        onTriggered: chatLoader.active = false
    }

    Connections {
        target: chatLoader.item
        function onVisibleChanged() {
            if (chatLoader.item && !chatLoader.item.visible) {
                closeChatTimer.start()
            }
        }
    }

    Timer {
        id: closeMangaTimer
        interval: 600
        // unless it was reopened or minimized in the meantime
        onTriggered: if (!mangaLoader.item?.visible && !mangaLoader.item?.minimized) mangaLoader.active = false
    }

    Connections {
        target: mangaLoader.item
        function onVisibleChanged() {
            if (mangaLoader.item && !mangaLoader.item.visible && !mangaLoader.item.minimized) {
                closeMangaTimer.start()
            }
        }
    }

    Timer {
        id: closeNovelTimer
        interval: 600
        // unless it was reopened or minimized in the meantime
        onTriggered: if (!novelLoader.item?.visible && !novelLoader.item?.minimized) novelLoader.active = false
    }

    Connections {
        target: novelLoader.item
        function onVisibleChanged() {
            if (novelLoader.item && !novelLoader.item.visible && !novelLoader.item.minimized) {
                closeNovelTimer.start()
            }
        }
    }

    Timer {
        id: closeAnimeTimer
        interval: 600
        // unless it was reopened or minimized in the meantime
        onTriggered: if (!animeLoader.item?.visible && !animeLoader.item?.minimized) animeLoader.active = false
    }

    Connections {
        target: animeLoader.item
        function onVisibleChanged() {
            if (animeLoader.item && !animeLoader.item.visible && !animeLoader.item.minimized) {
                closeAnimeTimer.start()
            }
        }
    }

    Timer {
        id: closeNetworkTimer
        interval: 600
        // unless it was opened again in the meantime
        onTriggered: if (!networkPanelLoader.item?.opened) networkPanelLoader.active = false
    }

    Connections {
        target: networkPanelLoader.item
        function onOpenedChanged() {
            if (networkPanelLoader.item && !networkPanelLoader.item.opened) {
                closeNetworkTimer.start()
            }
        }
    }

    // bluetoothd wants an answer (a pairing code, a device asking to
    // connect): bring up the Bluetooth tab, where the question is.
    Connections {
        target: Services.Bluetooth
        function onRequestArrived() {
            if (!networkPanelLoader.active)
                networkPanelLoader.active = true
            const panel = networkPanelLoader.item
            if (!panel)
                return
            panel.currentTab = 1
            panel.opened = true
        }
    }

    Timer {
        id: closeWallpaperTimer
        interval: 600
        // unless it was opened again in the meantime
        onTriggered: if (!wallpaperLoader.item?.visible) wallpaperLoader.active = false
    }

    Connections {
        target: wallpaperLoader.item
        function onVisibleChanged() {
            if (wallpaperLoader.item && !wallpaperLoader.item.visible) {
                closeWallpaperTimer.start()
            }
        }
    }

    Timer {
        id: closeControlCenterTimer
        interval: 600
        onTriggered: controlCenterLoader.active = false
    }

    Connections {
        target: controlCenterLoader.item
        function onOpenedChanged() {
            if (controlCenterLoader.item && !controlCenterLoader.item.opened) {
                closeControlCenterTimer.start()
            }
        }
    }

    IpcHandler {
        target: "mediaPanel"

        function toggle(): void {
            if (!mediaPanelLoader.active) {
                mediaPanelLoader.active = true
                mediaPanelLoader.item.opened = true
            } else {
                mediaPanelLoader.item.opened = !mediaPanelLoader.item.opened
            }
        }
    }

    IpcHandler {
        target: "mangaReader"

        function toggle(): void {
            if (!mangaLoader.active) {
                mangaLoader.active = true
                mangaLoader.item.visible = true
            } else if (mangaLoader.item.visible) {
                mangaLoader.item.visible = false
            } else {
                // restoring a minimized panel; closing it next time unloads it
                mangaLoader.item.minimized = false
                mangaLoader.item.visible = true
            }
        }
    }

    IpcHandler {
        target: "novelReader"

        function toggle(): void {
            if (!novelLoader.active) {
                novelLoader.active = true
                novelLoader.item.visible = true
            } else if (novelLoader.item.visible) {
                novelLoader.item.visible = false
            } else {
                // restoring a minimized panel; closing it next time unloads it
                novelLoader.item.minimized = false
                novelLoader.item.visible = true
            }
        }
    }

    IpcHandler {
        target: "animePlayer"

        function toggle(): void {
            if (!animeLoader.active) {
                animeLoader.active = true
                animeLoader.item.visible = true
            } else if (animeLoader.item.visible) {
                animeLoader.item.visible = false
            } else {
                // restoring a minimized panel; closing it next time unloads it
                animeLoader.item.minimized = false
                animeLoader.item.visible = true
            }
        }
    }

    IpcHandler {
        target: "networkPanel"

        function changeVisible(tab: string): void {
            if (!networkPanelLoader.active)
                networkPanelLoader.active = true

            const panel = networkPanelLoader.item
            if (!panel)
                return

            if (panel.opened) {
                panel.opened = false
                return
            }

            if (tab === "wifi")
                panel.currentTab = 0
            else if (tab === "bluetooth")
                panel.currentTab = 1

            if (tab !== undefined)
                panel.opened = true
            else
                panel.opened = !panel.opened
        }
    }

    IpcHandler {
        target: "controlCenter"
        function changeVisible(): void {
            if (!controlCenterLoader.active) {
                controlCenterLoader.active = true
                controlCenterLoader.item.opened = true
            } else {
                controlCenterLoader.item.opened = !controlCenterLoader.item.opened
            }
        }
    }

    IpcHandler {
        target: "ollamaChat"
        function changeVisible(): void {
            if (!chatLoader.active) {
                chatLoader.active = true
                chatLoader.item.visible = true
            } else {
                chatLoader.item.visible = !chatLoader.item.visible
            }
        }
    }

    IpcHandler {
        target: "visBottom"

        function toggle() {
            visBottom.visible = !visBottom.visible
        }
    }

    IpcHandler {
        target: "launcherWindow"

        function toggle() {
            launcherWindow.toggle()
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle() {
            if (!wallpaperLoader.active)
                wallpaperLoader.active = true
            const picker = wallpaperLoader.item
            if (!picker.visible || picker.closing)
                picker.open()
            else
                picker.close()
        }
        function set(path: string): void {
            Services.WallpaperEngine.set(path)
        }
        function wallhaven(): void {
            if (!wallpaperLoader.active)
                wallpaperLoader.active = true
            wallpaperLoader.item.open()
            wallpaperLoader.item.setMode("wallhaven")
        }
        function current(): string {
            return Services.WallpaperEngine.current
        }
    }

    Timer {
        id: closeWindowSwitcherTimer
        interval: 300
        onTriggered: windowSwitcherLoader.active = false
    }

    IpcHandler {
        target: "clipboardManager"
        function changeVisible(): void {
            if (!clipboardLoader.active)
                clipboardLoader.active = true
            const clipboard = clipboardLoader.item
            if (!clipboard.visible) {
                clipboard.open()
            } else {
                clipboard.close()
            }
        }
    }

    Timer {
        id: closeClipboardTimer
        interval: 600
        // unless it was opened again in the meantime
        onTriggered: if (!clipboardLoader.item?.visible) clipboardLoader.active = false
    }

    Connections {
        target: clipboardLoader.item
        function onVisibleChanged() {
            if (clipboardLoader.item && !clipboardLoader.item.visible) {
                closeClipboardTimer.start()
            }
        }
    }

    IpcHandler {
        target: "notepad"
        function toggle(): void {
            notepad.toggle()
        }
    }

    IpcHandler {
        target: "powerMenu"
        function toggle(): void {
            if (!powerMenu.visible) {
                powerMenu.open()
            } else {
                powerMenu.close()
            }
        }
    }

    IpcHandler {
        target: "desktopTheme"
        function toggle(): void {
            Services.DesktopTheme.toggle()
        }
        function enable(): void {
            if (!Services.DesktopTheme.enabled)
                Services.DesktopTheme.toggle()
        }
        function set(theme: string): void {
            Services.DesktopTheme.setTheme(theme)
        }
        function disable(): void {
            Services.DesktopTheme.setTheme("")
        }
        function screenEffect(mode: string): void {
            Services.DesktopTheme.setScreenEffect(mode)
        }
    }

    IpcHandler {
        target: "themes"
        function toggle(): void {
            lockThemes.toggle()
        }
        function desktop(): void {
            lockThemes.openTab("desktop")
        }
        function lockscreen(): void {
            lockThemes.openTab("lock")
        }
        function widgets(): void {
            lockThemes.openTab("widgets")
        }
    }

    IpcHandler {
        target: "widgets"
        function toggle(): void {
            if (lockThemes.visible && lockThemes.tab === "widgets")
                lockThemes.close()
            else
                lockThemes.openTab("widgets")
        }
        function enable(id: string): void {
            Services.DesktopWidgets.setEnabled(id, true)
        }
        function disable(id: string): void {
            Services.DesktopWidgets.setEnabled(id, false)
        }
        function reset(): void {
            Services.DesktopWidgets.resetPositions()
        }
    }

    IpcHandler {
        target: "lockscreen"
        function toggle(): void {
            lockThemes.toggle()
        }
        function open(): void {
            lockThemes.open()
        }
        function close(): void {
            lockThemes.close()
        }
        function lock(): void {
            lockThemes.lockNow()
        }
        function preview(theme: string): void {
            lockThemes.preview(theme)
        }
    }

    IpcHandler {
        target: "keybinds"
        function toggle(): void {
            if (!keybindsLoader.active)
                keybindsLoader.active = true
            keybindsLoader.item.toggle()
        }
        function open(): void {
            if (!keybindsLoader.active)
                keybindsLoader.active = true
            if (!keybindsLoader.item.visible)
                keybindsLoader.item.open()
        }
        function close(): void {
            if (keybindsLoader.item?.visible)
                keybindsLoader.item.close()
        }
    }

    Timer {
        id: closeKeybindsTimer
        interval: 600
        // unless it was opened again in the meantime
        onTriggered: if (!keybindsLoader.item?.visible) keybindsLoader.active = false
    }

    Connections {
        target: keybindsLoader.item
        function onVisibleChanged() {
            if (keybindsLoader.item && !keybindsLoader.item.visible)
                closeKeybindsTimer.start()
        }
    }

    IpcHandler {
        target: "avatarPicker"
        function toggle(): void {
            if (!avatarPicker.opened) {
                avatarPicker.open()
            } else {
                avatarPicker.close()
            }
        }
    }

    IpcHandler {
        target: "barLayout"
        function reset(): void {
            Services.BarLayout.reset()
        }
    }

    IpcHandler {
        target: "updatesPanel"
        function toggle(): void {
            updatesPanel.opened = !updatesPanel.opened
            if (updatesPanel.opened)
                Services.Updates.refresh()
        }
        function refresh(): void {
            Services.Updates.refresh()
        }
    }

    IpcHandler {
        target: "cavaWidget"
        function toggle(): void {
            cavaWidget.toggle()
        }
        function edit(): void {
            cavaWidget.edit()
        }
        function reset(): void {
            Services.CavaWidget.reset()
        }
    }

    IpcHandler {
        target: "aikiraChat"
        function changeVisible(): void {
            if (!aikiraLoader.active) {
                aikiraLoader.active = true
                aikiraLoader.item.visible = true
            } else {
                aikiraLoader.item.visible = !aikiraLoader.item.visible
            }
        }
    }

    Timer {
        id: closeAikiraTimer
        interval: 600
        onTriggered: aikiraLoader.active = false
    }

    Connections {
        target: aikiraLoader.item
        function onVisibleChanged() {
            if (aikiraLoader.item && !aikiraLoader.item.visible) {
                closeAikiraTimer.start()
            }
        }
    }

    IpcHandler {
        target: "pet"
        function toggle(): void {
            Services.Pet.toggleHub()
        }
        function open(): void {
            if (!Services.Pet.hubOpen)
                Services.Pet.toggleHub()
        }
        function close(): void {
            Services.Pet.hubOpen = false
        }
        function say(text: string): void {
            Services.Pet.say(text)
        }
        function pat(): void {
            Services.Pet.pat()
        }
        function feed(): void {
            Services.Pet.feed()
        }
        function play(): void {
            Services.Pet.play()
        }
        function nap(): void {
            Services.Pet.nap()
        }
        function wake(): void {
            Services.Pet.act("wake")
        }
        function show(): void {
            Services.Pet.setShown(true)
        }
        function hide(): void {
            Services.Pet.setShown(false)
        }
    }
}
