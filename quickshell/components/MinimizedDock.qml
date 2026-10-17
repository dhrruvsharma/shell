pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.colors

// Tabs on a screen edge for panels that were minimized: one per panel,
// clicking it brings the panel back. The window is mapped only while at
// least one tab is showing, and takes input only where the tabs are.
//
//   MinimizedDock {
//       side: "left"
//       entries: [{ item: mangaLoader.item, icon: "󰗚",
//                   restore: () => ... }]
//   }
//
// An entry shows while `item.minimized` is set; `restore` puts it back.
PanelWindow {
    id: dock

    property string side: "left"
    property var entries: []

    readonly property bool onLeft: dock.side !== "right"
    readonly property bool anyShown: dock.entries.some(e => e.item && e.item.minimized)

    visible: dock.anyShown
    WlrLayershell.namespace: "quickshell:dock"
    WlrLayershell.layer: WlrLayer.Top
    // Never takes the keyboard: a keyboard-interactive layer would also grab
    // the pointer as it maps.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Normal: sits beside a bar on the same edge rather than under it.
    exclusionMode: ExclusionMode.Normal
    color: "transparent"

    anchors.left: dock.onLeft
    anchors.right: !dock.onLeft

    implicitWidth: 44
    implicitHeight: Math.max(1, tabs.implicitHeight)

    mask: Region {
        item: tabs
    }

    Column {
        id: tabs
        spacing: 6
        anchors.left: dock.onLeft ? parent.left : undefined
        anchors.right: dock.onLeft ? undefined : parent.right

        Repeater {
            model: dock.entries

            delegate: Item {
                id: tab

                required property var modelData
                readonly property bool shown: !!(modelData.item && modelData.item.minimized)
                readonly property bool hovered: tapArea.containsMouse

                // 0 = out, 1 = tucked behind the edge; slides out when shown.
                property real tuck: tab.shown ? 0 : 1
                Behavior on tuck { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                visible: tab.shown
                width: tab.hovered ? 40 : 30
                height: 56
                Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                // The rounded body runs past the screen edge so only the inner
                // corners show.
                Rectangle {
                    id: body
                    readonly property real slideX: (dock.onLeft ? -1 : 1) * tab.tuck * tab.width
                    x: (dock.onLeft ? -radius : 0) + slideX
                    width: parent.width + radius
                    height: parent.height
                    radius: 12
                    color: tab.hovered ? Colors.surface_container_highest : Colors.surface_container_high
                    border.width: 1
                    border.color: Colors.withAlpha(Colors.outline_variant, 0.6)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    // Accent along the screen edge.
                    Rectangle {
                        x: dock.onLeft ? body.radius : parent.width - body.radius - width
                        width: 3
                        height: parent.height - 16
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 1.5
                        color: Colors.primary
                        opacity: tab.hovered ? 1 : 0.7
                    }

                    MaterialIcon {
                        x: (dock.onLeft ? body.radius + 3 : 0) + (tab.width - 3 - width) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: tab.modelData.icon
                        font.pixelSize: tab.hovered ? 20 : 17
                        color: tab.hovered ? Colors.primary : Colors.on_surface_variant
                        Behavior on font.pixelSize { NumberAnimation { duration: 140 } }
                    }
                }

                MouseArea {
                    id: tapArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tab.modelData.restore()
                }
            }
        }
    }
}
