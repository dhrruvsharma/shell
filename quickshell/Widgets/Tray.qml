import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.colors
import qs.components
import qs.services as Services

// The tray's icons: in a row, or a column on a standing bar (`vertical`).
GridLayout {
    id: trayRoot

    property bool vertical: false
    property int iconSize: 16
    property var pinnedApps: []
    property var blacklist: []
    property bool hidePassive: false

    flow: trayRoot.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    rowSpacing: 6
    columnSpacing: 6

    Repeater {
        model: SystemTray.items.values

        delegate: Rectangle {
            // Filter here instead
            visible: {
                let item = modelData
                if (!item) return false
                if (trayRoot.blacklist.some(name =>
                    item.id.toLowerCase().includes(name.toLowerCase())))
                    return false
                if (trayRoot.hidePassive && item.status === SystemTrayStatus.Passive)
                    return false
                return true
            }
            height: visible ? trayRoot.iconSize + 10 : 0
            width: visible ? trayRoot.iconSize + 10 : 0

            Layout.preferredWidth: visible ? trayRoot.iconSize + 10 : 0
            Layout.preferredHeight: visible ? trayRoot.iconSize + 10 : 0

            // Lit while its menu is out, and under the pointer: on the bar
            // as one strip in the strip's wash, as its widgets are.
            readonly property bool menuOpen: contextMenu.hasCurrent && contextMenu.chain.length > 0 && contextMenu.chain[0] === modelData.menu
            radius: Services.BarSettings.strip ? Services.DesktopTheme.rad(6) : 6
            color: !Services.BarSettings.strip ? (itemMouseArea.containsMouse || menuOpen ? Colors.primary_container : "transparent")
                : menuOpen ? Services.BarSettings.lit
                : itemMouseArea.containsMouse ? Services.BarSettings.wash : "transparent"

            Image {
                id: trayIcon
                anchors.centerIn: parent

                width: trayRoot.iconSize
                height: trayRoot.iconSize

                source: modelData.icon || ""
                // Requested at (twice) the drawn size: unsized, an app's
                // largest tray pixmap was decoded and kept.
                sourceSize: Qt.size(trayRoot.iconSize * 2, trayRoot.iconSize * 2)
                fillMode: Image.PreserveAspectFit
                smooth: true
                visible: status === Image.Ready || status === Image.Loading
            }

            // ---------- fallback ----------
            StyledText {
                anchors.centerIn: parent
                text: trayIcon.status === Image.Error ? "?" : ""
                font.pixelSize: 10
                visible: trayIcon.status === Image.Error
            }

            // ---------- interactions ----------
            MouseArea {
                id: itemMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton)
                        modelData.activate()
                    else if (mouse.button === Qt.MiddleButton)
                        modelData.secondaryActivate()
                    else if (mouse.button === Qt.RightButton && modelData.hasMenu)
                        contextMenu.toggle(modelData.menu, Services.BarLayout.along(this, width / 2, height / 2))
                }
            }
        }
    }

    TrayContextMenu {
        id: contextMenu
    }
}
