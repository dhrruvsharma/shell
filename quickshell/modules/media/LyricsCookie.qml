import QtQuick
import qs.colors
import qs.components
import qs.modules.lock
import qs.services as Services

// The Spotify cookie the lyrics are fetched with (see LyricsService), set in
// the lyrics' place: paste it and press Enter, and Spotify is asked whether
// it takes it; once it does, the lyrics come back. Emptied, Enter removes it.
Item {
    id: editor

    signal closeRequested

    readonly property string status: Services.LyricsService.cookieStatus
    readonly property bool edited: field.text.trim() !== Services.LyricsService.spDc
    // A cookie was saved here and Spotify hasn't answered yet
    property bool awaiting: false

    // A fresh field each time it opens, the cookie there selected to paste over.
    function reset() {
        awaiting = false;
        closeTimer.stop();
        field.text = Services.LyricsService.spDc;
        field.forceActiveFocus();
        field.selectAll();
    }

    function save() {
        Services.LyricsService.setCookie(field.text);
        field.text = Services.LyricsService.spDc;
        awaiting = field.text !== "";
    }

    onVisibleChanged: if (visible) reset()

    onStatusChanged: {
        if (!awaiting || status === "checking")
            return;
        awaiting = false;
        if (status === "ok")
            closeTimer.restart();
    }

    // Long enough to read that Spotify took it
    Timer {
        id: closeTimer
        interval: 1500
        onTriggered: editor.closeRequested()
    }

    Column {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 6

        Item {
            width: parent.width
            height: 18

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "SPOTIFY COOKIE (sp_dc)"
                font.pixelSize: 10
                font.weight: Font.Bold
                font.letterSpacing: 1.2
                color: Colors.on_surface_variant
            }

            ClickableRect {
                id: closeButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22
                radius: height / 2
                color: closeButton.hovered ? Colors.surface_container_highest : "transparent"
                cursorShape: Qt.PointingHandCursor
                onClicked: editor.closeRequested()

                Glyph {
                    anchors.centerIn: parent
                    text: "close"
                    font.pixelSize: 15
                    color: Colors.on_surface_variant
                }
            }
        }

        StyledTextField {
            id: field
            width: parent.width
            height: 32
            radius: Services.DesktopTheme.rad(8)
            backgroundColor: Colors.surface_container_highest
            focusBorderColor: Colors.primary
            echoMode: TextInput.Password
            passwordCharacter: "•"
            placeholderText: "Paste it here"
            font.pixelSize: 12
            leftPadding: 10
            rightPadding: 10
            selectionColor: Colors.withAlpha(Colors.primary, 0.4)
            selectedTextColor: Colors.on_surface
            onAccepted: editor.save()
            onTextEdited: {
                editor.awaiting = false;
                closeTimer.stop();
            }
            Keys.onEscapePressed: editor.closeRequested()
        }

        StyledText {
            width: parent.width
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font.pixelSize: 11
            text: editor.edited ? (field.text.trim() ? "Enter to save it" : "Enter to remove it")
                : editor.status === "checking" ? "Asking Spotify…"
                : editor.status === "ok" ? "Spotify takes it: lyrics are on."
                : editor.status === "refused" ? "Spotify refused it (lyrics come from LRCLIB meanwhile). Copy it again, whole, from a logged-in open.spotify.com."
                : editor.status === "unreachable" ? "Saved, but Spotify couldn't be reached to check it."
                : editor.status === "nogo" ? "Saved, but the lyrics need Go to run: sudo pacman -S go"
                : Services.LyricsService.spDc ? "Saved. Lyrics show while Spotify plays."
                : "Optional: lyrics come from LRCLIB without it. For Spotify's, log in at open.spotify.com and copy the sp_dc cookie from the browser's dev tools (Application → Cookies)."
            color: editor.edited ? Colors.on_surface_variant
                : editor.status === "refused" || editor.status === "nogo" ? Colors.error
                : editor.status === "ok" ? Colors.primary
                : Colors.on_surface_variant
        }
    }
}
