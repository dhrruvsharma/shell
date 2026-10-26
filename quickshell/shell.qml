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
import qs.modules.customizer
import qs.modules.screenshot

ShellRoot {
    id: root

    // This instance owns the compositor side of desktop themes and writes
    // Firefox's stylesheets (the lock screen instance only reads the choice).
    Component.onCompleted: {
        Services.DesktopTheme.manage = true
        Services.FirefoxTheme.manage = true
        Services.WindowLook.manage = true
        // A night light left on comes back with the shell.
        Services.NightLight.checkAvailable()
    }

    // The control centre's ways into the other panels.
    function openFromControlCenter(which) {
        if (which === "wifi" || which === "bluetooth") {
            if (!networkPanelLoader.active)
                networkPanelLoader.active = true
            const panel = networkPanelLoader.item
            if (!panel)
                return
            panel.currentTab = which === "wifi" ? 0 : 1
            panel.opened = true
        } else if (which === "themes") {
            lockThemes.openTab("desktop")
        } else if (which === "avatar") {
            if (!avatarPicker.opened)
                avatarPicker.open()
        }
    }

    // The customizer's book (SUPER+I; SUPER+B and the gear on the bar open
    // it at the bar): `where` is a chapter or spread, "" for where it was.
    function toggleCustomizer(where) {
        if (!customizerLoader.active)
            customizerLoader.active = true
        customizerLoader.item.toggle(where)
    }

    function openCustomizer(where) {
        if (!customizerLoader.active)
            customizerLoader.active = true
        customizerLoader.item.open(where)
    }

    Connections {
        target: Services.Customizer
        function onRequested(where) {
            root.toggleCustomizer(where)
        }
        // The book hands over to another panel, and closes behind it.
        function onPanelRequested(which) {
            if (customizerLoader.item)
                customizerLoader.item.close()
            if (which === "themes")
                lockThemes.openTab("desktop")
            else if (which === "lockscreen")
                lockThemes.openTab("lock")
            else if (which === "widgets")
                lockThemes.openTab("widgets")
            else if (which === "cava")
                cavaWidget.edit()
            else if (which === "wallpaper") {
                if (!wallpaperLoader.active)
                    wallpaperLoader.active = true
                if (!wallpaperLoader.item.visible)
                    wallpaperLoader.item.open()
            }
        }
    }

    // How things open, on hover or a click (services/Opening, set in the
    // customizer): it asks, these do it.
    function openerAction(target, action, arg) {
        const want = isOpen => action === "toggle" ? !isOpen : action === "open"
        if (target === "launcher") {
            if (want(launcherWindow.isOpen && !launcherWindow.closing))
                launcherWindow.open()
            else
                launcherWindow.close()
        } else if (target === "notes") {
            notesDrawer.opened = want(notesDrawer.opened)
        } else if (target === "github") {
            ghPopout.opened = want(ghPopout.opened)
        } else if (target === "calendar") {
            if (!want(Services.CalendarState.open))
                Services.CalendarState.close()
            else if (arg)
                Services.CalendarState.openAt(arg.pos, arg.length)
            else
                Services.CalendarState.open = true
        } else if (target === "system") {
            systemPanel.opened = want(systemPanel.opened)
        } else if (target === "network" || target === "bluetooth") {
            const tab = target === "network" ? 0 : 1
            const panel = networkPanelLoader.item
            const isOpen = panel !== null && panel.opened && panel.currentTab === tab
            if (want(isOpen)) {
                if (!networkPanelLoader.active)
                    networkPanelLoader.active = true
                networkPanelLoader.item.currentTab = tab
                networkPanelLoader.item.opened = true
            } else if (panel) {
                panel.opened = false
            }
        } else if (target === "media") {
            const isOpen = mediaPanelLoader.item !== null && mediaPanelLoader.item.opened
            if (want(isOpen)) {
                closeTimer.stop()
                if (!mediaPanelLoader.active)
                    mediaPanelLoader.active = true
                mediaPanelLoader.item.opened = true
            } else if (mediaPanelLoader.item) {
                mediaPanelLoader.item.opened = false
            }
        } else if (target === "updates") {
            updatesPanel.opened = want(updatesPanel.opened)
            if (updatesPanel.opened)
                Services.Updates.refresh()
        }
    }

    Connections {
        target: Services.Opening
        function onRequested(target, action, arg) {
            root.openerAction(target, action, arg)
        }
    }

    // What's open, for Opening (a peek that closes some other way is over).
    readonly property var openNow: ({
        launcher: launcherWindow.isOpen && !launcherWindow.closing,
        notes: notesDrawer.opened,
        github: ghPopout.opened,
        calendar: Services.CalendarState.open,
        system: systemPanel.opened,
        network: networkPanelLoader.item !== null && networkPanelLoader.item.opened && networkPanelLoader.item.currentTab === 0,
        bluetooth: networkPanelLoader.item !== null && networkPanelLoader.item.opened && networkPanelLoader.item.currentTab === 1,
        media: mediaPanelLoader.item !== null && mediaPanelLoader.item.opened,
        updates: updatesPanel.opened
    })
    onOpenNowChanged: Services.Opening.report(root.openNow)

    // The wallpaper, with the desktop theme's layer over it.
    WallpaperLayer {}
    NotificationToasts {}
    // A screenshot opened from its notification (scripts/screenshot), over
    // everything while it's open.
    ScreenshotEditor {}
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
    // Strips along the screen edges that open the launcher (the left edge),
    // the notes drawer (the bottom edge) and the GitHub popout (the right
    // edge), on hover or on a click as services/Opening says. Each is a tiny
    // surface of its own, so the full-screen panel surface below can shrink
    // away while no panel is open. They stay on the screen's very edge,
    // where the pointer stops by itself; where the bar lies on that edge
    // they take its outermost two pixels (which the bar leaves them) and
    // open on a click either way, so reaching for the bar doesn't set them
    // off.
    // Declared before it: surfaces on one layer stack in creation order, and
    // the panels must cover the strips (rootPanel's mask leaves them out, so
    // they keep working while a panel is open, as when they lived inside it).
    component EdgeTrigger: PanelWindow {
        id: trigger

        // What it opens (an Opening target); over the bar it opens on a
        // click either way.
        property string target: ""
        property bool overBar: false

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        // Out of the way while the workspace disc is dragged past.
        mask: Region {
            width: Services.WorkspaceDiscService.moving ? 0 : trigger.width
            height: trigger.height
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: if (!trigger.overBar) Services.Opening.entered(trigger.target, null)
            onExited: Services.Opening.left(trigger.target)
            onClicked: Services.Opening.clicked(trigger.target, null)

            Rectangle {
                anchors.fill: parent
                color: parent.containsMouse ? "#40FFFFFF" : "transparent"
                visible: parent.containsMouse
            }
        }
    }

    EdgeTrigger {
        id: notesDrawerTrigger
        target: "notes"
        anchors.bottom: true
        overBar: Services.BarLayout.atBottom
        implicitWidth: 900
        implicitHeight: 2
    }

    // The side strips stop short of a bottom bar.
    EdgeTrigger {
        id: githubTrigger
        target: "github"
        anchors.right: true
        anchors.bottom: true
        margins.bottom: Services.BarLayout.reserveBottom
        overBar: Services.BarLayout.atRight
        implicitWidth: 2
        implicitHeight: 500
    }

    EdgeTrigger {
        id: launcherTrigger
        target: "launcher"
        anchors.left: true
        anchors.bottom: true
        margins.bottom: Services.BarLayout.reserveBottom
        overBar: Services.BarLayout.atLeft
        implicitWidth: 2
        implicitHeight: 600
    }

    OsdWindow {}

    // Minimized readers wait as tabs on the edge they open from; a click
    // brings one back as it was left. Declared before rootPanel so an open
    // panel on the same edge covers them.
    function restoreReader(loader) {
        if (!loader.item)
            return
        // closing it next time unloads it
        loader.item.minimized = false
        loader.item.visible = true
    }

    MinimizedDock {
        side: "left"
        entries: [
            { item: mangaLoader.item, icon: "󰗚", restore: () => root.restoreReader(mangaLoader) },
            { item: animeLoader.item, icon: "󰻏", restore: () => root.restoreReader(animeLoader) }
        ]
    }

    MinimizedDock {
        side: "right"
        entries: [
            { item: novelLoader.item, icon: "󰘝", restore: () => root.restoreReader(novelLoader) }
        ]
    }

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
            || customizerLoader.active
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

            // The customizer's book, built for each opening like the
            // keybinds. The bar stays above its scrim (it isn't in the bar's
            // coveredByPanel), so what's set shows on the bar itself and the
            // bar can still be used; it comes first here, so a panel opened
            // from it or the bar meanwhile (themes, system, media…) comes up
            // over it.
            Loader {
                id: customizerLoader
                active: false
                anchors.fill: parent
                focus: true
                sourceComponent: Customizer {}
            }

            // The media and system panels hang from the middle of the bar's
            // edge, the updates panel from its far end (the right end, or
            // the bottom of a standing bar).
            Loader {
                id: mediaPanelLoader
                active: false
                x: Services.BarLayout.atLeft ? 0 : Services.BarLayout.atRight ? parent.width - width : (parent.width - width) / 2
                y: Services.BarLayout.atBottom ? parent.height - height : Services.BarLayout.vertical ? (parent.height - height) / 2 : 0
                sourceComponent: MediaPanel {
                    id: mediaPanel
                }
                focus: true
            }
            // In the bottom-right corner, clear of a bottom bar (a right bar
            // drops beneath it).
            GhPopout {
                id: ghPopout
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    bottomMargin: Services.BarLayout.reserveBottom
                }
            }
            SystemPanel {
                id: systemPanel
                x: Services.BarLayout.atLeft ? 0 : Services.BarLayout.atRight ? parent.width - width : (parent.width - width) / 2
                y: Services.BarLayout.atBottom ? parent.height - height : Services.BarLayout.vertical ? (parent.height - height) / 2 : 0
            }
            UpdatesPanel {
                id: updatesPanel
                x: Services.BarLayout.atLeft ? 0 : parent.width - width
                y: Services.BarLayout.atTop ? 0 : parent.height - height
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
                    onPanelRequested: which => root.openFromControlCenter(which)
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
                // None while an entry is dragged out, so the drop reaches
                // the window underneath.
                item: clipboardLoader.item && clipboardLoader.item.visible && !clipboardLoader.item.dragging
                    ? clipboardLoader.item : null
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
            Region {
                item: customizerLoader.item && customizerLoader.item.visible ? customizerLoader.item : null
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
                y: rootPanel.screenH - Services.BarLayout.reserveBottom - githubTrigger.implicitHeight
                width: githubTrigger.implicitWidth
                height: githubTrigger.implicitHeight
            }
            Region {
                intersection: Intersection.Subtract
                x: 0
                y: rootPanel.screenH - Services.BarLayout.reserveBottom - launcherTrigger.implicitHeight
                width: launcherTrigger.implicitWidth
                height: launcherTrigger.implicitHeight
            }
        }
    }

    // The bar, on the screen edge Services.BarLayout.edge says (drag it by an
    // empty stretch to another one): its own surface, plus a sliver holding
    // its exclusive zone (modules/bar/Bar.qml). Declared after rootPanel so
    // it stacks above it on the Top layer. While any of the panels below is
    // open the bar drops beneath them; the network panel joins them when
    // the bar stands on the left or right, and the GitHub/timer popout when
    // it stands on the right, where they come out over the bar.
    Bar {
        id: bar
        coveredByPanel: notesDrawer.opened
            || launcherWindow.isOpen
            || (Services.BarLayout.vertical && networkPanelLoader.item !== null && networkPanelLoader.item.visible)
            || (Services.BarLayout.atRight && ghPopout.visible)
            || (wallpaperLoader.item !== null && wallpaperLoader.item.visible)
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
                root.restoreReader(mangaLoader)
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
                root.restoreReader(novelLoader)
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
                root.restoreReader(animeLoader)
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

    // Do not disturb: toasts held back (all but critical ones), the
    // notifications still kept for the control centre.
    IpcHandler {
        target: "notifications"
        function toggleDnd(): void {
            Services.Notification.toggleDnd()
        }
        function setDnd(on: bool): void {
            Services.Notification.setDnd(on)
        }
        function clear(): void {
            Services.Notification.clearAll()
        }
    }

    // The screenshot editor: edit opens any image in it, last the newest
    // shot in ~/Pictures/screenshots.
    IpcHandler {
        target: "screenshot"
        function edit(path: string): void {
            Services.Screenshot.edit(path, "", false)
        }
        function last(): void {
            Services.Screenshot.editLast()
        }
    }

    // Night light (hyprsunset): toggle, or a temperature in kelvin (2500-6500).
    IpcHandler {
        target: "nightLight"
        function toggle(): void {
            Services.NightLight.toggle()
        }
        function setTemperature(kelvin: int): void {
            Services.NightLight.setTemperature(kelvin)
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

    // The customizer's book (SUPER+I): toggle it (where it was left), open
    // it at a chapter or spread ("opening", "bar", "disc", "gaps", "theme",
    // "palette", "desktop", "notices", "pet", or a chapter's number; "" for
    // where it was left), or close it.
    IpcHandler {
        target: "customizer"
        function toggle(): void {
            root.toggleCustomizer("")
        }
        function open(where: string): void {
            root.openCustomizer(where)
        }
        function close(): void {
            if (customizerLoader.item?.visible)
                customizerLoader.item.close()
        }
    }

    Timer {
        id: closeCustomizerTimer
        interval: 600
        // unless it was opened again in the meantime
        onTriggered: if (!customizerLoader.item?.visible) customizerLoader.active = false
    }

    Connections {
        target: customizerLoader.item
        function onVisibleChanged() {
            if (customizerLoader.item && !customizerLoader.item.visible)
                closeCustomizerTimer.start()
        }
    }

    // Hyprland's window settings, as the book's Windows chapter sets them:
    // set an option ("general.gaps_in", "decoration.rounding",
    // "decoration.blur.enabled"…) to a value, or give one (or all) back to
    // the theme's or the config's.
    IpcHandler {
        target: "windowLook"
        function set(key: string, value: string): void {
            Services.WindowLook.setText(key, value)
        }
        function reset(key: string): void {
            Services.WindowLook.clear(key)
        }
        function resetAll(): void {
            Services.WindowLook.clearAll()
        }
        function get(key: string): string {
            return String(Services.WindowLook.value(key))
        }
    }

    // The bar's chapter of the book (SUPER+B), and its settings for scripts:
    // toggleWidget takes one of cpu, memory, temp, battery, clock, network,
    // bluetooth, volume, updates, settings, media, tray, pet; setColor a
    // "#rrggbb" ("" for the wallpaper's); setTransparency 0 (solid) to 100;
    // setWidth a widget (not the tray or pet) and px (0 for auto);
    // setOverflow hover, always or cut.
    IpcHandler {
        target: "barSettings"
        function toggle(): void {
            root.toggleCustomizer("bar")
        }
        function open(): void {
            root.openCustomizer("bar")
        }
        function close(): void {
            if (customizerLoader.item?.visible)
                customizerLoader.item.close()
        }
        function toggleWidget(id: string): void {
            Services.BarSettings.toggle(id)
        }
        function setColor(color: string): void {
            Services.BarSettings.setCustomColor(color)
        }
        function setTransparency(percent: int): void {
            Services.BarSettings.setTransparency(percent / 100)
        }
        function resetLook(): void {
            Services.BarSettings.resetLook()
        }
        function setWidth(id: string, px: int): void {
            Services.BarSettings.setWidth(id, px)
        }
        function setOverflow(mode: string): void {
            Services.BarSettings.setOverflow(mode)
        }
        function resetWidths(): void {
            Services.BarSettings.resetWidths()
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
        // "top", "bottom", "left" or "right" (or drag the bar there).
        function setEdge(edge: string): void {
            Services.BarLayout.setEdge(edge)
        }
        // To the opposite edge.
        function toggleEdge(): void {
            Services.BarLayout.setEdge(Services.BarLayout.opposite(Services.BarLayout.edge))
        }
        function edge(): string {
            return Services.BarLayout.edge
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
