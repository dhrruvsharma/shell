pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Hyprland
import qs.colors
import qs.services as Services
import qs.modules.control

// The workspaces as a board: a card for each (the one you're on lit), with
// its number and the icons of the windows on it; a click goes there. Under
// it, the window you're in.
PaneSection {
    id: pane

    title: EdgeWords.word("workspaces")
    preferredWidth: 316

    readonly property var spaces: Hyprland.workspaces.values.filter(w => w.id > 0)
    readonly property int focused: Hyprland.focusedWorkspace?.id ?? 1
    // Whole rows of three, at least two of them.
    readonly property int count: Math.ceil(Math.max(6, pane.focused, ...pane.spaces.map(w => w.id)) / 3) * 3

    function iconOf(t) {
        const cls = t?.wayland?.appId || t?.lastIpcObject?.class || "";
        return cls ? Services.AppRegistry.iconForClass(cls) : "";
    }

    trailing: [
        Text {
            text: pane.spaces.reduce((n, w) => n + w.toplevels.values.length, 0) + " windows"
            font.family: ControlStyle.mono
            font.pixelSize: 11
            color: Colors.withAlpha(ControlStyle.ink, 0.55)
        }
    ]

    Grid {
        id: board
        width: parent.width
        columns: 3
        rowSpacing: 8
        columnSpacing: 8

        Repeater {
            model: pane.count

            MouseArea {
                id: card
                required property int index
                readonly property int ws: card.index + 1
                readonly property var space: pane.spaces.find(w => w.id === card.ws) ?? null
                readonly property var windows: card.space ? card.space.toplevels.values : []
                readonly property bool here: card.ws === pane.focused

                width: (board.width - 2 * board.columnSpacing) / 3
                height: 62
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.Hyprland.changeWorkspace(card.ws)

                Rectangle {
                    anchors.fill: parent
                    radius: ControlStyle.radius(12)
                    color: card.here ? Colors.withAlpha(ControlStyle.accent, 0.18) : card.containsMouse ? ControlStyle.wellHover : card.windows.length > 0 ? ControlStyle.well : "transparent"
                    border.width: 1
                    border.color: card.here ? Colors.withAlpha(ControlStyle.accent, 0.6) : ControlStyle.line

                    Behavior on color {
                        ColorAnimation {
                            duration: 140
                        }
                    }
                }

                Text {
                    x: 9
                    y: 5
                    text: card.ws
                    font.family: ControlStyle.display
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    color: card.here ? ControlStyle.accent : Colors.withAlpha(ControlStyle.ink, card.windows.length > 0 ? 0.9 : 0.4)
                }

                Text {
                    visible: card.windows.length > 3
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    y: 7
                    text: "+" + (card.windows.length - 3)
                    font.family: ControlStyle.mono
                    font.pixelSize: 10
                    color: Colors.withAlpha(ControlStyle.ink, 0.55)
                }

                Row {
                    x: 9
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 7
                    spacing: 4

                    Repeater {
                        model: card.windows.slice(0, 3)

                        Item {
                            id: appIcon
                            required property var modelData
                            readonly property string src: pane.iconOf(appIcon.modelData)
                            width: 20
                            height: 20

                            Image {
                                anchors.fill: parent
                                visible: appIcon.src !== ""
                                source: appIcon.src
                                sourceSize: Qt.size(40, 40)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                            }

                            Rectangle {
                                visible: appIcon.src === ""
                                anchors.centerIn: parent
                                width: 8
                                height: 8
                                radius: 4
                                color: Colors.withAlpha(ControlStyle.ink, 0.5)
                            }
                        }
                    }
                }
            }
        }
    }

    // The window you're in.
    Text {
        visible: text !== ""
        width: parent.width
        elide: Text.ElideRight
        text: Hyprland.activeToplevel?.title ?? ""
        font.family: ControlStyle.body
        font.pixelSize: 11
        color: Colors.withAlpha(ControlStyle.ink, 0.6)
    }
}
