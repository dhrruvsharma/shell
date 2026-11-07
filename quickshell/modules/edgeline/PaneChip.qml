import QtQuick
import qs.colors
import qs.modules.lock
import qs.modules.control

// A small button in a pane: a glyph, a word, or both (a word in the accent,
// like the control centre's "Clear all"). Its glyph turns round and round
// while what it started is under way (`spinning`: a scan, a check).
MouseArea {
    id: chip

    property string icon
    property string text
    property bool on: false
    property bool spinning: false

    implicitWidth: (chip.icon !== "" ? 20 : 0) + (chip.text !== "" ? label.implicitWidth : 0) + (chip.icon !== "" && chip.text !== "" ? 4 : 0) + 14
    implicitHeight: 26
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    Rectangle {
        anchors.fill: parent
        radius: ControlStyle.radius(9)
        color: chip.on ? Colors.withAlpha(ControlStyle.accent, 0.18) : chip.containsMouse ? ControlStyle.wellHover : "transparent"
    }

    Row {
        anchors.centerIn: parent
        spacing: 4

        Glyph {
            id: chipGlyph
            visible: chip.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            text: chip.icon
            filled: chip.on
            font.pixelSize: 17
            color: chip.on || chip.spinning || chip.text !== "" ? ControlStyle.accent : Colors.withAlpha(ControlStyle.ink, chip.containsMouse ? 0.95 : 0.7)

            NumberAnimation on rotation {
                running: chip.spinning
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                onRunningChanged: {
                    if (!running)
                        chipGlyph.rotation = 0;
                }
            }
        }

        Text {
            id: label
            visible: chip.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: ControlStyle.label(chip.text)
            font.family: ControlStyle.ui
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.capitalization: ControlStyle.caps
            font.letterSpacing: ControlStyle.upper ? 1 : 0
            color: ControlStyle.paper ? ControlStyle.ink : ControlStyle.accent
        }
    }
}
