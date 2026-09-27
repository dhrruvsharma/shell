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
    PanelWindow {
        focusable: true
        WlrLayershell.layer: WlrLayer.Bottom
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }
    }
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
    PanelWindow {
        id: rootPanel
        exclusionMode: ExclusionMode.Ignore
        implicitHeight: screen.height
        implicitWidth: screen.width
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        focusable: true

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
        WallhavenWrapper{
            id: wallhavenWrapper
        }
        Loader {
            id: networkPanelLoader
            active: false
            anchors.fill: parent
            sourceComponent: NetworkPanel {
                id: networkPanel
            }
        }

        OsdWindow {}

        NotesDrawer{
            id: notesDrawer
        }

        MouseArea {
            id: notesDrawerTrigger
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            height: 2
            z: 100
            width: 900

            onClicked: {
                notesDrawer.opened = !notesDrawer.opened
            }

            hoverEnabled: true

            Rectangle {
                anchors.fill: parent
                color: parent.containsMouse ? "#40FFFFFF" : "transparent"
                visible: parent.containsMouse
            }
        }

        MouseArea {
            id: githubTrigger
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: 2
            z: 100
            height: 500

            onEntered: {
                ghPopout.opened = !ghPopout.opened
            }

            hoverEnabled: true

            Rectangle {
                anchors.fill: parent
                color: parent.containsMouse ? "#40FFFFFF" : "transparent"
                visible: parent.containsMouse
            }
        }

        LauncherWindow{
            id: launcherWindow
        }

        MouseArea {
            id: launcherTrigger
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: 2
            z: 100
            height: 600

            onEntered: {
                launcherWindow.toggle()
            }

            hoverEnabled: true

            Rectangle {
                anchors.fill: parent
                color: parent.containsMouse ? "#40FFFFFF" : "transparent"
                visible: parent.containsMouse
            }
        }
        Wallpaper{
            id: wallpaper
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

        ClipboardManager {
            id: clipboardManager
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
                item: notesDrawerTrigger
            }
            Region{
                item: controlCenterLoader.item && controlCenterLoader.item.visible ? controlCenterLoader.item : null
            }
            Region {
                item: githubTrigger
            }
            Region {
                item: ghPopout
            }
            Region {
                item: updatesPanel.opened ? updatesPanel : null
            }
            Region{
                item: launcherTrigger
            }
            Region {
                item: launcherWindow.isOpen ? launcherWindow : null
            }
            Region{
                item: wallpaper.visible ? wallpaper : null
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
                item: clipboardManager.visible ? clipboardManager : null
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
            || wallpaper.visible
            || (controlCenterLoader.item !== null && controlCenterLoader.item.visible)
            || chatLoader.active
            || (mangaLoader.item !== null && mangaLoader.item.visible)
            || (novelLoader.item !== null && novelLoader.item.visible)
            || (animeLoader.item !== null && animeLoader.item.visible)
            || aikiraLoader.active
            || clipboardManager.visible
            || notepad.visible
            || powerMenu.visible
            || avatarPicker.visible
            || lockThemes.visible

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
        onTriggered: mangaLoader.active = false
    }

    Connections {
        target: mangaLoader.item
        function onVisibleChanged() {
            if (mangaLoader.item && !mangaLoader.item.visible) {
                closeMangaTimer.start()
            }
        }
    }

    Timer {
        id: closeNovelTimer
        interval: 600
        onTriggered: novelLoader.active = false
    }

    Connections {
        target: novelLoader.item
        function onVisibleChanged() {
            if (novelLoader.item && !novelLoader.item.visible) {
                closeNovelTimer.start()
            }
        }
    }

    Timer {
        id: closeAnimeTimer
        interval: 600
        onTriggered: animeLoader.active = false
    }

    Connections {
        target: animeLoader.item
        function onVisibleChanged() {
            if (animeLoader.item && !animeLoader.item.visible) {
                closeAnimeTimer.start()
            }
        }
    }

    Timer {
        id: closeNetworkTimer
        interval: 600
        onTriggered: networkPanelLoader.active = false
    }

    Connections {
        target: networkPanelLoader.item
        function onOpenedChanged() {
            if (networkPanelLoader.item && !networkPanelLoader.item.opened) {
                closeNetworkTimer.start()
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
            } else {
                mangaLoader.item.visible = !mangaLoader.item.visible
            }
        }
    }

    IpcHandler {
        target: "novelReader"

        function toggle(): void {
            if (!novelLoader.active) {
                novelLoader.active = true
                novelLoader.item.visible = true
            } else {
                novelLoader.item.visible = !novelLoader.item.visible
            }
        }
    }

    IpcHandler {
        target: "animePlayer"

        function toggle(): void {
            if (!animeLoader.active) {
                animeLoader.active = true
                animeLoader.item.visible = true
            } else {
                animeLoader.item.visible = !animeLoader.item.visible
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
            wallpaper.visible = !wallpaper.visible
        }
        function set(path: string): void {
            Services.WallpaperEngine.set(path)
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
            if (!clipboardManager.visible) {
                clipboardManager.open()
            } else {
                clipboardManager.close()
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

}