pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.colors
import qs.modules.lock

// Still clock face: a large, thin time and a quiet lowercase date.
Item {
    id: root

    property date now: new Date()
    readonly property string sans: "Adwaita Sans"

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    Column {
        id: col
        spacing: 14

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.35
            shadowBlur: 0.8
            blurMax: 32
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 2
        }

        Row {
            spacing: 14

            Text {
                id: hm
                text: Qt.formatDateTime(root.now, "h:mm")
                font.family: root.sans
                font.pixelSize: 150
                font.weight: Font.ExtraLight
                color: Colors.on_surface
            }

            Text {
                anchors.baseline: hm.baseline
                text: Qt.formatDateTime(root.now, "ap")
                font.family: root.sans
                font.pixelSize: 26
                font.weight: Font.Light
                color: LockTheme.alpha(Colors.on_surface, 0.7)
            }
        }

        Rectangle {
            x: 6
            width: 56
            height: 2
            radius: 1
            color: Colors.primary
        }

        Text {
            x: 6
            text: Qt.formatDateTime(root.now, "dddd, d MMMM").toLowerCase()
            font.family: root.sans
            font.pixelSize: 22
            font.weight: Font.Light
            font.letterSpacing: 0.5
            color: LockTheme.alpha(Colors.on_surface, 0.78)
        }
    }
}
