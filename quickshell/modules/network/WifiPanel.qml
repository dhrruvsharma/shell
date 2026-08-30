import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import Quickshell
import qs.services as Services
import qs.colors
import qs.components

Item {
    id: wifiRoot

    property string expandedSsid: ""
    readonly property color accent: Colors.primary

    onVisibleChanged: if (!visible) expandedSsid = ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // ── Hero status card ──
        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: 78
            radius: 18
            color: Colors.surface_container_high

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
                        : Colors.surface_container_highest
                    Behavior on color { ColorAnimation { duration: 200 } }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: !Services.Network.wifiEnabled
                            ? "󰤭"
                            : (Services.Network.active ? Services.Network.icon : "󰖩")
                        font.pixelSize: 24
                        color: Services.Network.wifiEnabled
                            ? Colors.primary
                            : Colors.on_surface_variant
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: Services.Network.active ? Services.Network.active.name : "Wi-Fi"
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        text: Services.Network.wifiStatus
                        font.pixelSize: 12
                        color: Services.Network.active
                            ? Colors.primary
                            : Colors.on_surface_variant
                    }
                }

                // toggle switch
                Rectangle {
                    Layout.preferredWidth: 50
                    Layout.preferredHeight: 28
                    radius: 14
                    color: Services.Network.wifiEnabled
                        ? Colors.primary
                        : Colors.surface_container_highest
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        width: 22; height: 22; radius: 11
                        y: 3
                        x: Services.Network.wifiEnabled ? parent.width - width - 3 : 3
                        color: Services.Network.wifiEnabled
                            ? Colors.on_primary
                            : Colors.on_surface_variant
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

            StyledText {
                Layout.fillWidth: true
                text: "Available networks"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                font.letterSpacing: 0.3
                color: Colors.on_surface_variant
            }

            ClickableRect {
                id: scanRect
                Layout.preferredWidth: 30; Layout.preferredHeight: 30
                radius: 15
                color: scanRect.hovered ? Colors.surface_container_highest : "transparent"
                MaterialIcon {
                    anchors.centerIn: parent
                    text: "󰑐"
                    font.pixelSize: 16
                    color: Services.Network.scanning ? Colors.primary : Colors.on_surface_variant
                    RotationAnimator on rotation {
                        from: 0; to: 360; duration: 900; loops: Animation.Infinite
                        running: Services.Network.scanning
                    }
                }
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.Network.rescan()
            }
        }

        // ── networks list ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 16
            color: Colors.surface_container_low

            // empty / off / scanning state
            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 40
                spacing: 6
                visible: Services.Network.connections.filter(c => c.type === "wifi").length === 0

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: Services.Network.wifiEnabled ? "󰤭" : "󰖪"
                    font.pixelSize: 42
                    opacity: 0.5
                    color: Colors.on_surface_variant
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: !Services.Network.wifiEnabled
                        ? "Wi-Fi is off"
                        : (Services.Network.scanning ? "Scanning…" : "No networks found")
                    color: Colors.on_surface_variant
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
                                : (rowMa.containsMouse ? Colors.surface_container_highest
                                                       : Colors.surface_container)
                            border.width: modelData.active ? 1 : 0
                            border.color: Colors.primary

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
                                                : Colors.surface_container_highest

                                            MaterialIcon {
                                                anchors.centerIn: parent
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
                                                    ? Colors.primary
                                                    : Colors.on_surface_variant
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
                                                StyledText {
                                                    Layout.fillWidth: true
                                                    text: modelData.name
                                                    elide: Text.ElideRight
                                                    font.pixelSize: 14
                                                    font.weight: modelData.active ? Font.DemiBold : Font.Normal
                                                }
                                                MaterialIcon {
                                                    visible: modelData.isSecure
                                                    text: "󰌾"
                                                    font.pixelSize: 12
                                                    color: Colors.on_surface_variant
                                                    opacity: 0.7
                                                }
                                            }

                                            StyledText {
                                                text: modelData.active ? "Connected"
                                                    : row.isConnecting ? "Connecting…"
                                                    : modelData.saved ? "Saved"
                                                    : (modelData.strength + "% signal")
                                                font.pixelSize: 11
                                                color: modelData.active ? Colors.primary
                                                                        : Colors.on_surface_variant
                                            }
                                        }

                                        // forget (saved networks)
                                        ClickableRect {
                                            id: forgetRect
                                            visible: modelData.saved && !row.isConnecting
                                            Layout.preferredWidth: 30; Layout.preferredHeight: 30
                                            radius: 15
                                            opacity: (forgetRect.hovered || rowMa.containsMouse) ? 1 : 0
                                            color: forgetRect.hovered ? Colors.error_container : "transparent"
                                            Behavior on opacity { NumberAnimation { duration: 120 } }

                                            MaterialIcon {
                                                anchors.centerIn: parent
                                                text: "󰺝"
                                                font.pixelSize: 15
                                                color: forgetRect.hovered
                                                    ? Colors.on_error_container
                                                    : Colors.on_surface_variant
                                            }
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: mouse => {
                                                    mouse.accepted = true
                                                    Services.Network.forget(modelData.name)
                                                }
                                        }

                                        // disconnect (active network)
                                        ClickableRect {
                                            id: dcRect
                                            visible: modelData.active
                                            Layout.preferredWidth: 96; Layout.preferredHeight: 32
                                            radius: 16
                                            color: dcRect.hovered ? Colors.primary : "transparent"
                                            border.width: 1
                                            border.color: Colors.primary

                                            StyledText {
                                                anchors.centerIn: parent
                                                text: "Disconnect"
                                                font.pixelSize: 12
                                                font.weight: Font.Medium
                                                color: dcRect.hovered ? Colors.on_primary
                                                                          : Colors.primary
                                            }
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: mouse => {
                                                    mouse.accepted = true
                                                    Services.Network.disconnect()
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
                                                color: Colors.surface_container_highest
                                                border.width: 1.5
                                                border.color: row.hasError
                                                    ? Colors.error
                                                    : (pwField.activeFocus ? Colors.primary
                                                                           : Colors.outline_variant)

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
                                                            ? Colors.error
                                                            : Colors.on_surface_variant
                                                        color: Colors.on_surface
                                                        font.pixelSize: 13
                                                        background: Rectangle { color: "transparent" }
                                                        onAccepted: { Services.Network.connect(modelData, text); text = "" }
                                                        Keys.onEscapePressed: wifiRoot.expandedSsid = ""
                                                    }

                                                    ClickableRect {
                                                        id: showPw
                                                        property bool shown: false
                                                        Layout.preferredWidth: 28; Layout.preferredHeight: 28
                                                        Layout.alignment: Qt.AlignVCenter
                                                        radius: 14
                                                        color: showPw.hovered ? Colors.surface_container : "transparent"
                                                        MaterialIcon {
                                                            anchors.centerIn: parent
                                                            text: showPw.shown ? "󰈉" : "󰈈"
                                                            font.pixelSize: 15
                                                            color: Colors.on_surface_variant
                                                        }
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: showPw.shown = !showPw.shown
                                                    }
                                                }
                                            }

                                            ClickableRect {
                                                id: connRect
                                                Layout.preferredWidth: 78; Layout.preferredHeight: 38
                                                radius: 10
                                                color: Colors.primary
                                                opacity: connRect.hovered ? 0.9 : 1
                                                StyledText {
                                                    anchors.centerIn: parent
                                                    text: "Connect"
                                                    font.pixelSize: 12
                                                    font.weight: Font.Medium
                                                    color: Colors.on_primary
                                                }
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
