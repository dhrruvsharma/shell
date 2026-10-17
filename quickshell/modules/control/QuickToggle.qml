pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.lock

// A small switch: a lamp with its glyph, lit in the accent while it's on,
// and its name (or its state) under it. `muted` greys it out for something
// that can't work here.
Item {
    id: toggle

    property string icon
    property string label
    property bool on
    property bool muted

    signal clicked

    readonly property color accent: ControlStyle.accent

    implicitWidth: 78
    implicitHeight: lamp.height + 7 + name.implicitHeight

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.clicked()
    }

    Rectangle {
        id: lamp
        anchors.horizontalCenter: parent.horizontalCenter
        width: 50
        height: 50
        topLeftRadius: ControlStyle.corner(25, 0)
        topRightRadius: ControlStyle.corner(25, 1)
        bottomRightRadius: ControlStyle.corner(25, 2)
        bottomLeftRadius: ControlStyle.corner(25, 3)
        color: toggle.on ? toggle.accent : area.containsMouse ? ControlStyle.wellHover : ControlStyle.well
        border.width: toggle.on ? 0 : 1
        border.color: ControlStyle.line
        opacity: toggle.muted ? 0.5 : 1

        Behavior on color {
            ColorAnimation {
                duration: 160
            }
        }

        Glyph {
            anchors.centerIn: parent
            text: toggle.icon
            filled: toggle.on
            font.pixelSize: 22
            color: toggle.on ? ControlStyle.inkOn(toggle.accent) : Colors.withAlpha(ControlStyle.ink, 0.8)
        }
    }

    Text {
        id: name
        anchors.top: lamp.bottom
        anchors.topMargin: 7
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: toggle.label
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
        lineHeight: 0.92
        font.family: ControlStyle.ui
        font.pixelSize: 11
        font.capitalization: ControlStyle.caps
        font.letterSpacing: ControlStyle.upper ? 0.8 : 0.2
        color: toggle.on ? ControlStyle.ink : Colors.withAlpha(ControlStyle.ink, 0.68)
        opacity: toggle.muted ? 0.6 : 1
    }
}
