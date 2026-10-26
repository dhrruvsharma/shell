pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.colors
import qs.modules.lock
import qs.services as Services

// The plate for how things open: your screen, small, with the bar on its
// edge and the places things open from marked and named round it (the
// launcher's left edge, the notes' bottom edge, GitHub's right edge, the
// bar's widgets), each with how it opens. Pointing at one on the facing
// page plays it: a pointer goes there and it opens, on hover or on a click.
Item {
    id: fig

    // launcher | notes | github | bar, or "" for none.
    property string pointing: ""

    readonly property real sw: 380
    readonly property real sh: 238
    readonly property real k: fig.sw / 1920
    readonly property real sx: (fig.width - fig.sw) / 2
    readonly property real sy: 64
    readonly property string edge: Services.BarLayout.edge
    readonly property real barT: 10

    function modeOf(t) {
        return Services.Opening.mode(t === "bar" ? "system" : t);
    }

    // Where each thing opens from, on the little screen.
    function spot(t) {
        const b = fig.barT;
        if (t === "launcher")
            return Qt.point(1, fig.sh - (Services.BarLayout.atBottom ? b : 0) - 600 * fig.k / 2);
        if (t === "notes")
            return Qt.point(fig.sw / 2, fig.sh - 1);
        if (t === "github")
            return Qt.point(fig.sw - 1, fig.sh - (Services.BarLayout.atBottom ? b : 0) - 500 * fig.k / 2);
        // a widget near the middle of the bar
        return Services.BarLayout.vertical ? Qt.point(Services.BarLayout.atLeft ? b / 2 : fig.sw - b / 2, fig.sh * 0.3)
            : Qt.point(fig.sw * 0.36, Services.BarLayout.atBottom ? fig.sh - b / 2 : b / 2);
    }

    // ── The screen ───────────────────────────────────────────────────────────
    Item {
        id: screen
        x: fig.sx
        y: fig.sy
        width: fig.sw
        height: fig.sh

        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: 8
            color: Qt.darker(BookStyle.cover, 1.2)
        }

        Item {
            anchors.fill: parent
            clip: true

            Image {
                anchors.fill: parent
                source: "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
                sourceSize: Qt.size(760, 476)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: 0.8
            }

            // The bar on its edge, with a few widgets on it.
            Rectangle {
                id: bar
                x: Services.BarLayout.atRight ? fig.sw - fig.barT : 0
                y: Services.BarLayout.atBottom ? fig.sh - fig.barT : 0
                width: Services.BarLayout.vertical ? fig.barT : fig.sw
                height: Services.BarLayout.vertical ? fig.sh : fig.barT
                color: Colors.withAlpha(Colors.background, 0.9)
                border.width: 1
                border.color: Colors.withAlpha(Colors.on_surface, 0.25)

                Repeater {
                    model: 7

                    Rectangle {
                        required property int index
                        readonly property real at: [0.06, 0.13, 0.2, 0.36, 0.72, 0.8, 0.88][index]
                        x: Services.BarLayout.vertical ? 2 : fig.sw * at
                        y: Services.BarLayout.vertical ? fig.sh * at : 2
                        width: Services.BarLayout.vertical ? fig.barT - 4 : (index === 3 ? 30 : 18)
                        height: Services.BarLayout.vertical ? (index === 3 ? 30 : 18) : fig.barT - 4
                        radius: 3
                        color: index === 3 && fig.pointing === "bar" ? BookStyle.accent : Services.BarSettings.pill
                    }
                }
            }

            // The edge strips, lit when they're pointed at.
            Repeater {
                model: ["launcher", "notes", "github"]

                Rectangle {
                    required property string modelData
                    readonly property bool lit: fig.pointing === modelData
                    readonly property real len: ({ launcher: 600, notes: 900, github: 500 })[modelData] * fig.k
                    readonly property real foot: Services.BarLayout.atBottom ? fig.barT : 0
                    x: modelData === "launcher" ? 0 : modelData === "github" ? fig.sw - 4 : (fig.sw - len) / 2
                    y: modelData === "notes" ? fig.sh - 4 : fig.sh - foot - len
                    width: modelData === "notes" ? len : 4
                    height: modelData === "notes" ? 4 : len
                    color: lit ? BookStyle.accent : Colors.withAlpha("#ffffff", 0.55)
                }
            }

            // What opens, while it's being shown.
            Rectangle {
                id: opened
                readonly property string t: fig.pointing
                visible: fig.shown > 0.01 && fig.pointing !== ""
                color: Colors.withAlpha(Colors.surface_container, 0.92)
                border.width: 1
                border.color: BookStyle.accent
                radius: 6
                x: t === "launcher" ? -width * (1 - fig.shown) : t === "github" ? fig.sw - width * fig.shown : t === "notes" ? (fig.sw - width) / 2 : fig.sw * 0.3
                y: t === "notes" ? fig.sh - height * fig.shown : t === "bar" ? (Services.BarLayout.atBottom ? fig.sh - fig.barT - height * fig.shown : fig.barT) : t === "launcher" ? fig.sh * 0.18 : fig.sh - height - (Services.BarLayout.atBottom ? fig.barT : 0)
                width: t === "launcher" ? 120 : t === "notes" ? 900 * fig.k : t === "github" ? 850 * fig.k : 96
                height: t === "launcher" ? fig.sh * 0.64 : t === "notes" ? 300 * fig.k : t === "github" ? 500 * fig.k : 70 * fig.shown
            }

            // A click lands.
            Rectangle {
                x: fig.cx - width / 2
                y: fig.cy - height / 2
                width: 34 * fig.ripple
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: BookStyle.accent
                opacity: 1 - fig.ripple
                visible: fig.ripple > 0.01 && fig.ripple < 0.99
            }

            // The pointer.
            Shape {
                x: fig.cx - 2
                y: fig.cy - 1
                width: 16
                height: 22
                visible: fig.pointing !== "" && fig.pointer > 0.01
                opacity: fig.pointer
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "#ffffff"
                    strokeColor: "#111111"
                    strokeWidth: 1.2
                    joinStyle: ShapePath.RoundJoin

                    PathPolyline {
                        path: [Qt.point(0, 0), Qt.point(0, 17), Qt.point(4.5, 13), Qt.point(7.5, 20), Qt.point(10.5, 18.6), Qt.point(7.6, 12), Qt.point(13, 12), Qt.point(0, 0)]
                    }
                }
            }
        }
    }

    // ── Names round it ───────────────────────────────────────────────────────
    Callout {
        target: "bar"
        side: "top"
        name: "The bar's panels"
        x: screen.x + fig.sw * 0.36 - width / 2
        y: 0
        lineFromX: fig.sw * 0.36 + 15
        lineFromY: Services.BarLayout.atBottom ? fig.sh - fig.barT / 2 : fig.barT / 2
    }

    Callout {
        target: "launcher"
        side: "left"
        name: "The launcher"
        x: 0
        y: screen.y + fig.sh * 0.55
        width: fig.sx - 14
        alignRight: true
        lineFromX: 2
        lineFromY: fig.sh - (Services.BarLayout.atBottom ? fig.barT : 0) - 300 * fig.k
    }

    Callout {
        target: "github"
        side: "right"
        name: "GitHub, timer"
        x: screen.x + fig.sw + 14
        y: screen.y + fig.sh * 0.55
        width: fig.sx - 14
        lineFromX: fig.sw - 2
        lineFromY: fig.sh - (Services.BarLayout.atBottom ? fig.barT : 0) - 250 * fig.k
    }

    Callout {
        target: "notes"
        side: "bottom"
        name: "The notes drawer"
        x: screen.x + fig.sw / 2 - width / 2
        y: screen.y + fig.sh + 26
        lineFromX: fig.sw / 2
        lineFromY: fig.sh
    }

    // A name with how it opens, and a leader line to where.
    component Callout: Item {
        id: callout

        property string target: ""
        property string name: ""
        // Which side of the screen it stands on.
        property string side: "top"
        property bool alignRight: false
        property real lineFromX: 0
        property real lineFromY: 0
        readonly property bool lit: fig.pointing === callout.target
        readonly property bool hover: fig.modeOf(callout.target) === "hover"

        width: Math.max(nameText.implicitWidth, how.implicitWidth)
        height: nameText.height + how.height + 2

        // The leader line, from the name to where it opens from.
        readonly property point to: Qt.point(screen.x + callout.lineFromX - callout.x, screen.y + callout.lineFromY - callout.y)
        readonly property point from: callout.side === "top" ? Qt.point(callout.width / 2, callout.height + 2)
            : callout.side === "bottom" ? Qt.point(callout.width / 2, -3)
            : callout.side === "left" ? Qt.point(callout.width + 4, callout.height / 2) : Qt.point(-4, callout.height / 2)

        Shape {
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: callout.lit ? BookStyle.accent : BookStyle.inkFaint
                strokeWidth: 1
                fillColor: "transparent"
                strokeStyle: ShapePath.DashLine
                dashPattern: [3, 3]
                startX: callout.from.x
                startY: callout.from.y

                PathLine {
                    x: callout.to.x
                    y: callout.to.y
                }
            }
        }

        Rectangle {
            x: callout.to.x - 3
            y: callout.to.y - 3
            width: 6
            height: 6
            radius: 3
            color: callout.lit ? BookStyle.accent : BookStyle.inkSoft
        }

        Column {
            anchors.left: callout.alignRight ? undefined : parent.left
            anchors.right: callout.alignRight ? parent.right : undefined
            spacing: 2

            BookText {
                id: nameText
                anchors.right: callout.alignRight ? parent.right : undefined
                text: callout.name
                font.family: BookStyle.ui
                font.pixelSize: 13
                font.weight: Font.DemiBold
                font.capitalization: BookStyle.labelCaps
                color: callout.lit ? BookStyle.accent : BookStyle.ink
            }

            Row {
                id: how
                anchors.right: callout.alignRight ? parent.right : undefined
                spacing: 4

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: callout.hover ? "arrow_selector_tool" : "ads_click"
                    font.pixelSize: 14
                    color: callout.lit ? BookStyle.accent : BookStyle.inkSoft
                }

                BookText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: callout.hover ? "on hover" : "on a click"
                    font.pixelSize: 12
                    font.italic: true
                    color: callout.lit ? BookStyle.accent : BookStyle.inkSoft
                }
            }
        }
    }

    // ── The demonstration ────────────────────────────────────────────────────
    property real cx: fig.sw / 2
    property real cy: fig.sh / 2
    property real pointer: 0
    property real ripple: 0
    property real shown: 0
    property real tx: 0
    property real ty: 0
    property bool clicks: false

    onPointingChanged: fig.play()
    Component.onCompleted: fig.play()

    function play() {
        demo.stop();
        fig.shown = 0;
        fig.ripple = 0;
        if (!fig.pointing) {
            fig.pointer = 0;
            return;
        }
        const p = fig.spot(fig.pointing);
        fig.tx = Math.max(2, Math.min(fig.sw - 14, p.x - (fig.pointing === "github" ? 8 : 0)));
        fig.ty = Math.max(2, Math.min(fig.sh - 18, p.y - (fig.pointing === "notes" ? 16 : 0)));
        fig.clicks = fig.modeOf(fig.pointing) === "click";
        fig.cx = fig.sw * 0.5;
        fig.cy = fig.sh * 0.5;
        demo.restart();
    }

    SequentialAnimation {
        id: demo
        loops: Animation.Infinite

        NumberAnimation { target: fig; property: "pointer"; to: 1; duration: 160 }
        ParallelAnimation {
            NumberAnimation { target: fig; property: "cx"; to: fig.tx; duration: 700; easing.type: Easing.InOutCubic }
            NumberAnimation { target: fig; property: "cy"; to: fig.ty; duration: 700; easing.type: Easing.InOutCubic }
        }
        PauseAnimation { duration: fig.clicks ? 220 : 120 }
        NumberAnimation { target: fig; property: "ripple"; from: 0; to: fig.clicks ? 1 : 0; duration: fig.clicks ? 380 : 1 }
        NumberAnimation { target: fig; property: "shown"; to: 1; duration: 320; easing.type: Easing.OutCubic }
        PauseAnimation { duration: 1100 }
        // Away again: a peek closes behind it, a click's stays a moment more.
        ParallelAnimation {
            NumberAnimation { target: fig; property: "cx"; to: fig.sw * 0.5; duration: 600; easing.type: Easing.InOutCubic }
            NumberAnimation { target: fig; property: "cy"; to: fig.sh * 0.42; duration: 600; easing.type: Easing.InOutCubic }
        }
        PauseAnimation { duration: fig.clicks || !Services.Opening.closeOnLeave ? 700 : Math.min(900, Services.Opening.closeDelay) }
        NumberAnimation { target: fig; property: "shown"; to: 0; duration: 260; easing.type: Easing.InCubic }
        NumberAnimation { target: fig; property: "pointer"; to: 0; duration: 200 }
        PauseAnimation { duration: 500 }
    }
}
