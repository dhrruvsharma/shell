pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.lock
import qs.services as Services

// One of the edge line's panels on the tabs page (EdgeTabEditor): its glyph
// and name on a slip. Pick it up and carry it to another tab, the dotted
// line or the shelf; a click picks the tab it's in.
Rectangle {
    id: chip

    required property string panelId
    property var editor: null

    readonly property var info: Services.EdgeLine.panel(chip.panelId)
    readonly property bool carried: chip.editor !== null && chip.editor.carried === chip.panelId
    // (the editor finds the chips in a row by this)
    readonly property string chipFor: chip.panelId

    implicitWidth: row.implicitWidth + 22
    implicitHeight: 30
    radius: Math.min(BookStyle.b.radius ?? 4, 8)
    color: area.containsMouse && !chip.carried ? BookStyle.wellHover : BookStyle.well
    border.width: 1
    border.color: area.containsMouse ? BookStyle.accent : BookStyle.line
    opacity: chip.carried ? 0.3 : 1

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: chip.info?.icon ?? ""
            font.pixelSize: 16
            color: area.containsMouse ? BookStyle.accent : BookStyle.ink
        }

        BookText {
            anchors.verticalCenter: parent.verticalCenter
            text: chip.info?.name ?? chip.panelId
            font.family: BookStyle.ui
            font.pixelSize: 13
            color: BookStyle.ink
        }
    }

    MouseArea {
        id: area

        property point start: Qt.point(0, 0)
        property bool moving: false

        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: area.moving ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        onContainsMouseChanged: {
            if (chip.editor)
                chip.editor.pointAt(area.containsMouse ? chip.panelId : "");
        }
        onPressed: mouse => {
            area.start = Qt.point(mouse.x, mouse.y);
            area.moving = false;
        }
        onPositionChanged: mouse => {
            if (!area.pressed || !chip.editor)
                return;
            if (!area.moving && Math.hypot(mouse.x - area.start.x, mouse.y - area.start.y) > 6) {
                area.moving = true;
                chip.editor.pickUp(chip.panelId);
            }
            if (area.moving)
                chip.editor.carryTo(chip.editor.mapFromItem(area, mouse.x, mouse.y));
        }
        onReleased: {
            if (!chip.editor)
                return;
            if (area.moving)
                chip.editor.drop();
            else
                chip.editor.choose(chip.panelId);
            area.moving = false;
        }
        onCanceled: {
            if (chip.editor)
                chip.editor.cancel();
            area.moving = false;
        }
    }
}
