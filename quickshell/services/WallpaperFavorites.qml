pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

// Persists the set of favorited local wallpapers (by bare file name) in its own
// small file so it never pollutes settings.json. Mirrors the FileView/JsonAdapter
// pattern used by SettingsConfig.
Singleton {
    id: root

    // Reactive list of favorited wallpaper file names (e.g. "sunset.jpg").
    property alias favorites: favAdapter.favorites

    function has(name) {
        const f = favAdapter.favorites
        for (let i = 0; i < f.length; i++)
            if (f[i] === name)
                return true
        return false
    }

    function toggle(name) {
        if (!name)
            return
        let next = []
        let removed = false
        const cur = favAdapter.favorites
        for (let i = 0; i < cur.length; i++) {
            if (cur[i] === name) {
                removed = true
                continue
            }
            next.push(cur[i])
        }
        if (!removed)
            next.push(name)
        favAdapter.favorites = next
    }

    Timer {
        id: writeTimer
        interval: 100
        repeat: false
        onTriggered: favFile.writeAdapter()
    }

    Timer {
        id: reloadTimer
        interval: 100
        repeat: false
        onTriggered: favFile.reload()
    }

    FileView {
        id: favFile
        path: Quickshell.env("HOME") + "/.cache/quickshell/wallpaper-favorites.json"
        watchChanges: true
        onFileChanged: reloadTimer.restart()
        onAdapterUpdated: writeTimer.restart()
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound)
                writeTimer.restart()
        }

        adapter: JsonAdapter {
            id: favAdapter
            property list<string> favorites: []
        }
    }
}
