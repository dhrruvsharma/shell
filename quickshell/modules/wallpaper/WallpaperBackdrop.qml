pragma ComponentBehavior: Bound
import QtQuick

// The wallpaper picker's full-screen preview: the card in front, shown at
// the size it would have on the desktop.
//
// Two images take turns: the one on screen (`front`) and the one loading
// or fading in over it (`back`). Only the latest request (`wanted`) is
// ever faded in; a fade in progress is finished before the next load
// starts, so a fading image is never swapped out from under its
// animation (which once left the preview black).
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
}
