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
        title: "System Info"
        icon: "󰋖"
    }

    Card {
        Layout.fillWidth: true
        Layout.preferredHeight: infoColumn.implicitHeight + 28

        ColumnLayout {
            id: infoColumn
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            InfoRow {
                Layout.fillWidth: true
                icon: "󰥔"
                label: "Uptime"
                value: Services.System.uptime
            }

            Divider { Layout.fillWidth: true }

            InfoRow {
                Layout.fillWidth: true
                icon: "󰌽"
                label: "Network"
                value: Services.Network.wifiEnabled ? "Connected" : "Disconnected"
            }
        }
    }
}
