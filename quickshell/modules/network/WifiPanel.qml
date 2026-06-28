import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import Quickshell
import qs.services as Services
import "../../colors" as ColorsModule

Item {
    id: wifiRoot

    property string expandedSsid: ""
    readonly property color accent: ColorsModule.Colors.primary

    onVisibleChanged: if (!visible) expandedSsid = ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // ── Hero status card ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 78
            radius: 18
            color: ColorsModule.Colors.surface_container_high
            border.width: 1
            border.color: ColorsModule.Colors.outline_variant

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 14
                spacing: 14

                Rectangle {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    radius: 24
                    color: Services.Network.wifiEnabled
                        ? Qt.rgba(wifiRoot.accent.r, wifiRoot.accent.g, wifiRoot.accent.b, 0.16)
                        : ColorsModule.Colors.surface_container_highest
                    Behavior on color { ColorAnimation { duration: 200 } }

                    Text {
                        anchors.centerIn: parent
                        text: !Services.Network.wifiEnabled
                            ? "󰤭"
                            : (Services.Network.active ? Services.Network.icon : "󰖩")
                        font.family: "Material Design Icons"
                        font.pixelSize: 24
                        color: Services.Network.wifiEnabled
                            ? ColorsModule.Colors.primary
                            : ColorsModule.Colors.on_surface_variant
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: Services.Network.active ? Services.Network.active.name : "Wi-Fi"
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        color: ColorsModule.Colors.on_surface
                    }
                    Text {
                        text: Services.Network.wifiStatus
                        font.pixelSize: 12
                        color: Services.Network.active
                            ? ColorsModule.Colors.primary
                            : ColorsModule.Colors.on_surface_variant
                    }
                }

                // toggle switch
                Rectangle {
                    Layout.preferredWidth: 50
                    Layout.preferredHeight: 28
                    radius: 14
                    color: Services.Network.wifiEnabled
                        ? ColorsModule.Colors.primary
                        : ColorsModule.Colors.surface_container_highest
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        width: 22; height: 22; radius: 11
                        y: 3
                        x: Services.Network.wifiEnabled ? parent.width - width - 3 : 3
                        color: Services.Network.wifiEnabled
                            ? ColorsModule.Colors.on_primary
                            : ColorsModule.Colors.on_surface_variant
                        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Services.Network.toggleWifi()
                    }
                }
            }
        }

        // ── list header ──
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 8
            visible: Services.Network.wifiEnabled

            Text {
                Layout.fillWidth: true
                text: "Available networks"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                font.letterSpacing: 0.3
                color: ColorsModule.Colors.on_surface_variant
            }

            Rectangle {
                Layout.preferredWidth: 30; Layout.preferredHeight: 30
                radius: 15
                color: scanMa.containsMouse ? ColorsModule.Colors.surface_container_highest : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "󰑐"
                    font.family: "Material Design Icons"
                    font.pixelSize: 16
                    color: Services.Network.scanning ? ColorsModule.Colors.primary : ColorsModule.Colors.on_surface_variant
                    RotationAnimator on rotation {
                        from: 0; to: 360; duration: 900; loops: Animation.Infinite
                        running: Services.Network.scanning
                    }
                }
                MouseArea {
                    id: scanMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Services.Network.rescan()
                }
            }
        }

        // ── networks list ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 16
            color: ColorsModule.Colors.surface_container_low

            // empty / off / scanning state
            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 40
                spacing: 6
                visible: Services.Network.connections.filter(c => c.type === "wifi").length === 0

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Services.Network.wifiEnabled ? "󰤭" : "󰖪"
                    font.family: "Material Design Icons"
                    font.pixelSize: 42
                    opacity: 0.5
                    color: ColorsModule.Colors.on_surface_variant
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: !Services.Network.wifiEnabled
                        ? "Wi-Fi is off"
                        : (Services.Network.scanning ? "Scanning…" : "No networks found")
                    color: ColorsModule.Colors.on_surface_variant
                    font.pixelSize: 13
                }
            }

            ScrollView {
                anchors.fill: parent
                anchors.margins: 6
                clip: true
                visible: Services.Network.wifiEnabled
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ColumnLayout {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: Services.Network.connections
                            .filter(c => c.type === "wifi")
                            .sort((a, b) => {
                                if (a.active && !b.active) return -1
                                if (!a.active && b.active) return 1
                                return b.strength - a.strength
                            })

                        delegate: Rectangle {
                            id: row
                            Layout.fillWidth: true
                            Layout.preferredHeight: rowCol.implicitHeight
                            radius: 12

                            property bool isExpanded: wifiRoot.expandedSsid === modelData.name
                            property bool isConnecting: Services.Network.connecting
                                && modelData.name === Services.Network.lastNetworkAttempt
                            property bool hasError: Services.Network.lastErrorMessage !== ""
                                && Services.Network.lastNetworkAttempt === modelData.name

                            color: modelData.active
                                ? Qt.rgba(wifiRoot.accent.r, wifiRoot.accent.g, wifiRoot.accent.b, 0.14)
                                : (rowMa.containsMouse ? ColorsModule.Colors.surface_container_highest
                                                       : ColorsModule.Colors.surface_container)
                            border.width: modelData.active ? 1 : 0
                            border.color: ColorsModule.Colors.primary

                            Behavior on Layout.preferredHeight { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 150 } }

                            ColumnLayout {
                                id: rowCol
                                width: parent.width
                                spacing: 0

                                // ── main row ──
                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 56

                                    MouseArea {
                                        id: rowMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (modelData.active || row.isConnecting) return
                                            if (modelData.isSecure && !modelData.saved) {
                                                wifiRoot.expandedSsid = row.isExpanded ? "" : modelData.name
                                            } else {
                                                Services.Network.connect(modelData, "")
                                            }
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 9
                                        anchors.rightMargin: 8
                                        spacing: 12

                                        Rectangle {
                                            Layout.preferredWidth: 38; Layout.preferredHeight: 38
                                            radius: 19
                                            color: (modelData.active || row.isConnecting)
                                                ? Qt.rgba(wifiRoot.accent.r, wifiRoot.accent.g, wifiRoot.accent.b, 0.18)
                                                : ColorsModule.Colors.surface_container_highest

                                            Text {
                                                anchors.centerIn: parent
                                                font.family: "Material Design Icons"
                                                font.pixelSize: 20
                                                text: {
                                                    if (row.isConnecting) return "󰑐"
                                                    if (modelData.active) return "󰄬"
                                                    const s = modelData.strength
                                                    if (s >= 75) return "󰤨"
                                                    if (s >= 50) return "󰤥"
                                                    if (s >= 25) return "󰤢"
                                                    return "󰤟"
                                                }
                                                color: (modelData.active || row.isConnecting)
                                                    ? ColorsModule.Colors.primary
                                                    : ColorsModule.Colors.on_surface_variant
                                                RotationAnimator on rotation {
                                                    from: 0; to: 360; duration: 900; loops: Animation.Infinite
                                                    running: row.isConnecting
                                                }
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.name
                                                    elide: Text.ElideRight
                                                    font.pixelSize: 14
                                                    font.weight: modelData.active ? Font.DemiBold : Font.Normal
                                                    color: ColorsModule.Colors.on_surface
                                                }
                                                Text {
                                                    visible: modelData.isSecure
                                                    text: "󰌾"
                                                    font.family: "Material Design Icons"
                                                    font.pixelSize: 12
                                                    color: ColorsModule.Colors.on_surface_variant
                                                    opacity: 0.7
                                                }
                                            }

                                            Text {
                                                text: modelData.active ? "Connected"
                                                    : row.isConnecting ? "Connecting…"
                                                    : modelData.saved ? "Saved"
                                                    : (modelData.strength + "% signal")
                                                font.pixelSize: 11
                                                color: modelData.active ? ColorsModule.Colors.primary
                                                                        : ColorsModule.Colors.on_surface_variant
                                            }
                                        }

                                        // forget (saved networks)
                                        Rectangle {
                                            visible: modelData.saved && !row.isConnecting
                                            Layout.preferredWidth: 30; Layout.preferredHeight: 30
                                            radius: 15
                                            opacity: (forgetMa.containsMouse || rowMa.containsMouse) ? 1 : 0
                                            color: forgetMa.containsMouse ? ColorsModule.Colors.error_container : "transparent"
                                            Behavior on opacity { NumberAnimation { duration: 120 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰺝"
                                                font.family: "Material Design Icons"
                                                font.pixelSize: 15
                                                color: forgetMa.containsMouse
                                                    ? ColorsModule.Colors.on_error_container
                                                    : ColorsModule.Colors.on_surface_variant
                                            }
                                            MouseArea {
                                                id: forgetMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: mouse => {
                                                    mouse.accepted = true
                                                    Services.Network.forget(modelData.name)
                                                }
                                            }
                                        }

                                        // disconnect (active network)
                                        Rectangle {
                                            visible: modelData.active
                                            Layout.preferredWidth: 96; Layout.preferredHeight: 32
                                            radius: 16
                                            color: dcMa.containsMouse ? ColorsModule.Colors.primary : "transparent"
                                            border.width: 1
                                            border.color: ColorsModule.Colors.primary

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Disconnect"
                                                font.pixelSize: 12
                                                font.weight: Font.Medium
                                                color: dcMa.containsMouse ? ColorsModule.Colors.on_primary
                                                                          : ColorsModule.Colors.primary
                                            }
                                            MouseArea {
                                                id: dcMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: mouse => {
                                                    mouse.accepted = true
                                                    Services.Network.disconnect()
                                                }
                                            }
                                        }
                                    }
                                }

                                // ── inline password reveal ──
                                Loader {
                                    Layout.fillWidth: true
                                    active: row.isExpanded && !modelData.active
                                    visible: active

                                    sourceComponent: Item {
                                        implicitHeight: 52
                                        Component.onCompleted: pwField.forceActiveFocus()

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 9
                                            anchors.rightMargin: 8
                                            anchors.bottomMargin: 10
                                            spacing: 8

                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 38
                                                radius: 10
                                                color: ColorsModule.Colors.surface_container_highest
                                                border.width: 1.5
                                                border.color: row.hasError
                                                    ? ColorsModule.Colors.error
                                                    : (pwField.activeFocus ? ColorsModule.Colors.primary
                                                                           : ColorsModule.Colors.outline_variant)

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 12
                                                    anchors.rightMargin: 6
                                                    spacing: 6

                                                    TextField {
                                                        id: pwField
                                                        Layout.fillWidth: true
                                                        Layout.alignment: Qt.AlignVCenter
                                                        echoMode: showPw.shown ? TextInput.Normal : TextInput.Password
                                                        placeholderText: row.hasError ? Services.Network.lastErrorMessage : "Password"
                                                        placeholderTextColor: row.hasError
                                                            ? ColorsModule.Colors.error
                                                            : ColorsModule.Colors.on_surface_variant
                                                        color: ColorsModule.Colors.on_surface
                                                        font.pixelSize: 13
                                                        background: Rectangle { color: "transparent" }
                                                        onAccepted: { Services.Network.connect(modelData, text); text = "" }
                                                        Keys.onEscapePressed: wifiRoot.expandedSsid = ""
                                                    }

                                                    Rectangle {
                                                        id: showPw
                                                        property bool shown: false
                                                        Layout.preferredWidth: 28; Layout.preferredHeight: 28
                                                        Layout.alignment: Qt.AlignVCenter
                                                        radius: 14
                                                        color: eyeMa.containsMouse ? ColorsModule.Colors.surface_container : "transparent"
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: showPw.shown ? "󰈉" : "󰈈"
                                                            font.family: "Material Design Icons"
                                                            font.pixelSize: 15
                                                            color: ColorsModule.Colors.on_surface_variant
                                                        }
                                                        MouseArea {
                                                            id: eyeMa
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: showPw.shown = !showPw.shown
                                                        }
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                Layout.preferredWidth: 78; Layout.preferredHeight: 38
                                                radius: 10
                                                color: ColorsModule.Colors.primary
                                                opacity: connMa.containsMouse ? 0.9 : 1
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "Connect"
                                                    font.pixelSize: 12
                                                    font.weight: Font.Medium
                                                    color: ColorsModule.Colors.on_primary
                                                }
                                                MouseArea {
                                                    id: connMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        Services.Network.connect(modelData, pwField.text)
                                                        pwField.text = ""
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
