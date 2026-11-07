pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.colors
import qs.services as Services

// The edge line's plate: your screen in small (the wallpaper, the bar when
// there is one), the line on its border where it lives, the pill it swells
// into, and the popout it opens into on the tab it opens on, drawn as a
// ghost: its strip along the border and its panes. A click along a border
// of the picture moves the line there.
Item {
    id: fig

    property string lit: ""

    readonly property var line: Services.EdgeLine
    readonly property real sw: 1920
    readonly property real sh: 1200
    readonly property real k: Math.min(fig.width / fig.sw, (fig.height - 12) / fig.sh)

    readonly property string edge: fig.line.edge
    readonly property bool horiz: fig.edge === "top" || fig.edge === "bottom"
    readonly property bool barShown: !fig.line.minimal
    readonly property string barEdge: Services.BarLayout.edge
    readonly property real barSize: Services.BarLayout.size

    function insetOf(e) {
        return fig.barShown && fig.barEdge === e ? fig.barSize : 0;
    }

    // A box on the screen, along a border and out from it (as the line
    // itself lays things out).
    function rectOn(e, a0, la, o0, lo) {
        switch (e) {
        case "top":
            return Qt.rect(a0, o0, la, lo);
        case "bottom":
            return Qt.rect(a0, fig.sh - o0 - lo, la, lo);
        case "left":
            return Qt.rect(o0, a0, lo, la);
        default:
            return Qt.rect(fig.sw - o0 - lo, a0, lo, la);
        }
    }

    readonly property real edgeLen: fig.horiz ? fig.sw : fig.sh
    readonly property real inset: fig.insetOf(fig.edge)
    readonly property real along: Math.max(fig.line.length / 2 + 6, Math.min(fig.edgeLen - fig.line.length / 2 - 6, fig.line.pos * fig.edgeLen))
    readonly property rect lineRect: fig.rectOn(fig.edge, fig.along - fig.line.length / 2, fig.line.length, fig.inset + 3, fig.lit === "length" || fig.lit === "edge" ? 8 : 5)
    readonly property rect pillRect: fig.rectOn(fig.edge, fig.along - (fig.horiz ? 120 : 60), fig.horiz ? 240 : 120, fig.inset + 3, fig.horiz ? 32 : 38)

    // The popout on the tab it opens on, as the line works it out (its
    // strip about this long).
    readonly property var tab: fig.line.tabs[fig.line.activeTab] ?? { panels: [] }
    readonly property real stripLen: fig.horiz ? 560 : 470
    readonly property var tree: fig.line.layoutFor(fig.line.activeTab, fig.tab.panels.map(id => {
            const s = fig.line.panelSize(id);
            return { id: id, w: s[0] + 28, h: s[1] + 28 };
        }), fig.tab.panels.map(id => {
            const g = fig.line.panelGuess[id] ?? [300, 200];
            return { id: id, w: g[0] + 28, h: g[1] + 28 };
        }), 12, fig.sw - 60, fig.sh * 0.72, fig.horiz, fig.horiz ? fig.stripLen : 0, fig.horiz ? 0 : fig.stripLen)
    readonly property real cw: fig.tree ? fig.tree.w : 300
    readonly property real ch: fig.tree ? fig.tree.h : 200
    readonly property real popAlong: fig.horiz ? Math.max(fig.cw, fig.stripLen) + 32 : 54 + Math.max(fig.ch, fig.stripLen) + 16
    readonly property real popOut: fig.horiz ? 54 + 44 + 10 + fig.ch + 16 : 32 + 48 + 10 + fig.cw
    readonly property rect popRect: fig.rectOn(fig.edge, Math.max(10, Math.min(fig.edgeLen - 10 - fig.popAlong, fig.along - fig.popAlong / 2)), fig.popAlong, fig.inset + 6, fig.popOut)
    readonly property rect stripRect: {
        const r = fig.popRect, t = fig.horiz ? 44 : 48;
        switch (fig.edge) {
        case "top":
            return Qt.rect(r.x + 16, r.y + 38, r.width - 32, t);
        case "bottom":
            return Qt.rect(r.x + 16, r.y + r.height - 16 - t, r.width - 32, t);
        case "left":
            return Qt.rect(r.x + 16, r.y + 38, t, r.height - 54);
        default:
            return Qt.rect(r.x + r.width - 16 - t, r.y + 38, t, r.height - 54);
        }
    }
    readonly property rect collageRect: {
        const r = fig.popRect, s = fig.stripRect;
        switch (fig.edge) {
        case "top":
            return Qt.rect(r.x + 16, s.y + s.height + 10, r.width - 32, r.y + r.height - 16 - (s.y + s.height + 10));
        case "bottom":
            return Qt.rect(r.x + 16, r.y + 38, r.width - 32, s.y - 10 - (r.y + 38));
        case "left":
            return Qt.rect(s.x + s.width + 10, r.y + 38, r.x + r.width - 16 - (s.x + s.width + 10), r.height - 54);
        default:
            return Qt.rect(r.x + 16, r.y + 38, s.x - 10 - (r.x + 16), r.height - 54);
        }
    }
    readonly property var cells: fig.tree ? fig.line.cells(fig.tree, fig.collageRect.x, fig.collageRect.y, fig.collageRect.width, fig.collageRect.height, 12, {}) : ({})

    Item {
        id: screen
        anchors.horizontalCenter: parent.horizontalCenter
        y: 6
        width: fig.sw * fig.k
        height: fig.sh * fig.k

        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: 6
            color: Qt.darker(BookStyle.cover, 1.2)
        }

        Image {
            anchors.fill: parent
            source: "file://" + Quickshell.env("HOME") + "/.cache/current_wallpaper"
            sourceSize: Qt.size(Math.max(1, width), Math.max(1, height))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: 0.8
        }

        // The bar, while there is one.
        Rectangle {
            readonly property bool side: fig.barEdge === "left" || fig.barEdge === "right"
            visible: fig.barShown
            opacity: fig.lit === "minimal" ? 0.35 : 0.92
            x: fig.barEdge === "right" ? screen.width - width : 0
            y: fig.barEdge === "bottom" ? screen.height - height : 0
            width: side ? fig.barSize * fig.k : screen.width
            height: side ? screen.height : fig.barSize * fig.k
            color: Services.BarSettings.fill

            Behavior on opacity {
                NumberAnimation {
                    duration: 160
                }
            }
        }

        // The popout, as a ghost: its frame, its strip, its panes.
        Item {
            id: ghost
            opacity: fig.lit === "length" || fig.lit === "peek" ? 0.25 : fig.lit === "edge" || fig.lit === "closeOnLeave" || fig.lit === "closeDelay" || fig.lit === "enabled" ? 0.95 : 0.7

            Behavior on opacity {
                NumberAnimation {
                    duration: 160
                }
            }

            Rectangle {
                x: fig.popRect.x * fig.k
                y: fig.popRect.y * fig.k
                width: fig.popRect.width * fig.k
                height: fig.popRect.height * fig.k
                radius: 5
                color: Colors.withAlpha(Colors.surface_container, 0.82)
                border.width: 1
                border.color: Colors.withAlpha(BookStyle.accent, 0.8)
            }

            Rectangle {
                x: fig.stripRect.x * fig.k
                y: fig.stripRect.y * fig.k
                width: fig.stripRect.width * fig.k
                height: fig.stripRect.height * fig.k
                radius: 3
                color: Colors.withAlpha(BookStyle.accent, 0.3)
            }

            Repeater {
                model: fig.tab.panels

                Rectangle {
                    id: cellBox
                    required property string modelData
                    readonly property rect r: fig.cells[cellBox.modelData] ?? Qt.rect(0, 0, 0, 0)
                    x: cellBox.r.x * fig.k
                    y: cellBox.r.y * fig.k
                    width: cellBox.r.width * fig.k
                    height: cellBox.r.height * fig.k
                    radius: 3
                    color: Colors.withAlpha(Colors.on_surface, 0.1)
                }
            }
        }

        // The pill.
        Rectangle {
            visible: fig.lit === "peek"
            x: fig.pillRect.x * fig.k
            y: fig.pillRect.y * fig.k
            width: fig.pillRect.width * fig.k
            height: fig.pillRect.height * fig.k
            radius: Math.min(width, height) / 2
            color: Services.BarSettings.fill
            border.width: 1
            border.color: BookStyle.accent
        }

        // The line.
        Rectangle {
            x: fig.lineRect.x * fig.k - 1
            y: fig.lineRect.y * fig.k - 1
            width: Math.max(3, fig.lineRect.width * fig.k) + 2
            height: Math.max(3, fig.lineRect.height * fig.k) + 2
            radius: Math.min(width, height) / 2
            color: fig.lit === "length" || fig.lit === "edge" ? BookStyle.accent : Colors.primary
            border.width: 1
            border.color: Colors.withAlpha("#000000", 0.4)
        }

        // A click near a border puts the line there.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                const x = mouse.x / fig.k, y = mouse.y / fig.k;
                const d = { top: y / fig.sh, bottom: 1 - y / fig.sh, left: x / fig.sw, right: 1 - x / fig.sw };
                let best = "bottom";
                for (const e of ["top", "bottom", "left", "right"])
                    if (d[e] < d[best])
                        best = e;
                fig.line.place(best, best === "top" || best === "bottom" ? x / fig.sw : y / fig.sh);
            }
        }
    }
}
