import QtQuick
import QtQuick.Effects
import Quickshell
import qs.modules.lock

// The world behind the HUD: the current wallpaper, heavily blurred, under a
// static shader that darkens it and adds a vignette, dot grid and scanlines.
Item {
    id: backdrop

    property real sc: 1

    Rectangle {
        anchors.fill: parent
        color: LockTheme.base
    }

    Image {
        id: wallpaper
        anchors.fill: parent
        source: "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
        sourceSize: Qt.size(Math.max(1, backdrop.width), Math.max(1, backdrop.height))
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        visible: wallpaper.status === Image.Ready
        autoPaddingEnabled: false
        blurEnabled: true
        // Blur radius is in pixels: scale it so thumbnails look like the real thing.
        blurMax: Math.max(8, Math.round(64 * backdrop.sc))
        blur: 1.0
        saturation: -0.15
    }

    ShaderEffect {
        anchors.fill: parent

        property real itemWidth: width
        property real itemHeight: height
        property real gridSize: Math.round(30 * backdrop.sc)
        property real dotAlpha: 0.13
        property real scanAlpha: 0.12
        property real tintAlpha: 0.52
        property real vignette: 0.8
        property color tintColor: LockTheme.base
        property color dotColor: LockTheme.ink

        fragmentShader: Qt.resolvedUrl("../../../../shaders/lock_backdrop.frag.qsb")
    }
}
