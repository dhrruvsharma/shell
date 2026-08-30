import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.services as Services
import qs.colors
import Qt5Compat.GraphicalEffects
import qs.components
import Quickshell.Io

Item {
    id: mediaControl
    property bool opened: true

    width: 400
    height: 120

    Behavior on y {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    Behavior on opacity {
        NumberAnimation { duration: 180 }
    }

    Process {
        id: toggleVisProc
        command: ["qs", "ipc", "call", "visBottom", "toggle"]
    }

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: Colors.background

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                Rectangle {
                    width: 72
                    height: 72
                    radius: 12
                    color: Colors.surface_container_highest
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: Services.Media.artUrl
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        asynchronous: true
                        cache: true

                        Rectangle {
                            anchors.fill: parent
                            visible: parent.status !== Image.Ready
                            color: Colors.surface_container_highest

                            StyledText {
                                anchors.centerIn: parent
                                text: "🎵"
                                font.pixelSize: 32
                                color: Colors.on_surface_variant
                            }
                        }
                    }
                }

                // Track Info
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    StyledText {
                        text: Services.Media.title || "No media playing"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    StyledText {
                        text: Services.Media.artist || "Unknown artist"
                        color: Colors.on_surface_variant
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Button {
                        id: visToggleBtn
                        implicitWidth: 28
                        implicitHeight: 20
                        hoverEnabled: true

                        onClicked: toggleVisProc.running = true

                        background: Rectangle {
                            radius: 4
                            color: visToggleBtn.hovered
                                ? Colors.surface_container_highest
                                : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }

                        contentItem: StyledText {
                            text: "♪"
                            font.pixelSize: 12
                            color: Colors.on_surface_variant
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Item { Layout.fillHeight: true }
                }

                RowLayout {
                    spacing: 4

                    Repeater {
                        model: [
                            { icon: "⏮", action: function() { Services.Media.previous() } },
                            { icon: Services.Media.isPlaying ? "⏸" : "▶", action: function() { Services.Media.playPause() } },
                            { icon: "⏭", action: function() { Services.Media.next() } }
                        ]

                        Button {
                            text: modelData.icon
                            onClicked: modelData.action()

                            implicitWidth: index === 1 ? 44 : 40
                            implicitHeight: index === 1 ? 44 : 40

                            hoverEnabled: true

                            background: Rectangle {
                                radius: parent.width / 2
                                color: index === 1
                                    ? (parent.hovered ? Colors.primary_container : Colors.primary)
                                    : (parent.hovered ? Colors.surface_container_highest : "transparent")

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }

                            contentItem: StyledText {
                                text: parent.text
                                font.pixelSize: index === 1 ? 18 : 16
                                color: index === 1
                                    ? Colors.on_primary
                                    : Colors.on_surface
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: Services.Media.playerCount > 1
                spacing: 4

                Button {
                    implicitWidth: 24
                    implicitHeight: 24
                    hoverEnabled: true
                    onClicked: Services.Media.previousPlayer()

                    background: Rectangle {
                        radius: 4
                        color: parent.hovered ? Colors.surface_container_highest : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    contentItem: StyledText {
                        text: "‹"
                        font.pixelSize: 16
                        color: Colors.on_surface_variant
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Services.Media.currentPlayerName
                    color: Colors.on_surface_variant
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }

                Button {
                    implicitWidth: 24
                    implicitHeight: 24
                    hoverEnabled: true
                    onClicked: Services.Media.nextPlayer()

                    background: Rectangle {
                        radius: 4
                        color: parent.hovered ? Colors.surface_container_highest : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    contentItem: StyledText {
                        text: "›"
                        font.pixelSize: 16
                        color: Colors.on_surface_variant
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Slider {
                    id: progressSlider
                    from: 0
                    to: Services.Media.length
                    value: Services.Media.position
                    Layout.fillWidth: true

                    onMoved: Services.Media.setPosition(value)

                    background: Rectangle {
                        x: progressSlider.leftPadding
                        y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                        implicitWidth: 200
                        implicitHeight: 4
                        width: progressSlider.availableWidth
                        height: implicitHeight
                        radius: 2
                        color: Colors.surface_container_highest

                        Rectangle {
                            width: progressSlider.visualPosition * parent.width
                            height: parent.height
                            color: Colors.primary
                            radius: 2
                        }
                    }

                    handle: Rectangle {
                        x: progressSlider.leftPadding + progressSlider.visualPosition * (progressSlider.availableWidth - width)
                        y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                        implicitWidth: 12
                        implicitHeight: 12
                        radius: 6
                        color: progressSlider.pressed ? Colors.primary_fixed : Colors.primary
                        border.color: Colors.primary_container
                        border.width: 1
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        text: formatTime(Services.Media.position)
                        color: Colors.on_surface_variant
                        font.pixelSize: 11
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        text: formatTime(Services.Media.length)
                        color: Colors.on_surface_variant
                        font.pixelSize: 11
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                radius: 10
                color: "transparent"
                visible: mediaControl.isSpotify

                Behavior on Layout.preferredHeight {
                    NumberAnimation { duration: 200 }
                }

                CavaBars {
                    anchors.fill: parent
                    anchors.margins: 5
                    opacity: 0.3
                    enableShadow: false
                    barCount: 25
                    clip: true
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    Repeater {
                        id: lyricsRepeater
                        model: lyricsModel

                        StyledText {
                            text: modelData.text
                            color: modelData.isCurrent
                                ? Colors.on_surface
                                : Colors.on_surface_variant
                            font.pixelSize: modelData.isCurrent ? 14 : 12
                            font.weight: modelData.isCurrent ? Font.DemiBold : Font.Normal
                            opacity: modelData.isCurrent ? 1.0 : 0.5
                            Layout.fillWidth: true
                            Layout.maximumWidth: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            lineHeight: 1.1

                            Behavior on opacity {
                                NumberAnimation { duration: 200 }
                            }

                            Behavior on font.pixelSize {
                                NumberAnimation { duration: 200 }
                            }

                            Behavior on color {
                                ColorAnimation { duration: 200 }
                            }
                        }
                    }
                }
            }
        }
    }

    property bool isSpotify: Services.Media.currentPlayerName.toLowerCase().indexOf("spotify") !== -1
    property var lyricsModel: []
    property int _lastPosition: -1

    Connections {
        target: Services.Media
        function onPositionChanged() {
            updateLyricsModel()
        }
    }

    Connections {
        target: Services.LyricsService
        function onLoadedChanged() {
            updateLyricsModel()
        }
        function onLinesChanged() {
            updateLyricsModel()
        }
    }

    Component.onCompleted: {
        updateLyricsModel()
    }

    function updateLyricsModel() {
        let currentPos = Math.floor(Services.Media.position)

        if (Math.abs(currentPos - _lastPosition) < 1 && lyricsModel.length > 0) {
            return
        }

        _lastPosition = currentPos

        if (!Services.LyricsService.loaded) {
            lyricsModel = [{ text: "Loading lyrics...", isCurrent: true }]
            return
        }

        let lines = Services.LyricsService.lines
        if (!lines || lines.length === 0) {
            lyricsModel = [{ text: "♪ No lyrics available ♪", isCurrent: true }]
            return
        }

        let posMs = Services.Media.position * 1000
        let currentIndex = -1

        for (let i = lines.length - 1; i >= 0; i--) {
            if (posMs >= parseInt(lines[i].startTimeMs)) {
                currentIndex = i
                break
            }
        }

        if (currentIndex === -1) {
            lyricsModel = [{ text: "♪", isCurrent: true }]
            return
        }

        let result = []

        if (currentIndex > 0 && lines[currentIndex - 1].words) {
            result.push({ text: lines[currentIndex - 1].words, isCurrent: false })
        }

        if (lines[currentIndex].words) {
            result.push({ text: lines[currentIndex].words, isCurrent: true })
        } else {
            result.push({ text: "♪", isCurrent: true })
        }

        if (currentIndex < lines.length - 1 && lines[currentIndex + 1].words) {
            result.push({ text: lines[currentIndex + 1].words, isCurrent: false })
        }

        lyricsModel = result
    }

    function formatTime(seconds) {
        if (!seconds || seconds < 0) return "0:00"
        var mins = Math.floor(seconds / 60)
        var secs = Math.floor(seconds % 60)
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }
}