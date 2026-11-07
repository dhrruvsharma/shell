pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.lock
import qs.modules.control

// A button on the edge line's spine: a glyph, lit (a lamp of the accent
// behind it) while what it opens is open, an optional figure beside it (a
// battery's charge) and a badge (how many notifications). Its name shows
// beside the spine after a moment under the pointer.
Item {
    id: button

    property string icon
    property string name
    property string figure
    property int badge: 0
    property bool on: false
    property bool filled: false
    property bool vertical: false
    property color ink: Colors.on_surface
    property color accent: Colors.primary
    property color iconColor: button.on ? button.accent : Colors.withAlpha(button.ink, 0.86)

    signal clicked
    signal wheeled(int steps)
    // Hovered long enough for its name to show (the spine shows it).
    signal tip(Item item, string text)
    signal untip(Item item)

    readonly property bool hovered: area.containsMouse
    readonly property real side: 34

    implicitWidth: button.vertical || figureText.text === "" ? button.side : button.side + figureText.implicitWidth + 2
    implicitHeight: button.vertical && figureText.text !== "" ? button.side + figureText.implicitHeight - 4 : button.side

    Rectangle {
        anchors.fill: parent
        radius: ControlStyle.radius(10)
        color: button.on ? Colors.withAlpha(button.accent, 0.2) : area.containsMouse ? Colors.withAlpha(button.ink, 0.1) : "transparent"
        border.width: button.on ? 1 : 0
        border.color: Colors.withAlpha(button.accent, 0.45)

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }
    }

    Glyph {
        id: glyph
        x: button.vertical || figureText.text === "" ? (button.width - width) / 2 : 6
        y: button.vertical && figureText.text !== "" ? 3 : (button.height - height) / 2
        width: 22
        height: 22
        text: button.icon
        filled: button.filled || button.on
        font.pixelSize: 20
        color: button.iconColor

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }
    }

    Text {
        id: figureText
        x: button.vertical ? (button.width - implicitWidth) / 2 : glyph.x + glyph.width + 1
        y: button.vertical ? glyph.y + glyph.height - 2 : (button.height - implicitHeight) / 2
        text: button.figure
        font.family: ControlStyle.mono
        font.pixelSize: button.vertical ? 10 : 11
        font.weight: Font.DemiBold
        color: Colors.withAlpha(button.ink, 0.8)
        rightPadding: button.vertical ? 0 : 6
    }

    Rectangle {
        visible: button.badge > 0
        x: button.width - width - 1
        y: 2
        width: Math.max(14, badgeText.implicitWidth + 6)
        height: 14
        radius: 7
        color: button.accent

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: button.badge > 99 ? "99+" : button.badge
            font.family: ControlStyle.mono
            font.pixelSize: 9
            font.weight: Font.Bold
            color: ControlStyle.inkOn(button.accent)
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
        onWheel: wheel => {
            const steps = wheel.angleDelta.y > 0 ? 1 : wheel.angleDelta.y < 0 ? -1 : 0;
            if (steps !== 0)
                button.wheeled(steps);
        }
        onContainsMouseChanged: {
            if (area.containsMouse) {
                tipDelay.restart();
            } else {
                tipDelay.stop();
                button.untip(button);
            }
        }
    }

    Timer {
        id: tipDelay
        interval: 450
        onTriggered: if (button.name !== "") button.tip(button, button.name)
    }
}
