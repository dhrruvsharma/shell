pragma Singleton
import QtQuick
import QtCore

// Plain notepad store. Each note is a single editable blob: { id, text, time }.
// Persisted to a dedicated notepad.conf so it never touches shared settings.
QtObject {
    id: root

    property var notes: []

    property Settings store: Settings {
        location: StandardPaths.standardLocations(StandardPaths.ConfigLocation)[0] + "/quickshell/notepad.conf"
        category: "notepad"
        property string data: "[]"
    }

    function load() {
        try {
            var loaded = JSON.parse(store.data)
            if (Array.isArray(loaded)) {
                notes = loaded.map(function (n) {
                    // Migrate the old { title, body } shape into a single text blob.
                    var text = n.text
                    if (text === undefined) {
                        var title = n.title || ""
                        var body = n.body || ""
                        text = (title && body) ? (title + "\n" + body) : (title || body)
                    }
                    return { id: n.id, text: text || "", time: n.time || Date.now() }
                }).filter(function (n) { return n.text.trim() !== "" })
            } else {
                notes = []
            }
        } catch (e) {
            console.warn("Notepad: failed to load notes:", e)
            notes = []
        }
    }

    function save() {
        store.data = JSON.stringify(notes)
    }

    // Create a note (may be empty, for immediate inline editing) and return its id.
    function add(text) {
        var id = Date.now() + Math.random()
        var next = notes.slice()
        next.unshift({ id: id, text: text || "", time: Date.now() })
        notes = next
        save()
        return id
    }

    function update(id, text) {
        var t = text || ""
        if (t.trim() === "") {
            remove(id)
            return
        }
        var next = notes.slice()
        for (var i = 0; i < next.length; i++) {
            if (next[i].id === id) {
                next[i] = { id: id, text: t, time: Date.now() }
                break
            }
        }
        notes = next
        save()
    }

    // Set a note's text without dropping it when empty (kept until pruneEmpty).
    // Structural position is preserved so the board doesn't need to relayout.
    function setText(id, text) {
        var next = notes.slice()
        for (var i = 0; i < next.length; i++) {
            if (next[i].id === id) {
                next[i] = { id: id, text: text || "", time: Date.now() }
                break
            }
        }
        notes = next
        save()
    }

    function remove(id) {
        var next = []
        for (var i = 0; i < notes.length; i++) {
            if (notes[i].id !== id)
                next.push(notes[i])
        }
        notes = next
        save()
    }

    // Drop notes that were added but never typed into.
    function pruneEmpty() {
        var next = notes.filter(function (n) { return (n.text || "").trim() !== "" })
        if (next.length !== notes.length) {
            notes = next
            save()
        }
    }

    function indexOfId(id) {
        for (var i = 0; i < notes.length; i++) {
            if (notes[i].id === id)
                return i
        }
        return -1
    }

    Component.onCompleted: load()
}
