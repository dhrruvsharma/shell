pragma ComponentBehavior: Bound
import QtQuick
import qs.services as Services
import qs.components
import qs.modules.lock

// "BGM" panel: what's playing, with previous / play-pause / next and a small
// GPU visualizer. Hidden when no MPRIS player is around.
HudPanel {
    id: media

    property real sc: 1
    readonly property bool playing: Services.Media.isPlaying

    visible: Services.Media.activePlayer !== null
    implicitWidth: 400 * sc
    implicitHeight: 104 * sc
    cut: 12 * sc

    // Only ever forces cava on, so it can't fight other consumers.
    Binding {
        target: Services.Cava
        property: "running"
        value: true
        when: media.visible && media.playing
    }

    component Control: Glyph {
        id: control

        property bool available: true
        signal activated

        font.pixelSize: 22 * media.sc
        filled: true
        opacity: available ? 1 : 0.35
        color: area.containsMouse && available ? LockTheme.accent : LockTheme.ink
        scale: area.pressed ? 0.85 : 1

        MouseArea {
            id: area
            anchors.fill: parent
            anchors.margins: -6 * media.sc
            hoverEnabled: true
            enabled: control.available
            cursorShape: Qt.PointingHandCursor
            onClicked: control.activated()
        }
    }

    Item {
        id: art
        x: 14 * media.sc
        anchors.verticalCenter: parent.verticalCenter
        width: 76 * media.sc
        height: width

        Rectangle {
            anchors.fill: parent
            color: LockTheme.panelHi
        }

        Glyph {
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            text: "music_note"
            filled: true
            font.pixelSize: 34 * media.sc
            color: LockTheme.inkDim
        }

        Image {
            id: cover
            anchors.fill: parent
            source: Services.Media.artUrl
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: LockTheme.line
        }
    }

    Column {
        anchors.left: art.right
        anchors.leftMargin: 14 * media.sc
        anchors.right: parent.right
        anchors.rightMargin: 16 * media.sc
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3 * media.sc

        Text {
            text: media.playing ? "NOW PLAYING" : "PAUSED"
            font.family: LockTheme.mono
            font.pixelSize: 10 * media.sc
            font.weight: Font.Bold
            font.letterSpacing: 3 * media.sc
            color: LockTheme.accent
        }

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: Services.Media.title || "Unknown track"
            font.family: LockTheme.mono
            font.pixelSize: 14 * media.sc
            font.weight: Font.Bold
            color: LockTheme.ink
        }

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: Services.Media.artist
            visible: text.length > 0
            font.family: LockTheme.mono
            font.pixelSize: 12 * media.sc
            color: LockTheme.inkDim
        }

        Item {
            width: parent.width
            height: 26 * media.sc

            Row {
                id: controls
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10 * media.sc

                Control {
                    text: "skip_previous"
                    available: Services.Media.activePlayer?.canGoPrevious ?? false
                    onActivated: Services.Media.previous()
                }

                Control {
                    text: media.playing ? "pause" : "play_arrow"
                    available: Services.Media.activePlayer?.canTogglePlaying ?? false
                    onActivated: Services.Media.playPause()
                }

                Control {
                    text: "skip_next"
                    available: Services.Media.activePlayer?.canGoNext ?? false
                    onActivated: Services.Media.next()
                }
            }

            CavaShader {
                anchors.left: controls.right
                anchors.leftMargin: 14 * media.sc
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 20 * media.sc
                visible: media.playing
                accentColor: LockTheme.accent
                gapPx: 2
            }
        }
    }
}
