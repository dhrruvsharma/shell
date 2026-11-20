pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.colors
import qs.services as Services
import "../panorama/Projection.js" as Proj

// Fig. 16: the panorama in little. Four made-up workspaces over your
// wallpaper on their strip, drawn by the real shader at the curve and depth
// set opposite: half way through a switch, or held back with a card lit
// while the pointer's on the overview's line. A click (or the pointer on
// the pace) plays a switch at the pace set.
Item {
    id: fig

    // The spread's focusKey: what the facing page's pointer is on.
    property string lit: ""
    readonly property bool overview: fig.lit === "view"

    property real pos: 1.45
    property real e: 1
    property real glowAmt: fig.overview ? 1 : 0

    Behavior on glowAmt {
        NumberAnimation {
            duration: 260
        }
    }

    function rest() {
        if (play.running)
            return;
        restAnim.stop();
        restAnim.toPos = fig.overview ? 1 : 1.45;
        restAnim.start();
    }

    onOverviewChanged: fig.rest()
    onLitChanged: if (fig.lit === "duration") fig.playSwitch()

    // A switch from card 1 to 2 and back, at the pace set.
    function playSwitch() {
        restAnim.stop();
        play.restart();
    }

    property real _t: 0

    SequentialAnimation {
        id: play
        PropertyAction {
            target: fig
            property: "pos"
            value: 1
        }
        PropertyAction {
            target: fig
            property: "e"
            value: 0
        }
        PauseAnimation {
            duration: 250
        }
        NumberAnimation {
            target: fig
            property: "_t"
            from: 0
            to: 1
            duration: Services.Panorama.duration
        }
        PauseAnimation {
            duration: 600
        }
        ScriptAction {
            script: fig.rest()
        }
    }

    on_TChanged: {
        if (!play.running)
            return;
        fig.pos = Proj.hermite(1, 0, 2, Proj.smooth(0.06, 0.86, fig._t));
        fig.e = Proj.smooth(0, 0.3, fig._t) * (1 - Proj.smooth(0.55, 1, fig._t));
    }

    ParallelAnimation {
        id: restAnim
        property real toPos: 1.45
        NumberAnimation {
            target: fig
            property: "pos"
            to: restAnim.toPos
            duration: 420
            easing.type: Easing.InOutCubic
        }
        NumberAnimation {
            target: fig
            property: "e"
            to: 1
            duration: 420
            easing.type: Easing.InOutCubic
        }
    }

    // ── The made-up workspaces ─────────────────────────────────────────────
    readonly property string wallUrl: "file://" + Services.WallpaperEngine.link

    Item {
        width: 0
        height: 0
        clip: true

        Item {
            id: card0
            width: fig.width
            height: fig.height
            Image {
                anchors.fill: parent
                source: fig.wallUrl
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(fig.width, fig.height)
                asynchronous: true
            }
            PanoramaMockWindow {
                u: fig.width / 600
                x: parent.width * 0.06
                y: parent.height * 0.08
                width: parent.width * 0.88
                height: parent.height * 0.84
            }
        }

        Item {
            id: card1
            width: fig.width
            height: fig.height
            Image {
                anchors.fill: parent
                source: fig.wallUrl
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(fig.width, fig.height)
                asynchronous: true
            }
            PanoramaMockWindow {
                u: fig.width / 600
                x: parent.width * 0.05
                y: parent.height * 0.08
                width: parent.width * 0.43
                height: parent.height * 0.84
            }
            PanoramaMockWindow {
                u: fig.width / 600
                x: parent.width * 0.52
                y: parent.height * 0.08
                width: parent.width * 0.43
                height: parent.height * 0.84
            }
        }

        Item {
            id: card2
            width: fig.width
            height: fig.height
            Image {
                anchors.fill: parent
                source: fig.wallUrl
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(fig.width, fig.height)
                asynchronous: true
            }
        }

        Item {
            id: card3
            width: fig.width
            height: fig.height
            Image {
                anchors.fill: parent
                source: fig.wallUrl
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(fig.width, fig.height)
                asynchronous: true
            }
            PanoramaMockWindow {
                u: fig.width / 600
                x: parent.width * 0.05
                y: parent.height * 0.08
                width: parent.width * 0.55
                height: parent.height * 0.84
            }
            PanoramaMockWindow {
                u: fig.width / 600
                x: parent.width * 0.63
                y: parent.height * 0.08
                width: parent.width * 0.32
                height: parent.height * 0.4
            }
            PanoramaMockWindow {
                u: fig.width / 600
                x: parent.width * 0.63
                y: parent.height * 0.52
                width: parent.width * 0.32
                height: parent.height * 0.4
            }
        }

        ShaderEffectSource {
            id: tex0
            width: 1
            height: 1
            sourceItem: card0
        }
        ShaderEffectSource {
            id: tex1
            width: 1
            height: 1
            sourceItem: card1
        }
        ShaderEffectSource {
            id: tex2
            width: 1
            height: 1
            sourceItem: card2
        }
        ShaderEffectSource {
            id: tex3
            width: 1
            height: 1
            sourceItem: card3
        }
    }

    Image {
        id: wallImg
        visible: false
        source: fig.wallUrl
        asynchronous: true
        sourceSize.width: 480
    }

    ShaderEffect {
        id: fx
        anchors.fill: parent

        readonly property real n: 4
        readonly property real pitchPx: Math.max(1, width) * 1.04
        readonly property real kFull: Math.min(2 * Math.PI / (n * pitchPx), 0.9 / pitchPx) * Services.Panorama.curve

        property size resolution: Qt.size(Math.max(1, width), Math.max(1, height))
        property color accent: Services.DesktopTheme.accent
        property vector4d bgRect: Qt.vector4d(0, 0, 1, 1)
        property real scroll: fig.pos * fx.pitchPx
        property real kappa: fx.kFull * fig.e
        property real dist: 1 / Math.max(fx.kFull, 0.0001)
        property real zoom: 1 - Services.Panorama.depth * fig.e
        property real cardW: Math.max(1, width * (1 - 0.1 * fig.e))
        property real cardH: Math.max(1, height * (1 - 0.1 * fig.e))
        property real pitch: fx.pitchPx
        property real count: fx.n
        property real radius: Services.DesktopTheme.rad(22) * fig.e * width / 1920
        property real depthFade: 0.6
        property real blankMask: 0
        property real lit: 1
        property real glow: fig.glowAmt
        property real veil: 1
        property var src0: tex0
        property var src1: tex1
        property var src2: tex2
        property var src3: tex3
        property var src4: tex0
        property var src5: tex1
        property var src6: tex2
        property var src7: tex3
        property var src8: tex0
        property var src9: tex1
        property var wall: wallImg

        fragmentShader: Qt.resolvedUrl("../../shaders/panorama.frag.qsb")

        readonly property var params: ({
            w: fx.width, h: fx.height, dist: fx.dist, zoom: fx.zoom, kappa: fx.kappa,
            scroll: fx.scroll, pitch: fx.pitch, cardW: fx.cardW, cardH: fx.cardH, count: fx.n
        })
    }

    // The workspaces' numbers, under their cards.
    Repeater {
        model: 4

        Text {
            id: num
            required property int index
            readonly property real idx: Proj.nearest(num.index, fig.pos, 4)
            readonly property var at: Proj.project(fx.params, num.idx * fx.pitchPx, fx.cardH / 2 + 10)
            visible: num.at !== null && fig.e > 0.2 && Math.abs(num.idx - fig.pos) <= 2
            x: num.at ? num.at.x - width / 2 : 0
            y: num.at ? num.at.y : 0
            text: String(num.index + 1)
            font.family: Services.DesktopTheme.font || Qt.application.font.family
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: fig.overview && num.idx === 1 ? Services.DesktopTheme.accent : Colors.withAlpha(Colors.on_surface, 0.75)
            opacity: Math.min(1, (fig.e - 0.2) * 3) * Math.max(0, 1 - Math.abs(num.idx - fig.pos) * 0.4)
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: fig.playSwitch()
    }
}
