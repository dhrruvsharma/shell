import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.colors
import qs.services
import qs.components

Item {
    id: browseView

    readonly property string fontDisplay: "Noto Serif"
    readonly property string fontBody:    "Noto Sans"

    // Passes the full show object so DetailView can seed itself immediately
    signal animeSelected(var show)

    // ── Background ────────────────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: Colors.background }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ────────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 56
            color: Colors.surface_container_low
            z: 2

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: Colors.outline_variant; opacity: 0.5
            }

            RowLayout {
                anchors { fill: parent; leftMargin: 18; rightMargin: 10 }
                spacing: 8

                // Wordmark (hidden when search is open)
                Row {
                    spacing: 0
                    visible: !searchBar.visible
                    Layout.fillWidth: true

                    StyledText {
                        text: "A"
                        font.family: browseView.fontDisplay
                        font.pixelSize: 24; font.letterSpacing: 1
                        color: Colors.primary
                    }
                    StyledText {
                        text: "nime"
                        font.family: browseView.fontDisplay
                        font.pixelSize: 24; font.letterSpacing: 1
                        color: Colors.on_surface; opacity: 0.85
                    }
                }

                // Search bar
                Rectangle {
                    id: searchBar
                    Layout.fillWidth: true
                    height: 36; radius: 18
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
                            leftMargin: 14; rightMargin: 6
                        }
                        color: Colors.on_surface
                        font.family: browseView.fontBody
                        font.pixelSize: 13
                        clip: true
                        onTextChanged: searchDebounce.restart()
                        Keys.onEscapePressed: {
                            searchBar.visible = false
                            text = ""
                            Anime.fetchPopular(true)
                        }
                    }

                    StyledText {
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 14 }
                        text: "Search anime…"
                        color: Colors.on_surface_variant
                        font.family: browseView.fontBody
                        font.pixelSize: 13
                        visible: searchField.text.length === 0
                        opacity: 0.6
                    }

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
                            font.pixelSize: 9; font.bold: true
                        }
                        MouseArea { anchors.fill: parent; onClicked: searchField.text = "" }
                    }
                }

                Timer {
                    id: searchDebounce
                    interval: 350
                    onTriggered: {
                        if (searchField.text.trim().length > 0)
                            Anime.searchAnime(searchField.text.trim(), true)
                        else
                            Anime.fetchPopular(true)
                    }
                }

                // Search toggle
                Item {
                    width: 38; height: 38

                    Rectangle {
                        anchors.centerIn: parent
                        width: 32; height: 32; radius: 16
                        color: searchBar.visible ? Colors.primary_container : "transparent"
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                    StyledText {
                        anchors.centerIn: parent
                        text: "⌕"; font.pixelSize: 18
                        color: searchBar.visible ? Colors.on_primary_container : Colors.on_surface_variant
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            searchBar.visible = !searchBar.visible
                            if (searchBar.visible) searchField.forceActiveFocus()
                            else {
                                searchField.text = ""
                                Anime.fetchPopular(true)
                            }
                        }
                    }
                }

                // Sub / Dub toggle
                Rectangle {
                    height: 28
                    width: modeRow.implicitWidth + 16
                    radius: DesktopTheme.rad(14)
                    color: Colors.surface_container
                    border.color: Colors.outline_variant; border.width: 1

                    Row {
                        id: modeRow
                        anchors.centerIn: parent
                        spacing: 0

                        Repeater {
                            model: ["sub", "dub"]

                            delegate: Item {
                                width: modeText.implicitWidth + 16
                                height: 28
                                readonly property bool active: Anime.currentMode === modelData

                                Rectangle {
                                    anchors { fill: parent; margins: 3 }
                                    radius: DesktopTheme.rad(11)
                                    color: active ? Colors.primary : "transparent"
                                    Behavior on color { ColorAnimation { duration: 160 } }
                                }
                                StyledText {
                                    id: modeText
                                    anchors.centerIn: parent
                                    text: modelData.toUpperCase()
                                    font.family: browseView.fontBody
                                    font.pixelSize: 10; font.letterSpacing: 1; font.bold: true
                                    color: active ? Colors.on_primary : Colors.on_surface_variant
                                    Behavior on color { ColorAnimation { duration: 160 } }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: Anime.setMode(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Filter chips ──────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 44
            color: Colors.surface_container_low
            clip: true

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1; color: Colors.outline_variant; opacity: 0.25
            }

            ListView {
                id: chipList
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                orientation: ListView.Horizontal
                spacing: 7; clip: true
                boundsBehavior: Flickable.StopAtBounds

                model: ListModel {
                    ListElement { label: "Popular"; view: "popular"; country: "ALL" }
                    ListElement { label: "Latest";  view: "latest";  country: "ALL" }
                    ListElement { label: "Japan";   view: "latest";  country: "JP"  }
                    ListElement { label: "China";   view: "latest";  country: "CN"  }
                    ListElement { label: "Korea";   view: "latest";  country: "KR"  }
                }

                delegate: Item {
                    width: chipRect.implicitWidth + 24
                    height: chipList.height

                    readonly property bool active:
                        Anime.currentView === view && Anime.currentCountry === country

                    Rectangle {
                        id: chipRect
                        anchors.centerIn: parent
                        implicitWidth: chipLbl.implicitWidth + 24
                        height: 28; radius: 14
                        color: active ? Colors.primary : Colors.surface_container
                        border.color: active ? Colors.primary : Colors.outline_variant
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 180 } }

                        StyledText {
                            id: chipLbl
                            anchors.centerIn: parent
                            text: label
                            font.family: browseView.fontBody
                            font.pixelSize: 11; font.letterSpacing: 0.5
                            color: active ? Colors.on_primary : Colors.on_surface_variant
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            searchField.text = ""
                            searchBar.visible = false
                            Anime.currentCountry = country
                            if (view === "popular") Anime.fetchPopular(true)
                            else Anime.fetchLatest(true)
                        }
                    }
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: Colors.outline_variant; opacity: 0.3
            }
        }

        // ── Content area ──────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Loading
            Rectangle {
                anchors.fill: parent; color: Colors.background
                visible: Anime.isFetchingAnime && Anime.animeList.length === 0
                z: 10

                Column {
                    anchors.centerIn: parent; spacing: 14

                    Spinner {
                        width: 34
                        anchors.horizontalCenter: parent.horizontalCenter
                        border.width: 2.5
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "loading"
                        color: Colors.on_surface_variant
                        font.family: browseView.fontBody
                        font.pixelSize: 11; font.letterSpacing: 2.5; opacity: 0.7
                    }
                }
            }

            // Error
            Rectangle {
                anchors.fill: parent; color: Colors.background
                visible: Anime.animeError.length > 0 && !Anime.isFetchingAnime
                z: 9

                Column {
                    anchors.centerIn: parent; spacing: 10

                    Text {
                        text: "⚠"; font.pixelSize: 30; color: Colors.error
                        anchors.horizontalCenter: parent.horizontalCenter; opacity: 0.8
                    }
                    StyledText {
                        text: Anime.animeError
                        color: Colors.on_surface_variant; font.pixelSize: 12
                        font.family: browseView.fontBody
                        wrapMode: Text.Wrap; width: 260
                        horizontalAlignment: Text.AlignHCenter; lineHeight: 1.4
                    }
                }
            }

            // Grid
            GridView {
                id: animeGrid
                anchors.fill: parent; anchors.margins: 10
                cellWidth: (width - 10) / 4
                cellHeight: cellWidth * 1.58
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: Anime.animeList

                ScrollBar.vertical: StyledScrollBar {
                }

                onContentYChanged: {
                    if (contentY + height > contentHeight - cellHeight * 2)
                        Anime.fetchNextPage()
                }

                delegate: Item {
                    width: animeGrid.cellWidth
                    height: animeGrid.cellHeight

                    ClickableRect {
                        id: card
                        anchors { fill: parent; margins: 5 }
                        radius: 12; color: Colors.surface_container; clip: true

                        // Cover
                        Image {
                            id: coverImg
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            height: parent.height - titleBar.height
                            source: modelData.thumbnail || ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true; cache: true
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 300 } }

                            Rectangle {
                                anchors.fill: parent; color: Colors.surface_container_high
                                visible: coverImg.status !== Image.Ready
                                Text {
                                    anchors.centerIn: parent; text: "◫"
                                    font.pixelSize: 32; color: Colors.outline; opacity: 0.25
                                }
                            }

                            // Score badge
                            Rectangle {
                                visible: modelData.score !== null && modelData.score !== undefined
                                anchors { top: parent.top; left: parent.left; topMargin: 8; leftMargin: 8 }
                                height: 20; radius: 10
                                width: scoreText.implicitWidth + 12
                                color: Qt.rgba(0, 0, 0, 0.72)

                                StyledText {
                                    id: scoreText; anchors.centerIn: parent
                                    text: modelData.score !== null
                                        ? "★ " + (modelData.score || 0).toFixed(1) : ""
                                    font.family: browseView.fontBody
                                    font.pixelSize: 8; font.bold: true; font.letterSpacing: 0.5
                                    color: "#f5c518"
                                }
                            }

                            // Type badge
                            Rectangle {
                                visible: modelData.type && modelData.type.length > 0
                                anchors { top: parent.top; right: parent.right; topMargin: 8; rightMargin: 8 }
                                height: 20; radius: 10
                                width: typeText.implicitWidth + 12
                                color: Qt.rgba(0, 0, 0, 0.7)

                                StyledText {
                                    id: typeText; anchors.centerIn: parent
                                    text: (modelData.type || "").toUpperCase()
                                    font.family: browseView.fontBody
                                    font.pixelSize: 8; font.letterSpacing: 1; font.bold: true
                                    color: Colors.primary_fixed_dim
                                }
                            }

                            // Episode count badge (bottom-right of cover)
                            Rectangle {
                                visible: modelData.availableEpisodes
                                    && (modelData.availableEpisodes.sub > 0
                                        || modelData.availableEpisodes.dub > 0)
                                anchors {
                                    bottom: parent.bottom; right: parent.right
                                    bottomMargin: 8; rightMargin: 8
                                }
                                height: 20; radius: 10
                                width: epText.implicitWidth + 12
                                color: Qt.rgba(0, 0, 0, 0.72)

                                StyledText {
                                    id: epText; anchors.centerIn: parent
                                    text: {
                                        var avail = modelData.availableEpisodes
                                        var n = Anime.currentMode === "dub"
                                            ? avail.dub : avail.sub
                                        return n + " ep"
                                    }
                                    font.family: browseView.fontBody
                                    font.pixelSize: 8; font.letterSpacing: 0.5
                                    color: Qt.rgba(1, 1, 1, 0.85)
                                }
                            }

                            // Gradient
                            Rectangle {
                                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                height: 48
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
                            height: titleText.implicitHeight + 16
                            color: Colors.surface_container; radius: 12

                            StyledText {
                                id: titleText
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 10; rightMargin: 10
                                }
                                text: modelData.englishName || modelData.name || ""
                                font.family: browseView.fontBody
                                font.pixelSize: 11; font.letterSpacing: 0.2
                                wrapMode: Text.Wrap; maximumLineCount: 2
                                elide: Text.ElideRight; lineHeight: 1.3
                            }
                        }

                        // Library bookmark dot
                        Rectangle {
                            visible: Anime.isInLibrary(modelData.id)
                            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 6 }
                            width: 7; height: 7; radius: 4
                            color: Colors.primary
                            opacity: 0.9
                        }

                        Rectangle {
                            anchors.fill: parent; radius: 12; color: Colors.primary
                            opacity: card.pressed ? 0.16 : (card.hovered ? 0.07 : 0)
                            Behavior on opacity { NumberAnimation { duration: 130 } }
                        }

                        transform: Scale {
                            origin.x: card.width / 2; origin.y: card.height / 2
                            xScale: card.pressed ? 0.97 : 1.0
                            yScale: card.pressed ? 0.97 : 1.0
                            Behavior on xScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            Behavior on yScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        }

                        onClicked: browseView.animeSelected(modelData)
                    }
                }
            }
        }
    }
}
