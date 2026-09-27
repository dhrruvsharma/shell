import QtQuick
import qs.services as Services
import QtQuick.Layouts
import qs.colors
import qs.components

Item {
    id: root
    height: 36

    property var conversation: null
    property bool selected: false
    signal clicked()
    signal deleteClicked()

    Rectangle {
        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
        radius: Services.DesktopTheme.rad(7)
        color: selected
            ? Colors.secondary_container
            : (area.containsMouse ? Colors.surface_container : "transparent")

        Behavior on color { ColorAnimation { duration: 120 } }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }

        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 6 }
            spacing: 6

            StyledText {
                text: "›"
                font.pixelSize: 14
                color: selected
                    ? Colors.on_secondary_container
                    : Colors.on_surface_variant
                opacity: selected ? 1 : 0.5
            }

            StyledText {
                Layout.fillWidth: true
                text: conversation ? conversation.title : ""
                font { pixelSize: 12 }
                color: selected
                    ? Colors.on_secondary_container
                    : Colors.on_surface
                elide: Text.ElideRight
            }

            Rectangle {
                width: 22; height: 22; radius: 6
                visible: area.containsMouse
                color: delHov.containsMouse
                    ? Colors.error_container : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }

                StyledText {
                    anchors.centerIn: parent; text: "×"; font.pixelSize: 14
                    color: delHov.containsMouse
                        ? Colors.on_error_container
                        : Colors.error
                    opacity: delHov.containsMouse ? 1 : 0.7
                }

                MouseArea {
                    id: delHov
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => { mouse.accepted = true; root.deleteClicked() }
                }
            }
        }
    }
}
