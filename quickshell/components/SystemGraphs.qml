import QtQuick
import qs.services as Services
import qs.components
import qs.colors

Item {
    width: 380
    height: 120

    Row {
        anchors.centerIn: parent
        spacing: 12

        // CPU Card
        Rectangle {
            width: 115
            height: 95
            radius: 12
            color: Colors.surface_container_high

            SemiCircularGraph {
                anchors.centerIn: parent
                value: Services.System.cpu
                fillColor: Colors.error
                label: "CPU"
                width: 95
                height: 55
            }
        }

        // RAM Card
        Rectangle {
            width: 115
            height: 95
            radius: 12
            color: Colors.surface_container_high

            SemiCircularGraph {
                anchors.centerIn: parent
                value: Services.System.ram
                fillColor: Colors.primary
                label: "RAM"
                width: 95
                height: 55
            }
        }

        // DISK Card
        Rectangle {
            width: 115
            height: 95
            radius: 12
            color: Colors.surface_container_high

            SemiCircularGraph {
                anchors.centerIn: parent
                value: Services.System.disk
                fillColor: Colors.tertiary
                label: "DISK"
                width: 95
                height: 55
            }
        }
    }
}