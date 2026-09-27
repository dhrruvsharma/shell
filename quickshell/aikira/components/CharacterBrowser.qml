import QtQuick
import qs.services as Services
import qs.aikira
import QtQuick.Layouts
import qs.colors
import qs.components

Item {
    id: root

    Rectangle { anchors.fill: parent; color: Colors.background }

    Rectangle {
        id: cbHead
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 56
        color: Colors.surface_container

        RowLayout {
            anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
            spacing: 12

            ColumnLayout {
                spacing: 2
                StyledText {
                    text: "Characters"
                    font { pixelSize: 15; weight: Font.Medium; letterSpacing: 0.3 }
                }
                StyledText {
                    text: "Click a card to start chatting"
                    font.pixelSize: 10
                    color: Colors.on_surface_variant; opacity: 0.45
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: 140; height: 32; radius: 16
                color: newCharHov.containsMouse
                    ? Colors.primary : Colors.primary_container
                Behavior on color { ColorAnimation { duration: 140 } }

                RowLayout {
                    anchors.centerIn: parent; spacing: 5
                    StyledText {
                        text: "＋"
                        font.pixelSize: 13
                        color: newCharHov.containsMouse
                            ? Colors.on_primary
                            : Colors.on_primary_container
                    }
                    StyledText {
                        text: "new character"
                        font { pixelSize: 12; weight: Font.Medium }
                        color: newCharHov.containsMouse
                            ? Colors.on_primary
                            : Colors.on_primary_container
                    }
                }

                MouseArea {
                    id: newCharHov; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { AppState.editingCharacter = null; AppState.view = "character_editor" }
                }
            }
        }
    }

    Item {
        anchors { top: cbHead.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        visible: !AppState.characters || AppState.characters.length === 0

        ColumnLayout {
            anchors.centerIn: parent; spacing: 10
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "✦"; font.pixelSize: 48
                color: Colors.primary; opacity: 0.15
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "no characters yet"
                font { pixelSize: 14; letterSpacing: 0.3 }
                color: Colors.on_surface_variant; opacity: 0.45
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "create a character to start chatting"
                font.pixelSize: 11
                color: Colors.on_surface_variant; opacity: 0.3
            }
        }
    }

    // ── Character grid ─────────────────────────────────────────────────────
    GridView {
        id: charGrid
        anchors { top: cbHead.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; margins: 16 }
        cellWidth: 300; cellHeight: 170
        clip: true
        visible: AppState.characters && AppState.characters.length > 0
        model: AppState.characters

        delegate: Item {
            width: 292; height: 162

            property bool isSelected: AppState.activeCharacter && AppState.activeCharacter.id === modelData.id
            property int  chatCount:  -1   // -1 = loading

            HoverHandler { id: cardHover }

            Component.onCompleted: {
                Api.loadConversations(modelData.id, function(err, data) {
                    chatCount = (err || !data) ? 0 : data.length
                })
            }

            Rectangle {
                anchors { fill: parent; margins: 4 }
                radius: Services.DesktopTheme.rad(14)
                clip: true
                color: isSelected
                    ? Colors.secondary_container
                    : (cardHover.hovered ? Colors.surface_container_high : Colors.surface_container)
                Behavior on color { ColorAnimation { duration: 130 } }

                ColumnLayout {
                    anchors { fill: parent; margins: 14 }
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            width: 42; height: 42; radius: 21
                            color: isSelected
                                ? Colors.primary
                                : Colors.primary_container

                            StyledText {
                                anchors.centerIn: parent
                                text: modelData.name.charAt(0).toUpperCase()
                                font { pixelSize: 18; weight: Font.Medium }
                                color: isSelected
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
                                font { pixelSize: 14; weight: Font.Medium }
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.personality
                                    ? modelData.personality.split(".")[0]
                                    : (modelData.description ? modelData.description : "")
                                font.pixelSize: 11
                                color: Colors.on_surface_variant; opacity: 0.6
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                wrapMode: Text.NoWrap
                                visible: text.length > 0
                            }
                        }

                        Row {
                            spacing: 4
                            visible: cardHover.hovered

                            ClickableRect {
                                id: editRect
                                width: 28; height: 28; radius: 8
                                color: editRect.hovered
                                    ? Colors.surface_container_highest : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                                StyledText {
                                    anchors.centerIn: parent; text: "✎"; font.pixelSize: 13
                                    color: Colors.on_surface_variant
                                }
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                        mouse.accepted = true
                                        AppState.editingCharacter = modelData
                                        AppState.view = "character_editor"
                                    }
                            }

                            ClickableRect {
                                id: delRect
                                width: 28; height: 28; radius: 8
                                color: delRect.hovered
                                    ? Colors.error_container : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                                StyledText {
                                    anchors.centerIn: parent; text: "×"; font.pixelSize: 16
                                    color: delRect.hovered
                                        ? Colors.on_error_container
                                        : Colors.error
                                }
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                        mouse.accepted = true
                                        deleteConfirm.targetId   = modelData.id
                                        deleteConfirm.targetName = modelData.name
                                        deleteConfirm.visible    = true
                                    }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            height: 22; radius: 11
                            width: chatBadgeRow.implicitWidth + 16
                            color: Colors.surface_container_highest

                            Row {
                                id: chatBadgeRow
                                anchors.centerIn: parent; spacing: 4
                                Text {
                                    text: "💬"; font.pixelSize: 10
                                    visible: chatCount >= 0
                                }
                                StyledText {
                                    text: chatCount < 0 ? "…" : (chatCount + " chat" + (chatCount !== 1 ? "s" : ""))
                                    font { pixelSize: 11; weight: Font.Medium }
                                    color: Colors.on_surface_variant; opacity: 0.7
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        ClickableRect {
                            id: startRect
                            height: 30; radius: 15
                            width: startTxt.implicitWidth + 24
                            color: startRect.hovered
                                ? Colors.primary
                                : Colors.primary_container
                            Behavior on color { ColorAnimation { duration: 120 } }

                            StyledText {
                                id: startTxt; anchors.centerIn: parent
                                text: "start chat"
                                font { pixelSize: 12; weight: Font.Medium }
                                color: startRect.hovered
                                    ? Colors.on_primary
                                    : Colors.on_primary_container
                            }

                            cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                    mouse.accepted = true
                                    AppState.selectCharacter(modelData)
                                }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent; z: -1
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AppState.selectCharacter(modelData)
                }
            }
        }
    }

    Rectangle {
        id: deleteConfirm; visible: false
        property string targetId:   ""
        property string targetName: ""
        anchors.fill: parent; color: "#99000000"; z: 10

        Rectangle {
            anchors.centerIn: parent; width: 340; height: 164; radius: 16
            color: Colors.surface_container_highest
            Column {
                anchors { fill: parent; margins: 24 }
                spacing: 12
                StyledText {
                    text: "Delete "+ deleteConfirm.targetName + "?"
                    font { pixelSize: 15; weight: Font.Medium }
                }
                Text {
                    text: "All conversations with this character will be permanently deleted."
                    font.pixelSize: 12; color: Colors.on_surface_variant; opacity: 0.7
                    wrapMode: Text.WordWrap; width: parent.width
                }
                Item { height: 4 }
                Row {
                    spacing: 10; anchors.right: parent.right
                    ClickableRect {
                        id: dcCxRect
                        width: 72; height: 32; radius: 16
                        color: dcCxRect.hovered
                            ? Colors.surface_container_high : "transparent"
                        Text { anchors.centerIn: parent; text: "cancel"; font.pixelSize: 13
                            color: Colors.on_surface_variant }
                        cursorShape: Qt.PointingHandCursor
                        onClicked: deleteConfirm.visible = false
                    }
                    Rectangle {
                        width: 80; height: 32; radius: 16
                        color: Colors.error_container
                        Text { anchors.centerIn: parent; text: "delete"
                            font { pixelSize: 13; weight: Font.Medium }
                            color: Colors.on_error_container }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const id = deleteConfirm.targetId
                                Api.deleteCharacter(id, function(err) {
                                    if (err) return
                                    AppState.refreshCharacters()
                                    if (AppState.activeCharacter && AppState.activeCharacter.id === id) {
                                        AppState.activeCharacter = null
                                        AppState.messages = []
                                        AppState.conversations = []
                                    }
                                    deleteConfirm.visible = false
                                })
                            }
                        }
                    }
                }
            }
        }
    }
}
