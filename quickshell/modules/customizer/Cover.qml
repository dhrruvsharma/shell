import QtQuick
import Quickshell
import qs.colors
import qs.components
import qs.modules.desktoptheme
import qs.modules.lock
import qs.services as Services

// The book's front cover: the theme's binding (its cloth and its frame,
// as its panels wear it), the title stamped on it, the theme's emblem, and
// whose book it is. It's seen as the book opens and closes.
Item {
    id: cover

    Paper {
        anchors.fill: parent
        paper: BookStyle.cover
        shade: Qt.darker(BookStyle.cover, 1.8)
        spineSide: 1
        grain: 0.9
        fibres: 0.6
        age: 0.5
        gutter: 0.35
        pattern: 0
        seed: 9
    }

    // The theme's frame, as on its panels; an inset double rule without one.
    Item {
        anchors.fill: parent
        anchors.margins: 26

        Rectangle {
            anchors.fill: parent
            visible: BookStyle.themeId === "" || BookStyle.themeId === "zen"
            color: "transparent"
            border.width: 1
            border.color: Colors.withAlpha(BookStyle.coverInk, 0.55)

            Rectangle {
                anchors.fill: parent
                anchors.margins: 6
                color: "transparent"
                border.width: 1
                border.color: Colors.withAlpha(BookStyle.coverInk, 0.3)
            }
        }

        PanelDecor {
            anchors.fill: parent
            radius: Services.DesktopTheme.panelRadius(8)
            title: "customize"
        }
    }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -40
        width: parent.width - 140
        spacing: 18

        Emblem {
            anchors.horizontalCenter: parent.horizontalCenter
            size: 54
            ink: BookStyle.coverInk
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 120
            height: 1
            color: Colors.withAlpha(BookStyle.coverInk, 0.6)
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: BookStyle.b.title
            wrapMode: Text.WordWrap
            font.family: BookStyle.b.cjk && /[^\x00-\x7f]/.test(BookStyle.b.title) ? BookStyle.cjk : BookStyle.display
            font.pixelSize: /[^\x00-\x7f]/.test(BookStyle.b.title) ? 74 : BookStyle.b.title.length > 14 ? 40 : 50
            font.letterSpacing: 1
            color: BookStyle.coverInk
            lineHeight: 0.95
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: BookStyle.b.subtitle
            wrapMode: Text.WordWrap
            font.family: BookStyle.body
            font.pixelSize: 17
            font.italic: true
            color: Colors.withAlpha(BookStyle.coverInk, 0.8)
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 120
            height: 1
            color: Colors.withAlpha(BookStyle.coverInk, 0.6)
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 64
        text: (Quickshell.env("USER") || "") + "  ·  " + Clocks.roman(new Date().getFullYear())
        font.family: BookStyle.ui
        font.pixelSize: 13
        font.letterSpacing: 3
        font.capitalization: Font.AllUppercase
        color: Colors.withAlpha(BookStyle.coverInk, 0.7)
    }
}
