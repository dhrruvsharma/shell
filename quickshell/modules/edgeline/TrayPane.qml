pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.colors
import qs.modules.lock
import qs.modules.control

// The tray, with no bar to sit in: the apps' icons (a click activates one,
// a middle click its second action), and an app's menu opened right here
// in the pane on a right click, its submenus too.
PaneSection {
    id: pane

    title: EdgeWords.word("tray")
    preferredWidth: 244

    // The menus open: the app's, then each submenu gone into. Every level
    // keeps its own opener: a menu that's let go of takes its entries with
    // it, the submenu being looked at among them.
    property var chain: []
    property string menuTitle: ""
    readonly property var menu: pane.chain.length > 0 ? pane.chain[pane.chain.length - 1] : null
    readonly property var current: [opener0, opener1, opener2, opener3][Math.max(0, Math.min(3, pane.chain.length - 1))]

    function openMenu(item) {
        pane.chain = [];
        pane.menuTitle = item.tooltipTitle || item.title || item.id;
        pane.chain = [item.menu];
    }

    function closeMenu() {
        pane.chain = [];
    }

    QsMenuOpener {
        id: opener0
        menu: pane.chain[0] ?? null
    }
    QsMenuOpener {
        id: opener1
        menu: pane.chain[1] ?? null
    }
    QsMenuOpener {
        id: opener2
        menu: pane.chain[2] ?? null
    }
    QsMenuOpener {
        id: opener3
        menu: pane.chain[3] ?? null
    }

    Text {
        visible: SystemTray.items.values.length === 0
        width: parent.width
        topPadding: 6
        bottomPadding: 6
        horizontalAlignment: Text.AlignHCenter
        text: "Nothing in the tray"
        font.family: ControlStyle.body
        font.pixelSize: 12
        color: Colors.withAlpha(ControlStyle.ink, 0.6)
    }

    Grid {
        id: icons
        width: parent.width
        columns: 6
        spacing: 6

        Repeater {
            model: SystemTray.items.values

            MouseArea {
                id: trayItem
                required property var modelData
                width: (icons.width - 5 * icons.spacing) / 6
                height: width
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton) {
                        trayItem.modelData.activate();
                    } else if (mouse.button === Qt.MiddleButton) {
                        trayItem.modelData.secondaryActivate();
                    } else if (trayItem.modelData.hasMenu) {
                        pane.openMenu(trayItem.modelData);
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: ControlStyle.radius(10)
                    color: trayItem.containsMouse ? ControlStyle.wellHover : ControlStyle.well
                }

                Image {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: trayItem.modelData.icon || ""
                    sourceSize: Qt.size(40, 40)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
            }
        }
    }

    // An app's menu.
    Column {
        visible: pane.menu !== null
        width: parent.width
        spacing: 2

        Item {
            width: parent.width
            height: 26

            PaneChip {
                id: up
                icon: "arrow_back"
                visible: pane.chain.length > 1
                onClicked: pane.chain = pane.chain.slice(0, -1)
            }

            Text {
                anchors.left: up.visible ? up.right : parent.left
                anchors.leftMargin: 4
                anchors.right: shut.left
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: pane.menuTitle
                font.family: ControlStyle.ui
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: ControlStyle.labelColor
            }

            PaneChip {
                id: shut
                anchors.right: parent.right
                icon: "close"
                onClicked: pane.closeMenu()
            }
        }

        Repeater {
            model: pane.current.children

            Item {
                id: entry
                required property var modelData
                width: parent.width
                height: entry.modelData.isSeparator ? 9 : 30

                Rectangle {
                    visible: entry.modelData.isSeparator
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 1
                    color: ControlStyle.line
                }

                MouseArea {
                    id: entryArea
                    visible: !entry.modelData.isSeparator
                    anchors.fill: parent
                    enabled: entry.modelData.enabled
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (entry.modelData.hasChildren) {
                            if (pane.chain.length < 4)
                                pane.chain = pane.chain.concat([entry.modelData]);
                        } else {
                            entry.modelData.triggered();
                            pane.closeMenu();
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: ControlStyle.radius(8)
                        color: entryArea.containsMouse ? ControlStyle.wellHover : "transparent"
                    }

                    Glyph {
                        id: mark
                        x: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        visible: entry.modelData.buttonType !== QsMenuButtonType.None
                        text: entry.modelData.checkState === Qt.Checked ? (entry.modelData.buttonType === QsMenuButtonType.RadioButton ? "radio_button_checked" : "check_box") : (entry.modelData.buttonType === QsMenuButtonType.RadioButton ? "radio_button_unchecked" : "check_box_outline_blank")
                        font.pixelSize: 16
                        color: ControlStyle.accent
                    }

                    Text {
                        anchors.left: mark.visible ? mark.right : parent.left
                        anchors.leftMargin: mark.visible ? 6 : 8
                        anchors.right: more.left
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: (entry.modelData.text || "").replace(/_(?=\S)/, "")
                        font.family: ControlStyle.body
                        font.pixelSize: 12
                        color: Colors.withAlpha(ControlStyle.ink, entry.modelData.enabled ? 0.92 : 0.4)
                    }

                    Glyph {
                        id: more
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        width: entry.modelData.hasChildren ? 18 : 0
                        visible: entry.modelData.hasChildren
                        text: "chevron_right"
                        font.pixelSize: 16
                        color: Colors.withAlpha(ControlStyle.ink, 0.6)
                    }
                }
            }
        }
    }
}
