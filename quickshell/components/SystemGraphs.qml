import QtQuick
import qs.services as Services
import qs.components
import qs.colors

// CPU, memory and disk as three gauge cards in a row; stacked, and as wide
// as the system panel's tabs, beside a standing bar (`vertical`).
Item {
    id: root

    property bool vertical: false

    width: root.vertical ? 188 : 380
    height: root.vertical ? cards.implicitHeight : 120

    component GaugeCard: Rectangle {
        property alias value: gauge.value
        property alias fillColor: gauge.fillColor
        property alias label: gauge.label

        width: root.vertical ? 188 : 115
        height: root.vertical ? 84 : 95
        radius: Services.DesktopTheme.rad(12)
        color: Colors.surface_container_high

        SemiCircularGraph {
            id: gauge
            anchors.centerIn: parent
            width: 95
            height: 55
        }
    }

    Grid {
        id: cards
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 3
        spacing: root.vertical ? 10 : 12

        GaugeCard {
            value: Services.System.cpu
            fillColor: Colors.error
            label: "CPU"
        }

        GaugeCard {
            value: Services.System.ram
            fillColor: Colors.primary
            label: "RAM"
        }

        GaugeCard {
            value: Services.System.disk
            fillColor: Colors.tertiary
            label: "DISK"
        }
    }
}
