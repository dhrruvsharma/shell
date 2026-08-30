import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.colors
import qs.services
import qs.components

Item {
    id: libraryView

    readonly property string fontDisplay: "Noto Serif"
    readonly property string fontBody:    "Noto Sans"

    // Emitted when the user taps an entry — parent handles navigation
    signal mangaSelected(string mangaId)

    // ── Background ────────────────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: Colors.background }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Empty state ───────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Manga.libraryList.length === 0 && Manga.libraryLoaded

            EmptyState {
                title: "Your library is empty"
                subtitle: "Open any manga and tap  + Library"
                displayFont: libraryView.fontDisplay
                bodyFont: libraryView.fontBody
            }
        }

        // ── Loading (first open before file is read) ──────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !Manga.libraryLoaded

            Column {
                anchors.centerIn: parent
                spacing: 16
                Spinner {
                    width: 28
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        GridView {
            id: libGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Manga.libraryList.length > 0
            topMargin: 10
            leftMargin: 8
            rightMargin: 8
            bottomMargin: 10
            cellWidth: Math.floor((width - leftMargin - rightMargin) / 4)
            cellHeight: cellWidth * 1.72
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: Manga.libraryList

            ScrollBar.vertical: StyledScrollBar {
            }

            delegate: Item {
                width: libGrid.cellWidth
                height: libGrid.cellHeight

                readonly property var libEntry: modelData

                CoverCard {
                    anchors.fill: parent
                    source: libEntry.coverUrl || ""
                    title: libEntry.title || ""
                    bodyFont: libraryView.fontBody
                    gradientHeight: 48
                    footerHeight: 30

                    CoverProgressBar {
                        height: 30
                        rowSpacing: 6
                        bodyFont: libraryView.fontBody
                        started: libEntry.lastReadChapterNum
                        label: libEntry.lastReadChapterNum
                                ? "Ch. " + libEntry.lastReadChapterNum
                                : "Not started"
                    }

                    onClicked: {
                        Manga.fetchMangaDetail(libEntry.id)
                        libraryView.mangaSelected(libEntry.id)
                    }
                }
            }
        }
    }
}
