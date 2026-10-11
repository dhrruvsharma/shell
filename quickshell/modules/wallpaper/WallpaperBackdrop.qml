pragma ComponentBehavior: Bound
import QtQuick
import QtMultimedia
import qs.services

// The wallpaper picker's full-screen preview: the card in front, shown at
// the size it would have on the desktop.
//
// Two images take turns: the one on screen (`front`) and the one loading
// or fading in over it (`back`). Only the latest request (`wanted`) is
// ever faded in; a fade in progress is finished before the next load
// starts, so a fading image is never swapped out from under its
// animation (which once left the preview black).
//
// Over the still, the live preview: a video (muted, looping) or an
// animated GIF/WebP playing, `motion` its URL. It fades in once its first
// frame is up, so the still is never swapped for black, and the one
// playing fades out before the next one loads. Loading or unloading a
// player stalls the whole shell for a moment (about a tenth of a second),
// so the picker changes `motion` only while the deck is at rest; while it
// moves, `motionPaused` just pauses the one loaded and fades it out.
Item {
    id: backdrop

    property Image front: imgA
    readonly property Image back: front === imgA ? imgB : imgA
    // The image the running fade is animating.
    property Image fading: null
    property string wanted: ""
    property bool failed: false
    // The latest request is a full-resolution upgrade of what's shown.
    property bool upgrading: false

    readonly property bool loading: back.status === Image.Loading
    readonly property bool ready: front.status === Image.Ready && front.opacity > 0.5
    readonly property real progress: back.progress

    // The live preview's URL ("" for none), and the one loaded (it catches
    // up once the last one has faded out).
    property string motion: ""
    property string playing: ""
    property bool motionPaused: false
    // The live preview as drawn, for a ShaderEffectSource, and how much of
    // it shows over the still (0..1 as it fades).
    readonly property Item motionItem: motionLayer
    readonly property real motionShown: motionLayer.opacity

    onMotionChanged: {
        if (motionLayer.opacity === 0)
            swapMotion();
    }

    // `upgrade`: the same wallpaper at a higher resolution, so no zoom.
    function show(url, upgrade) {
        wanted = url || "";
        failed = false;
        upgrading = !!upgrade;
        if (fadeIn.running) {
            fadeIn.stop();
            settle();
        }
        if (!url) {
            back.source = "";
            front.opacity = 0;
            return;
        }
        if (String(front.source) === url && front.status === Image.Ready)
            return;
        back.opacity = 0;
        back.scale = upgrade ? 1 : 1.035;
        back.z = 2;
        front.z = 1;
        back.source = url;
        if (back.status === Image.Ready)
            reveal();
    }

    function reveal() {
        if (String(back.source) !== wanted || fadeIn.running)
            return;
        fading = back;
        fadeIn.restart();
    }

    // Loads the requested live preview in place of the one loaded (by way
    // of none, so the loader makes a fresh player).
    function swapMotion() {
        if (playing === motion)
            return;
        playing = "";
        if (motion !== "")
            Qt.callLater(() => {
                if (motionLayer.opacity === 0)
                    playing = motion;
            });
    }

    // End state of a fade: the faded-in image becomes the front.
    function settle() {
        if (!fading)
            return;
        fading.opacity = 1;
        fading.scale = 1;
        if (fading !== front) {
            const old = front;
            front = fading;
            old.opacity = 0;
            old.source = "";
        }
        fading = null;
    }

    clip: true

    component Layer: Image {
        id: layer
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.max(1, backdrop.width), Math.max(1, backdrop.height))
        asynchronous: true
        cache: false
        smooth: true
        // Drawn small too: a chosen card's picture (CardPicture) is this.
        mipmap: true
        opacity: 0
        onStatusChanged: {
            if (layer !== backdrop.back || String(source) !== backdrop.wanted)
                return;
            if (status === Image.Ready)
                backdrop.reveal();
            else if (status === Image.Error)
                backdrop.failed = true;
        }
    }

    Layer {
        id: imgA
    }

    Layer {
        id: imgB
    }

    ParallelAnimation {
        id: fadeIn
        NumberAnimation { target: backdrop.fading; property: "opacity"; to: 1; duration: 300; easing.type: Easing.OutCubic }
        NumberAnimation { target: backdrop.fading; property: "scale"; to: 1; duration: 520; easing.type: Easing.OutCubic }
        onFinished: backdrop.settle()
    }

    // ── The live preview ─────────────────────────────────────────────────
    Item {
        id: motionLayer

        // Its first frame is up, and it's still the one wanted.
        readonly property bool up: !!motionLoader.item && motionLoader.item.ready
            && backdrop.playing !== "" && backdrop.playing === backdrop.motion && !backdrop.motionPaused

        anchors.fill: parent
        z: 3
        opacity: up ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        onOpacityChanged: {
            if (opacity === 0 && backdrop.playing !== backdrop.motion)
                backdrop.swapMotion();
        }

        Loader {
            id: motionLoader
            anchors.fill: parent
            sourceComponent: backdrop.playing === "" ? null
                : WallpaperEngine.kind(backdrop.playing) === "video" ? videoMotion : animatedMotion
        }
    }

    // Muted (no audio output at all) and looping.
    Component {
        id: videoMotion

        Item {
            id: movie

            property bool ready: false
            readonly property bool paused: backdrop.motionPaused

            onPausedChanged: paused ? player.pause() : player.play()

            MediaPlayer {
                id: player
                source: backdrop.playing
                loops: MediaPlayer.Infinite
                videoOutput: output
                onErrorOccurred: (error, errorString) => console.warn("wallpaper preview:", errorString)
                Component.onCompleted: {
                    if (!movie.paused)
                        play();
                }
            }

            VideoOutput {
                id: output
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectCrop
            }

            Connections {
                target: output.videoSink

                function onVideoFrameChanged() {
                    movie.ready = true;
                }
            }
        }
    }

    // Frames are decoded as they're shown (cache: false), not all held.
    Component {
        id: animatedMotion

        AnimatedImage {
            readonly property bool ready: status === Image.Ready

            source: backdrop.playing
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            playing: true
            paused: backdrop.motionPaused
        }
    }
}
