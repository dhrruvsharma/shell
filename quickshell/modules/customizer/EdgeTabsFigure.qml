pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.lock
import qs.services as Services

// The tabs' plate: the popout drawn as a blueprint, on the tab that's
// picked on the facing page, laid out the way the line lays it out
// (services/EdgeLine.bento, with the sizes its panes last measured): its
// panes as cells with their glyphs and names, the strip under them with
// every tab on it. The pane the pointer is on, on the facing page, is lit.
Item {
    id: fig

    property string lit: ""

    readonly property var line: Services.EdgeLine
    readonly property var tabs: fig.line.tabs
    readonly property int current: fig.line.activeTab
    readonly property var tab: fig.tabs[fig.current] ?? { name: "", panels: [] }

    // The popout at full size (as on a border lying flat), then scaled
    // into the plate.
    readonly property real gap: 12
    readonly property real cellPad: 14
    readonly property real stripLen: Math.max(420, 150 + fig.tabs.reduce((s, t) => s + 44 + t.name.length * 7.5, 0) + 120)
    readonly property var tree: fig.line.layoutFor(fig.current, fig.tab.panels.map(id => {
            const s = fig.line.panelSize(id);
            return { id: id, w: s[0] + 2 * fig.cellPad, h: s[1] + 2 * fig.cellPad };
        }), fig.tab.panels.map(id => {
            const g = fig.line.panelGuess[id] ?? [300, 200];
            return { id: id, w: g[0] + 2 * fig.cellPad, h: g[1] + 2 * fig.cellPad };
        }), fig.gap, 1700, 800, true, fig.stripLen, 0)
    readonly property real innerW: Math.max(fig.tree ? fig.tree.w : 300, fig.stripLen)
    readonly property real collageH: fig.tree ? fig.tree.h : 200
    readonly property real popW: fig.innerW + 32
    readonly property real popH: 16 + fig.collageH + 10 + 44 + 16
    readonly property real k: Math.min(1, (fig.width - 8) / fig.popW, (fig.height - 8) / fig.popH)
    readonly property var cells: fig.tree ? fig.line.cells(fig.tree, 16, 16, fig.innerW, fig.collageH, fig.gap, {}) : ({})

    Item {
        id: sheet
        anchors.centerIn: parent
        width: fig.popW * fig.k
        height: fig.popH * fig.k

        // The frame, as a draughtsman draws it.
        Rectangle {
            anchors.fill: parent
            radius: 8
            color: Colors.withAlpha(BookStyle.ink, 0.04)
            border.width: 1.5
            border.color: BookStyle.ink
        }

        // The panes.
        Repeater {
            model: fig.tab.panels

            Rectangle {
                id: cellBox

                required property string modelData
                readonly property var info: fig.line.panel(cellBox.modelData)
                readonly property rect r: fig.cells[cellBox.modelData] ?? Qt.rect(0, 0, 0, 0)
                readonly property bool here: fig.lit === cellBox.modelData

                x: cellBox.r.x * fig.k
                y: cellBox.r.y * fig.k
                width: cellBox.r.width * fig.k
                height: cellBox.r.height * fig.k
                radius: 5
                color: cellBox.here ? Colors.withAlpha(BookStyle.accent, 0.16) : BookStyle.well
                border.width: cellBox.here ? 2 : 1
                border.color: cellBox.here ? BookStyle.accent : BookStyle.line

                Behavior on x {
                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on width {
                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 4

                    Glyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: cellBox.info?.icon ?? ""
                        filled: cellBox.here
                        font.pixelSize: Math.max(14, 28 * fig.k * 1.6)
                        color: cellBox.here ? BookStyle.accent : BookStyle.ink
                    }

                    BookText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: cellBox.info?.name ?? ""
                        font.family: BookStyle.ui
                        font.pixelSize: Math.max(10, Math.round(13 * Math.min(1, fig.k * 1.8)))
                        font.capitalization: BookStyle.labelCaps
                        color: cellBox.here ? BookStyle.accent : BookStyle.ink
                    }
                }
            }
        }

        // The strip: the workspaces and the time, the tabs, the actions.
        Item {
            x: 16 * fig.k
            y: (16 + fig.collageH + 10) * fig.k
            width: fig.innerW * fig.k
            height: 44 * fig.k

            Rectangle {
                width: parent.width
                height: 1
                y: -5 * fig.k
                color: BookStyle.line
            }

            Row {
                id: lead
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: 4

                    Rectangle {
                        required property int index
                        anchors.verticalCenter: parent.verticalCenter
                        width: index === 1 ? 12 : 5
                        height: 5
                        radius: 2.5
                        color: index === 1 ? BookStyle.accent : BookStyle.inkFaint
                    }
                }
            }

            Row {
                anchors.left: lead.right
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: fig.tabs

                    Rectangle {
                        id: chip

                        required property var modelData
                        required property int index
                        readonly property bool here: chip.index === fig.current

                        width: chipRow.implicitWidth + 12
                        height: 22
                        radius: 5
                        color: chip.here ? Colors.withAlpha(BookStyle.accent, 0.18) : "transparent"
                        border.width: chip.here ? 1 : 0
                        border.color: BookStyle.accent

                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 3

                            Glyph {
                                anchors.verticalCenter: parent.verticalCenter
                                text: chip.modelData.icon
                                filled: chip.here
                                font.pixelSize: 12
                                color: chip.here ? BookStyle.accent : BookStyle.inkSoft
                            }

                            BookText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: chip.modelData.name
                                font.family: BookStyle.ui
                                font.pixelSize: 10
                                color: chip.here ? BookStyle.accent : BookStyle.inkSoft
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: fig.line.setActiveTab(chip.index)
                        }
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: ["apps", "power_settings_new", "horizontal_rule"]

                    Glyph {
                        required property string modelData
                        text: modelData
                        font.pixelSize: 13
                        color: BookStyle.inkSoft
                    }
                }
            }
        }
    }
}
