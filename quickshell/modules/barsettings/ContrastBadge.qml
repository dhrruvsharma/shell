import QtQuick
import qs.colors
import qs.components
import qs.modules.lock
import qs.services as Services

// How well the bar's text reads on its containers: a sample, the WCAG
// contrast ratio and a word for it. Transparency isn't counted (what's
// behind the containers then is the wallpaper's business).
Rectangle {
    id: root

    readonly property real ratio: Services.BarSettings.contrast(Services.BarSettings.ink, Services.BarSettings.fill)
    readonly property bool poor: root.ratio < 3

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 28
    radius: Services.DesktopTheme.rad(14)
    color: root.poor ? Colors.withAlpha(Colors.error_container, 0.6) : Colors.surface_container

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 20
            radius: Services.DesktopTheme.rad(6)
            color: Services.BarSettings.fill
            border.width: 1
            border.color: Colors.withAlpha(Colors.on_surface, 0.15)

            StyledText {
                anchors.centerIn: parent
                text: "Aa"
                font.pixelSize: 12
                font.weight: Font.Bold
                color: Services.BarSettings.ink
            }
        }

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: root.poor ? "warning" : "check_circle"
            filled: true
            font.pixelSize: 15
            color: root.poor ? Colors.error : root.ratio >= 4.5 ? Colors.primary : Colors.on_surface_variant
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: (root.ratio >= 7 ? "Very readable" : root.ratio >= 4.5 ? "Readable" : root.ratio >= 3 ? "Readable, just" : "Hard to read")
                + " · " + root.ratio.toFixed(1) + ":1"
            font.pixelSize: 12
            font.weight: Font.Medium
            color: root.poor ? Colors.on_error_container : Colors.on_surface_variant
        }
    }
}
