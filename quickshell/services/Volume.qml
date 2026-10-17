pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.services as Services

Singleton {
    id: root

    PwObjectTracker {
        objects: [
            Pipewire.defaultAudioSource,
            Pipewire.defaultAudioSink,
            Pipewire.nodes,
            Pipewire.links
        ]
    }

    property var sinks: Pipewire.nodes.values.filter(node => node.isSink && !node.isStream && node.audio)
    property PwNode defaultSink: Pipewire.defaultAudioSink

    property var sources: Pipewire.nodes.values.filter(node => !node.isSink && !node.isStream && node.audio)
    property PwNode defaultSource: Pipewire.defaultAudioSource

    property real volume: (defaultSink?.audio?.volume > 1 ? 1 : defaultSink?.audio?.volume) ?? 0
    property bool muted: defaultSink?.audio?.muted ?? false

    // The OSD stays quiet while the shell starts: the default output and its
    // level only arrive then.
    property bool _armed: false

    Timer {
        running: true
        interval: 2500
        onTriggered: root._armed = true
    }

    Connections {
        id: audioConn
        target: root.defaultSink && root.defaultSink.audio ? root.defaultSink.audio : null

        function onVolumeChanged() {
            root.report();
        }

        function onMutedChanged() {
            root.report();
        }
    }

    // A new output (headphones plugged in, buds connected, a pick in the
    // control center) shows its name and level once it has settled.
    onDefaultSinkChanged: if (_armed) sinkSettle.restart()

    Timer {
        id: sinkSettle
        interval: 400
        onTriggered: root.report()
    }

    // The output's own level for the OSD, past 100% too (the keys can push
    // it there; `volume` above stops at 1 for the sliders). Muted, it keeps
    // the level and the OSD shows it muted.
    function report(): void {
        if (_armed && defaultSink?.audio)
            Services.Osd.show("volume", defaultSink.audio.volume * 100);
    }

    function setVolume(to: real): void {
        if (defaultSink?.ready && defaultSink?.audio) {
            defaultSink.audio.muted = false;
            let val = Math.max(0, Math.min(1, to));
            defaultSink.audio.volume = val
            Services.Osd.show("volume", val * 100)
        }
    }

    function setSourceVolume(to: real): void {
        if (defaultSource?.ready && defaultSource?.audio) {
            defaultSource.audio.muted = false;
            let val = Math.max(0, Math.min(1, to));
            defaultSource.audio.volume = val
        }
    }

    function setDefaultSink(sink: PwNode): void {
        Pipewire.preferredDefaultAudioSink = sink;
        // (and through pulse, which streams already playing follow)
        if (sink?.name)
            Quickshell.execDetached(["pactl", "set-default-sink", sink.name]);
    }

    function toggleMute(): void {
        if (defaultSink?.ready && defaultSink?.audio)
            defaultSink.audio.muted = !defaultSink.audio.muted;
    }

    function setDefaultSource(source: PwNode): void {
        Pipewire.preferredDefaultAudioSource = source;
    }

    function init() {
    }
}
