import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.components
import qs.colors
import qs.modules.timer
import qs.services as Services

Popout {
    id: root
    alignment: 3
    property bool opened: false
    // Hidden once fully collapsed so the calendar's loading indicator (and any
    // repaint) stops; a zero-width but visible panel still drives frames.
    visible: root.opened || root.implicitWidth > 0
    // Without a GitHub username only the Timer tab is shown
    readonly property bool githubEnabled: Services.Github.enabled
    property int currentTab: githubEnabled ? 0 : 1
    focus: true

    property int headerHeight: 48
    property color backgroundColor: Colors.surface
    property color surfaceColor: Colors.surface_container_highest
    property color accentColor: Colors.primary
    property color textColor: Colors.on_surface
    property color closeButtonColor: Colors.error
    property color closeButtonHoverColor: Colors.error_container

    implicitHeight: 500
    implicitWidth: opened ? 850 : 0

    opacity: 1

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 350
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.backgroundColor
        radius: Services.DesktopTheme.rad(12)

        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 16

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.headerHeight
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

                        TabButton {
                            text: "GitHub"
                            visible: root.githubEnabled
                            active: currentTab === 0
                            onClicked: currentTab = 0
                        }

                        TabButton {
                            text: "Timer"
                            active: currentTab === 1
                            onClicked: currentTab = 1
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            id: closeButton
                            implicitWidth: 32
                            implicitHeight: 32
                            radius: Services.DesktopTheme.rad(16)
                            color: closeMouseArea.containsMouse ? root.closeButtonHoverColor : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }

                            StyledText {
                                anchors.centerIn: parent
                                text: "✕"
                                color: closeMouseArea.containsMouse ?
                                    Colors.on_error_container :
                                    root.closeButtonColor
                                font.pixelSize: 16
                                font.bold: true
                            }

                            MouseArea {
                                id: closeMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.opened = false
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.surfaceColor
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 8

                Loader {
                    id: contentLoader
                    anchors.fill: parent
                    sourceComponent: currentTab === 0 && root.githubEnabled ? ghCalendar : timerComponent

                    opacity: 1
                    Behavior on opacity {
                        NumberAnimation { duration: 200 }
                    }
                }
            }
        }
    }

    Component {
        id: ghCalendar
        GhCalendar {}
    }

    Component {
        id: timerComponent
        TimerComponent {}
    }

    Timer {
        running: root.autoHide && root.opened
        interval: root.hideDelay
        onTriggered: root.opened = false
    }
}