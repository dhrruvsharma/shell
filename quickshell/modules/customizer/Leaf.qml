import QtQuick

// A right-hand page of settings: the section's heading, a paragraph on
// it (with a raised initial in the themes that letter one), a rule, and
// its Entries. A page that runs long scrolls; most are set to fit.
Item {
    id: leaf

    property string kicker: ""
    property string title: ""
    property string intro: ""
    property real spacing: 24
    default property alias entries: list.data

    anchors.fill: parent

    Column {
        id: head
        width: parent.width
        spacing: 10

        BookText {
            visible: leaf.kicker !== ""
            text: leaf.kicker
            font.family: BookStyle.ui
            font.pixelSize: 12
            font.letterSpacing: 2
            font.capitalization: Font.AllUppercase
            color: BookStyle.accent
        }

        BookText {
            width: parent.width
            text: leaf.title
            wrapMode: Text.WordWrap
            font.family: BookStyle.display
            font.pixelSize: BookStyle.themeId === "gothic" ? 34 : 28
            lineHeight: 1.0
        }

        BookText {
            id: intro
            width: parent.width
            visible: leaf.intro !== ""
            readonly property bool initial: BookStyle.b.dropCap === true && leaf.intro.length > 1
            textFormat: intro.initial ? Text.RichText : Text.PlainText
            text: intro.initial
                ? "<span style=\"font-family:'" + BookStyle.display + "'; font-size:" + Math.round(BookStyle.bodySize * 2.3) + "px; color:" + BookStyle.accent + ";\">" + leaf.intro.charAt(0) + "</span>" + leaf.intro.slice(1).replace(/&/g, "&amp;").replace(/</g, "&lt;")
                : leaf.intro
            wrapMode: Text.WordWrap
            lineHeight: 1.22
            color: BookStyle.inkSoft
        }

        Item {
            width: 1
            height: 2
        }

        Rule {
            width: parent.width
        }
    }

    Flickable {
        id: flick
        anchors.top: head.bottom
        anchors.topMargin: 22
        anchors.bottom: parent.bottom
        width: parent.width + 24
        x: -12
        contentWidth: width
        contentHeight: list.implicitHeight + 16
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: interactive

        Column {
            id: list
            x: 12
            y: 8
            width: leaf.width
            spacing: leaf.spacing
        }
    }
}
