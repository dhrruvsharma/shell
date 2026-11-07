pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.services as Services
import qs.modules.lock
import qs.modules.control

// Notes: the notepad's (services/Notepad, the same notes SUPER+N pins on
// its board). A list of them, newest first; a click opens one to write
// in, right here, and "+" starts a new one. What's typed is kept as it's
// typed; a note left empty goes when it's put away.
PaneSection {
    id: pane

    title: EdgeWords.word("notes")
    preferredWidth: 300

    // The note being written in (its id), or null for the list.
    property var editing: null
    readonly property var notes: Services.Notepad.notes

    function edit(id) {
        const i = Services.Notepad.indexOfId(id);
        if (i < 0)
            return;
        pane.editing = id;
        editor.text = pane.notes[i].text;
        editor.cursorPosition = editor.length;
        editor.forceActiveFocus();
    }

    function startNew() {
        Services.Notepad.pruneEmpty();
        pane.edit(Services.Notepad.add(""));
    }

    function putAway() {
        pane.editing = null;
        editor.focus = false;
        Services.Notepad.pruneEmpty();
    }

    function ago(t) {
        const s = Math.max(0, (Date.now() - t) / 1000);
        if (s < 60)
            return "now";
        if (s < 3600)
            return Math.floor(s / 60) + "m";
        if (s < 86400)
            return Math.floor(s / 3600) + "h";
        if (s < 86400 * 7)
            return Math.floor(s / 86400) + "d";
        return Qt.formatDate(new Date(t), "d MMM");
    }

    Component.onDestruction: Services.Notepad.pruneEmpty()

    trailing: [
        PaneChip {
            icon: "add"
            onClicked: pane.startNew()
        },
        PaneChip {
            icon: "open_in_full"
            onClicked: Services.EdgeLine.request("notepad")
        }
    ]

    // Writing in one.
    Item {
        visible: pane.editing !== null
        width: parent.width
        height: 196

        Rectangle {
            anchors.fill: parent
            radius: ControlStyle.radius(12)
            color: ControlStyle.well
            border.width: 1
            border.color: editor.activeFocus ? Colors.withAlpha(ControlStyle.accent, 0.7) : ControlStyle.line
        }

        Flickable {
            id: scroller
            anchors.fill: parent
            anchors.margins: 10
            anchors.bottomMargin: 36
            contentWidth: width
            contentHeight: editor.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            function follow(r) {
                if (r.y < scroller.contentY)
                    scroller.contentY = r.y;
                else if (r.y + r.height > scroller.contentY + scroller.height)
                    scroller.contentY = r.y + r.height - scroller.height;
            }

            TextEdit {
                id: editor
                width: scroller.width
                wrapMode: TextEdit.Wrap
                font.family: ControlStyle.body
                font.pixelSize: 13
                color: ControlStyle.ink
                selectionColor: Colors.withAlpha(ControlStyle.accent, 0.4)
                onCursorRectangleChanged: scroller.follow(cursorRectangle)
                onTextChanged: {
                    if (pane.editing !== null && editor.activeFocus)
                        Services.Notepad.setText(pane.editing, editor.text);
                }
                Keys.onEscapePressed: event => {
                    pane.putAway();
                    event.accepted = true;
                }

                Text {
                    visible: editor.text.length === 0
                    text: "Write something…"
                    font: editor.font
                    color: Colors.withAlpha(ControlStyle.ink, 0.4)
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 6
            spacing: 4

            PaneChip {
                icon: "delete"
                onClicked: {
                    const id = pane.editing;
                    pane.putAway();
                    if (id !== null)
                        Services.Notepad.remove(id);
                }
            }

            PaneChip {
                text: "Done"
                onClicked: pane.putAway()
            }
        }
    }

    // The list.
    Column {
        visible: pane.editing === null
        width: parent.width
        spacing: 4

        Repeater {
            model: pane.editing === null ? pane.notes.filter(n => (n.text || "").trim() !== "").slice(0, 6) : []

            PaneRow {
                id: note
                required property var modelData
                readonly property var lines: (note.modelData.text || "").trim().split("\n")
                width: parent.width
                icon: "sticky_note_2"
                title: note.lines[0]
                subtitle: note.lines.slice(1).join(" ").trim()
                figure: pane.ago(note.modelData.time)
                action: "delete"
                actionName: "Delete"
                onClicked: pane.edit(note.modelData.id)
                onActionClicked: Services.Notepad.remove(note.modelData.id)
            }
        }

        MouseArea {
            visible: pane.notes.filter(n => (n.text || "").trim() !== "").length === 0
            width: parent.width
            height: 64
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pane.startNew()

            Rectangle {
                anchors.fill: parent
                radius: ControlStyle.radius(12)
                color: parent.containsMouse ? ControlStyle.wellHover : "transparent"
                border.width: 1
                border.color: ControlStyle.line
            }

            Column {
                anchors.centerIn: parent
                spacing: 2

                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "edit_note"
                    font.pixelSize: 20
                    color: ControlStyle.accent
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Nothing written yet: start a note"
                    font.family: ControlStyle.body
                    font.pixelSize: 12
                    color: Colors.withAlpha(ControlStyle.ink, 0.6)
                }
            }
        }

        Text {
            readonly property int more: pane.notes.filter(n => (n.text || "").trim() !== "").length - 6
            visible: more > 0
            width: parent.width
            horizontalAlignment: Text.AlignRight
            text: "and " + more + " more on the board"
            font.family: ControlStyle.body
            font.pixelSize: 11
            color: Colors.withAlpha(ControlStyle.ink, 0.55)
        }
    }
}
