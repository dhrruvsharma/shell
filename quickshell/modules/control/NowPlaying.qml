pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.services as Services
import qs.modules.lock
import qs.modules.desktopwidgets

// What's playing (services/Media): the art in the theme's frame, the track,
// its progress on the theme's meter (a click seeks) and the controls,
// under the title the theme's music widget wears.
Column {
    id: root

    readonly property var media: Services.Media

    spacing: 12

    function time(s) {
        s = Math.max(0, Math.floor(s || 0));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    SectionTitle {
        width: parent.width
        text: ControlStyle.word("music")

        Text {
            visible: root.media.playerCount > 1
            text: root.media.currentPlayerName
            font.family: ControlStyle.body
            font.pixelSize: 11
            color: Colors.withAlpha(ControlStyle.ink, 0.55)
        }
    }

    Item {
        width: parent.width
        height: art.height + 2 * ControlStyle.artBleed

        WidgetArt {
            id: art
            x: ControlStyle.artBleed
            y: ControlStyle.artBleed
            width: 72
            height: 72
            themeId: ControlStyle.themeId
            source: root.media.artUrl
        }

        Column {
            anchors.left: art.right
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                width: parent.width
                text: root.media.title || "Unknown track"
                elide: Text.ElideRight
                // Broadsheet runs it as a headline.
                font.family: ControlStyle.frame === "clipping" ? ControlStyle.display : ControlStyle.body
                font.pixelSize: ControlStyle.frame === "clipping" ? 17 : 15
                font.weight: ControlStyle.frame === "clipping" ? Font.Black : Font.DemiBold
                color: ControlStyle.ink
            }

            Text {
                width: parent.width
                text: root.media.artist || root.media.currentPlayerName
                elide: Text.ElideRight
                font.family: ControlStyle.body
                font.pixelSize: 12
                font.italic: ["scroll", "lancet", "clipping", "brass", "patta", "banner"].includes(ControlStyle.frame)
                color: Colors.withAlpha(ControlStyle.ink, 0.68)
            }

            Item {
                width: parent.width
                height: 6
            }

            Item {
                width: parent.width
                height: Math.max(12, bar.implicitHeight)

                WidgetBar {
                    id: bar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    themeId: ControlStyle.themeId
                    value: root.media.length > 0 ? root.media.position / root.media.length : 0
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.topMargin: -4
                    anchors.bottomMargin: -4
                    enabled: root.media.length > 0 && (root.media.activePlayer?.canSeek ?? false)
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => root.media.setPosition(root.media.length * Math.max(0, Math.min(1, mouse.x / width)))
                }
            }

            Item {
                width: parent.width
                height: controls.height

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.time(root.media.position) + " / " + root.time(root.media.length)
                    font.family: ControlStyle.mono
                    font.pixelSize: 11
                    color: Colors.withAlpha(ControlStyle.ink, 0.58)
                }

                Row {
                    id: controls
                    anchors.right: parent.right
                    spacing: ControlStyle.frame === "console" ? 6 : 4

                    // A fixed model; the play/pause look is worked out in the
                    // delegate, so pausing doesn't rebuild the buttons.
                    Repeater {
                        model: 3

                        MouseArea {
                            id: button
                            required property int index
                            readonly property bool main: index === 1
                            readonly property var spec: index === 0 ? { icon: "skip_previous", word: "prev", act: () => root.media.previous() }
                                : index === 2 ? { icon: "skip_next", word: "next", act: () => root.media.next() }
                                : { icon: root.media.isPlaying ? "pause" : "play_arrow", word: root.media.isPlaying ? "pause" : "play", act: () => root.media.playPause() }
                            width: ControlStyle.frame === "console" ? label.implicitWidth + 4 : main ? 38 : 30
                            height: 30
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: spec.act()

                            Rectangle {
                                anchors.fill: parent
                                visible: button.main && ControlStyle.frame !== "console"
                                radius: ControlStyle.radius(15)
                                color: Colors.withAlpha(ControlStyle.accent, button.containsMouse ? 0.32 : 0.18)
                            }

                            Glyph {
                                anchors.centerIn: parent
                                visible: ControlStyle.frame !== "console"
                                text: button.spec.icon
                                filled: true
                                font.pixelSize: button.main ? 22 : 20
                                color: button.containsMouse || button.main ? ControlStyle.accent : Colors.withAlpha(ControlStyle.ink, 0.75)
                            }

                            Text {
                                id: label
                                anchors.centerIn: parent
                                visible: ControlStyle.frame === "console"
                                text: "[" + button.spec.word + "]"
                                font.family: ControlStyle.mono
                                font.pixelSize: 13
                                color: button.containsMouse ? ControlStyle.ink : ControlStyle.accent
                            }
                        }
                    }
                }
            }
        }
    }
}
