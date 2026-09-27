import QtQuick
import qs.services as Services
import qs.aikira
import QtQuick.Layouts
import qs.colors
import qs.components

Item {
    id: root
    height: 36

    property string selectedId: ""
    property bool   open:       false

    property string selectedName: {
        if (!selectedId || selectedId === "") return "none (use default)"
        const proxies = AppState.proxies
        if (!proxies || !proxies.length) return "loading…"
        const p = proxies.find(x => x && x.id === selectedId)
        return p ? p.name : "unknown"
    }

    Rectangle {
        anchors.fill: parent
        radius: Services.DesktopTheme.rad(8)
        color: Colors.surface_container_highest
        border { width: open ? 1 : 0; color: Colors.primary }

        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
            StyledText {
                Layout.fillWidth: true
                text: root.selectedName
                font { pixelSize: 12; family: "monospace" }
                color: root.selectedId ? Colors.on_surface : Colors.on_surface_variant
                opacity: root.selectedId ? 1 : 0.5
                elide: Text.ElideRight
            }
            StyledText {
                text: open ? "▲" : "▼"
                font.pixelSize: 9
                color: Colors.on_surface_variant
                opacity: 0.6
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.open = !root.open
        }
    }

    // Dropdown list
    Rectangle {
        visible: open
        anchors { top: parent.bottom; topMargin: 2; left: parent.left; right: parent.right }
        height: Math.min(((AppState.proxies ? AppState.proxies.length : 0) + 1) * 34, 200)
        radius: Services.DesktopTheme.rad(8)
        color: Colors.surface_container_highest
        border { width: 1; color: Colors.outline_variant }
        z: 100
        clip: true

        ListView {
            anchors { fill: parent; topMargin: 4; bottomMargin: 4 }
            model: {
                const none = [{ id: "", name: "none (use default)" }]
                const proxies = AppState.proxies
                return proxies && proxies.length ? none.concat(proxies) : none
            }

            delegate: Item {
                width: ListView.view ? ListView.view.width : 0
                height: 32

                // Guard against null modelData
                property var pdata: modelData || { id: "", name: "" }

                ClickableRect {
                    id: itemRect
                    anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                    radius: Services.DesktopTheme.rad(6)
                    color: root.selectedId === pdata.id
                        ? Colors.primary_container
                        : (itemRect.hovered ? Colors.surface_container_high : "transparent")

                    StyledText {
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 10 }
                        text: pdata.name || ""
                        font { pixelSize: 12; family: "monospace" }
                        color: root.selectedId === pdata.id
                            ? Colors.on_primary_container
                            : Colors.on_surface
                    }
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                            root.selectedId = pdata.id
                            root.open = false
                        }
                }
            }
        }
    }
}
