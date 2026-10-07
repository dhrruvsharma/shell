pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services as Services
import qs.colors
import qs.components

// The airwaves round this computer. The Wi-Fi tab draws the channels as a
// spectrum, a ridge per access point over the band it occupies, above the
// connection and the networks in range (WifiPanel); the Bluetooth tab puts
// the devices in orbit round the computer (BluetoothPanel). A tab's head
// shows its radio's state and switch. Slides in from the right edge;
// shell.qml opens it on a tab, and on the Bluetooth one when bluetoothd
// has a question.
Item {
    id: networkPanel
    anchors.fill: parent
    visible: false

    property bool opened: false
    property int currentTab: 0

    readonly property color accent: Services.DesktopTheme.accent
    readonly property var adapter: Services.Bluetooth.defaultAdapter

    onOpenedChanged: {
        if (opened) {
            visible = true
            panel.x = networkPanel.width
            scrim.opacity = 0
            openAnim.restart()
            Services.Network.refresh()
        } else {
            closeAnim.restart()
        }
    }

    function close() {
        opened = false
    }

    // Dark or light ink, whichever reads on `c`.
    function inkOn(c) {
        const q = Qt.color(c)
        return 0.2126 * q.r + 0.7152 * q.g + 0.0722 * q.b > 0.5 ? Qt.rgba(0, 0, 0, 0.78) : Qt.rgba(1, 1, 1, 0.92)
    }

    // ── Scrim ─────────────────────────────────────────────────────────────────

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Colors.scrim
        opacity: 0
        enabled: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        MouseArea {
            anchors.fill: parent
            enabled: parent.enabled
            onClicked: networkPanel.close()
        }
    }

    // ── Panel ─────────────────────────────────────────────────────────────────

    Card {
        id: panel

        PanelDecor {
            radius: panel.radius
            title: "network"
        }
        width: 400
        height: 680
        anchors.bottom: parent.bottom
        x: networkPanel.width

        radius: Services.DesktopTheme.rad(22)
        color: Colors.surface_container

        layer.enabled: true
        layer.smooth: true

        // subtle top accent wash
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Colors.withAlpha(networkPanel.accent, 0.06) }
                GradientStop { position: 0.3; color: "transparent" }
            }
        }

        FocusScope {
            anchors.fill: parent
            focus: networkPanel.opened

            Keys.onEscapePressed: networkPanel.close()
            Keys.onLeftPressed: networkPanel.currentTab = 0
            Keys.onRightPressed: networkPanel.currentTab = 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                anchors.topMargin: 14
                spacing: 12

                // ── The two radios: name, state and switch; the lit one is the tab shown ──
                Item {
                    id: tabBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48

                    Row {
                        anchors.fill: parent

                        RadioTab {
                            index: 0
                            label: "Wi-Fi"
                            on: Services.Network.wifiEnabled
                            status: !Services.Network.wifiEnabled ? "Off"
                                : Services.Network.connecting ? "Connecting to " + Services.Network.lastNetworkAttempt + "…"
                                : Services.Network.active?.type === "wifi" ? Services.Network.active.name
                                : Services.Network.active ? Services.Network.active.name + " (wired)"
                                : "Not connected"
                            linked: Services.Network.active !== null
                            onSwitched: Services.Network.toggleWifi()
                        }

                        RadioTab {
                            index: 1
                            label: "Bluetooth"
                            on: networkPanel.adapter?.enabled ?? false
                            available: networkPanel.adapter !== null
                            status: {
                                if (!networkPanel.adapter)
                                    return "No adapter"
                                if (!networkPanel.adapter.enabled)
                                    return "Off"
                                const linked = Services.Bluetooth.devices.filter(d => d.connected && d.paired)
                                if (linked.length > 1)
                                    return linked.length + " connected"
                                if (linked.length === 1)
                                    return linked[0].name || "Connected"
                                const paired = Services.Bluetooth.devices.filter(d => d.paired).length
                                return paired > 0 ? paired + " paired" : "On"
                            }
                            linked: Services.Bluetooth.activeDevice !== null
                            // bluetoothd is waiting on an answer in this tab
                            calling: Services.Bluetooth.request !== null
                            onSwitched: {
                                if (networkPanel.adapter)
                                    networkPanel.adapter.enabled = !networkPanel.adapter.enabled
                            }
                        }
                    }

                    // the rule under both, lit under the tab shown
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: Colors.withAlpha(Colors.outline_variant, 0.8)
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        x: networkPanel.currentTab * tabBar.width / 2
                        width: tabBar.width / 2
                        height: 2
                        radius: Services.DesktopTheme.rad(1)
                        color: networkPanel.accent
                        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    }
                }

                Loader {
                    id: tabLoader
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: networkPanel.currentTab === 0
                        ? wifiComponent
                        : bluetoothComponent

                    // the tab comes in from its side
                    onLoaded: tabIn.restart()
                    ParallelAnimation {
                        id: tabIn
                        NumberAnimation {
                            target: tabLoader.item
                            property: "opacity"
                            from: 0; to: 1
                            duration: 240; easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: tabLoader.item
                            property: "x"
                            from: networkPanel.currentTab === 0 ? -18 : 18; to: 0
                            duration: 300; easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }

    component RadioTab: Item {
        id: tab

        required property int index
        property string label
        property string status
        property bool on
        property bool available: true
        // connected to something
        property bool linked
        property bool calling: false
        readonly property bool selected: networkPanel.currentTab === index

        signal switched

        width: tabBar.width / 2
        height: tabBar.height

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: networkPanel.currentTab = tab.index
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: tab.index === 0 ? 2 : 14
            anchors.right: toggle.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -2
            spacing: 1

            Row {
                spacing: 7

                StyledText {
                    text: tab.label
                    font.pixelSize: 17
                    font.weight: tab.selected ? Font.DemiBold : Font.Medium
                    color: tab.selected ? Colors.on_surface : Colors.withAlpha(Colors.on_surface_variant, 0.75)
                    Behavior on color { ColorAnimation { duration: 160 } }
                }

                // connected: a lit dot; asked something: a ringing one
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 1
                    visible: tab.on && (tab.linked || tab.calling)
                    width: 6
                    height: 6
                    radius: 3
                    color: tab.calling && !tab.selected ? Colors.tertiary : networkPanel.accent
                }
            }

            StyledText {
                width: parent.width
                text: tab.status
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.pixelSize: 11
                color: tab.on && tab.linked
                    ? Colors.withAlpha(networkPanel.accent, tab.selected ? 1 : 0.7)
                    : Colors.withAlpha(Colors.on_surface_variant, tab.selected ? 0.9 : 0.6)
            }
        }

        // the radio's switch
        Rectangle {
            id: toggle
            anchors.right: parent.right
            anchors.rightMargin: tab.index === 0 ? 14 : 2
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -2
            width: 34
            height: 20
            radius: Services.DesktopTheme.rad(10)
            opacity: tab.available ? 1 : 0.4
            color: tab.on ? networkPanel.accent : "transparent"
            border.width: tab.on ? 0 : 1
            border.color: Colors.outline
            Behavior on color { ColorAnimation { duration: 160 } }

            Rectangle {
                width: 12
                height: 12
                radius: Services.DesktopTheme.rad(6)
                y: 4
                x: tab.on ? toggle.width - width - 4 : 4
                color: tab.on ? networkPanel.inkOn(networkPanel.accent) : Colors.outline
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                enabled: tab.available
                cursorShape: Qt.PointingHandCursor
                onClicked: tab.switched()
            }
        }
    }

    // ── Animations ────────────────────────────────────────────────────────────

    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: scrim; property: "opacity"
            to: 0.45; duration: 280; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: panel; property: "x"
            to: networkPanel.width - panel.width
            duration: 320; easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation {
            target: scrim; property: "opacity"
            to: 0; duration: 200; easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: panel; property: "x"
            to: networkPanel.width
            duration: 260; easing.type: Easing.InCubic
        }
        onFinished: networkPanel.visible = false
    }

    Component { id: wifiComponent;      WifiPanel      {} }
    Component { id: bluetoothComponent; BluetoothPanel {} }
}
