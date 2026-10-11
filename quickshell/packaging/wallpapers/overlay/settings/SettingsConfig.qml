pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

// The picker's settings, kept in settings.json next to this config. The
// folder, command, API key and the chosen card's animation are set from the
// picker's gear; the Wallhaven filters from its chips; the live preview
// from its play button.
Singleton {
    id: root

    property alias wallpaperDir: settingsAdapter.wallpaperDir
    property alias wallpaperCommand: settingsAdapter.wallpaperCommand
    property alias wallpaperLivePreview: settingsAdapter.wallpaperLivePreview
    property alias wallpaperAnimateChoice: settingsAdapter.wallpaperAnimateChoice
    property alias wallhavenApiKey: settingsAdapter.wallhavenApiKey
    property alias wallhavenCategories: settingsAdapter.wallhavenCategories
    property alias wallhavenPurity: settingsAdapter.wallhavenPurity
    property alias wallhavenSorting: settingsAdapter.wallhavenSorting
    property alias wallhavenOrder: settingsAdapter.wallhavenOrder
    property alias wallhavenTopRange: settingsAdapter.wallhavenTopRange
    property alias wallhavenAtleast: settingsAdapter.wallhavenAtleast
    property alias wallhavenRatios: settingsAdapter.wallhavenRatios

    Timer {
        id: writeTimer
        interval: 100
        onTriggered: settingsFile.writeAdapter()
    }

    Timer {
        id: reloadTimer
        interval: 100
        onTriggered: settingsFile.reload()
    }

    FileView {
        id: settingsFile
        path: Quickshell.shellPath("settings.json")
        watchChanges: true
        onFileChanged: reloadTimer.restart()
        onAdapterUpdated: writeTimer.restart()
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound)
                writeTimer.restart();
        }

        adapter: JsonAdapter {
            id: settingsAdapter
            property string wallpaperDir: "~/Pictures/wallpapers"
            // "" = Quickshell draws the wallpaper; else e.g. "swww img {}"
            property string wallpaperCommand: ""
            // Videos and animated pictures play in the preview
            property bool wallpaperLivePreview: false
            // The card set grows into the wallpaper (false: set straight
            // away, the deck stays open)
            property bool wallpaperAnimateChoice: true
            property string wallhavenApiKey: ""
            property string wallhavenCategories: "111"
            property string wallhavenPurity: "100"
            property string wallhavenSorting: "toplist"
            property string wallhavenOrder: "desc"
            property string wallhavenTopRange: "1M"
            property string wallhavenAtleast: ""
            property string wallhavenRatios: ""
        }
    }
}
