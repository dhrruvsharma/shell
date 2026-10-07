import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.modules.anime
import qs.modules.manga
import qs.modules.novel

// Anime player, manga reader and novel reader as side panels. Each one is
// loaded on its first toggle, kept while minimized, and unloaded shortly
// after it is closed:
//
//   qs-novelmangareader anime|manga|novel
// (bin/qs-novelmangareader; underneath, `qs -p <this folder> ipc call
// animePlayer|mangaReader|novelReader toggle`)
ShellRoot {
    id: root

    component ReaderSlot: Loader {
        id: slot

        // Tracked by hand: while the window is unmapped every panel in it
        // reads as invisible, so item.visible can't say what should show.
        property bool open: false

        function toggle() {
            if (!active) {
                active = true;
                item.visible = true;
                open = true;
            } else if (open) {
                item.visible = false;
            } else {
                // restoring a minimized panel; closing it next time unloads it
                item.minimized = false;
                item.visible = true;
                open = true;
            }
        }

        active: false

        Timer {
            id: unloadTimer
            interval: 600
            // unless it was reopened or minimized in the meantime
            onTriggered: if (!slot.open && !slot.item?.minimized) slot.active = false
        }

        Connections {
            target: slot.item
            // Closed from the toggle or its own minimize button.
            function onVisibleChanged() {
                if (!slot.open || slot.item.visible)
                    return;
                slot.open = false;
                if (!slot.item.minimized)
                    unloadTimer.start();
            }
        }
    }

    PanelWindow {
        id: window

        // Mapped only while a panel is showing; the rest of the surface
        // passes input through to the windows below.
        visible: animeSlot.open || mangaSlot.open || novelSlot.open

        WlrLayershell.namespace: "qs-novelmangareader"
        WlrLayershell.layer: WlrLayer.Top
        // Keep clear of the user's bar and other panels' exclusive zones.
        exclusionMode: ExclusionMode.Normal
        focusable: true
        color: "transparent"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        mask: Region {
            Region {
                item: root.maskItem(mangaSlot)
            }
            Region {
                item: root.maskItem(novelSlot)
            }
            Region {
                item: root.maskItem(animeSlot)
            }
        }

        Item {
            anchors.fill: parent

            ReaderSlot {
                id: mangaSlot
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
                sourceComponent: MangaReader {}
            }

            ReaderSlot {
                id: novelSlot
                anchors {
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                }
                sourceComponent: NovelReader {}
            }

            ReaderSlot {
                id: animeSlot
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
                sourceComponent: AnimePanel {}
            }
        }
    }

    function maskItem(slot) {
        return slot.open ? slot.item : null;
    }

    IpcHandler {
        target: "mangaReader"
        function toggle(): void {
            mangaSlot.toggle();
        }
    }

    IpcHandler {
        target: "novelReader"
        function toggle(): void {
            novelSlot.toggle();
        }
    }

    IpcHandler {
        target: "animePlayer"
        function toggle(): void {
            animeSlot.toggle();
        }
    }
}
