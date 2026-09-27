import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.colors
import qs.services
import qs.components

Item {
    id: browseView

    // ── Exposed API ──────────────────────────────────────────────────────────
    readonly property string fontDisplay: "Noto Serif"
    readonly property string fontBody:    "Noto Sans"

    // Emitted when the user taps a manga card
    signal mangaSelected(string mangaId)

    property string currentTagId: ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ──────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 60
            color: Colors.surface_container_low
            z: 2

            Divider {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                opacity: 0.5
            }

            RowLayout {
                anchors { fill: parent; leftMargin: 18; rightMargin: 12 }
                spacing: 10

                // Wordmark
                Row {
                    spacing: 0
                    visible: !searchBar.visible
                    Layout.fillWidth: true

                    StyledText {
                        text: "M"
                        font.family: browseView.fontDisplay
                        font.pixelSize: 24
                        font.letterSpacing: 1
                        color: Colors.primary
                    }
                    StyledText {
                        text: "anga"
                        font.family: browseView.fontDisplay
                        font.pixelSize: 24
                        font.letterSpacing: 1
                        opacity: 0.85
                    }
                }

                // Search bar
                Rectangle {
                    id: searchBar
                    Layout.fillWidth: true
                    height: 38
                    radius: DesktopTheme.rad(19)
                    color: Colors.surface_container
                    visible: false
                    border.color: searchField.activeFocus ? Colors.primary : Colors.outline_variant
                    border.width: searchField.activeFocus ? 1.5 : 1
                    Behavior on border.width { NumberAnimation { duration: 120 } }

                    TextInput {
                        id: searchField
                        anchors {
                            verticalCenter: parent.verticalCenter
                            left: parent.left; right: clearBtn.left
                            leftMargin: 16; rightMargin: 6
                        }
                        color: Colors.on_surface
                        font.family: browseView.fontBody
                        font.pixelSize: 13
                        clip: true
                        onTextChanged: searchDebounce.restart()
                        Keys.onEscapePressed: {
                            searchBar.visible = false
                            text = ""
                            Manga.fetchByOrigin(browseView.currentTagId, true)
                        }
                    }

                    StyledText {
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 16 }
                        text: "Search titles…"
                        color: Colors.on_surface_variant
                        font.family: browseView.fontBody
                        font.pixelSize: 13
                        visible: searchField.text.length === 0
                        opacity: 0.6
                    }

                    // Clear button
                    Item {
                        id: clearBtn
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 10 }
                        width: 22; height: 22
                        visible: searchField.text.length > 0
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 100 } }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 18; height: 18; radius: 9
                            color: Colors.surface_container_highest
                        }
                        StyledText {
                            anchors.centerIn: parent
                            text: "✕"
                            color: Colors.on_surface_variant
                            font.pixelSize: 9
                            font.bold: true
                        }
                        MouseArea { anchors.fill: parent; onClicked: searchField.text = "" }
                    }
                }

                Timer {
                    id: searchDebounce
                    interval: 350
                    onTriggered: {
                        if (searchField.text.trim().length > 0)
                            Manga.searchManga(searchField.text.trim(), true)
                        else
                            Manga.fetchByOrigin(browseView.currentTagId, true)
                    }
                }

                // Search toggle button
                Item {
                    width: 40; height: 40

                    Rectangle {
                        anchors.centerIn: parent
                        width: 34; height: 34; radius: 17
                        color: searchBar.visible ? Colors.primary_container : "transparent"
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                    StyledText {
                        anchors.centerIn: parent
                        text: "⌕"
                        font.pixelSize: 19
                        color: searchBar.visible ? Colors.on_primary_container : Colors.on_surface_variant
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            searchBar.visible = !searchBar.visible
                            if (searchBar.visible) {
                                searchField.forceActiveFocus()
                            } else {
                                searchField.text = ""
                                Manga.fetchByOrigin(browseView.currentTagId, true)
                            }
                        }
                    }
                }
            }
        }

        // ── Tag filter chips ─────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 48
            color: Colors.surface_container_low
            clip: true

            Divider {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                opacity: 0.25
            }

            ListView {
                id: tagList
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                orientation: ListView.Horizontal
                spacing: 7
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                model: ListModel {
                    ListElement { label: "Hot";     tagId: ""       }
                    ListElement { label: "Latest";  tagId: "latest" }
                    ListElement { label: "Manga";   tagId: "ja"     }
                    ListElement { label: "Manhwa";  tagId: "ko"     }
                    ListElement { label: "Manhua";  tagId: "zh"     }
                }

                delegate: Item {
                    width: chip.implicitWidth + 28
                    height: tagList.height

                    Rectangle {
                        id: chip
                        anchors.centerIn: parent
                        implicitWidth: chipLabel.implicitWidth + 28
                        height: 30
                        radius: DesktopTheme.rad(15)
                        color: browseView.currentTagId === tagId
                            ? Colors.primary
                            : Colors.surface_container
                        border.color: browseView.currentTagId === tagId
                            ? Colors.primary
                            : Colors.outline_variant
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 180 } }

                        StyledText {
                            id: chipLabel
                            anchors.centerIn: parent
                            text: label
                            font.family: browseView.fontBody
                            font.pixelSize: 12
                            font.letterSpacing: 0.6
                            color: browseView.currentTagId === tagId
                                ? Colors.on_primary
                                : Colors.on_surface_variant
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            browseView.currentTagId = tagId
                            searchField.text = ""
                            searchBar.visible = false
                            Manga.fetchByOrigin(tagId, true)
                        }
                    }
                }
            }

            Divider {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                opacity: 0.3
            }
        }

        // ── Main content area ────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Loading state
            Rectangle {
                anchors.fill: parent
                color: Colors.background
                visible: Manga.isFetchingManga && Manga.mangaList.length === 0
                z: 10

                Column {
                    anchors.centerIn: parent
                    spacing: 16

                    Spinner {
                        width: 36
                        anchors.horizontalCenter: parent.horizontalCenter
                        border.width: 2.5
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "loading"
                        color: Colors.on_surface_variant
                        font.family: browseView.fontBody
                        font.pixelSize: 11
                        font.letterSpacing: 2.5
                        opacity: 0.7
                    }
                }
            }

            // Error state
            Rectangle {
                anchors.fill: parent
                color: Colors.background
                visible: Manga.mangaError.length > 0 && !Manga.isFetchingManga
                z: 9

                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    StyledText {
                        text: "⚠"
                        font.pixelSize: 32
                        color: Colors.error
                        anchors.horizontalCenter: parent.horizontalCenter
                        opacity: 0.8
                    }
                    StyledText {
                        text: Manga.mangaError
                        color: Colors.on_surface_variant
                        font.pixelSize: 12
                        font.family: browseView.fontBody
                        wrapMode: Text.Wrap
                        width: 260
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight: 1.4
                    }
                }
            }

            // ── Manga grid ───────────────────────────────────────────────────
            GridView {
                id: mangaGrid
                anchors.fill: parent
                anchors.margins: 10
                cellWidth: (width - 10) / 4
                cellHeight: cellWidth * 1.58
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: Manga.mangaList

                ScrollBar.vertical: StyledScrollBar {
                }

                onContentYChanged: {
                    if (contentY + height > contentHeight - cellHeight * 2)
                        Manga.fetchNextMangaPage()
                }

                delegate: Item {
                    width: mangaGrid.cellWidth
                    height: mangaGrid.cellHeight

                    ClickableRect {
                        id: card
                        anchors { fill: parent; margins: 5 }
                        radius: DesktopTheme.rad(12)
                        color: Colors.surface_container
                        clip: true

                        // Cover image
                        Image {
                            id: coverImg
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            height: parent.height - titleBar.height
                            source: modelData.thumbUrl || ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 300 } }

                            // Placeholder shimmer
                            Rectangle {
                                anchors.fill: parent
                                color: Colors.surface_container_high
                                visible: coverImg.status !== Image.Ready
                                StyledText {
                                    anchors.centerIn: parent
                                    text: "◫"
                                    font.pixelSize: 32
                                    color: Colors.outline
                                    opacity: 0.25
                                }
                            }

                            // Type badge
                            Rectangle {
                                visible: modelData.type && modelData.type.length > 0
                                anchors { top: parent.top; right: parent.right; topMargin: 8; rightMargin: 8 }
                                height: 20
                                radius: DesktopTheme.rad(10)
                                width: typeText.implicitWidth + 14
                                color: Qt.rgba(0, 0, 0, 0.7)

                                StyledText {
                                    id: typeText
                                    anchors.centerIn: parent
                                    text: (modelData.type || "").toUpperCase()
                                    font.family: browseView.fontBody
                                    font.pixelSize: 8
                                    font.letterSpacing: 1
                                    font.bold: true
                                    color: Colors.primary_fixed_dim
                                }
                            }

                            // Gradient vignette at bottom of cover
                            Rectangle {
                                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                height: 56
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 1.0; color: Colors.surface_container }
                                }
                            }
                        }

                        // Title bar
                        Rectangle {
                            id: titleBar
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: titleText.implicitHeight + 18
                            color: Colors.surface_container
                            radius: DesktopTheme.rad(12)

                            StyledText {
                                id: titleText
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 10; rightMargin: 10
                                }
                                text: modelData.title || ""
                                font.family: browseView.fontBody
                                font.pixelSize: 11
                                font.letterSpacing: 0.2
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                lineHeight: 1.3
                            }
                        }

                        // Hover + press overlay
                        Rectangle {
                            anchors.fill: parent
                            radius: DesktopTheme.rad(12)
                            color: Colors.primary
                            opacity: card.pressed
                                ? 0.16
                                : (card.hovered ? 0.07 : 0)
                            Behavior on opacity { NumberAnimation { duration: 130 } }
                        }

                        // Scale effect on hover
                        transform: Scale {
                            origin.x: card.width / 2
                            origin.y: card.height / 2
                            xScale: card.pressed ? 0.97 : 1.0
                            yScale: card.pressed ? 0.97 : 1.0
                            Behavior on xScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            Behavior on yScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        }

                        onClicked: {
                                Manga.fetchMangaDetail(modelData.id)
                                browseView.mangaSelected(modelData.id)
                            }
                    }
                }
            }
        }
    }
}
