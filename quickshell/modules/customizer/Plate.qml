import QtQuick

// A left-hand page: the chapter's number and title (large on its first
// spread, a line on the ones after), an epigraph, and the plate itself, a
// live figure of what the facing page sets, framed in the theme's manner
// and captioned. The figure goes in as the default content and fills the
// frame.
Item {
    id: plate

    property int chapter: 1
    property string title: ""
    property string epigraph: ""
    // The chapter's first spread: the big numeral and title.
    property bool opening: true
    // On the spreads after: the section's own title.
    property string section: ""
    property string figure: ""
    property string caption: ""
    default property alias content: figArea.data
    // The figure's frame drops away (a figure that draws its own).
    property bool framed: true

    anchors.fill: parent

    Column {
        id: head
        width: parent.width
        spacing: 6

        BookText {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: plate.opening
            text: "Chapter"
            font.family: BookStyle.ui
            font.pixelSize: 12
            font.letterSpacing: 4
            font.capitalization: Font.AllUppercase
            color: BookStyle.inkSoft
        }

        BookText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: plate.opening ? BookStyle.roman(plate.chapter).toUpperCase() : BookStyle.roman(plate.chapter).toUpperCase() + "  ·  " + plate.title
            font.family: plate.opening ? BookStyle.numeral : BookStyle.ui
            font.pixelSize: plate.opening ? 64 : 12
            font.letterSpacing: plate.opening ? 2 : 3
            font.capitalization: plate.opening ? Font.MixedCase : Font.AllUppercase
            color: plate.opening ? BookStyle.accent : BookStyle.inkSoft
            lineHeight: 0.95
        }

        BookText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: plate.opening ? plate.title : plate.section
            wrapMode: Text.WordWrap
            font.family: BookStyle.display
            font.pixelSize: plate.opening ? 32 : 28
            lineHeight: 1.0
        }

        Item {
            width: 1
            height: 4
        }

        Fleuron {
            anchors.horizontalCenter: parent.horizontalCenter
            span: 90
        }

        BookText {
            width: parent.width
            visible: plate.epigraph !== ""
            topPadding: 4
            horizontalAlignment: Text.AlignHCenter
            text: plate.epigraph
            wrapMode: Text.WordWrap
            font.italic: true
            font.pixelSize: BookStyle.bodySize
            color: BookStyle.inkSoft
        }
    }

    Item {
        id: frameBox
        anchors.top: head.bottom
        anchors.topMargin: 24
        anchors.bottom: captionText.top
        anchors.bottomMargin: 14
        width: parent.width

        Item {
            id: figArea
            anchors.fill: parent
            anchors.margins: plate.framed ? 14 : 0
        }

        PlateFrame {
            anchors.fill: parent
            visible: plate.framed
        }
    }

    BookText {
        id: captionText
        anchors.bottom: parent.bottom
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: (plate.figure ? plate.figure + "  " : "") + plate.caption
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
        font.italic: true
        font.pixelSize: BookStyle.bodySize - 1
        color: BookStyle.inkSoft
    }
}
