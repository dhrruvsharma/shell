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
        Novel.currentNovel ? Novel.isInLibrary(Novel.currentNovel.id) : false

    readonly property var _reversedChapters:
        Novel.currentNovel ? Novel.currentNovel.chapters.slice().reverse() : []

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true; height: 56
            color: c.surface_container_low; z: 2

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
                        anchors.centerIn: parent; width: 34; height: 34; radius: 17
                        color: backArea.containsMouse ? c.surface_container : "transparent"
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }
                    Text { anchors.centerIn: parent; text: "←"; font.pixelSize: 18; color: c.on_surface_variant }
                    MouseArea {
                        id: backArea; anchors.fill: parent; hoverEnabled: true
                        onClicked: { Novel.clearDetail(); detailView.backRequested() }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: Novel.currentNovel ? Novel.currentNovel.title : ""
                    font.family: detailView.fontDisplay
                    font.pixelSize: 15; color: c.on_surface; elide: Text.ElideRight
                }

                Item {
                    visible: Novel.currentNovel !== null
                    width: libBtnLabel.implicitWidth + 28; height: 34

                    Rectangle {
                        anchors.fill: parent; radius: height / 2
                        color: detailView._inLibrary ? c.primary_container : c.surface_container
                        border.color: detailView._inLibrary ? c.primary : c.outline_variant
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }

                    Row {
                        anchors.centerIn: parent; spacing: 5
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: detailView._inLibrary ? "✓" : "+"
                            font.pixelSize: 11; font.bold: true
                            color: detailView._inLibrary ? c.on_primary_container : c.on_surface_variant
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                        Text {
                            id: libBtnLabel; anchors.verticalCenter: parent.verticalCenter
                            text: "Library"; font.family: detailView.fontBody
                            font.pixelSize: 11; font.letterSpacing: 0.3
                            color: detailView._inLibrary ? c.on_primary_container : c.on_surface_variant
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            if (detailView._inLibrary)
                                Novel.removeFromLibrary(Novel.currentNovel.id)
                            else
                                Novel.addToLibrary({
                                    id:       Novel.currentNovel.id,
                                    title:    Novel.currentNovel.title,
                                    coverUrl: Novel.currentNovel.coverUrl
                                })
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: Novel.currentNovel !== null ? 130 : 0
            color: c.surface_container_low; clip: true
            Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            Image {
                anchors.fill: parent
                source: Novel.currentNovel ? Novel.currentNovel.coverUrl : ""
                fillMode: Image.PreserveAspectCrop; asynchronous: true; opacity: 0.1
            }
            Rectangle { anchors.fill: parent; color: c.surface_container_low; opacity: 0.84 }

            Row {
                anchors { fill: parent; margins: 14 }
                spacing: 14

                Rectangle {
                    width: 72; height: 104; radius: 8
                    color: c.surface_container_high; clip: true
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent
                        source: Novel.currentNovel ? Novel.currentNovel.coverUrl : ""
                        fillMode: Image.PreserveAspectCrop; asynchronous: true
                    }
                    Rectangle {
                        anchors.fill: parent; radius: 8; color: "transparent"
                        border.color: c.outline_variant; border.width: 1
                    }
                }

                Column {
                    width: parent.width - 86; spacing: 5
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        spacing: 6

                        Rectangle {
                            visible: Novel.currentNovel && Novel.currentNovel.status.length > 0
                            height: 18; width: statusTxt.implicitWidth + 14; radius: 9
                            color: Qt.rgba(c.tertiary.r, c.tertiary.g, c.tertiary.b, 0.15)
                            border.color: c.tertiary; border.width: 1

                            Text {
                                id: statusTxt; anchors.centerIn: parent
                                text: Novel.currentNovel ? (Novel.currentNovel.status || "").toUpperCase() : ""
                                font.family: detailView.fontBody; font.pixelSize: 9
                                font.letterSpacing: 1.2; font.bold: true; color: c.tertiary
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: Novel.currentNovel ? Novel.currentNovel.author : ""
                        font.family: detailView.fontBody; font.pixelSize: 12; font.bold: true
                        color: c.on_surface; elide: Text.ElideRight
                    }

                    Text {
                        visible: Novel.currentNovel && Novel.currentNovel.genres.length > 0
                        width: parent.width
                        text: Novel.currentNovel ? Novel.currentNovel.genres.join(" · ") : ""
                        font.family: detailView.fontBody; font.pixelSize: 10
                        color: c.primary; opacity: 0.85; elide: Text.ElideRight; font.letterSpacing: 0.2
                    }

                    Text {
                        width: parent.width
                        text: Novel.currentNovel ? Novel.currentNovel.description : ""
                        font.family: detailView.fontBody; font.pixelSize: 11
                        color: c.on_surface_variant; wrapMode: Text.Wrap
                        maximumLineCount: 3; elide: Text.ElideRight; opacity: 0.8; lineHeight: 1.35
                    }
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: c.outline_variant; opacity: 0.35
            }
        }

        Rectangle {
            Layout.fillWidth: true; height: 36
            color: c.surface_container
            visible: Novel.currentNovel !== null

            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }

                Text {
                    text: Novel.currentNovel ? Novel.currentNovel.chapters.length + " chapters" : ""
                    font.family: detailView.fontBody; font.pixelSize: 11
                    font.letterSpacing: 1; color: c.on_surface_variant; opacity: 0.75
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    readonly property var _entry: Novel.currentNovel
                        ? Novel.getLibraryEntry(Novel.currentNovel.id) : null
                    visible: _entry !== null && _entry !== undefined
                        && _entry.lastReadChapterNum !== "" && _entry.lastReadChapterNum !== undefined
                    height: 20; width: lastReadTxt.implicitWidth + 18; radius: 10
                    color: Qt.rgba(c.primary.r, c.primary.g, c.primary.b, 0.12)
                    border.color: c.primary; border.width: 1

                    Text {
                        id: lastReadTxt; anchors.centerIn: parent
                        text: {
                            var e = Novel.currentNovel ? Novel.getLibraryEntry(Novel.currentNovel.id) : null
                            return e ? "Last: Ch. " + e.lastReadChapterNum : ""
                        }
                        font.family: detailView.fontBody; font.pixelSize: 9
                        font.letterSpacing: 0.8; color: c.primary
                    }
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: c.outline_variant; opacity: 0.3
            }
        }

        Item {
            Layout.fillWidth: true; Layout.fillHeight: true

            Rectangle { anchors.fill: parent; color: c.background }

            Rectangle {
                anchors.fill: parent; color: c.background
                visible: Novel.isFetchingDetail; z: 5

                Column {
                    anchors.centerIn: parent; spacing: 14
                    Rectangle {
                        width: 28; height: 28; radius: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "transparent"; border.color: c.primary; border.width: 2
                        RotationAnimator on rotation {
                            from: 0; to: 360; duration: 800
                            loops: Animation.Infinite; running: parent.visible; easing.type: Easing.Linear
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter; text: "fetching chapters"
                        color: c.on_surface_variant; font.family: detailView.fontBody
                        font.pixelSize: 11; font.letterSpacing: 2; opacity: 0.7
                    }
                }
            }

            ListView {
                id: chapterList
                anchors.fill: parent; clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: Novel.currentNovel ? Novel.currentNovel.chapters : []
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitWidth: 3; color: c.primary; opacity: 0.45; radius: 2 }
                }

                delegate: Rectangle {
                    width: chapterList.width; height: 62

                    readonly property var _libEntry: Novel.currentNovel
                        ? Novel.getLibraryEntry(Novel.currentNovel.id) : null
                    readonly property bool isLastRead:
                        _libEntry !== null && _libEntry !== undefined
                        && _libEntry.lastReadChapterId === modelData.id

                    color: isLastRead
                        ? Qt.rgba(c.primary.r, c.primary.g, c.primary.b, 0.07)
                        : (rowArea.pressed ? c.surface_container_high
                            : (rowArea.containsMouse ? c.surface_container : "transparent"))
                    Behavior on color { ColorAnimation { duration: 110 } }

                    Rectangle {
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 72; rightMargin: 16 }
                        height: 1; color: c.outline_variant; opacity: 0.25
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                        spacing: 14

                        // Chapter pill
                        Rectangle {
                            width: chPillTxt.implicitWidth + 16; height: 26; radius: 13
                            color: isLastRead ? c.primary : c.primary_container

                            Text {
                                id: chPillTxt; anchors.centerIn: parent
                                text: "Ch." + (modelData.chapter || "?")
                                font.family: detailView.fontBody; font.pixelSize: 9
                                font.bold: true; font.letterSpacing: 0.5
                                color: isLastRead ? c.on_primary : c.on_primary_container
                            }
                        }

                        Column {
                            Layout.fillWidth: true; spacing: 3

                            Text {
                                width: parent.width
                                text: modelData.title || ("Chapter " + (modelData.chapter || ""))
                                font.family: detailView.fontBody; font.pixelSize: 12
                                color: c.on_surface; elide: Text.ElideRight
                            }

                            // Word count hint if available (omitted if 0)
                            Text {
                                visible: false  // populated after chapter is fetched — omit for now
                                font.family: detailView.fontBody; font.pixelSize: 10
                                color: c.on_surface_variant; opacity: 0.5; font.letterSpacing: 0.3
                            }
                        }

                        Text {
                            text: "›"; font.pixelSize: 20; color: c.outline
                            opacity: rowArea.containsMouse ? 0.9 : 0.4
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }
                    }

                    MouseArea {
                        id: rowArea; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            Novel.fetchChapter(modelData.id)
                            detailView.chapterSelected(modelData.id)
                            if (Novel.currentNovel && Novel.isInLibrary(Novel.currentNovel.id))
                                Novel.updateLastRead(Novel.currentNovel.id, modelData.id, modelData.chapter)
                        }
                    }
                }
            }
        }
    }
}
