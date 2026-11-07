pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.colors
import qs.services as Services
import qs.modules.lock
import qs.modules.control

// What the line shows while the pointer rests on it: the time, the day,
// what's playing, the battery when it's running on it, and how many
// notifications there are; then the screen tools (services/ScreenRecord): a
// screenshot of an area, record (stop, and for how long, while it records)
// and whether the next recording has the system's sound. Along a border
// lying flat, a row; up a standing one, the hour over the minutes and the
// rest as glyphs.
//
// The tools are drawn here and pressed through the line's grip (the view
// asks toolAt() where the pointer is, and says which one it's on: `hot`),
// so the pill keeps the pointer as one piece.
Item {
    id: face

    property bool vertical: false
    property color ink: Colors.on_surface
    property color accent: Colors.primary
    property date now: new Date()
    // The tool under the pointer ("shot", "record", "sound"; "" none).
    property string hot: ""

    readonly property bool playing: Services.Media.activePlayer !== null && Services.Media.isPlaying
    readonly property bool onBattery: Services.Battery.ready && !Services.Battery.charging && !Services.Battery.full
    readonly property int notes: Services.Notification.history.length
    readonly property var rec: Services.ScreenRecord

    // The tool at a point of the face's own, or "".
    function toolAt(x, y) {
        for (const t of face.vertical ? [vShot, vRecord, vSound] : [hShot, hRecord, hSound]) {
            if (!t.visible)
                continue;
            const p = t.mapFromItem(face, x, y);
            if (p.x >= -2 && p.y >= -3 && p.x <= t.width + 2 && p.y <= t.height + 3)
                return t.tool;
        }
        return "";
    }

    // A tool's middle, in the face's own coordinates.
    function toolCentre(name) {
        const t = (face.vertical ? [vShot, vRecord, vSound] : [hShot, hRecord, hSound]).find(x => x.tool === name);
        return t ? t.mapToItem(face, t.width / 2, t.height / 2) : Qt.point(face.width / 2, face.height / 2);
    }

    // What a tool does, said beside the pill while the pointer is on it.
    function hint(tool) {
        const r = face.rec;
        if (tool === "shot")
            return "Screenshot an area";
        if (tool === "record")
            return r.recording ? "Stop recording · " + r.clock : r.starting ? "Starting…" : "Record the screen" + (r.withSound ? ", with its sound" : ", silent");
        if (tool === "sound")
            return r.recording ? (r.current.recording ? (r.soundNow ? "Recording the system's sound" : "Recording without sound") : "Recording")
                : r.withSound ? "System sound: on (click for silent)" : "System sound: off (click to record it)";
        return "";
    }


    implicitWidth: face.vertical ? column.implicitWidth : row.implicitWidth
    implicitHeight: face.vertical ? column.implicitHeight : row.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Row {
        id: row
        visible: !face.vertical
        spacing: 9

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(face.now, "h:mm AP").split(" ")[0]
            font.family: ControlStyle.display
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: face.ink

            Text {
                anchors.left: parent.right
                anchors.leftMargin: 3
                anchors.baseline: parent.baseline
                text: Qt.formatDateTime(face.now, "AP")
                font.family: ControlStyle.body
                font.pixelSize: 9
                font.weight: Font.Bold
                color: Colors.withAlpha(face.ink, 0.6)
            }
        }

        Item {
            width: 16
            height: 1
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: 3
            radius: 1.5
            color: Colors.withAlpha(face.ink, 0.4)
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !face.playing
            text: Qt.formatDateTime(face.now, "ddd d MMM")
            font.family: ControlStyle.body
            font.pixelSize: 12
            color: Colors.withAlpha(face.ink, 0.78)
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            visible: face.playing
            spacing: 5

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: "graphic_eq"
                font.pixelSize: 15
                color: face.accent
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 190)
                elide: Text.ElideRight
                text: Services.Media.title + (Services.Media.artist ? "  ·  " + Services.Media.artist : "")
                font.family: ControlStyle.body
                font.pixelSize: 12
                color: Colors.withAlpha(face.ink, 0.85)
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: 3
            radius: 1.5
            color: Colors.withAlpha(face.ink, 0.4)
            visible: face.onBattery
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            visible: face.onBattery
            spacing: 2

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: EdgeIcons.battery(Services.Battery.percentage, false)
                font.pixelSize: 15
                color: Services.Battery.percentage <= 15 ? Colors.error : Colors.withAlpha(face.ink, 0.8)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Services.Battery.percentage + "%"
                font.family: ControlStyle.mono
                font.pixelSize: 11
                color: Colors.withAlpha(face.ink, 0.8)
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: 3
            radius: 1.5
            color: Colors.withAlpha(face.ink, 0.4)
            visible: face.notes > 0
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            visible: face.notes > 0
            spacing: 2

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: Services.Notification.dnd ? "notifications_off" : "notifications"
                filled: true
                font.pixelSize: 14
                color: Colors.withAlpha(face.ink, 0.8)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: face.notes
                font.family: ControlStyle.mono
                font.pixelSize: 11
                color: Colors.withAlpha(face.ink, 0.8)
            }
        }

        // A VPN up.
        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            visible: Services.Vpn.current !== null
            text: "vpn_lock"
            filled: true
            font.pixelSize: 15
            color: face.accent
        }

        // The screen tools.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 16
            color: Colors.withAlpha(face.ink, 0.22)
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            visible: face.rec.recording
            spacing: 4

            PeekRecDot {
                anchors.verticalCenter: parent.verticalCenter
                running: face.rec.recording && face.visible
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: face.rec.clock
                font.family: ControlStyle.mono
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: Colors.error
            }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            PeekTool {
                id: hShot
                hot: face.hot === "shot"
                ink: face.ink
                tool: "shot"
                glyph: "screenshot_region"
                tint: Colors.withAlpha(face.ink, 0.85)
            }

            PeekTool {
                id: hRecord
                hot: face.hot === "record"
                ink: face.ink
                tool: "record"
                glyph: face.rec.recording ? "stop_circle" : "radio_button_checked"
                lit: face.rec.recording
                tint: face.rec.recording || face.hot === "record" ? Colors.error : Colors.withAlpha(face.ink, 0.85)
                opacity: face.rec.starting ? 0.5 : 1
            }

            PeekTool {
                id: hSound
                hot: face.hot === "sound"
                ink: face.ink
                tool: "sound"
                glyph: (face.rec.recording ? face.rec.soundNow : face.rec.withSound) ? "volume_up" : "volume_off"
                tint: Colors.withAlpha(face.ink, 0.85)
                dim: face.rec.recording
            }
        }
    }


    Column {
        id: column
        visible: face.vertical
        spacing: 3

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(face.now, "hh AP").split(" ")[0]
            font.family: ControlStyle.display
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: face.ink
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(face.now, "mm")
            font.family: ControlStyle.display
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: Colors.withAlpha(face.ink, 0.75)
        }

        Item {
            width: 1
            height: 3
        }

        Glyph {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: face.playing
            text: "graphic_eq"
            font.pixelSize: 16
            color: face.accent
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: face.onBattery
            text: Services.Battery.percentage
            font.family: ControlStyle.mono
            font.pixelSize: 11
            font.weight: Font.Bold
            color: Services.Battery.percentage <= 15 ? Colors.error : Colors.withAlpha(face.ink, 0.8)
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: face.notes > 0
            width: 6
            height: 6
            radius: 3
            color: face.accent
        }

        Glyph {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: Services.Vpn.current !== null
            text: "vpn_lock"
            filled: true
            font.pixelSize: 14
            color: face.accent
        }

        // The screen tools.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 16
            height: 1
            color: Colors.withAlpha(face.ink, 0.22)
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: face.rec.recording
            spacing: 2

            PeekRecDot {
                anchors.horizontalCenter: parent.horizontalCenter
                running: face.rec.recording && face.visible
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: face.rec.clock
                font.family: ControlStyle.mono
                font.pixelSize: 9
                font.weight: Font.DemiBold
                color: Colors.error
            }
        }

        PeekTool {
            id: vShot
            hot: face.hot === "shot"
            ink: face.ink
            anchors.horizontalCenter: parent.horizontalCenter
            tool: "shot"
            glyph: "screenshot_region"
            tint: Colors.withAlpha(face.ink, 0.85)
        }

        PeekTool {
            id: vRecord
            hot: face.hot === "record"
            ink: face.ink
            anchors.horizontalCenter: parent.horizontalCenter
            tool: "record"
            glyph: face.rec.recording ? "stop_circle" : "radio_button_checked"
            lit: face.rec.recording
            tint: face.rec.recording || face.hot === "record" ? Colors.error : Colors.withAlpha(face.ink, 0.85)
            opacity: face.rec.starting ? 0.5 : 1
        }

        PeekTool {
            id: vSound
            hot: face.hot === "sound"
            ink: face.ink
            anchors.horizontalCenter: parent.horizontalCenter
            tool: "sound"
            glyph: (face.rec.recording ? face.rec.soundNow : face.rec.withSound) ? "volume_up" : "volume_off"
            tint: Colors.withAlpha(face.ink, 0.85)
            dim: face.rec.recording
        }
    }
}
