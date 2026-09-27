import QtQuick
import qs.services as Services
import QtQuick.Layouts
import qs.colors
import qs.components

Item {
    id: root
    height: 56

    property var character: null
    property bool selected: false
    signal clicked()
    signal editClicked()

    Rectangle {
        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
        radius: Services.DesktopTheme.rad(10)
        color: selected
            ? Colors.primary_container
            : (hover.containsMouse ? Colors.surface_container_high : "transparent")

        Behavior on color { ColorAnimation { duration: 130 } }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clicked()
        }

        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
            spacing: 10

            // Avatar circle
            Rectangle {
                width: 34; height: 34
                radius: Services.DesktopTheme.rad(17)
                color: selected
                    ? Colors.primary
                    : Colors.surface_container_highest

                StyledText {
                    anchors.centerIn: parent
                    text: character ? character.name.charAt(0).toUpperCase() : "?"
                    font { pixelSize: 14; weight: Font.Medium }
                    color: selected
                        ? Colors.on_primary
                        : Colors.on_surface_variant
                }
            }

            // Name + description
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: character ? character.name : ""
                    font { pixelSize: 13; weight: Font.Medium }
                    color: selected
                        ? Colors.on_primary_container
                        : Colors.on_surface
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: character && character.personality ? character.personality.split(".")[0] : ""
                    font.pixelSize: 10
                    color: Colors.on_surface_variant
                    opacity: 0.7
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }

            // Edit button — only on hover
            Rectangle {
                width: 26; height: 26; radius: 7
                visible: hover.containsMouse
                color: editHov.containsMouse
                    ? Colors.surface_container_highest : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }

                StyledText {
                    anchors.centerIn: parent
                    text: "✎"; font.pixelSize: 12
                    color: Colors.on_surface_variant
                }

                MouseArea {
                    id: editHov
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => { mouse.accepted = true; root.editClicked() }
                }
            }
        }
    }
}
