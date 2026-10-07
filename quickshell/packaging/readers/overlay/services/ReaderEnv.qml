pragma Singleton
import Quickshell

// Where the anime/manga/novel backends live: one venv (made by install.sh)
// for all three servers, and the scripts shipped next to this config.
Singleton {
    readonly property string dataHome: Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share"
    readonly property string python: dataHome + "/qs-novelmangareader/venv/bin/python3"

    readonly property string animePython: python
    readonly property string mangaPython: python
    readonly property string novelPython: python

    readonly property string scripts: Quickshell.shellPath("scripts")
}
