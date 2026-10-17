pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.services as Services
import qs.modules.lock

// The levels: the output's volume (its glyph mutes, its chevron opens the
// outputs to choose from), the screen's brightness, and the night light's
// warmth while it's on.
Column {
    id: root

    spacing: 10

    property bool outputsOpen: false

    readonly property var sink: Services.Volume.defaultSink
    readonly property bool muted: Services.Volume.muted
    readonly property real volume: Services.Volume.volume

    // Outputs by their own names, less what they all share ("700 Series
    // Chipset Family HD Audio Speaker" -> "Speaker").
    readonly property var sinks: Services.Volume.sinks
    readonly property string sharedPrefix: {
        const names = sinks.map(s => s.description || s.nickname || s.name || "");
        if (names.length < 2)
            return "";
        let words = names[0].split(" ");
        for (const n of names.slice(1)) {
            const w = n.split(" ");
            let i = 0;
            while (i < words.length && i < w.length - 1 && words[i] === w[i])
                i++;
            words = words.slice(0, i);
        }
        return words.length > 0 ? words.join(" ") + " " : "";
    }

    function shortName(node) {
        const full = node?.description || node?.nickname || node?.name || "Output";
        const name = sharedPrefix && full.startsWith(sharedPrefix) ? full.slice(sharedPrefix.length) : full;
        return name.replace(/\s*\((Stereo|Mono)\)$/, "").replace(/\s+Output$/, "");
    }

    function glyphFor(node) {
        const s = ((node?.description ?? "") + " " + (node?.name ?? "")).toLowerCase();
        if (s.includes("bluez") || s.includes("head") || s.includes("buds") || s.includes("pods"))
            return "headphones";
        if (s.includes("hdmi") || s.includes("displayport"))
            return "tv";
        if (s.includes("usb"))
            return "usb";
        return "speaker";
    }

    LevelSlider {
        width: parent.width
        icon: root.muted ? "volume_off" : root.volume < 0.01 ? "volume_mute" : root.volume < 0.5 ? "volume_down" : "volume_up"
        value: root.volume
        dim: root.muted
        figure: root.muted ? "muted" : Math.round(root.volume * 100) + "%"
        iconButton: true
        detail: root.sinks.length > 1
        detailOpen: root.outputsOpen
        onMoved: v => Services.Volume.setVolume(v)
        onIconClicked: Services.Volume.toggleMute()
        onDetailClicked: root.outputsOpen = !root.outputsOpen
    }

    // The outputs.
    Item {
        width: parent.width
        height: root.outputsOpen ? outputs.implicitHeight : 0
        visible: height > 0
        clip: true

        Behavior on height {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        Column {
            id: outputs
            width: parent.width
            topPadding: 2
            bottomPadding: 2
            spacing: 4

            Repeater {
                model: root.sinks

                MouseArea {
                    id: row
                    required property var modelData
                    readonly property bool current: modelData === root.sink
                    width: outputs.width
                    height: 38
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!current)
                            Services.Volume.setDefaultSink(modelData);
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 18
                        radius: ControlStyle.radius(10)
                        color: row.current ? Colors.withAlpha(ControlStyle.accent, 0.14) : row.containsMouse ? ControlStyle.well : "transparent"
                    }

                    Glyph {
                        x: 30
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.glyphFor(row.modelData)
                        filled: row.current
                        font.pixelSize: 18
                        color: row.current ? ControlStyle.accent : Colors.withAlpha(ControlStyle.ink, 0.7)
                    }

                    Text {
                        x: 60
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x - 40
                        text: root.shortName(row.modelData)
                        elide: Text.ElideRight
                        font.family: ControlStyle.body
                        font.pixelSize: 13
                        font.weight: row.current ? Font.DemiBold : Font.Normal
                        color: row.current ? ControlStyle.ink : Colors.withAlpha(ControlStyle.ink, 0.78)
                    }

                    Glyph {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.current
                        text: "check"
                        font.pixelSize: 18
                        color: ControlStyle.accent
                    }
                }
            }
        }
    }

    LevelSlider {
        width: parent.width
        icon: Services.System.brightness < 34 ? "brightness_low" : Services.System.brightness < 67 ? "brightness_medium" : "brightness_high"
        value: Services.System.brightness / 100
        figure: Services.System.brightness + "%"
        // (below 1% the backlight goes dark)
        onMoved: v => Services.System.setBrightness(Math.max(1, Math.round(v * 100)))
    }

    // Warmth: further right is warmer.
    LevelSlider {
        readonly property var light: Services.NightLight
        visible: light.available && light.enabled
        width: parent.width
        icon: "thermostat"
        value: (light.coolest - light.temperature) / (light.coolest - light.warmest)
        figure: light.temperature + "K"
        onMoved: v => light.setTemperature(light.coolest - v * (light.coolest - light.warmest))
    }
}
