import QtQuick

// The pre-lock screenshot of this screen as a texture provider for transition
// shaders (`property variant source: capture.image`). The Image has to stay
// visible to keep providing its texture, so it sits in a zero-size clipped
// host: live, but never drawn itself. Size it to the surface it covers.
Item {
    id: capture

    property url source
    property real imageWidth: 0
    property real imageHeight: 0
    readonly property alias image: img
    readonly property bool ready: img.status === Image.Ready

    width: 0
    height: 0
    clip: true

    Image {
        id: img
        width: capture.imageWidth
        height: capture.imageHeight
        source: capture.source
        asynchronous: false
        cache: false
        smooth: true
    }
}
