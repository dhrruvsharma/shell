import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.services as Services
import "../../colors" as ColorsModule
import qs.components
import qs.modules.control

Item {
    id: controlCenter
    property bool opened: false
    focus: true

    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    property int controlCenterWidth: 450
    implicitWidth: opened ? controlCenterWidth : 0
    x: 0

    function run(cmd) {
        proc.exec(cmd)
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    Process { id: proc }

    FocusScope {
        anchors.fill: parent
        focus: controlCenter.opened
        Keys.onEscapePressed: {
            controlCenter.opened = false
        }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 1

            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
        }

        Rectangle {
            id: slideContainer
            width: controlCenter.controlCenterWidth
            height: parent.height
            color: "transparent"

            x: controlCenter.opened ? 0 : -width

            Behavior on x {
                NumberAnimation {
                    duration: 400
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors.fill: parent
                color: ColorsModule.Colors.surface_container_low

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0) }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.15) }
                    }
                }

                Rectangle {
                    width: 3
                    height: parent.height
                    anchors.left: parent.left
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: ColorsModule.Colors.primary }
                        GradientStop { position: 0.5; color: ColorsModule.Colors.secondary }
                        GradientStop { position: 1.0; color: ColorsModule.Colors.tertiary }
                    }
                }
            }

            layer.enabled: true

            Flickable {
                id: flickable
                anchors.fill: parent
                contentHeight: mainColumn.height + 30
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                ColumnLayout {
                    id: mainColumn
                    width: parent.width
                    spacing: 0

                    Header { }

                    QuickSettings { }

                    SliderSection { }

                    SinkSelector {
                        anchors.left: parent.left
                        anchors.right: parent.right
                    }

                    StatsSection { }

                    InfoSection { }

                    Notifications { }

                    PowerSection { }
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 6
                width: 5
                radius: 2.5
                color: ColorsModule.Colors.surface_container_high
                opacity: flickable.moving ? 0.4 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 250 }
                }

                Rectangle {
                    width: parent.width
                    height: Math.max(30, (flickable.height / flickable.contentHeight) * parent.height)
                    y: (flickable.contentY / flickable.contentHeight) * parent.height
                    radius: 2.5
                    color: ColorsModule.Colors.primary
                    opacity: 0.8

                    Behavior on y {
                        NumberAnimation { duration: 100 }
                    }
                }
            }
        }
    }
}
