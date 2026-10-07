pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import qs.colors
import qs.components
import qs.modules.lock
import qs.services
import qs.settings

// The wallpaper picker's settings (the gear in its head): the folder it
// lists, which Wallhaven downloads are saved to as well; the command that
// sets a wallpaper when another program draws it (swww, swaybg, …); and a
// Wallhaven API key. Each field applies on Enter: a folder once it's found
// (or made), a command after a try on the wallpaper on screen, a key after
// Wallhaven is asked whether it knows it.
Rectangle {
    id: card

    property real u: 1
    // The picker's try-on colours.
    property color surface: Colors.surface_container_low
    property color ink: Colors.on_surface
    property color muted: Colors.on_surface_variant
    property color accent: Colors.primary
    property color accentInk: Colors.on_primary
    // Wallpapers listed from the folder now set.
    property int wallpaperCount: 0

    signal closeRequested

    // "", "checking", "missing", "relative", "failed" or "saved"
    property string folderStatus: ""
    property string pendingFolder: ""
    // "", "running", "ok" or "failed"
    property string commandStatus: ""
    property string commandMessage: ""
    // "", "checking", "ok", "rejected" or "unreachable"
    property string keyStatus: ""
    property bool showKey: false

    readonly property bool folderEdited: folderField.text.trim().replace(/\/+$/, "") !== SettingsConfig.wallpaperDir
    readonly property bool commandEdited: commandField.text.trim() !== SettingsConfig.wallpaperCommand
    readonly property bool keyEdited: keyField.text.trim() !== SettingsConfig.wallhavenApiKey

    // Fresh fields each time it opens, the folder's ready to type over.
    function reset() {
        folderField.text = SettingsConfig.wallpaperDir;
        keyField.text = SettingsConfig.wallhavenApiKey;
        commandField.text = SettingsConfig.wallpaperCommand;
        commandStatus = "";
        folderStatus = "";
        keyStatus = "";
        showKey = false;
        folderField.forceActiveFocus();
        folderField.selectAll();
    }

    function applyFolder() {
        const typed = folderField.text.trim().replace(/\/+$/, "");
        if (!typed || typed === SettingsConfig.wallpaperDir) {
            folderField.text = SettingsConfig.wallpaperDir;
            folderStatus = "";
            return;
        }
        const abs = WallpaperEngine.expandHome(typed);
        if (!abs.startsWith("/")) {
            folderStatus = "relative";
            return;
        }
        pendingFolder = typed;
        folderStatus = "checking";
        folderCheck.exec(["test", "-d", abs]);
    }

    function createFolder() {
        folderStatus = "checking";
        folderMake.exec(["mkdir", "-p", WallpaperEngine.expandHome(pendingFolder)]);
    }

    function useFolder() {
        SettingsConfig.wallpaperDir = pendingFolder;
        folderField.text = pendingFolder;
        folderStatus = "saved";
    }

    // Saved, then tried on the wallpaper on screen. Emptied, Quickshell
    // draws the wallpaper again.
    function applyCommand() {
        const cmd = commandField.text.trim();
        SettingsConfig.wallpaperCommand = cmd;
        commandField.text = cmd;
        commandStatus = cmd && WallpaperEngine.current ? "running" : "";
        WallpaperEngine.runCommand(WallpaperEngine.current);
    }

    function applyKey() {
        const key = keyField.text.trim();
        if (key !== SettingsConfig.wallhavenApiKey)
            SettingsConfig.wallhavenApiKey = key;
        keyField.text = key;
        if (!key) {
            keyStatus = "";
            return;
        }
        keyStatus = "checking";
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || keyField.text.trim() !== key)
                return;
            keyStatus = xhr.status === 200 ? "ok" : xhr.status === 401 || xhr.status === 404 ? "rejected" : "unreachable";
        };
        // Wallhaven's account settings answer only to a valid key (an
        // unknown one gets a 404).
        xhr.open("GET", "https://wallhaven.cc/api/v1/settings?apikey=" + encodeURIComponent(key));
        xhr.send();
    }

    width: 460 * u
    height: body.implicitHeight + 40 * u
    radius: DesktopTheme.rad(20) * u
    color: Colors.withAlpha(surface, 0.95)
    border.width: 1
    border.color: Colors.withAlpha(ink, 0.12)

    Connections {
        target: WallpaperEngine
        function onCommandFinished(ok, message) {
            if (card.commandStatus !== "running")
                return;
            card.commandStatus = ok ? "ok" : "failed";
            card.commandMessage = message;
        }
    }

    Process {
        id: folderCheck
        onExited: code => {
            if (code === 0)
                card.useFolder();
            else
                card.folderStatus = "missing";
        }
    }

    Process {
        id: folderMake
        onExited: code => {
            if (code === 0)
                card.useFolder();
            else
                card.folderStatus = "failed";
        }
    }

    // Clicks stay on the card rather than reaching the deck under it.
    MouseArea {
        anchors.fill: parent
        onWheel: wheel => wheel.accepted = true
    }

    component Label: StyledText {
        font.pixelSize: 11 * card.u
        font.weight: Font.Bold
        font.letterSpacing: 1.2 * card.u
        color: card.muted
    }

    component Note: StyledText {
        width: parent.width
        wrapMode: Text.Wrap
        font.pixelSize: 12 * card.u
        color: card.muted
    }

    component Field: StyledTextField {
        width: parent.width
        height: 40 * card.u
        radius: DesktopTheme.rad(12) * card.u
        backgroundColor: Colors.withAlpha(card.ink, 0.06)
        borderColor: Colors.withAlpha(card.ink, 0.12)
        focusBorderColor: card.accent
        color: card.ink
        placeholderTextColor: Colors.withAlpha(card.muted, 0.7)
        selectionColor: Colors.withAlpha(card.accent, 0.4)
        selectedTextColor: card.ink
        font.pixelSize: 13 * card.u
        leftPadding: 14 * card.u
        rightPadding: 14 * card.u
        Keys.onEscapePressed: card.closeRequested()
    }

    component Chip: ClickableRect {
        id: chip

        property string label

        width: chipText.implicitWidth + 22 * card.u
        height: 28 * card.u
        radius: DesktopTheme.rad(14) * card.u
        color: chip.hovered ? Qt.lighter(card.accent, 1.08) : card.accent
        cursorShape: Qt.PointingHandCursor

        StyledText {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            font.pixelSize: 12 * card.u
            font.weight: Font.DemiBold
            color: card.accentInk
        }
    }

    Column {
        id: body

        x: 20 * card.u
        y: 20 * card.u
        width: parent.width - 40 * card.u
        spacing: 8 * card.u

        Item {
            width: parent.width
            height: 32 * card.u

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10 * card.u

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "settings"
                    filled: true
                    font.pixelSize: 20 * card.u
                    color: card.accent
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Picker settings"
                    font.pixelSize: 16 * card.u
                    font.weight: Font.Bold
                    color: card.ink
                }
            }

            ClickableRect {
                id: closeButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 32 * card.u
                height: 32 * card.u
                radius: height / 2
                color: closeButton.hovered ? Colors.withAlpha(card.ink, 0.1) : "transparent"
                cursorShape: Qt.PointingHandCursor
                onClicked: card.closeRequested()

                Glyph {
                    anchors.centerIn: parent
                    text: "close"
                    font.pixelSize: 18 * card.u
                    color: card.ink
                }
            }
        }

        Item {
            width: 1
            height: 4 * card.u
        }

        Label {
            text: "WALLPAPER FOLDER"
        }

        Field {
            id: folderField
            placeholderText: "~/Pictures/wallpapers"
            onAccepted: card.applyFolder()
            onTextEdited: card.folderStatus = ""
            KeyNavigation.tab: commandField
        }

        Note {
            text: card.folderStatus === "checking" ? "Looking for it…"
                : card.folderStatus === "missing" ? "There's no folder there yet."
                : card.folderStatus === "failed" ? "Couldn't create that folder."
                : card.folderStatus === "relative" ? "Use a full path, or one starting with ~/"
                : card.folderEdited ? "Enter to use this folder"
                : (card.wallpaperCount === 1 ? "1 wallpaper" : card.wallpaperCount + " wallpapers") + " here. Wallhaven downloads are saved here too."
            color: card.folderStatus === "missing" || card.folderStatus === "failed" || card.folderStatus === "relative" ? Colors.error : card.muted
        }

        Chip {
            visible: card.folderStatus === "missing"
            label: "Create it and use it"
            onClicked: card.createFolder()
        }

        Item {
            width: 1
            height: 8 * card.u
        }

        Label {
            text: "WALLPAPER COMMAND"
        }

        Field {
            id: commandField
            placeholderText: "Empty: Quickshell draws the wallpaper"
            font.family: "monospace"
            onAccepted: card.applyCommand()
            onTextEdited: card.commandStatus = ""
            KeyNavigation.tab: keyField
        }

        Note {
            text: card.commandStatus === "running" ? "Trying it on the wallpaper on screen…"
                : card.commandStatus === "ok" ? "It worked on the wallpaper on screen."
                : card.commandStatus === "failed" ? "It failed: " + card.commandMessage
                : card.commandEdited ? (commandField.text.trim() ? "Enter to use this command" : "Enter to let Quickshell draw the wallpaper again")
                : SettingsConfig.wallpaperCommand ? "Setting a wallpaper runs this, with {} as the file."
                : "To use your own wallpaper tool, e.g. swww img {} ({} is the file). Empty, Quickshell draws it, with transitions and videos."
            color: card.commandStatus === "failed" ? Colors.error : card.commandStatus === "ok" ? card.accent : card.muted
        }

        Item {
            width: 1
            height: 8 * card.u
        }

        Label {
            text: "WALLHAVEN API KEY"
        }

        Item {
            width: parent.width
            height: keyField.height

            Field {
                id: keyField
                width: parent.width - eye.width - 8 * card.u
                placeholderText: "Optional"
                echoMode: card.showKey ? TextInput.Normal : TextInput.Password
                passwordCharacter: "•"
                onAccepted: card.applyKey()
                onTextEdited: card.keyStatus = ""
                KeyNavigation.tab: folderField
            }

            ClickableRect {
                id: eye
                anchors.right: parent.right
                width: 40 * card.u
                height: 40 * card.u
                radius: DesktopTheme.rad(12) * card.u
                color: eye.hovered ? Colors.withAlpha(card.ink, 0.12) : Colors.withAlpha(card.ink, 0.06)
                cursorShape: Qt.PointingHandCursor
                onClicked: card.showKey = !card.showKey

                Glyph {
                    anchors.centerIn: parent
                    text: card.showKey ? "visibility_off" : "visibility"
                    font.pixelSize: 18 * card.u
                    color: card.ink
                }
            }
        }

        Note {
            text: card.keyStatus === "checking" ? "Asking Wallhaven…"
                : card.keyStatus === "ok" ? "Wallhaven knows this key: NSFW results are available."
                : card.keyStatus === "rejected" ? "Wallhaven doesn't accept this key."
                : card.keyStatus === "unreachable" ? "Saved, but Wallhaven couldn't be reached to check it."
                : card.keyEdited ? (keyField.text.trim() ? "Enter to save the key" : "Enter to remove the key")
                : "Optional. It unlocks NSFW results and your account's filters; find it at wallhaven.cc/settings/account"
            color: card.keyStatus === "ok" ? card.accent : card.keyStatus === "rejected" ? Colors.error : card.muted
        }
    }
}
