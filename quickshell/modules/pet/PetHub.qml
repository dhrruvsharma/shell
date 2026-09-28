pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services as Services

// The pet's hub (PetHubCard) in a window hanging from the bar under the
// pet, while Services.Pet.hubOpen. It takes the keyboard while it's open
// and closes on Esc, on a click anywhere else, or on the pet again. The
// window exists only while it's showing.
Scope {
    id: root

    property bool up: false
    property real shown: 0
    // Where the pet was when it opened (the card stays put while it walks);
    // -1 to centre it, when the pet isn't in the bar.
    property real anchorX: -1

    Behavior on shown {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    Connections {
        target: Services.Pet

        function onHubOpenChanged() {
            if (Services.Pet.hubOpen) {
                root.anchorX = Services.Pet.shown && Services.Pet.barX > 0 ? Services.Pet.barX : -1;
                root.up = true;
                root.shown = 1;
            } else {
                root.shown = 0;
            }
        }
    }

    // Unloads once the fade-out is done.
    Timer {
        interval: 220
        running: root.up && !Services.Pet.hubOpen && root.shown === 0
        onTriggered: root.up = false
    }

    LazyLoader {
        active: root.up

        PanelWindow {
            id: win

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:pet-hub"
            WlrLayershell.keyboardFocus: Services.Pet.hubOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            color: "transparent"

            // A click anywhere else closes it.
            MouseArea {
                anchors.fill: parent
                enabled: Services.Pet.hubOpen
                acceptedButtons: Qt.AllButtons
                onClicked: Services.Pet.hubOpen = false
            }

            Item {
                id: holder

                x: root.anchorX < 0 ? (win.width - width) / 2 : Math.max(12, Math.min(win.width - width - 12, root.anchorX - width / 2))
                y: 50
                width: Math.min(640, win.width - 24)
                height: card.implicitHeight
                opacity: root.shown
                scale: 0.94 + 0.06 * root.shown
                transformOrigin: Item.Top

                // Clicks on the card's bare parts stay on the card.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                }

                PetHubCard {
                    id: card
                    anchors.fill: parent
                    onCloseRequested: Services.Pet.hubOpen = false
                }
            }

            Component.onCompleted: Qt.callLater(card.focusSearch)
        }
    }
}
