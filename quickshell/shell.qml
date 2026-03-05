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
import qs.quotes
import qs.modules.launcher
import qs.modules.wallpaper

ShellRoot {
    id: root
    NotificationToasts {}
    CalendarWindow {}
    RandomQuote{}
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

        Loader {
            id: networkPanelLoader
            active: false
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            sourceComponent: NetworkPanel {
                id: networkPanel
            }
        }

        OsdWindow {}

        PanelWindow{
            implicitHeight: 42
            implicitWidth: 0
            anchors {
                top: true
            }
            color: "transparent"
            mask: rootPanel.mask
        }

        TopBar{
            id: topBar
        }
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
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            sourceComponent: ControlCenter {
                id: controlCenter
            }
            focus: true
        }

        property bool altHeld: false

        mask: Region{
            Region{
                item: mediaPanelLoader.active ? mediaPanelLoader : null
            }
            Region{
                item: systemPanel
            }
            Region{
                item: topBar
            }
            Region {
                item: networkPanelLoader.item ? networkPanelLoader.item : null
            }
            Region{
                item: notesDrawer.opened ? notesDrawer : null
            }
            Region{
                item: notesDrawerTrigger
            }
            Region{
                item: controlCenterLoader.active ? controlCenterLoader : null
            }
            Region {
                item: githubTrigger
            }
            Region {
                item: ghPopout
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
    }

    Timer {
        id: closeWindowSwitcherTimer
        interval: 300
        onTriggered: windowSwitcherLoader.active = false
    }

}