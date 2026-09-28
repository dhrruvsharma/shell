import QtQuick
import qs.services as Services

// The pet, large, in the hub's header. It sits and blinks, looks up when
// the pointer comes near, and a click pats it (hearts and all).
PetFigure {
    id: portrait

    property bool petted: false

    pose: portrait.petted ? "happy" : near.containsMouse ? "look" : "sit"
    species: Services.Pet.species
    coat: Services.Pet.coat
    costume: Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""
    accent: Services.DesktopTheme.accent
    accent2: Services.DesktopTheme.accent2

    SequentialAnimation {
        id: blinkAnim
        NumberAnimation { target: portrait; property: "blink"; to: 1; duration: 70 }
        NumberAnimation { target: portrait; property: "blink"; to: 0; duration: 110 }
    }

    Timer {
        interval: 2600 + Math.random() * 3000
        repeat: true
        running: portrait.visible && !portrait.petted
        onTriggered: {
            interval = 2600 + Math.random() * 3000;
            blinkAnim.restart();
        }
    }

    SequentialAnimation {
        id: patAnim
        PropertyAction { target: portrait; property: "petted"; value: true }
        NumberAnimation { target: portrait; property: "hearts"; from: 0.001; to: 0.999; duration: 1300 }
        PropertyAction { target: portrait; property: "hearts"; value: 0 }
        PropertyAction { target: portrait; property: "petted"; value: false }
    }

    MouseArea {
        id: near
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Services.Pet.pat();
            patAnim.restart();
        }
    }
}
