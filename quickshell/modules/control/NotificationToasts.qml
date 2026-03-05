import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services as Services
import "../../colors" as ColorsModule
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: win

    color: "transparent"

    anchors.top: true
    anchors.right: true

    implicitWidth: Services.Notification.popups.length > 0 ? 340 : 0
    implicitHeight: 600

    Column {
        id: stack
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 8

        Repeater {
            model: Services.Notification.popups

            delegate: Rectangle {
                required property var modelData

                radius: 14
                width: 280
                height: content.implicitHeight + 18

                color: ColorsModule.Colors.surface_container_high
                border.color: ColorsModule.Colors.outline_variant
                border.width: 1

                opacity: 1
                scale: 1

                // shadow
                layer.enabled: true
                layer.effect: DropShadow {
                    horizontalOffset: 0
                    verticalOffset: 3
                    radius: 16
                    samples: 24
                    color: ColorsModule.Colors.shadow
                }

                Behavior on opacity {
                    NumberAnimation { duration: 120 }
                }

                Behavior on scale {
                    NumberAnimation { duration: 120 }
                }

                ColumnLayout {
                    id: content
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            width: 28
                            height: 28
                            radius: 7
                            color: "transparent"
                            clip: true

                            Image {
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                property var image: modelData.appIcon

                                source: {
                                    if (typeof image !== "undefined" && image && image.startsWith("/"))
                                        return "file://" + image;

                                    if (typeof image !== "undefined" && image && image.includes("://"))
                                        return image;

                                    if (typeof appIcon !== "undefined" && appIcon && appIcon.includes("/"))
                                        return "file://" + appIcon;

                                    if (typeof appIcon !== "undefined" && appIcon)
                                        return "image://icon/" + appIcon;

                                    return "";
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Text {
                                text: modelData.summary
                                font.bold: true
                                font.pixelSize: 13
                                color: ColorsModule.Colors.on_surface
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }

                            Text {
                                visible: modelData.body.length > 0
                                text: modelData.body
                                font.pixelSize: 12
                                color: ColorsModule.Colors.on_surface_variant
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    onPressed: parent.scale = 0.97
                    onReleased: parent.scale = 1.0

                    onClicked: {
                        if (modelData.actions.length > 0) {
                            let defaultAction = modelData.actions.find(action => action.id === "default");
                            if (defaultAction) {
                                defaultAction.invoke();
                            } else {
                                modelData.actions[0].invoke();
                            }
                        }
                        modelData.popup = false;
                    }
                }
            }
        }
    }
}