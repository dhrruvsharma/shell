pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// The applications on this computer, from their desktop entries: Quickshell's
// DesktopEntries index, which parses each entry's Exec line into the command
// to run and follows installs and removals as they happen. Icons are looked
// up in the GTK icon theme (scripts/app-icons.py), so every app list in the
// shell shows the same ones.
//
// launch() starts an app detached from the shell (a reload doesn't take it
// down with it, and an app that's still running doesn't hold up the next),
// in its working directory, and in a terminal when its entry asks for one
// (btop, htop, nvim…). It also counts what's launched, for search().
Singleton {
    id: registry

    // { id, name, genericName, comment, keywords, categories, icon (a file
    // path, or the bare name if the theme hasn't got it), iconName, exec
    // (the command as a shell takes it), command (its words),
    // workingDirectory, terminal, wmClass, desktopId, actions: [{ name,
    // icon, command }] }, by name.
    property var apps: []
    property var classToIcon: ({})
    property var desktopIdToIcon: ({})
    property var nameToIcon: ({})

    signal ready()

    // Entries kept out of the lists (desktop file ids).
    readonly property var hiddenIds: ["xfce4-about", "avahi-discover", "bssh", "bvnc", "qv4l2", "qvidcap", "lstopo", "uuctl", "codium", "xgps", "xgpsspeed"]

    // Runs the apps whose entries ask for a terminal.
    readonly property string terminal: Quickshell.env("TERMINAL") || "kitty"

    function iconForDesktopIcon(icon) {
        if (!icon) return ""

        if (icon.startsWith("file://") || icon.startsWith("qrc:/") || icon.startsWith("image://"))
            return icon

        if (icon.startsWith("/"))
            return "file://" + icon

        return Quickshell.iconPath(icon)
    }

    function iconForClass(id) {
        if (!id) return ""

        const lower = id.toLowerCase()

        if (classToIcon[lower])
            return iconForDesktopIcon(classToIcon[lower])

        if (desktopIdToIcon[lower])
            return iconForDesktopIcon(desktopIdToIcon[lower])

        if (nameToIcon[lower])
            return iconForDesktopIcon(nameToIcon[lower])

        // fuzzy contains match against wmClass map
        for (let key in classToIcon) {
            if (lower.includes(key) || key.includes(lower))
                return iconForDesktopIcon(classToIcon[key])
        }

        // fuzzy against desktop ids
        for (let key in desktopIdToIcon) {
            if (lower.includes(key) || key.includes(lower))
                return iconForDesktopIcon(desktopIdToIcon[key])
        }

        // fuzzy against names
        for (let key in nameToIcon) {
            if (lower.includes(key) || key.includes(lower))
                return iconForDesktopIcon(nameToIcon[key])
        }

        // final fallback to theme resolution
        const resolved = FileUtils.resolveIcon(id)
        return iconForDesktopIcon(resolved)
    }

    // Extra helper: resolve icon using any metadata we might have (Hyprland, Niri, etc.)
    function iconForAppMeta(meta) {
        if (!meta) return Quickshell.iconPath("application-x-executable")

        const candidates = [
            meta.appId,
            meta.class,
            meta.initialClass,
            meta.desktopId,
            meta.title,
            meta.name
        ]

        for (let c of candidates) {
            const icon = iconForClass(c)
            if (icon !== "")
                return icon
        }

        // fallback: try compositor provided icon name
        if (meta.icon)
            return iconForDesktopIcon(meta.icon)

        // hard fallback icons (guaranteed to exist in most themes)
        const fallbacks = [
            "application-x-executable",
            "application-default-icon",
            "window"
        ]

        for (let f of fallbacks) {
            const resolved = Quickshell.iconPath(f)
            if (resolved)
                return resolved
        }

        return ""
    }

    // ── Running apps ─────────────────────────────────────────────────────────

    // Starts `app`, or one of its desktop actions ("New Private Window").
    function launch(app, action) {
        const words = action ? action.command : app ? app.command : null
        if (!words || words.length === 0)
            return false

        Quickshell.execDetached({
            command: app.terminal ? [terminal, "-e"].concat(words) : words,
            workingDirectory: app.workingDirectory || Quickshell.env("HOME")
        })
        _countLaunch(app)
        return true
    }

    // Starts the app whose command `exec` is (as `exec` gave it, the pet's
    // pinned apps keep it), so it gets its terminal; false if no app has it.
    function launchExec(exec) {
        const plain = s => String(s ?? "").trim().replace(/\s+/g, " ")
        const want = plain(exec)
        const app = want ? apps.find(a => plain(a.exec) === want) : null
        return app ? launch(app) : false
    }

    // The command as a shell takes it: each word quoted where it must be.
    function _shellWords(words) {
        return words.map(w => /^[A-Za-z0-9_@%+=:,.\/~-]+$/.test(w) ? w : "'" + w.replace(/'/g, "'\\''") + "'").join(" ")
    }

    // ── Search ───────────────────────────────────────────────────────────────

    // The apps that match `query`, best first: a name that starts with it,
    // then one with a word that does or whose initials spell it ("vlc",
    // "gc" for Google Chrome), then the name containing it, what the app is
    // ("browser"), its keywords, its command ("nvim"), its description,
    // and its letters in order. The apps launched most get a lift. Every
    // word of the query has to match. No query: all of them, by name.
    function search(query) {
        const terms = String(query ?? "").trim().toLowerCase().split(/\s+/).filter(t => t.length > 0)
        if (terms.length === 0)
            return apps

        const scored = []
        for (const app of apps) {
            let total = 0
            for (const t of terms) {
                const s = _score(app, t)
                if (s <= 0) {
                    total = 0
                    break
                }
                total += s
            }
            if (total > 0)
                scored.push({ app: app, score: total + _lift(app) })
        }
        scored.sort((a, b) => b.score - a.score || a.app.name.localeCompare(b.app.name))
        return scored.map(s => s.app)
    }

    function _score(app, t) {
        const name = app._name
        if (name === t)
            return 1000
        if (name.startsWith(t))
            return 900 - name.length
        const word = app._words.findIndex(w => w.startsWith(t))
        if (word > 0)
            return 700 - word * 10
        if (t.length > 1 && app._initials.startsWith(t))
            return 650
        const at = name.indexOf(t)
        if (at > 0)
            return 500 - at
        if (app._generic.includes(t))
            return 400
        if (app._keywords.some(k => k.startsWith(t)))
            return 380
        if (app._exec.includes(t))
            return 300
        if (t.length > 2 && app._comment.includes(t))
            return 200
        return _subsequence(name, t)
    }

    // Letters in order, the closer together the better ("fm" in "EZ File
    // Manager"); 0 when they're spread too thin to mean it.
    function _subsequence(text, t) {
        if (t.length < 2)
            return 0
        let at = -1
        let first = -1
        for (const c of t) {
            at = text.indexOf(c, at + 1)
            if (at < 0)
                return 0
            if (first < 0)
                first = at
        }
        const spread = at - first + 1 - t.length
        return spread > t.length * 3 ? 0 : 120 - spread * 4 - first
    }

    // ── Launch counts (~/.cache/quickshell/appusage.json) ────────────────────

    // How much more an app ranks for being used: by how often, on a log
    // scale, and a little for having been used today.
    function _lift(app) {
        const u = usage.counts[app.id]
        if (!u)
            return 0
        const recent = Date.now() - (usage.last[app.id] ?? 0) < 86400000 ? 25 : 0
        return Math.min(160, 40 * Math.log2(1 + u)) + recent
    }

    function _countLaunch(app) {
        if (!app || !app.id)
            return
        const counts = Object.assign({}, usage.counts)
        const last = Object.assign({}, usage.last)
        counts[app.id] = (counts[app.id] ?? 0) + 1
        last[app.id] = Date.now()
        usage.counts = counts
        usage.last = last
    }

    FileView {
        id: usageFile
        path: Quickshell.env("HOME") + "/.cache/quickshell/appusage.json"
        printErrors: false
        onAdapterUpdated: usageWrite.restart()

        adapter: JsonAdapter {
            id: usage
            property var counts: ({})
            property var last: ({})
        }
    }

    Timer {
        id: usageWrite
        interval: 1000
        onTriggered: usageFile.writeAdapter()
    }

    // ── The index ────────────────────────────────────────────────────────────

    // The index announces every entry of a scan on its own: build the list
    // once they've all come.
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() {
            rescan.restart()
        }
    }

    Timer {
        id: rescan
        interval: 80
        running: true
        onTriggered: registry._scan()
    }

    // Icon paths by Icon= name, as app-icons.py found them ("" = not found).
    property var _icons: ({})
    property bool _scanAgain: false

    function _scan() {
        if (iconLookup.running) {
            _scanAgain = true
            return
        }
        const names = ["application-x-executable"]
        for (const e of DesktopEntries.applications.values) {
            if (e.icon && !(e.icon in _icons) && !names.includes(e.icon))
                names.push(e.icon)
            for (const a of e.actions)
                if (a.icon && !(a.icon in _icons) && !names.includes(a.icon))
                    names.push(a.icon)
        }
        if (names.length === 1 && "application-x-executable" in _icons) {
            _publish()
            return
        }
        iconLookup.names = names
        iconLookup.command = ["python3", Quickshell.shellPath("scripts/app-icons.py")].concat(names)
        iconLookup.running = true
    }

    Process {
        id: iconLookup

        property var names: []

        stdout: StdioCollector {
            onStreamFinished: {
                const icons = Object.assign({}, registry._icons)
                for (const n of iconLookup.names)
                    icons[n] = ""
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t")
                    if (tab > 0)
                        icons[line.slice(0, tab)] = line.slice(tab + 1)
                }
                registry._icons = icons
            }
        }

        onExited: {
            registry._publish()
            if (registry._scanAgain) {
                registry._scanAgain = false
                rescan.restart()
            }
        }
    }

    // An icon to show for Icon= `name`: its file, or the shell's own lookup
    // when the theme hasn't got it, or a generic one.
    function _iconFor(name) {
        if (!name)
            return _icons["application-x-executable"] || "application-x-executable"
        if (_icons[name])
            return _icons[name]
        if (name.startsWith("/") || Quickshell.iconPath(name, true) !== "")
            return name
        return _icons["application-x-executable"] || "application-x-executable"
    }

    function _publish() {
        const list = []
        const classes = {}
        const ids = {}
        const names = {}

        for (const e of DesktopEntries.applications.values) {
            if (hiddenIds.includes(e.id) || !e.name || e.command.length === 0)
                continue

            const icon = _iconFor(e.icon)
            const words = e.name.toLowerCase().split(/[\s\-_.,:;()\[\]\/+·]+/).filter(w => w.length > 0)
            list.push({
                id: e.id,
                name: e.name,
                genericName: e.genericName,
                comment: e.comment,
                keywords: e.keywords,
                categories: e.categories,
                icon: icon,
                iconName: e.icon,
                exec: _shellWords(e.command),
                command: e.command,
                workingDirectory: e.workingDirectory,
                terminal: e.runInTerminal,
                wmClass: e.startupClass,
                desktopId: e.id,
                actions: e.actions.filter(a => a.command.length > 0).map(a => ({
                    name: a.name,
                    icon: a.icon ? _iconFor(a.icon) : "",
                    command: a.command
                })),
                // For search().
                _name: e.name.toLowerCase(),
                _words: words,
                _initials: words.map(w => w[0]).join(""),
                _generic: (e.genericName || "").toLowerCase(),
                _keywords: e.keywords.map(k => k.toLowerCase()),
                _exec: (e.id + " " + e.command.map(w => w.replace(/^.*\//, "")).join(" ")).toLowerCase(),
                _comment: (e.comment || "").toLowerCase()
            })

            if (e.startupClass)
                classes[e.startupClass.toLowerCase()] = icon
            ids[e.id.toLowerCase()] = icon
            names[e.name.toLowerCase()] = icon

            // Hard aliases for apps with messy WM_CLASS values
            if (e.name.toLowerCase().includes("visual studio code") ||
                String(e.icon).toLowerCase().includes("code")) {

                classes["code"] = icon
                classes["code-oss"] = icon
                classes["code-url-handler"] = icon
                ids["code.desktop"] = icon
                ids["code-oss.desktop"] = icon
            }
        }

        list.sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: "base" }))
        // A rescan that changed nothing (the index rescans on any change
        // in the folders it watches) leaves the lists, and what's built on
        // them, alone.
        const key = list.map(a => [a.id, a.name, a.icon, a.exec, a.terminal, a.comment, a.actions.length].join("\u0001")).join("\n")
        if (key === _published)
            return
        _published = key
        classToIcon = classes
        desktopIdToIcon = ids
        nameToIcon = names
        apps = list
        ready()
    }

    property string _published: ""
}
