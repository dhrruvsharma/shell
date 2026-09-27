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

    signal novelSelected(string novelId)

    property string currentFilter: "hot"

    function _switchFilter(f) {
        if (currentFilter === f) return
        currentFilter = f
        searchBar.visible = false
        searchField.text = ""
        Novel.clearNovelList()
        if (f === "hot") Novel.fetchHot()
        else             Novel.fetchLatest(true)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Top bar ───────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 60
            color: Colors.surface_container_low
            z: 2

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: Colors.outline_variant; opacity: 0.5
            }

            RowLayout {
                anchors { fill: parent; leftMargin: 18; rightMargin: 12 }
                spacing: 10

                // Title (hidden while search bar is open)
                Row {
                    spacing: 0
                    visible: !searchBar.visible
                    StyledText {
                        text: "N"
                        font.family: browseView.fontDisplay
                        font.pixelSize: 24; font.letterSpacing: 1
                        color: Colors.primary
                    }
                    StyledText {
                        text: "ovel"
                        font.family: browseView.fontDisplay
                        font.pixelSize: 24; font.letterSpacing: 1
                        color: Colors.on_surface; opacity: 0.85
                    }
                }

                // Search bar (shown when search icon is tapped)
                Rectangle {
                    id: searchBar
                    Layout.fillWidth: true
                    height: 38; radius: 19
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
                        font.family: browseView.fontBody; font.pixelSize: 13
                        clip: true
                        onTextChanged: searchDebounce.restart()
                        Keys.onEscapePressed: {
                            searchBar.visible = false
                            text = ""
                            browseView.currentFilter = "hot"
                            Novel.fetchHot()
                        }
                    }

                    StyledText {
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 16 }
                        text: "Search novels…"
                        color: Colors.on_surface_variant; font.family: browseView.fontBody
                        font.pixelSize: 13; visible: searchField.text.length === 0; opacity: 0.6
                    }

                    Item {
                        id: clearBtn
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 10 }
                        width: 22; height: 22
                        visible: searchField.text.length > 0
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                        Rectangle {
                            anchors.centerIn: parent; width: 18; height: 18; radius: 9
                            color: Colors.surface_container_highest
                        }
                        StyledText {
                            anchors.centerIn: parent; text: "✕"
                            color: Colors.on_surface_variant; font.pixelSize: 9; font.bold: true
                        }
                        MouseArea { anchors.fill: parent; onClicked: searchField.text = "" }
                    }
                }

                Timer {
                    id: searchDebounce
                    interval: 380
                    onTriggered: {
                        var q = searchField.text.trim()
                        if (q.length > 0) {
                            browseView.currentFilter = "search"
                            Novel.searchNovels(q, "", "All", true)
                        } else {
                            browseView.currentFilter = "hot"
                            Novel.fetchHot()
                        }
                    }
                }

                // ── Provider dropdown button ──────────────────────────────────
                Item {
                    visible: !searchBar.visible
                    width: 200
                    height: 32

                    Rectangle {
                        anchors.fill: parent; radius: 16
                        color: providerDropArea.containsMouse
                            ? Colors.surface_container_highest
                            : Colors.surface_container
                        border.color: Colors.outline_variant; border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 5

                        StyledText {
                            id: providerLabel
                            text: {
                                for (var i = 0; i < Novel.availableProviders.length; i++) {
                                    if (Novel.availableProviders[i].name === Novel.activeProvider)
                                        return Novel.availableProviders[i].label
                                }
                                return Novel.activeProvider
                            }
                            font.family: browseView.fontBody; font.pixelSize: 11
                            font.letterSpacing: 0.3
                            color: Novel.isSwitchingProvider ? Colors.on_surface_variant : Colors.on_surface
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        // Tiny spinner shown while switching
                        Spinner {
                            visible: Novel.isSwitchingProvider
                            width: 10
                            border.width: 1.5
                            anchors.verticalCenter: parent.verticalCenter
                            duration: 700
                            running: Novel.isSwitchingProvider
                        }

                        // Chevron (hidden while switching)
                        StyledText {
                            visible: !Novel.isSwitchingProvider
                            text: providerPopup.visible ? "▲" : "▾"
                            font.pixelSize: 8
                            color: Colors.on_surface_variant
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: providerDropArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (!Novel.isSwitchingProvider)
                                providerPopup.visible = !providerPopup.visible
                        }
                    }

                    // ── Dropdown popup ────────────────────────────────────────
                    Rectangle {
                        id: providerPopup
                        visible: false
                        // Anchor below the button, right-aligned
                        anchors { top: parent.bottom; right: parent.right; topMargin: 6 }
                        width: 150
                        height: popupColumn.implicitHeight + 10
                        radius: DesktopTheme.rad(10)
                        color: Colors.surface_container_high
                        border.color: Colors.outline_variant; border.width: 1
                        z: 100

                        // Drop shadow hint
                        layer.enabled: true

                        Column {
                            id: popupColumn
                            anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 5 }
                            spacing: 0

                            Repeater {
                                model: Novel.availableProviders

                                delegate: Item {
                                    width: parent.width
                                    height: 36

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.leftMargin: 4; anchors.rightMargin: 4
                                        radius: DesktopTheme.rad(7)
                                        color: {
                                            if (modelData.name === Novel.activeProvider)
                                                return Colors.primary_container
                                            return optionArea.containsMouse
                                                ? Colors.surface_container_highest
                                                : "transparent"
                                        }
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }

                                    Row {
                                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 14 }
                                        spacing: 8

                                        // Active indicator dot
                                        Rectangle {
                                            width: 6; height: 6; radius: 3
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: Colors.primary
                                            visible: modelData.name === Novel.activeProvider
                                        }
                                        // Spacer when not active so text stays aligned
                                        Item {
                                            width: 6; height: 6
                                            visible: modelData.name !== Novel.activeProvider
                                        }

                                        StyledText {
                                            text: modelData.label
                                            font.family: browseView.fontBody; font.pixelSize: 12
                                            color: modelData.name === Novel.activeProvider
                                                ? Colors.on_primary_container
                                                : Colors.on_surface
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: optionArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            providerPopup.visible = false
                                            Novel.switchProvider(modelData.name)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Search icon ───────────────────────────────────────────────
                Item {
                    width: 40; height: 40

                    Rectangle {
                        anchors.centerIn: parent; width: 34; height: 34; radius: 17
                        color: searchBar.visible ? Colors.primary_container : "transparent"
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                    StyledText {
                        anchors.centerIn: parent; text: "⌕"; font.pixelSize: 19
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
                                browseView.currentFilter = "hot"
                                Novel.fetchHot()
                            }
                        }
                    }
                }
            }
        }

        // ── Filter chips (Hot / Latest) ───────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 48
            color: Colors.surface_container_low; clip: true

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1; color: Colors.outline_variant; opacity: 0.25
            }

            ListView {
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                orientation: ListView.Horizontal; spacing: 7; clip: true
                boundsBehavior: Flickable.StopAtBounds

                model: ListModel {
                    ListElement { label: "Hot";    fid: "hot"    }
                    ListElement { label: "Latest"; fid: "latest" }
                }

                delegate: Item {
                    width: chip.implicitWidth + 28; height: parent.height

                    Rectangle {
                        id: chip
                        anchors.centerIn: parent
                        implicitWidth: chipLbl.implicitWidth + 28; height: 30; radius: 15
                        color: browseView.currentFilter === fid ? Colors.primary : Colors.surface_container
                        border.color: browseView.currentFilter === fid ? Colors.primary : Colors.outline_variant
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 180 } }

                        StyledText {
                            id: chipLbl; anchors.centerIn: parent; text: label
                            font.family: browseView.fontBody; font.pixelSize: 12
                            font.letterSpacing: 0.6
                            color: browseView.currentFilter === fid ? Colors.on_primary : Colors.on_surface_variant
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: browseView._switchFilter(fid)
                    }
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: Colors.outline_variant; opacity: 0.3
            }
        }

        // ── Novel grid ────────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true

            // Close the provider popup when clicking outside it
            MouseArea {
                anchors.fill: parent
                enabled: providerPopup.visible
                onClicked: providerPopup.visible = false
                z: 50
            }

            // Loading overlay
            Rectangle {
                anchors.fill: parent; color: Colors.background; z: 10
                visible: Novel.isFetchingNovel && Novel.novelList.length === 0

                Column {
                    anchors.centerIn: parent; spacing: 16
                    Spinner {
                        width: 36
                        anchors.horizontalCenter: parent.horizontalCenter
                        border.width: 2.5
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "loading"; color: Colors.on_surface_variant
                        font.family: browseView.fontBody; font.pixelSize: 11
                        font.letterSpacing: 2.5; opacity: 0.7
                    }
                }
            }

            // Error overlay
            Rectangle {
                anchors.fill: parent; color: Colors.background; z: 9
                visible: Novel.novelError.length > 0 && !Novel.isFetchingNovel

                Column {
                    anchors.centerIn: parent; spacing: 10
                    Text { text: "⚠"; font.pixelSize: 32; color: Colors.error; anchors.horizontalCenter: parent.horizontalCenter; opacity: 0.8 }
                    Text {
                        text: Novel.novelError; color: Colors.on_surface_variant
                        font.pixelSize: 12; font.family: browseView.fontBody
                        wrapMode: Text.Wrap; width: 260; horizontalAlignment: Text.AlignHCenter; lineHeight: 1.4
                    }
                }
            }

            GridView {
                id: novelGrid
                anchors.fill: parent; anchors.margins: 10
                cellWidth: (width - 10) / 4
                cellHeight: cellWidth * 1.65
                clip: true; boundsBehavior: Flickable.StopAtBounds
                model: Novel.novelList

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitWidth: 3; color: Colors.primary; opacity: 0.45; radius: 2 }
                }

                onContentYChanged: {
                    if (contentY + height > contentHeight - cellHeight * 2)
                        Novel.fetchNextPage()
                }

                delegate: Item {
                    width: novelGrid.cellWidth; height: novelGrid.cellHeight

                    ClickableRect {
                        id: nCard
                        anchors { fill: parent; margins: 5 }
                        radius: 10; color: Colors.surface_container; clip: true

                        Image {
                            id: coverImg
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            height: parent.height - nTitleBar.height
                            source: modelData.coverUrl || ""
                            fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 300 } }

                            Rectangle {
                                anchors.fill: parent; color: Colors.surface_container_high
                                visible: coverImg.status !== Image.Ready
                                Text { anchors.centerIn: parent; text: "◫"; font.pixelSize: 28; color: Colors.outline; opacity: 0.25 }
                            }

                            Rectangle {
                                visible: modelData.status && modelData.status.length > 0
                                anchors { top: parent.top; left: parent.left; topMargin: 8; leftMargin: 8 }
                                height: 18; radius: 9; width: statusBadge.implicitWidth + 12
                                color: modelData.status === "Ongoing"
                                    ? Qt.rgba(0.2, 0.75, 0.4, 0.85)
                                    : Qt.rgba(0.3, 0.5, 0.9, 0.85)

                                Text {
                                    id: statusBadge; anchors.centerIn: parent
                                    text: (modelData.status || "").toUpperCase()
                                    font.family: browseView.fontBody; font.pixelSize: 7
                                    font.letterSpacing: 0.8; font.bold: true; color: "white"
                                }
                            }

                            Rectangle {
                                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                height: 52
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 1.0; color: Colors.surface_container }
                                }
                            }
                        }

                        Rectangle {
                            id: nTitleBar
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: nTitleText.implicitHeight + 18; color: Colors.surface_container; radius: 10

                            Column {
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 10; rightMargin: 10
                                }
                                spacing: 3

                                Text {
                                    id: nTitleText; width: parent.width
                                    text: modelData.title || ""
                                    font.family: browseView.fontBody; font.pixelSize: 11
                                    font.letterSpacing: 0.2; color: Colors.on_surface
                                    wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; lineHeight: 1.3
                                }
                                StyledText {
                                    visible: modelData.author && modelData.author.length > 0
                                    width: parent.width
                                    text: modelData.author || ""
                                    font.family: browseView.fontBody; font.pixelSize: 9
                                    color: Colors.on_surface_variant; opacity: 0.6
                                    elide: Text.ElideRight; font.letterSpacing: 0.3
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent; radius: 10; color: Colors.primary
                            opacity: nCard.pressed ? 0.16 : (nCard.hovered ? 0.07 : 0)
                            Behavior on opacity { NumberAnimation { duration: 130 } }
                        }

                        transform: Scale {
                            origin.x: nCard.width / 2; origin.y: nCard.height / 2
                            xScale: nCard.pressed ? 0.97 : 1.0
                            yScale: nCard.pressed ? 0.97 : 1.0
                            Behavior on xScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            Behavior on yScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        }

                        onClicked: {
                                Novel.fetchNovelDetail(modelData.id)
                                browseView.novelSelected(modelData.id)
                            }
                    }
                }
            }
        }
    }
}
