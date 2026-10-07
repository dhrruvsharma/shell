pragma Singleton
import Quickshell

// Where the anime/manga/novel backends live: the Python each one runs under
// and the folder holding the server scripts. The standalone readers package
// (packaging/readers) ships its own copy of this file pointing at one venv.
Singleton {
    readonly property string home: Quickshell.env("HOME")

    readonly property string animePython: home + "/ani-env/bin/python3"
    readonly property string mangaPython: home + "/.venv/manga/bin/python3"
    readonly property string novelPython: home + "/novel-env/bin/python3"

    readonly property string scripts: Quickshell.shellPath("scripts")
}
