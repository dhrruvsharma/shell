pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.services as Services
import qs.modules.lock
import qs.modules.control

// One of the shell's commands in the commands tile's catalogue
// (CommandsPane): its function, what it takes and what it gives back. A
// click pins it to the tile (and unpins it again); one that takes
// arguments opens for them first (`open`), with a name of yours for its
// tile if you like, and can be pinned once for each set of them.
Item {
    id: entry

    required property var item
    property bool open: false

    signal toggled
    signal pinned

    readonly property var ipc: Services.IpcCommands
    readonly property bool takesArgs: entry.item.params.length > 0
    readonly property int pins: entry.ipc.pinCount(entry.item.target, entry.item.fn)
    property string problem: ""

    implicitHeight: row.height + (entry.open ? form.height + 8 : 0)

    function values() {
        const out = [];
        for (let i = 0; i < fields.count; i++)
            out.push(fields.itemAt(i)?.value ?? "");
        return out;
    }

    function pin() {
        const args = entry.values();
        const why = entry.ipc.check(entry.item, args);
        if (why !== "") {
            entry.problem = why + ".";
            return;
        }
        if (!entry.ipc.pin(entry.item.target, entry.item.fn, args, name.text)) {
            entry.problem = entry.ipc.pinned.length >= entry.ipc.maxPinned ? "The tile is full." : "That one's pinned already.";
            return;
        }
        entry.problem = "";
        name.text = "";
        entry.pinned();
    }

    // Pins or unpins one without arguments; opens one with them.
    function activate() {
        if (entry.takesArgs)
            entry.toggled();
        else if (entry.pins > 0)
            entry.ipc.unpinCommand(entry.item.target, entry.item.fn, []);
        else
            entry.ipc.pin(entry.item.target, entry.item.fn, [], "");
    }

    onOpenChanged: {
        entry.problem = "";
        if (entry.open)
            Qt.callLater(() => fields.itemAt(0)?.focusIn());
    }

    Item {
        id: row
        width: parent.width
        height: entry.item.live ? 32 : 40

        Rectangle {
            anchors.fill: parent
            radius: ControlStyle.radius(9)
            color: area.containsMouse || entry.open ? ControlStyle.wellHover : "transparent"
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: entry.activate()
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 30
            anchors.right: end.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                elide: Text.ElideRight
                textFormat: Text.StyledText
                text: entry.item.fn + (entry.takesArgs ? " <font color=\"" + Colors.withAlpha(ControlStyle.ink, 0.5) + "\">" + entry.item.params.map(p => p.name + ": " + p.type).join(", ") + "</font>" : "")
                font.family: ControlStyle.mono
                font.pixelSize: 12
                color: entry.pins > 0 ? ControlStyle.accent : ControlStyle.ink
            }

            Text {
                visible: !entry.item.live
                width: parent.width
                elide: Text.ElideRight
                text: "not loaded just now"
                font.family: ControlStyle.body
                font.pixelSize: 10
                color: Colors.withAlpha(ControlStyle.ink, 0.5)
            }
        }

        Row {
            id: end
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Text {
                visible: entry.item.returns !== "void"
                anchors.verticalCenter: parent.verticalCenter
                text: "→ " + entry.item.returns
                font.family: ControlStyle.mono
                font.pixelSize: 10
                color: Colors.withAlpha(ControlStyle.ink, 0.5)
            }

            Text {
                visible: entry.takesArgs && entry.pins > 0
                anchors.verticalCenter: parent.verticalCenter
                text: "×" + entry.pins
                font.family: ControlStyle.mono
                font.pixelSize: 10
                color: ControlStyle.accent
            }

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: entry.takesArgs ? (entry.open ? "expand_less" : "expand_more") : "push_pin"
                filled: entry.pins > 0
                font.pixelSize: 16
                color: entry.pins > 0 ? ControlStyle.accent : Colors.withAlpha(ControlStyle.ink, area.containsMouse ? 0.8 : 0.35)
            }
        }
    }

    // What it takes: a field for each argument, a name for the tile, Pin.
    Column {
        id: form
        visible: entry.open
        y: row.height + 4
        x: 30
        width: parent.width - 38
        spacing: 5

        Repeater {
            id: fields
            model: entry.open ? entry.item.params : []

            Rectangle {
                id: field
                required property var modelData
                required property int index
                readonly property string value: arg.text
                function focusIn() {
                    arg.forceActiveFocus();
                }
                width: form.width
                height: 28
                radius: ControlStyle.radius(8)
                color: ControlStyle.well
                border.width: 1
                border.color: arg.activeFocus ? ControlStyle.accent : ControlStyle.line

                TextInput {
                    id: arg
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    font.family: ControlStyle.mono
                    font.pixelSize: 12
                    color: ControlStyle.ink
                    selectionColor: Colors.withAlpha(ControlStyle.accent, 0.4)
                    inputMethodHints: field.modelData.type === "int" || field.modelData.type === "real" ? Qt.ImhFormattedNumbersOnly : Qt.ImhNoAutoUppercase
                    onAccepted: {
                        const next = fields.itemAt(field.index + 1);
                        if (next)
                            next.focusIn();
                        else
                            entry.pin();
                    }

                    Text {
                        visible: arg.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        elide: Text.ElideRight
                        text: field.modelData.name + " · " + (field.modelData.type === "bool" ? "true or false" : field.modelData.type === "int" ? "a whole number" : field.modelData.type === "real" ? "a number" : "text")
                        font: arg.font
                        color: Colors.withAlpha(ControlStyle.ink, 0.4)
                    }
                }
            }
        }

        Rectangle {
            width: form.width
            height: 28
            radius: ControlStyle.radius(8)
            color: ControlStyle.well
            border.width: 1
            border.color: name.activeFocus ? ControlStyle.accent : ControlStyle.line

            TextInput {
                id: name
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                maximumLength: 40
                font.family: ControlStyle.body
                font.pixelSize: 12
                color: ControlStyle.ink
                selectionColor: Colors.withAlpha(ControlStyle.accent, 0.4)
                onAccepted: entry.pin()

                Text {
                    visible: name.text.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    elide: Text.ElideRight
                    text: "Its name on the tile (if you like)"
                    font: name.font
                    color: Colors.withAlpha(ControlStyle.ink, 0.4)
                }
            }
        }

        Item {
            width: form.width
            height: Math.max(26, problemText.implicitHeight)

            Text {
                id: problemText
                visible: entry.problem !== ""
                anchors.left: parent.left
                anchors.right: pinChip.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                wrapMode: Text.Wrap
                text: entry.problem
                font.family: ControlStyle.body
                font.pixelSize: 11
                color: ControlStyle.danger
            }

            PaneChip {
                id: pinChip
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: "push_pin"
                text: "Pin"
                onClicked: entry.pin()
            }
        }
    }
}
