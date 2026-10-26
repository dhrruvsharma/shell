pragma ComponentBehavior: Bound
import QtQuick

// Two facing pages of the book: the plate on the left (what's being set,
// drawn), the settings on the right. Each page has its stock, a running
// head and its folio, and a content area inside the margins that the
// spreads (spreads/) fill through `leftContent` and `rightContent`.
//
// The right page says what the pointer is on (`focusKey`, set by its
// Entries), so the plate can show that part.
Item {
    id: spread

    property real pageW: 740
    property real pageH: 900
    // The left page's number (the right one's is one more).
    property int number: 2
    // Running heads: the chapter on the left, the section on the right.
    property string chapterTitle: ""
    property string sectionTitle: ""
    // The book (for spreads that turn to another page, like the contents).
    property var book: null
    // What the right page is pointing at ("" for nothing).
    property string focusKey: ""
    property bool runningHeads: true

    readonly property real marginOuter: 58
    readonly property real marginInner: 50
    readonly property real marginTop: 70
    readonly property real marginFoot: 74

    property alias leftPage: leftPage
    property alias rightPage: rightPage
    default property alias rightContent: rightArea.data
    property alias leftContent: leftArea.data

    width: spread.pageW * 2
    height: spread.pageH

    // ── Left page ────────────────────────────────────────────────────────────
    Item {
        id: leftPage
        width: spread.pageW
        height: spread.pageH

        Paper {
            anchors.fill: parent
            spineSide: 0
            seed: spread.number
        }

        Head {
            x: spread.marginOuter
            width: parent.width - spread.marginOuter - spread.marginInner
            text: spread.chapterTitle
            alignRight: false
        }

        Item {
            id: leftArea
            x: spread.marginOuter
            y: spread.marginTop
            width: parent.width - spread.marginOuter - spread.marginInner
            height: parent.height - spread.marginTop - spread.marginFoot
        }

        Folio {
            anchors.horizontalCenter: leftArea.horizontalCenter
            y: parent.height - 46
            number: spread.number
        }
    }

    // ── Right page ───────────────────────────────────────────────────────────
    Item {
        id: rightPage
        x: spread.pageW
        width: spread.pageW
        height: spread.pageH

        Paper {
            anchors.fill: parent
            spineSide: 1
            seed: spread.number + 1
        }

        Head {
            x: spread.marginInner
            width: parent.width - spread.marginOuter - spread.marginInner
            text: spread.sectionTitle
            alignRight: true
        }

        Item {
            id: rightArea
            x: spread.marginInner
            y: spread.marginTop
            width: parent.width - spread.marginOuter - spread.marginInner
            height: parent.height - spread.marginTop - spread.marginFoot
        }

        Folio {
            anchors.horizontalCenter: rightArea.horizontalCenter
            y: parent.height - 46
            number: spread.number + 1
        }
    }

    // A running head: small, spaced capitals on the outer side, over a rule.
    component Head: Item {
        id: head

        property string text: ""
        property bool alignRight: false

        y: 30
        height: 22
        visible: spread.runningHeads && head.text !== ""

        BookText {
            anchors.left: head.alignRight ? undefined : parent.left
            anchors.right: head.alignRight ? parent.right : undefined
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 5
            text: head.text
            font.family: BookStyle.ui
            font.pixelSize: 11
            font.letterSpacing: 2.2
            font.capitalization: Font.AllUppercase
            color: BookStyle.inkSoft
        }

        Rule {
            anchors.bottom: parent.bottom
            width: parent.width
            kind: (BookStyle.b.rule ?? "single") === "none" ? "none" : "single"
        }
    }
}
