import QtQuick
import qs.colors
import qs.components
import qs.modules.lock
import qs.services as Services

// One of the wallpaper's tones, as a paint card: the fill, with its name
// and an "Aa" in the text that goes on it; ticked while it's in use.
ClickableRect {
    id: root

    property string label
    property color fill
    property color ink
    property bool chosen: false

    implicitWidth: 120
    implicitHeight: 58
    radius: Services.DesktopTheme.rad(14)
    color: root.fill
    border.width: root.chosen ? 2 : 1
    border.color: root.chosen ? Colors.primary : root.hovered ? Colors.outline : Colors.withAlpha(Colors.outline_variant, 0.9)
    cursorShape: Qt.PointingHandCursor

    StyledText {
        x: 12
        y: 9
        width: parent.width - 40
        text: root.label
        elide: Text.ElideRight
        font.pixelSize: 12
        font.weight: Font.DemiBold
        color: root.ink
        opacity: 0.85
    }

    StyledText {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        text: "Aa"
        font.pixelSize: 22
        font.weight: Font.Bold
        color: root.ink
    }

    Rectangle {
        visible: root.chosen
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 7
        width: 18
        height: 18
        radius: 9
        color: Colors.primary

        Glyph {
            anchors.centerIn: parent
            text: "check"
            font.pixelSize: 13
            weight: 700
            color: Colors.on_primary
        }
    }
}
