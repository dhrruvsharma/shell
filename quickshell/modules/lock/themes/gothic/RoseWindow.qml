import QtQuick
import Quickshell

// A rose window (shaders/rose.frag), glazed in the wallpaper's colours:
// the Cathedral's mark. The clock lights its lancets through the hours and
// its roundels through the five-minute marks; the "Rose Window" lock lights
// them keystroke by keystroke, cracks one for each rejected passcode, and
// floods it with light on the way in.
Item {
    id: rose

    property real lit: 12
    property real litInner: 12
    property real glow: 1
    property real bloom: 0
    // How much of each pane's colour comes from the wallpaper.
    property real wallMix: 0.6
    property vector4d cracks: Qt.vector4d(-1, -1, -1, -1)

    Item {
        width: 0
        height: 0
        clip: true

        Image {
            id: wall
            width: 256
            height: 256
            source: "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
            sourceSize: Qt.size(256, 256)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }
    }

    ShaderEffect {
        anchors.fill: parent
        visible: wall.status === Image.Ready

        property variant wall: wall
        property real itemWidth: width
        property real itemHeight: height
        property real lit: rose.lit
        property real litInner: rose.litInner
        property real glow: rose.glow
        property real bloom: rose.bloom
        property real wallMix: rose.wallMix
        property vector4d cracks: rose.cracks
        property color glassA: Gothic.glassA
        property color glassB: Gothic.glassB
        property color glassC: Gothic.glassC
        property color glassD: Gothic.glassD
        property color leadColor: Gothic.lead
        property color stoneColor: Gothic.stone

        fragmentShader: Qt.resolvedUrl("../../../../shaders/rose.frag.qsb")
    }
}
