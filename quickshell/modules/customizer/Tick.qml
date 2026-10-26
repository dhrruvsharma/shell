import QtQuick
import qs.colors
import qs.modules.lock

// A line to tick on a list (what the bar shows, which desktop widgets are
// out): a box, an optional glyph, a name and a few words under it. The
// whole line takes the click. Pointing at it shows it on the facing plate
// (the spread's `focusKey`).
Item {
    id: tick

    property string key: ""
    property string label: ""
    property string note: ""
    property string icon: ""
    property bool checked: false

    signal toggled

    // The spread it's on (found up its parents), told what it points at.
    property Item owner: null

    implicitHeight: tick.note ? 42 : 30

    Component.onCompleted: {
        let p = tick.parent;
        while (p && !("focusKey" in p))
            p = p.parent;
        tick.owner = p;
    }

    HoverHandler {
        onHoveredChanged: {
            if (!tick.owner || !tick.key)
                return;
            if (hovered)
                tick.owner.focusKey = tick.key;
            else if (tick.owner.focusKey === tick.key)
                tick.owner.focusKey = "";
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -8
        anchors.rightMargin: -4
        radius: BookStyle.b.radius ?? 4
        color: BookStyle.well
        visible: area.containsMouse
    }

    InkSwitch {
        id: box
        anchors.verticalCenter: parent.verticalCenter
        checked: tick.checked
        onToggled: tick.toggled()
    }

    Glyph {
        id: glyph
        visible: tick.icon !== ""
        anchors.left: box.right
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: visible ? 22 : 0
        text: tick.icon
        filled: tick.checked
        font.pixelSize: 17
        color: tick.checked ? BookStyle.accent : BookStyle.inkFaint
    }

    Column {
        anchors.left: glyph.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        BookText {
            width: parent.width
            text: tick.label
            elide: Text.ElideRight
            font.family: BookStyle.ui
            font.pixelSize: 14
            font.weight: Font.Medium
            font.capitalization: BookStyle.labelCaps
            font.letterSpacing: BookStyle.labelSpacing * 0.4
            color: tick.checked ? BookStyle.ink : BookStyle.inkSoft
        }

        BookText {
            width: parent.width
            visible: tick.note !== ""
            text: tick.note
            elide: Text.ElideRight
            font.pixelSize: 12
            font.italic: true
            color: BookStyle.inkFaint
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.leftMargin: 30
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tick.toggled()
    }
}
