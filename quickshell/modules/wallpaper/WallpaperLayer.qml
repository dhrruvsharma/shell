pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.colors
import qs.modules.desktoptheme
import qs.services as Services

// The desktop background, one window per screen on the Background layer: the
// wallpaper (services/WallpaperEngine) and, over it in the same surface, the
// active desktop theme's layer. Desktop widgets and windows sit above.
//
// Two images take turns: the new wallpaper loads into the hidden one, the
// theme's transition (shaders/wallpaper_transition.frag) runs from the shown
// one to it, then they swap. Idle, it is just an image.
Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property ShellScreen modelData

            // Transition per desktop theme (see the shader).
            readonly property var modes: ({ "": 0, hud: 1, terminal: 2, cosmos: 3, zen: 4, xianxia: 5 })
            readonly property int mode: modes[Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""] ?? 0

            property Image front: imgA
            readonly property Image back: front === imgA ? imgB : imgA
            property real progress: 0
            property bool waiting: false

            function url(path) {
                return path ? "file://" + path : "";
            }

            function show(path) {
                if (!path)
                    return;
                if (!front.source.toString()) {
                    front.source = url(path);
                    return;
                }
                if (front.source.toString() === url(path))
                    return;
                if (anim.running) {
                    anim.stop();
                    finish();
                }
                back.source = url(path);
                waiting = true;
                if (back.status === Image.Ready)
                    start();
            }

            function start() {
                waiting = false;
                progress = 0;
                anim.duration = mode === 4 ? 1500 : mode === 1 ? 1300 : 1100;
                anim.start();
            }

            // The part of a cropped image's texture that's on screen, as
            // (offset x, offset y, width, height) in texture UV.
            function cropRect(img) {
                const sx = img.paintedWidth > 0 ? Math.min(1, img.width / img.paintedWidth) : 1;
                const sy = img.paintedHeight > 0 ? Math.min(1, img.height / img.paintedHeight) : 1;
                return Qt.vector4d((1 - sx) / 2, (1 - sy) / 2, sx, sy);
            }

            function finish() {
                const old = front;
                front = back;
                progress = 0;
                old.source = "";
            }

            screen: modelData
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "quickshell:wallpaper"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            color: Colors.background
            mask: Region {}

            Component.onCompleted: show(Services.WallpaperEngine.current)

            Connections {
                target: Services.WallpaperEngine

                function onCurrentChanged() {
                    win.show(Services.WallpaperEngine.current);
                }
            }

            component Wall: Image {
                id: wall
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(Math.max(1, win.width), Math.max(1, win.height))
                asynchronous: true
                cache: false
                smooth: true
                onStatusChanged: {
                    if (status === Image.Ready && win.waiting && wall === win.back)
                        win.start();
                    else if (status === Image.Error && wall === win.back)
                        win.waiting = false;
                }
            }

            Wall {
                id: imgA
                z: win.front === imgA ? 1 : 0
            }

            Wall {
                id: imgB
                z: win.front === imgB ? 1 : 0
            }

            ShaderEffect {
                anchors.fill: parent
                z: 2
                visible: anim.running

                property var fromTex: win.front
                property var toTex: win.back
                property real progress: win.progress
                property real mode: win.mode
                property real aspect: width / Math.max(1, height)
                property color edgeColor: Colors.primary
                property vector4d fromRect: win.cropRect(win.front)
                property vector4d toRect: win.cropRect(win.back)

                fragmentShader: Qt.resolvedUrl("../../shaders/wallpaper_transition.frag.qsb")
            }

            NumberAnimation {
                id: anim
                target: win
                property: "progress"
                from: 0
                to: 1
                easing.type: Easing.InOutCubic
                onFinished: win.finish()
            }

            Loader {
                anchors.fill: parent
                z: 3
                active: Services.DesktopTheme.enabled
                sourceComponent: ThemeLayer {}
            }
        }
    }
}
