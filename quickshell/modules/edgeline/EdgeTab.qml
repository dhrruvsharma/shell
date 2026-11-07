pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.lock
import qs.modules.control

// A tab on the popout's strip: its glyph and name (the glyph alone up a
// standing border, its name beside it on hover), lit in the accent while
// it's the one showing.
Item {
    id: tab

    property string icon
    property string name
    property bool current: false
    property bool vertical: false
    property color ink: Colors.on_surface
    property color accent: Colors.primary

    signal clicked
    signal tip(Item item, string text)
    signal untip(Item item)

    implicitWidth: tab.vertical ? 34 : row.implicitWidth + 24
    implicitHeight: 34

    Rectangle {
        anchors.fill: parent
        radius: ControlStyle.radius(10)
        color: tab.current ? Colors.withAlpha(tab.accent, 0.2) : area.containsMouse ? Colors.withAlpha(tab.ink, 0.1) : "transparent"
        border.width: tab.current ? 1 : 0
        border.color: Colors.withAlpha(tab.accent, 0.45)

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: tab.icon
            filled: tab.current
            font.pixelSize: 19
            color: tab.current ? tab.accent : Colors.withAlpha(tab.ink, area.containsMouse ? 0.95 : 0.75)
        }

        Text {
            visible: !tab.vertical
            anchors.verticalCenter: parent.verticalCenter
            text: tab.name
            font.family: ControlStyle.body
            font.pixelSize: 13
            font.weight: tab.current ? Font.DemiBold : Font.Normal
            color: tab.current ? tab.accent : Colors.withAlpha(tab.ink, area.containsMouse ? 0.95 : 0.75)
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tab.clicked()
        onContainsMouseChanged: {
            if (!tab.vertical)
                return;
            if (area.containsMouse)
                tipDelay.restart();
            else {
                tipDelay.stop();
                tab.untip(tab);
            }
        }
    }

    Timer {
        id: tipDelay
        interval: 350
        onTriggered: tab.tip(tab, tab.name)
    }
}
