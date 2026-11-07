pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.colors
import qs.services as Services
import qs.modules.lock
import qs.modules.control

// Arranging a tab's panes by hand (the strip's Arrange): a card over each
// pane, to carry onto another pane's edge (it goes beside that one, on that
// side) or onto the edge of the whole collage (beside all of them). Where
// it would go lights up while it's carried, red when the popout wouldn't
// fit on the screen that way. The arrangement stays with the tab
// (services/EdgeLine.setLayout) whatever the panes come to show; Automatic
// gives the tab back the one worked out for it.
Item {
    id: arrange

    required property var host

    readonly property var line: Services.EdgeLine
    readonly property int tab: arrange.host.shownIndex
    readonly property var panes: arrange.host.shownPanes
    // The arrangement on show (its own, or the one worked out for it).
    readonly property var shape: arrange.line.shapeOf(arrange.host.collage)
    readonly property bool own: arrange.line.layoutOf(arrange.tab) !== null

    // Being carried: the pane, the pointer, and where it would go (a pane,
    // "" for beside all of them, "-" for nowhere) and on which side.
    property string carried: ""
    property point at: Qt.point(0, 0)
    property string target: "-"
    property string side: ""

    readonly property var proposal: arrange.carried !== "" && arrange.target !== "-" ? arrange.line.docked(arrange.shape, arrange.carried, arrange.target, arrange.side) : null
    readonly property bool same: arrange.proposal !== null && JSON.stringify(arrange.proposal) === JSON.stringify(arrange.shape)
    readonly property bool fits: {
        if (arrange.proposal === null)
            return true;
        const byId = {};
        for (const it of arrange.host.paneItems)
            byId[it.id] = it;
        const t = arrange.line.sized(arrange.proposal, byId, arrange.host.cellGap);
        return t.w <= arrange.host.maxCollageW + 1 && t.h <= arrange.host.maxCollageH + 1;
    }

    // What's under the pointer: the collage's own edge first (beside all of
    // them), then a pane's nearest edge.
    function aim(p) {
        const c = arrange.host.collageRect;
        const band = 22, out = 18;
        if (arrange.panes.length > 2 && p.x >= c.x - out && p.x <= c.x + c.width + out && p.y >= c.y - out && p.y <= c.y + c.height + out) {
            const d = { left: p.x - c.x, right: c.x + c.width - p.x, top: p.y - c.y, bottom: c.y + c.height - p.y };
            let best = "";
            for (const k of ["left", "right", "top", "bottom"]) {
                if (d[k] < band && (best === "" || d[k] < d[best]))
                    best = k;
            }
            if (best !== "") {
                arrange.target = "";
                arrange.side = best;
                return;
            }
        }
        for (const id of arrange.panes) {
            const r = arrange.host.cellRects[id];
            if (id === arrange.carried || !r || p.x < r.x || p.y < r.y || p.x > r.x + r.width || p.y > r.y + r.height)
                continue;
            const fx = (p.x - r.x) / r.width, fy = (p.y - r.y) / r.height;
            const d = { left: fx, right: 1 - fx, top: fy, bottom: 1 - fy };
            let best = "left";
            for (const k of ["right", "top", "bottom"]) {
                if (d[k] < d[best])
                    best = k;
            }
            arrange.target = id;
            arrange.side = best;
            return;
        }
        arrange.target = "-";
        arrange.side = "";
    }

    // (the tab's panes are made again for it: not from inside a card's
    // own handler)
    function drop() {
        if (arrange.proposal !== null && arrange.fits && !arrange.same)
            Qt.callLater(arrange.line.setLayout, arrange.tab, arrange.proposal);
        arrange.cancel();
    }

    function cancel() {
        arrange.carried = "";
        arrange.target = "-";
        arrange.side = "";
    }

    // Where it would go.
    readonly property rect zone: {
        if (arrange.carried === "" || arrange.target === "-")
            return Qt.rect(0, 0, 0, 0);
        const r = arrange.target === "" ? arrange.host.collageRect : arrange.host.cellRects[arrange.target];
        if (!r)
            return Qt.rect(0, 0, 0, 0);
        const f = arrange.target === "" ? 0.3 : 0.5;
        switch (arrange.side) {
        case "left":
            return Qt.rect(r.x, r.y, r.width * f, r.height);
        case "right":
            return Qt.rect(r.x + r.width * (1 - f), r.y, r.width * f, r.height);
        case "top":
            return Qt.rect(r.x, r.y, r.width, r.height * f);
        default:
            return Qt.rect(r.x, r.y + r.height * (1 - f), r.width, r.height * f);
        }
    }

    // A card over each pane.
    Repeater {
        model: ScriptModel {
            values: arrange.panes
        }

        Item {
            id: card

            required property string modelData

            readonly property rect r: arrange.host.cellRects[card.modelData] ?? Qt.rect(0, 0, 0, 0)
            readonly property var info: arrange.line.panel(card.modelData)
            readonly property bool moving: arrange.carried === card.modelData

            x: card.r.x
            y: card.r.y
            width: card.r.width
            height: card.r.height

            Behavior on x {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on width {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }

            // (the frame's colour under the well's, so the pane under it is
            // put away: wells are often see-through)
            Rectangle {
                anchors.fill: parent
                topLeftRadius: ControlStyle.corner(14, 0)
                topRightRadius: ControlStyle.corner(14, 1)
                bottomRightRadius: ControlStyle.corner(14, 2)
                bottomLeftRadius: ControlStyle.corner(14, 3)
                color: Colors.withAlpha(arrange.host.fill, card.moving ? 0.55 : 0.96)

                Rectangle {
                    anchors.fill: parent
                    topLeftRadius: parent.topLeftRadius
                    topRightRadius: parent.topRightRadius
                    bottomRightRadius: parent.bottomRightRadius
                    bottomLeftRadius: parent.bottomLeftRadius
                    color: grab.containsMouse && !card.moving ? ControlStyle.wellHover : ControlStyle.well
                    border.width: 1
                    border.color: Colors.withAlpha(ControlStyle.accent, card.moving ? 0.3 : grab.containsMouse ? 0.9 : 0.5)
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 4
                opacity: card.moving ? 0.35 : 1

                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: card.info?.icon ?? "widgets"
                    filled: grab.containsMouse
                    font.pixelSize: 28
                    color: ControlStyle.accent
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ControlStyle.label(card.info?.name ?? card.modelData)
                    font.family: ControlStyle.ui
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    font.capitalization: ControlStyle.caps
                    color: ControlStyle.ink
                }
            }

            MouseArea {
                id: grab

                property point start: Qt.point(0, 0)
                property bool carrying: false

                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                cursorShape: card.moving ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                onPressed: mouse => {
                    grab.start = Qt.point(mouse.x, mouse.y);
                    grab.carrying = false;
                }
                onPositionChanged: mouse => {
                    if (!grab.pressed)
                        return;
                    if (!grab.carrying && Math.hypot(mouse.x - grab.start.x, mouse.y - grab.start.y) > 6) {
                        grab.carrying = true;
                        arrange.carried = card.modelData;
                    }
                    if (grab.carrying) {
                        const p = grab.mapToItem(arrange, mouse.x, mouse.y);
                        arrange.at = p;
                        arrange.aim(p);
                    }
                }
                onReleased: {
                    if (grab.carrying)
                        arrange.drop();
                    grab.carrying = false;
                }
                onCanceled: {
                    grab.carrying = false;
                    arrange.cancel();
                }
            }
        }
    }

    // Where it would go: the half of a pane, or a band along all of them.
    Rectangle {
        visible: arrange.carried !== "" && arrange.target !== "-" && !arrange.same
        x: arrange.zone.x
        y: arrange.zone.y
        width: arrange.zone.width
        height: arrange.zone.height
        radius: ControlStyle.radius(12)
        color: Colors.withAlpha(arrange.fits ? ControlStyle.accent : ControlStyle.danger, 0.22)
        border.width: 2
        border.color: arrange.fits ? ControlStyle.accent : ControlStyle.danger

        Text {
            visible: !arrange.fits
            anchors.centerIn: parent
            width: parent.width - 12
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: "Too big for the screen"
            font.family: ControlStyle.body
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: ControlStyle.danger
        }
    }

    // The pane carried, under the pointer.
    Rectangle {
        id: ghost

        readonly property var info: arrange.line.panel(arrange.carried)

        visible: arrange.carried !== ""
        x: arrange.at.x + 12
        y: arrange.at.y + 12
        width: ghostRow.implicitWidth + 20
        height: 34
        radius: Math.min(17, ControlStyle.radius(17))
        color: ControlStyle.well
        border.width: 1
        border.color: ControlStyle.accent

        Row {
            id: ghostRow
            anchors.centerIn: parent
            spacing: 6

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: ghost.info?.icon ?? ""
                font.pixelSize: 17
                color: ControlStyle.accent
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ghost.info?.name ?? ""
                font.family: ControlStyle.ui
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: ControlStyle.ink
            }
        }
    }

    // What to do, over the collage (on its side away from the strip).
    Rectangle {
        id: banner

        readonly property rect c: arrange.host.collageRect

        visible: arrange.carried === ""
        width: Math.min(banner.c.width - 16, bannerRow.implicitWidth + 24)
        height: bannerRow.implicitHeight + 14
        x: banner.c.x + (banner.c.width - width) / 2
        y: arrange.host.edge === "top" ? banner.c.y + banner.c.height - height - 8 : banner.c.y + 8
        radius: Math.min(height / 2, ControlStyle.radius(height / 2))
        color: Colors.withAlpha(arrange.host.fill, 0.97)
        border.width: 1
        border.color: Colors.withAlpha(ControlStyle.accent, 0.6)

        Row {
            id: bannerRow
            anchors.centerIn: parent
            spacing: 8

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: "drag_pan"
                font.pixelSize: 17
                color: ControlStyle.accent
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, banner.c.width - 230)
                elide: Text.ElideRight
                text: arrange.panes.length < 2 ? "One panel: nothing to arrange" : "Carry a panel onto another's edge"
                font.family: ControlStyle.body
                font.pixelSize: 12
                color: arrange.host.ink
            }

            PaneChip {
                visible: arrange.own
                anchors.verticalCenter: parent.verticalCenter
                icon: "auto_awesome_mosaic"
                text: "Automatic"
                onClicked: arrange.line.clearLayout(arrange.tab)
            }

            PaneChip {
                anchors.verticalCenter: parent.verticalCenter
                icon: "check"
                text: "Done"
                onClicked: arrange.line.setArranging(false)
            }
        }
    }
}
