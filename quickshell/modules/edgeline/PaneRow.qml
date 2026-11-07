pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.lock
import qs.modules.control

// A row in a pane's list (a network, a device, a note): its glyph, a name
// and a line under it, and something at its end (a figure, or a glyph that
// is a button of its own). Lit while it's the one in use; while it's busy
// (connecting, joining) a spinner turns at its end.
Item {
    id: row

    property string icon
    property string title
    property string subtitle
    property string figure
    // A button at the end (forget, disconnect, delete), shown on hover.
    property string action
    property string actionName
    property bool on: false
    property bool busy: false
    property bool filled: row.on

    signal clicked
    signal actionClicked

    readonly property bool hovered: area.containsMouse || actionArea.containsMouse
    readonly property real r: 12

    implicitHeight: row.subtitle !== "" ? 46 : 38

    Rectangle {
        anchors.fill: parent
        topLeftRadius: ControlStyle.corner(row.r, 0)
        topRightRadius: ControlStyle.corner(row.r, 1)
        bottomRightRadius: ControlStyle.corner(row.r, 2)
        bottomLeftRadius: ControlStyle.corner(row.r, 3)
        color: row.on ? Colors.withAlpha(ControlStyle.accent, ControlStyle.paper ? 0.14 : 0.16) : row.hovered ? ControlStyle.wellHover : ControlStyle.well
        border.width: row.on ? 1 : 0
        border.color: Colors.withAlpha(ControlStyle.accent, 0.45)

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.clicked()
    }

    Glyph {
        id: glyph
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        text: row.icon
        filled: row.filled
        font.pixelSize: 19
        color: row.on ? ControlStyle.accent : Colors.withAlpha(ControlStyle.ink, 0.75)
        opacity: row.busy ? 0.6 : 1
    }

    Column {
        opacity: row.busy ? 0.75 : 1
        anchors.left: glyph.right
        anchors.leftMargin: 9
        anchors.right: end.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: row.title
            elide: Text.ElideRight
            font.family: ControlStyle.body
            font.pixelSize: 13
            font.weight: row.on ? Font.DemiBold : Font.Normal
            color: ControlStyle.ink
        }

        Text {
            visible: row.subtitle !== ""
            width: parent.width
            text: row.subtitle
            elide: Text.ElideRight
            font.family: ControlStyle.body
            font.pixelSize: 11
            color: Colors.withAlpha(ControlStyle.ink, 0.6)
        }
    }

    Item {
        id: end
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(figureText.visible ? figureText.implicitWidth + 4 : 0, actionArea.visible || row.busy ? 28 : 0)
        height: 28

        // Under way.
        Glyph {
            id: spinner
            visible: row.busy
            anchors.centerIn: parent
            text: "progress_activity"
            font.pixelSize: 18
            color: ControlStyle.accent

            NumberAnimation on rotation {
                running: row.busy
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
            }
        }

        Text {
            id: figureText
            visible: row.figure !== "" && !(row.action !== "" && row.hovered) && !row.busy
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: row.figure
            font.family: ControlStyle.mono
            font.pixelSize: 11
            color: Colors.withAlpha(ControlStyle.ink, 0.6)
        }

        MouseArea {
            id: actionArea
            visible: row.action !== "" && row.hovered && !row.busy
            anchors.right: parent.right
            width: 28
            height: 28
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.actionClicked()

            Rectangle {
                anchors.fill: parent
                radius: ControlStyle.radius(14)
                color: actionArea.containsMouse ? ControlStyle.wellHover : "transparent"
            }

            Glyph {
                anchors.centerIn: parent
                text: row.action
                font.pixelSize: 17
                color: actionArea.containsMouse ? ControlStyle.danger : Colors.withAlpha(ControlStyle.ink, 0.62)
            }
        }
    }
}
