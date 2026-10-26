pragma Singleton
import QtQuick
import Quickshell

// The customizer's book (modules/customizer) as the rest of the shell sees
// it: whether it's open, and a way to ask for it from anywhere (the gear on
// the bar asks for its chapter on the bar). shell.qml answers `requested`.
Singleton {
    id: root

    // The book is open (or on its way open).
    property bool open: false

    // `where` is a chapter or spread ("bar", "disc", "gaps", "3"…), or ""
    // for wherever it was left.
    signal requested(string where)

    function request(where) {
        root.requested(where ?? "");
    }

    // Another of the shell's panels, asked for from the book (the Themes
    // panel, the lock screens, the wallpaper picker, the keybinds…).
    signal panelRequested(string which)

    function openPanel(which) {
        root.panelRequested(which);
    }

    function opened(on) {
        root.open = on;
    }
}
