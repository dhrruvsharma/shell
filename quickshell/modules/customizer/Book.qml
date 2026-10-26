pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.colors
import qs.modules.lock

// The customizer's book (see Customizer.qml): boards, a block of pages
// with the spread that's open on it, the leaf that turns when you go to
// another, thumb-index tabs for the chapters (those you've passed stand
// out of the left-hand edge, those ahead out of the right), a ribbon back
// to the contents, and page corners that turn on a click.
//
// It opens on its front cover (`openAt`), which swings over to the left as
// the book slides to the middle, and closes back onto it (`close`).
// Spreads are built only while they're open (or turning in), two at most,
// and at once when asked for (a few ms each), so a turn starts on the click.
Item {
    id: book

    property real pageW: 740
    property real pageH: 900
    readonly property real board: 14
    readonly property int count: BookContents.spreads.length

    // The open spread.
    property int current: 0
    // Shut on its cover (before it opens, after it's closed).
    property bool shut: true
    // 0 shut .. 1 open: the book slides over as the cover swings.
    property real openness: 0
    readonly property bool turning: turnAnim.running || coverAnim.running
    // How long a leaf takes to turn, and the cover to open.
    property int turnDuration: 720
    property int coverDuration: 820

    signal opened
    signal closed

    width: book.pageW * 2
    height: book.pageH

    transform: Translate {
        x: -book.pageW / 2 * (1 - book.openness)
    }

    // ── Spreads ──────────────────────────────────────────────────────────────
    readonly property var components: ({
        contents: contentsC,
        opening: openingC,
        bar: barC,
        barColour: barColourC,
        barWidths: barWidthsC,
        disc: discC,
        discForm: discFormC,
        gaps: gapsC,
        glass: glassC,
        theme: themeC,
        palette: paletteC,
        desktop: desktopC,
        notices: noticesC,
        pet: petC
    })

    Component { id: contentsC; ContentsSpread {} }
    Component { id: openingC; OpeningSpread {} }
    Component { id: barC; BarSpread {} }
    Component { id: barColourC; BarColourSpread {} }
    Component { id: barWidthsC; BarWidthsSpread {} }
    Component { id: discC; DiscSpread {} }
    Component { id: discFormC; DiscFormSpread {} }
    Component { id: gapsC; GapsSpread {} }
    Component { id: glassC; GlassSpread {} }
    Component { id: themeC; ThemeSpread {} }
    Component { id: paletteC; PaletteSpread {} }
    Component { id: desktopC; DesktopSpread {} }
    Component { id: noticesC; NoticesSpread {} }
    Component { id: petC; PetSpread {} }

    // Two slots: the open spread, and the one being turned to.
    property Loader front: slotA
    readonly property Loader spare: book.front === slotA ? slotB : slotA
    property int _target: -1
    property real _dir: 1

    function _fill(slot, i) {
        slot.index = i;
        slot.sourceComponent = book.components[BookContents.spreads[i].id];
    }

    function _setUp(slot) {
        const it = slot.item;
        const s = BookContents.spreads[slot.index];
        const ch = BookContents.chapter(s.chapter);
        it.pageW = book.pageW;
        it.pageH = book.pageH;
        it.number = BookContents.pageOf(slot.index);
        it.book = book;
        it.chapterTitle = ch ? ch.title : "";
        it.sectionTitle = s.section;
        // A shut book shows only its cover.
        it.leftPage.visible = Qt.binding(() => !book.shut || leaf.active);
    }

    // To the i-th spread, turning as many leaves as it takes.
    function go(i) {
        if (i < 0 || i >= book.count || i === book.current || book.shut || book.turning || book._target >= 0)
            return;
        book._target = i;
        book._dir = i > book.current ? 1 : -1;
        book._fill(book.spare, i);
    }

    function next() {
        book.go(book.current + 1);
    }

    function prev() {
        book.go(book.current - 1);
    }

    function _turnIn() {
        // Closed (or turned elsewhere) while the page was being built.
        if (book._target < 0 || book.shut || coverAnim.running || !book.spare.item || book.spare.index !== book._target)
            return;
        const dir = book._dir;
        leaf.dir = dir;
        leaf.frontItem = dir > 0 ? book.front.item.rightPage : book.front.item.leftPage;
        leaf.backItem = dir > 0 ? book.spare.item.leftPage : book.spare.item.rightPage;
        leaf.progress = 0;
        leaf.active = true;
        // A longer jump riffles past the pages between, a little quicker.
        const leaves = Math.abs(book._target - book.current);
        riffle.leaves = Math.min(3, leaves - 1);
        turnAnim.duration = leaves > 1 ? Math.round(book.turnDuration * 0.86) : book.turnDuration;
        turnAnim.restart();
    }

    function _turned() {
        const old = book.front;
        book.front = book.spare;
        book.current = book._target;
        book._target = -1;
        old.sourceComponent = undefined;
        old.index = -1;
        leaf.active = false;
        leaf.frontItem = null;
        leaf.backItem = null;
        riffle.leaves = 0;
    }

    // Open on the i-th spread: the cover swings over.
    function openAt(i) {
        coverAnim.stop();
        turnAnim.stop();
        book._target = -1;
        book.shut = true;
        book.openness = 0;
        leaf.active = false;
        if (book.front.index !== i || !book.front.item)
            book._fill(book.front, i);
        book.current = i;
        coverOpen.start();
    }

    function close() {
        if (book.shut || coverAnim.running && coverAnim.closing)
            return;
        turnAnim.stop();
        if (book._target >= 0) {
            book.spare.sourceComponent = undefined;
            book._target = -1;
        }
        leaf.active = false;
        leaf.dir = -1;
        leaf.frontItem = book.front.item ? book.front.item.leftPage : null;
        leaf.backItem = cover;
        leaf.progress = 0;
        leaf.active = true;
        coverAnim.closing = true;
        coverAnim.restart();
    }

    // Starts the cover once the spread under it is built.
    Timer {
        id: coverOpen
        interval: 16
        repeat: true
        onTriggered: {
            if (!book.front.item)
                return;
            stop();
            leaf.dir = 1;
            leaf.frontItem = cover;
            leaf.backItem = book.front.item.leftPage;
            leaf.progress = 0;
            leaf.active = true;
            coverAnim.closing = false;
            coverAnim.restart();
        }
    }

    ParallelAnimation {
        id: coverAnim

        property bool closing: false

        NumberAnimation {
            target: leaf
            property: "progress"
            from: 0
            to: 1
            duration: coverAnim.closing ? Math.round(book.coverDuration * 0.68) : book.coverDuration
            easing.type: Easing.Linear
        }
        NumberAnimation {
            target: book
            property: "openness"
            to: coverAnim.closing ? 0 : 1
            duration: coverAnim.closing ? Math.round(book.coverDuration * 0.68) : book.coverDuration
            easing.type: Easing.InOutCubic
        }

        onStarted: if (!coverAnim.closing) book.shut = false
        onFinished: {
            leaf.active = false;
            leaf.frontItem = null;
            leaf.backItem = null;
            if (coverAnim.closing) {
                book.shut = true;
                book.closed();
            } else {
                book.opened();
            }
        }
    }

    NumberAnimation {
        id: turnAnim
        target: leaf
        property: "progress"
        from: 0
        to: 1
        duration: 720
        easing.type: Easing.Linear
        onFinished: book._turned()
    }

    // ── The binding ──────────────────────────────────────────────────────────
    RectangularShadow {
        x: -book.board + (book.leftShown ? 0 : book.pageW)
        y: -book.board + 16
        width: book.pageW * (book.leftShown ? 2 : 1) + 2 * book.board
        height: book.pageH + 2 * book.board
        radius: 8
        blur: 46
        spread: 4
        color: Colors.withAlpha("#000000", 0.5)
    }

    // The left half shows once the cover has swung past the spine (and
    // until it swings back).
    readonly property bool leftShown: coverAnim.running ? (coverAnim.closing ? leaf.progress < 0.5 : leaf.progress > 0.5) : !book.shut

    // The boards, a little proud of the pages.
    Rectangle {
        id: backBoard
        x: book.pageW - book.board * 0
        y: -book.board
        width: book.pageW + book.board
        height: book.pageH + 2 * book.board
        radius: 6
        color: BookStyle.cover
        border.width: 1
        border.color: Qt.darker(BookStyle.cover, 1.5)
    }

    Rectangle {
        x: -book.board
        y: -book.board
        width: book.pageW + book.board
        height: book.pageH + 2 * book.board
        radius: 6
        visible: book.leftShown
        color: BookStyle.cover
        border.width: 1
        border.color: Qt.darker(BookStyle.cover, 1.5)
    }

    // The spine's hinge between the boards.
    Rectangle {
        x: book.pageW - 7
        y: -book.board
        width: 14
        height: book.pageH + 2 * book.board
        visible: book.leftShown
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.darker(BookStyle.cover, 1.25) }
            GradientStop { position: 0.5; color: Qt.darker(BookStyle.cover, 1.7) }
            GradientStop { position: 1; color: Qt.darker(BookStyle.cover, 1.25) }
        }
    }

    // The page block's edges: the pages already read on the left, those
    // still to come on the right, thicker or thinner as you go.
    readonly property real readShare: book.count > 1 ? book.current / (book.count - 1) : 0

    Repeater {
        model: 2

        Item {
            id: blockEdge

            required property int index
            readonly property bool onLeft: index === 0
            property real depth: 2 + 6 * (blockEdge.onLeft ? book.readShare : 1 - book.readShare)

            visible: blockEdge.onLeft ? book.leftShown : true
            x: blockEdge.onLeft ? -blockEdge.depth : book.pageW * 2
            y: 2
            width: blockEdge.depth
            height: book.pageH + blockEdge.depth * 0.5

            Behavior on depth {
                NumberAnimation {
                    duration: 400
                }
            }

            Repeater {
                model: Math.ceil(blockEdge.depth / 1.5)

                Rectangle {
                    required property int index
                    x: blockEdge.onLeft ? blockEdge.width - (index + 1) * 1.5 : index * 1.5
                    y: index * 0.6
                    width: 1.5
                    height: book.pageH - index * 0.4
                    color: index % 2 === 0 ? Qt.tint(BookStyle.edge, Colors.withAlpha(BookStyle.paper, 0.35)) : Qt.darker(BookStyle.paper, BookStyle.lightPaper ? 1.25 : 0.7)
                }
            }
        }
    }

    // ── The pages ────────────────────────────────────────────────────────────
    Loader {
        id: slotA

        property int index: -1

        width: book.pageW * 2
        height: book.pageH
        // The spread being turned to stays hidden until its leaf takes it
        // up (slotB lies over slotA, so it would flash over the open one).
        visible: book.front === slotA || leaf.active
        enabled: !book.turning && book.front === slotA
        onLoaded: {
            book._setUp(slotA);
            if (book.front !== slotA && book._target === slotA.index)
                Qt.callLater(book._turnIn);
        }
    }

    Loader {
        id: slotB

        property int index: -1

        width: book.pageW * 2
        height: book.pageH
        // The spread being turned to stays hidden until its leaf takes it
        // up (slotB lies over slotA, so it would flash over the open one).
        visible: book.front === slotB || leaf.active
        enabled: !book.turning && book.front === slotB
        onLoaded: {
            book._setUp(slotB);
            if (book.front !== slotB && book._target === slotB.index)
                Qt.callLater(book._turnIn);
        }
    }

    // The fold: a little shadow over both pages where they meet.
    Rectangle {
        x: book.pageW - 26
        width: 52
        height: book.pageH
        visible: book.leftShown
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.47; color: Colors.withAlpha("#000000", BookStyle.lightPaper ? 0.1 : 0.22) }
            GradientStop { position: 0.5; color: Colors.withAlpha("#000000", BookStyle.lightPaper ? 0.22 : 0.4) }
            GradientStop { position: 0.53; color: Colors.withAlpha("#000000", BookStyle.lightPaper ? 0.1 : 0.22) }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    // ── Ribbon ───────────────────────────────────────────────────────────────
    // Back to the contents.
    Item {
        id: ribbon
        x: book.pageW + 26
        y: -book.board - 3
        width: 11
        height: book.pageH + book.board + 64
        visible: !book.shut
        opacity: book.openness

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: ribbonArea.containsMouse ? Qt.lighter(BookStyle.ribbon, 1.2) : Qt.darker(BookStyle.ribbon, 1.15)
                strokeColor: Qt.darker(BookStyle.ribbon, 1.6)
                strokeWidth: 0.6

                PathPolyline {
                    path: [Qt.point(0, 0), Qt.point(ribbon.width, 0), Qt.point(ribbon.width, ribbon.height), Qt.point(ribbon.width / 2, ribbon.height - 8), Qt.point(0, ribbon.height), Qt.point(0, 0)]
                }
            }
        }

        // The satin's sheen down its middle.
        Rectangle {
            x: 4
            width: 2
            height: ribbon.height - 12
            color: Colors.withAlpha("#ffffff", 0.1)
        }

        MouseArea {
            id: ribbonArea
            anchors.fill: parent
            anchors.topMargin: book.pageH * 0.75
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: book.go(0)
        }
    }

    // The front cover, lying on the right while the book is shut (and drawn
    // into the leaf while it turns).
    Cover {
        id: cover
        x: book.pageW
        width: book.pageW
        height: book.pageH
        visible: book.shut || leaf.active && (leaf.frontItem === cover || leaf.backItem === cover)
    }

    // Blank leaves riffling past ahead of the one that turns, on a jump.
    Riffle {
        id: riffle
        pageW: book.pageW
        pageH: book.pageH
        dir: leaf.dir
        progress: leaf.progress
    }

    PageTurn {
        id: leaf
        pageW: book.pageW
        pageH: book.pageH
    }

    // ── Thumb index ──────────────────────────────────────────────────────────
    Repeater {
        model: BookContents.chapters

        Item {
            id: tab

            required property var modelData
            required property int index
            readonly property int start: BookContents.chapterStart(tab.modelData.n)
            readonly property bool passed: tab.start <= book.current
            readonly property bool here: BookContents.spreads[book.current].chapter === tab.modelData.n
            readonly property real reach: tabArea.containsMouse ? 40 : tab.here ? 34 : 28

            visible: !book.shut
            opacity: book.openness
            y: 64 + tab.index * 90
            x: tab.passed ? -book.board - tab.reach : book.pageW * 2 + book.board + tab.reach - width
            width: 76
            height: 78
            z: tab.passed ? -1 : -1

            Behavior on x {
                NumberAnimation {
                    duration: 380
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Math.min(8, (BookStyle.b.radius ?? 6) + 2)
                color: tab.here ? BookStyle.accent : Qt.tint(Qt.darker(BookStyle.paper, BookStyle.lightPaper ? 1.08 : 0.82), Colors.withAlpha(BookStyle.accent, 0.12 + 0.03 * (tab.index % 3)))
                border.width: 1
                border.color: Colors.withAlpha(BookStyle.ink, 0.18)
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                x: tab.passed ? 6 : parent.width - width - 6
                width: 26
                spacing: 3

                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: tab.modelData.icon
                    filled: tab.here
                    font.pixelSize: 19
                    color: tab.here ? BookStyle.onAccent : BookStyle.ink
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: BookStyle.roman(tab.modelData.n)
                    font.family: BookStyle.body
                    font.pixelSize: 12
                    color: tab.here ? BookStyle.onAccent : BookStyle.inkSoft
                }
            }

            // The chapter's name, beside the tab while the pointer's on it.
            Rectangle {
                visible: tabArea.containsMouse
                x: tab.passed ? -width - 8 : tab.width + 8
                anchors.verticalCenter: parent.verticalCenter
                width: tipText.implicitWidth + 20
                height: 30
                radius: BookStyle.b.radius ?? 4
                color: BookStyle.cover
                border.width: 1
                border.color: Colors.withAlpha(BookStyle.coverInk, 0.3)

                Text {
                    id: tipText
                    anchors.centerIn: parent
                    text: tab.modelData.title
                    font.family: BookStyle.ui
                    font.pixelSize: 13
                    color: BookStyle.coverInk
                }
            }

            MouseArea {
                id: tabArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: book.go(tab.start)
            }
        }
    }

    // ── Page corners ─────────────────────────────────────────────────────────
    // Point at a lower corner and it lifts; click it to turn the page.
    Repeater {
        model: 2

        Item {
            id: corner

            required property int index
            readonly property bool onRight: index === 1
            readonly property bool can: corner.onRight ? book.current < book.count - 1 : book.current > 0
            readonly property real lift: cornerArea.containsMouse && corner.can && !book.turning ? 1 : 0

            visible: !book.shut && corner.can
            x: corner.onRight ? book.pageW * 2 - width : 0
            y: book.pageH - height
            width: 64
            height: 64

            property real shownLift: corner.lift

            Behavior on shownLift {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }

            // The dog-ear: the corner folded back over the page.
            Shape {
                anchors.fill: parent
                visible: corner.shownLift > 0.01
                preferredRendererType: Shape.CurveRenderer
                readonly property real s: 30 * corner.shownLift

                ShapePath {
                    fillColor: Colors.withAlpha("#000000", 0.22)
                    strokeWidth: 0
                    strokeColor: "transparent"

                    PathPolyline {
                        readonly property real s: 30 * corner.shownLift
                        path: corner.onRight
                            ? [Qt.point(corner.width - s - 4, corner.height), Qt.point(corner.width - s - 3, corner.height - s - 3), Qt.point(corner.width, corner.height - s - 4), Qt.point(corner.width - s - 4, corner.height)]
                            : [Qt.point(s + 4, corner.height), Qt.point(s + 3, corner.height - s - 3), Qt.point(0, corner.height - s - 4), Qt.point(s + 4, corner.height)]
                    }
                }

                ShapePath {
                    fillColor: Qt.darker(BookStyle.paper, BookStyle.lightPaper ? 1.07 : 0.85)
                    strokeColor: BookStyle.line
                    strokeWidth: 0.6

                    PathPolyline {
                        readonly property real s: 30 * corner.shownLift
                        path: corner.onRight
                            ? [Qt.point(corner.width - s, corner.height), Qt.point(corner.width - s, corner.height - s), Qt.point(corner.width, corner.height - s), Qt.point(corner.width - s, corner.height)]
                            : [Qt.point(s, corner.height), Qt.point(s, corner.height - s), Qt.point(0, corner.height - s), Qt.point(s, corner.height)]
                    }
                }
            }

            // Where it leads.
            Glyph {
                visible: corner.shownLift > 0.5
                x: corner.onRight ? corner.width - 30 - 26 : 30
                y: corner.height - 30 - 24
                text: corner.onRight ? "arrow_forward" : "arrow_back"
                font.pixelSize: 14
                color: BookStyle.inkSoft
            }

            MouseArea {
                id: cornerArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: corner.onRight ? book.next() : book.prev()
            }
        }
    }
}
