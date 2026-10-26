import QtQuick
import qs.colors
import qs.modules.lock
import qs.services as Services

// How well the bar's text reads on its containers: a sample in the bar's
// colours, the WCAG contrast ratio and a word for it. Transparency isn't
// counted (what's behind the containers then is the wallpaper's business).
Row {
    id: root

    readonly property real ratio: Services.BarSettings.contrast(Services.BarSettings.ink, Services.BarSettings.fill)
    readonly property bool poor: root.ratio < 3

    spacing: 10

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        height: 26
        radius: Math.min(BookStyle.b.radius ?? 6, 6)
        color: Services.BarSettings.fill
        border.width: 1
        border.color: BookStyle.line

        Text {
            anchors.centerIn: parent
            text: "Aa"
            font.pixelSize: 13
            font.weight: Font.Bold
            color: Services.BarSettings.ink
        }
    }

    Glyph {
        anchors.verticalCenter: parent.verticalCenter
        text: root.poor ? "warning" : "check_circle"
        filled: true
        font.pixelSize: 16
        color: root.poor ? BookStyle.accent : BookStyle.inkSoft
    }

    BookText {
        anchors.verticalCenter: parent.verticalCenter
        text: (root.ratio >= 7 ? "Very readable" : root.ratio >= 4.5 ? "Readable" : root.ratio >= 3 ? "Readable, just" : "Hard to read")
            + " · " + root.ratio.toFixed(1) + " : 1"
        font.pixelSize: 13
        font.italic: true
        color: root.poor ? BookStyle.accent : BookStyle.inkSoft
    }
}
