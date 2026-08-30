import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.colors
import qs.components

Item {
    id: networkPanel
    anchors.fill: parent
    visible: false

    property bool opened: false
    property int currentTab: 0

    onOpenedChanged: {
        if (opened) {
            visible = true
            panel.x = networkPanel.width
            scrim.opacity = 0
            openAnim.restart()
        } else {
            closeAnim.restart()
        }
    }

    function close() {
        opened = false
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
        width: 384
        height: 620
        anchors.bottom: parent.bottom
        x: networkPanel.width

        radius: 22

        layer.enabled: true
        layer.smooth: true

        // subtle top accent wash
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(panel.accent.r, panel.accent.g, panel.accent.b, 0.05) }
                GradientStop { position: 0.35; color: "transparent" }
            }
        }
        readonly property color accent: Colors.primary

        FocusScope {
            anchors.fill: parent
            focus: networkPanel.opened

            Keys.onEscapePressed: networkPanel.close()

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 14

                // ── Segmented tab control with sliding indicator ──
                Rectangle {
                    id: tabBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    radius: 16
                    color: Colors.surface_container_high

                    Rectangle {
                        id: tabIndicator
                        width: (tabBar.width - 8) / 2
                        height: tabBar.height - 8
                        y: 4
                        x: 4 + (networkPanel.currentTab === 0 ? 0 : width)
                        radius: 12
                        color: Colors.primary
                        Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 0

                        Repeater {
                            model: [
                                { glyph: "󰖩", label: "Wi-Fi" },
                                { glyph: "󰂯", label: "Bluetooth" }
                            ]
                            delegate: Item {
                                id: tabDelegate
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                property bool selected: networkPanel.currentTab === index

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 8

                                    MaterialIcon {
                                        text: modelData.glyph
                                        font.pixelSize: 17
                                        color: tabDelegate.selected
                                            ? Colors.on_primary
                                            : Colors.on_surface_variant
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }
                                    StyledText {
                                        text: modelData.label
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        color: tabDelegate.selected
                                            ? Colors.on_primary
                                            : Colors.on_surface_variant
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: networkPanel.currentTab = index
                                }
                            }
                        }
                    }
                }

                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: networkPanel.currentTab === 0
                        ? wifiComponent
                        : bluetoothComponent
                }
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
