import QtQuick
import qs.colors
import qs.services as Services
import qs.modules.lock
import qs.modules.control

// What's playing: the control centre's section (the art in the theme's
// frame, the track, its progress on the theme's meter, the controls); the
// theme's line for the quiet while nothing is.
PaneSection {
    id: pane

    readonly property bool playing: Services.Media.activePlayer !== null

    titled: !pane.playing
    title: ControlStyle.word("music")
    preferredWidth: 316

    NowPlaying {
        visible: pane.playing
        width: parent.width
    }

    Column {
        visible: !pane.playing
        width: parent.width
        topPadding: 6
        bottomPadding: 6
        spacing: 6

        Glyph {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "music_off"
            font.pixelSize: 26
            color: Colors.withAlpha(ControlStyle.ink, 0.45)
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: ControlStyle.word("musicIdle") || "Nothing playing"
            font.family: ControlStyle.body
            font.pixelSize: 12
            color: Colors.withAlpha(ControlStyle.ink, 0.6)
        }
    }
}
