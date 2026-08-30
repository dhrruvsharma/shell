import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.services as Services
import qs.colors
import qs.components

Item {
    id: root

    property date currentDate: new Date()   // month being shown
    property date selectedDate: new Date()   // day whose notes are shown
    property bool notesOpen: false
    property bool newNoteRecurring: false    // "repeat yearly" toggle for the next note

    readonly property int dispY: currentDate.getFullYear()
    readonly property int dispM: currentDate.getMonth()
    readonly property string selectedKey: Services.CalendarNotes.dateKey(selectedDate)

    implicitWidth: 360
    implicitHeight: notesOpen ? (notesPanel.y + notesPanel.height) : calCard.height

    Behavior on implicitHeight {
        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
    }

    function daysInMonth(y, m) { return new Date(y, m + 1, 0).getDate() }
    function firstDayOffset(y, m) { return (new Date(y, m, 1).getDay() + 6) % 7 }

    function isToday(y, m, d) {
        const t = new Date()
        return t.getFullYear() === y && t.getMonth() === m && t.getDate() === d
    }
    function isSelected(y, m, d) {
        return selectedDate.getFullYear() === y &&
               selectedDate.getMonth() === m &&
               selectedDate.getDate() === d
    }

    function monthModel() {
        const y = dispY, m = dispM
        const offset = firstDayOffset(y, m)
        const total = daysInMonth(y, m)
        let arr = []
        for (let i = 0; i < offset; i++) arr.push({ day: 0 })
        for (let d = 1; d <= total; d++) arr.push({ day: d })
        while (arr.length % 7 !== 0) arr.push({ day: 0 })
        return arr
    }

    function resetView() {
        currentDate = new Date()
        selectedDate = new Date()
        notesOpen = false
    }

    function addNoteForSelected(field) {
        if (!field || field.text.trim() === "") return
        Services.CalendarNotes.add(selectedKey, field.text, newNoteRecurring)
        field.text = ""
        newNoteRecurring = false
    }

    // ───────────────────────── Calendar card ─────────────────────────
    Card {
        id: calCard
        width: root.width
        y: 0
        height: col.height + 32
        radius: 26

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.04)
        }

        Column {
            id: col
            x: 16; y: 16
            width: calCard.width - 32
            spacing: 14

            property real spacingCell: 4
            property real cellW: (width - spacingCell * 6) / 7

            // ── Header: month / year with nav ──
            RowLayout {
                width: col.width
                spacing: 6

                ClickableRect {
                    id: prevHoverRect
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 17
                    color: prevHoverRect.hovered ? Colors.surface_container_highest : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    StyledText {
                        anchors.centerIn: parent
                        text: "‹"
                        font.pixelSize: 22
                        color: Colors.on_surface_variant
                    }
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentDate = new Date(root.dispY, root.dispM - 1, 1)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.formatDate(root.currentDate, "MMMM")
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.formatDate(root.currentDate, "yyyy")
                        font.pixelSize: 11
                        color: Colors.on_surface_variant
                        opacity: 0.8
                    }
                }

                ClickableRect {
                    id: nextHoverRect
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 17
                    color: nextHoverRect.hovered ? Colors.surface_container_highest : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    StyledText {
                        anchors.centerIn: parent
                        text: "›"
                        font.pixelSize: 22
                        color: Colors.on_surface_variant
                    }
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentDate = new Date(root.dispY, root.dispM + 1, 1)
                }
            }

            // ── Weekday header (same column geometry as the grid below) ──
            Row {
                spacing: col.spacingCell
                width: col.width
                Repeater {
                    model: ["M", "T", "W", "T", "F", "S", "S"]
                    delegate: Item {
                        width: col.cellW
                        height: 22
                        StyledText {
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: index >= 5 ? Colors.tertiary
                                              : Colors.on_surface_variant
                            opacity: 0.85
                        }
                    }
                }
            }

            // ── Day grid ──
            Grid {
                id: daysGrid
                width: col.width
                columns: 7
                spacing: col.spacingCell

                Repeater {
                    model: root.monthModel()

                    delegate: Item {
                        id: cell
                        width: col.cellW
                        height: 42

                        property bool valid: modelData.day > 0
                        property int col7: index % 7
                        property bool weekend: col7 >= 5
                        property var cellDate: valid ? new Date(root.dispY, root.dispM, modelData.day) : null
                        property string key: valid ? Services.CalendarNotes.dateKey(cellDate) : ""
                        property bool today: valid && root.isToday(root.dispY, root.dispM, modelData.day)
                        property bool selected: valid && root.isSelected(root.dispY, root.dispM, modelData.day)
                        property bool hasNotes: valid && Services.CalendarNotes.countFor(key) > 0

                        Rectangle {
                            id: pill
                            anchors.centerIn: parent
                            width: 38
                            height: 38
                            radius: 19
                            color: cell.today
                                   ? Colors.primary
                                   : (cellMa.containsMouse && cell.valid
                                      ? Colors.surface_container_highest
                                      : "transparent")
                            border.width: cell.selected && !cell.today ? 1.5 : 0
                            border.color: Colors.primary
                            Behavior on color { ColorAnimation { duration: 150 } }

                            StyledText {
                                anchors.centerIn: parent
                                text: cell.valid ? modelData.day : ""
                                font.pixelSize: 13
                                font.weight: (cell.today || cell.selected) ? Font.DemiBold : Font.Normal
                                color: cell.today ? Colors.on_primary
                                      : cell.selected ? Colors.primary
                                      : cell.weekend ? Colors.on_surface_variant
                                      : Colors.on_surface
                            }
                        }

                        // note indicator dot
                        Rectangle {
                            visible: cell.hasNotes
                            width: 5; height: 5; radius: 2.5
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: pill.bottom
                            anchors.topMargin: -4
                            color: cell.today ? Colors.on_primary
                                              : Colors.tertiary
                        }

                        MouseArea {
                            id: cellMa
                            anchors.fill: parent
                            enabled: cell.valid
                            hoverEnabled: true
                            cursorShape: cell.valid ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                root.selectedDate = cell.cellDate
                                root.notesOpen = true
                            }
                        }
                    }
                }
            }
        }
    }

    // ───────────────────────── Notes panel ─────────────────────────
    Item {
        id: notesPanel
        width: root.width
        y: calCard.height + 12
        height: notesBg.height
        opacity: root.notesOpen ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 180 } }

        Card {
            id: notesBg
            width: parent.width
            height: notesCol.implicitHeight + 32
            radius: 26

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.04)
            }

            ColumnLayout {
                id: notesCol
                x: 16; y: 16
                width: parent.width - 32
                spacing: 12

                // ── header: selected date + count + close ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText {
                            text: Qt.formatDate(root.selectedDate, "dddd")
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                        StyledText {
                            text: Qt.formatDate(root.selectedDate, "d MMMM yyyy")
                            font.pixelSize: 11
                            color: Colors.on_surface_variant
                        }
                    }

                    Rectangle {
                        visible: Services.CalendarNotes.countFor(root.selectedKey) > 0
                        Layout.preferredHeight: 22
                        Layout.preferredWidth: Math.max(22, badge.contentWidth + 16)
                        radius: 11
                        color: Colors.primary_container
                        StyledText {
                            id: badge
                            anchors.centerIn: parent
                            text: Services.CalendarNotes.countFor(root.selectedKey)
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: Colors.on_primary_container
                        }
                    }

                    ClickableRect {
                        id: closeRect
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: 14
                        color: closeRect.hovered ? Colors.surface_container_highest : "transparent"
                        StyledText {
                            anchors.centerIn: parent
                            text: "×"
                            font.pixelSize: 18
                            color: Colors.on_surface_variant
                        }
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.notesOpen = false
                    }
                }

                // ── list of notes for the selected day ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(Math.max(listCol.implicitHeight + 12, 44), 156)
                    radius: 16
                    color: Colors.surface_container_low

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 6
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        ColumnLayout {
                            id: listCol
                            width: parent.width
                            spacing: 6

                            property var notesModel: Services.CalendarNotes.notesFor(root.selectedKey)

                            StyledText {
                                visible: listCol.notesModel.length === 0
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                topPadding: 10; bottomPadding: 10
                                text: "No notes yet — add one below"
                                font.pixelSize: 12
                                color: Colors.on_surface_variant
                                opacity: 0.7
                            }

                            Repeater {
                                model: listCol.notesModel
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.max(34, noteTxt.implicitHeight + 16)
                                    radius: 12
                                    color: Colors.surface_container_high

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 6
                                        spacing: 8

                                        StyledText {
                                            id: noteTxt
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            text: modelData.text
                                            wrapMode: Text.Wrap
                                            font.pixelSize: 12
                                        }

                                        // recurrence toggle (filled when this note repeats yearly)
                                        ClickableRect {
                                            id: repBtn
                                            Layout.preferredWidth: 24
                                            Layout.preferredHeight: 24
                                            Layout.alignment: Qt.AlignVCenter
                                            radius: 12
                                            property bool recurring: modelData.repeat === "yearly"
                                            color: recurring ? Colors.primary_container
                                                  : (repBtn.hovered ? Colors.surface_container_highest : "transparent")
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            StyledText {
                                                anchors.centerIn: parent
                                                text: "↻"
                                                font.pixelSize: 14
                                                font.bold: true
                                                color: repBtn.recurring ? Colors.on_primary_container
                                                                        : Colors.on_surface_variant
                                                opacity: repBtn.recurring ? 1 : 0.55
                                            }
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Services.CalendarNotes.toggleRepeat(modelData.id)
                                        }

                                        ClickableRect {
                                            id: delRect
                                            Layout.preferredWidth: 24
                                            Layout.preferredHeight: 24
                                            Layout.alignment: Qt.AlignVCenter
                                            radius: 12
                                            color: delRect.hovered ? Colors.error_container : "transparent"
                                            StyledText {
                                                anchors.centerIn: parent
                                                text: "🗑"
                                                font.pixelSize: 12
                                                color: Colors.on_surface_variant
                                            }
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Services.CalendarNotes.remove(modelData.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── add-note input ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    radius: 16
                    color: Colors.surface_container_high
                    border.width: 1.5
                    border.color: noteInput.activeFocus ? Colors.primary
                                                        : Colors.outline_variant
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 6
                        spacing: 8

                        TextField {
                            id: noteInput
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            placeholderText: "Add a note for this day…"
                            placeholderTextColor: Colors.on_surface_variant
                            color: Colors.on_surface
                            font.pixelSize: 12
                            background: Rectangle { color: "transparent" }
                            onAccepted: root.addNoteForSelected(noteInput)
                        }

                        // "repeat yearly" toggle for the note about to be added
                        ClickableRect {
                            id: repeatToggle
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            Layout.alignment: Qt.AlignVCenter
                            radius: 15
                            color: root.newNoteRecurring ? Colors.primary_container
                                  : (repeatToggle.hovered ? Colors.surface_container_highest : "transparent")
                            border.width: root.newNoteRecurring ? 0 : 1
                            border.color: Colors.outline_variant
                            Behavior on color { ColorAnimation { duration: 150 } }
                            StyledText {
                                anchors.centerIn: parent
                                text: "↻"
                                font.pixelSize: 15
                                font.bold: true
                                color: root.newNoteRecurring ? Colors.on_primary_container
                                                             : Colors.on_surface_variant
                                opacity: root.newNoteRecurring ? 1 : 0.6
                            }
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.newNoteRecurring = !root.newNoteRecurring
                        }

                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            Layout.alignment: Qt.AlignVCenter
                            radius: 15
                            color: noteInput.text.trim().length > 0
                                   ? Colors.primary
                                   : Colors.surface_container_highest
                            Behavior on color { ColorAnimation { duration: 150 } }
                            StyledText {
                                anchors.centerIn: parent
                                text: "↑"
                                font.pixelSize: 16
                                font.weight: Font.Bold
                                color: noteInput.text.trim().length > 0
                                       ? Colors.on_primary
                                       : Colors.on_surface_variant
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.addNoteForSelected(noteInput)
                            }
                        }
                    }
                }
            }
        }
    }
}
