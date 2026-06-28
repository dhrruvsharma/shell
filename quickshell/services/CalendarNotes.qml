pragma Singleton
import QtQuick
import QtCore

QtObject {
    id: root

    // Map of "YYYY-MM-DD" -> [ { id, text, time, repeat: "none"|"yearly" }, ... ]
    property var notesByDate: ({})

    property Settings store: Settings {
        location: StandardPaths.standardLocations(StandardPaths.ConfigLocation)[0] + "/quickshell/calendar_notes.conf"
        category: "calendar"
        property string data: "{}"
    }

    function load() {
        try {
            notesByDate = JSON.parse(store.data) || ({})
        } catch (e) {
            console.warn("Failed to load calendar notes:", e)
            notesByDate = ({})
        }
    }

    function save() {
        store.data = JSON.stringify(notesByDate)
    }

    function pad(n) {
        return n < 10 ? "0" + n : "" + n
    }

    function dateKey(d) {
        return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
    }

    // Notes that apply to `key`: the ones stored on that exact date, plus any
    // yearly-recurring notes from other years sharing the same month/day.
    function notesFor(key) {
        var nb = notesByDate
        var md = key.substring(5)            // "MM-DD"
        var result = []

        if (nb[key]) {
            for (var i = 0; i < nb[key].length; i++)
                result.push(nb[key][i])
        }

        for (var k in nb) {
            if (k === key) continue
            if (k.substring(5) !== md) continue
            var arr = nb[k]
            for (var j = 0; j < arr.length; j++) {
                if (arr[j].repeat === "yearly")
                    result.push(arr[j])
            }
        }

        result.sort(function (a, b) { return a.time - b.time })
        return result
    }

    function countFor(key) {
        return notesFor(key).length
    }

    function add(key, text, recurring) {
        if (!text || text.trim() === "") return
        var copy = JSON.parse(JSON.stringify(notesByDate))
        if (!copy[key]) copy[key] = []
        copy[key].push({
            id: Date.now() + Math.random(),
            text: text.trim(),
            time: Date.now(),
            repeat: recurring ? "yearly" : "none"
        })
        notesByDate = copy
        save()
    }

    // ids are globally unique, so a note can be found without knowing its date.
    function remove(id) {
        var copy = JSON.parse(JSON.stringify(notesByDate))
        for (var k in copy) {
            var arr = copy[k]
            for (var i = 0; i < arr.length; i++) {
                if (arr[i].id === id) {
                    arr.splice(i, 1)
                    if (arr.length === 0) delete copy[k]
                    notesByDate = copy
                    save()
                    return
                }
            }
        }
    }

    function toggleRepeat(id) {
        var copy = JSON.parse(JSON.stringify(notesByDate))
        for (var k in copy) {
            var arr = copy[k]
            for (var i = 0; i < arr.length; i++) {
                if (arr[i].id === id) {
                    arr[i].repeat = (arr[i].repeat === "yearly") ? "none" : "yearly"
                    notesByDate = copy
                    save()
                    return
                }
            }
        }
    }

    Component.onCompleted: load()
}
