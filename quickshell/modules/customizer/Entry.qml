pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.lock

// A setting on a right-hand page: its name, a line on what it does, and
// its control (a choice, a tick box, a slider…) beside it, or under it
// when `stacked`. Pointing at it shows its part on the facing plate (it
// sets the spread's `focusKey` to `key`).
//
// `overridden` marks a value set here over the theme's or the config's
// own, with a small way back to that (`reset`).
Item {
    id: entry

    property string key: ""
    property string label: ""
    property string note: ""
    property bool stacked: false
    property real controlWidth: 0
    property bool overridden: false
    property string resetText: "theme's"
    // Greyed out (it does nothing as things are set).
    property bool dim: false

    signal reset

    default property alias control: slot.data

    readonly property bool hovered: hover.hovered
    // The spread it's on (found up its parents), told what it points at.
    property Item owner: null

    implicitHeight: entry.stacked ? texts.height + 10 + slot.height : Math.max(texts.height, slot.height)
    opacity: entry.dim ? 0.45 : 1

    Behavior on opacity {
        NumberAnimation {
            duration: 160
        }
    }

    Component.onCompleted: {
        let p = entry.parent;
        while (p && !("focusKey" in p))
            p = p.parent;
        entry.owner = p;
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (!entry.owner || !entry.key)
                return;
            if (hovered)
                entry.owner.focusKey = entry.key;
            else if (entry.owner.focusKey === entry.key)
                entry.owner.focusKey = "";
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -12
        anchors.rightMargin: -12
        anchors.topMargin: -7
        anchors.bottomMargin: -7
        radius: BookStyle.b.radius ?? 4
        color: BookStyle.well
        opacity: entry.hovered ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 140
            }
        }
    }

    Column {
        id: texts
        width: entry.stacked ? entry.width : entry.width - slot.width - 22
        spacing: 2

        Row {
            spacing: 10

            BookText {
                id: name
                text: entry.label
                font.family: BookStyle.ui
                font.pixelSize: 15
                font.weight: Font.DemiBold
                font.capitalization: BookStyle.labelCaps
                font.letterSpacing: BookStyle.labelSpacing * 0.5
            }

            // Set here: the way back to the theme's own.
            Item {
                visible: entry.overridden
                anchors.verticalCenter: name.verticalCenter
                width: resetRow.implicitWidth
                height: 18

                Row {
                    id: resetRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "undo"
                        font.pixelSize: 13
                        color: resetArea.containsMouse ? BookStyle.accent : BookStyle.inkSoft
                    }

                    BookText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.resetText
                        font.pixelSize: 12
                        font.italic: true
                        color: resetArea.containsMouse ? BookStyle.accent : BookStyle.inkSoft
                    }
                }

                MouseArea {
                    id: resetArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: entry.reset()
                }
            }
        }

        BookText {
            width: parent.width
            visible: entry.note !== ""
            text: entry.note
            wrapMode: Text.WordWrap
            font.pixelSize: BookStyle.bodySize - 1
            font.italic: BookStyle.themeId !== "terminal" && BookStyle.themeId !== "hud"
            color: BookStyle.inkSoft
        }
    }

    Item {
        id: slot

        readonly property Item ctl: slot.children.length > 0 ? slot.children[0] : null

        x: entry.stacked ? 0 : entry.width - slot.width
        y: entry.stacked ? texts.height + 10 : Math.max(0, (Math.min(texts.height, 44) - slot.height) / 2)
        width: entry.stacked ? entry.width : entry.controlWidth > 0 ? entry.controlWidth : slot.ctl ? slot.ctl.implicitWidth : 0
        height: slot.ctl ? slot.ctl.implicitHeight : 0

        onCtlChanged: {
            if (slot.ctl)
                slot.ctl.width = Qt.binding(() => slot.width);
        }
    }
}
