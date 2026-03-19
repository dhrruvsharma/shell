import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../colors" as ColorsModule
import qs.services

Item {
    id: detailView

    readonly property var c: ColorsModule.Colors
    readonly property string fontDisplay: "Noto Serif"
    readonly property string fontBody:    "Noto Sans"

    signal backRequested()
    signal chapterSelected(string chapterId)

    readonly property bool _inLibrary:
        Manga.currentManga ? Manga.isInLibrary(Manga.currentManga.id) : false

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ────────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 56
            color: c.surface_container_low
            z: 2

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: c.outline_variant; opacity: 0.5
            }

            RowLayout {
                anchors { fill: parent; leftMargin: 6; rightMargin: 10 }
                spacing: 2

                // Back button
                Item {
                    width: 44; height: 44

                    Rectangle {
                        anchors.centerIn: parent
                        width: 34; height: 34; radius: 17
                        color: backArea.containsMouse ? c.surface_container : "transparent"
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "←"; font.pixelSize: 18; color: c.on_surface_variant
                    }
                    MouseArea {
                        id: backArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: { Manga.clearChapterList(); detailView.backRequested() }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: Manga.currentManga ? Manga.currentManga.title : ""
                    font.family: detailView.fontDisplay
                    font.pixelSize: 15; color: c.on_surface; elide: Text.ElideRight
                }

                // ── Library toggle button ─────────────────────────────────────
                Item {
                    visible: Manga.currentManga !== null
                    width: libBtnLabel.implicitWidth + 28
                    height: 34

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: detailView._inLibrary ? c.primary_container : c.surface_container
                        border.color: detailView._inLibrary ? c.primary : c.outline_variant
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: detailView._inLibrary ? "✓" : "+"
                            font.pixelSize: 11; font.bold: true
                            color: detailView._inLibrary
                                ? c.on_primary_container : c.on_surface_variant
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                        Text {
                            id: libBtnLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Library"
                            font.family: detailView.fontBody
                            font.pixelSize: 11; font.letterSpacing: 0.3
                            color: detailView._inLibrary
                                ? c.on_primary_container : c.on_surface_variant
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (detailView._inLibrary) {
                                Manga.removeFromLibrary(Manga.currentManga.id)
                            } else {
                                Manga.addToLibrary({
                                    id:       Manga.currentManga.id,
                                    title:    Manga.currentManga.title,
                                    coverUrl: Manga.currentManga.coverUrl
                                })
                            }
                        }
                    }
                }
            }
        }

        // ── Hero banner ───────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: Manga.currentManga !== null ? 120 : 0
            color: c.surface_container_low
            clip: true
            Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            Image {
                anchors.fill: parent
                source: Manga.currentManga ? Manga.currentManga.coverUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true; opacity: 0.12
                layer.enabled: true; layer.effect: null
            }
            Rectangle { anchors.fill: parent; color: c.surface_container_low; opacity: 0.82 }

            Row {
                anchors { fill: parent; margins: 14 }
                spacing: 14

                Rectangle {
                    width: 66; height: 92; radius: 8
                    color: c.surface_container_high; clip: true
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent
                        source: Manga.currentManga ? Manga.currentManga.coverUrl : ""
                        fillMode: Image.PreserveAspectCrop; asynchronous: true
                    }
                    Rectangle {
                        anchors.fill: parent; radius: 8; color: "transparent"
                        border.color: c.outline_variant; border.width: 1
                    }
                }

                Column {
                    width: parent.width - 80
                    spacing: 5; anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        visible: Manga.currentManga && Manga.currentManga.status.length > 0
                        height: 18; width: statusText.implicitWidth + 14; radius: 9
                        color: Qt.rgba(c.tertiary.r, c.tertiary.g, c.tertiary.b, 0.15)
                        border.color: c.tertiary; border.width: 1

                        Text {
                            id: statusText; anchors.centerIn: parent
                            text: Manga.currentManga
                                ? (Manga.currentManga.status || "").toUpperCase() : ""
                            font.family: detailView.fontBody
                            font.pixelSize: 9; font.letterSpacing: 1.2; font.bold: true
                            color: c.tertiary
                        }
                    }

                    Text {
                        width: parent.width
                        text: Manga.currentManga
                            ? (Manga.currentManga.authors || []).join(", ") : ""
                        font.family: detailView.fontBody
                        font.pixelSize: 12; font.bold: true
                        color: c.on_surface; elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: Manga.currentManga ? Manga.currentManga.description : ""
                        font.family: detailView.fontBody; font.pixelSize: 11
                        color: c.on_surface_variant
                        wrapMode: Text.Wrap; maximumLineCount: 3
                        elide: Text.ElideRight; opacity: 0.8; lineHeight: 1.35
                    }
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: c.outline_variant; opacity: 0.35
            }
        }

        // ── Chapter count + last-read strip ───────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 36
            color: c.surface_container
            visible: Manga.currentManga !== null

            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }

                Text {
                    text: Manga.currentManga
                        ? Manga.currentManga.chapters.length + " chapters" : ""
                    font.family: detailView.fontBody
                    font.pixelSize: 11; font.letterSpacing: 1
                    color: c.on_surface_variant; opacity: 0.75
                }

                Item { Layout.fillWidth: true }

                // Last-read badge (visible only when manga is in library and a chapter was read)
                Rectangle {
                    readonly property var _entry: Manga.currentManga
                        ? Manga.getLibraryEntry(Manga.currentManga.id) : null
                    visible: _entry !== null && _entry !== undefined
                        && _entry.lastReadChapterNum !== ""
                        && _entry.lastReadChapterNum !== undefined
                    height: 20; width: lastReadText.implicitWidth + 18; radius: 10
                    color: Qt.rgba(c.primary.r, c.primary.g, c.primary.b, 0.12)
                    border.color: c.primary; border.width: 1

                    Text {
                        id: lastReadText; anchors.centerIn: parent
                        text: {
                            var e = Manga.currentManga
                                ? Manga.getLibraryEntry(Manga.currentManga.id) : null
                            return e ? "Last: Ch. " + e.lastReadChapterNum : ""
                        }
                        font.family: detailView.fontBody
                        font.pixelSize: 9; font.letterSpacing: 0.8; color: c.primary
                    }
                }

                Rectangle { width: 3; height: 3; radius: 2; color: c.outline_variant; opacity: 0.5 }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: c.outline_variant; opacity: 0.3
            }
        }

        // ── Chapter list ──────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            Rectangle { anchors.fill: parent; color: c.background }

            Rectangle {
                anchors.fill: parent; color: c.background
                visible: Manga.isFetchingDetail; z: 5

                Column {
                    anchors.centerIn: parent; spacing: 14

                    Rectangle {
                        width: 28; height: 28; radius: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "transparent"; border.color: c.primary; border.width: 2
                        RotationAnimator on rotation {
                            from: 0; to: 360; duration: 800
                            loops: Animation.Infinite; running: parent.visible
                            easing.type: Easing.Linear
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "fetching chapters"
                        color: c.on_surface_variant
                        font.family: detailView.fontBody
                        font.pixelSize: 11; font.letterSpacing: 2; opacity: 0.7
                    }
                }
            }

            ListView {
                id: chapterList
                anchors.fill: parent; clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: Manga.currentManga ? Manga.currentManga.chapters : []

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 3; color: c.primary; opacity: 0.45; radius: 2
                    }
                }

                delegate: Rectangle {
                    width: chapterList.width; height: 58

                    readonly property var _libEntry: Manga.currentManga
                        ? Manga.getLibraryEntry(Manga.currentManga.id) : null
                    readonly property bool isLastRead:
                        _libEntry !== null && _libEntry !== undefined
                        && _libEntry.lastReadChapterId === modelData.id

                    color: isLastRead
                        ? Qt.rgba(c.primary.r, c.primary.g, c.primary.b, 0.07)
                        : (chapterRowArea.pressed
                            ? c.surface_container_high
                            : (chapterRowArea.containsMouse ? c.surface_container : "transparent"))
                    Behavior on color { ColorAnimation { duration: 110 } }

                    Rectangle {
                        anchors {
                            bottom: parent.bottom
                            left: parent.left; right: parent.right
                            leftMargin: 72; rightMargin: 16
                        }
                        height: 1; color: c.outline_variant; opacity: 0.25
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                        spacing: 14

                        Rectangle {
                            width: chapterPillText.implicitWidth + 16
                            height: 26; radius: 13
                            color: isLastRead ? c.primary : c.primary_container

                            Text {
                                id: chapterPillText; anchors.centerIn: parent
                                text: "Ch." + (modelData.chapter || "?")
                                font.family: detailView.fontBody
                                font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.5
                                color: isLastRead ? c.on_primary : c.on_primary_container
                            }
                        }

                        Column {
                            Layout.fillWidth: true; spacing: 3

                            Text {
                                width: parent.width
                                text: modelData.title || ("Chapter " + (modelData.chapter || ""))
                                font.family: detailView.fontBody
                                font.pixelSize: 12; color: c.on_surface; elide: Text.ElideRight
                            }
                            Text {
                                text: modelData.publishAt
                                    ? Qt.formatDate(new Date(modelData.publishAt), "MMM d, yyyy")
                                    : ""
                                font.family: detailView.fontBody
                                font.pixelSize: 10; color: c.on_surface_variant
                                opacity: 0.55; font.letterSpacing: 0.3
                            }
                        }

                        Text {
                            text: "›"; font.pixelSize: 20; color: c.outline
                            opacity: chapterRowArea.containsMouse ? 0.9 : 0.4
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }
                    }

                    MouseArea {
                        id: chapterRowArea; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            Manga.fetchChapterPages(modelData.id)
                            detailView.chapterSelected(modelData.id)
                            if (Manga.currentManga && Manga.isInLibrary(Manga.currentManga.id)) {
                                Manga.updateLastRead(
                                    Manga.currentManga.id,
                                    modelData.id,
                                    modelData.chapter
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
