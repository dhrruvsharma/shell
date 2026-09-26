import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.colors
import qs.services
import Quickshell.Io
import qs.components

Item {
    id: detailView

    readonly property string fontDisplay: "Noto Serif"
    readonly property string fontBody:    "Noto Sans"

    signal backRequested()

    readonly property bool _inLibrary:
        Anime.currentAnime ? Anime.isInLibrary(Anime.currentAnime.id) : false

    // ── MPV launcher ──────────────────────────────────────────────────────────
    Process {
        id: mpvProcess
    }

    function _playWithMpv(url, referer, subtitle, title) {
        if (!url || url.length === 0) {
            console.warn("[AnimeDetail] _playWithMpv called with empty URL, aborting")
            return
        }

        mpvProcess.running = false

        var args = [
            "mpv",
            "--fs",
            "--force-window=yes",
            "--title=" + (title || "Anime"),
            "--no-terminal"
        ]

        if (referer && referer.length > 0)
            args.push("--referrer=" + referer)
        if (subtitle && subtitle.length > 0)
            args.push("--sub-file=" + subtitle)

        args.push(url)
        mpvProcess.command = args
        mpvProcess.running = true
    }

    Rectangle { anchors.fill: parent; color: Colors.background }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            height: 52
            color: Colors.surface_container_low
            z: 2

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: Colors.outline_variant; opacity: 0.5
            }

            RowLayout {
                anchors { fill: parent; leftMargin: 6; rightMargin: 10 }
                spacing: 2

                // Back
                Item {
                    width: 44; height: 44

                    Rectangle {
                        anchors.centerIn: parent; width: 34; height: 34; radius: 17
                        color: backArea.containsMouse ? Colors.surface_container : "transparent"
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "←"; font.pixelSize: 18; color: Colors.on_surface_variant
                    }
                    MouseArea {
                        id: backArea; anchors.fill: parent; hoverEnabled: true
                        onClicked: detailView.backRequested()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: Anime.currentAnime
                        ? (Anime.currentAnime.englishName || Anime.currentAnime.name || "")
                        : ""
                    font.family: detailView.fontDisplay
                    font.pixelSize: 14; color: Colors.on_surface; elide: Text.ElideRight
                }

                Item {
                    visible: Anime.currentAnime !== null
                    width: libBtnLabel.implicitWidth + 28; height: 32

                    Rectangle {
                        anchors.fill: parent; radius: height / 2
                        color: detailView._inLibrary ? Colors.primary_container : Colors.surface_container
                        border.color: detailView._inLibrary ? Colors.primary : Colors.outline_variant
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                    Row {
                        anchors.centerIn: parent; spacing: 5

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: detailView._inLibrary ? "✓" : "+"
                            font.pixelSize: 11; font.bold: true
                            color: detailView._inLibrary
                                ? Colors.on_primary_container : Colors.on_surface_variant
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                        StyledText {
                            id: libBtnLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Library"
                            font.family: detailView.fontBody
                            font.pixelSize: 11; font.letterSpacing: 0.3
                            color: detailView._inLibrary
                                ? Colors.on_primary_container : Colors.on_surface_variant
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            if (detailView._inLibrary)
                                Anime.removeFromLibrary(Anime.currentAnime.id)
                            else
                                Anime.addToLibrary(Anime.currentAnime)
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true; height: 34
            color: Colors.surface_container
            visible: Anime.currentAnime !== null

            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }

                StyledText {
                    text: Anime.currentAnime
                        ? (Anime.currentAnime.episodes
                        ? Anime.currentAnime.episodes.length : 0) + " episodes"
                        : ""
                    font.family: detailView.fontBody
                    font.pixelSize: 11; font.letterSpacing: 1
                    color: Colors.on_surface_variant; opacity: 0.75
                }

                Item { Layout.fillWidth: true }

                // Last-watched badge
                Rectangle {
                    readonly property var _entry: Anime.currentAnime
                        ? Anime.getLibraryEntry(Anime.currentAnime.id) : null
                    visible: _entry !== null && _entry !== undefined
                        && _entry.lastWatchedEpNum !== ""
                        && _entry.lastWatchedEpNum !== undefined
                    height: 20; width: lastWatchedText.implicitWidth + 18; radius: 10
                    color: Colors.withAlpha(Colors.primary, 0.12)
                    border.color: Colors.primary; border.width: 1

                    Text {
                        id: lastWatchedText; anchors.centerIn: parent
                        text: {
                            var e = Anime.currentAnime
                                ? Anime.getLibraryEntry(Anime.currentAnime.id) : null
                            return e ? "Last: Ep. " + e.lastWatchedEpNum : ""
                        }
                        font.family: detailView.fontBody
                        font.pixelSize: 9; font.letterSpacing: 0.8; color: Colors.primary
                    }
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: Colors.outline_variant; opacity: 0.3
            }
        }

        Item {
            Layout.fillWidth: true; Layout.fillHeight: true

            Rectangle {
                anchors.fill: parent; color: Colors.background
                visible: Anime.isFetchingDetail; z: 5

                Column {
                    anchors.centerIn: parent; spacing: 14

                    Spinner {
                        width: 28
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "fetching episodes"
                        color: Colors.on_surface_variant
                        font.family: detailView.fontBody
                        font.pixelSize: 11; font.letterSpacing: 2; opacity: 0.7
                    }
                }
            }

            Rectangle {
                anchors.fill: parent; color: Colors.withAlpha(Colors.background, 0.88)
                visible: Anime.isFetchingLinks; z: 6

                Column {
                    anchors.centerIn: parent; spacing: 14

                    Spinner {
                        width: 28
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "fetching stream"
                        color: Colors.on_surface_variant
                        font.family: detailView.fontBody
                        font.pixelSize: 11; font.letterSpacing: 2; opacity: 0.7
                    }
                }
            }

            // Links error toast
            Rectangle {
                id: linksErrorToast
                anchors {
                    bottom: parent.bottom; horizontalCenter: parent.horizontalCenter
                    bottomMargin: 12
                }
                height: 36; radius: 18
                width: linksErrText.implicitWidth + 28
                color: Colors.error_container
                visible: Anime.linksError.length > 0 && !Anime.isFetchingLinks
                z: 7

                Text {
                    id: linksErrText; anchors.centerIn: parent
                    text: Anime.linksError
                    font.family: detailView.fontBody
                    font.pixelSize: 11; color: Colors.on_error_container; elide: Text.ElideRight
                }
            }

            ListView {
                id: epList
                anchors.fill: parent; clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: Anime.currentAnime ? Anime.currentAnime.episodes : []

                ScrollBar.vertical: StyledScrollBar {
                }

                delegate: ClickableRect {
                    id: epRowAreaRect
                    width: epList.width; height: 52

                    readonly property var _libEntry: Anime.currentAnime
                        ? Anime.getLibraryEntry(Anime.currentAnime.id) : null
                    readonly property bool isLastWatched:
                        _libEntry !== null && _libEntry !== undefined
                        && _libEntry.lastWatchedEpNum === String(modelData.number)

                    color: isLastWatched
                        ? Colors.withAlpha(Colors.primary, 0.07)
                        : (epRowAreaRect.pressed
                            ? Colors.surface_container_high
                            : (epRowAreaRect.hovered ? Colors.surface_container : "transparent"))
                    Behavior on color { ColorAnimation { duration: 110 } }

                    Rectangle {
                        anchors {
                            bottom: parent.bottom
                            left: parent.left; right: parent.right
                            leftMargin: 64; rightMargin: 16
                        }
                        height: 1; color: Colors.outline_variant; opacity: 0.22
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                        spacing: 14

                        Rectangle {
                            width: epPillText.implicitWidth + 16; height: 26; radius: 13
                            color: isLastWatched ? Colors.primary : Colors.primary_container

                            StyledText {
                                id: epPillText; anchors.centerIn: parent
                                text: "Ep." + (modelData.number || "?")
                                font.family: detailView.fontBody
                                font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.5
                                color: isLastWatched ? Colors.on_primary : Colors.on_primary_container
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Episode " + (modelData.number || "")
                            font.family: detailView.fontBody
                            font.pixelSize: 12; color: Colors.on_surface; elide: Text.ElideRight
                        }

                        // Play icon
                        StyledText {
                            text: "▶"; font.pixelSize: 13
                            color: epRowAreaRect.hovered ? Colors.primary : Colors.outline
                            opacity: epRowAreaRect.hovered ? 0.9 : 0.35
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                            Behavior on color   { ColorAnimation  { duration: 120 } }
                        }
                    }

                    onClicked: {
                            if (!Anime.currentAnime) return

                            Anime.fetchStreamLinks(
                                Anime.currentAnime.id,
                                modelData.number,
                                "best"
                            )

                            if (Anime.isInLibrary(Anime.currentAnime.id)) {
                                Anime.updateLastWatched(
                                    Anime.currentAnime.id,
                                    modelData.id,
                                    modelData.number
                                )
                            }
                        }
                }
            }
        }
    }

    Connections {
        target: Anime
        function onSelectedLinkChanged() {
            if (!Anime.selectedLink) return
            var lnk = Anime.selectedLink
            if (lnk.error) {
                console.warn("[AnimeDetail] selectedLink has error:", lnk.error)
                Anime.clearStreamLinks()
                return
            }
            if (!lnk.url || lnk.url.length === 0) {
                console.warn("[AnimeDetail] selectedLink has no URL, aborting playback")
                Anime.clearStreamLinks()
                return
            }

            var title = Anime.currentAnime
                ? (Anime.currentAnime.englishName || Anime.currentAnime.name)
                + " — Ep." + Anime.currentEpisode
                : ""
            detailView._playWithMpv(lnk.url, lnk.referer, lnk.subtitle, title)
            Anime.clearStreamLinks()
        }
    }
}
