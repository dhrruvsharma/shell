pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.modules.lock
import qs.services as Services

// Desktop music player: artwork, track, progress and controls for the active
// MPRIS player (services/Media), in the look of the desktop theme.
WidgetFrame {
    id: root

    readonly property var media: Services.Media
    readonly property bool has: media.activePlayer !== null

    function time(s) {
        s = Math.max(0, Math.floor(s || 0));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    themeId: Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""
    title: WidgetStyle.word("music", themeId)
    seal: "琴"

    Row {
        spacing: 16

        WidgetArt {
            anchors.verticalCenter: parent.verticalCenter
            themeId: root.themeId
            source: root.has ? root.media.artUrl : ""
        }

        Column {
            width: 250
            spacing: 5

            Text {
                width: parent.width
                text: root.has ? root.media.title : WidgetStyle.word("musicIdle", root.themeId)
                elide: Text.ElideRight
                font.family: root.st.font
                font.pixelSize: 15
                font.weight: root.st.frame === "bare" ? Font.Normal : Font.DemiBold
                color: Colors.on_surface
            }

            Text {
                width: parent.width
                visible: root.has
                text: root.media.artist || root.media.currentPlayerName
                elide: Text.ElideRight
                font.family: root.st.font
                font.pixelSize: 12
                font.italic: root.st.frame === "scroll"
                color: Colors.withAlpha(Colors.on_surface, 0.7)
            }

            Item {
                width: 1
                height: 4
            }

            WidgetBar {
                width: parent.width
                themeId: root.themeId
                value: root.media.length > 0 ? root.media.position / root.media.length : 0
                opacity: root.has ? 1 : 0.4
            }

            Item {
                width: parent.width
                height: controls.height

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.has ? root.time(root.media.position) + " / " + root.time(root.media.length) : "--:--"
                    font.family: root.st.mono
                    font.pixelSize: 11
                    color: Colors.withAlpha(Colors.on_surface, 0.6)
                }

                Row {
                    id: controls
                    anchors.right: parent.right
                    spacing: root.st.frame === "console" ? 6 : 2

                    Repeater {
                        model: [
                            { icon: "skip_previous", word: "prev", act: () => root.media.previous() },
                            { icon: root.media.isPlaying ? "pause" : "play_arrow", word: root.media.isPlaying ? "pause" : "play", act: () => root.media.playPause() },
                            { icon: "skip_next", word: "next", act: () => root.media.next() }
                        ]

                        MouseArea {
                            id: button
                            required property var modelData
                            required property int index
                            readonly property bool main: index === 1
                            width: root.st.frame === "console" ? label.implicitWidth + 4 : main ? 34 : 28
                            height: 28
                            enabled: root.has
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modelData.act()

                            Rectangle {
                                anchors.fill: parent
                                visible: button.main && root.st.frame !== "console" && root.st.frame !== "bare"
                                radius: root.st.frame === "chamfer" ? 0 : root.st.frame === "scroll" ? 4 : height / 2
                                color: Colors.withAlpha(Colors[root.st.accentRole], button.containsMouse ? 0.35 : 0.2)
                            }

                            Glyph {
                                anchors.centerIn: parent
                                visible: root.st.frame !== "console"
                                text: button.modelData.icon
                                filled: true
                                font.pixelSize: button.main ? 22 : 20
                                color: button.containsMouse || button.main ? Colors[root.st.accentRole] : Colors.withAlpha(Colors.on_surface, 0.75)
                            }

                            Text {
                                id: label
                                anchors.centerIn: parent
                                visible: root.st.frame === "console"
                                text: "[" + button.modelData.word + "]"
                                font.family: root.st.mono
                                font.pixelSize: 13
                                color: button.containsMouse ? Colors.on_surface : Colors[root.st.accentRole]
                            }
                        }
                    }
                }
            }
        }
    }
}
