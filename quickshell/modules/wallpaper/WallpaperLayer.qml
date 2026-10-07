pragma ComponentBehavior: Bound
import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.colors
import qs.modules.desktoptheme
import qs.services as Services

// The desktop background, one window per screen on the Background layer: the
// wallpaper (services/WallpaperEngine) and, over it in the same surface, the
// active desktop theme's layer. Desktop widgets and windows sit above.
//
// Two slots take turns: the new wallpaper loads into the hidden one, the
// theme's transition (shaders/wallpaper_transition.frag) runs from the shown
// one to it, then they swap. A slot draws a still image, an animated GIF/WebP
// or a muted, looping video; those play only while the screen's workspace has
// no fullscreen or tiled window over them. Idle, it is just that one item. A
// theme layer that reworks the wallpaper itself (Broadsheet's halftone) gets
// a texture of all this, transitions included, which exists only while it's
// wanted.
Scope {
    Variants {
        // None while another program draws the wallpaper (a wallpaper
        // command is set).
        model: Services.WallpaperEngine.external ? [] : Quickshell.screens

        PanelWindow {
            id: win

            required property ShellScreen modelData

            // Transition per desktop theme (see the shader).
            readonly property var modes: ({ "": 0, hud: 1, terminal: 2, cosmos: 3, zen: 4, xianxia: 5, cyberpunk: 6, wabisabi: 7, artdeco: 8, gothic: 9, newspaper: 10, wasteland: 11, observatory: 12, abyss: 13, devaloka: 14, siege: 15 })
            readonly property int mode: modes[Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""] ?? 0

            property Wall front: imgA
            readonly property Wall back: front === imgA ? imgB : imgA
            property real progress: 0
            property bool waiting: false
            // Animated wallpapers play only while they can be seen: not under
            // a fullscreen window, and not behind tiled windows (which leave
            // just the gaps; Qt also spins its render thread on a video
            // surface the compositor stops drawing). Floating windows don't
            // count.
            readonly property HyprlandWorkspace workspace: Hyprland.monitorFor(modelData)?.activeWorkspace ?? null
            readonly property bool covered: !!workspace && (workspace.hasFullscreen || Services.Hyprland.windowList.some(w => w.workspace?.id === workspace.id && !w.floating))
            readonly property bool playing: !covered

            function show(path) {
                if (!path)
                    return;
                if (!front.path) {
                    front.path = path;
                    return;
                }
                if (front.path === path)
                    return;
                if (anim.running) {
                    anim.stop();
                    finish();
                }
                back.path = path;
                waiting = true;
                if (back.ready)
                    start();
            }

            function start() {
                waiting = false;
                progress = 0;
                anim.duration = ({ 1: 1300, 4: 1500, 6: 950, 7: 1400, 8: 1400, 9: 1500, 10: 1600, 11: 1500, 12: 1500, 13: 1600, 14: 1500, 15: 1600 })[mode] ?? 1100;
                anim.start();
            }

            function finish() {
                const old = front;
                front = back;
                progress = 0;
                old.path = "";
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

            // One slot: whatever `path` is, cropped to fill the screen.
            component Wall: Item {
                id: wall

                property string path: ""
                readonly property string kind: Services.WallpaperEngine.kind(path)
                // Something to show (a video: its first frame is decoded).
                readonly property bool ready: !!loader.item && loader.item.ready
                readonly property bool failed: !!loader.item && loader.item.failed

                anchors.fill: parent

                onReadyChanged: {
                    if (ready && win.waiting && wall === win.back)
                        win.start();
                }
                onFailedChanged: {
                    if (failed && wall === win.back)
                        win.waiting = false;
                }

                Loader {
                    id: loader
                    anchors.fill: parent
                    sourceComponent: !wall.path ? null : wall.kind === "video" ? video : wall.kind === "animated" ? animated : still
                }

                Component {
                    id: still

                    Image {
                        readonly property bool ready: status === Image.Ready
                        readonly property bool failed: status === Image.Error

                        source: "file://" + wall.path
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(Math.max(1, win.width), Math.max(1, win.height))
                        asynchronous: true
                        cache: false
                        smooth: true
                    }
                }

                // Frames are decoded as they're shown (cache: false), not
                // all held in memory.
                Component {
                    id: animated

                    AnimatedImage {
                        readonly property bool ready: status === Image.Ready
                        readonly property bool failed: status === Image.Error

                        source: "file://" + wall.path
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        smooth: true
                        playing: true
                        paused: !win.playing
                    }
                }

                // Muted (no audio output at all) and looping. It plays until
                // its first frame is up even when paused, so it never shows
                // black.
                Component {
                    id: video

                    Item {
                        id: clip

                        property bool shown: false
                        readonly property bool ready: shown
                        readonly property bool failed: player.error !== MediaPlayer.NoError

                        function sync() {
                            if (win.playing || !shown)
                                player.play();
                            else
                                player.pause();
                        }

                        Component.onCompleted: sync()

                        Connections {
                            target: win

                            function onPlayingChanged() {
                                clip.sync();
                            }
                        }

                        MediaPlayer {
                            id: player
                            source: "file://" + wall.path
                            loops: MediaPlayer.Infinite
                            videoOutput: output
                            onErrorOccurred: (error, errorString) => console.warn("wallpaper:", errorString)
                        }

                        VideoOutput {
                            id: output
                            anchors.fill: parent
                            fillMode: VideoOutput.PreserveAspectCrop
                        }

                        Connections {
                            target: output.videoSink

                            function onVideoFrameChanged() {
                                if (!clip.shown) {
                                    clip.shown = true;
                                    clip.sync();
                                }
                            }
                        }
                    }
                }
            }

            // The wallpaper as drawn: both slots and the transition. The
            // transition reads the slots through textures that live only
            // while it runs (so a video keeps moving through it).
            Item {
                id: stack
                anchors.fill: parent

                Wall {
                    id: imgA
                    z: win.front === imgA ? 1 : 0
                }

                Wall {
                    id: imgB
                    z: win.front === imgB ? 1 : 0
                }

                ShaderEffectSource {
                    id: fromSource
                    anchors.fill: parent
                    visible: false
                    sourceItem: anim.running ? win.front : null
                    textureSize: Qt.size(width * win.modelData.devicePixelRatio, height * win.modelData.devicePixelRatio)
                }

                ShaderEffectSource {
                    id: toSource
                    anchors.fill: parent
                    visible: false
                    sourceItem: anim.running ? win.back : null
                    textureSize: fromSource.textureSize
                }

                ShaderEffect {
                    anchors.fill: parent
                    z: 2
                    visible: anim.running

                    property var fromTex: fromSource
                    property var toTex: toSource
                    property real progress: win.progress
                    property real mode: win.mode
                    property real aspect: width / Math.max(1, height)
                    property color edgeColor: Services.DesktopTheme.accent
                    property vector4d fromRect: Qt.vector4d(0, 0, 1, 1)
                    property vector4d toRect: Qt.vector4d(0, 0, 1, 1)

                    fragmentShader: Qt.resolvedUrl("../../shaders/wallpaper_transition.frag.qsb")
                }
            }

            // Only when the theme layer reworks the wallpaper.
            ShaderEffectSource {
                id: stackTexture
                width: win.width
                height: win.height
                visible: false
                sourceItem: (themeLoader.item as ThemeLayer)?.usesWallpaper ? stack : null
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
                id: themeLoader
                anchors.fill: parent
                z: 3
                active: Services.DesktopTheme.enabled
                sourceComponent: ThemeLayer {
                    wallpaper: stackTexture
                }
            }
        }
    }
}
