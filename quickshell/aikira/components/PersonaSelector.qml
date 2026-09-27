import QtQuick
import qs.services as Services
import qs.aikira
import QtQuick.Layouts
import qs.colors
import qs.components

Item {
    id: root

    property bool showForm: false
    property var  editing:  null

    function openNew()   {
        editing = null
        pnField.text = ""
        pdField.text = ""
        pdDef.on = false
        pErrMsg.visible = false
        showForm = true
    }

    function openEdit(p) {
        editing = p
        pnField.text = p.name
        pdField.text = p.description || ""
        pdDef.on = p.is_default
        pErrMsg.visible = false
        showForm = true
    }

    Rectangle { anchors.fill: parent; color: Colors.background }

    Rectangle {
        id: psHead
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 56
        color: Colors.surface_container

        RowLayout {
            anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
            spacing: 12

            ColumnLayout {
                spacing: 2
                StyledText {
                    text: "Personas"
                    font { pixelSize: 15; weight: Font.Medium; letterSpacing: 0.3 }
                }
                StyledText {
                    text: "Click a card to use as active persona"
                    font.pixelSize: 10
                    color: Colors.on_surface_variant; opacity: 0.45
                }
            }

            Item { Layout.fillWidth: true }

            ClickableRect {
                id: addPRect
                width: 116; height: 32; radius: 16
                color: addPRect.hovered
                    ? Colors.primary : Colors.primary_container
                Behavior on color { ColorAnimation { duration: 140 } }

                RowLayout {
                    anchors.centerIn: parent; spacing: 5
                    StyledText {
                        text: "＋"; font { pixelSize: 13 }
                        color: addPRect.hovered
                            ? Colors.on_primary
                            : Colors.on_primary_container
                    }
                    StyledText {
                        text: "Add persona"
                        font { pixelSize: 12; weight: Font.Medium }
                        color: addPRect.hovered
                            ? Colors.on_primary
                            : Colors.on_primary_container
                    }
                }

                cursorShape: Qt.PointingHandCursor
                onClicked: root.openNew()
            }
        }
    }

    Item {
        anchors {
            top: psHead.bottom; left: parent.left
            right: parent.right; bottom: parent.bottom
            rightMargin: formPanel.width
        }
        visible: !AppState.personas || AppState.personas.length === 0

        ColumnLayout {
            anchors.centerIn: parent; spacing: 10

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "◈"; font.pixelSize: 44
                color: Colors.primary; opacity: 0.15
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "No personas yet"
                font { pixelSize: 14; letterSpacing: 0.3 }
                color: Colors.on_surface_variant; opacity: 0.45
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "Add a persona to tell the AI who you are"
                font.pixelSize: 11
                color: Colors.on_surface_variant; opacity: 0.3
            }
        }
    }

    GridView {
        id: personaGrid
        anchors {
            top: psHead.bottom; left: parent.left
            right: parent.right; bottom: parent.bottom
            margins: 16
            rightMargin: formPanel.width + 16
        }
        cellWidth: 230; cellHeight: 138
        clip: true
        visible: AppState.personas && AppState.personas.length > 0
        model: AppState.personas

        delegate: Item {
            width: 222; height: 130

            property bool isActive: AppState.activePersona && AppState.activePersona.id === modelData.id
            property bool cardHovered: cardHoverHandler.hovered

            HoverHandler { id: cardHoverHandler }

            Rectangle {
                anchors { fill: parent; margins: 4 }
                radius: Services.DesktopTheme.rad(14)
                color: isActive
                    ? Colors.secondary_container
                    : (cardHovered ? Colors.surface_container_high : Colors.surface_container)
                border {
                    width: modelData.is_default ? 1 : 0
                    color: Colors.primary
                }
                Behavior on color { ColorAnimation { duration: 130 } }

                MouseArea {
                    id: cardHov
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        AppState.activePersona = modelData
                        AppState.view = "chat"
                    }
                }

                ColumnLayout {
                    anchors { fill: parent; margins: 14 }
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            width: 36; height: 36; radius: 18
                            color: isActive
                                ? Colors.primary
                                : Colors.primary_container

                            StyledText {
                                anchors.centerIn: parent
                                text: modelData.name.charAt(0).toUpperCase()
                                font { pixelSize: 15; weight: Font.Medium }
                                color: isActive
                                    ? Colors.on_primary
                                    : Colors.on_primary_container
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.name
                                font { pixelSize: 13; weight: Font.Medium }
                                elide: Text.ElideRight
                            }

                            Row {
                                spacing: 6
                                visible: modelData.is_default || isActive

                                Rectangle {
                                    visible: modelData.is_default
                                    width: defBadge.implicitWidth + 8; height: 16; radius: 8
                                    color: Colors.primary; opacity: 0.15
                                    StyledText {
                                        id: defBadge
                                        anchors.centerIn: parent
                                        text: "default"; font.pixelSize: 9
                                        color: Colors.primary
                                    }
                                }

                                Rectangle {
                                    visible: isActive
                                    width: actBadge.implicitWidth + 8; height: 16; radius: 8
                                    color: Colors.secondary; opacity: 0.15
                                    StyledText {
                                        id: actBadge
                                        anchors.centerIn: parent
                                        text: "active"; font.pixelSize: 9
                                        color: Colors.secondary
                                    }
                                }
                            }
                        }

                        Row {
                            spacing: 4
                            visible: cardHovered

                            Rectangle {
                                width: 26; height: 26; radius: 7
                                color: editBtnHov.containsMouse
                                    ? Colors.surface_container_highest : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }

                                StyledText {
                                    anchors.centerIn: parent; text: "✎"; font.pixelSize: 12
                                    color: Colors.on_surface_variant
                                }

                                MouseArea {
                                    id: editBtnHov; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: (mouse) => { mouse.accepted = true; root.openEdit(modelData) }
                                }
                            }

                            ClickableRect {
                                id: delBtnRect
                                width: 26; height: 26; radius: 7
                                color: delBtnRect.hovered
                                    ? Colors.error_container : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }

                                StyledText {
                                    anchors.centerIn: parent; text: "×"; font.pixelSize: 15
                                    color: delBtnRect.hovered
                                        ? Colors.on_error_container
                                        : Colors.error
                                    opacity: delBtnRect.hovered ? 1 : 0.7
                                }

                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                        mouse.accepted = true
                                        Api.deletePersona(modelData.id, function(err) {
                                            if (!err) {
                                                if (AppState.activePersona && AppState.activePersona.id === modelData.id)
                                                    AppState.activePersona = null
                                                AppState.refreshPersonas()
                                            }
                                        })
                                    }
                            }
                        }
                    }

                    Item { height: 8 }

                    // Description
                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.description || ""
                        font.pixelSize: 11
                        color: Colors.on_surface_variant; opacity: 0.65
                        wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                        visible: text.length > 0
                    }
                }
            }
        }
    }

    Rectangle {
        id: formPanel
        visible: showForm
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: showForm ? 340 : 0
        color: Colors.surface_container_low
        border { width: 1; color: Colors.outline_variant }
        clip: true
        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Flickable {
            anchors.fill: parent
            contentHeight: formContent.implicitHeight + 40
            clip: true

            Column {
                id: formContent
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
                spacing: 20

                // Panel header
                RowLayout {
                    width: parent.width

                    ColumnLayout {
                        spacing: 2
                        StyledText {
                            text: editing ? "Edit persona" : "New persona"
                            font { pixelSize: 14; weight: Font.Medium }
                        }
                        StyledText {
                            text: editing ? "Update persona details" : "Create a new persona"
                            font.pixelSize: 10
                            color: Colors.on_surface_variant; opacity: 0.45
                        }
                    }

                    Item { Layout.fillWidth: true }

                    ClickableRect {
                        id: pcRect
                        width: 30; height: 30; radius: 8
                        color: pcRect.hovered
                            ? Colors.surface_container_high : "transparent"
                        Behavior on color { ColorAnimation { duration: 110 } }
                        StyledText {
                            anchors.centerIn: parent; text: "×"; font.pixelSize: 18
                            color: Colors.on_surface_variant
                        }
                        cursorShape: Qt.PointingHandCursor
                        onClicked: showForm = false
                    }
                }

                // Name field
                Column {
                    width: parent.width; spacing: 6

                    StyledText {
                        text: "NAME"
                        font { pixelSize: 10; letterSpacing: 1.5; weight: Font.Bold }
                        color: Colors.on_surface_variant; opacity: 0.6
                    }

                    Rectangle {
                        width: parent.width; height: 38; radius: 9
                        color: Colors.surface_container_highest
                        border {
                            width: pnField.activeFocus ? 1 : 0
                            color: Colors.primary
                        }
                        Behavior on border.width { NumberAnimation { duration: 100 } }

                        TextInput {
                            id: pnField
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: Colors.on_surface
                            font { pixelSize: 13; family: "monospace" }
                            selectByMouse: true

                            StyledText {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "e.g. Traveler"
                                font { pixelSize: 13; family: "monospace" }
                                color: Colors.on_surface_variant; opacity: 0.3
                                visible: pnField.text.length === 0
                            }
                        }
                    }
                }

                // Description field
                Column {
                    width: parent.width; spacing: 6

                    StyledText {
                        text: "DESCRIPTION"
                        font { pixelSize: 10; letterSpacing: 1.5; weight: Font.Bold }
                        color: Colors.on_surface_variant; opacity: 0.6
                    }
                    StyledText {
                        text: "How you want to be described to the AI"
                        font.pixelSize: 10
                        color: Colors.on_surface_variant; opacity: 0.38
                    }

                    Rectangle {
                        width: parent.width
                        height: Math.max(90, pdField.implicitHeight + 24)
                        radius: 9; clip: true
                        color: Colors.surface_container_highest
                        border {
                            width: pdField.activeFocus ? 1 : 0
                            color: Colors.primary
                        }
                        Behavior on border.width { NumberAnimation { duration: 100 } }

                        TextEdit {
                            id: pdField
                            anchors { fill: parent; margins: 12 }
                            color: Colors.on_surface
                            font { pixelSize: 13; family: "monospace" }
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                        }
                    }
                }

                // Default toggle
                RowLayout {
                    width: parent.width; spacing: 12

                    Rectangle {
                        id: pdDef; property bool on: false
                        width: 42; height: 24; radius: 12
                        color: on ? Colors.primary : Colors.surface_container_highest
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            width: 18; height: 18; radius: 9
                            anchors.verticalCenter: parent.verticalCenter
                            x: parent.on ? parent.width - width - 3 : 3
                            color: parent.on ? Colors.on_primary : Colors.on_surface_variant
                            opacity: parent.on ? 1 : 0.5
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: pdDef.on = !pdDef.on
                        }
                    }

                    ColumnLayout {
                        spacing: 1
                        StyledText {
                            text: "default persona"
                            font { pixelSize: 12; weight: Font.Medium }
                        }
                        StyledText {
                            text: "used automatically in new chats"
                            font.pixelSize: 10
                            color: Colors.on_surface_variant; opacity: 0.4
                        }
                    }
                }

                // Error message
                Text {
                    id: pErrMsg; visible: false
                    text: "name is required"
                    font.pixelSize: 11; color: Colors.error
                }

                // Action buttons
                RowLayout {
                    width: parent.width; spacing: 8

                    // Delete button (editing only)
                    ClickableRect {
                        id: pdelRect
                        visible: editing !== null
                        width: 80; height: 36; radius: 18
                        color: pdelRect.hovered
                            ? Colors.error : Colors.error_container
                        Behavior on color { ColorAnimation { duration: 120 } }

                        StyledText {
                            anchors.centerIn: parent; text: "delete"
                            font { pixelSize: 13; weight: Font.Medium }
                            color: pdelRect.hovered
                                ? "white" : Colors.on_error_container
                        }

                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                                Api.deletePersona(editing.id, function(err) {
                                    if (!err) {
                                        if (AppState.activePersona && AppState.activePersona.id === editing.id)
                                            AppState.activePersona = null
                                        AppState.refreshPersonas()
                                        showForm = false
                                    }
                                })
                            }
                    }

                    Item { Layout.fillWidth: true }

                    // Cancel button
                    ClickableRect {
                        id: pcanRect
                        width: 76; height: 36; radius: 18
                        color: pcanRect.hovered
                            ? Colors.surface_container_high
                            : Colors.surface_container_highest
                        Behavior on color { ColorAnimation { duration: 120 } }

                        StyledText {
                            anchors.centerIn: parent; text: "cancel"
                            font { pixelSize: 13; weight: Font.Medium }
                            color: Colors.on_surface_variant
                        }

                        cursorShape: Qt.PointingHandCursor
                        onClicked: showForm = false
                    }

                    // Save button
                    ClickableRect {
                        id: psvRect
                        width: 76; height: 36; radius: 18
                        color: psvRect.hovered
                            ? Colors.primary_fixed_dim : Colors.primary
                        Behavior on color { ColorAnimation { duration: 120 } }

                        StyledText {
                            anchors.centerIn: parent; text: "save"
                            font { pixelSize: 13; weight: Font.Medium }
                            color: Colors.on_primary
                        }

                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                                const name = pnField.text.trim()
                                if (!name) { pErrMsg.visible = true; return }
                                pErrMsg.visible = false
                                const data = { name: name, description: pdField.text, is_default: pdDef.on }
                                if (!editing) {
                                    Api.createPersona(data, function(err) {
                                        if (err) { pErrMsg.visible = true; return }
                                        AppState.refreshPersonas(); showForm = false
                                    })
                                } else {
                                    Api.updatePersona(editing.id, data, function(err) {
                                        if (err) { pErrMsg.visible = true; return }
                                        AppState.refreshPersonas(); showForm = false
                                    })
                                }
                            }
                    }
                }
            }
        }
    }
}
