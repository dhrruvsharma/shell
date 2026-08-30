import QtQuick.Layouts
import qs.components
import qs.services as Services

ColumnLayout {
    Layout.fillWidth: true
    Layout.leftMargin: 20
    Layout.rightMargin: 20
    Layout.topMargin: 20
    spacing: 14

    SectionHeader {
        title: "System Resources"
        icon: "󰍛"
    }

    Card {
        Layout.fillWidth: true
        Layout.preferredHeight: statsColumn.implicitHeight + 28

        ColumnLayout {
            id: statsColumn
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            StatBar {
                Layout.fillWidth: true
                label: "CPU"
                value: Services.System.cpu
                icon: "󰻠"
            }

            Divider { Layout.fillWidth: true }

            StatBar {
                Layout.fillWidth: true
                label: "RAM"
                value: Services.System.ram
                icon: "󰍛"
            }

            Divider { Layout.fillWidth: true }

            StatBar {
                Layout.fillWidth: true
                label: "Disk"
                value: Services.System.disk
                icon: "󰋊"
            }

            Divider { Layout.fillWidth: true }

            StatBar {
                Layout.fillWidth: true
                label: "Temp"
                value: Services.System.temp
                icon: "󰔏"
                maxValue: 100
                suffix: "°C"
            }
        }
    }
}
