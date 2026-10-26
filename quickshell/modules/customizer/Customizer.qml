pragma ComponentBehavior: Bound
import QtQuick
import qs.colors
import qs.services as Services

// The customizer: a book of everything that can be set (SUPER+I, the gear
// on the bar or SUPER+B for its chapter on the bar, `qs ipc call customizer
// toggle [chapter]`). It opens on its cover, which swings over to the
// first page asked for; a tab, the ribbon, a page corner or the contents
// turn to the others. The left-hand page of each spread draws what's set
// on the right-hand one, live.
//
// It lies in the room the bar leaves and stays under the bar, so what's
// set on the bar shows on the bar itself as well. Keys: ←→ (or PgUp/PgDn)
// turn a page, Home the contents, 1–8 a chapter, Esc closes.
Item {
    id: root

    anchors.fill: parent
    visible: false

    // Where it should open (a spread's index), and where it was left.
    property int lastSpread: 0
    readonly property alias book: bookItem

    function open(where) {
        const i = BookContents.resolve(where);
        const at = i >= 0 ? i : root.lastSpread;
        if (root.visible && !closeFade.running && !bookItem.shut) {
            bookItem.go(at);
            return;
        }
        closeFade.stop();
        root.visible = true;
        Services.Customizer.opened(true);
        root.forceActiveFocus();
        scrim.opacity = 0;
        stage.opacity = 0;
        openFade.restart();
        bookItem.openAt(at);
    }

    function close() {
        if (!root.visible || bookItem.shut && !bookItem.turning)
            return;
        root.lastSpread = bookItem.current;
        Services.Customizer.opened(false);
        bookItem.close();
        closeFade.restart();
    }

    function toggle(where) {
        if (root.visible && !bookItem.shut && !closeFade.running) {
            const i = BookContents.resolve(where);
            if (i >= 0 && BookContents.spreads[i].chapter !== BookContents.spreads[bookItem.current].chapter)
                bookItem.go(i);
            else
                root.close();
        } else {
            root.open(where);
        }
    }

    Component.onDestruction: Services.Customizer.opened(false)

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.close();
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_PageDown) {
            bookItem.next();
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_PageUp) {
            bookItem.prev();
        } else if (event.key === Qt.Key_Home) {
            bookItem.go(0);
        } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_8) {
            bookItem.go(BookContents.chapterStart(event.key - Qt.Key_0));
        } else {
            return;
        }
        event.accepted = true;
    }

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Colors.scrim
        opacity: 0

        MouseArea {
            anchors.fill: parent
            enabled: root.visible
            onClicked: root.close()
        }
    }

    ParallelAnimation {
        id: openFade
        NumberAnimation { target: scrim; property: "opacity"; to: 0.55; duration: 320; easing.type: Easing.OutCubic }
        NumberAnimation { target: stage; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
        NumberAnimation { target: stage; property: "lift"; from: 40; to: 0; duration: 520; easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        id: closeFade
        PauseAnimation { duration: 420 }
        ParallelAnimation {
            NumberAnimation { target: scrim; property: "opacity"; to: 0; duration: 260; easing.type: Easing.InCubic }
            NumberAnimation { target: stage; property: "opacity"; to: 0; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: stage; property: "lift"; to: 30; duration: 260; easing.type: Easing.InCubic }
        }
        ScriptAction { script: root.visible = false }
    }

    // The book, centred in the room the bar leaves, made smaller to fit a
    // smaller screen. Clicks on it stay on it.
    Item {
        id: stage

        property real lift: 0

        readonly property real roomW: root.width - Services.BarLayout.reserveLeft - Services.BarLayout.reserveRight
        readonly property real roomH: root.height - Services.BarLayout.reserveTop - Services.BarLayout.reserveBottom
        // The book with its boards and its tabs.
        readonly property real fullW: bookItem.width + 2 * bookItem.board + 2 * 44
        readonly property real fullH: bookItem.height + 2 * bookItem.board + 60
        readonly property real fit: Math.min(1, (stage.roomW - 24) / stage.fullW, (stage.roomH - 24) / stage.fullH)

        x: Services.BarLayout.reserveLeft + (stage.roomW - bookItem.width * stage.fit) / 2
        y: Services.BarLayout.reserveTop + (stage.roomH - bookItem.height * stage.fit) / 2 - 12 * stage.fit + stage.lift
        width: bookItem.width
        height: bookItem.height
        scale: stage.fit
        transformOrigin: Item.TopLeft
        opacity: 0

        MouseArea {
            x: -bookItem.board
            y: -bookItem.board
            width: bookItem.width + 2 * bookItem.board
            height: bookItem.height + 2 * bookItem.board
            onClicked: root.forceActiveFocus()
        }

        Book {
            id: bookItem
            onClosed: root.visible = false
        }
    }
}
