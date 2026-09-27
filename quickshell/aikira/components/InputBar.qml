import QtQuick
import qs.services as Services
import qs.aikira
import QtQuick.Layouts
import qs.colors
import qs.components

Item {
    id: root
    height: 56

    property bool enabled: true
    signal send(string text)

    Rectangle {
        anchors.fill: parent
        color: Colors.surface_container

        Divider {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            opacity: 0.4
        }

        RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 12; topMargin: 8; bottomMargin: 8 }
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                height: 36
                radius: Services.DesktopTheme.rad(18)
                clip: true
                color: Colors.surface_container_highest
                border {
                    width: inputField.activeFocus ? 1 : 0
                    color: Colors.primary
                }

                Behavior on border.width { NumberAnimation { duration: 100 } }

                StyledText {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 16; topMargin: 8; bottomMargin: 8 }
                    text: root.enabled ? "type a message…" : "waiting for response…"
                    color: Colors.on_surface_variant
                    opacity: 0.4
                    font { pixelSize: 13; family: "monospace" }
                    visible: inputField.text.length === 0
                    verticalAlignment: Text.AlignVCenter
                }

                Flickable {
                    id: inputFlickable
                    anchors { fill: parent; leftMargin: 16; rightMargin: 16; topMargin: 8; bottomMargin: 8 }
                    contentHeight: inputField.implicitHeight
                    clip: true
                    flickableDirection: Flickable.VerticalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    onContentHeightChanged: {
                        if (contentHeight > height) contentY = contentHeight - height
                    }

                    TextEdit {
                        id: inputField
                        width: inputFlickable.width
                        color: Colors.on_surface
                        font { pixelSize: 13; family: "monospace" }
                        wrapMode: TextEdit.Wrap
                        enabled: root.enabled
                        selectByMouse: true

                        // Enter = send, Shift+Enter = newline
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Return && !(event.modifiers & Qt.ShiftModifier)) {
                                event.accepted = true
                                doSend()
                            }
                        }
                    }
                }
            }

            // Send button
            Rectangle {
                width: 36; height: 36; radius: 18
                color: root.enabled && inputField.text.trim().length > 0
                    ? Colors.primary
                    : Colors.surface_container_highest

                Behavior on color { ColorAnimation { duration: 150 } }

                StyledText {
                    anchors.centerIn: parent
                    text: AppState.streaming ? "◼" : "↑"
                    font { pixelSize: 15; weight: Font.Bold }
                    color: root.enabled && inputField.text.trim().length > 0
                        ? Colors.on_primary
                        : Colors.on_surface_variant
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: root.enabled
                    onClicked: doSend()
                }
            }
        }
    }

    function doSend() {
        const t = inputField.text.trim()
        if (!t || !root.enabled) return
        inputField.text = ""
        root.send(t)
    }
}
