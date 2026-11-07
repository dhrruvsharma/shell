pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.services as Services
import qs.modules.lock
import qs.modules.control

// One pinned command on the commands tile (CommandsPane): its glyph, what
// it does and where. A click runs it (the glyph turns while it does, the
// tile flashes when it went through, and turns red when it didn't); hovered,
// a × unpins it; a right click renames it; carried, it moves among the
// others (the board, `board`, keeps where everything goes meanwhile).
Item {
    id: tile

    required property var modelData
    required property int index
    required property var board

    readonly property var cmd: tile.modelData
    readonly property var ipc: Services.IpcCommands
    readonly property string key: tile.ipc.key(tile.cmd)
    readonly property var run: tile.ipc.runs[tile.key] ?? null
    readonly property bool running: tile.run?.state === "running"
    readonly property bool failed: tile.run?.state === "failed"
    readonly property bool carried: tile.board.dragFrom === tile.index
    readonly property bool hovered: area.containsMouse || unpinArea.containsMouse
    property bool renaming: false
    property real flash: 0

    readonly property point home: tile.board.slotPos(tile.board.slotOf(tile.index))

    x: tile.carried ? tile.board.carryX : tile.home.x
    y: tile.carried ? tile.board.carryY : tile.home.y
    z: tile.carried ? 10 : 0
    width: tile.board.cellW
    height: tile.board.cellH
    scale: tile.carried ? 1.06 : 1

    Behavior on x {
        enabled: !tile.carried
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }
    Behavior on y {
        enabled: !tile.carried
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 120
        }
    }

    function startRename() {
        tile.renaming = true;
        input.text = tile.ipc.titleOf(tile.cmd);
        input.selectAll();
        input.forceActiveFocus();
    }

    function finishRename(keep) {
        if (!tile.renaming)
            return;
        tile.renaming = false;
        if (!keep)
            return;
        const t = input.text.trim();
        // (its own words again: no name of yours)
        const made = tile.ipc.titleOf(Object.assign({}, tile.cmd, { name: "" }));
        // (the tiles are made again for it: not from inside this one's handler)
        Qt.callLater(tile.ipc.rename, tile.index, t === made ? "" : t);
    }

    Connections {
        target: tile.ipc

        function onRan(k, ok) {
            if (k === tile.key && ok)
                flashAnim.restart();
        }
    }

    SequentialAnimation {
        id: flashAnim
        NumberAnimation {
            target: tile
            property: "flash"
            to: 1
            duration: 90
        }
        NumberAnimation {
            target: tile
            property: "flash"
            to: 0
            duration: 520
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: ControlStyle.radius(12)
        color: tile.carried || (area.containsMouse && !tile.renaming) ? ControlStyle.wellHover : ControlStyle.well
        border.width: tile.failed || tile.carried || tile.renaming ? 1 : 0
        border.color: tile.failed ? ControlStyle.danger : ControlStyle.accent

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: ControlStyle.accent
            opacity: tile.flash * 0.35
        }
    }

    Glyph {
        visible: !tile.running
        anchors.horizontalCenter: parent.horizontalCenter
        y: 8
        text: tile.failed ? "error" : tile.ipc.glyphOf(tile.cmd.target)
        filled: !tile.failed && (area.containsMouse || tile.flash > 0)
        font.pixelSize: 20
        color: tile.failed ? ControlStyle.danger : area.containsMouse || tile.flash > 0 ? ControlStyle.accent : Colors.withAlpha(ControlStyle.ink, 0.8)
    }

    // (made while it runs, so the glyph above is never left turned)
    Loader {
        active: tile.running
        anchors.horizontalCenter: parent.horizontalCenter
        y: 8

        sourceComponent: Glyph {
            text: "progress_activity"
            font.pixelSize: 20
            color: ControlStyle.accent

            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                running: true
            }
        }
    }

    Text {
        id: title
        visible: !tile.renaming
        anchors.horizontalCenter: parent.horizontalCenter
        y: 32
        width: parent.width - 12
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: tile.ipc.titleOf(tile.cmd)
        font.family: ControlStyle.ui
        font.pixelSize: 11
        font.weight: Font.DemiBold
        color: ControlStyle.ink
    }

    Text {
        visible: !tile.renaming
        anchors.horizontalCenter: parent.horizontalCenter
        y: 47
        width: parent.width - 12
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideMiddle
        text: tile.ipc.detailOf(tile.cmd)
        font.family: ControlStyle.mono
        font.pixelSize: 9
        color: Colors.withAlpha(ControlStyle.ink, 0.55)
    }

    // Its name of yours, while it's being given one.
    Rectangle {
        visible: tile.renaming
        anchors.horizontalCenter: parent.horizontalCenter
        y: 32
        width: parent.width - 10
        height: 26
        radius: ControlStyle.radius(7)
        color: ControlStyle.well
        border.width: 1
        border.color: ControlStyle.accent

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 5
            anchors.rightMargin: 5
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignHCenter
            clip: true
            maximumLength: 40
            font.family: ControlStyle.ui
            font.pixelSize: 11
            color: ControlStyle.ink
            selectionColor: Colors.withAlpha(ControlStyle.accent, 0.4)
            onAccepted: tile.finishRename(true)
            onActiveFocusChanged: if (!activeFocus) tile.finishRename(true)
            Keys.onEscapePressed: event => {
                tile.finishRename(false);
                event.accepted = true;
            }
        }
    }

    MouseArea {
        id: area

        property point start: Qt.point(0, 0)
        property bool moving: false

        anchors.fill: parent
        enabled: !tile.renaming
        hoverEnabled: true
        preventStealing: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: tile.carried ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        onContainsMouseChanged: tile.board.point(area.containsMouse ? tile.key : "")
        onPressed: mouse => {
            area.start = Qt.point(mouse.x, mouse.y);
            area.moving = false;
        }
        onPositionChanged: mouse => {
            if (!(area.pressedButtons & Qt.LeftButton))
                return;
            if (!area.moving && Math.hypot(mouse.x - area.start.x, mouse.y - area.start.y) > 6) {
                area.moving = true;
                tile.board.pickUp(tile.index);
            }
            if (area.moving) {
                const p = area.mapToItem(tile.board, mouse.x, mouse.y);
                tile.board.carryTo(p.x - area.start.x, p.y - area.start.y);
            }
        }
        onReleased: mouse => {
            if (area.moving) {
                area.moving = false;
                tile.board.drop();
                return;
            }
            if (!area.containsMouse)
                return;
            if (mouse.button === Qt.RightButton)
                tile.startRename();
            else
                tile.ipc.run(tile.cmd);
        }
        onCanceled: {
            if (area.moving)
                tile.board.cancel();
            area.moving = false;
        }
    }

    // Unpins it.
    MouseArea {
        id: unpinArea
        visible: tile.hovered && !tile.carried && !tile.renaming && tile.board.dragFrom < 0
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 3
        width: 18
        height: 18
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Qt.callLater(tile.ipc.unpin, tile.index)

        Rectangle {
            anchors.fill: parent
            radius: ControlStyle.radius(9)
            color: unpinArea.containsMouse ? Colors.withAlpha(ControlStyle.danger, 0.18) : "transparent"
        }

        Glyph {
            anchors.centerIn: parent
            text: "close"
            font.pixelSize: 13
            color: unpinArea.containsMouse ? ControlStyle.danger : Colors.withAlpha(ControlStyle.ink, 0.55)
        }
    }
}
