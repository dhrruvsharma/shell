import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services as Services
import qs.colors
import qs.components

// A blank-slate notepad board. Hit + to drop a new tile and type straight into
// it — the tiles are the editors, there are no separate input fields.
Item {
    id: root
    anchors.fill: parent
    visible: false

    readonly property color accent: Colors.primary

    // id of a just-added tile that should grab focus once its delegate exists
    property real pendingFocusId: 0

    // live search query; filters which tiles are shown
    property string searchText: ""

    // ── Open / close ──────────────────────────────────────────────────────────

    function open() {
        visible = true
        Services.Notepad.pruneEmpty()
        refreshLayout()
        searchField.text = ""
        if (layoutNotes.length > 0)
            searchField.forceActiveFocus()
        openAnim.restart()
    }

    function close() {
        focusSink.forceActiveFocus()   // blur the active tile so its text commits
        Services.Notepad.pruneEmpty()
        closeAnim.restart()
    }

    function toggle() {
        if (visible)
            close()
        else
            open()
    }

    // The board renders from this snapshot; it only refreshes on structural
    // changes (add / delete) so live text edits never rebuild the tiles.
    property var layoutNotes: []
    function refreshLayout() {
        layoutNotes = Services.Notepad.notes.slice()
    }

    function addNote() {
        focusSink.forceActiveFocus()      // commit whatever is being edited
        Services.Notepad.pruneEmpty()     // don't pile up blank tiles
        searchField.text = ""             // clear any filter so the new tile shows
        pendingFocusId = Services.Notepad.add("")
        refreshLayout()
        flick.contentY = 0
    }

    function removeNote(id) {
        focusSink.forceActiveFocus()
        Services.Notepad.remove(id)
        refreshLayout()
    }

    // Persist a tile's text when it loses focus. Empty tiles are kept for the
    // session (placeholder stickies) and pruned on the next open / add / close.
    function commitTile(id, text) {
        if (Services.Notepad.indexOfId(id) < 0)
            return
        var idx = Services.Notepad.indexOfId(id)
        if (Services.Notepad.notes[idx].text === text)
            return
        Services.Notepad.setText(id, text)
    }

    function relTime(ts) {
        var diff = Date.now() - ts
        var m = Math.floor(diff / 60000)
        if (m < 1) return "just now"
        if (m < 60) return m + "m ago"
        var h = Math.floor(m / 60)
        if (h < 24) return h + "h ago"
        var d = Math.floor(h / 24)
        if (d < 7) return d + "d ago"
        return Qt.formatDate(new Date(ts), "d MMM")
    }

    // ── Masonry column packing (balanced by estimated height) ──────────────────

    // notes matching the current search, in board order
    readonly property var filteredNotes: {
        var q = searchText.trim().toLowerCase()
        if (q === "")
            return layoutNotes
        return layoutNotes.filter(function (n) {
            return (n.text || "").toLowerCase().indexOf(q) !== -1
        })
    }

    readonly property int columns: Math.max(1, Math.min(4, Math.floor(flick.width / 240)))

    readonly property var columnBuckets: {
        var cols = []
        var heights = []
        for (var c = 0; c < columns; c++) {
            cols.push([])
            heights.push(0)
        }
        var list = root.filteredNotes
        for (var i = 0; i < list.length; i++) {
            var n = list[i]
            var t = n.text || ""
            var lines = Math.max((t.match(/\n/g) || []).length + 1, Math.ceil(t.length / 24))
            var est = 46 + lines * 18

            var mi = 0
            for (var k = 1; k < columns; k++) {
                if (heights[k] < heights[mi])
                    mi = k
            }
            cols[mi].push(n)
            heights[mi] += est + 14
        }
        return cols
    }

    // ── Scrim ─────────────────────────────────────────────────────────────────

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Colors.scrim
        opacity: 0
        enabled: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        MouseArea {
            anchors.fill: parent
            enabled: parent.enabled
            onClicked: root.close()
        }
    }

    // ── Panel ─────────────────────────────────────────────────────────────────

    Rectangle {
        id: panel

        PanelDecor {
            radius: panel.radius
            title: "notepad"
        }
        anchors.centerIn: parent
        width: Math.max(560, Math.min(1040, parent.width * 0.72))
        height: Math.min(760, parent.height * 0.82)
        radius: Services.DesktopTheme.rad(30)
        color: Colors.surface_container_lowest
        clip: true
        enabled: scrim.opacity > 0.01

        opacity: 0
        scale: 0.94
        transformOrigin: Item.Center

        // catches focus when closing so the active tile commits
        Item { id: focusSink; width: 0; height: 0 }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.06) }
                GradientStop { position: 0.45; color: "transparent" }
            }
        }

        Card {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            opacity: 0.5
        }

        ParallelAnimation {
            id: openAnim
            NumberAnimation { target: scrim; property: "opacity"; to: 0.5; duration: 240; easing.type: Easing.OutCubic }
            NumberAnimation { target: panel; property: "opacity"; to: 1; duration: 240; easing.type: Easing.OutCubic }
            NumberAnimation { target: panel; property: "scale"; to: 1; duration: 320; easing.type: Easing.OutBack }
        }

        ParallelAnimation {
            id: closeAnim
            NumberAnimation { target: scrim; property: "opacity"; to: 0; duration: 200; easing.type: Easing.InCubic }
            NumberAnimation { target: panel; property: "opacity"; to: 0; duration: 200; easing.type: Easing.InCubic }
            NumberAnimation { target: panel; property: "scale"; to: 0.94; duration: 200; easing.type: Easing.InCubic }
            onFinished: root.visible = false
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            // ── Header ─────────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "📝"
                    font.pixelSize: 20
                    Layout.alignment: Qt.AlignVCenter
                }

                StyledText {
                    text: "Notepad"
                    font.pixelSize: 19
                    font.weight: Font.Bold
                    Layout.alignment: Qt.AlignVCenter
                }

                Rectangle {
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: Math.max(24, cntText.contentWidth + 16)
                    Layout.alignment: Qt.AlignVCenter
                    radius: Services.DesktopTheme.rad(12)
                    color: Colors.primary_container
                    opacity: root.filteredNotes.length > 0 ? 1 : 0.4
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    StyledText {
                        id: cntText
                        anchors.centerIn: parent
                        text: root.filteredNotes.length
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: Colors.on_primary_container
                    }
                }

                Item { Layout.fillWidth: true }

                // new note
                ClickableRect {
                    id: addRect
                    Layout.preferredHeight: 34
                    Layout.preferredWidth: 106
                    Layout.alignment: Qt.AlignVCenter
                    radius: Services.DesktopTheme.rad(17)
                    color: addRect.hovered
                        ? Qt.darker(Colors.primary_container, 1.15)
                        : Colors.primary_container
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        border.width: 1.5
                        border.color: Colors.primary
                        opacity: 0.35
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        StyledText {
                            text: "+"
                            font.pixelSize: 18
                            font.weight: Font.Bold
                            color: Colors.on_primary_container
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: "New"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: Colors.on_primary_container
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.addNote()
                }

                // close
                ClickableRect {
                    id: closeRect
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    Layout.alignment: Qt.AlignVCenter
                    radius: Services.DesktopTheme.rad(16)
                    color: closeRect.hovered ? Colors.surface_container_high : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    StyledText {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 15
                        color: Colors.on_surface_variant
                    }
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }

            // ── Search ─────────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                visible: root.layoutNotes.length > 0
                radius: Services.DesktopTheme.rad(14)
                color: Colors.surface_container
                border.width: 1
                border.color: searchField.activeFocus
                    ? Colors.primary
                    : Colors.outline_variant
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: "🔍"
                        font.pixelSize: 13
                        opacity: searchField.activeFocus ? 1 : 0.55
                        Layout.alignment: Qt.AlignVCenter
                    }

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        placeholderText: "Search notes…"
                        placeholderTextColor: Colors.on_surface_variant
                        color: Colors.on_surface
                        font.pixelSize: 13
                        padding: 0
                        background: Item {}
                        // re-snapshot on focus so filtering sees the latest committed
                        // text of any tile that was just being edited
                        onActiveFocusChanged: if (activeFocus) root.refreshLayout()
                        onTextChanged: root.searchText = text
                        Keys.onEscapePressed: {
                            if (text.length > 0)
                                text = ""
                            else
                                root.close()
                        }
                    }

                    // clear query
                    ClickableRect {
                        id: clearRect
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        Layout.alignment: Qt.AlignVCenter
                        radius: Services.DesktopTheme.rad(11)
                        visible: searchField.text.length > 0
                        color: clearRect.hovered ? Colors.surface_container_highest : "transparent"
                        StyledText {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: 11
                            color: Colors.on_surface_variant
                        }
                        cursorShape: Qt.PointingHandCursor
                        onClicked: searchField.text = ""
                    }
                }
            }

            // ── Board ──────────────────────────────────────────────────────────
            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Services.DesktopTheme.rad(20)

                Flickable {
                    id: flick
                    anchors.fill: parent
                    anchors.margins: 14
                    clip: true
                    contentWidth: width
                    contentHeight: masonryRow.implicitHeight + 4
                    boundsBehavior: Flickable.StopAtBounds
                    visible: root.filteredNotes.length > 0

                    ScrollBar.vertical: StyledScrollBar {
                        width: 8
                        background: Item {}
                        thickness: 6
                        handleColor: Colors.outline_variant
                        handleOpacity: 0.5
                        handleRadius: 3
                    }

                    RowLayout {
                        id: masonryRow
                        width: flick.width
                        spacing: 14
                        Layout.alignment: Qt.AlignTop

                        Repeater {
                            model: root.columnBuckets

                            delegate: ColumnLayout {
                                id: colLayout
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.alignment: Qt.AlignTop
                                spacing: 14

                                property var colNotes: modelData

                                Repeater {
                                    model: colLayout.colNotes

                                    delegate: Rectangle {
                                        id: tile
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: tileCol.implicitHeight + 26
                                        radius: Services.DesktopTheme.rad(14)
                                        color: Colors.surface_container_high

                                        property var note: modelData

                                        HoverHandler { id: hh }

                                        // focus / hover ring
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: parent.radius
                                            color: "transparent"
                                            border.width: bodyArea.activeFocus ? 1.5 : 1
                                            border.color: bodyArea.activeFocus
                                                ? Colors.primary
                                                : hh.hovered
                                                    ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.4)
                                                    : Qt.rgba(255, 255, 255, 0.05)
                                            Behavior on border.color { ColorAnimation { duration: 150 } }
                                        }

                                        ColumnLayout {
                                            id: tileCol
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.leftMargin: 14
                                            anchors.rightMargin: 14
                                            anchors.topMargin: 12
                                            spacing: 4

                                            TextArea {
                                                id: bodyArea
                                                Layout.fillWidth: true
                                                padding: 0
                                                placeholderText: "Write something…"
                                                placeholderTextColor: Colors.on_surface_variant
                                                color: Colors.on_surface
                                                font.pixelSize: 14
                                                wrapMode: TextArea.Wrap
                                                selectByMouse: true
                                                background: Item {}

                                                Component.onCompleted: {
                                                    text = tile.note.text
                                                    if (tile.note.id === root.pendingFocusId) {
                                                        forceActiveFocus()
                                                        root.pendingFocusId = 0
                                                    }
                                                }

                                                onActiveFocusChanged: {
                                                    if (!activeFocus)
                                                        root.commitTile(tile.note.id, text)
                                                }

                                                Keys.onEscapePressed: root.close()
                                            }

                                            StyledText {
                                                text: root.relTime(tile.note.time)
                                                Layout.topMargin: 2
                                                color: Colors.on_surface_variant
                                                opacity: (hh.hovered || bodyArea.activeFocus) ? 0.5 : 0
                                                font.pixelSize: 10
                                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                            }
                                        }

                                        // delete (hover / focus)
                                        ClickableRect {
                                            id: delRect
                                            anchors.top: parent.top
                                            anchors.right: parent.right
                                            anchors.topMargin: 8
                                            anchors.rightMargin: 8
                                            width: 26
                                            height: 26
                                            radius: Services.DesktopTheme.rad(13)
                                            opacity: (hh.hovered || bodyArea.activeFocus) ? 1 : 0
                                            color: delRect.hovered
                                                ? Colors.error_container
                                                : Colors.surface_container_highest
                                            Behavior on opacity { NumberAnimation { duration: 150 } }
                                            StyledText {
                                                anchors.centerIn: parent
                                                text: "🗑"
                                                font.pixelSize: 12
                                                color: delRect.hovered
                                                    ? Colors.on_error_container
                                                    : Colors.on_surface_variant
                                            }
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.removeNote(tile.note.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Blank slate ────────────────────────────────────────────────
                MouseArea {
                    id: blankMa
                    anchors.fill: parent
                    anchors.margins: 24
                    visible: root.layoutNotes.length === 0
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.addNote()

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 14

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 76
                            Layout.preferredHeight: 76
                            radius: Services.DesktopTheme.rad(38)
                            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, blankMa.containsMouse ? 0.22 : 0.12)
                            border.width: 2
                            border.color: Colors.primary
                            Behavior on color { ColorAnimation { duration: 160 } }
                            StyledText {
                                anchors.centerIn: parent
                                text: "+"
                                font.pixelSize: 40
                                font.weight: Font.Light
                                color: Colors.primary
                            }
                        }
                        StyledText {
                            text: "Blank slate"
                            Layout.alignment: Qt.AlignHCenter
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            opacity: 0.9
                        }
                        StyledText {
                            text: "Click anywhere to drop a note and start typing"
                            Layout.alignment: Qt.AlignHCenter
                            color: Colors.on_surface_variant
                            font.pixelSize: 12
                            opacity: 0.6
                        }
                    }
                }

                // ── No search matches ──────────────────────────────────────────
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: root.layoutNotes.length > 0 && root.filteredNotes.length === 0
                    Text {
                        text: "🔍"
                        font.pixelSize: 34
                        opacity: 0.4
                        Layout.alignment: Qt.AlignHCenter
                    }
                    StyledText {
                        text: "No matching notes"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        opacity: 0.85
                        Layout.alignment: Qt.AlignHCenter
                    }
                    StyledText {
                        text: "Nothing matches “" + root.searchText + "”"
                        color: Colors.on_surface_variant
                        font.pixelSize: 12
                        opacity: 0.6
                        Layout.alignment: Qt.AlignHCenter
                        elide: Text.ElideRight
                        Layout.maximumWidth: 260
                    }
                }
            }
        }
    }
}
