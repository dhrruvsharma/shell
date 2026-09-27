pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.colors

// Clock face without a desktop theme: time and date on the wallpaper in the
// shell's own type.
Item {
    id: root

    property date now: new Date()

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    Column {
        id: col
        spacing: 2

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.4
            shadowBlur: 0.8
            blurMax: 32
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 2
        }

        Row {
            spacing: 10

            Text {
                id: hm
                text: Qt.formatDateTime(root.now, "hh:mm")
                font.pixelSize: 96
                font.weight: Font.Bold
                color: Colors.on_surface
            }

            Text {
                anchors.baseline: hm.baseline
                text: Qt.formatDateTime(root.now, "AP")
                font.pixelSize: 24
                font.weight: Font.DemiBold
                color: Colors.primary
            }
        }

        Text {
            x: 4
            text: Qt.formatDateTime(root.now, "dddd, d MMMM")
            font.pixelSize: 20
            color: Colors.withAlpha(Colors.on_surface, 0.8)
        }
    }
}
